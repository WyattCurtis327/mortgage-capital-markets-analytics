# SQL pack

Databricks SQL. Deploy in order: `01` → `02` → `05` → `06` → `03` (needs daily snapshot) → `04` job.

| File | On main |
|---|---|
| [01_origination_kpis.sql](01_origination_kpis.sql) | `gold_lock_asof`, `gold_lock_risk_asof`, `gold_cm_daily_position` |
| [02_pullthrough_forecast.sql](02_pullthrough_forecast.sql) | **Full** PT grid: resolved locks, shrinkage, beta, live join |
| [03_pnl_attribution.sql](03_pnl_attribution.sql) | **Full** daily P&L waterfall |
| [04_daily_merge_job.sql](04_daily_merge_job.sql) | DDL + MERGE contract + gates (stage SQL in local pack) |
| [05_gold_star_ddl.sql](05_gold_star_ddl.sql) | **Full** star DDL |
| [06_eligibility_note_structure.sql](06_eligibility_note_structure.sql) | **Full** LLPA + note-structure extension |

Glossary: [docs/glossary.md](../docs/glossary.md) and the long form in the [root README](../README.md#glossary).
Agent: [docs/agent-15min.md](../docs/agent-15min.md).
