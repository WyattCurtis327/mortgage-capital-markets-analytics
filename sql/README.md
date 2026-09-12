# SQL pack

Deploy: `05` → `06` → `01`/`02` → nightly `04` → `03` → examples.

| File | What |
|---|---|
| [01_origination_kpis.sql](01_origination_kpis.sql) | Lock as-of, risk, position |
| [02_pullthrough_forecast.sql](02_pullthrough_forecast.sql) | Full PT grid |
| [03_pnl_attribution.sql](03_pnl_attribution.sql) | Full daily waterfall |
| [04_daily_merge_job.sql](04_daily_merge_job.sql) | MERGE contract + gates |
| [05_gold_star_ddl.sql](05_gold_star_ddl.sql) | Star DDL |
| [06_eligibility_note_structure.sql](06_eligibility_note_structure.sql) | LLPA + note structure |
| [07_reporting_examples.sql](07_reporting_examples.sql) | Desk queries against gold_cm |

Examples in `07`:
1. Morning sheet (coverage after SUM)
2. Coupon coverage drill
3. Open book by note × ITM
4. Attribution window
5. GOS by sale month × channel
6. Realized L2F
7. Default-PT leak
8. Lock eligibility vs current loan
9. Warehouse utilization
10. 15-min print vs SOD
