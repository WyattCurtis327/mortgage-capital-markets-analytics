# SQL pack

Databricks SQL. Deploy A → B → C.

| File | Session | Status |
|---|---|---|
| [01_origination_kpis.sql](01_origination_kpis.sql) | Foundation | Object list + grain notes |
| [02_pullthrough_forecast.sql](02_pullthrough_forecast.sql) | A | Object list + model notes |
| [03_pnl_attribution.sql](03_pnl_attribution.sql) | B | **Full script on main** |
| [04_daily_merge_job.sql](04_daily_merge_job.sql) | C | Object list + MERGE / gate notes |

`03` is the complete attribution pack. `01`, `02`, and `04` on this branch describe the objects and grains; paste the matching full scripts from a local checkout of this pack if you need every view body in-repo in one commit.

Postgres: replace `QUALIFY` with a subquery + `WHERE rn = 1`, and `SUM() FILTER` with `SUM(CASE WHEN ...)`.
