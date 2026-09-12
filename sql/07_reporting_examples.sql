-- Reporting examples — capital markets gold mart. Databricks SQL.
-- Dates: current_date() - 1 or a warehouse parameter.
-- Sources: main.gold_cm fact_lock_snapshot_daily, fact_position_daily,
--   fact_attribution_daily, fact_gos, fact_vintage_l2f,
--   v_lock_snapshot_with_note, fact_position_15m, fact_loan_eligibility.

-- 1) Morning sheet — coverage recomputed after SUM
SELECT
  as_of_date,
  SUM(locked_upb_gross) AS locked_upb,
  SUM(locked_ptwlv) AS ptwlv,
  SUM(hfs_upb) AS hfs_upb,
  SUM(locked_ptwlv) + SUM(hfs_upb) AS hedgeable_upb,
  SUM(pipeline_mtm_usd) AS pipeline_mtm_usd,
  SUM(hedge_mtm_usd) AS hedge_mtm_usd,
  SUM(net_mtm_usd) AS net_mtm_usd,
  SUM(pipeline_dv01_usd) AS pipeline_dv01_usd,
  SUM(hedge_dv01_usd) AS hedge_dv01_usd,
  SUM(tba_short_upb) / NULLIF(SUM(locked_ptwlv + hfs_upb), 0) AS pt_coverage,
  SUM(hedge_dv01_usd) / NULLIF(SUM(pipeline_dv01_usd), 0) AS duration_coverage,
  (SUM(pipeline_dv01_usd) - SUM(COALESCE(hedge_dv01_usd, 0)))
    / NULLIF(SUM(pipeline_dv01_usd), 0) AS net_dv01_pct
FROM main.gold_cm.fact_position_daily
WHERE as_of_date = current_date() - INTERVAL 1 DAY
GROUP BY as_of_date;

-- 2) Coupon drill
SELECT p.as_of_date, c.coupon_bucket_code, p.locked_ptwlv, p.hfs_upb, p.tba_short_upb,
  p.tba_short_upb / NULLIF(p.locked_ptwlv + p.hfs_upb, 0) AS pt_coverage,
  p.pipeline_dv01_usd, p.hedge_dv01_usd,
  (p.pipeline_dv01_usd - COALESCE(p.hedge_dv01_usd, 0))
    / NULLIF(p.pipeline_dv01_usd, 0) AS net_dv01_pct
FROM main.gold_cm.fact_position_daily p
LEFT JOIN main.gold_cm.dim_coupon_bucket c ON c.coupon_bucket_key = p.coupon_bucket_key
WHERE p.as_of_date = current_date() - INTERVAL 1 DAY
ORDER BY ABS((p.pipeline_dv01_usd - COALESCE(p.hedge_dv01_usd, 0))
  / NULLIF(p.pipeline_dv01_usd, 0)) DESC NULLS LAST;

-- 3) Open book by note structure x ITM
SELECT s.channel_key, n.note_structure_code, i.itm_code,
  COUNT(*) lock_count, SUM(s.current_upb) locked_upb, SUM(s.pt_weighted_upb) ptwlv,
  SUM(s.econ_usd) econ_usd, AVG(s.pt_forecast) avg_pt,
  SUM(CASE WHEN s.pt_source = 'default' THEN 1 ELSE 0 END) / COUNT(*) AS default_pt_share
FROM main.gold_cm.v_lock_snapshot_with_note s
LEFT JOIN main.gold_cm.dim_note_structure n ON n.note_structure_key = s.note_structure_key
LEFT JOIN main.gold_cm.dim_itm_bucket i ON i.itm_bucket_key = s.itm_bucket_key
WHERE s.as_of_date = current_date() - INTERVAL 1 DAY AND s.is_fallout = FALSE
GROUP BY 1, 2, 3;

-- 4) Attribution window
SELECT as_of_date,
  SUM(econ_sod) econ_sod, SUM(econ_eod) econ_eod, SUM(d_econ) d_econ,
  SUM(pnl_new_locks) pnl_new_locks, SUM(pnl_fallout) pnl_fallout,
  SUM(pnl_fund_pt_stepup) pnl_fund_pt_stepup,
  SUM(pnl_market) pnl_market, SUM(pnl_pt_revision) pnl_pt_revision,
  SUM(pnl_renego) pnl_renego, SUM(pnl_upb_change) pnl_upb_change,
  SUM(pnl_residual) pnl_residual,
  ABS(SUM(pnl_residual)) / NULLIF(ABS(SUM(d_econ)), 0) AS residual_share
FROM main.gold_cm.fact_attribution_daily
WHERE as_of_date >= current_date() - INTERVAL 10 DAYS
GROUP BY as_of_date ORDER BY as_of_date;

-- 4b) Offset using LAG of hedge mark on position
WITH attr AS (
  SELECT as_of_date, SUM(pnl_market) pnl_market, SUM(pnl_pt_revision) pnl_pt_revision, SUM(d_econ) d_econ
  FROM main.gold_cm.fact_attribution_daily
  WHERE as_of_date >= current_date() - INTERVAL 10 DAYS
  GROUP BY as_of_date
),
pos AS (
  SELECT as_of_date, SUM(hedge_mtm_usd) hedge_mtm_usd
  FROM main.gold_cm.fact_position_daily
  WHERE as_of_date >= current_date() - INTERVAL 10 DAYS
  GROUP BY as_of_date
)
SELECT a.as_of_date, a.d_econ,
  p.hedge_mtm_usd - LAG(p.hedge_mtm_usd) OVER (ORDER BY a.as_of_date) AS d_hedge_mark,
  -(p.hedge_mtm_usd - LAG(p.hedge_mtm_usd) OVER (ORDER BY a.as_of_date))
    / NULLIF(a.pnl_market + a.pnl_pt_revision, 0) AS offset_ratio
FROM attr a JOIN pos p ON p.as_of_date = a.as_of_date
ORDER BY a.as_of_date;

-- 5) GOS by sale month x channel — do not add daily MTM
SELECT DATE_TRUNC('month', g.sale_date) sale_month, c.channel_code,
  SUM(g.sold_upb) sold_upb, SUM(g.realized_gos_usd) gos_usd,
  SUM(g.realized_gos_usd) / NULLIF(SUM(g.sold_upb), 0) * 10000 AS gos_bps,
  SUM(g.sold_upb * g.locked_margin_pts) / NULLIF(SUM(g.sold_upb), 0) AS wavg_locked_margin_pts,
  SUM(g.sold_upb * g.gos_slippage_pts) / NULLIF(SUM(g.sold_upb), 0) AS wavg_slippage_pts
FROM main.gold_cm.fact_gos g
LEFT JOIN main.gold_cm.dim_channel c ON c.channel_key = g.channel_key
WHERE g.sale_date >= ADD_MONTHS(current_date(), -6)
GROUP BY 1, 2;

-- 6) Realized L2F (calibration only)
SELECT lock_month, ch.channel_code, pr.product_code, pu.purpose_code,
  lock_count, locked_upb, funded_count, funded_upb, pt_vol, pt_count
FROM main.gold_cm.fact_vintage_l2f v
LEFT JOIN main.gold_cm.dim_channel ch ON ch.channel_key = v.channel_key
LEFT JOIN main.gold_cm.dim_product pr ON pr.product_key = v.product_key
LEFT JOIN main.gold_cm.dim_purpose pu ON pu.purpose_key = v.purpose_key
WHERE lock_month >= ADD_MONTHS(DATE_TRUNC('month', current_date()), -12);

-- 7) Default PT leak
SELECT pt_source, COUNT(*) n_locks, SUM(current_upb) upb, SUM(pt_weighted_upb) ptwlv, AVG(pt_forecast) avg_pt
FROM main.gold_cm.fact_lock_snapshot_daily
WHERE as_of_date = current_date() - INTERVAL 1 DAY AND is_fallout = FALSE
GROUP BY pt_source;

-- 8) LLPA replay: lock eligibility vs current dim_loan
SELECT e.loan_id, e.as_of_date AS lock_elig_date,
  e.fico AS fico_at_lock, d.fico AS fico_now,
  e.ltv AS ltv_at_lock, d.ltv AS ltv_now, e.llpa_pts,
  n.note_structure_code, o.occupancy_code, p.property_type_code
FROM main.gold_cm.fact_loan_eligibility e
JOIN main.gold_cm.dim_loan d ON d.loan_id = e.loan_id AND d.is_current = TRUE
LEFT JOIN main.gold_cm.dim_note_structure n ON n.note_structure_key = e.note_structure_key
LEFT JOIN main.gold_cm.dim_occupancy o ON o.occupancy_key = e.occupancy_key
LEFT JOIN main.gold_cm.dim_property_type p ON p.property_type_key = e.property_type_key
WHERE e.event_type = 'lock' AND e.as_of_date >= current_date() - INTERVAL 30 DAYS;

-- 9) Warehouse utilization
SELECT w.as_of_date, f.facility_code, w.committed_capacity, w.outstanding, w.available,
  w.aging_30plus_upb, w.outstanding / NULLIF(w.committed_capacity, 0) AS utilization
FROM main.gold_cm.fact_warehouse_balance_daily w
LEFT JOIN main.gold_cm.dim_warehouse f ON f.facility_key = w.facility_key AND f.is_current = TRUE
WHERE w.as_of_date = current_date() - INTERVAL 1 DAY;

-- 10) Latest 15-min print vs yesterday SOD
WITH last_print AS (
  SELECT * FROM main.gold_cm.fact_position_15m
  QUALIFY ROW_NUMBER() OVER (PARTITION BY coupon_bucket_key ORDER BY print_ts DESC) = 1
),
sod AS (
  SELECT coupon_bucket_key, locked_ptwlv, hfs_upb, pipeline_dv01_usd, tba_short_upb
  FROM main.gold_cm.fact_position_daily
  WHERE as_of_date = current_date() - INTERVAL 1 DAY
)
SELECT c.coupon_bucket_code, p.print_ts,
  p.locked_ptwlv AS ptwlv_now, s.locked_ptwlv AS ptwlv_sod,
  p.locked_ptwlv - s.locked_ptwlv AS d_ptwlv,
  p.tba_short_upb / NULLIF(p.locked_ptwlv + p.hfs_upb, 0) AS pt_coverage_now,
  s.tba_short_upb / NULLIF(s.locked_ptwlv + s.hfs_upb, 0) AS pt_coverage_sod
FROM last_print p
LEFT JOIN sod s ON s.coupon_bucket_key = p.coupon_bucket_key
LEFT JOIN main.gold_cm.dim_coupon_bucket c ON c.coupon_bucket_key = p.coupon_bucket_key;
