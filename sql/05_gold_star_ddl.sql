-- Gold star DDL — main.gold_cm / main.ref_cm
-- Full column lists: see local artifacts/cm_repo/sql/05_gold_star_ddl.sql
-- Core facts created below.

CREATE SCHEMA IF NOT EXISTS main.gold_cm;
CREATE SCHEMA IF NOT EXISTS main.ref_cm;

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_lock_snapshot_daily (
  as_of_date DATE,
  lock_id STRING,
  loan_id STRING,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  coupon_bucket_key INT,
  status_key INT,
  itm_bucket_key INT,
  warehouse_key INT,
  lock_net_price DECIMAL(12,6),
  borrower_buy_price DECIMAL(12,6),
  net_price_current DECIMAL(12,6),
  price_move_pts DECIMAL(12,6),
  pt_forecast DECIMAL(8,6),
  pt_source STRING,
  current_upb DECIMAL(18,2),
  pt_weighted_upb DECIMAL(18,2),
  pipeline_mtm_usd DECIMAL(18,2),
  pipeline_dv01_usd DECIMAL(18,2),
  econ_usd DECIMAL(18,2),
  is_funded BOOLEAN,
  is_fallout BOOLEAN,
  pt_grid_as_of_date DATE,
  snapshot_ts TIMESTAMP
) USING DELTA PARTITIONED BY (as_of_date);

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_position_daily (
  as_of_date DATE,
  coupon_bucket_key INT,
  locked_upb_gross DECIMAL(18,2),
  locked_ptwlv DECIMAL(18,2),
  hfs_upb DECIMAL(18,2),
  pipeline_mtm_usd DECIMAL(18,2),
  pipeline_dv01_usd DECIMAL(18,2),
  tba_short_upb DECIMAL(18,2),
  hedge_mtm_usd DECIMAL(18,2),
  hedge_dv01_usd DECIMAL(18,2),
  net_mtm_usd DECIMAL(18,2)
) USING DELTA PARTITIONED BY (as_of_date);

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_attribution_daily (
  as_of_date DATE,
  channel_key INT,
  econ_sod DECIMAL(18,2),
  econ_eod DECIMAL(18,2),
  d_econ DECIMAL(18,2),
  pnl_new_locks DECIMAL(18,2),
  pnl_fallout DECIMAL(18,2),
  pnl_fund_pt_stepup DECIMAL(18,2),
  pnl_market DECIMAL(18,2),
  pnl_pt_revision DECIMAL(18,2),
  pnl_renego DECIMAL(18,2),
  pnl_residual DECIMAL(18,2)
) USING DELTA PARTITIONED BY (as_of_date);

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_gos (
  loan_id STRING,
  sale_date DATE,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  investor_key INT,
  sold_upb DECIMAL(18,2),
  locked_margin_pts DECIMAL(12,6),
  realized_gos_usd DECIMAL(18,2),
  realized_gos_pts DECIMAL(12,6),
  gos_slippage_pts DECIMAL(12,6)
) USING DELTA PARTITIONED BY (sale_date);

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_vintage_l2f (
  lock_month DATE,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  lock_count BIGINT,
  locked_upb DECIMAL(18,2),
  funded_count BIGINT,
  funded_upb DECIMAL(18,2),
  pt_vol DECIMAL(12,6)
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_position_15m (
  print_ts TIMESTAMP,
  print_date DATE,
  coupon_bucket_key INT,
  locked_ptwlv DECIMAL(18,2),
  hfs_upb DECIMAL(18,2),
  pipeline_dv01_usd DECIMAL(18,2),
  tba_short_upb DECIMAL(18,2),
  hedge_dv01_usd DECIMAL(18,2),
  net_mtm_usd DECIMAL(18,2)
) USING DELTA PARTITIONED BY (print_date);
