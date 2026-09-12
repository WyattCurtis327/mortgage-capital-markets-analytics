# Capital Markets Origination Glossary

**Canonical glossary for this pack.** Price convention is **points** (`100` = par). Dollars = `UPB × points / 100`. Basis points = `points × 100`.

Related files: `sql/01`–`08` · `databricks/fred_pull.py` · [docs/README.md](README.md) (novice) · [docs/metrics.md](metrics.md).

## Sign convention

`price_move = P_now − P_lock`. Positive = market rallied, lock is **OTM for the borrower**, PT should fall. PT beta is **negative**.

HFS / funded PT = **1**. Default `0.75` is only for open locks with no grid cell.

## Fallout (two grains)

**Fallout rate** = `1 − PT` (vintage). **Fallout P&L** = minus SOD `econ_usd` of locks that left without funding.

## Pair-off and DV01

Short pair-off: `notional × (sell_price − cover_price) / 100`. Gain when cover is below the short sale price.

DV01 = `PTW UPB × EffDur / 10000` = dollar **loss** on a long mortgage if yields rise 1 bp.

## Status path

`locked` < `approved` < `ctc` < `scheduled` < `funded`. Terminal: `fallen_out`, `expired`, `sold`.

## Eligibility and note structure

Replay LLPAs from `fact_loan_eligibility` at **lock**. `hedge_coupon_bucket_key` is the TBA you shorted, not always the note coupon.

## Acronyms

| Acronym | Meaning |
|---|---|
| AOT | assignment of trade |
| ARM | adjustable-rate mortgage |
| ATM | at the money (lock vs market, borrower view) |
| ATR | ability to repay |
| AUS | automated underwriting system |
| BPS | basis points (points × 100) |
| CAC | customer acquisition cost |
| CDC | change data capture |
| CLTV | combined loan-to-value |
| CMT | constant-maturity Treasury |
| CPR | constant prepayment rate |
| CTC | clear to close |
| CTAS | cash to acquire servicing |
| CTD | cheapest to deliver |
| DTI | debt-to-income |
| DVP | delivery versus payment |
| DV01 | dollar value of a 1 bp yield rise |
| EOD | end of day |
| EPD | early payment default (or early payoff) |
| FHA | Federal Housing Administration |
| FHLMC | Freddie Mac |
| FICO | Fair Isaac credit score |
| FNMA | Fannie Mae |
| FRM | fixed-rate mortgage |
| FRED | Federal Reserve Economic Data |
| FTHB | first-time homebuyer |
| FV | fair value |
| GNMA | Ginnie Mae |
| GOS | gain on sale |
| GSE | government-sponsored enterprise |
| HFS | held for sale |
| IO | interest-only |
| IRLC | interest rate lock commitment |
| ITM | in the money (borrower view) |
| KPI | key performance indicator |
| L2F | lock-to-fund |
| LLPA | loan-level price adjustment |
| LO | loan officer |
| LOS | loan origination system |
| LTV | loan-to-value |
| MBS | mortgage-backed security |
| MCR | NMLS mortgage call report |
| MI | mortgage insurance |
| MIN | MERS mortgage identification number |
| MISMO | Mortgage Industry Standards Maintenance Organization |
| MSR | mortgage servicing right |
| MTM | mark to market |
| NIM | net interest margin (note vs warehouse while HFS) |
| NMLS | Nationwide Multistate Licensing System |
| OAS | option-adjusted spread |
| OTM | out of the money (borrower view) |
| P&L | profit and loss |
| PMMS | Freddie Mac Primary Mortgage Market Survey |
| PPE | product / pricing / eligibility engine |
| PSA | PSA prepay curve |
| PT | pull-through |
| PTWLV | pull-through-weighted lock volume |
| QM | qualified mortgage |
| SIFMA | Securities Industry and Financial Markets Association |
| SMM | single monthly mortality |
| SOFR | Secured Overnight Financing Rate |
| SOD | start of day |
| SRP | servicing release premium |
| TBA | to-be-announced agency MBS forward |
| UC | Unity Catalog |
| ULDD | Uniform Loan Delivery Dataset |
| UMBS | Uniform Mortgage-Backed Security |
| UPB | unpaid principal balance |
| USDA | USDA rural housing |
| UW | underwriting / underwriter |
| VA | Department of Veterans Affairs |

Term write-ups: working-copy `docs/glossary.md` sections 1–12. Metrics: [metrics.md](metrics.md).
