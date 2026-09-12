-- =============================================================================
-- B) Daily capital markets P&L attribution
-- Dialect: Databricks SQL
-- econ_usd = current_upb * pt * (net_price_current - borrower_buy_price) / 100
-- Hedge P&L = open TBA mark change + pair-off cash realized that day.
-- =============================================================================

CREATE OR REPLACE VIEW gold_lock_econ_daily AS
SELECT
  s.*,
  s.current_upb
    * CASE WHEN s.is_funded THEN 1.0 ELSE s.pt_forecast END
    * (COALESCE(s.net_price_current, s.lock_net_price) - s.borrower_buy_price)
    / 100 AS econ_usd,
  CASE WHEN s.is_funded THEN 1.0 ELSE s.pt_forecast END AS pt_used
FROM gold_lock_risk_daily s
WHERE s.is_fallout = FALSE;

CREATE OR REPLACE VIEW gold_pnl_lock_bridge AS
WITH dates AS (
  SELECT DISTINCT as_of_date FROM gold_lock_econ_daily
),
pairs AS (
  SELECT
    d.as_of_date AS as_of_date,
    LAG(d.as_of_date) OVER (ORDER BY d.as_of_date) AS prev_date
  FROM dates d
),
t0 AS (
  SELECT e.*, p.as_of_date AS today, p.prev_date
  FROM gold_lock_econ_daily e
  JOIN pairs p ON e.as_of_date = p.prev_date
),
t1 AS (
  SELECT e.*, p.as_of_date AS today, p.prev_date
  FROM gold_lock_econ_daily e
  JOIN pairs p ON e.as_of_date = p.as_of_date
),
cls AS (
  SELECT
    COALESCE(t1.today, t0.today) AS as_of_date,
    COALESCE(t1.lock_id, t0.lock_id) AS lock_id,
    COALESCE(t1.channel, t0.channel) AS channel,
    COALESCE(t1.product, t0.product) AS product,
    COALESCE(t1.coupon_bucket, t0.coupon_bucket) AS coupon_bucket,
    CASE
      WHEN t0.lock_id IS NULL AND t1.lock_id IS NOT NULL
           AND COALESCE(t1.is_funded, FALSE) = FALSE THEN 'new_lock'
      WHEN t0.lock_id IS NULL AND t1.lock_id IS NOT NULL
           AND t1.is_funded = TRUE THEN 'new_hfs'
      WHEN t0.lock_id IS NOT NULL AND t1.lock_id IS NULL THEN
        CASE
          WHEN EXISTS (
            SELECT 1 FROM fact_funded_loan f
            WHERE f.lock_id = t0.lock_id
              AND CAST(f.fund_ts AS DATE) = t0.today
          ) THEN 'funded_out'
          ELSE 'fallout'
        END
      WHEN t0.is_funded = FALSE AND t1.is_funded = TRUE THEN 'funded_stay'
      WHEN t0.is_funded = TRUE AND t1.is_funded = TRUE THEN 'hfs_continuing'
      ELSE 'lock_continuing'
    END AS bucket,
    t0.current_upb AS upb_0,
    t1.current_upb AS upb_1,
    t0.pt_used AS pt_0,
    t1.pt_used AS pt_1,
    t0.borrower_buy_price AS buy_0,
    t1.borrower_buy_price AS buy_1,
    t0.lock_net_price AS lock_px_0,
    t1.lock_net_price AS lock_px_1,
    COALESCE(t0.net_price_current, t0.lock_net_price) AS px_0,
    COALESCE(t1.net_price_current, t1.lock_net_price) AS px_1,
    t0.econ_usd AS econ_0,
    t1.econ_usd AS econ_1
  FROM t0
  FULL OUTER JOIN t1
    ON t1.lock_id = t0.lock_id AND t1.today = t0.today
)
SELECT
  as_of_date, lock_id, channel, product, coupon_bucket, bucket,
  econ_0, econ_1,
  COALESCE(econ_1, 0) - COALESCE(econ_0, 0) AS d_econ,
  CASE WHEN bucket IN ('new_lock', 'new_hfs') THEN COALESCE(econ_1, 0) ELSE 0 END AS pnl_new_locks,
  CASE WHEN bucket = 'fallout' THEN -COALESCE(econ_0, 0) ELSE 0 END AS pnl_fallout,
  CASE WHEN bucket = 'funded_stay'
       THEN upb_0 * (1.0 - pt_0) * (px_0 - buy_0) / 100 ELSE 0 END AS pnl_fund_pt_stepup,
  CASE WHEN bucket IN ('lock_continuing', 'hfs_continuing', 'funded_stay')
       THEN COALESCE(upb_0, 0) * COALESCE(pt_0, 0) * (px_1 - px_0) / 100 ELSE 0 END AS pnl_market,
  CASE WHEN bucket = 'lock_continuing'
       THEN COALESCE(upb_0, 0) * (pt_1 - pt_0) * (px_1 - buy_1) / 100 ELSE 0 END AS pnl_pt_revision,
  CASE WHEN bucket IN ('lock_continuing', 'funded_stay', 'hfs_continuing')
        AND (buy_1 <> buy_0 OR lock_px_1 <> lock_px_0)
       THEN COALESCE(upb_1, 0) * COALESCE(pt_1, 0)
            * ((px_1 - buy_1) - (px_1 - buy_0)) / 100 ELSE 0 END AS pnl_renego,
  CASE WHEN bucket IN ('lock_continuing', 'hfs_continuing')
       THEN (COALESCE(upb_1, 0) - COALESCE(upb_0, 0))
            * COALESCE(pt_1, 0) * (px_1 - buy_1) / 100 ELSE 0 END AS pnl_upb_change
FROM cls;

CREATE OR REPLACE VIEW gold_pnl_lock_bridge_tied AS
SELECT
  b.*,
  d_econ - pnl_new_locks - pnl_fallout - pnl_fund_pt_stepup
    - pnl_market - pnl_pt_revision - pnl_renego - pnl_upb_change AS pnl_residual
FROM gold_pnl_lock_bridge b;

CREATE OR REPLACE VIEW gold_pnl_hedge_daily AS
WITH dates AS (
  SELECT
    as_of_date,
    LAG(as_of_date) OVER (ORDER BY as_of_date) AS prev_date,
    hedge_mtm_usd,
    LAG(hedge_mtm_usd) OVER (ORDER BY as_of_date) AS hedge_mtm_prev
  FROM gold_cm_daily_position
),
pairoff AS (
  SELECT
    CAST(pairoff_ts AS DATE) AS as_of_date,
    SUM(
      CASE WHEN side = 'SELL'
           THEN notional * (price_pts - pairoff_price_pts) / 100
           ELSE notional * (pairoff_price_pts - price_pts) / 100 END
    ) AS realized_pairoff_usd
  FROM fact_hedge_trade
  WHERE pairoff_ts IS NOT NULL
  GROUP BY 1
)
SELECT
  d.as_of_date,
  d.hedge_mtm_usd - COALESCE(d.hedge_mtm_prev, 0) AS d_hedge_mtm,
  COALESCE(p.realized_pairoff_usd, 0) AS realized_pairoff_usd,
  (d.hedge_mtm_usd - COALESCE(d.hedge_mtm_prev, 0))
    + COALESCE(p.realized_pairoff_usd, 0) AS hedge_pnl_total
FROM dates d
LEFT JOIN pairoff p ON p.as_of_date = d.as_of_date
WHERE d.prev_date IS NOT NULL;

CREATE OR REPLACE VIEW gold_pnl_attribution_daily AS
WITH pipe AS (
  SELECT
    as_of_date,
    SUM(econ_0) AS econ_sod,
    SUM(econ_1) AS econ_eod,
    SUM(d_econ) AS d_econ,
    SUM(pnl_new_locks) AS pnl_new_locks,
    SUM(pnl_fallout) AS pnl_fallout,
    SUM(pnl_fund_pt_stepup) AS pnl_fund_pt_stepup,
    SUM(pnl_market) AS pnl_market,
    SUM(pnl_pt_revision) AS pnl_pt_revision,
    SUM(pnl_renego) AS pnl_renego,
    SUM(pnl_upb_change) AS pnl_upb_change,
    SUM(pnl_residual) AS pnl_residual
  FROM gold_pnl_lock_bridge_tied
  GROUP BY as_of_date
)
SELECT
  p.*,
  h.d_hedge_mtm,
  h.realized_pairoff_usd,
  h.hedge_pnl_total,
  p.d_econ + COALESCE(h.hedge_pnl_total, 0) AS net_desk_pnl,
  CASE WHEN (p.pnl_market + p.pnl_pt_revision) = 0 THEN NULL
       ELSE -h.hedge_pnl_total / NULLIF(p.pnl_market + p.pnl_pt_revision, 0)
  END AS hedge_offset_ratio
FROM pipe p
LEFT JOIN gold_pnl_hedge_daily h ON h.as_of_date = p.as_of_date;

CREATE OR REPLACE VIEW gold_pnl_attribution_channel AS
SELECT
  as_of_date, channel,
  SUM(d_econ) AS d_econ,
  SUM(pnl_new_locks) AS pnl_new_locks,
  SUM(pnl_fallout) AS pnl_fallout,
  SUM(pnl_fund_pt_stepup) AS pnl_fund_pt_stepup,
  SUM(pnl_market) AS pnl_market,
  SUM(pnl_pt_revision) AS pnl_pt_revision,
  SUM(pnl_renego) AS pnl_renego,
  SUM(pnl_upb_change) AS pnl_upb_change,
  SUM(pnl_residual) AS pnl_residual
FROM gold_pnl_lock_bridge_tied
GROUP BY 1, 2;
