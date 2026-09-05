# RamusenEA — Latest Research & Development Roadmap

**Project:** RamusenEA  
**Platform:** MetaTrader 5 / MQL5  
**Market:** XAUUSD  
**Style:** Fast intraday / scalping  
**Primary holding target:** 5–30 minutes  
**Document date:** 2026-09-05  
**Current program:** S3 Alpha Research  
**Production status:** **NOT APPROVED**

---

## 1. Executive Summary

RamusenEA has completed its infrastructure, baseline strategy, fast-signal research, Candidate S1, Candidate S2, controlled-layer research, fresh OOS validation, and two S3 mechanism studies.

The current conclusions are:

- Raw M5 EMA9/21 crossover is **not strong enough as primary alpha**.
- M15 EMA20/50 bearish context remains useful as context.
- Candidate S1 failed OOS.
- Candidate S2 failed a pre-registered fresh OOS test.
- Old fixed-time pyramiding passed engineering verification but **failed strategically** because it amplified rare tail winners and weakened typical-opportunity robustness.
- P2F.15A showed that the main S2 failure was **gross alpha decay / winner-magnitude compression**, not leverage, not execution bugs, and not fees alone.
- S3.0 showed EMA9/21 still contains useful **event/timing information** inside M15 bearish context.
- S3.1 completed the fixed-delay test and **rejected the blanket delay mechanism**.
- No production-worthy alpha currently exists.
- The next alpha family is **S3-B V1 — Confirmed Lower-High Rejection Continuation**.
- Layering remains disabled until stronger base alpha is demonstrated.

---

## 2. Status Legend

| Status | Meaning |
|---|---|
| ✅ COMPLETE / PASS | Stage completed and objective passed |
| 🟡 CONDITIONAL / RESEARCH PASS | Useful evidence, not production approval |
| ❌ FAIL | Stage failed its gate |
| ❌ FAIL_KEEP_CONTROL | Challenger failed; retain reference/control only |
| 🔒 LOCKED | Frozen or reserved |
| ⛔ BLOCKED | Cannot proceed until prior requirements pass |
| ➡️ NEXT | Immediate next stage |
| ⬜ PENDING | Planned but not started |
| 📦 ARCHIVED | Preserved for reproducibility/reference only |

---

## 3. Non-Negotiable Research Rules

- No martingale.
- No averaging down.
- No grid.
- No forced daily profit target.
- No leverage/risk increase to hide weak expectancy.
- One major hypothesis change per experiment whenever possible.
- Use executable BID/ASK semantics.
- Never double-count spread.
- Keep development, contaminated research, fresh OOS, and future validation separated.
- Multiple layer tickets from one setup remain **one independent market opportunity** statistically.
- Pyramiding may only add to **protected winners**.
- September 2026+ remains reserved for future validation and must not be inspected during S3 discovery.

---

# 4. Foundation & Baseline

## P0.x — Foundation & Safety
**Status:** ✅ COMPLETE

Completed:

- modular EA structure
- fail-closed defaults
- broker-aware risk sizing
- market snapshot
- magic ownership
- duplicate-position block
- spread guard
- BUY/SELL execution self-test
- SL/TP attachment
- restart/recovery safety
- structured logging

## P1.x — Baseline Strategy
**Status:** ✅ ENGINEERING COMPLETE / ❌ PROFITABILITY FAIL

Initial XAUUSD H1 EMA20/50 baseline:

- 9 trades
- 1 win / 8 losses
- PF ≈ 0.498
- Net PnL ≈ -$184.69
- Return ≈ -1.85%

The baseline became a control, not a production candidate.

---

# 5. P2F — Fast Intraday / Scalping Program

## P2F.0 — Fast Engine Redesign
**Status:** ✅ COMPLETE

Architecture became:

```text
M15 = context / regime
M5  = primary setup
M1  = optional precision later
```

## P2F.1 — Minute Signal Research
**Status:** ✅ COMPLETE

## P2F.2 — Raw EMA9/21 Alpha Gate
**Status:** ❌ FAIL

Raw crossover did not produce robust standalone alpha.

## P2F.3 — Context / Regime Discovery
**Status:** ✅ PASS

Key development discovery:

```text
SELL M5 EMA9/21 bearish crossover
+
M15 EMA20 < EMA50
```

## P2F.4 — Candidate S1 Entry Gate
**Status:** ✅ PASS

## P2F.5 — Risk Architecture
**Status:** ✅ PASS

Provisional envelope:

```text
SL = 1.25 ATR(M5,14)
Risk reference = 0.50%
```

## P2F.6 — Time Exit
**Status:** ✅ PASS

Provisional champion:

```text
10-minute TIME EXIT
```

## P2F.7 — Profit Retention V1
**Status:** ✅ RESEARCH PASS

BE_050 improved development metrics but did not provide strong enough paired evidence for promotion.

## P2F.8 — Cost Gate
**Status:** 🟡 CONDITIONAL PASS

## P2F.9 — Champion / Challenger Freeze
**Status:** ✅ PASS

Champion:

```text
CONTROL
SL 1.25 ATR
10m TIME EXIT
Retention NONE
```

Primary challenger:

```text
BE_050
```

## P2F.10 — Candidate S1 OOS
**Status:** ❌ FAIL_KEEP_CONTROL

Candidate S1 rejected for production.

---

# 6. P2F.11 — Post-OOS Research

## P2F.11A — Failure Decomposition
**Status:** ✅ COMPLETE

Main findings:

- regime dependency
- continuation decay
- lower-volatility mix
- higher giveback
- spread not primary root cause

## P2F.11B — Context Drift
**Status:** ✅ COMPLETE

Static development relationships weakened in OOS.

## P2F.11C — Adaptive Retention V2
**Status:** ❌ NO_RETENTION_POLICY_PASS

Decision:

```text
S2 retention = NONE
```

---

# 7. P2F.12 — Candidate S2

**Status:** ✅ DEVELOPMENT COMPLETE

Frozen Candidate S2:

```text
P2F12_CANDIDATE_S2_EDGE_STATE_V1

Base:
SELL M5 EMA9/21 bearish crossover
+
M15 EMA20 < EMA50

Warmup = 20

Eligible if ALL:
last20 mean shadow 10m return > +1.0 bps
last20 median > 0
last5 mean > 0

SL = 1.25 ATR
Exit = 10m TIME EXIT
Retention = NONE
Reference risk = 0.50%
```

Development @ +1 bps:

- N = 94
- mean ≈ +0.2391R
- median ≈ +0.1871R
- PF ≈ 1.91
- trimmed ≈ +0.1050R
- ex-best1 ≈ +0.1156R
- return @0.5% ≈ +11.63%
- Max DD ≈ -2.61%

---

# 8. P2F.13 — S2 Cost / Robustness

**Status:** 🟡 CONDITIONAL PASS

Development operating envelope was approximately:

```text
<= 2 bps extra cost
```

This was not production approval.

Independent audit found:

- causality: PASS
- implementation reproduction: PASS
- cost accounting: PASS
- statistical robustness: FAIL
- selection bias: HIGH
- overfitting risk: HIGH
- tail dependence: HIGH
- regime dependence: HIGH
- production ready: NO

Audit fixes and regression checks were completed.

---

# 9. P2F.14 — Controlled Layer Engine

## P2F.14A — Engineering
**Status:** ✅ PASS

Tested:

- CONTROL_L1
- PYRAMID_L3
- PYRAMID_L5
- PYRAMID_L7
- PYRAMID_L10

## P2F.14B — Strategy
**Status:** ❌ FAIL_KEEP_CONTROL

Problems:

- negative incremental median
- negative trimmed incremental result
- weak ex-best1 robustness
- high tail dependence
- chronological weakness
- one macro event dominated the incremental benefit

Jul–Aug old layer incremental results were negative even before extra-cost stress.

Conclusion:

> Old fixed-time layering is rejected as a strategy. Engineering infrastructure remains reusable.

---

# 10. P2F.15 — Fresh OOS Validation

**Status:** ❌ FAIL

Fresh OOS: 2026-07-01 → 2026-08-31  
Valid S2 selected: N = 25

Gross:

- mean ≈ +0.0719R
- median ≈ +0.2467R
- PF ≈ 1.30
- win rate ≈ 64%

+1 bps:

- mean ≈ -0.0066R
- median ≈ +0.1168R
- PF ≈ 0.975
- trimmed ≈ -0.0041R
- ex-best1 ≈ -0.0548R

+2 bps:

- mean ≈ -0.0851R
- PF ≈ 0.716

Candidate S2 is not production approved.

Jul–Aug 2026 is now contaminated research data and can never be called fresh OOS again.

---

# 11. P2F.15A — Fresh OOS Failure Decomposition

**Status:** ✅ COMPLETE

Primary causes:

1. winner / continuation magnitude compression
2. lower volatility increased cost in R
3. S2 gate generalization weakness
4. higher adverse excursion / stop pressure

Interpretation:

> Gross continuation alpha weakened substantially, and lower volatility made the remaining edge more expensive to monetize.

---

# 12. P2F.16 — Production Readiness

**Status:** ⛔ BLOCKED

No current production candidate exists.

Candidate S2 is now:

```text
📦 ARCHIVED / REFERENCE ONLY
```

Do not rescue it by changing EMA periods, adaptive windows, thresholds, ATR multiplier, risk, leverage, or layer count.

---

# 13. S3 Program — New Alpha Research

Main objective:

> Find a causal market-structure entry with materially larger gross displacement before scaling exposure.

---

# 14. S3.0 — Event Generator Control

**Status:** ✅ FULL PASS

Result:

```text
M5 EMA9/21
❌ primary alpha
✅ event/timing information

M15 EMA20 < EMA50
✅ retained context candidate
```

---

# 15. S3.1 — Paired Delayed Entry Mechanism

**Status:** ❌ COMPLETE — `DELAY_MECHANISM_REJECTED`

Research-only contaminated Jan–Aug sample.

Equal-hold paired cohort: **428 complete opportunities**.

| Arm | Mean executable bps | Increment vs CONTROL |
|---|---:|---:|
| CONTROL | +2.299 | — |
| DELAY_1 | +1.780 | -0.519 |
| DELAY_3 | +1.440 | -0.859 |
| DELAY_5 | +0.984 | -1.315 |

Additional findings:

- all delays failed robust trimmed comparisons
- ex-best1 comparisons failed
- average MAE increased
- MFE was not improved enough to rescue expectancy
- fixed delay did not provide a repeatable better SELL entry
- no robust positive incremental delay evidence was found
- no additional delay values were tested
- zero trades were submitted

Official decision:

```text
DELAY_MECHANISM_REJECTED
```

Fixed-delay research is closed.

Do not try DELAY_2, DELAY_4, DELAY_6, delay-second optimization, or filters to rescue fixed delay.

---

# 16. S3-B V1 — Confirmed Lower-High Rejection Continuation

**Status:** 📋 FROZEN SPEC / ➡️ NEXT

This is the current next-stage alpha family.

No S3-B outcomes have been used to tune this V1 definition.

## Hypothesis

A bearish context plus a completed pullback that fails below the previous swing high may identify renewed selling with more remaining displacement than EMA crossover or fixed delay.

The trigger is market-state confirmation, not elapsed time.

## Frozen Pivot Rules

Pivot high at `j`:

```text
High[j] > High[j-1]
AND
High[j] > High[j+1]
```

Pivot low:

```text
Low[j] < Low[j-1]
AND
Low[j] < Low[j+1]
```

A pivot becomes known only after the right-neighbor bar completes.

No hindsight replacement is allowed.

## Structural Sequence

When a new pivot high `Q` is confirmed:

- `P` = immediately preceding recognized pivot high
- `L` = latest recognized pivot low strictly between `P` and `Q`

Require:

```text
P.index < L.index < Q.index
Q.high < P.high
L.low < Q.low
```

## Arming

At the first tick after Q's right-neighbor `C` completes:

Require completed M15:

```text
EMA20 < EMA50
```

Freeze:

- P / L / Q / C
- recognition timestamps
- original ATR14
- arming BID/ASK
- M15 context

No EMA crossover is required.

## Breakdown

Freeze:

```text
B = Low[C]
```

Inspect only the next **3 completed M5 bars**.

Trigger first `K` where:

```text
Close[K] < B
AND
Close[K-1] >= B
```

M15 must remain bearish at K close.

## Invalidation

Before trigger evaluation:

```text
Close >= Q.high
→ INVALIDATE
```

Invalidation has priority.

## Expiration

No trigger within 3 completed M5 bars:

```text
EXPIRE
```

Do not optimize this window in V1.

## Entry

First valid SELL BID after trigger bar K completes, within 30 seconds.

---

# 17. S3-B V1 Research Arms

Exactly two arms:

### ARMING_CONTROL
Enter SELL at Q causal arming instant.

### S3B_CONFIRMED
Enter only after frozen breakdown confirmation.

If EXPIRED, CONTEXT_FAILED, or INVALIDATED:

```text
ABSTAIN
```

True abstention policy PnL = 0 and transaction cost = 0.

Missing data is not abstention.

---

# 18. S3-B V1 Primary Label

Primary horizon:

```text
10 minutes from each arm's actual entry
```

SELL executable return:

```text
entry BID → future ASK
```

Primary result is uncensored gross executable return.

No layering.  
No S2 gate.  
No new ATR filter.  
No session filter.  
No profit retention.

---

# 19. S3-B V1 Secondary Structural Stop

Frozen stop:

```text
max observed ASK during completed Q pivot bar
+
one symbol trade tick
```

First touch:

```text
ASK >= stop
```

Fill at actual ASK including stop-through.

This is a secondary risk diagnostic only.

---

# 20. S3-B V1 Cost View

Executable spread is already embedded.

Additional one-ticket round-trip stress:

```text
0
0.5
1.0
1.5
2.0 bps
```

Do not double-count spread.

---

# 21. S3-B V1 Decision Boundary

Do not promote from triggered-subset mean alone.

Primary comparison is policy-level across **all eligible Q opportunities**.

Retain for later cost research only if:

- triggered absolute mean > 0
- triggered median > 0
- triggered trimmed mean > 0
- triggered ex-best1 > 0
- all-opportunity paired mean > 0
- all-opportunity paired trimmed > 0
- paired ex-best1 > 0
- paired ex-top3 > 0
- paired day-cluster lower bound > 0
- improvement survives chronological blocks
- improvement survives leave-one-month-out
- +1 bps mean > 0
- +1 bps trimmed mean > 0
- no single opportunity/month dominates

These are contaminated discovery criteria, not production approval.

---

# 22. Immediate Next Action — Implement S3-B V1

**Status:** ➡️ NEXT

Create:

```text
Include/RamusenEA/
└── S3BLowerHighContinuationResearch.mqh
```

Minimal orchestration changes only:

```text
Include/RamusenEA/Config.mqh
Experts/RamusenEA/RamusenEA.mq5
```

Requirements:

- default disabled
- tester-only
- trading disabled
- fail closed
- no production execution dependency
- no layer dependency
- no S2 dependency
- completed bars only
- no hindsight pivot replacement
- recognition timestamps separate from pivot timestamps

---

# 23. S3-B Functional Test

After clean compile:

```text
Symbol    : XAUUSD
Timeframe : M5
Model     : Every tick based on real ticks

From : 2026-01-01
To   : 2026-01-06 exclusive
```

Verify:

- pivot causality
- P/L/Q recognition
- Q confirmation
- B frozen correctly
- invalidation priority
- 3-bar expiration
- completed M15 context
- first executable BID
- 10m ASK exit
- MFE/MAE
- structural stop
- missing vs abstention
- zero orders

Only after functional PASS:

```text
ONE Jan–Aug contaminated discovery run
```

---

# 24. Layer Program

**Status:** 🔒 DISABLED

Current research cap:

```text
1
```

No new L3/L5/L7/L10 research during S3-B discovery.

Only after stronger base alpha and cost robustness:

```text
CONTROL_L1
vs
L3_FIXED_TIME
vs
L3_MARKET_STATE
```

Maximum initial future layer cap:

```text
3
```

L5/L7/L10 remain blocked.

---

# 25. Data Classification

Jan–Jun 2026:

```text
CONTAMINATED RESEARCH
```

Jul–Aug 2026:

```text
CONSUMED OOS → CONTAMINATED RESEARCH
```

Sep-2026 onward:

```text
🔒 RESERVED FOR FUTURE VALIDATION / FORWARD SHADOW
```

Do not inspect September+ during S3-B discovery.

---

# 26. Current Progress Snapshot

```text
FOUNDATION
P0.x                              ✅ COMPLETE

BASELINE
P1.x                              ✅ COMPLETE
Baseline profitability             ❌ FAIL

FAST RESEARCH
P2F.0                             ✅ COMPLETE
P2F.1                             ✅ COMPLETE
P2F.2 Raw EMA Alpha               ❌ FAIL
P2F.3 Context Discovery           ✅ PASS
P2F.4 Candidate S1                ✅ PASS
P2F.5 Risk Architecture           ✅ PASS
P2F.6 Time Exit                   ✅ PASS
P2F.7 Retention V1                ✅ RESEARCH PASS
P2F.8 Cost Gate                   🟡 CONDITIONAL
P2F.9 Champion Freeze             ✅ PASS
P2F.10 S1 OOS                     ❌ FAIL

POST-OOS
P2F.11A Failure Analysis          ✅ COMPLETE
P2F.11B Context Drift             ✅ COMPLETE
P2F.11C Retention V2              ❌ NO POLICY PASS

CANDIDATE S2
P2F.12                            ✅ DEVELOPMENT COMPLETE
P2F.13                            🟡 CONDITIONAL PASS
Independent Audit                 ✅ COMPLETE
Audit Fixes                       ✅ COMPLETE

LAYER RESEARCH
P2F.14A Engineering               ✅ PASS
P2F.14B Strategy                  ❌ FAIL_KEEP_CONTROL

FRESH VALIDATION
P2F.15 S2 Fresh OOS               ❌ FAIL
P2F.15A Failure Decomposition     ✅ COMPLETE
P2F.16 Production Readiness       ⛔ BLOCKED

S3
S3.0 Event Generator Control      ✅ FULL PASS
S3.1 Fixed Delay                  ❌ REJECTED / CLOSED
S3-B Lower-High Continuation      ➡️ NEXT
S3-C Compression → Expansion      ⬜ HOLD
S3-D M15 Low Break                ⬜ HOLD

LAYER ENGINE
Current cap                       1
New layer research                🔒 WAIT
Future initial cap                3

FORWARD VALIDATION
Sep-2026 onward                   🔒 RESERVED
```

---

# 27. Current Official Decision

## BUILD S3-B V1 RESEARCH MODULE NEXT

Do not:

- optimize fixed delay again
- modify frozen S3-B definitions after viewing outcomes
- inspect September+ for discovery
- enable production trading
- enable layering
- add ATR/session/spread filters
- add S2 adaptive state
- run parameter sweeps

Long-term path:

```text
S3-B STRUCTURAL ALPHA
        ↓
FUNCTIONAL VERIFICATION
        ↓
JAN–AUG CONTAMINATED DISCOVERY
        ↓
S3-B DECISION
        ↓
COST ROBUSTNESS
        ↓
FREEZE CANDIDATE
        ↓
SEP+ FORWARD VALIDATION
        ↓
IF BASE ALPHA PASSES
        ↓
L1 vs L3 MARKET-STATE LAYER RESEARCH
        ↓
PRODUCTION READINESS
```

This is the current official RamusenEA roadmap as of 2026-09-05.
