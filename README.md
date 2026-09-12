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

See [`docs/glossary.md`](docs/glossary.md) for the full glossary (also inlined below).

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
  glossary.md                  Full glossary (also inlined below)
  kpis-and-calculations.md     Worked KPI math
  agent-15min.md               15-minute agent architecture
sql/
  01_origination_kpis.sql      Gold views: lock as-of, position, L2F, GOS
  02_pullthrough_forecast.sql  Session A — PT grid + beta + live join
  03_pnl_attribution.sql       Session B — daily P&L waterfall
  04_daily_merge_job.sql       Session C — incremental MERGE + gates
databricks/
  metric_views.yaml            Unity Catalog metric views
  daily_snapshot_job.py        Notebook wrapper (widgets, PT refresh, fail-on-gate)
  workflow.yaml                Suggested 3-task Databricks job
LICENSE                        MIT
```

Dialect is **Databricks SQL** (`QUALIFY`, `FILTER`, `DATE_TRUNC`). Postgres notes are in the KPI file header comments.

---

## Data grains (do not mix)

| Object | Grain | Use |
|---|---|---|
| `gold_lock_risk_daily` | `lock_id × as_of_date` | Live PTWLV, econ, MTM, DV01 |
| `gold_cm_daily_position_tbl` | `as_of_date` | Coverage, net MTM, policy |
| `gold_vintage_l2f` | lock month × channel × product × purpose | Realized PT to retrain the grid |
| `gold_loan_gos` | sold `loan_id` | Realized GOS and slippage |
| `gold_pnl_attribution_daily` | `as_of_date` | Why the book moved |
| Intra-day `gold_cm_position_15m` | `print_ts` | Agent Watcher |

Point-in-time measures (PTWLV, coverage) are **not** additive across dates. Flow measures (fallout UPB, hedge P&L in a window) are.

One value definition is used everywhere:

```text
econ_usd = UPB × PT × (P_now − P_buy) / 100
```

Open locks use forecast PT. Funded held-for-sale uses `PT = 1`. Fallen-out and sold loans leave the snapshot.

---

## Deploy order

### A — Pull-through forecast (`sql/02_pullthrough_forecast.sql`)

Empirical PT by `status × channel × purpose × product × ITM bucket`, shrunk toward a parent when the cell is thin (`k = 40`), plus a channel beta on price move.

- Price move `P_now − P_lock` **> 0** means the market rallied, the lock is OTM for the borrower, PT should fall. Beta is **negative**.
- Rebuild the grid nightly from resolved vintages. Do not fit it on the live open book.
- Live locks join `gold_lock_pt_live` (`leaf` / `parent` / `default`).

### B — Daily P&L attribution (`sql/03_pnl_attribution.sql`)

Needs stored `gold_lock_risk_daily`. Splits Δecon into new locks, fallout, fund PT step-up, market, PT revision, renegotiation, UPB change, residual. Hedge P&L is open TBA mark change **plus** pair-off cash that day.

Judge hedge quality with:

```text
offset = −hedge_pnl / (market + pt_revision)
```

Do not put new locks, fallout, or renego in the denominator. Those are not what the TBA was sized for.

### C — Incremental snapshot (`sql/04_daily_merge_job.sql`)

- Restate the last `restate_days` (default 5) with MERGE + `WHEN NOT MATCHED BY SOURCE` delete.
- Freeze older partitions, including the PT used that day.
- Full-refresh the small PT grid; do not MERGE it.
- Quality gates fail the job on zero rows, bad UPB/PT, default-PT share > 20%, PTWLV shock > 35%. Coverage outside 70–120% is a **WARN**.

Backfill day-by-day with `restate_days = 0`. Do not restatement-rebuild 90 days of history with tonight’s PT model.

### 15-minute agent (`docs/agent-15min.md`)

Watcher every print or TBA jump → Analyst on WARN/FAIL → Reporter desk card. Last night’s PT grid is a prior. The agent drafts tickets (`auto_execute: false`). It does not refit the model at 10:15 and it does not send TBA orders.

Trust test: sum of intra-day flashes should reconcile to the daily B waterfall by morning, within late-arrival tolerance.

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

Unity Catalog metric views live in `databricks/metric_views.yaml`:

- `cm_loan_economics` — sold-loan grain
- `cm_daily_position` — date grain
- `cm_daily_attribution` — date grain

Do not union those grains.

---

## Assumed silver inputs

Map these from your LOS / secondary / warehouse systems before the gold views will run.

- `fact_rate_lock` — one row per IRLC
- `fact_lock_status_hist` — status through time
- `fact_lock_event` — renegotiate, extend, fallout, fund
- `fact_funded_loan`
- `fact_loan_sale`
- `fact_warehouse_draw`
- `fact_hedge_trade` — TBA lots, side, pair-off
- `fact_best_ex_quote`
- `ref_tba_market` — daily (and optionally 15-min) marks + effective duration

---

## Glossary

Canonical copy: [`docs/glossary.md`](docs/glossary.md).

### Origination and locks

**Origination.** Manufacturing a new loan: application, processing, underwriting, close. Capital markets does not take the application; it prices, hedges, funds, and sells what origination produces.

**Interest rate lock / IRLC.** Commitment to the borrower to close at a stated rate and points for a stated number of days. The lender is long a not-yet-funded mortgage from lock until sale.

**Lock desk.** Team and system that takes locks, extensions, and renegotiations against pricing and product rules.

**Lock period.** Days the rate is guaranteed (15 / 30 / 45 / 60). Longer locks carry more rate risk.

**Extension.** Adding days to a lock. Policy fee vs fee charged is lock-desk leakage.

**Renegotiation / relock.** Changing the locked rate or points after the original lock, usually because the market rallied.

**Fall-in.** A lock that was out and comes back.

**Channel.** Consumer-direct, retail, wholesale/broker, correspondent, joint venture. Different PT, cost, and execution.

**PPE.** Product, pricing, and eligibility engine. Turns secondary bids into the rate the LO or borrower sees.

**LOS.** Loan origination system. Status history for the daily snapshot comes from here.

### Price and margin

**Points.** Percent of UPB. `101.25` = 101-08 = 1.25 points above par.

**Ticks / 32nds.** TBA quote convention. `100-16` = 100.50.

**Par.** Price of 100.

**Borrower buy price.** All-in price from the lender’s side of the borrower deal (par ± credits/points + LO/broker comp in price).

**Lock net price.** Best-ex net investor price at lock (base − LLPAs − g-fees + SRP − file fees in points).

**Locked margin.** `lock_net_price − borrower_buy_price`.

**Price move.** `P_now − P_lock`. Positive = market rallied, lock is OTM for the borrower.

**ITM / OTM.** From the borrower’s view of the lock versus today’s market. ITM → higher PT. OTM → more fallout.

**ITM buckets (this pack).** `itm_deep` ≤ −0.75 pts · `itm` −0.75 to −0.25 · `atm` ±0.25 · `otm` +0.25 to +0.75 · `otm_deep` > +0.75.

**LLPA.** Up-front investor price adjustment from credit, LTV, purpose, occupancy, units. Cumulative.

**Guarantee fee / buy-up / buy-down.** Agency guarantee cost, ongoing or paid up front.

**File fee.** Per-loan investor fee. Points = `fee_usd / UPB × 100`.

### Pull-through and fallout

**Pull-through (PT).** Probability a lock funds. Forecast sizes the hedge. Realized PT is lock-to-fund on a resolved vintage.

**PT count vs PT volume.** Count = loans / loans. Volume = UPB / UPB. Volume overweight jumbo.

**Fallout.** `1 − PT`.

**Soft fallout.** Would have fallen out if the desk had not renegotiated.

**PTWLV.** `Σ UPB_i × PT̂_i`. Hedge this, not gross locked UPB.

**Lock-to-fund (L2F).** Realized PT for a lock-date vintage after the window closed. Calibrate the grid here, not on the live book.

**PT source.** `leaf` / `parent` / `default`. High default share is a data-quality fail.

**PT beta.** Slope of funded indicator on price move, by channel. Expected sign is negative.

**Shrinkage.** `PT_shrunk = (n × PT_cell + k × PT_parent) / (n + k)`, clipped to [0.05, 0.99].

### Pipeline and value

**Pipeline.** Open locks plus closed loans still held for sale.

**HFS.** Funded, not yet sold. PT = 1. Still rate-risked. Sits on the warehouse line.

**Econ USD.** `UPB × PT × (P_now − P_buy) / 100`. The number attribution explains.

**Pipeline MTM.** `UPB × PT × (P_now − P_lock) / 100`.

**Restatement window.** Last N days the nightly job may rewrite. Older rows stay frozen, including that day’s PT.

### Hedging and risk

**TBA MBS.** Forward on an agency pool (product, coupon, month) without naming pools. Standard pipeline hedge.

**Short TBA.** Gains when MBS prices fall (rates up), which is when locked loans lose value.

**Pair-off.** Buy back the TBA. P&L = (short price − cover price) × notional / 100.

**AOT.** Assign the existing TBA to the investor and deliver loans into it. Avoids paying bid/ask twice.

**Mandatory vs best efforts.** Mandatory: you commit to deliver and keep market/fallout risk (hedge it). Best efforts: investor takes fallout; worse price.

**Pull-through risk.** Actual funded UPB ≠ the PT you hedged.

**Basis risk.** Pipeline does not move one-for-one with the TBA coupon you shorted.

**Convexity.** Mortgage duration shortens when rates fall and lengthens when rates rise. Duration hedges are local.

**Effective duration.** Percent price change for a 100 bp yield move, including expected prepay.

**DV01.** Dollar value of +1 bp yield: `PTW UPB × EffDur / 10000`.

**Gross coverage.** TBA short / (gross locked + HFS).

**PT coverage.** TBA short / (PTWLV + HFS).

**Duration coverage.** hedge DV01 / pipeline DV01.

**Net DV01 percent.** `(pipe DV01 − hedge DV01) / pipe DV01`. Example policy: ±5%.

**Offset.** `− hedge P&L / (market + PT revision)`. Target near 1.0.

### Funding

**Warehouse line.** Revolving credit against the note from funding until sale. How nonbanks originate without deposits.

**Advance rate / haircut.** Share of UPB the line will fund (often 80–95%).

**Borrowing base.** Which loans are eligible collateral.

**Wet vs dry funding.** Wet: warehouse wires to the table. Dry: lender funds first, warehouse reimburses.

**Warehouse carry.** `UPB × warehouse_rate × days / 360`.

**NIM while HFS.** `UPB × (note_rate − warehouse_rate) × days / 360`.

### Secondary and sale

**Best execution.** Route that maximizes net proceeds after LLPAs, SRP or MSR, fees, and carry.

**Cash best ex vs economic best ex.** Cash ignores MSR fair value. Economic includes it.

**CTAS.** Cash to acquire servicing = best released net − best retained cash net.

**Specified pool / pay-up.** Named pool that trades above TBA. Harder to hedge.

**Servicing-released vs retained.** Released: cash SRP. Retained: keep the MSR, lower cash price.

**SRP.** Servicing release premium, in points of UPB.

**Reps and warranties.** Seller promises that can force a post-sale repurchase.

**EPD.** Early payment default or early payoff shortly after sale (often 90 days). Contra-revenue against GOS.

### Gain on sale

**GOS.** Sale premium + SRP + MSR FV + hedge/pair-off + HFS NIM − warehouse interest − LLPAs/g-fees − fees − LO comp − allocated origination cost.

**Slippage.** Realized GOS minus locked margin after planned costs.

**Slippage waterfall.** Locked margin → market/LLPA → hedge → lock desk → best ex/fees → carry/NIM → costs → GOS.

### Servicing

**MSR.** Asset when you sell the loan and keep servicing.

**Net servicing strip.** Note rate minus pass-through minus g-fee. Agency base servicing is often 25 bps.

**CPR.** Annualized prepay rate. Faster prepays hurt MSR value.

**Recapture.** Refi your own serviced borrower so the MSR does not run off.

**Pipeline book vs MSR book.** Different hedge instruments. Do not combine coverage ratios.

### Daily attribution buckets

**New locks.** EOD econ of locks not on yesterday’s snapshot.

**Fallout P&L.** Minus SOD econ of locks that left without funding.

**Fund PT step-up.** PT goes from forecast to 1 on yesterday’s price.

**Market.** Yesterday UPB and PT × today’s price minus yesterday’s.

**PT revision.** Yesterday UPB × ΔPT × today’s margin.

**Renego.** Change in borrower buy price or lock price.

**Residual.** Δecon minus named buckets. Large residual means a dirty snapshot.

**Hedge P&L (total).** Δ open TBA mark + pair-off cash realized today.

**Net desk P&L.** Δecon + hedge P&L.

### Job and lakehouse terms

**Spine.** Dates from `as_of − restate_days` through `as_of` the MERGE may rewrite.

**`WHEN NOT MATCHED BY SOURCE` delete.** Drops locks that no longer belong on a restated date. Required or fallout never shows up in B.

**Late arrival.** Intra-day event after the print watermark. Next print + `late_arrival_ind`. Do not silently rewrite the last card.

### Acronyms

AOT assignment of trade · CTC clear to close · CTAS cash to acquire servicing · EPD early payment default · GOS gain on sale · GSE Fannie/Freddie · HFS held for sale · IRLC interest rate lock commitment · LLPA loan-level price adjustment · LO loan officer · LOS loan origination system · MBS mortgage-backed security · MSR mortgage servicing right · NIM net interest margin (note vs warehouse) · PPE product/pricing/eligibility engine · PT pull-through · PTWLV pull-through-weighted lock volume · SRP servicing release premium · TBA to-be-announced · UPB unpaid principal balance

---

## Disclaimer

Formulas and SQL are illustrative. Hedge ratios, PT grids, LLPAs, warehouse terms, and investor bids are firm-specific and change. Do not use this repository as the sole input to a live trade, rate sheet, or warehouse draw.
