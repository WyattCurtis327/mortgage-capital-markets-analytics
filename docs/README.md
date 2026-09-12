# Capital markets operations (novice guide)

Plain-language README for how a mortgage capital markets desk works.

The Databricks pack lives in the [root README](../README.md). Desk-precise formulas stay in [glossary.md](glossary.md) and [metrics.md](metrics.md). Definitions a novice needs are in this file.

## The company you are in

Origination manufactures the loan. Almost no nonbank keeps it 30 years. It **sells** the loan to Fannie, Freddie, Ginnie pools, or another investor.

**Capital markets** sets the rate the borrower sees, takes the risk when they lock, borrows money to close, sells the loan, and hedges so a rate move in between does not sink the company.

## The clock starts at lock, not at closing

A **lock / IRLC** is: close in 30 days at this rate and these points. From that second the company is long a mortgage that does not exist yet.

- Prices fall (rates up) → the promise is worth less.
- Prices rise (rates down) → the promise is worth more, but the borrower may shop and **fall out**.

## One loan, six steps

1. Borrower locks.
2. Desk compares investor price vs borrower price — that gap is **locked margin**.
3. Desk **shorts TBA** MBS so a price drop is offset by the hedge.
4. Some files never close (**fallout**). Hedge **pull-through-weighted** volume, not every lock dollar.
5. At closing, draw a **warehouse line**. Loan is **HFS** until delivery.
6. **Best execution** picks the investor. Sale pays off the warehouse. Remainder is **gain on sale (GOS)**.

## Pull-through

```text
PTWLV = sum of (lock UPB × forecast PT)
price move = today’s loan price − price at lock
```

A $400,000 lock at 75% PT is $300,000 of hedge. After funding, PT = 1.
Positive price move = market rallied = lock is OTM for the borrower = PT should fall.

## The hedge

```text
PT coverage    = TBA short / (PTWLV + HFS)
Duration cover = hedge DV01 / pipeline DV01
```

DV01 = dollars lost if yields rise 1 bp. Policy keeps **net** DV01 small.

## Warehouse, sale, GOS

Nonbanks fund closing on a warehouse line. Carry is interest on that line. Best ex = route with the most net proceeds after LLPAs, fees, SRP or MSR, and carry. GOS minus day-one locked margin (after planned costs) is **slippage**.

## A day on the desk

Morning: book, coverage, what moved. Intraday: locks/fallout ~15 minutes. After sale: GOS. After the vintage resolves: lock-to-fund — never fit PT on the live open book.

## How this repo maps

| Question | Where |
|---|---|
| Book + hedge? | `sql/07` query 1, `cm_daily_position` |
| Why did value move? | `sql/03`, `cm_daily_attribution` |
| What did we make? | `fact_gos`, `cm_loan_economics` |
| Is PT believable? | Vintage L2F vs last night’s grid |

```text
econ = UPB × PT × (today’s net price − borrower price) / 100
```

## Glossary

Price unit is **points** (`100` = par). Dollars = `UPB × points / 100`. bps = points × 100.

**Origination.** Building the loan. Capital markets does not take the application.

**Lock / IRLC.** Promise to the borrower of a rate and points for a stated number of days. Risk starts here.

**Lock desk.** Accepts locks, extensions, renegotiations against the rate sheet.

**Lock period.** Days the rate is guaranteed (15 / 30 / 45 / 60).

**Extension.** Extra lock days. Policy fee vs fee charged is leakage.

**Renegotiation / relock.** Changing the locked rate after the fact. Shrinks day-one margin.

**Fall-in.** A dead lock that comes back.

**Fallout.** The lock never funds.

**Fallout rate.** `1 − PT`. Vintage statistic.

**Fallout P&L.** Book value that disappeared when those locks left. Not the same grain as the rate.

**Channel.** Direct, retail, wholesale/broker, correspondent.

**PPE.** Turns investor bids into the rate the LO sees.

**LOS.** System of record for the file.

**Points.** Percent of UPB. `101.25` is 1.25 above par.

**Par.** Price of 100.

**UPB.** Unpaid principal balance.

**Borrower buy price.** All-in price from the lender’s side of the borrower deal.

**Lock net price.** Best-ex net investor price on lock day.

**Locked margin.** `lock net − borrower buy`. Day-one promise.

**Price move.** Today’s loan price minus lock-day price. Positive = rally = OTM for the borrower.

**ITM / OTM.** In / out of the money *for the borrower*. ITM funds more often.

**LLPA.** Investor price cut for credit, LTV, purpose, occupancy, units.

**G-fee.** Agency guarantee cost.

**Pull-through (PT).** Chance a lock funds. Forecast sizes the hedge.

**PTWLV.** `Σ lock UPB × forecast PT`. Dollars you actually hedge.

**HFS.** Funded, not yet sold. PT = **1**.

**Lock-to-fund (L2F).** Realized PT on a finished vintage. Calibrate here, not on the open book.

**PT beta.** How PT changes when prices move. Expected sign is **negative**.

**Pipeline.** Open locks plus HFS.

**Econ.** `UPB × PT × (today’s net − borrower price) / 100`.

**Pipeline MTM.** `UPB × PT × (today’s price − lock price) / 100`.

**TBA.** Forward on agency MBS. Standard hedge.

**Short TBA.** Makes money when bond prices fall.

**Pair-off.** Buy the TBA back. Short gains if cover < sale price.

**AOT.** Assign the TBA to the investor and deliver loans into it.

**DV01.** Dollars the long book loses if yields rise 1 bp.

**PT coverage.** TBA short ÷ (PTWLV + HFS).

**Duration coverage.** Hedge DV01 ÷ pipeline DV01.

**Offset.** −hedge P&L / (market + PT revision). Target ~ 1.0.

**Basis risk.** Loans did not move with the TBA you shorted.

**Convexity.** Duration shrinks when rates fall and grows when rates rise.

**Warehouse line.** Bank revolver that funds closing until sale.

**Haircut / advance rate.** Share of UPB the line funds.

**Borrowing base.** Loans the warehouse still accepts.

**Warehouse carry.** `UPB × rate × days / 360`.

**Best execution.** Route with the most net money after cuts.

**SRP.** Cash if you sell the servicing.

**MSR.** Asset if you keep servicing.

**Delivery.** Investor pays; warehouse is repaid.

**GOS.** Profit when the loan leaves: sale + SRP or MSR + hedge + interest − warehouse − cuts − fees − LO pay − cost to originate.

**Slippage.** Realized GOS minus locked margin after planned costs.

**EPD.** Delinquent or paid off right after sale. Hits GOS.

## What this desk is not

Not processing. Not the warehouse credit committee. Not a prop TBA trader. Mandate: transfer rate risk and get paid for manufacturing the loan.
