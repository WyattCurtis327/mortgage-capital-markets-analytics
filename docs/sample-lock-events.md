# Sample lock events

Working copy: `data/sample_lock_event.csv` (paired with `sample_lock_pipeline_10k.csv`).

## Counts (seed 20260913)

| Type | n |
|---|---|
| lock | 10,000 |
| fund | 3,958 |
| sale | 2,577 |
| fallout | 4,042 |
| renegotiate | 1,321 |
| relock | 79 |
| extend | 160 |
| status | 823 |
| **total** | **22,960** |

Soft fallout: D1/D2 = 1,560 events; D3 (margin give ≤ −0.25 pts) = 1,044.
Renego cost on tape ≈ **−$1.52mm** (give).

## L2F two ways

| Series | Rate |
|---|---|
| As-funded (resolved) | 49.5% |
| Ex-save (funded without D3) | **37.7%** |

944 funded loans are D3 saves. Train the grid on ex-save if the next book will not get the same courtesy.

## Load

```sql
CREATE OR REPLACE TABLE main.silver.sample_lock_event
USING CSV OPTIONS (header = true, inferSchema = true)
LOCATION 'dbfs:/FileStore/cm/sample_lock_event.csv';
```

Join to locks on `chain_id = lock_id` (relocks use `prior_lock_id`).
