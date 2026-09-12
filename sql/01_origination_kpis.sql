-- Capital Markets origination KPIs. Databricks SQL.
-- Price: points (100 = par). Dollars = UPB * points / 100.
-- Silver inputs: fact_rate_lock, fact_lock_status_hist, fact_lock_event,
--   fact_funded_loan, fact_loan_sale, fact_warehouse_draw, fact_hedge_trade,
--   fact_best_ex_quote, ref_pullthrough_forecast, ref_tba_market.

CREATE OR REPLACE VIEW gold_lock_asof AS
WITH params AS (SELECT current_date() AS as_of_date),
latest AS (
  SELECT h.lock_id, h.status_ts, h.status, h.upb, h.net_price_current, h.days_to_expire, p.as_of_date
  FROM fact_lock_status_hist h
  CROSS JOIN params p
  WHERE h.status_ts < p.as_of_date + INTERVAL 1 DAY
  QUALIFY ROW_NUMBER() OVER (PARTITION BY h.lock_id ORDER BY h.status_ts DESC) = 1
)
SELECT
  l.lock_id, l.loan_id, l.lock_ts, l.expire_ts, l.original_upb,
  COALESCE(s.upb, l.original_upb) AS current_upb,
  l.note_rate, l.product, l.purpose, l.occupancy, l.channel, l.coupon_bucket,
  l.lock_net_price, l.borrower_buy_price, l.planned_lo_comp_pts, l.planned_orig_cost_pts,
  COALESCE(s.status, l.status) AS status_asof,
  s.net_price_current, s.days_to_expire, s.as_of_date,
  CASE WHEN COALESCE(s.status, l.status) IN ('fallen_out','expired','funded') THEN TRUE ELSE FALSE END AS is_terminal,
  CASE WHEN COALESCE(s.status, l.status) = 'funded' THEN TRUE ELSE FALSE END AS is_funded,
  CASE WHEN COALESCE(s.status, l.status) IN ('fallen_out','expired') THEN TRUE ELSE FALSE END AS is_fallout
FROM fact_rate_lock l
LEFT JOIN latest s ON s.lock_id = l.lock_id;

CREATE OR REPLACE VIEW gold_lock_risk_asof AS
SELECT
  a.*,
  COALESCE(pt.pt_forecast, 0.75) AS pt_forecast,
  COALESCE(pt.eff_duration, 5.20) AS loan_eff_duration,
  tba.tba_price_pts, tba.tba_eff_duration,
  COALESCE(a.net_price_current, a.lock_net_price) - a.lock_net_price AS price_move_pts,
  a.lock_net_price - a.borrower_buy_price AS locked_margin_pts,
  COALESCE(a.net_price_current, a.lock_net_price) - a.borrower_buy_price AS current_margin_pts,
  a.current_upb * COALESCE(pt.pt_forecast, 0.75) AS pt_weighted_upb,
  a.current_upb * COALESCE(pt.pt_forecast, 0.75)
    * (a.lock_net_price - a.borrower_buy_price) / 100 AS expected_lock_margin_usd,
  a.current_upb * COALESCE(pt.pt_forecast, 0.75)
    * (COALESCE(a.net_price_current, a.lock_net_price) - a.lock_net_price) / 100 AS pipeline_mtm_usd,
  a.current_upb * COALESCE(pt.pt_forecast, 0.75)
    * COALESCE(pt.eff_duration, 5.20) / 10000 AS pipeline_dv01_usd,
  a.current_upb * COALESCE(pt.pt_forecast, 0.75)
    * (COALESCE(a.net_price_current, a.lock_net_price) - a.borrower_buy_price) / 100 AS econ_usd
FROM gold_lock_asof a
LEFT JOIN ref_pullthrough_forecast pt
  ON pt.as_of_date = a.as_of_date AND pt.status = a.status_asof
 AND pt.channel = a.channel AND pt.purpose = a.purpose AND pt.product = a.product
LEFT JOIN ref_tba_market tba
  ON tba.as_of_date = a.as_of_date AND tba.coupon_bucket = a.coupon_bucket
WHERE a.is_fallout = FALSE;

CREATE OR REPLACE VIEW gold_cm_daily_position AS
WITH pipeline AS (
  SELECT as_of_date,
    SUM(CASE WHEN is_funded THEN 0 ELSE current_upb END) AS locked_upb_gross,
    SUM(CASE WHEN is_funded THEN 0 ELSE pt_weighted_upb END) AS locked_ptwlv,
    SUM(CASE WHEN is_funded THEN current_upb ELSE 0 END) AS hfs_upb,
    SUM(pipeline_mtm_usd) AS pipeline_mtm_usd,
    SUM(pipeline_dv01_usd) AS pipeline_dv01_usd
  FROM gold_lock_risk_asof
  GROUP BY as_of_date
)
SELECT
  p.as_of_date, p.locked_upb_gross, p.locked_ptwlv, p.hfs_upb,
  p.locked_ptwlv + p.hfs_upb AS hedgeable_upb,
  p.pipeline_mtm_usd, p.pipeline_dv01_usd
FROM pipeline p;

-- Additional views in the local pack (gold_vintage_l2f, gold_loan_gos,
-- gold_gos_slippage_waterfall, gold_lock_desk_leakage, gold_hfs_carry):
-- artifacts/cm_repo/sql/01_origination_kpis.sql
