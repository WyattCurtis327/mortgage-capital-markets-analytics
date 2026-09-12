-- =============================================================================
-- Gold star DDL — capital markets datamart
-- Dialect: Databricks SQL / Delta Lake
--   main.gold_cm   dimensions + facts
--   main.ref_cm    PT grid + policy (not dimensions)
-- Snapshot facts: SUM across keys on one date; last() across dates.
-- Coverage / offset: recompute after SUM.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS main.gold_cm
COMMENT 'Capital markets gold star — facts and conformed dimensions';

CREATE SCHEMA IF NOT EXISTS main.ref_cm
COMMENT 'Capital markets reference snapshots (PT grid, policy bands)';

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_date (
  date_key INT NOT NULL COMMENT 'yyyymmdd',
  calendar_date DATE NOT NULL,
  year INT NOT NULL,
  quarter INT NOT NULL,
  month INT NOT NULL,
  month_start DATE NOT NULL,
  week_start DATE NOT NULL,
  day_of_week INT NOT NULL COMMENT '1=Mon .. 7=Sun',
  is_business_day BOOLEAN NOT NULL,
  is_month_end BOOLEAN NOT NULL,
  biz_day_seq INT COMMENT 'monotonic business-day index for lag-1'
) USING DELTA
COMMENT 'Role-played as lock_date, fund_date, sale_date, as_of_date, print_date';

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_channel (
  channel_key INT NOT NULL,
  channel_code STRING NOT NULL COMMENT 'direct|retail|wholesale|correspondent|jv',
  channel_group STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_product (
  product_key INT NOT NULL,
  product_code STRING NOT NULL,
  agency_flag STRING COMMENT 'fnma|fhlmc|gnma|non_agency',
  term_months INT,
  government_flag BOOLEAN
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_purpose (
  purpose_key INT NOT NULL,
  purpose_code STRING NOT NULL COMMENT 'purchase|rate_term_refi|cashout',
  purpose_group STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_coupon_bucket (
  coupon_bucket_key INT NOT NULL,
  coupon_bucket_code STRING NOT NULL COMMENT 'e.g. UMBS_30_6.0',
  agency_family STRING,
  term_months INT,
  coupon DECIMAL(6,3),
  tba_product STRING
) USING DELTA
COMMENT 'Conformed join from locks to TBA marks and hedge lots';

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_itm_bucket (
  itm_bucket_key INT NOT NULL,
  itm_code STRING NOT NULL,
  price_move_low DECIMAL(8,4) NOT NULL,
  price_move_high DECIMAL(8,4) NOT NULL
) USING DELTA
COMMENT 'price_move = P_now - P_lock; positive = OTM for the borrower';

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_lock_status (
  status_key INT NOT NULL,
  status_code STRING NOT NULL,
  is_open BOOLEAN NOT NULL,
  is_hfs BOOLEAN NOT NULL,
  is_terminal BOOLEAN NOT NULL,
  status_sort INT NOT NULL
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_investor (
  investor_key INT NOT NULL,
  investor_code STRING NOT NULL,
  investor_type STRING COMMENT 'gse_cash|gse_mbs|ginnie|aggregator|private',
  servicing_released_default BOOLEAN
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_execution_route (
  route_key INT NOT NULL,
  route_code STRING NOT NULL,
  investor_key INT COMMENT 'FK dim_investor',
  delivery_type STRING COMMENT 'mandatory|best_efforts',
  servicing_choice STRING COMMENT 'released|retained'
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_warehouse (
  facility_key INT NOT NULL,
  facility_code STRING NOT NULL,
  lender_name STRING,
  advance_rate DECIMAL(8,4),
  index_name STRING COMMENT 'sofr|wsj_prime',
  spread_bps DECIMAL(8,2),
  effective_from DATE,
  effective_to DATE,
  is_current BOOLEAN
) USING DELTA
COMMENT 'Type 2 on advance rate / spread';

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_tba_contract (
  tba_contract_key INT NOT NULL,
  coupon_bucket_key INT COMMENT 'FK dim_coupon_bucket',
  settle_month STRING COMMENT 'YYYYMM',
  instrument STRING COMMENT 'tba|future|option'
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.gold_cm.dim_loan (
  loan_key BIGINT NOT NULL,
  loan_id STRING NOT NULL,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  occupancy STRING,
  fico_bucket STRING,
  ltv_bucket STRING,
  state STRING,
  effective_from DATE NOT NULL,
  effective_to DATE,
  is_current BOOLEAN NOT NULL
) USING DELTA
COMMENT 'Mini-dimension type 2. Prices and PT do not live here.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_lock_snapshot_daily (
  as_of_date DATE NOT NULL,
  lock_id STRING NOT NULL,
  loan_id STRING,
  channel_key INT COMMENT 'FK dim_channel',
  product_key INT COMMENT 'FK dim_product',
  purpose_key INT COMMENT 'FK dim_purpose',
  coupon_bucket_key INT COMMENT 'FK dim_coupon_bucket',
  status_key INT COMMENT 'FK dim_lock_status',
  itm_bucket_key INT COMMENT 'FK dim_itm_bucket',
  warehouse_key INT COMMENT 'FK dim_warehouse when funded',
  lock_net_price DECIMAL(12,6),
  borrower_buy_price DECIMAL(12,6),
  net_price_current DECIMAL(12,6),
  price_move_pts DECIMAL(12,6),
  locked_margin_pts DECIMAL(12,6),
  current_margin_pts DECIMAL(12,6),
  pt_forecast DECIMAL(8,6),
  pt_source STRING COMMENT 'leaf|parent|default',
  pt_n INT,
  loan_eff_duration DECIMAL(8,4),
  tba_price_pts DECIMAL(12,6),
  tba_eff_duration DECIMAL(8,4),
  current_upb DECIMAL(18,2),
  original_upb DECIMAL(18,2),
  pt_weighted_upb DECIMAL(18,2),
  expected_lock_margin_usd DECIMAL(18,2),
  pipeline_mtm_usd DECIMAL(18,2),
  pipeline_dv01_usd DECIMAL(18,2),
  econ_usd DECIMAL(18,2),
  is_funded BOOLEAN,
  is_fallout BOOLEAN,
  is_terminal BOOLEAN,
  pt_grid_as_of_date DATE,
  snapshot_ts TIMESTAMP
) USING DELTA
PARTITIONED BY (as_of_date)
COMMENT 'Grain: lock_id x as_of_date. Semi-additive. Open locks + HFS only.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_lock_now (
  lock_id STRING NOT NULL,
  loan_id STRING,
  as_of_ts TIMESTAMP NOT NULL,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  coupon_bucket_key INT,
  status_key INT,
  itm_bucket_key INT,
  current_upb DECIMAL(18,2),
  pt_forecast DECIMAL(8,6),
  pt_weighted_upb DECIMAL(18,2),
  net_price_current DECIMAL(12,6),
  borrower_buy_price DECIMAL(12,6),
  econ_usd DECIMAL(18,2),
  pipeline_dv01_usd DECIMAL(18,2),
  is_funded BOOLEAN
) USING DELTA
COMMENT 'Type-1 current book for the 15-minute agent. Not historical.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_lock_event (
  event_id STRING NOT NULL,
  event_ts TIMESTAMP NOT NULL,
  event_date DATE NOT NULL,
  lock_id STRING NOT NULL,
  loan_id STRING,
  event_type STRING NOT NULL COMMENT 'lock|extend|renegotiate|fallout|fallin|fund|sale',
  channel_key INT,
  product_key INT,
  purpose_key INT,
  coupon_bucket_key INT,
  status_key INT,
  upb DECIMAL(18,2),
  price_before DECIMAL(12,6),
  price_after DECIMAL(12,6),
  fee_charged_usd DECIMAL(18,2),
  fee_policy_usd DECIMAL(18,2),
  renego_cost_usd DECIMAL(18,2),
  extension_giveaway_usd DECIMAL(18,2),
  late_arrival_ind BOOLEAN
) USING DELTA
PARTITIONED BY (event_date)
COMMENT 'Grain: one lock-desk or lifecycle event. Fully additive.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_position_daily (
  as_of_date DATE NOT NULL,
  coupon_bucket_key INT NOT NULL,
  locked_upb_gross DECIMAL(18,2),
  locked_ptwlv DECIMAL(18,2),
  hfs_upb DECIMAL(18,2),
  hedgeable_upb DECIMAL(18,2),
  wavg_locked_margin_pts DECIMAL(12,6),
  expected_lock_margin_usd DECIMAL(18,2),
  pipeline_mtm_usd DECIMAL(18,2),
  pipeline_dv01_usd DECIMAL(18,2),
  tba_short_upb DECIMAL(18,2),
  hedge_mtm_usd DECIMAL(18,2),
  hedge_dv01_usd DECIMAL(18,2),
  net_mtm_usd DECIMAL(18,2),
  snapshot_ts TIMESTAMP
) USING DELTA
PARTITIONED BY (as_of_date)
COMMENT 'Grain: as_of_date x coupon. Recompute coverage after SUM across coupons.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_position_15m (
  print_ts TIMESTAMP NOT NULL,
  print_date DATE NOT NULL,
  coupon_bucket_key INT NOT NULL,
  locked_upb_gross DECIMAL(18,2),
  locked_ptwlv DECIMAL(18,2),
  hfs_upb DECIMAL(18,2),
  pipeline_mtm_usd DECIMAL(18,2),
  pipeline_dv01_usd DECIMAL(18,2),
  tba_short_upb DECIMAL(18,2),
  hedge_mtm_usd DECIMAL(18,2),
  hedge_dv01_usd DECIMAL(18,2),
  net_mtm_usd DECIMAL(18,2)
) USING DELTA
PARTITIONED BY (print_date)
COMMENT 'Grain: print_ts x coupon. Agent Watcher source.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_hedge_snapshot_daily (
  as_of_date DATE NOT NULL,
  trade_id STRING NOT NULL,
  tba_contract_key INT,
  coupon_bucket_key INT NOT NULL,
  side STRING COMMENT 'SELL|BUY',
  notional DECIMAL(18,2),
  trade_price_pts DECIMAL(12,6),
  mark_price_pts DECIMAL(12,6),
  mtm_usd DECIMAL(18,2),
  dv01_usd DECIMAL(18,2),
  is_open BOOLEAN
) USING DELTA
PARTITIONED BY (as_of_date)
COMMENT 'Grain: open TBA lot x date.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_hedge_trade (
  trade_id STRING NOT NULL,
  trade_ts TIMESTAMP NOT NULL,
  trade_date DATE NOT NULL,
  coupon_bucket_key INT NOT NULL,
  tba_contract_key INT,
  side STRING NOT NULL,
  notional DECIMAL(18,2) NOT NULL,
  price_pts DECIMAL(12,6),
  pairoff_ts TIMESTAMP,
  pairoff_price_pts DECIMAL(12,6),
  realized_pairoff_usd DECIMAL(18,2)
) USING DELTA
PARTITIONED BY (trade_date)
COMMENT 'Grain: one blotter fill. Pair-off cash is additive.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_tba_mark (
  as_of_date DATE NOT NULL,
  print_ts TIMESTAMP,
  coupon_bucket_key INT NOT NULL,
  tba_price_pts DECIMAL(12,6) NOT NULL,
  tba_eff_duration DECIMAL(8,4),
  settle_month STRING,
  source STRING
) USING DELTA
PARTITIONED BY (as_of_date)
COMMENT 'Grain: date (or print) x coupon.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_warehouse_balance_daily (
  as_of_date DATE NOT NULL,
  facility_key INT NOT NULL,
  committed_capacity DECIMAL(18,2),
  outstanding DECIMAL(18,2),
  available DECIMAL(18,2),
  aging_30plus_upb DECIMAL(18,2)
) USING DELTA
PARTITIONED BY (as_of_date)
COMMENT 'Grain: facility x date. Semi-additive balances.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_warehouse_draw (
  draw_id STRING NOT NULL,
  loan_id STRING NOT NULL,
  facility_key INT NOT NULL,
  channel_key INT,
  product_key INT,
  fund_date DATE NOT NULL,
  repay_date DATE,
  draw_upb DECIMAL(18,2),
  warehouse_rate DECIMAL(8,6),
  interest_accrued_usd DECIMAL(18,2),
  days_on_line INT
) USING DELTA
COMMENT 'Grain: one draw.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_loan_fund (
  loan_id STRING NOT NULL,
  lock_id STRING,
  fund_date DATE NOT NULL,
  lock_date DATE,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  coupon_bucket_key INT,
  facility_key INT,
  funded_upb DECIMAL(18,2),
  note_rate DECIMAL(8,5),
  lock_net_price DECIMAL(12,6),
  borrower_buy_price DECIMAL(12,6)
) USING DELTA
PARTITIONED BY (fund_date)
COMMENT 'Grain: one funded loan.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_loan_sale (
  sale_id STRING NOT NULL,
  loan_id STRING NOT NULL,
  sale_date DATE NOT NULL,
  fund_date DATE,
  lock_date DATE,
  investor_key INT,
  route_key INT,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  coupon_bucket_key INT,
  sold_upb DECIMAL(18,2),
  sale_price_pts DECIMAL(12,6),
  srp_pts DECIMAL(12,6),
  llpa_pts DECIMAL(12,6),
  gfee_pts DECIMAL(12,6),
  file_fee_usd DECIMAL(18,2),
  msr_fv_pts DECIMAL(12,6),
  servicing_retained BOOLEAN,
  pairoff_pnl_usd DECIMAL(18,2)
) USING DELTA
PARTITIONED BY (sale_date)
COMMENT 'Grain: one investor purchase.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_gos (
  loan_id STRING NOT NULL,
  sale_date DATE NOT NULL,
  lock_date DATE,
  channel_key INT,
  product_key INT,
  purpose_key INT,
  coupon_bucket_key INT,
  investor_key INT,
  route_key INT,
  facility_key INT,
  sold_upb DECIMAL(18,2),
  locked_margin_pts DECIMAL(12,6),
  warehouse_carry_pts DECIMAL(12,6),
  nim_pts DECIMAL(12,6),
  planned_lo_comp_pts DECIMAL(12,6),
  planned_orig_cost_pts DECIMAL(12,6),
  realized_gos_usd DECIMAL(18,2),
  realized_gos_pts DECIMAL(12,6),
  gos_slippage_pts DECIMAL(12,6)
) USING DELTA
PARTITIONED BY (sale_date)
COMMENT 'Grain: one sold loan. Finance scoreboard.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_best_ex_quote (
  loan_id STRING NOT NULL,
  quote_ts TIMESTAMP NOT NULL,
  quote_date DATE NOT NULL,
  route_key INT NOT NULL,
  channel_key INT,
  product_key INT,
  coupon_bucket_key INT,
  net_price_pts DECIMAL(12,6),
  includes_msr BOOLEAN
) USING DELTA
PARTITIONED BY (quote_date)
COMMENT 'Grain: loan x route x quote_ts.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_attribution_daily (
  as_of_date DATE NOT NULL,
  channel_key INT NOT NULL,
  econ_sod DECIMAL(18,2),
  econ_eod DECIMAL(18,2),
  d_econ DECIMAL(18,2),
  pnl_new_locks DECIMAL(18,2),
  pnl_fallout DECIMAL(18,2),
  pnl_fund_pt_stepup DECIMAL(18,2),
  pnl_market DECIMAL(18,2),
  pnl_pt_revision DECIMAL(18,2),
  pnl_renego DECIMAL(18,2),
  pnl_upb_change DECIMAL(18,2),
  pnl_residual DECIMAL(18,2)
) USING DELTA
PARTITIONED BY (as_of_date)
COMMENT 'Grain: date x channel. Hedge lives on fact_position_daily.';

CREATE TABLE IF NOT EXISTS main.gold_cm.fact_vintage_l2f (
  lock_month DATE NOT NULL,
  channel_key INT NOT NULL,
  product_key INT NOT NULL,
  purpose_key INT NOT NULL,
  lock_count BIGINT,
  locked_upb DECIMAL(18,2),
  funded_count BIGINT,
  funded_upb DECIMAL(18,2),
  pt_count DECIMAL(12,6),
  pt_vol DECIMAL(12,6),
  wavg_locked_margin_pts DECIMAL(12,6),
  avg_lock_to_fund_days DECIMAL(12,4)
) USING DELTA
COMMENT 'Grain: lock month x channel x product x purpose.';

CREATE TABLE IF NOT EXISTS main.ref_cm.ref_pullthrough_forecast (
  as_of_date DATE NOT NULL,
  status_code STRING NOT NULL,
  channel_code STRING NOT NULL,
  purpose_code STRING NOT NULL,
  product_code STRING NOT NULL,
  itm_code STRING,
  n_locks BIGINT,
  pt_raw DECIMAL(8,6),
  pt_parent DECIMAL(8,6),
  pt_forecast DECIMAL(8,6) NOT NULL,
  eff_duration DECIMAL(8,4)
) USING DELTA
PARTITIONED BY (as_of_date);

CREATE TABLE IF NOT EXISTS main.ref_cm.ref_pullthrough_beta (
  as_of_date DATE NOT NULL,
  channel_code STRING NOT NULL,
  n BIGINT,
  locked_upb DECIMAL(18,2),
  pt_uncond DECIMAL(8,6),
  avg_price_move DECIMAL(12,6),
  pt_beta_per_point DECIMAL(12,6)
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.ref_cm.ref_policy (
  policy_as_of DATE NOT NULL,
  coverage_band_low DECIMAL(8,4),
  coverage_band_high DECIMAL(8,4),
  max_net_dv01_pct DECIMAL(8,4),
  max_ticket_notional DECIMAL(18,2)
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.ref_cm.ref_duration_by_product (
  product_code STRING NOT NULL,
  coupon_bucket_code STRING NOT NULL,
  eff_duration DECIMAL(8,4) NOT NULL
) USING DELTA;

INSERT INTO main.gold_cm.dim_itm_bucket VALUES
  (1, 'itm_deep', -99.0000, -0.7500),
  (2, 'itm', -0.7500, -0.2500),
  (3, 'atm', -0.2500, 0.2500),
  (4, 'otm', 0.2500, 0.7500),
  (5, 'otm_deep', 0.7500, 99.0000);

INSERT INTO main.gold_cm.dim_lock_status VALUES
  (1, 'locked', TRUE, FALSE, FALSE, 10),
  (2, 'approved', TRUE, FALSE, FALSE, 20),
  (3, 'ctc', TRUE, FALSE, FALSE, 30),
  (4, 'scheduled', TRUE, FALSE, FALSE, 40),
  (5, 'funded', FALSE, TRUE, FALSE, 50),
  (6, 'fallen_out', FALSE, FALSE, TRUE, 80),
  (7, 'expired', FALSE, FALSE, TRUE, 85),
  (8, 'sold', FALSE, FALSE, TRUE, 90);

INSERT INTO main.gold_cm.dim_purpose VALUES
  (1, 'purchase', 'purchase'),
  (2, 'rate_term_refi', 'refi'),
  (3, 'cashout', 'refi');

INSERT INTO main.gold_cm.dim_channel VALUES
  (1, 'direct', 'retail'),
  (2, 'retail', 'retail'),
  (3, 'wholesale', 'third_party'),
  (4, 'correspondent', 'third_party'),
  (5, 'jv', 'partner');

CREATE OR REPLACE VIEW main.gold.gold_lock_risk_daily AS
SELECT * FROM main.gold_cm.fact_lock_snapshot_daily;

CREATE OR REPLACE VIEW main.gold.gold_cm_daily_position_tbl AS
SELECT
  as_of_date,
  SUM(locked_upb_gross) AS locked_upb_gross,
  SUM(locked_ptwlv) AS locked_ptwlv,
  SUM(hfs_upb) AS hfs_upb,
  SUM(hedgeable_upb) AS hedgeable_upb,
  SUM(pipeline_mtm_usd) AS pipeline_mtm_usd,
  SUM(pipeline_dv01_usd) AS pipeline_dv01_usd,
  SUM(tba_short_upb) AS tba_short_upb,
  SUM(hedge_mtm_usd) AS hedge_mtm_usd,
  SUM(hedge_dv01_usd) AS hedge_dv01_usd,
  SUM(net_mtm_usd) AS net_mtm_usd,
  SUM(tba_short_upb) / NULLIF(SUM(locked_ptwlv + hfs_upb), 0) AS pt_coverage,
  SUM(hedge_dv01_usd) / NULLIF(SUM(pipeline_dv01_usd), 0) AS duration_coverage,
  (SUM(pipeline_dv01_usd) - SUM(COALESCE(hedge_dv01_usd, 0)))
    / NULLIF(SUM(pipeline_dv01_usd), 0) AS net_dv01_pct,
  MAX(snapshot_ts) AS snapshot_ts
FROM main.gold_cm.fact_position_daily
GROUP BY as_of_date;
