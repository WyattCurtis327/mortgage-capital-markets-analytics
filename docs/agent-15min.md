# Cap markets AI agent on a ~15-minute origination pipeline

Goal: surface **decisioning** analytics for the capital markets desk — coverage, hedge, pricing, lock policy, fallout — as lock status, TBA marks, and warehouse draws refresh about every 15 minutes.

The agent is not a chatbot on a warehouse. It is a constrained loop: read the latest book, compare to the last print and to SOD, explain the move, recommend an action, and stop. Humans trade.

## Two clocks

**Daily (job C).** Frozen SOD book, PT grid, vintage L2F, GOS. Rewritten at night.

**Intra-day.** Current lock/HFS state + an append-only 15-minute event log + a one-row position print.

Each print recomputes PTWLV, econ, MTM, DV01, coverage, and the tape (new lock / fallout / fund / renego). It does **not** rebuild pull-through, EPD, or the slippage waterfall. Mid-day PT still comes from last night’s grid. If a cell is running hot, recommend a **same-day coverage overlay** that dies at tomorrow’s SOD.

Point-in-time measures (PTWLV, coverage) and flow measures (fallout since 10:00) stay in separate metric views.

```
gold_lock_risk_now          -- 1 row per open lock / HFS loan
gold_lock_event_15m         -- append-only events
gold_cm_position_15m        -- 1 row per print_ts
gold_tba_mark_15m           -- coupon_bucket x print_ts
gold_hedge_book_now         -- open TBA lots
gold_warehouse_now          -- facility availability vs CTC
```

Watermark: process `event_ts <= print_ts`. Late events hit the next print and are tagged `late_arrival_ind`.

## Agent roles

| Role | When | Output |
|---|---|---|
| Watcher | Every 15 min or a TBA jump | OK / WARN / FAIL flash |
| Analyst | On warn/fail or a human question | Structured decision object |
| Reporter | After Analyst | Desk card, Genie answer, page |

Watcher exits on a quiet tape. Most prints should be six lines and no ticket.

## Decision object

JSON first, prose second. Include `print_ts`, `sod_ts`, `status`, position (PTWLV, HFS, PT coverage, net DV01, net P&L vs SOD), attribution since print, trigger codes, recommendations with `auto_execute: false`, and a short narrative in glossary terms.

## Tools (read-only except a draft ticket)

`get_position` · `get_gates` · `get_attribution` · `get_lock_tape` · `get_pt_cells` · `get_tba_path` · `get_hedge_lots` · `get_warehouse` · `what_if_coverage` · `what_if_rate_sheet` · `propose_rebalance` · `post_desk_card`

Banned: raw silver SQL, trading APIs, mid-day UPDATE to `ref_pullthrough_forecast`.

## Workflows

1. **Hedge rebalance** — net DV01 or PT coverage outside the band → `what_if_coverage` → sell/pair-off TBA in lot size on the mismatched coupon.
2. **Rate sheet** — TBA moved a full increment → margin at risk on ATM/OTM open locks → roll one increment.
3. **Live PT** — run-rate vs last night’s cell, only if n is large enough → overlay, not a grid rewrite.
4. **Lock-desk leakage** — extension giveaway + renego $ vs budget run-rate.
5. **Warehouse** — available line vs next four hours of CTC.
6. **Explain P&L** — market / PT revision / new / fallout / renego / hedge. If residual > 10% of |Δecon|, the print is dirty; freeze recs.

## Guardrails

- Last night’s PT is a prior.
- Ticket notional cap; no sheet move more than one increment per print.
- Late arrivals tagged; print marked `provisional` if material.
- Dirty attribution freezes recommendations except restore-the-limit.
- Log every tool call and decision object.

## Trust test

Sum of intra-day flashes should reconcile to the daily B waterfall by morning, within late-arrival tolerance. If it does not, the agent does not draft tickets.
