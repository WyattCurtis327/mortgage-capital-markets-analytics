# SQL pack

Databricks SQL. Deploy A → B → C, then the star DDL.

| File | Session | On main |
|---|---|---|
| [01_origination_kpis.sql](01_origination_kpis.sql) | Foundation | Object list + grains |
| [02_pullthrough_forecast.sql](02_pullthrough_forecast.sql) | A | Object list + PT model notes |
| [03_pnl_attribution.sql](03_pnl_attribution.sql) | B | Full attribution script |
| [04_daily_merge_job.sql](04_daily_merge_job.sql) | C | MERGE / gate notes |
| [05_gold_star_ddl.sql](05_gold_star_ddl.sql) | Datamart | **Full star DDL** — dims, facts, seeds, compatibility views |

`05` creates `main.gold_cm` and `main.ref_cm`. Seed INSERTs for ITM, status, purpose, and channel are not idempotent — run once.

Compatibility views:
- `main.gold.gold_lock_risk_daily` → `fact_lock_snapshot_daily`
- `main.gold.gold_cm_daily_position_tbl` → date rollup of `fact_position_daily` with coverage recomputed after SUM
