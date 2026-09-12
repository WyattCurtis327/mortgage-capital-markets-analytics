# Mortgage Capital Markets Analytics

Open pack for a fintech / nonbank mortgage capital markets desk that originates to sell.

**Canonical glossary:** [docs/glossary.md](docs/glossary.md) — do not keep a second full copy here.

**Price convention:** points (`100` = par). Dollars = `UPB × points / 100`. Basis points = `points × 100`.

See the repository map, grains, deploy order, and metric cheat sheet in this file on `main` after pull, or in the working copy `artifacts/cm_repo/README.md`.

## Glossary pointer

- `price_move = P_now − P_lock`. Positive = rally = OTM for the borrower = PT should fall.
- PT beta is **negative**.
- HFS / funded PT = **1**. Default `0.75` is open locks with no grid cell only.
- Fallout **rate** is `1 − PT`. Fallout **P&L** is minus SOD econ of locks that left without funding.
- Offset denominator is market + PT revision only.
- Replay LLPAs from `fact_loan_eligibility` at lock, not from current `dim_loan`.

Full definitions: [docs/glossary.md](docs/glossary.md).

## Disclaimer

Formulas and SQL are illustrative. Do not use this repository as the sole input to a live trade, rate sheet, or warehouse draw.
