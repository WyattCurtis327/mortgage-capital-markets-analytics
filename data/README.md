# Sample origination pipeline

10,000 application rows as of **2026-09-11**.

File (local working copy): `data/sample_origination_pipeline_10k.csv` (2.5 MB). Regenerate with the generator in the working copy (`seed=20260912`).

## Market anchors

| Input | Value | Source |
|---|---|
| 30yr FRM | 6.76% | Freddie PMMS 2026-09-10 |
| 15yr FRM | 6.09% | same |
| Baseline CLL | $832,750 | FHFA 2026 1-unit |
| Occupancy | owner-occupied |
| Products | CONV_30 / CONV_15 FRM only |

## Funnel (exact)

10,000 apps → 2,000 locks (20%) → 1,000 funded (**50% L2F**, **10% app-to-fund**) → 650 sold / 350 HFS.

## Columns (54)

Identity and dates, status, channel/product/purpose/occupancy, credit box (FICO/LTV/CLTV/DTI/MI/FTHB/high-balance), note + TBA prices, LLPA/SRP/LO comp, PT stub, econ, warehouse carry/NIM, GOS.

This is a one-day wide silver snapshot, not a multi-day gold history and not a TBA blotter.
