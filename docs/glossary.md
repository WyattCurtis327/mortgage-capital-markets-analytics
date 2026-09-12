# Capital Markets Origination Glossary

**Canonical glossary for this pack.** README links here; do not keep a second full copy there.

Price convention is **points** (`100` = par). Dollars = `UPB × points / 100`. Basis points = `points × 100`.

Related files: `sql/01` · `02` · `03` · `04` · `05` · `06`.

## Sign convention

`price_move = P_now − P_lock`. Positive = market rallied, lock is **OTM for the borrower**, PT should fall. PT beta is **negative**.

HFS / funded PT = **1**. Default `0.75` is only for open locks with no grid cell.

## Fallout (two grains)

**Fallout rate** = `1 − PT` (vintage statistic).

**Fallout P&L** = minus SOD `econ_usd` of locks that left the snapshot without funding (attribution bucket).

## Pair-off and DV01 (signed)

Short pair-off: `realized_pairoff_usd = notional × (sell_price − cover_price) / 100`. Gain when you cover **below** the short sale price.

DV01 stored as `PTW UPB × EffDur / 10000` is the **dollar loss** on a long mortgage if yields rise 1 bp. Hedge DV01 is the offsetting short-TBA gain. Policy limits **net** DV01.

## Status path (`dim_lock_status`)

`locked` < `approved` < `ctc` < `scheduled` < `funded`. Terminal: `fallen_out`, `expired`, `sold`. Application is LOS workflow, not a lock-status code here.

## Eligibility, note structure, coupon mapping

**Note structure** (`dim_note_structure`): the note on the loan, not the product card. `CONV_30` can close as `FIX_30`, `ARM_5_6_SOFR`, `FIX_30_IO10`, or `FIX_30_BD21`.

**Qualifying rate:** note rate on a standard fixed; ARM qualifying rule on an ARM; usually note (not stepped) rate on a buydown.

**Hedge coupon vs note coupon:** `hedge_coupon_bucket_key` is the TBA you shorted. A 6.125% note often hedges with UMBS 6.0.

**Eligibility snapshot** (`fact_loan_eligibility`): FICO/LTV/CLTV/DTI/occupancy/property/MI/jumbo **as of lock, fund, or sale**. Replay LLPAs from the **lock** row, not current `dim_loan`.

## TBA roll

Moving a short from the front settle month to the next embeds financing (specialness). **Not in v1 facts.** Pair-off cash ≠ roll P&L.

## IRLC FV vs desk econ

Accounting IRLC fair value uses a different cost set than `econ_usd`. Do not reconcile 1:1.

**Bailee:** warehouse/investor letter that the note is held for the line or buyer.

## Warehouse carry

Dollars: `UPB × rate × days / 360`. Points: `rate × days / 360 × 100`. Cheat sheet uses points.

## Slippage

Cheat-sheet **slippage pts** = realized GOS pts − locked margin after planned costs (one number). The waterfall explains that gap. Not two competing GOS figures.

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

`itm_deep` ≤ −0.75 · `itm` (−0.75, −0.25] · `atm` ± 0.25 · `otm` (+0.25, +0.75] · `otm_deep` > +0.75

## Attribution buckets

New locks · Fallout P&L · Fund PT step-up · Market · PT revision · Renego · UPB change · Residual · Hedge (open mark + pair-off cash)

Offset denominator: market + PT revision only.

## Acronyms

AOT · ARM · CTC · CTAS · EPD · GOS · GSE · HFS · IRLC · IO · LLPA · LO · LOS · MBS · MSR · NIM · OAS · PPE · PT · PTWLV · SRP · TBA · UMBS · UPB

Longer narrative definitions (lock desk, convexity, borrowing base, GOS stack, job spine) are in the working-copy `docs/glossary.md` sections 1–13.
