# ASTRA HFC3 TickRobust Strategy Tester — 2026-09-25

Purpose: simple local screening of the open-source N30 TickRobust Z-score mean-reversion mechanism as a possible high-frequency companion to frozen P812 + KAGURA G10.

Upstream
- Repository: https://github.com/n30dyn4m1c/gold-pro-scalper
- Source: XAU_Quant_Reversion_TickRobust.mq5
- License: MIT
- Core concept remains source-derived: closed-bar Z-score stretch, turn confirmation, ADX/range regime, ATR regime, cost gates, H1 alignment, server-side hard SL and mean TP, bar-based backup exit/time exit/breakeven/gravity TP.

ASTRA research changes
1. Default symbol = XAUUSDm.
2. Strict M1 guard.
3. Fixed 0.01-lot research mode is ON by default.
4. Dynamic risk is OFF by default.
5. News filter and daily-loss overlay are OFF for alpha discovery.
6. CSV audit added for single tests.
7. OnTester() added only as an optimizer ranking helper. It is NOT the PASS/FAIL rule.

## Compile
Copy `HFC3_TickRobust_Research.mq5` into:
`MQL5/Experts/AstraResearch/HFC3/`

Compile in MetaEditor. Required target: 0 errors. Warnings should be reviewed rather than ignored.

## SINGLE DEFAULT — run this first
Preset: `HFC3_SINGLE_DEFAULT.set`

Strategy Tester:
- Expert: HFC3_TickRobust_Research
- Symbol: XAUUSDm
- Timeframe: M1
- Model: Every tick based on real ticks
- Date: 2026-01-02 through 2026-09-23
- Deposit: USD 1000
- Leverage: 1:500
- Account: Hedging
- Execution delay: Fixed 1000 ms
- Optimization: Disabled

Expected audit files (Common/Files):
- HFC3_DEFAULT_SIGNALS.csv
- HFC3_DEFAULT_TRADES.csv
- HFC3_DEFAULT_SUMMARY.csv

Important: confirm every opened trade volume is 0.01.

Simple gate before any optimizer:
- target frequency >= 1.5 independent trades / market day
- overall PF > 1.10
- net expectancy > 0
- no catastrophic chronology collapse
- hard SL present on every entry
- fixed 0.01 only

If headline PF is roughly 0.9 or below, reject HFC3 instead of rescuing it.

## SEARCH A — only if SINGLE DEFAULT is worth continuing
Preset: `HFC3_SEARCH_A_160.set`

Window:
- 2026-01-02 through 2026-04-30 only

Tester:
- Slow complete algorithm
- Every tick based on real ticks
- Fixed delay 1000 ms
- Custom max

Exactly 160 parameter combinations:
- EntryZ: 1.8, 2.0, 2.2, 2.4, 2.6
- MAPeriod: 15, 20, 25, 30
- ADXMax: 18, 22, 26, 30
- H1 SMA filter: OFF(0), ON(50)

All management, session, ATR, cost, SL and sizing parameters remain frozen.

Search-A candidate gate:
- enough sample / frequency
- PF >= 1.20 in DEV
- profit > 0
- bounded DD

Survivors are then replayed without tuning on:
- May-Jun validation
- Jul-Aug pseudo-OOS
- Sep stress

October 2026+ remains untouched prospective OOS.

## Portfolio gate
A standalone survivor is NOT automatically accepted.
It must then be tested against:
P812 frozen + KAGURA G10 frozen + HFC3

Audit:
- incremental trade/day
- daily PnL correlation
- overlap with P812 HF10 micro mean-reversion
- opposite-direction conflicts
- combined PF
- mark-to-market DD
- contribution on P812/KAGURA losing or flat days

No martingale, grid, or averaging down.
