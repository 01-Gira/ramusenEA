# RamusenEA — independent alpha and winner-pyramid research audit

Research date: 2026-09-05. Decision: **BUILD_S3_ALPHA; WAIT_FOR_STRONGER_ALPHA before layering. Immediate research cap: 1.**

No new alpha has been demonstrated. The strongest *untested structural hypothesis* is a confirmed lower-high rejection followed by renewed selling. The single next implementation should complete S3.1 paired entry timing, with a falsification mandate; the available snapshot diagnostic already rejects treating a blanket delay as a generally effective repair. Do not build a structural filter and a delay simultaneously.

All January–August 2026 results below are **contaminated research**, including July–August. September outcome records were excluded. No production MQL5 source was changed, no trades were submitted, and no new layer-trigger simulation was run. Offline audit calculations and design documents were created under `research/s3_independent_audit`.

## Audit scope and evidence quality

The workspace contains 20 MQL5 source files, approximately 19,718 lines, and exported research/trade CSVs. This was a source architecture and targeted correctness audit of signal, context, S2 state, tick labeling, execution safety and layer accounting, plus a schema/coverage review of all XAUUSD exports; it is not a claim that every journal line received a formal proof. All 20 source files are byte-identical to their copies in the installed MT5 MQL5 directory. Compiled EX5 provenance was not established. No Git repository or applicable AGENTS.md was present in the project.

Reviewed components:

| Source component | Role and disposition |
|---|---|
| RamusenEA.mq5 | Initialization, every-tick processing, bar-clock dispatch, research dependencies and trading route; reuse orchestration with explicit new research guards. |
| Config.mqh / Types.mqh / Market.mqh | Defaults, snapshots and contracts; trading defaults false, but quote validity must become explicit. |
| SignalEngine.mqh | EMA9/21 crossover on completed shifts 2/1; retain as event generator. |
| ScalpingContext.mqh / ScalpingEntryGate.mqh | Completed M15 context, ATR, candle and momentum fields; retain causal inputs, not selected profitability thresholds. |
| S30EventGeneratorControlResearch.mqh / SignalResearch.mqh | Forward BID/ASK labeling and event population; retain, with stronger provenance and missing-data handling. |
| ScalpingCandidateS2Research.mqh | FIFO completed shadow history, ATR stop and time exit; archive S2 decision rule, retain state-history pattern. |
| ScalpingExcursionResearch.mqh / ScalpingTimeExitResearch.mqh | Tick-path MFE/MAE and stop/time diagnostics; reuse concepts after explicit coverage checks. |
| ScalpingProfitRetentionResearch.mqh / ScalpingAdaptiveProfitRetentionResearch.mqh | Existing exit experiments; archive as prior trials, do not combine with S3.1. |
| ScalpingControlledLayerResearch.mqh | Existing fixed-time experiment; audit benchmark only. |
| RiskManager.mqh / PositionManager.mqh / Execution.mqh | Basic risk sizing and order wrappers; insufficient for a portfolio-aware pyramid. |
| TradeJournal.mqh / TradeDiagnostics.mqh | Deal reconciliation and historical excursions; retain observability concepts. |

Main artifacts and limits:

- S3.0: **22,077 events, 433 crossovers, 176,616 horizon rows**, zero duplicate event/horizon keys. Recalculated returns agree within 5×10⁻⁹ bps of stored values. There are 173,282 OK rows, 3,292 missing-target rows and 42 pending rows. Observed event coverage ends August 28, not August 31.
- At 10m, 430/433 crossover outcomes are usable: 342 January–June and 88 July–August. Common paired cohorts are 430/428/424 at original-event deadlines 10/15/30m. These horizons and tickets are repeated observations of the same opportunities.
- Context features join exactly by event milliseconds for **428 of 430** usable 10m crossovers. No nearest-time substitution was used.
- S2 development export has 96 eligible events but only **94 valid outcomes**. July–August contributes 25 valid eligible events. The later file starts in June; June is warmup/history, not an extra validation month. Development June is kept from the earlier run, and later-run June is excluded from pooled estimates.
- Dedicated excursion exports contain only **50 valid early-January–February events**; the time-exit export contains 50 valid events at three configurations/horizons. Repeated files are not independent evidence. They cannot establish a January–August delayed-entry MAE result.
- MetaQuotes-Demo XAUUSD monthly tick caches exist for January–August. Their existence does not prove complete real-tick coverage. They are terminal binary caches, not a portable verified BID/ASK dataset. No new export or replay was performed before the experiment design.
- Historical tester summaries corroborate the event counts. Inspection was restricted to records with January–August simulation timestamps. S3.0's final historical summary says `integrity=OK` despite missing rows; that flag is not a sufficient research acceptance gate.
- The deterministic daily frequency-matching/hash rule and original S3.0 analysis script are absent. The supplied +1.02 to +7.10 bps control-bootstrap interval therefore remains **user-supplied evidence, not independently reproduced here**. The audit reports absolute crossover returns and does not substitute an unmatched context estimate for that estimator.
- XAUUSD M5 closed-trade CSVs are empty. There is no usable actual commission/slippage calibration for this candidate. +1 bps is the historical nominal scenario, not proof of the intended broker's all-in non-spread cost.

Input/source hashes, terminal comparisons, opportunity rows and verification results accompany this report. `audit.py` is a reproducible standard-library offline calculation, not trading implementation.

## 1. Current system diagnosis

S2 fails on displacement and robustness. Its development gross mean of approximately +0.2959R drops to +0.0719R in July–August; +1 bps produces approximately −0.0066R. The shadow move falls from **9.9503 to 0.1924 bps**. The stopped executable price return averages only **0.0466 bps** in July–August. A positive risk-normalized mean can coexist with almost zero equal-notional price expectancy because each outcome has a different stop denominator. These quantities must not be interchanged.

The stop median contracts from **18.2414 to 12.5968 bps**; an extra 1 bps consumes about 0.0548R versus 0.0794R at those medians. This supports the secondary cost-in-R problem without replacing the primary gross-alpha diagnosis. The user's approximately 91%/9% attribution is not newly estimated by this audit.

The all-crossover population is broader than S2. Its 10m executable means are **2.6817 bps** in January–June and **0.7966 bps** in July–August. Combined mean is 2.2959, median 1.0259 and trimmed mean 0.7726 bps. At +1 bps the combined trimmed mean becomes **−0.2274 bps**, and July–August mean becomes **−0.2034 bps**. Relative timing information does not establish sufficient absolute alpha.

Measured S3.0 crossover spread drag also rises: approximately 0.3646 to 0.7548 bps on average. This is already inside executable return. It must not be subtracted a second time.

## 2. S2 components to retire

Retire from candidate selection and production consideration: the S2 last20/last5 adaptive profitability gate and its optimized historical thresholds; the interpretation of EMA crossover as sufficient primary alpha; fixed-time P2F.14 layering; production use of previous retention-policy selections; and any risk/lot-size increase used to compensate for weak expectancy. Preserve their source and results as research history rather than deleting evidence.

The 1.25 ATR stop and 10m exit may remain **reference measurements**. Neither is established as the optimal architecture for a new structural signal. Do not change them in the same experiment as entry timing.

## 3. Components that still contain information

Retain completed-bar EMA9/21 crossing as an event clock, completed M15 EMA20<EMA50 as a context definition, ATR as a displacement/risk scale, executable quotes, shadow observation of rejected signals, FIFO maturation and one-opportunity accounting. The S2 source updates shadow history only after the outcome matures (+10m plus the 30s lookup window); this is a useful causal pattern. It does not rescue the learned gate.

Treat ATR/cost measures as conditioning diagnostics. Existing ATR correlations are modest and do not establish a profitable volatility threshold.

## 4. New alpha family screen

The trial register was written before the new calculations: nine paired snapshot comparisons; ten descriptive feature rank associations; audits of five existing layer arms under seven cost scenarios. There was no threshold sweep. The three horizons in the delay analysis are not three independent confirmations.

| Family | Evidence now | Decision |
|---|---|---|
| A1: unconditional 1/3/5m delay | Direct paired snapshot calculation; gains in July–August reverse in development. | HOLD as alpha; complete one bounded S3.1 falsification experiment. |
| A2: pullback continuation | Signal OHLC exists; post-event impulse/retracement sequence is missing from portable exports. | HOLD; combine with A3 in one parsimonious structural hypothesis, not separate threshold variants. |
| A3: confirmed lower-high failure | No complete causal swing sequence has been tested. | Best untested structural candidate; HOLD until timing experiment is closed. |
| A4: compression → expansion | ATR and one-bar range are present; trailing range history and compression duration are absent. | HOLD one fixed, economical definition. |
| A5: breakout/range expansion | Prior completed M15 low is not exported. | HOLD one prior-M15-low definition; reject arbitrary N sweeps. |
| A6: M1 continuation | No complete M1 sequence in current CSVs. | HOLD as a later timing refinement, not an independent parameter family. |
| A7: bar shape | Ten-feature screen includes body, close location and wick imbalance; effects are weak and sign-unstable. | REJECT as standalone evidence of alpha; no filter promotion. |
| A8: regime | ATR modestly positive; several slope/strength signs reverse. | Retain diagnostics; defer cost-coverage gate until displacement exists. |

Direct A1 result, exit fixed at original event+10m; executable bps, spread embedded:

| Entry | Jan–Jun mean, N=342 | Jul–Aug mean, N=88 | Combined mean | Combined increment | Combined trimmed mean |
|---|---:|---:|---:|---:|---:|
| CONTROL | 2.6817 | 0.7966 | 2.2959 | 0 | 0.7726 |
| DELAY_1 | 1.8135 | 1.4936 | 1.7480 | −0.5479 | 0.6081 |
| DELAY_3 | 1.4372 | 1.5931 | 1.4691 | −0.8268 | 0.5025 |
| DELAY_5 snapshot | 1.1677 | 0.6367 | 1.0591 | −1.2369 | 0.3621 |

DELAY_3 combined median is approximately zero and becomes −1 bps after +1 bps degradation. Its improvement is positive in only **3/8 months**: March, July and August. The original-price-normalized entry improvement is −0.8286 bps, day-cluster bootstrap 95% interval **[−1.8349, +0.1159]**, 10,000 draws over 124 event days. The three-delay multiplicity-adjusted 98.333% interval is **[−2.0518,+0.3307]**. This is not affirmative evidence for delay. Nor is it a precise proof that every possible delayed-entry strategy loses.

DELAY_3 at original-event+15m has combined mean 1.3896, median −0.4162 and trimmed mean −0.0823 bps. At +30m, mean is 1.8211, median −0.3657 and trimmed mean −0.0187. Extending these fixed deadlines does not supply robust displacement.

Why the early adverse clue is insufficient: a negative SELL executable 1m return includes spread, and a negative *increment versus context control* need not mean price moved upward. Direct entry-BID comparisons are the relevant test. For SELL, a higher delayed BID is better. On the common deadline, price-unit improvement equals delayed BID minus original BID; identical improvement across horizons is an accounting identity, not independent alpha evidence.

Ten-feature rank screen at 10m (Spearman, January–June / July–August; N=340/88): ATR bps **+.106/+.166**; spread/ATR **−.054/−.055**; M5 fast slope **−.052/−.149**; M15 fast slope **−.089/+.028**; M15 EMA separation **−.077/+.077**; sell-directed 3-bar momentum **−.009/+.041**; body/range **+.057/−.143**; range/ATR **−.026/+.070**; sell close location **+.065/−.094**; wick asymmetry **+.010/−.035**. These are descriptive associations, not multiple-testing-adjusted predictive discoveries. No family has demonstrated incremental information outside noise by this screen.

## 5–6. Four alpha candidates, with exact causal definitions

All candidates are SELL research only. Any bar used must have closed before the decision tick. M15 context means the latest completed M15 EMA20<EMA50. Tick-derived XAUUSD bars must use one documented feed/chart convention. No session/month profitability filter is allowed.

### S3-A — Paired clock-delay falsification

- **Hypothesis:** a crossover can precede a short adverse retracement; waiting may improve execution and leave enough continuation for a 10–30m hold.
- **Rationale / larger-edge mechanism:** avoid paying for the early adverse part of the path. Waiting creates no new directional information by itself.
- **Features/context:** original completed EMA crossing and original M15 bearish state only. Record subsequent state, but do not gate on it.
- **Entry:** first valid observed quote at event+0/+1/+3 minutes, or first tick of the next M5 bar for DELAY_5. No improvement/retracement/volatility filter. Keep original opportunities identical.
- **Exit research:** 10m after each actual entry is primary; 15/30m after entry secondary. Original-event+10/+15/+30m common-deadline book separates entry benefit from additional elapsed market time.
- **Cost exposure:** one round trip per arm. Spread embedded; commission and extra slippage charged separately.
- **Falsification:** paired price improvement or equal-hold net improvement fails chronological/tail/CI gates, or the benefit arises only from a later exit. Available common-deadline evidence already fails the broad entry-price thesis.
- **Failure mode:** miss immediate impulses, regime-dependent benefit, enter after continuation has exhausted.
- **Complexity / overfitting:** low implementation complexity; moderate selection risk with three delays and multiple horizons, high if choosing a winner from July–August.
- **Recommendation:** **BUILD the research module only**, as the single next experiment; HOLD as tradable alpha.

### S3-B — Confirmed lower-high rejection continuation

- **Hypothesis:** a new upswing failing below a previous confirmed swing high identifies renewed supply before another decline.
- **Rationale / larger-edge mechanism:** failed buyer recovery can offer a higher SELL price and a nearby invalidation level while preserving a larger downward move. This is a market-structure hypothesis, not demonstrated order-flow information.
- **Exact features:** a confirmed M5 pivot high at bar k has H[k]>H[k−1] and H[k]>H[k+1]. It becomes known only after k+1 closes; equal highs do not qualify. Let P be the latest confirmed pivot high at the original crossover. P must exist. For the 10 minutes following the crossover, identify the first subsequently confirmed pivot Q after P with Q.high<P.high. Reject the setup if any completed intervening bar closed at/above P.high. The pivot confirmation bar must close below Q.close. This is one lower-high/rejection predicate with no ATR-depth optimization. Store every confirmation time.
- **Entry:** first quote after that confirmation bar closes, provided its BID is above original crossover BID; otherwise record NO_TRIGGER. The better-price requirement explicitly tests pullback entry rather than silently chasing a lower low. One qualifying entry per original event, no rearming. The condition uses quotes known at entry.
- **Context:** original bearish M15 state and bearish completed M15 state at entry. This additional state condition belongs to S3-B only, never S3.1's timing-only experiment.
- **Exit research:** 10m after entry primary, 15/30m secondary. First measure returns without stop censoring; subsequently compare one fixed reference stop against Q.high plus a documented spread/execution allowance in a separate stop experiment.
- **Cost exposure:** one ticket, potentially wider structural stop; tick sequence can show that confirmation consumes the price improvement. No limit fill assumed at Q.high.
- **Falsification:** no robust net gain versus original-event control on the entire opportunity population, counting no-trigger opportunities as zero deployed return; or selected gains disappear when compared with original entries on the same triggered events; or fewer/later trades merely avoid exposure without stronger conditional displacement.
- **Failure mode:** confirms too late, very few qualifying swings within 10m, shallow structural stops, genuine trend reversal, poor price after rejection. Sparse outcomes mean insufficient evidence, not a relaxed rule.
- **Complexity / overfitting:** medium, state machine and completed bars; medium selection risk even with one fixed pivot definition. No claim that this is optimized.
- **Recommendation:** **HOLD**. Strongest new structural hypothesis, but no measured edge yet. Do not implement concurrently with S3-A.

### S3-C — One-M15-block compression followed by bearish expansion

- **Hypothesis/rationale:** reduced short-term range followed by a downside release may mark transition from balance to directional movement, providing displacement rather than merely a crossing.
- **Exact causal features:** candidate completed M5 bar b; three preceding M5 bars form one 15m compression block. Each of their true ranges must be below the median true range of the 12 completed M5 bars preceding that block. Candidate b must have TR above that same frozen median, close below the compression block low and close below its open. Prior close must still be at/above the block low. All thresholds are relative ordering, not searched magnitudes. Three bars = M15 context scale; 12 bars = one-hour background.
- **Entry/context:** first next-bar BID after b closes; latest completed M15 bearish. One event per compression block, consumed on first breakout; no EMA crossover required. This is a genuinely different event family and requires its own context-control experiment.
- **Horizons/mechanism:** 10m primary, 15/30m secondary; seek expansion persistence after the observed breakout, not the already-completed breakout-bar range.
- **Cost exposure:** spread can widen and entry may be far below the range; measure remaining executable move, not bar range.
- **Falsification:** large breakout bars but small/negative post-entry returns, negative trim/ex-tail net return, or no increment over an appropriately registered bearish-context control. No secondary compression-period sweep to rescue failure.
- **Failure mode:** volatility exhaustion, false break, thin quotes, news gap dominates mean.
- **Complexity / overfitting:** medium; moderate risk from the combined pattern, lower than an ATR-period grid.
- **Recommendation:** **HOLD**; history not exported and no outcome evidence yet.

### S3-D — Prior completed M15-low break

- **Hypothesis/rationale:** crossing a visible prior context-bar low may coincide with renewed selling; remaining move must exceed breakout spread and slippage.
- **Exact causal features:** freeze the latest completed M15 bar's low at the start of the current M15 bar. At the first completed M5 close below it, require previous M5 close at/above that frozen level. One event per M15 block; no N search, sessions or wick threshold.
- **Entry/context:** first next-bar BID; completed M15 EMA20<EMA50. No crossover prerequisite. Record breakout distance and spread without filtering initially.
- **Horizons/mechanism:** 10m primary, 15/30m secondary. Seek continuation after a structural break, not credit for the preceding downward bar.
- **Cost exposure:** adverse selection/chasing, widened spread; one round trip. M1 confirmation is a later separate intervention if this base family merits it.
- **Falsification:** price displacement or robust cost-adjusted return fails, or all improvement is one macro release; compare with a prespecified context clock at matched frequency, without relabeling it clean OOS.
- **Failure mode:** stop-run reversal, selling at exhaustion, broker-specific tick extremes.
- **Complexity / overfitting:** low–medium; moderate selection risk because this is still one of several families.
- **Recommendation:** **HOLD**.

## 7. Single best next implementation

Implement **S31PairedDelayedEntryResearch.mqh** only after the accompanying design is accepted as the frozen experiment. It must produce paired executable quotes, equal-holding-time outcomes and complete post-entry MAE/MFE paths for CONTROL/DELAY_1/DELAY_3/DELAY_5, on all original S3.0 crossover events. DELAY_3 versus CONTROL at a 10m holding time is the primary comparison, selected from the user's original 1–3m hypothesis, not because it won this audit.

This recommendation completes an inexpensive unresolved measurement question. It does **not** assert delayed entry is the best new alpha. The direct snapshot evidence argues against promoting it. Close S3.1 as FAIL if equal-hold evidence does not meet its predeclared conditions; do not turn it into a filter search. Only after that decision consider a separate S3-B structural experiment. No production logic or new layer module is authorized by the research recommendation itself.

## 8. Layer engine thesis

A layer is a new conditional investment in the remaining move. Positive floating PnL is necessary under the requested safety policy but is not evidence that another ticket has positive expectancy. Pyramiding can improve allocation to states with stronger continuation; that improvement requires demonstrable continuation alpha and must exceed new ticket costs plus any profit lost from tightening old stops.

Exceptional winners may contribute to growth, but they cannot be the sole basis for selecting the engine. Use the same monetary opportunity denominator, downside budget and base-event population for all caps.

## 9. Why old P2F.14 failed — independently reproduced

At +1 bps per ticket, development incremental means/trimmed means/ex-best1 were: L3 **+.0703/−.0801/−.0143R**; L5 **−.0079/−.1566/−.1462R**; L7 **+.1211/−.1693/−.0846R**; L10 **+.1668/−.1867/−.1579R**. Every arm fails robustness.

July–August, 25 opportunities:

| Arm | Increment before extra cost | Increment at +1 bps | Increment at +2 bps | Average tickets at recorded rules |
|---|---:|---:|---:|---:|
| L3 | −.1350R | −.2095R | −.2840R | 1.92 |
| L5 | −.0823R | −.1658R | −.2493R | 2.04 |
| L7 | −.2023R | −.2876R | −.3728R | 2.04 |
| L10 | −.1029R | −.1847R | −.2665R | 2.04 |

All four lose even before extra cost; this is not just too many fees. Only 8% of July–August opportunities improve in each layered arm.

Across 119 combined opportunities at +1 bps, L10 mean increment is +.0930R, but trimmed increment is −.1908R, ex-best1 −.1636R, ex-top3 −.1975R and ex-top5 −.2180R. The February 12 18:10 event contributes **+30.3647R** increment, versus **+11.0615R for the entire sample**, or 274.5% of the total. Its L10-cap simulation actually opens six tickets; the count cap is not a forced ticket count. Removing that opportunity reverses the result.

Engineering distinctions: old stops are scanned in chronological tick order and filled at observed ASK, which is useful. But prior layers are tightened only to entry BID; extra fees and slippage remain unfunded. The next ticket takes another full stop-distance unit. And add times are k×10m/N, so cap N changes the schedule as well as capacity. More layers is not an isolated treatment.

## 10. What must change

Require continuation evidence, net-positive existing tickets after reserved costs, confirmation that protection succeeded, an opportunity and portfolio floor calculation, spread/remaining-move coverage, no broken layer, and first-touch executable stops. Separate the effect of tighter old stops from added-ticket profit in a diagnostic accounting book. Maintain one common trigger stream independent of the cap. Tighten stops only, never widen them or reset the opportunity after a stop.

The real-order wrappers do not currently provide this. RiskManager counts positions rather than aggregate cash-at-risk, sizes from balance rather than a pyramid equity budget, and has no portfolio margin/cost reserve logic. The existing volume floor is good: it refuses to round a sub-minimum size upward. Execution.Sell returns CTrade's boolean, and the EA logs an opened order on that boolean; future live implementation must reconcile retcode/deals and actual fills. MetaQuotes explicitly says boolean success alone does not establish execution: [CTrade Sell documentation](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradesell).

## 11–12. Fixed-time versus market-state experiment and recommended trigger

First future layer experiment, conditional on alpha passing: CONTROL_L1 versus two L3-cap arms with identical risk, protection, costs and shared base deadline. Fixed-time comparator considers an add after each completed M1 bar, one candidate per minute independent of cap. Market-state arm considers an add only on **a completed-M1 lower-high pullback followed by a break of its intervening low**.

Deterministic recommended trigger: M1 pivot Q is confirmed when its high exceeds the highs of its immediate completed neighbors. Compare to previous confirmed M1 pivot P; require Q.high<P.high. After Q is confirmed, freeze L as the minimum low of completed M1 bars strictly between P and Q; require at least one intervening bar. Require a subsequent M1 close below L and previous close at/above L. Trigger at the first following quote. Each Q can trigger once. The Q pivot must have formed after the last layer entry. Require current BID below the most recent layer entry BID as well as net profitability of every existing ticket. Never infer a pivot before its right-hand bar closes, and never add from a lower-low tick alone multiple times.

This chooses one market-state trigger to research; A–G are not seven simultaneous backtests. New lower low alone can chase exhaustion. Break/retest and pullback continuation are covered by this single sequence. M5 impulse may be too sparse in 10m. MFE milestones measure progress but do not themselves establish remaining edge. Volatility expansion can identify exhaustion as easily as persistence.

Measure triggered opportunities as well as all base opportunities. A cap arm with no adds equals L1 and contributes zero increment; it is not omitted.

## 13. Protection models and exits

Primary proposed protection: per-layer structural stops, monotonically tightened to the maximum observed ASK within the most recently confirmed M1 lower-high pivot bar plus one symbol trade tick. This uses completed ASK history, not BID highs treated as executable ASK. For the initial engineering design, reserve an additional 2 bps of adverse stop-through in funding/floor calculations, separately from the selected non-spread cost scenario; this is a fixed stress policy, not a calibrated loss guarantee. Realized replay PnL uses observed first-touch ASK, so an unused projected reserve is not deducted again. Prior tickets must additionally meet a cost-covered cash floor before adding. If structural protection and broker stop distance cannot both be satisfied, skip the add; do not force break-even.

A SELL cost-covered break-even stop is **below entry BID** by the reserved non-spread cost and stop-through allowance in price units. Entry-price stop is only pre-extra-cost break-even. Actual close uses first executable ASK at/through stop, plus explicit residual slippage. Do not fill at the requested level. SELL execution at BID and closing at ASK follows [MT5 trading principles](https://www.metatrader5.com/en/terminal/help/trading/general_concept).

Protection alternatives are separate later experiments: entry-price BE is an intentionally weaker benchmark; entry+cost in PnL terms is the minimum; minimum locked R provides additional funding; structural trailing avoids arbitrary time tightening; a shared stop is easy to account for but can cause correlated liquidation; per-layer stops permit older winners to survive. In a netting account, independent server-side position stops do not exist for each virtual ticket; research must log virtual layers and later choose netting-compatible execution or require hedging mode.

Keep **one shared base time exit** in the first layer experiment. No add at or after that deadline. If the newest layer stops, mark BROKEN and prohibit future adds; older protected tickets can remain until their existing stops/deadline. Compare, one at a time and only later: layer-specific clocks (risk of silently extending the campaign); shared structural exit; close-all on continuation failure; and partial de-risking. No combined exit optimizer. Any later architecture needs a hard 30m campaign/holding limit appropriate to its frozen alpha horizon; 60/90m cannot become a hidden production holding rule.

## 14. Downside and four sizing models

Let R0 be the fixed monetary risk budget established at base-opportunity inception; 1R always means this R0 for every ticket and arm. At time t, let C(t) be realized net cash PnL. For active ticket i, q_i is quantity, b_i actual SELL entry, s_i protected stop, a_i the reserved stop-through price allowance, K_i all remaining/allocated fees. Let V convert quantity×price to cash. Define the model stop-out floor:

`F(t) = C(t) + Σ[q_i V (b_i − s_i − a_i) − K_i]`.

Do not count the same paid fee twice, or count floating profit as locked profit. Funding means profit under the adverse stop-out scenario. Cash risk from inception is `max(0,−F)/R0`. Peak-to-floor giveback is `current liquidation PnL/R0 − F/R0`; report it even when F≥0. A winner may still give back a large amount of equity.

For first future layer work, use one active XAUUSD campaign at a time in the deployable portfolio book. Establish the base so estimated initial loss inclusive of cost reserves is ≤R0. Across all active campaigns, sum downside without correlation netting and cap it at the chosen reference fraction of current equity, with an independent margin check. Freeze 0.25% and 0.50% illustrations; never optimize them. A skipped opportunity remains in the allocation ledger.

| Model | Exact principle | Research judgment |
|---|---|---|
| A: constant atomic quantity | Every layer q_i=q0, analogous to equal 0.01-lot units; same quantity is not same risk when stops differ. Require floor/risk tests for each proposed add. | Useful comparator; can consume profit rapidly. |
| B: decreasing risk | Standalone reserved loss allocations proportional to 1.00, .75, .50, then .25 units; derive quantity from actual stop distance and costs, round down. Budget/funding tests still override schedule. | More defensible than increasing size; not automatically superior. |
| C: profit-funded | Available previously locked profit, after already funding active downside, must cover 100% of proposed new ticket maximum reserved loss. New q capped at atomic q0. | Preferred funding rule; do not reuse the same locked profit for multiple tickets. |
| D: zero incremental downside | Require all older net floors ≥0 and proposed full-pyramid F_after≥0, including costs and reserved stop-through; q≤q0. | Preferred additional constraint for the first viable layer engine. |

C and D are related but not identical: C imposes a funding ledger/size source; D imposes an aggregate floor. The recommended eventual engine uses C with D's floor. The first A/B/C/D comparison must keep trigger, exit and L3 cap fixed, with all versions also constrained not to worsen the original −1R modeled opportunity floor. Do not interpret these as 4×5×7 unrestricted parameter trials.

**A stop is not a guaranteed loss cap.** Under a price gap, insufficient liquidity or a failed modification, actual loss can breach the modeled reserve and even a nominal F≥0. Model D is feasible only as a stress-reserved constraint, not a promise that realized outcome cannot be negative. Report every breach and stop-through distribution. If the user requires a literal guaranteed nonnegative outcome after adding, this OTC stop-based architecture cannot satisfy that requirement; remain L1. Broker stop/freeze levels, tick size and volume constraints must be honored: [symbol properties](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants).

## 15. Cost model

Define “gross executable” consistently as `SELL entry BID − exit ASK`, before commission and additional execution degradation; it already includes spread. Also export mid-to-mid displacement separately.

Apply **0, .5, 1, 1.5, 2, 2.5, 3 bps per completed ticket round trip**. If quoting degradation per side, explicitly sum the two sides; +1 round-trip bps is not +1 on each side. Charge actual broker commission separately when known, unless the registered scenario explicitly includes it. Do not subtract spread again. Costs scale by each ticket's actual notional, not merely by count when quantities differ; minimum per-order commission adds a fixed ticket term if the broker has one.

For every new stress scenario, rerun eligibility, profit funding and protection using that scenario's reserved costs, then execute its tick path. A static subtraction is insufficient when eligibility depends on net PnL. The old-arm audit is deliberately a fixed-path cost attribution of recorded P2F.14, not a cost-aware new engine.

Keep first-touch ASK stop-through separate from added slippage so the same degradation is not charged twice. Real-tick tester mode still needs gap/generated-tick auditing: [MT5 real and generated tick documentation](https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation). A tester execution-delay setting does not automatically stress a custom virtual ticket simulator.

## 16. L1/L3/L5/L7/L10 arms and trial staging

Immediate cap is **1** until base alpha passes. Deferred program:

1. One accepted alpha, fixed horizon/risk: L1 and L3 fixed-time versus L3 market-state (two incremental trigger hypotheses).
2. If a trigger passes, at L3 compare the four risk models under identical stops/exits. If changing the risk model is needed to rescue a failed trigger, register a new experiment; do not relabel the original trigger pass.
3. Freeze one trigger/risk/exit policy; run L1/L3/L5/L7/L10 on one common trigger stream. The cap alone changes. L5 must add value beyond L3; L7 beyond L5; L10 beyond L7 as well as beating L1. The cap never forces tickets.
4. Later exit interventions one at a time, each registered. Cost stress is seven robustness scenarios, not seven selectable winners.

Future larger caps are economically sensible only if their actually reached late-layer states supply independent base opportunities across time. No evidence at layer rank 7 means no permission to extrapolate layer-3 results to rank 7.

## 17. Exact accounting and required metrics

One base event gets one immutable opportunity key: symbol/feed, completed M5 event bar time, first observed event milliseconds, direction and event-rule version. Run IDs distinguish reproductions, not new opportunities. Each cap/scenario has one final summary row keyed to that base event. Tickets are child records. Multiple horizons and cap arms must stay paired in resampling.

`pyramid_R = (sum ticket net PnL + realized partial cash flows)/R0`.
`incremental_R = pyramid_R − matched CONTROL_L1_R`.

All base opportunities remain in the ledger, including NO_TRIGGER, COST_REJECT, RISK_REJECT, PORTFOLIO_BUSY, DATA_INVALID and zero-add opportunities. Data-invalid outcomes are missing, never assigned a favorable zero. Policy no-trade is a zero in the deployed opportunity ledger; report filled-event conditional results separately. For structure-only events, establish their own event universe before controls. Avoid double-counting overlapping duplicate setups; pre-register canonicalization and use day clusters because even distinct base events can be dependent.

Summary fields: total R, increment, ticket count, maximum active downside, maximum protected profit, final R; average/max active quantity and incremental quantity relative to q0; time-integrated incremental exposure; peak total standalone loss budget, peak aggregate net downside, peak unprotected risk; before-each-add locked profit and floor; maximum pyramid liquidation PnL, peak-to-final giveback and peak-to-stop-out reversal loss. Distinguish standalone risks from netting against locked profit.

Report mean/median/PF/10%-each-tail trimmed mean/ex-best1/ex-top3/ex-top5; worst one and worst-three aggregate; positive/negative/zero increment rates; worst day; consecutive losing opportunities; daily marked-to-market drawdown and closed-opportunity drawdown; reference-risk log growth. No annualization of a sparse trial.

The supplied old details reproduce summary gross/net totals within 10⁻⁸R. Old CSVs do **not** record complete stop-update states, cost-covered floors, time-integrated exposure or continuous pyramid equity. Those requested path-risk metrics are **not measurable from the current exports**, not zero. New trigger MAE/MFE and live portfolio drawdown likewise remain unmeasured until replay.

Illustrative old July–August +1 bps closed-opportunity results, reference risk 0.50%:

| Arm | Compounded return | Closed-opportunity max DD | Mean log growth/opportunity | Consecutive losses |
|---|---:|---:|---:|---:|
| L1 | −0.096% | −1.670% | −0.0000384 | 2 |
| L3 | −2.684% | −4.329% | −0.0010882 | 9 |
| L5 | −2.153% | −3.963% | −0.0008706 | 8 |
| L7 | −3.628% | −4.900% | −0.0014782 | 8 |
| L10 | −2.379% | −3.770% | −0.0009631 | 10 |

At 0.25%, compounded returns respectively are **−0.0446%, −1.3462%, −1.0771%, −1.8262%, −1.1926%**; the engine still loses. These are sequential R-based illustrations from old opportunity totals, not a newly reconciled overlapping-account simulation or certified intratrade drawdown. Full risk/cost metrics are in the accompanying CSVs. Growth is shown here to diagnose failure, not to market a compounding strategy.

## 18. Exact pass/fail criteria

The following are **proposed fixed research acceptance policies**, not statistical facts learned from the history. Freeze them, actual commission assumptions and the code/config hash before the next untouched validation. No passed discovery result becomes production approved.

Alpha development gate, at the single registered primary horizon:

- Valid paired data coverage ≥99% among events eligible by a predeclared session/end-of-run availability rule; no unknown tick provenance or invalid/negative/crossed quotes. Missingness by month/state is reported and a missing-outcome sensitivity analysis cannot overturn the conclusion. Actual portfolio replay requires complete execution paths; it cannot drop a bad open position because a label is absent.
- Gross executable mean, median, 10% trimmed mean and ex-best1 mean >0. At nominal cost, mean, median, trimmed and ex-best1 also >0. At +2 bps, mean and trimmed >0. Report all seven scenarios and the exact break-even cost.
- Positive net mean and trimmed mean separately in Jan–Mar, Apr–Jun and Jul–Aug contaminated partitions. At least 6/8 available months have positive net mean; leaving out any one month leaves net mean >0. Months are robustness checks, never trading filters.
- Paired incremental mean and trimmed mean versus its registered control >0; a day-cluster 95% lower bound for primary net mean and increment >0. Use 10,000 resamples; if selecting among three delays, require Holm-corrected paired tests or the conservative 98.333% per-delay interval as preregistered. A conditional structural strategy must report both opportunity-level deployment and same-triggered-event comparisons.
- Economic coverage: target expected pre-spread mid displacement ≥3× expected full round-trip cost, with the underlying executable return also passing the above tests. This is an explicit conservative hurdle. It must use measurable costs and no future-volatility predictor. Reject merely green low-margin expectancy.

S3.1 separately asks whether timing improves price, MAE, or equal-hold expectancy. A timing-only result can receive `KEEP_TIMING_RESEARCH` without passing the economic alpha gate; it cannot authorize layers. Failure at 10m is not rescued by quietly promoting 30/60/90m results.

Layer gate, nominal registered cost:

- All opportunity and portfolio safety invariants pass, with exact executable gap/slippage treatment and every floor breach reported. No additional layer after any ticket failure; no cost-free simultaneous protection assumption.
- Incremental mean >0, median ≥0, trimmed >0, ex-best1 >0, ex-top3 >0 and **ex-top5 >0**. Positive headline mean with failed trim or ex-best1 is `FAIL_KEEP_CONTROL`, regardless of p-value.
- Positive increment in each of the three chronological blocks above; leave-one-month-out incremental mean >0. Removing the February 12 opportunity and the three largest incremental opportunity days separately must leave mean and trim positive. Report all event contributions; no historical macro-event trading exclusion is selected.
- Day-cluster bootstrap lower bound >0 for increment and for paired log-growth improvement at both 0.25% and 0.50%. Initial layer-trigger selection uses multiplicity control for its two hypotheses. No statistically independent ticket count.
- At +2 bps, incremental mean and trimmed mean >0. At +3 bps, incremental mean must be ≥0; otherwise HOLD for explicit cost-resolution, not production. These are deliberately strict stress gates.
- Marked-to-market max drawdown may be no more than 1.25× matched L1 DD; if L1 DD is zero, require no increase. Worst opportunity may not breach the registered stress-reserved opportunity risk budget; worst day cannot be below L1's worst day by more than 1R0 at the day's fixed denominator. Higher log growth does not waive floor breaches.
- Before promoting a larger cap, require ≥100 distinct base opportunities reaching its newly admitted layer ranks in aggregate, ≥30 distinct event days, and ≥3 chronological months, plus a positive robust increment over the preceding cap. Correlated layer ranks do not multiply that count. Sparse late ranks produce INSUFFICIENT_EVIDENCE, not assumed safety.

Clean validation: reserve the first trading session after design/code freeze onward. If frozen this weekend, a prospective run can start September 7, 2026; September 1–4 can remain untouched holdout but cannot be described as prospectively preregistered before they occurred. A proposed first fixed review date is December 31, 2026, with at least 200 base opportunities and 60 event days for an alpha candidate. If counts are insufficient, report insufficient evidence at that date; any extension is registered before revealing outcome performance. Layer rank counts may require much longer. No early stopping when PnL turns green, no reuse of January–August as clean data.

## 19. Expected layer failure modes

Remaining edge shrinks with each lower-priced SELL; spread/commission erodes small late moves; rapid BE tightening creates churn and sacrifices base winners; stop-through converts nominal protection into loss; all layers share a reversal shock; floating profits are mistaken for funding; a fixed lot minimum breaks small-account risk constraints; shared/netting position semantics corrupt ticket stops; late adds have too little horizon; asynchronous protection/fills create temporary risk; duplicate opportunities create hidden leverage; sparse last-layer states inherit one macro event; and a data gap is wrongly treated as a harmless no-trade.

Profit-funded losses are still foregone equity. A model with nonnegative inception floor can have large peak-to-trough drawdown. Neither atomic lots nor small ticket size establishes an absence of blow-up risk.

## 20. MQL5 implementation plan and CSV additions

**Next module only:** `Include/RamusenEA/S31PairedDelayedEntryResearch.mqh`, with a standalone research event/arm state and no reference to CTrade. Depend on the S3.0 completed-bar event definition, Config/Types/Market snapshots, completed ATR/context capture, SignalResearch target-quote semantics and Excursion/TimeExit chronological ASK processing. It must not depend on the S2 profitability gate or ControlledLayerResearch eligibility. Prefer an immutable event snapshot shared by the event generator and S3.1 over duplicating selection rules. Exact details and clocks are in `FROZEN_S31_DESIGN.md`.

New files planned: run manifest, base opportunity CSV, entry-arm CSV, horizon outcome CSV, and bounded full-path tick/M1/M5 export for audit. Required fields:

- Provenance: schema, experiment/trial ID, run ID, source/config hash, symbol/feed/server, tester mode, server UTC offset/DST mapping, dates, real/generated tick provenance, build version, trading-disabled flags, commission convention and cost scenario.
- Event: immutable key, event timestamp milliseconds, bar-close timestamps, indicator as-of timestamps, completed EMA values, original BID/ASK/mid/spread, ATR frozen at original event, original stop scale, all arm schedules.
- Entry: arm/delay, target and actual time, lateness, quote sequence/time/flags, actual BID/ASK, change versus original BID in price/ATR/bps, pre-entry path MFE/MAE, M15 at entry recorded as a diagnostic only, valid/missing/reject reason.
- Outcomes: event-clock and entry-clock deadlines, first executable exit time/ASK and latency, actual holding seconds, mid return, executable bps and common-denominator R, separate commission/additional slippage, all seven cost returns, post-entry executable MFE/MAE and their times, continuous path tick count/max gap, missing provenance, reference stop first touch/ASK/stop-through as diagnostic only.
- Structural readiness, recorded without filtering S3.1: completed M1/M5 OHLC/TR sequences; prior completed M15 OHLC; pivot bar and confirmation times; original signal-bar OHLC and body/wick/close location; trailing compression reference window boundaries. Outcomes never enter these features.

After stronger alpha and a separate freeze, a new virtual `S3WinnerPyramidResearch.mqh` can consume approved immutable opportunities and replay one ordered tick stream. Add a transition CSV for every add attempt/protection update/stop: opportunity/scenario/arm/layer keys, trigger/pivot IDs and as-of times, reasons, all ticket net marks, realized cash, old/new stops, requested/effective protection time, locked profit, funding already committed, proposed risk, floor before/after, margin/lot constraints and exact fill. Summary fields are in section 17.

Fail closed on research/trading flag conflict, wrong symbol/timeframe/EMA settings, missing bar or tick provenance, stale/invalid quote, unconfirmed protection, insufficient floor or minimum size. MQL5 research flags must initialize as `RESEARCH_ONLY`, `TRADING_DISABLED`, `FAIL_CLOSED`; OnInit rejects `InpEnableTrading`, baseline execution and execution-test modes for S3.1. A runtime fatal data fault quarantines the run/arm and prohibits simulated deployment, while preserving explicit missing labels.

Later real-order support, if ever validated, needs portfolio cash risk, OrderCalcProfit/OrderCalcMargin, volume and tick rounding, stop/freeze validation, hedging/netting handling, broker modification acknowledgments, deal/partial-fill reconciliation and recovery after restart. These are not part of the next research implementation.

## Special question: do many layers make this bot more profitable?

**They can, but not merely because there are more layers.** They amplify conditional exposure. Market-confirmed adds can exploit additional continuation information or improve allocation; without that, they magnify the existing edge and its errors while adding execution costs. Protection also changes the base payoff, so the causal effect is not just leverage times old return.

For opportunity o and layer j, define activation I, quantity relative to q0 w, executable remaining move g in bps, non-spread ticket cost c, and original stop scale s0 in bps. With exact per-entry notional conversion in implementation:

`E[ΔR] ≈ E[ΔR_from_changed_old_stops] + E[Σ(j≥2) I_j w_j (g_j−c_j)/s0]`.

All terms are joint expectations over base opportunities; do not replace E[g/s0] with E[g]/E[s0]. Every new ticket must have positive conditional net contribution, and the entire expression must pass tail tests. Base-entry mean alone cannot determine this.

For equal-size tickets all actually opened, with illustrative original stop 12.60 bps, extra-cost hurdle alone is:

| Cap reached | Extra tickets | Incremental cost at +1 bps | At +2 bps | Sum of extra tickets' executable moves needed merely to cover +1 bps cost* |
|---|---:|---:|---:|---:|
| 3 | 2 | .1587R | .3175R | >2 quantity-weighted bps |
| 5 | 4 | .3175R | .6349R | >4 quantity-weighted bps |
| 7 | 6 | .4762R | .9524R | >6 quantity-weighted bps |
| 10 | 9 | .7143R | 1.4286R | >9 quantity-weighted bps |

*Before compensating for lost base profit, additional spread already embedded in each move, variance, or drawdown. These are sums across tickets, not a prediction that the underlying price must move by 2/4/6/9 bps. If only two tickets open, pay for two, not the cap. If one fixed total quantity is merely split into more tickets, proportional notional costs do not multiply by cap; minimum per-ticket fees and execution effects may still increase. The requested 0.01-lot-like additions generally increase total notional.

With a positive/negative continuation model, let p be win probability, W average positive *remaining executable* move, L average negative remaining move and c extra cost. Positive ticket expectancy requires:

`p > (L+c)/(W+L)` or `W > ((1−p)L+c)/p`.

Illustration only—not a fitted layer model: use W=6.35 bps from the supplied July–August positive shadow movement and L=12.60 bps as a hypothetical adverse move. At c=1, p must exceed **71.77%**; at c=2, **77.04%**. At p=64%, W must exceed **8.65 bps** nominal or **10.21 bps** at +2 bps merely to break even. The implied mean before extra cost with W=6.35 is −0.472 bps, and after +1 bps is −1.472 bps. The 64%, 6.35 and 12.60 figures come from different summary concepts; this calculation illustrates a requirement, not an empirical estimate of actual layer win/loss distributions.

For a conservative economic margin, use the registered 3× all-in-cost hurdle. At a representative .75 bps spread drag and +1 bps non-spread cost, target mean mid displacement ≥5.25 bps, equivalent to executable mean ≥**4.50 bps**. At +2 bps it becomes **7.50 executable bps** under the same 3× policy. These are design hurdles, not universal constants. July–August raw-crossover executable mean .7966 bps and DELAY_3 common-deadline mean 1.5931 bps fall well short.

There is **no defensible universal minimum base mean for cap 3 versus 5 versus 7 versus 10**. A 10-bps base opportunity can have negative expectancy after its first 8-bps move; a smaller initial signal can have a rare but causally identifiable strong continuation state. Economically sensible caps require the above conditional inequality at each admitted rank, adequate cost margin, funding/floor feasibility, enough independent rank-reaching opportunities and positive opportunity-level log-growth increment after protection effects. Current data satisfy none of that for new market-state layers.

BEST_NEW_ALPHA:
S3-B — Confirmed lower-high rejection continuation (untested hypothesis)

NEXT_EXPERIMENT:
S3.1 paired CONTROL/DELAY_1/DELAY_3/next-M5 entry; primary DELAY_3 versus CONTROL at 10 minutes after actual entry, with common-event-deadline and full ASK-path MAE/MFE diagnostics; no new filter.

LAYER_ENGINE_STATUS:
WAIT_FOR_STRONGER_ALPHA

MAX_LAYER_RESEARCH_CAP:
1

WHY:
The 3m-delay snapshot loses 0.827 bps versus control across 430 events; old July–August layers lose 0.166–0.288R incrementally at +1 bps, and one L10 opportunity supplies 274.5% of pooled incremental profit.

FINAL_DECISION:
BUILD_S3_ALPHA
