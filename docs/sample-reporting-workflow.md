# Sample lock tape — report and analyze workflow

Working copy: `data/sample_lock_pipeline_10k.csv` plus `data/ref_pullthrough_forecast_sample.csv`.

## Funding assignment

- 80% of locks **resolved** by a fair coin: funded vs withdrawn/denied/expired.
- Realized L2F on resolved ≈ 50% (seed: 3,958 funded / 4,042 fallout).
- 20% stay **open**. Their PT is a join to `ref_pullthrough_forecast` (`status × channel × purpose × product × ITM`), not an inline rule.
- Funded PT = 1. Fallout PT = 0.
- ~65% of funded are sold; rest HFS.

All-lock funded share ≈ 40% because 20% are still open. Vintage L2F = funded / resolved.

## Book rules

Open → PTWLV = UPB × grid PT.
HFS → PT = 1.
Sold → GOS only.
Withdrawn/denied/expired → out.

## Load + rejoin grid

```sql
CREATE OR REPLACE TABLE main.silver.sample_lock_pipeline
USING CSV OPTIONS (header = true, inferSchema = true)
LOCATION 'dbfs:/FileStore/cm/sample_lock_pipeline_10k.csv';

CREATE OR REPLACE TABLE main.ref_cm.ref_pullthrough_forecast
USING CSV OPTIONS (header = true, inferSchema = true)
LOCATION 'dbfs:/FileStore/cm/ref_pullthrough_forecast_sample.csv';
```

Open-lock `pt_forecast` on the tape should match the grid join on those five keys (`pt_source = leaf`).

Demo hedge: short = PTWLV + HFS so coverage = 1.0.

Reports: morning sheet; open book by ITM; L2F on `resolved_ind = 1`; GOS on sold; warehouse on funded/sold.

Still missing: prior-day snapshot, duration, real TBA shorts, FRED, 15-min prints.
