# Sample lock tape — report and analyze workflow

File (working copy): `data/sample_lock_pipeline_10k.csv`.
Grain: one **locked** loan as of 2026-09-11. 10,000 locks, 50% lock-to-fund (5,000 funded, 3,250 sold, 1,750 HFS).

Never-locked apps are not in this file. App-to-fund 10% is off-file context only.

## Status → book

Open locks (locked/approved/ctc/scheduled): PTWLV = UPB × PT.
HFS (funded): PT = 1.
Sold: GOS only.
Fallout/expired: out of the snapshot.

## Load

```sql
CREATE OR REPLACE TABLE main.silver.sample_lock_pipeline
USING CSV OPTIONS (header = true, inferSchema = true)
LOCATION 'dbfs:/FileStore/cm/sample_lock_pipeline_10k.csv';
```

## Project

Snapshot view: exclude sold/fallout from PTWLV and econ.
Position: group by `hedge_coupon`.
Demo hedge: `tba_short = locked_ptwlv + hfs` so coverage = 1.0 until a real blotter exists.

## Reports (sql/07)

Morning sheet on the hedged position.
Open book by channel × product × ITM.
GOS on `status = sold` only — do not add econ into GOS.
Warehouse on funded/sold carry columns.

## Still blocked without extra files

Attribution needs a prior-day clone.
Duration coverage needs EffDur.
FRED join after `fred_pull.py`.
15-min agent needs prints.
