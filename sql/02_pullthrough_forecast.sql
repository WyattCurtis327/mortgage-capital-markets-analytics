-- =============================================================================
-- A) Pull-through forecast builder
-- Dialect: Databricks SQL
-- Writes: gold_pt_resolved_locks, gold_pt_cell_raw, gold_pt_cell_shrunk,
--         ref_pullthrough_beta, ref_pullthrough_forecast, gold_lock_pt_live
-- lookback_months=12  k_shrink=40  pt clip [0.05, 0.99]
-- price_move > 0 => market rallied, lock OTM for borrower, PT falls.
-- =============================================================================

CREATE OR REPLACE VIEW gold_pt_resolved_locks AS
WITH terminal AS (
  SELECT
    l.lock_id, l.loan_id, l.lock_ts, l.expire_ts, l.original_upb,
    l.channel, l.product, l.purpose, l.occupancy, l.coupon_bucket,
    l.lock_net_price, l.borrower_buy_price,
    CASE WHEN f.loan_id IS NOT NULL THEN 1 ELSE 0 END AS funded_ind,
    COALESCE(f.fund_ts, l.expire_ts) AS resolve_ts,
    CASE WHEN f.loan_id IS NOT NULL THEN 'funded' ELSE 'fallen_out' END AS resolve_type
  FROM fact_rate_lock l
  LEFT JOIN fact_funded_loan f ON f.lock_id = l.lock_id
  WHERE f.loan_id IS NOT NULL
     OR l.expire_ts < current_timestamp()
     OR l.status IN ('fallen_out', 'expired', 'funded')
),
last_open AS (
  SELECT h.lock_id, h.status_ts, h.status, h.upb, h.net_price_current, h.days_to_expire
  FROM fact_lock_status_hist h
  JOIN terminal t ON t.lock_id = h.lock_id
  WHERE h.status NOT IN ('fallen_out', 'expired', 'funded')
    AND h.status_ts < t.resolve_ts
  QUALIFY ROW_NUMBER() OVER (PARTITION BY h.lock_id ORDER BY h.status_ts DESC) = 1
)
SELECT
  t.lock_id, t.loan_id,
  CAST(t.lock_ts AS DATE) AS lock_date,
  CAST(t.resolve_ts AS DATE) AS resolve_date,
  t.channel, t.product, t.purpose, t.occupancy, t.coupon_bucket,
  COALESCE(o.status, 'locked') AS last_open_status,
  COALESCE(o.days_to_expire, 15) AS days_to_expire,
  t.original_upb, t.lock_net_price,
  COALESCE(o.net_price_current, t.lock_net_price) AS net_price_at_last_open,
  COALESCE(o.net_price_current, t.lock_net_price) - t.lock_net_price AS price_move_pts,
  CASE
    WHEN COALESCE(o.net_price_current, t.lock_net_price) - t.lock_net_price <= -0.75 THEN 'itm_deep'
    WHEN COALESCE(o.net_price_current, t.lock_net_price) - t.lock_net_price <= -0.25 THEN 'itm'
    WHEN COALESCE(o.net_price_current, t.lock_net_price) - t.lock_net_price <=  0.25 THEN 'atm'
    WHEN COALESCE(o.net_price_current, t.lock_net_price) - t.lock_net_price <=  0.75 THEN 'otm'
    ELSE 'otm_deep'
  END AS rate_itm_bucket,
  t.funded_ind, t.resolve_type,
  t.original_upb * t.funded_ind AS funded_upb
FROM terminal t
LEFT JOIN last_open o ON o.lock_id = t.lock_id
WHERE t.resolve_ts >= ADD_MONTHS(current_timestamp(), -12);

CREATE OR REPLACE VIEW gold_pt_cell_raw AS
WITH base AS (SELECT * FROM gold_pt_resolved_locks),
leaf AS (
  SELECT 'leaf' AS level_name, last_open_status AS status, channel, purpose, product, rate_itm_bucket,
         COUNT(*) n_locks, SUM(original_upb) locked_upb,
         SUM(funded_ind) / NULLIF(COUNT(*), 0.0) AS pt_count,
         SUM(funded_upb) / NULLIF(SUM(original_upb), 0) AS pt_vol
  FROM base GROUP BY 2,3,4,5,6
),
no_itm AS (
  SELECT 'no_itm', last_open_status, channel, purpose, product, CAST(NULL AS STRING),
         COUNT(*), SUM(original_upb),
         SUM(funded_ind) / NULLIF(COUNT(*), 0.0),
         SUM(funded_upb) / NULLIF(SUM(original_upb), 0)
  FROM base GROUP BY 2,3,4,5
),
status_channel AS (
  SELECT 'status_channel', last_open_status, channel, CAST(NULL AS STRING), CAST(NULL AS STRING), CAST(NULL AS STRING),
         COUNT(*), SUM(original_upb),
         SUM(funded_ind) / NULLIF(COUNT(*), 0.0),
         SUM(funded_upb) / NULLIF(SUM(original_upb), 0)
  FROM base GROUP BY 2,3
),
status_only AS (
  SELECT 'status', last_open_status, CAST(NULL AS STRING), CAST(NULL AS STRING), CAST(NULL AS STRING), CAST(NULL AS STRING),
         COUNT(*), SUM(original_upb),
         SUM(funded_ind) / NULLIF(COUNT(*), 0.0),
         SUM(funded_upb) / NULLIF(SUM(original_upb), 0)
  FROM base GROUP BY 2
),
book AS (
  SELECT 'book', CAST(NULL AS STRING), CAST(NULL AS STRING), CAST(NULL AS STRING), CAST(NULL AS STRING), CAST(NULL AS STRING),
         COUNT(*), SUM(original_upb),
         SUM(funded_ind) / NULLIF(COUNT(*), 0.0),
         SUM(funded_upb) / NULLIF(SUM(original_upb), 0)
  FROM base
)
SELECT * FROM leaf
UNION ALL SELECT * FROM no_itm
UNION ALL SELECT * FROM status_channel
UNION ALL SELECT * FROM status_only
UNION ALL SELECT * FROM book;

CREATE OR REPLACE VIEW gold_pt_cell_shrunk AS
WITH k AS (SELECT 40.0 AS k_shrink, 0.05 AS pt_floor, 0.99 AS pt_ceil),
leaf AS (SELECT * FROM gold_pt_cell_raw WHERE level_name = 'leaf'),
parent AS (SELECT * FROM gold_pt_cell_raw WHERE level_name = 'no_itm'),
grand AS (SELECT * FROM gold_pt_cell_raw WHERE level_name = 'status_channel'),
g2 AS (SELECT * FROM gold_pt_cell_raw WHERE level_name = 'status'),
g3 AS (SELECT * FROM gold_pt_cell_raw WHERE level_name = 'book')
SELECT
  l.status, l.channel, l.purpose, l.product, l.rate_itm_bucket,
  l.n_locks, l.locked_upb, l.pt_vol AS pt_raw,
  COALESCE(p.pt_vol, g.pt_vol, g2.pt_vol, g3.pt_vol) AS pt_parent,
  COALESCE(p.n_locks, g.n_locks, g2.n_locks, g3.n_locks) AS n_parent,
  GREATEST((SELECT pt_floor FROM k), LEAST((SELECT pt_ceil FROM k),
    (l.n_locks * l.pt_vol + (SELECT k_shrink FROM k) * COALESCE(p.pt_vol, g.pt_vol, g2.pt_vol, g3.pt_vol))
    / (l.n_locks + (SELECT k_shrink FROM k))
  )) AS pt_shrunk
FROM leaf l
LEFT JOIN parent p ON p.status = l.status AND p.channel = l.channel AND p.purpose = l.purpose AND p.product = l.product
LEFT JOIN grand g ON g.status = l.status AND g.channel = l.channel
LEFT JOIN g2 ON g2.status = l.status
CROSS JOIN g3;

CREATE OR REPLACE TABLE ref_pullthrough_beta AS
WITH d AS (
  SELECT channel, price_move_pts, funded_ind, original_upb FROM gold_pt_resolved_locks
),
stats AS (
  SELECT channel, COUNT(*) n, AVG(price_move_pts) x_bar, AVG(funded_ind) y_bar,
         AVG(price_move_pts * funded_ind) xy_bar, AVG(price_move_pts * price_move_pts) x2_bar,
         SUM(original_upb) locked_upb
  FROM d GROUP BY channel
)
SELECT channel, n, locked_upb, y_bar AS pt_uncond, x_bar AS avg_price_move,
  CASE WHEN x2_bar - x_bar * x_bar < 1e-8 THEN 0
       ELSE (xy_bar - x_bar * y_bar) / (x2_bar - x_bar * x_bar) END AS pt_beta_per_point,
  current_date() AS as_of_date
FROM stats;

CREATE OR REPLACE TABLE ref_pullthrough_forecast AS
SELECT current_date() AS as_of_date, status, channel, purpose, product, rate_itm_bucket,
       n_locks, pt_raw, pt_parent, pt_shrunk AS pt_forecast, CAST(NULL AS DECIMAL(8,4)) AS eff_duration
FROM gold_pt_cell_shrunk
UNION ALL
SELECT current_date(), status, channel, purpose, product, CAST(NULL AS STRING),
       n_locks, pt_vol, pt_vol, pt_vol, CAST(NULL AS DECIMAL(8,4))
FROM gold_pt_cell_raw
WHERE level_name = 'no_itm';

CREATE OR REPLACE VIEW gold_lock_pt_live AS
WITH scored AS (
  SELECT a.lock_id, a.as_of_date, a.status_asof, a.channel, a.purpose, a.product, a.current_upb,
         COALESCE(a.net_price_current, a.lock_net_price) - a.lock_net_price AS price_move_pts,
         CASE
           WHEN COALESCE(a.net_price_current, a.lock_net_price) - a.lock_net_price <= -0.75 THEN 'itm_deep'
           WHEN COALESCE(a.net_price_current, a.lock_net_price) - a.lock_net_price <= -0.25 THEN 'itm'
           WHEN COALESCE(a.net_price_current, a.lock_net_price) - a.lock_net_price <=  0.25 THEN 'atm'
           WHEN COALESCE(a.net_price_current, a.lock_net_price) - a.lock_net_price <=  0.75 THEN 'otm'
           ELSE 'otm_deep'
         END AS rate_itm_bucket
  FROM gold_lock_asof a
),
joined AS (
  SELECT s.*,
    COALESCE(leaf.pt_forecast, parent.pt_forecast, 0.75) AS pt_forecast,
    COALESCE(leaf.n_locks, parent.n_locks, 0) AS pt_n,
    CASE WHEN leaf.pt_forecast IS NOT NULL THEN 'leaf'
         WHEN parent.pt_forecast IS NOT NULL THEN 'parent' ELSE 'default' END AS pt_source,
    b.pt_beta_per_point
  FROM scored s
  LEFT JOIN ref_pullthrough_forecast leaf
    ON leaf.as_of_date = (SELECT MAX(as_of_date) FROM ref_pullthrough_forecast)
   AND leaf.status = s.status_asof AND leaf.channel = s.channel
   AND leaf.purpose = s.purpose AND leaf.product = s.product
   AND leaf.rate_itm_bucket = s.rate_itm_bucket
  LEFT JOIN ref_pullthrough_forecast parent
    ON parent.as_of_date = (SELECT MAX(as_of_date) FROM ref_pullthrough_forecast)
   AND parent.status = s.status_asof AND parent.channel = s.channel
   AND parent.purpose = s.purpose AND parent.product = s.product
   AND parent.rate_itm_bucket IS NULL
  LEFT JOIN ref_pullthrough_beta b ON b.channel = s.channel
)
SELECT lock_id, as_of_date, status_asof, channel, purpose, product, rate_itm_bucket, price_move_pts,
       pt_source, pt_n,
       LEAST(0.99, GREATEST(0.05, pt_forecast)) AS pt_forecast,
       current_upb * LEAST(0.99, GREATEST(0.05, pt_forecast)) AS pt_weighted_upb
FROM joined;
