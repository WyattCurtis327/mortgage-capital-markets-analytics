# Databricks notebook: pull FRED → ref_fred_observation → rebuild ref_fred_daily.
# Secret: FRED_API_KEY (scope cm) or env FRED_API_KEY.
# Series list comes from ref_fred_series (seed in sql/08_fred_macro.sql).
# Interpolation: linear between neighboring prints. No extrapolation.
# See working copy databricks/fred_pull.py for the full MERGE + QUALIFY rebuild.

# Requires: run sql/08_fred_macro.sql first (tables + series seed).
print("Load FRED_API_KEY, GET /fred/series/observations for each series_id,")
print("MERGE ref_fred_observation on (series_id, obs_date),")
print("then INSERT OVERWRITE ref_fred_daily with linear interpolation.")
