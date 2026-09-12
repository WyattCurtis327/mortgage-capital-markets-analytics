-- =============================================================================
-- C) Incremental daily snapshot + PT rebuild
-- Dialect: Databricks SQL
-- Params: as_of_date default current_date(), restate_days default 5
-- Spine dates are restated. Older partitions stay FROZEN including that day's PT.
-- =============================================================================

CREATE TABLE IF NOT EXISTS gold_lock_risk_daily (
  as_of_date DATE, lock_id STRING, loan_id STRING,
  channel STRING, product STRING, purpose STRING, coupon_bucket STRING,
  status_asof STRING, is_funded BOOLEAN, is_fallout BOOLEAN, is_terminal BOOLEAN,
  current_upb DECIMAL(18,2), original_upb DECIMAL(18,2),
  lock_net_price DECIMAL(12,6), borrower_buy_price DECIMAL(12,6),
  net_price_current DECIMAL(12,6), price_move_pts DECIMAL(12,6),
  rate_itm_bucket STRING, pt_forecast DECIMAL(8,6), pt_source STRING, pt_n INT,
  loan_eff_duration DECIMAL(8,4), tba_price_pts DECIMAL(12,6), tba_eff_duration DECIMAL(8,4),
  pt_weighted_upb DECIMAL(18,2), locked_margin_pts DECIMAL(12,6),
  pipeline_mtm_usd DECIMAL(18,2), pipeline_dv01_usd DECIMAL(18,2), econ_usd DECIMAL(18,2),
  snapshot_ts TIMESTAMP
) USING DELTA PARTITIONED BY (as_of_date);

CREATE TABLE IF NOT EXISTS gold_cm_daily_position_tbl (
  as_of_date DATE,
  locked_upb_gross DECIMAL(18,2), locked_ptwlv DECIMAL(18,2), hfs_upb DECIMAL(18,2),
  pipeline_mtm_usd DECIMAL(18,2), pipeline_dv01_usd DECIMAL(18,2),
  tba_short_upb DECIMAL(18,2), hedge_mtm_usd DECIMAL(18,2), hedge_dv01_usd DECIMAL(18,2),
  net_mtm_usd DECIMAL(18,2), pt_coverage DECIMAL(12,6), duration_coverage DECIMAL(12,6),
  net_dv01_pct DECIMAL(12,6), snapshot_ts TIMESTAMP
) USING DELTA PARTITIONED BY (as_of_date);

CREATE TABLE IF NOT EXISTS gold_cm_job_audit (
  run_id STRING, as_of_date DATE, restate_from DATE, step STRING, status STRING,
  row_count BIGINT, notes STRING, ts TIMESTAMP
) USING DELTA;

-- Bind as_of_date / restate_days via widgets or DECLARE in the job.
-- CREATE TEMP VIEW date_spine AS SELECT explode(sequence(restate_from, as_of_date, INTERVAL 1 DAY)) as_of_date;
-- Stage stg_lock_risk for every spine date (latest status < date+1 day, drop sold/fallout).
-- Then:

-- MERGE INTO gold_lock_risk_daily t
-- USING stg_lock_risk s
-- ON t.lock_id = s.lock_id AND t.as_of_date = s.as_of_date
-- WHEN MATCHED THEN UPDATE SET *
-- WHEN NOT MATCHED THEN INSERT *
-- WHEN NOT MATCHED BY SOURCE AND t.as_of_date IN (SELECT as_of_date FROM date_spine)
-- THEN DELETE;

-- DELETE FROM gold_cm_daily_position_tbl WHERE as_of_date IN (SELECT as_of_date FROM date_spine);
-- INSERT INTO gold_cm_daily_position_tbl SELECT ... from snapshot + open TBA lots;

-- Gates (FAIL unless WARN):
--   lock row_count > 0
--   default PT share < 0.20
--   no current_upb <= 0, pt outside [0.05, 1]
--   PTWLV shock vs yesterday < 0.35
--   PT coverage 0.70-1.20 is WARN only

-- Backfill: loop as_of_date with restate_days = 0.
-- Do not restatement-rebuild 90 days with tonight's PT model.
-- Full stage + MERGE body: artifacts/cm_repo/sql/04_daily_merge_job.sql local pack
-- and cap_markets_daily_merge_job.sql (same logic, longer comments).
