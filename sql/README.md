# SQL pack

Databricks SQL. Deploy in order.

| File | Session | What it writes |
|---|---|---|
| [01_origination_kpis.sql](01_origination_kpis.sql) | Foundation | Lock as-of, risk as-of, daily position view, vintage L2F, lock-desk leakage, HFS carry, best-ex capture, loan GOS, slippage waterfall |
| [02_pullthrough_forecast.sql](02_pullthrough_forecast.sql) | A | Resolved-lock training set, hierarchical PT cells, channel beta, `ref_pullthrough_forecast`, `gold_lock_pt_live` |
| [03_pnl_attribution.sql](03_pnl_attribution.sql) | B | Lock-level bridge, hedge P&L, `gold_pnl_attribution_daily` |
| [04_daily_merge_job.sql](04_daily_merge_job.sql) | C | DDL, date spine, MERGE `gold_lock_risk_daily`, position table, quality gates |

Assumed silver facts are listed at the top of `01_origination_kpis.sql` and in the root README.

Postgres: replace `QUALIFY` with a subquery + `WHERE rn = 1`, and `SUM() FILTER` with `SUM(CASE WHEN ...)`.
