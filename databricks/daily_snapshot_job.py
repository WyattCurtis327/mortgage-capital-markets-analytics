# Databricks notebook source
# MAGIC %md
# MAGIC # Capital markets daily snapshot
# MAGIC
# MAGIC Workflow: widgets → PT grid rebuild → MERGE snapshot (SQL task) → gates → morning print.
# MAGIC Run cap_markets_pullthrough_forecast.sql once before this job so gold_pt_cell_shrunk exists.

# COMMAND ----------

dbutils.widgets.text("as_of_date", "", "as_of_date YYYY-MM-DD (blank = today)")
dbutils.widgets.text("restate_days", "5", "restate_days")
dbutils.widgets.text("catalog", "main", "catalog")
dbutils.widgets.text("schema", "gold", "schema")

# COMMAND ----------

from datetime import date, timedelta
from pyspark.sql import functions as F

as_of_raw = dbutils.widgets.get("as_of_date").strip()
as_of = date.fromisoformat(as_of_raw) if as_of_raw else date.today()
restate_days = int(dbutils.widgets.get("restate_days"))
catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")
restate_from = as_of - timedelta(days=restate_days)
run_id = spark.sql("SELECT uuid() AS id").collect()[0]["id"]

spark.sql(f"USE CATALOG {catalog}")
spark.sql(f"USE SCHEMA {schema}")

spark.sql(f"""
CREATE OR REPLACE TEMP VIEW job_params AS
SELECT
  DATE('{as_of}')            AS as_of_date,
  DATE('{restate_from}')     AS restate_from,
  {restate_days}             AS restate_days,
  '{run_id}'                 AS run_id,
  current_timestamp()        AS run_ts
""")

spark.sql(f"""
CREATE OR REPLACE TEMP VIEW date_spine AS
SELECT explode(sequence(DATE('{restate_from}'), DATE('{as_of}'), INTERVAL 1 DAY)) AS as_of_date
""")

print(f"run_id={run_id} as_of={as_of} restate_from={restate_from}")

# COMMAND ----------

pt_exists = spark.catalog.tableExists(f"{catalog}.{schema}.gold_pt_cell_shrunk") or \
            spark.sql("SHOW VIEWS").filter(F.col("viewName") == "gold_pt_cell_shrunk").count() > 0

if not pt_exists:
    raise Exception(
        "gold_pt_cell_shrunk missing. Run sql/02_pullthrough_forecast.sql once before this job."
    )

spark.sql("""
CREATE OR REPLACE TABLE ref_pullthrough_forecast AS
SELECT
  current_date() AS as_of_date,
  status, channel, purpose, product, rate_itm_bucket,
  n_locks, pt_raw, pt_parent, pt_shrunk AS pt_forecast,
  CAST(NULL AS DECIMAL(8,4)) AS eff_duration
FROM gold_pt_cell_shrunk
UNION ALL
SELECT
  current_date(),
  status, channel, purpose, product,
  CAST(NULL AS STRING) AS rate_itm_bucket,
  n_locks, pt_vol, pt_vol, pt_vol,
  CAST(NULL AS DECIMAL(8,4))
FROM gold_pt_cell_raw
WHERE level_name = 'no_itm'
""")

spark.sql("""
CREATE OR REPLACE TABLE ref_pullthrough_beta AS
WITH d AS (
  SELECT channel, price_move_pts, funded_ind, original_upb
  FROM gold_pt_resolved_locks
),
stats AS (
  SELECT
    channel,
    COUNT(*) n,
    AVG(price_move_pts) x_bar,
    AVG(funded_ind) y_bar,
    AVG(price_move_pts * funded_ind) xy_bar,
    AVG(price_move_pts * price_move_pts) x2_bar,
    SUM(original_upb) locked_upb
  FROM d
  GROUP BY channel
)
SELECT
  channel, n, locked_upb,
  y_bar AS pt_uncond,
  x_bar AS avg_price_move,
  CASE WHEN x2_bar - x_bar * x_bar < 1e-8 THEN 0
       ELSE (xy_bar - x_bar * y_bar) / (x2_bar - x_bar * x_bar)
  END AS pt_beta_per_point,
  current_date() AS as_of_date
FROM stats
""")

print("PT grid rows=", spark.table("ref_pullthrough_forecast").count())
print("Run sql/04_daily_merge_job.sql as the next workflow task.")

# COMMAND ----------

gates = spark.sql("""
SELECT step, status, notes
FROM gold_cm_job_audit
WHERE run_id = (SELECT MAX(run_id) FROM gold_cm_job_audit)
  AND step LIKE 'gate_%'
""")
gates.show(truncate=False)

fails = [r for r in gates.collect() if r["status"] == "FAIL"]
warns = [r for r in gates.collect() if r["status"] == "WARN"]
for w in warns:
    print(f"WARN {w['step']}: {w['notes']}")
if fails:
    msg = "; ".join(f"{r['step']} {r['notes']}" for r in fails)
    raise Exception(f"CM snapshot gates failed: {msg}")
print("All FAIL-level gates passed.")
