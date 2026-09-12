# Gold star schema — capital markets datamart

DDL:
- [`sql/05_gold_star_ddl.sql`](../sql/05_gold_star_ddl.sql) — core star
- [`sql/06_eligibility_note_structure.sql`](../sql/06_eligibility_note_structure.sql) — LLPA attributes + note structure

## Rules

1. One grain per fact.
2. Conformed dimensions (date, channel, product, purpose, coupon, investor, warehouse, status, ITM, occupancy, property type, note structure).
3. Semi-additive measures: SUM across locks/coupons on one date; never SUM across dates.
4. Snapshots freeze the PT used that day.
5. Replay LLPAs from `fact_loan_eligibility` at event `lock`, not from current `dim_loan`.
6. Product card ≠ note. A CONV_30 can be fixed, ARM, IO, or a buydown (`dim_note_structure`).

## Facts

| Fact | Grain |
|---|---|
| fact_lock_snapshot_daily | lock × date |
| fact_lock_now | current lock |
| fact_lock_event | one event |
| fact_loan_eligibility | loan × lock\|fund\|sale |
| fact_position_daily | date × coupon |
| fact_position_15m | print × coupon |
| fact_hedge_snapshot_daily | lot × date |
| fact_hedge_trade | one fill |
| fact_tba_mark | date × coupon |
| fact_warehouse_balance_daily | facility × date |
| fact_warehouse_draw | one draw |
| fact_loan_fund | funded loan |
| fact_loan_sale | sold loan |
| fact_gos | sold-loan economics |
| fact_best_ex_quote | loan × route × ts |
| fact_attribution_daily | date × channel |
| fact_vintage_l2f | lock month × channel × product × purpose |

## Note structure seeds

FIX_30 · FIX_15 · ARM_5_6_SOFR · ARM_7_6_SOFR · FIX_30_IO10 · FIX_30_BD21 · FIX_30_BD10

Hedge coupon may differ from note coupon: `hedge_coupon_bucket_key` on the lock snapshot.
