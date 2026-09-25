# ASTRA HFC3 TickRobust Research

Purpose: screen an open-source cost-aware Z-score mean-reversion strategy as a high-frequency companion to frozen P812 + KAGURA G10.

## Files
- HFC3_TickRobust_Research.mq5 — Strategy Tester EA.
- HFC3_SINGLE_DEFAULT.set — first mandatory single run.
- HFC3_SEARCH_A_160.set — use only if single run passes the preregistered gate.
- UPSTREAM_MIT_LICENSE.txt — upstream license.

## Research changes vs upstream
- Default symbol XAUUSDm.
- Explicit fixed 0.01 lot.
- Dynamic risk disabled.
- Economic-calendar news overlay disabled.
- Daily-loss overlay disabled.
- Entry/exit/cost/regime logic otherwise retained.

## Mandatory first test
- Symbol XAUUSDm
- Period M1
- Model Every tick based on real ticks
- Execution delay Fixed 1000 ms
- 2026-01-02 through 2026-09-23
- Deposit 1000 USD
- Leverage 1:500
- Hedging
- Optimization Disabled
- Load HFC3_SINGLE_DEFAULT.set

Do NOT run Search A unless the single default run is economically positive and sufficiently frequent.

## Search A
Only if default passes:
- Date 2026-01-02 through 2026-04-30
- Slow complete algorithm
- EntryZ: 1.8,2.0,2.2,2.4,2.6
- MAPeriod: 15,20,25,30
- ADXMax: 18,22,26,30
- H1 filter: OFF/50
- Total 160 passes.

P812 and KAGURA are immutable controls. October 2026+ remains untouched prospective OOS.
