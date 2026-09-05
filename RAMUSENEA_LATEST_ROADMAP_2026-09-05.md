# RamusenEA — Latest Research & Development Roadmap

**Project:** RamusenEA  
**Platform:** MetaTrader 5 / MQL5  
**Market:** XAUUSD  
**Primary Style:** Fast intraday / scalping  
**Target Holding Window:** Primarily 5–30 minutes  
**Document Date:** 2026-09-05  
**Current Program:** S3 Alpha Research  
**Production Status:** **NOT APPROVED**

---

## 1. Executive Summary

RamusenEA has progressed from infrastructure and baseline strategy development into a structured quantitative research program.

The project has already completed multiple generations of signal research, risk architecture, exit design, cost stress, out-of-sample validation, controlled pyramiding, and post-failure analysis.

The most important conclusions so far are:

- The original raw M5 EMA9/21 crossover is **not robust enough to be used as primary alpha**.
- M15 EMA20/50 bearish context has repeatedly shown useful directional information.
- Candidate S1 looked promising in development but **failed out-of-sample**.
- Candidate S2 improved development quality substantially but also **failed its pre-registered fresh OOS test**.
- Controlled layering was implemented correctly, but the old layer strategy **failed because it amplified rare tail winners rather than improving typical opportunity quality**.
- P2F.15A showed that the primary S2 failure was **gross alpha decay / winner magnitude compression**, not leverage, not execution bugs, and not fees alone.
- S3.0 has now demonstrated that the M5 EMA9/21 bearish crossover still contains useful **event-timing information inside M15 bearish context**, even though it is not strong enough to be the primary alpha itself.
- The next stage is **S3.1 — Paired Delayed Entry Research**, where only entry timing will change.

The project remains research-only until a new S3 candidate passes clean future validation.

---

# 2. Status Legend

| Status | Meaning |
|---|---|
| ✅ COMPLETE / PASS | Stage completed and evidence supports its intended objective |
| 🟡 CONDITIONAL / RESEARCH PASS | Useful development evidence, but not enough for production approval |
| ❌ FAIL | Stage failed its decision gate |
| ❌ FAIL_KEEP_CONTROL | Challenger failed; keep control/reference only |
| 🔒 LOCKED | Reserved or frozen; must not be changed or opened prematurely |
| ⛔ BLOCKED | Cannot proceed until earlier validation requirements are satisfied |
| ➡️ NEXT | Current immediate development/research stage |
| ⬜ PENDING | Planned but not started |
| 📦 ARCHIVED | Kept for reproducibility/reference, not current production candidate |

---

# 3. Core Research Principles

The project follows these non-negotiable rules:

- No martingale.
- No averaging down.
- No grid.
- No forced daily profit target.
- No increasing leverage to hide weak expectancy.
- No increasing risk to make a weak strategy appear profitable.
- One major hypothesis change per experiment whenever possible.
- Executable BID/ASK semantics must be used.
- Spread must not be double-counted.
- Development, contaminated research, fresh OOS, and forward validation must remain clearly separated.
- A layered trade with 10 tickets is still **one independent market opportunity** statistically.
- Profitability must come from positive expectancy, not from position-size escalation.
- Multi-layer pyramiding is allowed only when adding to **protected winners**.
- Future validation data must remain untouched until the strategy is frozen.

---

# 4. Project Architecture

Current research architecture:

```text
M15 = directional context / regime
M5  = primary setup / event generator
M1  = optional future precision / continuation confirmation
```

Current direction of research:

```text
M15 BEARISH CONTEXT
        ↓
M5 EVENT / TIMING SIGNAL
        ↓
BETTER ENTRY TIMING / STRUCTURAL ENTRY
        ↓
GROSS EDGE CHECK
        ↓
COST COVERAGE
        ↓
RISK / EXIT
        ↓
OPTIONAL WINNER PYRAMIDING
        ↓
FORWARD VALIDATION
```

---

# 5. Phase 0 — Foundation & Safety

## P0.1 — Runtime & Safety Foundation
**Status:** ✅ COMPLETE

Implemented:

- modular EA structure
- configuration layer
- market snapshot
- magic-number ownership
- single-position protection
- spread guard
- structured logging
- fail-closed default

---

## P0.2 — Risk-Based Position Sizing
**Status:** ✅ COMPLETE

Implemented:

- risk percentage sizing
- broker-aware volume normalization
- min/max/step handling
- `OrderCalcProfit` based risk calculation

Important decision:

> Risk sizing must remain broker-aware and must not be replaced by simplistic tick-value arithmetic.

---

## P0.3 — Demo Execution Self-Test
**Status:** ✅ COMPLETE

Validated:

- BUY execution
- SELL execution
- SL attached
- TP attached
- magic ownership
- duplicate-position blocking
- broker retcode logging

---

## P0.4 — Restart / Recovery Safety
**Status:** ✅ COMPLETE

EA can recognize its own existing positions after restart and does not assume that a restart means no position exists.

---

## P0.5 — Foundation Verification
**Status:** ✅ COMPLETE

Foundation considered stable enough for strategy research.

---

# 6. Phase 1 — Baseline Strategy

## P1.1 — Signal Engine
**Status:** ✅ COMPLETE

Initial baseline used EMA crossover logic.

---

## P1.2 — Entry Engine
**Status:** ✅ COMPLETE

---

## P1.3 — Exit Policy
**Status:** ✅ COMPLETE

---

## P1.4 — Trade Journal
**Status:** ✅ COMPLETE

Sub-stages:

- P1.4A Execution Truth Ledger — ✅ PASS
- P1.4B Strategy Context — ✅ PASS
- P1.4C Closed Trade Dataset — ✅ PASS

---

## P1.5 — Historical Baseline Test
**Status:** ❌ PROFITABILITY FAIL

Initial H1 EMA20/50 baseline:

- 9 closed trades
- 1 win / 8 losses
- Win Rate: 11.11%
- Profit Factor: 0.498
- Net PnL: -$184.69
- Return: -1.85%

Engineering and accounting passed, but the strategy itself was not profitable.

This became the first formal control rather than a production candidate.

---

# 7. Phase 2 — Profitability Discovery

## P2.0 — Control Freeze
**Status:** ✅ COMPLETE

Baseline control was frozen before further research.

---

## P2.1 — MFE / MAE Diagnostics
**Status:** ✅ COMPLETE

Important discovery:

There were two types of losing trades:

1. entries that were weak almost immediately
2. entries that reached meaningful positive MFE and then returned to loss

This motivated later profit-retention research.

---

## P2.2 — Signal Forward Return Research
**Status:** ✅ COMPLETE

Long-horizon research helped show that the original H1 architecture did not fit the intended fast intraday style.

---

# 8. P2F — Fast Intraday / Scalping Program

## P2F.0 — Fast Engine Redesign
**Status:** ✅ COMPLETE

Architecture changed to:

```text
M15 context
M5 primary setup
M1 optional precision later
```

Target holding changed to approximately 5–30 minutes.

---

## P2F.1 — Minute Signal Research
**Status:** ✅ COMPLETE

Raw M5 EMA9/21 crossover research:

- 341 unique signals
- 171 BUY
- 170 SELL
- horizons: 1m, 3m, 5m, 10m, 15m, 30m, 60m

Research pipeline passed.

---

## P2F.2 — Raw EMA9/21 Alpha Gate
**Status:** ❌ FAIL

At 10 minutes:

- mean executable return ≈ +0.78 bps
- median ≈ -0.90 bps
- positive rate ≈ 45.9%

The mean was supported by large winners while typical outcomes were weak.

Conclusion:

> EMA9/21 crossover alone is not robust primary alpha.

---

## P2F.3 — Context / Regime Discovery
**Status:** ✅ PASS

Key discovery:

```text
SELL M5 EMA9/21 bearish crossover
+
M15 EMA20 < EMA50
```

was substantially better than raw crossover.

Development 10-minute result for SELL + M15 aligned:

- N ≈ 50
- mean executable ≈ +13.29 bps
- median ≈ +2.45 bps
- positive ≈ 58%

BUY-aligned did not show comparable edge.

This became Candidate S1.

---

## P2F.4 — Candidate S1 Entry Gate
**Status:** ✅ PASS

Frozen Candidate S1:

```text
Symbol: XAUUSD
Entry TF: M5
Direction: SELL only
Trigger: EMA9/21 bearish crossover
Context TF: M15
Context: EMA20 < EMA50
Research horizon: 10 minutes
Trading: disabled
```

---

## P2F.5A — 10-Minute Excursion Research
**Status:** ✅ FULL PASS

Validated:

- 50 valid opportunities
- 29 winners
- 21 losers

Important path findings:

- winner median MAE ≈ 0.33 ATR
- loser median MAE ≈ 0.95 ATR
- winner median MFE ≈ 1.04 ATR
- many winners experienced small adverse movement before continuation

---

## P2F.5B — Risk Envelope Simulation
**Status:** ✅ PASS

Tested:

- SL 0.75 ATR
- SL 1.00 ATR
- SL 1.25 ATR

Provisional champion:

```text
SL = 1.25 ATR(M5,14)
Risk reference = 0.50%
Primary exit = 10-minute time exit
```

Why 1.25 ATR was selected:

- PF ≈ 1.90
- Max DD ≈ -1.72%
- winner survival ≈ 96.6%
- strongest trimmed expectancy
- early and late chronological segments both positive

Not production-approved.

---

## P2F.6 — Time Exit
**Status:** ✅ FULL PASS

Compared:

- 5 minutes
- 10 minutes
- 15 minutes

Result:

```text
10m = provisional champion
```

10-minute metrics:

- mean ≈ +0.202R
- median ≈ +0.120R
- PF ≈ 1.90
- trimmed mean ≈ +0.125R
- Max DD ≈ -1.72%

5m was too early.
15m showed too much giveback / regime dependence.

---

## P2F.7 — Profit Retention V1
**Status:** ✅ RESEARCH PASS

Tested:

- CONTROL
- BE_050
- LOCK
- TRAIL

Development result:

BE_050 improved several metrics, but only a small number of trades changed and the paired confidence interval crossed zero.

Decision:

```text
CONTROL remains champion
BE_050 becomes primary challenger
```

---

## P2F.8 — Cost Gate
**Status:** 🟡 CONDITIONAL PASS

Development edge remained viable around approximately +1 to +2 bps extra cost.

Important:

- executable spread already embedded
- extra bps represent additional commission/slippage/latency stress
- do not double-charge spread

---

## P2F.9 — Champion / Challenger Freeze
**Status:** ✅ PASS

Frozen:

### Champion
```text
CONTROL
SELL M5 EMA9/21
M15 EMA20 < EMA50
SL = 1.25 ATR
Exit = 10m
Retention = NONE
```

### Primary Challenger
```text
BE_050
same as CONTROL
+ move stop to 0R after +0.50R
```

No further tuning before OOS.

---

## P2F.10 — Candidate S1 OOS Validation
**Status:** ❌ FAIL_KEEP_CONTROL

OOS:
2026-02-10 → 2026-06-30

CONTROL and BE_050 both failed to validate robust positive expectancy.

Conclusion:

```text
Candidate S1 rejected for production.
```

---

# 9. P2F.11 — Post-OOS Failure Research

## P2F.11A — Failure Decomposition
**Status:** ✅ COMPLETE

Key findings:

1. regime dependency
2. continuation decay
3. lower-volatility mix
4. increased giveback
5. spread was not the primary failure

Development vs OOS showed that the strategy did not generalize cleanly.

---

## P2F.11B — Context Drift Analysis
**Status:** ✅ FULL PASS

Findings:

- M5 ATR relationship weakened materially
- M5 fast slope relationship weakened
- spread/ATR relationship weakened
- static thresholds derived from development did not transfer
- M15 bearish gate frequency increased while its information content weakened

Conclusion:

> S2 should not simply be S1 + a fixed ATR threshold.

---

## P2F.11C — Adaptive Profit Retention V2
**Status:** ❌ NO_RETENTION_POLICY_PASS

Tested:

- CONTROL
- LEGACY_BE
- STEPLOCK
- GIVEBACK

None produced a sufficiently robust new retention policy.

Important result:

- some policies improved headline averages
- robustness, clipping, tail, and chronological checks failed

Decision:

```text
S2 retention = NONE
```

---

# 10. P2F.12 — Candidate S2

## P2F.12A — Offline Discovery
**Status:** 🟡 PROVISIONAL PASS

Frozen Candidate S2:

```text
P2F12_CANDIDATE_S2_EDGE_STATE_V1

Base:
SELL M5 EMA9/21 bearish crossover
+
M15 EMA20 < EMA50

Warmup:
20 valid completed shadow outcomes

Eligible only if ALL:
last20 mean shadow 10m return > +1.0 bps
last20 median > 0
last5 mean > 0

Blocked signals remain shadow-observed.

SL:
1.25 ATR(M5,14)

Exit:
10-minute TIME EXIT

Retention:
NONE

Reference risk:
0.50%
```

---

## P2F.12B — MQL5 Functional Verification
**Status:** ✅ PASS

---

## P2F.12C — Full MQL5 Reproduction
**Status:** ✅ PASS

Important reproduction results:

- 343 total S1 events
- 340 valid
- 96 S2 ELIGIBLE decisions
- 94 valid S2 selected events
- exact offline/MQL5 selected set match = 94/94
- causal gate reconstruction = exact

Development @ +1 bps:

- mean ≈ +0.2391R
- median ≈ +0.1871R
- PF ≈ 1.91
- trimmed ≈ +0.1050R
- mean ex-best1 ≈ +0.1156R
- return @0.5% ≈ +11.63%
- Max DD ≈ -2.61%

Strong development evidence, not production approval.

---

# 11. P2F.13 — S2 Cost / Robustness Gate

**Status:** 🟡 CONDITIONAL PASS

Cost ladder showed:

### +1 bps
- mean +0.239R
- PF 1.91
- trimmed +0.105R
- ex-best1 +0.116R
- strong development result

### +2 bps
- mean +0.182R
- PF 1.63
- aggregate positive
- statistical certainty weaker

### +3 bps
- trimmed mean approximately zero / negative
- tail and chronological robustness deteriorated

Development operating envelope:

```text
approximately <= 2 bps extra cost
```

This was not a production cost approval.

---

# 12. Independent Audit of S2 / P2F.13

**Status:** ✅ COMPLETE

Independent verdict:

```text
CONTINUE_P2F14_WITH_AUDIT_FIXES_ONLY
```

Audit conclusions:

- causality: PASS
- implementation reproduction: PASS
- cost accounting: PASS
- statistical robustness: FAIL
- selection bias: HIGH
- overfitting risk: HIGH
- tail dependence: HIGH
- regime dependence: HIGH
- production ready: NO

Important outlier:

2026-02-12 macro move dominated a large share of development profit.

---

# 13. Audit Fixes

**Status:** ✅ COMPLETE

Completed:

- Candidate S2 queue-stall protection
- failed-event retry/quarantine handling
- shutdown observability
- actual stop-fill accounting
- type/compile warnings
- regression verification

January post-patch output reproduced the pre-patch Candidate S2 result exactly.

---

# 14. P2F.14 — Controlled Layer Engine

## P2F.14A — Functional Verification
**Status:** ✅ PASS

Arms:

- CONTROL_L1
- PYRAMID_L3
- PYRAMID_L5
- PYRAMID_L7
- PYRAMID_L10

Rules:

- add only into winners
- never average down
- previous layers protected
- one base opportunity remains the statistical unit

Engineering worked correctly.

---

## P2F.14B — Full Jan–Jun Layer Comparison
**Status:** ❌ FAIL_KEEP_CONTROL

Key result:

Layering increased headline mean for some arms, but typical-trade robustness deteriorated.

Observed problems:

- median incremental result negative
- trimmed incremental result negative
- ex-best1 often negative
- late-period performance weak
- +2 bps robustness weak
- strong tail dependence
- one large macro event dominated incremental results

Official decision:

```text
Layer engine engineering: PASS
Layer strategy promotion: FAIL_KEEP_CONTROL
```

Important lesson:

> Layers cannot create alpha. They magnify whatever alpha already exists.

The next layer engine must be built only after stronger S3 alpha exists, and should use market-state continuation triggers rather than fixed-time checkpoints.

---

# 15. P2F.15 — Fresh OOS Validation

Fresh OOS:
2026-07-01 → 2026-08-31

Burn-in:
June 2026

**Status:** ❌ FAIL

Valid S2 selected:
N = 25

### Gross
- mean +0.0719R
- median +0.2467R
- PF 1.30
- win rate 64%

### +1 bps
- mean -0.0066R
- median +0.1168R
- PF 0.975
- trimmed -0.0041R
- mean ex-best1 -0.0548R

### +2 bps
- mean -0.0851R
- PF 0.716

Frozen pre-registered verdict:

```text
FAIL
```

Candidate S2 is not production approved.

Jul–Aug 2026 is now consumed and may never be called fresh OOS again.

---

# 16. P2F.15A — Fresh OOS Failure Decomposition

**Status:** ✅ COMPLETE

Primary findings:

## Root Cause #1 — Winner / Continuation Magnitude Compression
Development selected 10m executable move was much larger than fresh OOS.

Positive-return frequency did not collapse dramatically.

The major failure was:

```text
when right,
the move became much smaller
```

---

## Root Cause #2 — Lower Volatility Increased Cost in R
Fresh OOS stop distances were materially smaller in bps.

This made the same fixed execution cost consume more R per trade.

---

## Root Cause #3 — S2 Gate Generalization Weakness
The gate retained some sorting ability but no longer selected sufficiently large continuation moves.

---

## Root Cause #4 — Higher Fast Adverse Excursion
Hard-stop rate increased.

However:

```text
SL execution itself was not the primary problem.
```

---

## Official Interpretation

The correct diagnosis is:

> Gross continuation alpha weakened substantially, while lower volatility made the remaining edge more expensive to monetize.

Not:

> Fees alone killed a profitable system.

---

# 17. P2F.16 — Production Readiness

**Status:** ⛔ BLOCKED

Candidate S2 failed fresh OOS.

Production-readiness evaluation must not continue using S2 as if it were validated.

---

# 18. Candidate S2 Status

**Status:** 📦 ARCHIVED / REFERENCE ONLY

Candidate S2 is preserved for reproducibility and comparison.

It must not be rescued by:

- changing 20/5 windows
- changing +1 bps threshold
- changing EMA periods
- changing ATR multiplier
- adding layers
- increasing leverage
- increasing risk
- retesting Jul–Aug as OOS

---

# 19. S3 Program — New Alpha Research

The S3 program begins after Candidate S2 fresh-OOS failure.

Main objective:

> Find a causal entry/event structure with materially larger gross price displacement before considering position scaling.

---

# 20. S3.0 — M15 Bearish Context Event-Generator Control

**Status:** ✅ FULL PASS — `KEEP_FOR_S3_1`

Research question:

> Does M5 EMA9/21 bearish crossover add timing information beyond simply sampling ordinary M5 bars while M15 EMA20 < EMA50?

Population:

```text
all completed M5 bars
while completed M15 EMA20 < EMA50
```

Groups:

```text
CROSSOVER_EVENT
vs
CONTEXT_ONLY
```

Full Jan–Aug research:

- ~22,077 bearish-context M5 events
- ~433 bearish crossover events
- 8 forward horizons per event

Primary horizon:
10 minutes

---

## S3.0 Jan–Jun

Crossover:

- mean ≈ +2.682 bps
- median ≈ +0.989 bps
- trimmed ≈ +0.817 bps

Frequency-matched control:

- mean ≈ -0.669 bps

Incremental:

- mean ≈ +3.350 bps
- trimmed ≈ +1.356 bps

---

## S3.0 Jul–Aug

Crossover:

- mean ≈ +0.797 bps
- median ≈ +1.178 bps
- trimmed ≈ +0.599 bps

Matched control:

- mean ≈ -3.613 bps

Incremental:

- mean ≈ +4.409 bps
- trimmed ≈ +3.578 bps

---

## Combined S3.0

Combined matched-control incremental mean:

≈ +3.564 bps

Day-cluster bootstrap 95% CI:

```text
approximately +1.02 → +7.10 bps
```

Result:

```text
KEEP_FOR_S3_1
```

Important interpretation:

```text
M5 EMA9/21
❌ not primary alpha
✅ still useful as an event / timing generator
```

---

# 21. S3.1 — Paired Delayed Entry Research

**Status:** ➡️ NEXT

This is the immediate next stage.

Primary experiment:

```text
SAME CROSSOVER EVENT

CONTROL
entry at crossover event

vs

DELAYED
entry one completed M5 bar later
```

Only entry timing changes.

Do NOT add in the primary arm:

- ATR filter
- S2 gate
- M15 persistence gate
- spread filter
- structural pattern
- new SL
- layering

Purpose:

> Determine whether the crossover is informative but systematically entered too early.

Key metrics:

- entry-price improvement
- 10m / 15m / 30m executable return
- MAE improvement
- MFE preservation
- mean
- median
- 10% trimmed mean
- ex-best1
- monthly consistency
- paired day-cluster bootstrap

Possible decisions:

```text
DELAYED ENTRY IMPROVES GROSS EDGE
→ continue S3 delayed-entry branch

NO IMPROVEMENT
→ do not force delayed entry
→ move toward structural trigger research
```

---

# 22. S3.2 — Cost Coverage Gate

**Status:** 🔒 WAIT

Only starts after a stronger gross edge exists.

Purpose:

```text
expected move
>>
spread + commission + slippage
```

This stage must not be used to create alpha from a weak signal.

It only removes opportunities that cannot economically pay for execution.

---

# 23. S3.3 — Structural Pullback / Lower-High Trigger

**Status:** ⬜ HOLD / FUTURE CANDIDATE

Candidate concept:

```text
M15 bearish
+
pullback
+
lower high / failed retracement
+
M5 rejection / continuation
→ SELL
```

This is likely the strongest alternative if delayed-entry research fails or if EMA event timing proves insufficient.

Potential features:

- lower-high structure
- retracement depth
- failed breakout
- local swing high
- rejection bar
- M1 continuation confirmation
- range expansion

Risk:

This stage contains more degrees of freedom and therefore more overfitting risk.

It must be pre-registered carefully.

---

# 24. S3.D — BUY / SELL Symmetry Control

**Status:** ⬜ DIAGNOSTIC / LOW PRIORITY

Purpose:

Determine whether the context effect is a real trend-continuation effect or only a SELL-specific historical bias.

This is a control experiment, not the primary strategy branch.

---

# 25. Future Layer Program

**Status:** 🔒 WAIT FOR STRONGER S3 ALPHA

The old fixed-time layer strategy failed.

Future layer research must use **market-state confirmation**, not simply elapsed-time checkpoints.

Candidate future triggers:

- new lower low
- break and retest
- renewed M1 continuation
- new M5 bearish impulse
- favorable excursion milestone
- pullback followed by continuation
- volatility expansion

Core rule:

```text
Pyramid into proven winners.
Never average into losers.
```

---

# 26. Future Layer Research Arms

Planned caps:

```text
CONTROL_L1
PYRAMID_L3
PYRAMID_L5
PYRAMID_L7
PYRAMID_L10
```

The number is only a maximum cap.

The engine must never force all layers.

Every additional layer must require:

- existing pyramid profitable
- prior layers protected
- continuation still valid
- cost still acceptable
- total downside still within risk budget

---

# 27. Layer Pass / Fail Philosophy

Layering passes only if improvement survives at the **base-opportunity level**.

Required future metrics:

- incremental mean R > 0
- incremental median >= 0
- 10% trimmed incremental mean > 0
- ex-best1 > 0
- ex-top3 > 0
- chronological robustness
- cost robustness
- no single macro event dominance
- acceptable drawdown
- improved expected log growth

If only headline mean improves because of one giant trend:

```text
FAIL_KEEP_CONTROL
```

---

# 28. Data Classification

## Jan–Jun 2026
**Status:** CONTAMINATED RESEARCH / DEVELOPMENT DATA

Can be used for:

- research
- decomposition
- hypothesis generation
- paired comparisons

Cannot be called fresh OOS.

---

## Jul–Aug 2026
**Status:** CONSUMED OOS → CONTAMINATED RESEARCH DATA

Was used once for pre-registered Candidate S2 OOS.

Can now be used for failure analysis and S3 research.

Cannot ever be reused as fresh OOS.

---

## Sep 2026 onward
**Status:** 🔒 RESERVED FOR FUTURE VALIDATION / FORWARD SHADOW

Do not inspect future results while designing Candidate S3.

---

# 29. Current Frozen Decisions

```text
Candidate S1
❌ rejected for production

Candidate S2
❌ failed fresh OOS
📦 archived

P2F.14 fixed-time layering
❌ strategy failed
✅ engineering reusable

M5 EMA9/21
❌ primary alpha
✅ event / timing generator

M15 EMA20 < EMA50
✅ retained as bearish context candidate

S3.0
✅ KEEP_FOR_S3_1

Production trading
❌ not approved
```

---

# 30. Current Progress Snapshot

```text
FOUNDATION
P0.x                          ✅ COMPLETE

BASELINE
P1.x                          ✅ COMPLETE
Baseline profitability         ❌ FAIL

FAST RESEARCH
P2F.0                         ✅ COMPLETE
P2F.1                         ✅ COMPLETE
P2F.2 Raw EMA Alpha           ❌ FAIL
P2F.3 Context Discovery       ✅ PASS
P2F.4 Candidate S1            ✅ PASS
P2F.5 Risk Architecture       ✅ PASS
P2F.6 Time Exit               ✅ PASS
P2F.7 Retention V1            ✅ RESEARCH PASS
P2F.8 Cost Gate               🟡 CONDITIONAL
P2F.9 Champion Freeze         ✅ PASS
P2F.10 S1 OOS                 ❌ FAIL

POST-OOS
P2F.11A Failure Analysis      ✅ COMPLETE
P2F.11B Context Drift         ✅ COMPLETE
P2F.11C Retention V2          ❌ NO POLICY PASS

CANDIDATE S2
P2F.12                        ✅ DEVELOPMENT COMPLETE
P2F.13                        🟡 CONDITIONAL PASS
Independent Audit             ✅ COMPLETE
Audit Fixes                   ✅ PASS

LAYER RESEARCH
P2F.14A Engineering           ✅ PASS
P2F.14B Strategy              ❌ FAIL_KEEP_CONTROL

FRESH VALIDATION
P2F.15 S2 Fresh OOS           ❌ FAIL
P2F.15A Failure Decomposition ✅ COMPLETE
P2F.16 Production Readiness   ⛔ BLOCKED

S3
S3.0 Event Generator Control  ✅ FULL PASS
S3.1 Paired Delayed Entry     ➡️ NEXT
S3.2 Cost Coverage            🔒 WAIT
S3.3 Structural Trigger       ⬜ HOLD
S3.D Symmetry Control         ⬜ OPTIONAL

FUTURE LAYER ENGINE
Market-state pyramiding       🔒 WAIT FOR STRONGER ALPHA

FORWARD VALIDATION
Sep-2026 onward               🔒 RESERVED
```

---

# 31. Immediate Next Action

## S3.1 — Paired Delayed Entry

The next implementation should create a research-only paired dataset.

For every valid S3 crossover event:

```text
CONTROL
entry now

DELAYED
entry one completed M5 bar later
```

The experiment must preserve the same base opportunity.

Primary question:

> Does waiting one M5 bar improve executable entry quality enough to produce materially larger gross edge without adding new filters?

No production trading should be enabled.

---

# 32. What Must NOT Be Done Next

Do not:

- retune S2 thresholds
- reopen Jul–Aug as OOS
- increase risk
- increase leverage
- add more fixed-time layers
- optimize EMA periods
- create hour/month filters from historical winners
- promote 60m/90m findings directly to production
- mix delayed entry with multiple new filters in the same primary experiment
- treat win rate alone as alpha

---

# 33. Long-Term Target Architecture

The long-term RamusenEA architecture should become:

```text
MARKET
   ↓
M15 REGIME / CONTEXT
   ↓
HIGH-QUALITY EVENT
   ↓
ENTRY TIMING / STRUCTURE
   ↓
GROSS EDGE CHECK
   ↓
COST COVERAGE
   ↓
RISK SIZING
   ↓
INITIAL POSITION
   ↓
WINNER CONFIRMED?
   │
   ├── NO → manage / exit
   │
   └── YES
        ↓
   PROTECT PRIOR RISK
        ↓
   ADD LAYER
        ↓
   CONTINUATION CONFIRMED?
        ↓
   ADD AGAIN IF SAFE
        ↓
   EXIT / PROFIT RETENTION
        ↓
   COMPOUND EQUITY
```

The system must earn the right to layer.

Layering is a capital-efficiency amplifier, not a substitute for alpha.

---

# 34. Final Project Status

```text
Current production candidate:
NONE

Latest failed production candidate:
Candidate S2

Current research branch:
S3

Latest successful research stage:
S3.0 Event Generator Control

Immediate next stage:
S3.1 Paired Delayed Entry

Layer engine:
WAITING FOR STRONGER S3 ALPHA

Production readiness:
BLOCKED

Future clean validation:
Sep-2026 onward / forward shadow
```

---

# 35. Current Official Decision

## CURRENT DECISION

**BUILD S3 ALPHA FIRST.**

Do not restart aggressive layer research until the base opportunity has materially stronger and more robust gross continuation edge.

After S3 alpha is demonstrated:

```text
S3 ALPHA
   ↓
COST-AWARE VALIDATION
   ↓
CONTROL_L1
   ↓
MARKET-STATE LAYER ENGINE
   ↓
FORWARD SHADOW
   ↓
PRODUCTION READINESS
```

This is the current official roadmap for RamusenEA as of 2026-09-05.
