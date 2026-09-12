# Mortgage Capital Markets Analytics

Databricks **reporting and analytics** pack for a fintech / nonbank capital markets desk that originates to sell.

It answers four desk questions:

1. What is the PT-weighted book, and is the hedge inside policy?
2. Why did economic value move since yesterday?
3. What did we realize when the loan sold?
4. Is last night’s pull-through grid still usable?

It is **not** a trading system, an LOS, or a MISMO exchange.

**Price convention:** points (`100` = par). Dollars = `UPB × points / 100`. Basis points = `points × 100`.

## Canonical docs

| Doc | What it is |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Unity Catalog, jobs, consumers, additivity |
| [docs/glossary.md](docs/glossary.md) | Terms and sign convention |
| [docs/metrics.md](docs/metrics.md) | Metric catalog: formula, grain, view |
| [docs/kpis-and-calculations.md](docs/kpis-and-calculations.md) | Worked algebra |
| [docs/gold-star-schema.md](docs/gold-star-schema.md) | Star facts and dimensions |
| [docs/agent-15min.md](docs/agent-15min.md) | Intra-day decisioning agent |

## Why capital markets sits inside origination

Origination manufactures the loan. Capital markets makes it fundable, hedgeable, and saleable. Risk starts at **rate lock**. The book value is:

```text
econ_usd = UPB × PT × (P_now − P_buy) / 100
```

Open locks use forecast PT. Funded HFS uses `PT = 1`. Sold and fallen-out loans leave the snapshot.

## Databricks layout

`main.silver` · `main.gold_cm` (star) · `main.ref_cm` (PT grid) · `main.gold` (compat views)

Deploy: `databricks/uc_schemas.sql` → `sql/05` → `sql/06` → `01`/`02` → nightly `04` → `03` → metric views.

## Grains (do not mix)

| Object | Grain |
|---|---|
| fact_lock_snapshot_daily | lock × date |
| fact_position_daily | date × coupon |
| fact_attribution_daily | date × channel |
| fact_gos | sold loan |
| fact_vintage_l2f | lock month × channel × product × purpose |
| fact_position_15m | print × coupon |
| fact_loan_eligibility | loan × lock/fund/sale |

Coverage is **recomputed after SUM**. Do not average stored coverage across dates.

## Sign rules

- `price_move = P_now − P_lock`. Positive = rally = OTM for the borrower.
- PT beta is **negative**. HFS PT = **1**.
- Fallout rate = `1 − PT`. Fallout P&L = minus SOD econ.
- Offset = `−hedge / (market + PT revision)`.
- Replay LLPAs from lock-row `fact_loan_eligibility`.

## Metric views

`cm_daily_position` (date) · `cm_daily_attribution` (date) · `cm_loan_economics` (sold loan)

Do not union those views. Catalog: [docs/metrics.md](docs/metrics.md).

## Disclaimer

Illustrative. Do not use as the sole input to a live trade, rate sheet, or warehouse draw.
