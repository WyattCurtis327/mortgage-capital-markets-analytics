# Gold star schema — capital markets datamart

Dimensional model for cap-markets reporting on an originate-to-sell mortgage book. Supports the daily desk and the 15-minute agent without mixing grains.

Price convention: **points** (`100` = par).

Full design notes, bus matrix, additivity rules, query patterns, and load sequence: see this file in the repo. DDL: `sql/05_gold_star_ddl.sql`.

## Rules

1. One grain per fact.
2. Conformed dimensions (date, channel, product, purpose, coupon, investor, warehouse, status, ITM).
3. Semi-additive measures: SUM across locks/coupons on one date; never SUM across dates.
4. Snapshots freeze the PT used that day.
5. Hedge P&L at book or coupon grain, not forced onto every lock.
6. `*_now` tables serve the agent; history lives in snapshot facts.

## Facts (grain)

| Fact | Grain |
|---|---|
| fact_lock_snapshot_daily | lock × date |
| fact_lock_event | one event |
| fact_position_daily | date × coupon |
| fact_hedge_snapshot_daily | lot × date |
| fact_hedge_trade | one fill |
| fact_tba_mark | date × coupon |
| fact_warehouse_balance_daily | facility × date |
| fact_warehouse_draw | one draw |
| fact_loan_fund | funded loan |
| fact_loan_sale | sold loan |
| fact_gos | sold loan economics |
| fact_best_ex_quote | loan × route × ts |
| fact_attribution_daily | date × channel |
| fact_vintage_l2f | lock month × channel × product × purpose |
| fact_position_15m | print × coupon |

`fact_lock_snapshot_daily` is the rename of `gold_lock_risk_daily`.

## Dimensions

dim_date · dim_channel · dim_product · dim_purpose · dim_coupon_bucket · dim_itm_bucket · dim_lock_status · dim_investor · dim_execution_route · dim_warehouse · dim_tba_contract · dim_loan (mini, type 2)

Degenerate on facts: lock_id, loan_id, trade_id, sale_id, draw_id.

## Additivity

| Measure | Same date | Across dates |
|---|---|---|
| UPB, PTWLV, econ, MTM, DV01, TBA short | SUM | last / as-of |
| Coverage, net DV01 pct, offset | recompute after SUM | n/a |
| PT | weighted avg | n/a |
| New lock / fallout / renego / pair-off / GOS $ | SUM | SUM |
| Warehouse outstanding | SUM facilities | last |

## References

`ref_pullthrough_forecast` and `ref_policy` are not dimensions. Copy applied PT onto the snapshot fact (`pt_forecast`, `pt_grid_as_of_date`).
