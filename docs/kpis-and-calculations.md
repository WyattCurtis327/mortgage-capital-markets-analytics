# KPIs and calculations

Worked formulas for the gold views in `sql/`. Price convention: points (`100` = par).

## Pull-through

```text
PT_vol   = funded_upb / locked_upb
PT_count = funded_count / lock_count
PTWLV    = Σ UPB_i × PT̂_i
```

ITM buckets on `P_now − P_lock`:

| Bucket | Price move |
|---|---|
| itm_deep | ≤ −0.75 |
| itm | (−0.75, −0.25] |
| atm | (−0.25, +0.25] |
| otm | (+0.25, +0.75] |
| otm_deep | > +0.75 |

Shrinkage toward parent:

```text
PT_shrunk = (n × PT_cell + k × PT_parent) / (n + k)
            clipped to [0.05, 0.99], k = 40
```

Channel beta is the slope of `funded_ind` on `price_move_pts`. Expected sign is negative.

## Value

```text
econ_usd      = UPB × PT × (P_now − P_buy) / 100
pipeline_mtm  = UPB × PT × (P_now − P_lock) / 100
dv01          = PTW_UPB × EffDur / 10000
```

Funded HFS uses `PT = 1`.

## Coverage

```text
gross_coverage    = tba_short / (locked_upb_gross + hfs_upb)
pt_coverage       = tba_short / (PTWLV + hfs_upb)
duration_coverage = hedge_dv01 / pipeline_dv01
net_dv01_pct      = (pipeline_dv01 − hedge_dv01) / pipeline_dv01
```

Example policy: `|net_dv01_pct| ≤ 0.05`.

## Warehouse

```text
carry_usd = UPB × warehouse_rate × days / 360
nim_usd   = UPB × (note_rate − warehouse_rate) × days / 360
```

## Gain on sale (sold loan)

```text
gos_pts =
    sale_price + srp − llpa − gfee − file_fee_pts
  − warehouse_carry_pts + nim_pts + hedge_pairoff_pts
  − borrower_buy_price − lo_comp_pts − orig_cost_pts

slippage_pts = gos_pts − (lock_net − buy − planned_lo_comp − planned_orig_cost)
gos_bps      = gos_usd / sold_upb × 10_000
```

## Attribution offset

```text
offset = −hedge_pnl / (market + pt_revision)
```

Hedge P&L = Δ open TBA mark + pair-off cash realized that day.

See `sql/01_origination_kpis.sql`, `sql/02_pullthrough_forecast.sql`, and `sql/03_pnl_attribution.sql`.
