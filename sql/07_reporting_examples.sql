-- Reporting examples for main.gold_cm. Databricks SQL.
-- Bind dates as current_date() - 1 or a warehouse parameter.

-- 1) Morning sheet: coverage recomputed after SUM
SELECT as_of_date,
  SUM(locked_upb_gross) AS locked_upb,
  SUM(locked_ptwlv) AS ptwlv,
  SUM(hfs_upb) AS hfs_upb,
  SUM(locked_ptwlv) + SUM(hfs_upb) AS hedgeable_upb,
  SUM(net_mtm_usd) AS net_mtm_usd,
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
  (p.pipeline_dv01_usd - COALESCE(p.hedge_dv01_usd, 0))
    / NULLIF(p.pipeline_dv01_usd, 0) AS net_dv01_pct
FROM main.gold_cm.fact_position_daily p
LEFT JOIN main.gold_cm.dim_coupon_bucket c ON c.coupon_bucket_key = p.coupon_bucket_key
WHERE p.as_of_date = current_date() - INTERVAL 1 DAY;

-- 3) Open book by note structure x ITM
SELECT n.note_structure_code, i.itm_code, COUNT(*) lock_count,
  SUM(s.current_upb) locked_upb, SUM(s.pt_weighted_upb) ptwlv, SUM(s.econ_usd) econ_usd,
  SUM(CASE WHEN s.pt_source = 'default' THEN 1 ELSE 0 END) / COUNT(*) AS default_pt_share
FROM main.gold_cm.v_lock_snapshot_with_note s
LEFT JOIN main.gold_cm.dim_note_structure n ON n.note_structure_key = s.note_structure_key
LEFT JOIN main.gold_cm.dim_itm_bucket i ON i.itm_bucket_key = s.itm_bucket_key
WHERE s.as_of_date = current_date() - INTERVAL 1 DAY AND s.is_fallout = FALSE
GROUP BY 1, 2;

-- 4) Attribution window
SELECT as_of_date, SUM(d_econ) d_econ, SUM(pnl_new_locks) pnl_new_locks,
  SUM(pnl_fallout) pnl_fallout, SUM(pnl_market) pnl_market,
  SUM(pnl_pt_revision) pnl_pt_revision, SUM(pnl_renego) pnl_renego,
  SUM(pnl_residual) pnl_residual
FROM main.gold_cm.fact_attribution_daily
WHERE as_of_date >= current_date() - INTERVAL 10 DAYS
GROUP BY as_of_date ORDER BY as_of_date;

-- 5) GOS by sale month x channel (do not add daily MTM)
SELECT DATE_TRUNC('month', g.sale_date) sale_month, c.channel_code,
  SUM(g.sold_upb) sold_upb, SUM(g.realized_gos_usd) gos_usd,
  SUM(g.realized_gos_usd) / NULLIF(SUM(g.sold_upb), 0) * 10000 AS gos_bps,
  SUM(g.sold_upb * g.gos_slippage_pts) / NULLIF(SUM(g.sold_upb), 0) AS wavg_slippage_pts
FROM main.gold_cm.fact_gos g
LEFT JOIN main.gold_cm.dim_channel c ON c.channel_key = g.channel_key
WHERE g.sale_date >= ADD_MONTHS(current_date(), -6)
GROUP BY 1, 2;

-- 6) Realized L2F (calibration only)
SELECT lock_month, lock_count, locked_upb, funded_upb, pt_vol, pt_count
FROM main.gold_cm.fact_vintage_l2f
WHERE lock_month >= ADD_MONTHS(DATE_TRUNC('month', current_date()), -12);

-- 7) Default PT leak
SELECT pt_source, COUNT(*) n_locks, SUM(current_upb) upb, SUM(pt_weighted_upb) ptwlv
FROM main.gold_cm.fact_lock_snapshot_daily
WHERE as_of_date = current_date() - INTERVAL 1 DAY AND is_fallout = FALSE
GROUP BY pt_source;

-- 8) Eligibility at lock vs current dim_loan
SELECT e.loan_id, e.fico AS fico_at_lock, d.fico AS fico_now,
       e.ltv AS ltv_at_lock, d.ltv AS ltv_now, e.llpa_pts
FROM main.gold_cm.fact_loan_eligibility e
JOIN main.gold_cm.dim_loan d ON d.loan_id = e.loan_id AND d.is_current = TRUE
WHERE e.event_type = 'lock' AND e.as_of_date >= current_date() - INTERVAL 30 DAYS;

-- 9) Warehouse utilization
SELECT w.as_of_date, f.facility_code, w.committed_capacity, w.outstanding, w.available,
  w.outstanding / NULLIF(w.committed_capacity, 0) AS utilization
FROM main.gold_cm.fact_warehouse_balance_daily w
LEFT JOIN main.gold_cm.dim_warehouse f ON f.facility_key = w.facility_key AND f.is_current = TRUE
WHERE w.as_of_date = current_date() - INTERVAL 1 DAY;

-- 10) Latest 15-min print vs yesterday SOD
WITH last_print AS (
  SELECT * FROM main.gold_cm.fact_position_15m
  QUALIFY ROW_NUMBER() OVER (PARTITION BY coupon_bucket_key ORDER BY print_ts DESC) = 1
),
sod AS (
  SELECT coupon_bucket_key, locked_ptwlv, hfs_upb, tba_short_upb
  FROM main.gold_cm.fact_position_daily
  WHERE as_of_date = current_date() - INTERVAL 1 DAY
)
SELECT p.print_ts, p.locked_ptwlv AS ptwlv_now, s.locked_ptwlv AS ptwlv_sod,
  p.tba_short_upb / NULLIF(p.locked_ptwlv + p.hfs_upb, 0) AS pt_coverage_now
FROM last_print p
LEFT JOIN sod s ON s.coupon_bucket_key = p.coupon_bucket_key;
