# Architecture — Databricks capital markets analytics

Reporting mart for an originate-to-sell desk. Not a trading system.

## Unity Catalog

| Schema | Role |
|---|---|
| main.silver | LOS / PPE / warehouse / blotter |
| main.gold_cm | Star facts + dimensions |
| main.ref_cm | PT grid, policy, duration |
| main.gold | Compatibility views |

DDL: `sql/05_gold_star_ddl.sql` then `sql/06_eligibility_note_structure.sql`.

## Flow

Silver (15-min / nightly) → nightly PT grid + lock snapshot + position + attribution + GOS → metric views, SQL warehouse dashboards, Genie, agent.

Intra-day writes `fact_lock_now` and `fact_position_15m` only. Do not UPDATE `ref_pullthrough_forecast` mid-day.

## Jobs

- `cm_daily_snapshot` ~07:15 PT → MERGE spine → gates
- `cm_gos_load` after purchase advice
- `cm_print_15m` market hours

Restate last 5 days. Freeze older PT. Fail: zero rows, bad UPB/PT, default PT > 20%, PTWLV shock > 35%. Coverage 70–120% is WARN.

## Consumers

Morning sheet → `cm_daily_position`.
Attribution → `cm_daily_attribution` (offset denom = market + PT revision only).
Finance → `cm_loan_economics` (do not SUM daily MTM to get GOS).
PT review → vintage L2F, not the open book.
Agent → 15-min facts, read-only.
Genie → metric views only.

## Additivity

UPB / PTWLV / econ / MTM / DV01: SUM same date, last across dates.
Coverage / net DV01 %: recompute after SUM.
GOS / fallout $ / pair-off: SUM everywhere.
