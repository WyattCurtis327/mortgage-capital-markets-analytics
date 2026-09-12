# Capital markets operations (novice guide)

Plain-language README for how a mortgage capital markets desk works.

The Databricks pack lives in the [root README](../README.md). Terms: [glossary.md](glossary.md).

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
5. At closing, draw a **warehouse line**. Loan is **HFS** (held for sale) until delivery.
6. **Best execution** picks the investor. Sale pays off the warehouse. Remainder is **gain on sale (GOS)**.

## Pull-through

```text
PTWLV = sum of (lock UPB × forecast PT)
```

A $400,000 lock at 75% PT is $300,000 of hedge. After funding, PT = 1.

```text
price move = today’s loan price − price at lock
```

Positive = market rallied = lock is out of the money for the borrower = PT should fall.

## The hedge

Long locks and HFS, short TBA. Coverage:

```text
PT coverage    = TBA short / (PTWLV + HFS)
Duration cover = hedge DV01 / pipeline DV01
```

DV01 = dollars lost if yields rise 1 bp. Policy keeps **net** DV01 small. Hedges miss because of fallout (PT risk), loan vs TBA mismatch (basis), and duration change (convexity).

## Warehouse

Nonbanks do not have deposits. A bank line advances most of the UPB at closing. Interest is **carry**. Old loans can fall out of the **borrowing base**. Speed to sale is a cap-markets KPI.

## Sale and GOS

Best ex = route with the most net proceeds after LLPAs, fees, SRP or MSR, and carry.

- Released servicing → cash **SRP**.
- Retained servicing → keep the **MSR**, less cash.

GOS is sale + SRP/MSR + hedge + interest − warehouse − cuts − fees − LO pay − origination cost.

GOS minus day-one locked margin (after planned costs) is **slippage**. Explain it; do not hide it.

## A day on the desk

Morning: book, coverage, what moved. Intraday: locks/fallout every ~15 minutes, rebalance or move the sheet if TBA jumps. After sale: GOS. After the vintage resolves: lock-to-fund to recalibrate PT — never fit PT on the live open book.

## How this repo maps

| Question | Where |
|---|---|
| Book + hedge? | `sql/07` query 1, `cm_daily_position` |
| Why did value move? | `sql/03`, `cm_daily_attribution` |
| What did we make? | `fact_gos`, `cm_loan_economics` |
| Is PT believable? | Vintage L2F vs last night’s grid |
| Intra-day? | 15-min prints, [agent-15min.md](agent-15min.md) |

```text
econ = UPB × PT × (today’s net price − borrower price) / 100
```

Points: `100` = par. Dollars = `UPB × points / 100`.

## First vocabulary

Lock/IRLC · PT · PTWLV · HFS · TBA · pair-off · warehouse · best ex · GOS · MSR/SRP · slippage

Full list: [glossary.md](glossary.md). Metrics: [metrics.md](metrics.md).

## What this desk is not

Not processing. Not the warehouse credit committee. Not a prop TBA trader. Mandate: transfer rate risk and get paid for manufacturing the loan. Coverage inside the band and GOS near locked margin after honest slippage means the job got done.
