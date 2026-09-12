# Mortgage Capital Markets Analytics

Databricks **reporting and analytics** pack for a fintech / nonbank capital markets desk that originates to sell.

Novice operations walkthrough: [docs/README.md](docs/README.md).

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
| [docs/README.md](docs/README.md) | Novice operations + definitions |
| [docs/architecture.md](docs/architecture.md) | Unity Catalog, jobs, consumers |
| [docs/glossary.md](docs/glossary.md) | Full desk glossary |
| [docs/metrics.md](docs/metrics.md) | Metric catalog: formula, grain, view |
| [docs/kpis-and-calculations.md](docs/kpis-and-calculations.md) | Worked algebra |
| [docs/gold-star-schema.md](docs/gold-star-schema.md) | Star facts and dimensions |
| [docs/agent-15min.md](docs/agent-15min.md) | Intra-day agent |

## Why capital markets sits inside origination

Origination manufactures the loan. Capital markets makes it fundable, hedgeable, and saleable. Risk starts at **rate lock**.

```text
econ_usd = UPB × PT × (P_now − P_buy) / 100
```

Open locks use forecast PT. Funded HFS uses `PT = 1`.

## Databricks layout

`main.silver` · `main.gold_cm` · `main.ref_cm` · `main.gold`

Deploy: `databricks/uc_schemas.sql` → `sql/05` → `sql/06` → `01`/`02` → nightly `04` → `03` → metric views.

## Glossary

**Origination.** Building the loan. Capital markets does not take the application.

**Lock / IRLC.** Promise to the borrower of a rate and points for a stated number of days. Economic risk starts here.

**Lock desk.** Accepts locks, extensions, and renegotiations against the rate sheet.

**Extension.** Extra lock days. Policy fee vs fee charged is leakage.

**Renegotiation / relock.** Changing the locked rate after the fact. Shrinks day-one margin.

**Fallout.** The lock never funds.

**Fallout rate.** `1 − PT` (vintage).

**Fallout P&L.** Minus SOD econ of locks that left without funding (attribution).

**Channel.** Direct, retail, wholesale/broker, correspondent.

**PPE.** Turns investor bids and rules into the rate the LO sees.

**LOS.** System of record for the file.

**Points.** Percent of UPB. `101.25` = 1.25 above par.

**Par.** Price of 100.

**UPB.** Unpaid principal balance.

**Borrower buy price.** All-in price from the lender’s side of the borrower deal.

**Lock net price.** Best-ex net investor price on lock day.

**Locked margin.** `lock net − borrower buy`.

**Price move.** `P_now − P_lock`. Positive = rally = OTM for the borrower = PT should fall.

**ITM / OTM.** In / out of the money *for the borrower*.

**LLPA.** Investor price cut for credit, LTV, purpose, occupancy, units.

**Pull-through (PT).** Chance a lock funds. Forecast sizes the hedge.

**PTWLV.** `Σ UPB × PT̂`. Dollars you actually hedge.

**HFS.** Funded, not yet sold. PT = **1**.

**Lock-to-fund (L2F).** Realized PT on a finished vintage. Calibrate here, not on the open book.

**PT beta.** Slope of funding on price move. Expected sign is **negative**.

**Pipeline.** Open locks plus HFS.

**Econ USD.** `UPB × PT × (P_now − P_buy) / 100`.

**Pipeline MTM.** `UPB × PT × (P_now − P_lock) / 100`.

**TBA.** Forward on agency MBS. Standard pipeline hedge.

**Short TBA.** Gains when MBS prices fall.

**Pair-off.** Buy the TBA back. Short P&L = `notional × (sell − cover) / 100`.

**AOT.** Assign the TBA to the investor and deliver loans into it.

**DV01.** Dollar **loss** on the long book if yields rise 1 bp: `PTW UPB × EffDur / 10000`.

**PT coverage.** TBA short / (PTWLV + HFS). Recompute after SUM.

**Duration coverage.** Hedge DV01 / pipeline DV01. Recompute after SUM.

**Offset.** `−hedge P&L / (market + PT revision)`. Target ~ 1.0.

**Basis risk.** Loans did not move with the TBA you shorted.

**Convexity.** Mortgage duration shortens when rates fall and lengthens when rates rise.

**Warehouse line.** Bank revolver that funds closing until sale.

**Warehouse carry.** `UPB × rate × days / 360`.

**Best execution.** Route with the most net proceeds after cuts, carry, and servicing choice.

**SRP.** Cash if you sell the servicing.

**MSR.** Asset if you keep servicing.

**GOS.** Profit when the loan is sold.

**Slippage.** Realized GOS minus locked margin after planned costs.

**EPD.** Delinquent or paid off shortly after sale.

Longer entries: [docs/glossary.md](docs/glossary.md). Grains and additivity: [docs/metrics.md](docs/metrics.md).

## Metric views

`cm_daily_position` (date) · `cm_daily_attribution` (date) · `cm_loan_economics` (sold loan). Do not union those views.

## Disclaimer

Illustrative. Do not use as the sole input to a live trade, rate sheet, or warehouse draw.
