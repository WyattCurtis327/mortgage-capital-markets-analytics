# Mortgage Capital Markets Analytics

Open pack for a **fintech / nonbank mortgage capital markets desk** that originates to sell.

It covers:

1. How capital markets is involved in loan origination (pricing, lock, hedge, warehouse, best ex, sale).
2. Desk KPIs and the formulas behind them.
3. Databricks SQL for pull-through, daily position, gain-on-sale, and P&L attribution.
4. An incremental nightly job that MERGEs a `lock_id × date` snapshot.
5. How an AI agent can run **decisioning** analytics on a pipeline that refreshes about every 15 minutes.

This is a reference implementation, not a trading system. It does not connect to a live LOS, TBA desk, or warehouse bank.

**Price convention:** points (`100` = par). Dollars = `UPB × points / 100`. Basis points = `points × 100`.

**Canonical glossary:** [`docs/glossary.md`](docs/glossary.md) — not duplicated below.

---

## Why capital markets sits inside origination

Origination manufactures the loan. Capital markets makes it **fundable, hedgeable, and saleable**.

The economic clock starts at **rate lock**, not at closing. When the borrower locks, the company is long a fixed-rate mortgage that does not yet exist. If market prices fall before sale, that lock is worth less. The desk:

- Feeds the product / pricing / eligibility (PPE) engine from TBA and investor bids.
- Hedges the lock pipeline, usually by shorting TBA MBS, sized to **pull-through-weighted** exposure.
- Arranges warehouse lines so closing can fund.
- Runs best execution and delivers the loan.
- Marks and optionally hedges MSRs if servicing is retained.

Without that loop, origination quotes rates the secondary market will not pay and closes loans the balance sheet cannot carry.

---

## Repository map

```
docs/
  glossary.md                  Canonical glossary
  gold-star-schema.md          Star grains and additivity
  kpis-and-calculations.md     Worked KPI math
  agent-15min.md               15-minute agent architecture
sql/
  01_origination_kpis.sql      Gold views: lock as-of, risk, position
  02_pullthrough_forecast.sql  Session A — PT grid + beta + live join
  03_pnl_attribution.sql       Session B — daily P&L waterfall
  04_daily_merge_job.sql       Session C — incremental MERGE + gates
  05_gold_star_ddl.sql         Gold star DDL
  06_eligibility_note_structure.sql  LLPA attributes + ARM/IO/buydown
databricks/
  metric_views.yaml            Unity Catalog metric views
  daily_snapshot_job.py        Notebook wrapper
  workflow.yaml                Suggested 3-task Databricks job
LICENSE                        MIT
```

Dialect is **Databricks SQL** (`QUALIFY`, `FILTER`, `DATE_TRUNC`).

---

## Data grains (do not mix)

| Object | Grain | Use |
|---|---|---|
| `gold_lock_risk_daily` | `lock_id × as_of_date` | Live PTWLV, econ, MTM, DV01 |
| `gold_cm_daily_position_tbl` | `as_of_date` | Coverage, net MTM, policy |
| `gold_vintage_l2f` | lock month × channel × product × purpose | Realized PT |
| `gold_loan_gos` | sold `loan_id` | Realized GOS and slippage |
| `gold_pnl_attribution_daily` | `as_of_date` | Why the book moved |
| Intra-day `gold_cm_position_15m` | `print_ts` | Agent Watcher |

```text
econ_usd = UPB × PT × (P_now − P_buy) / 100
```

Open locks use forecast PT. Funded HFS uses `PT = 1`. Fallen-out and sold loans leave the snapshot.

---

## Deploy order

**A** `sql/02_pullthrough_forecast.sql` — PT grid, shrinkage k=40, channel beta (expected negative).

**B** `sql/03_pnl_attribution.sql` — needs stored daily snapshot. Offset = −hedge / (market + PT revision).

**C** `sql/04_daily_merge_job.sql` — restate last 5 days; freeze older PT; fail on default-PT share > 20% or PTWLV shock > 35%.

**Star** `sql/05` then `sql/06` (eligibility + note structure).

**Agent** `docs/agent-15min.md` — drafts tickets (`auto_execute: false`).

---

## Metric cheat sheet

| Metric | Formula |
|---|---|
| PT volume | funded UPB / locked UPB |
| PTWLV | Σ UPB × PT̂ |
| Locked margin | P_lock_net − P_buy |
| Econ USD | UPB × PT × (P_now − P_buy) / 100 |
| Pipeline MTM | UPB × PT × (P_now − P_lock) / 100 |
| DV01 | PTW UPB × EffDur / 10000 |
| PT coverage | TBA short / (PTWLV + HFS) |
| Duration coverage | hedge DV01 / pipeline DV01 |
| Warehouse carry pts | rate × days / 360 × 100 |
| GOS bps | GOS $ / sold UPB × 10,000 |
| Slippage pts | realized GOS pts − locked margin after planned costs |
| Offset | −hedge P&L / (market + PT revision) |
| EPD rate 90 | EPD UPB / sold UPB |

---

## Glossary pointer

See [`docs/glossary.md`](docs/glossary.md).

- `price_move = P_now − P_lock`. Positive = rally = OTM for the borrower = PT should fall.
- PT beta is **negative**.
- HFS / funded PT = **1**. Default `0.75` only if the open lock has no grid cell.
- Fallout **rate** is `1 − PT`. Fallout **P&L** is minus SOD econ of locks that left without funding.
- Offset denominator is market + PT revision only.
- Replay LLPAs from `fact_loan_eligibility` at lock, not from current `dim_loan`.

---

## Disclaimer

Formulas and SQL are illustrative. Hedge ratios, PT grids, LLPAs, warehouse terms, and investor bids are firm-specific and change. Do not use this repository as the sole input to a live trade, rate sheet, or warehouse draw.
