# Capital Markets Origination Glossary

Canonical desk glossary for this pack. The same text is inlined in the [README](../README.md#glossary).

Price convention is **points** (`100` = par). Dollars = `UPB × points / 100`. Basis points = `points × 100`.

## Sign convention

`price_move = P_now − P_lock`. Positive means the market rallied, the lock is **OTM for the borrower**, and pull-through should fall. Hedge PT beta on price move is **negative**.

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

## ITM buckets

| Bucket | Price move |
|---|---|
| itm_deep | ≤ −0.75 |
| itm | (−0.75, −0.25] |
| atm | (−0.25, +0.25] |
| otm | (+0.25, +0.75] |
| otm_deep | > +0.75 |

## Core terms

**IRLC / lock.** Commitment to the borrower at a stated rate and points for a stated number of days. Economic risk starts here.

**PT / pull-through.** Probability a lock funds. Forecast sizes the hedge. Realized PT is lock-to-fund on a resolved vintage.

**PTWLV.** Σ UPB × PT̂. Hedge this, not gross locked UPB.

**HFS.** Funded, not yet sold. PT = 1. Sits on the warehouse line.

**Econ USD.** UPB × PT × (P_now − P_buy) / 100. The number daily attribution explains.

**TBA.** Agency MBS forward. Standard pipeline hedge. Short TBA gains when prices fall.

**Pair-off / AOT.** Close a TBA by buying it back, or assign it to the investor and deliver loans into it.

**Best ex.** Route that maximizes net proceeds after LLPAs, SRP or MSR, fees, and carry.

**GOS.** Realized gain on sale after premium, SRP, hedge, carry, fees, and compensation.

**MSR / SRP.** Servicing asset if retained; cash premium if released.

**Warehouse.** Revolving line that funds the loan from closing until sale.

**Offset.** −hedge P&L / (market + PT revision). Do not put new locks, fallout, or renego in the denominator.

**Spine / restatement window.** Last N days the nightly MERGE may rewrite. Older partitions stay frozen, including that day’s PT.

## Attribution buckets

New locks · Fallout · Fund PT step-up · Market · PT revision · Renego · UPB change · Residual · Hedge (open mark + pair-off cash)

## Acronyms

AOT assignment of trade · CTC clear to close · CTAS cash to acquire servicing · EPD early payment default · GOS gain on sale · GSE Fannie/Freddie · HFS held for sale · IRLC interest rate lock commitment · LLPA loan-level price adjustment · LO loan officer · LOS loan origination system · MBS mortgage-backed security · MSR mortgage servicing right · NIM net interest margin (note vs warehouse) · PPE product/pricing/eligibility engine · PT pull-through · PTWLV pull-through-weighted lock volume · SRP servicing release premium · TBA to-be-announced · UPB unpaid principal balance

For longer definitions (lock desk, convexity, borrowing base, CTAS, quality gates, metric-view grains), use the [README glossary](../README.md#glossary).
