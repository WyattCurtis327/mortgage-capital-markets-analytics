# SQL pack

Databricks SQL. Deploy in order.

| File | What |
|---|---|
| [01_origination_kpis.sql](01_origination_kpis.sql) | Foundation gold views (object list on main) |
| [02_pullthrough_forecast.sql](02_pullthrough_forecast.sql) | PT grid + beta (object list on main) |
| [03_pnl_attribution.sql](03_pnl_attribution.sql) | Full daily P&L attribution |
| [04_daily_merge_job.sql](04_daily_merge_job.sql) | Incremental MERGE notes |
| [05_gold_star_ddl.sql](05_gold_star_ddl.sql) | Full star DDL — dims, facts, seeds, compat views |
| [06_eligibility_note_structure.sql](06_eligibility_note_structure.sql) | LLPA eligibility fact + ARM/IO/buydown note structure |

Run `05` once, then `06`. `06` is additive (`ALTER` + new dims/facts). Occupancy, property type, and note-structure seeds use `MERGE` and are rerunnable.

New objects in `06`:
- `dim_note_structure`, `dim_property_type`, `dim_occupancy`
- `fact_loan_eligibility` (loan × lock/fund/sale)
- columns on snapshot, fund, GOS, sale
- views `v_lock_eligibility`, `v_lock_snapshot_with_note`
