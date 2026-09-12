# Solution status and gaps

## In the pack

Docs (ops, glossary, metrics, architecture) · star DDL 05/06 · PT / attribution / MERGE SQL · metric views · reporting examples 07 · FRED 08 · 10k sample pipeline.

Not built: live LOS/TBA/warehouse connectors, automated CSV→gold load, multi-day snapshots, real hedge blotter, dashboards/Genie space, pool/AOT/roll facts, MSR OAS book.

## Sample vs gold

CSV = application × one as_of. Gold wants lock×date history, TBA shorts by coupon, eligibility at lock/fund/sale, FRED join.

## Gaps that break first queries

1. No TBA short inventory — coverage is undefined until you synthesize shorts ≈ PTWLV by coupon.
2. No yesterday snapshot — attribution cannot run.
3. PT on the file is a status/ITM stub, not the trained grid.
4. 8,000 never-locked apps are funnel only; exclude from PTWLV.
5. No ARM/IO/government/jumbo.
6. Warehouse is per-loan carry, not a borrowing base.
7. FRED pull needs an API key.
8. Pool/AOT/roll/MSR valuation still missing.

## Demo path

Load CSV → filter locks → fake hedge = PTWLV by coupon → run sql/07 #1 #3 #5 #7 → clone as_of-1 with a TBA bump to demo attribution.
