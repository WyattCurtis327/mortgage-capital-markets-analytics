# Mortgage Capital Markets Analytics

Databricks reporting and analytics pack for a fintech / nonbank capital markets desk that originates to sell.

Novice walkthrough: [docs/README.md](docs/README.md). Grok Project prompt: [docs/GROK-PROJECT.md](docs/GROK-PROJECT.md).

Four desk questions: PT-weighted book and hedge policy; why econ moved; realized GOS; whether last night's PT grid is still usable.

Not a trading system, LOS, or MISMO exchange.

Price convention: points (`100` = par). Dollars = `UPB × points / 100`.

## Canonical docs

| Doc | What it is |
|---|---|
| [docs/README.md](docs/README.md) | Novice operations + definitions |
| [docs/architecture.md](docs/architecture.md) | Unity Catalog, jobs, consumers |
| [docs/glossary.md](docs/glossary.md) | Full desk glossary |
| [docs/metrics.md](docs/metrics.md) | Metric catalog |
| [docs/kpis-and-calculations.md](docs/kpis-and-calculations.md) | Worked algebra |
| [docs/gold-star-schema.md](docs/gold-star-schema.md) | Star facts |
| [docs/agent-15min.md](docs/agent-15min.md) | Intra-day agent |
| [docs/GROK-PROJECT.md](docs/GROK-PROJECT.md) | Grok Project UI prompt |
| [docs/sample-reporting-workflow.md](docs/sample-reporting-workflow.md) | Load and report the sample tape |
| [docs/sample-lock-events.md](docs/sample-lock-events.md) | Events and soft fallout |
| [docs/solution-status-and-gaps.md](docs/solution-status-and-gaps.md) | Built vs missing |
| [data/README.md](data/README.md) | Sample tape + PT grid |

## Why capital markets sits inside origination

```text
econ_usd = UPB × PT × (P_now − P_buy) / 100
```

Open locks use forecast PT. Funded HFS uses PT = 1. Never-locked apps are funnel only.

## Sample tape

Local (gitignored): `data/sample_lock_pipeline_10k.csv`, `data/sample_lock_event.csv`.
In repo: PT grid `data/ref_pullthrough_forecast_sample.csv` (add from working copy if missing).

10,000 locks. 80% coin-resolved (~50% L2F). 20% open on the grid. Ex-D3-save L2F ~38%.

## Deploy

`databricks/uc_schemas.sql` → `sql/05` → `sql/06` → `sql/09` → `01`/`02` → nightly `04` → `03` → `08` FRED → metric views.

## Disclaimer

Illustrative. Do not use as the sole input to a live trade, rate sheet, or warehouse draw.
