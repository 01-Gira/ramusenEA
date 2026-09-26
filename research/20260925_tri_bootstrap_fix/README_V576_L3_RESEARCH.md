# ASTRA QUAD V576-L3 RESEARCH

V575 live-demo remains frozen and untouched.

## Hypothesis
Test profit-funded pyramiding on the frozen primary sleeve only.

## Rules
- Base = frozen primary position.
- L2: +0.50R, fixed 0.01.
- Before L2: base SL >= BE + $0.25 cash-equivalent buffer.
- L2 hard SL = parent entry.
- L3: +1.00R, fixed 0.01.
- Before L3: base SL >= +0.50R and L2 SL >= its own BE + $0.25 buffer.
- L3 hard SL = parent +0.50R.
- Max = base + L2 + L3.
- No averaging down, martingale, grid, or layer re-entry.
- Gross remaining hard-stop downside across XAUUSDm positions <= 10% balance.
- HF08_SESSION_SWEEP_FADE excluded.
- KAGURA and LBMA remain single-position.

## A/B protocol
Compile AstraQuadV576_L3.mq5.

Run A first:
QUAD_V576_CONTROL_LAYER_OFF.set
Must reproduce V575 (latest reference final balance ~1360.30) with zero layer trades.

Only if Run A passes, run:
QUAD_V576_L3_RESEARCH_ON.set

Tester:
XAUUSDm M1
Every tick based on real ticks
Fixed delay 1000ms
$20
1:500
Hedging
2026-01-02 to 2026-09-26
Optimization disabled

Collect normal Quad CSVs plus:
QUAD_V576_LAYER_EVENTS.csv
QUAD_V576_LAYER_SUMMARY.csv

Jan-Sep is consumed research data. Historical improvement cannot replace V575 without fresh prospective evidence.
