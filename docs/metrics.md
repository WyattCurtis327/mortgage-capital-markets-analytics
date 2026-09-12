# Metric definitions

Controlled list. Terms: [glossary.md](glossary.md). Architecture: [architecture.md](architecture.md).

Price: points (`100` = par). `price_move = P_now − P_lock` (positive = rally = OTM for borrower).

## Pipeline (metric view `cm_daily_position`, date grain)

| Metric | Formula | Additivity |
|---|---|---|
| Locked UPB | Σ open-lock UPB | SUM same date; last across dates |
| PTWLV | Σ UPB × PT̂ | same |
| HFS UPB | Σ funded not-sold UPB (PT = 1) | same |
| Econ USD | UPB × PT × (P_now − P_buy) / 100 | SUM same date |
| Pipeline MTM | UPB × PT × (P_now − P_lock) / 100 | SUM same date |
| Pipeline DV01 | PTW UPB × EffDur / 10000 | SUM same date; $ loss on +1 bp yield |
| PT coverage | TBA short / (PTWLV + HFS) | **recompute after SUM** |
| Duration coverage | hedge DV01 / pipeline DV01 | **recompute after SUM** |
| Net DV01 % | (pipe − hedge) / pipe DV01 | **recompute after SUM** |

## Pull-through

Forecast: shrunk cell, clip [0.05, 0.99], k = 40.
Realized L2F: funded UPB / locked UPB on a resolved vintage.
PT beta by channel: expected **negative**.
Default PT 0.75 only if the open lock has no cell. HFS PT = 1.
Do not mix live PT and L2F in one metric view.

## Attribution (metric view `cm_daily_attribution`)

Buckets: new locks, fallout P&L, fund PT step-up, market, PT revision, renego, UPB change, residual.
Hedge P&L = Δ open mark + pair-off cash.
Offset = −hedge / (market + PT revision). Target ~ 1.0.
Fallout rate ≠ fallout P&L.

## GOS (metric view `cm_loan_economics`, sold-loan grain)

Do not SUM daily MTM to get GOS.

```
gos_pts = sale + srp − llpa − gfee − file − carry + nim + pair-off − buy − lo_comp − orig_cost
gos_bps = gos_usd / sold_upb × 10_000
slippage_pts = gos_pts − (lock_net − buy − planned costs)
```

## Warehouse

Carry $ = UPB × rate × days / 360. Carry pts = rate × days / 360 × 100.
Balances: last across dates.

## Gates

FAIL: rows=0, UPB≤0, PT outside [0.05,1], default PT > 20%, PTWLV shock > 35%.
WARN: coverage outside 70–120%.

## Views

`cm_daily_position` date · `cm_daily_attribution` date · `cm_loan_economics` sold loan.
Never union them.
