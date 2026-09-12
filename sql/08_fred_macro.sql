-- FRED macro layer. Databricks SQL.
-- ref_fred_series, ref_fred_observation (as printed),
-- ref_fred_daily (calendar daily, linear fill on gaps),
-- v_fred_desk_daily (wide + pmms30_minus_dgs10).
-- Do not extrapolate past last print. is_interpolated flags invented points.
-- Full MERGE seed + rebuild: working copy sql/08_fred_macro.sql

CREATE TABLE IF NOT EXISTS main.ref_cm.ref_fred_series (
  series_id STRING NOT NULL,
  title STRING,
  native_frequency STRING NOT NULL COMMENT 'd|w|m|q',
  units STRING,
  interpolate_daily BOOLEAN NOT NULL,
  desk_role STRING
) USING DELTA;

CREATE TABLE IF NOT EXISTS main.ref_cm.ref_fred_observation (
  series_id STRING NOT NULL,
  obs_date DATE NOT NULL,
  value DOUBLE,
  is_missing BOOLEAN NOT NULL,
  pulled_ts TIMESTAMP NOT NULL
) USING DELTA PARTITIONED BY (series_id);

CREATE TABLE IF NOT EXISTS main.ref_cm.ref_fred_daily (
  series_id STRING NOT NULL,
  calendar_date DATE NOT NULL,
  value DOUBLE,
  is_observed BOOLEAN NOT NULL,
  is_interpolated BOOLEAN NOT NULL,
  prev_obs_date DATE,
  next_obs_date DATE,
  native_frequency STRING
) USING DELTA PARTITIONED BY (series_id);

-- Linear rebuild (same logic in databricks/fred_pull.py):
-- value = prev + (next-prev) * datediff(d,prev) / datediff(next,prev)
-- when prev_date = next_date => observed print.

CREATE OR REPLACE VIEW main.ref_cm.v_fred_desk_daily AS
SELECT calendar_date,
  MAX(CASE WHEN series_id = 'DGS10' THEN value END) AS dgs10,
  MAX(CASE WHEN series_id = 'SOFR' THEN value END) AS sofr,
  MAX(CASE WHEN series_id = 'MORTGAGE30US' THEN value END) AS pmms_30,
  MAX(CASE WHEN series_id = 'MORTGAGE30US' THEN value END)
    - MAX(CASE WHEN series_id = 'DGS10' THEN value END) AS pmms30_minus_dgs10
FROM main.ref_cm.ref_fred_daily
GROUP BY calendar_date;
