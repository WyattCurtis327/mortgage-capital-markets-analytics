# Grok Project — Mortgage Capital Markets Analytics

Paste this file into a new Grok Project system prompt (or pin it). Skill name on this computer: `mortgage-capital-markets`.

Repo: https://github.com/WyattCurtis327/mortgage-capital-markets-analytics

## Purpose

Databricks reporting mart for an originate-to-sell capital markets desk. Not a trading system.

## Always true

- Risk starts at lock. Never-locked apps are funnel only.
- econ = UPB × PT × (P_now − P_buy) / 100. Points convention.
- price_move > 0 = OTM for the borrower. PT beta negative.
- Coverage recomputed after SUM.
- Offset denom = market + PT revision.
- Vintage L2F = funded / resolved. Also publish ex-soft-fallout L2F.
- Sample CSVs are local (`data/sample_lock_pipeline_10k.csv`, `data/sample_lock_event.csv`).

## Extending

Databricks SQL in `sql/0N_*.sql`. Update glossary acronyms. Push docs; keep large CSVs off GitHub.
