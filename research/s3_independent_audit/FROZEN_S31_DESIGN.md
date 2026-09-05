# S3.1 — paired delayed-entry research contract

Design version: S31_PAIRED_ENTRY_TIMING_V1, 2026-09-05.
Status: **specified for review; MQL5 implementation not started**.
This is a fixed proposed design, not a claim of user approval, a completed backtest,
or a preregistration predating already observed January–August data.

## Question and single intervention

On the exact same completed M5 EMA9/21 bearish crossover event inside completed
M15 EMA20<EMA50, does entering later improve executable 10m holding-time return,
and is the mechanism better entry price, less adverse excursion, or simply a
later market-time exit?

The single intervention is the scheduled entry time. No S2 gate, structural
confirmation, spread/ATR profitability filter, context recheck for eligibility,
stop change, retention, layer, session-PnL restriction or risk increase.

Primary arm contrast: **DELAY_3 minus CONTROL**, 10 minutes after actual entry.
DELAY_1 and DELAY_5 are prespecified secondary arms. A later decision selecting
one of the three delays must account for all three trials; no claim of an
unselected primary if the winner changes. No 2/4/6-minute follow-up sweep.

## Population and boundaries

1. Use the S3.0 event definition exactly: completed M5 EMA9/21 shifts 2/1,
   `fast2>=slow2 && fast1<slow1`; completed M15 shift1 `EMA20<EMA50`.
2. Timestamp t0 is the first observed valid tick of the new M5 bar, after the
   signal bar closes. Record that signal bar and context bar close times. Prime
   the bar clock at startup, without inventing an event on a partial bar.
3. Historical paired audit uses the 433 canonical crossover events in the
   supplied S3.0 export, including those with unavailable labels. An event-list
   hash is mandatory; new complete-date coverage is a separately versioned run.
4. Historical prices, bars and exits must precede 2026-09-01 00:00:00 server time.
   Never access September prices to finish an August event. End-censored events
   remain explicit. Reconcile the actual August-28 export end separately from
   the nominal January–August research window.
5. All January–August results are contaminated. September outcomes are not read
   to design or calibrate this experiment. No live order is sent.
6. One base event remains one opportunity even if four shadow entry arms and
   several labels exist. Use separate deployed-account replay later for overlap;
   never multiply independent sample size by arm count or horizon count.

## Entry clocks and executable quotes

| Arm | Target |
|---|---|
| CONTROL | t0 |
| DELAY_1 | t0+60,000 milliseconds |
| DELAY_3 | t0+180,000 milliseconds |
| DELAY_5 | first observed tick of the next M5 bar after the event bar |

For DELAY_5, scheduled boundary is current event M5 bar open +300 seconds,
not t0+300 seconds. A delayed first event tick can make these different.

Use the first valid observed quote at/after each target, with the inherited
maximum 30-second lookup tolerance. Require positive finite BID/ASK, ASK>=BID,
monotonic timestamp and a valid documented tick sequence. Preserve simultaneous
millisecond quotes in native order. CONTROL uses its original observed quote.
No ideal fill at a bar open or at the scheduled time. Entry SELL fill is BID.
A missing or late quote produces explicit ENTRY_MISSING / ENTRY_TOO_LATE,
not a later discretionary entry or an invented midpoint.

The original context is frozen. If it changes before delayed entry, record it
as a diagnostic but still execute the shadow arm. Likewise, a price that has
already fallen must not cause a skip; otherwise this is timing plus a filter.

## Two distinct outcome clocks

**Primary entry clock:** first executable ASK at/after actual entry +10 minutes.
Secondary entry-clock horizons are +15/+30 minutes. All actual holding times
remain 10/15/30 minutes plus observed quote latency; an event campaign can begin
up to five minutes before its delayed position is opened. This is still an
intraday/scalping experiment, not a 60–90m production extension.

**Common event clock:** first executable ASK at/after t0+10/+15/+30 minutes.
The matched arms share that exact exit quote. This separates the contribution
of entry-price improvement. Common-deadline DELAY_5 has roughly a 5m hold at the
10m deadline; it must not be called a 10m holding-time return.

Do not synthesize equal-hold DELAY_3's t0+13m endpoint from t0+10 and t0+15
snapshots. Do not call an approximate DELAY_5 t0+15m label exact if the entry
quote was late or used a different next-bar boundary. Full target ticks resolve
these differences. The existing snapshot result is a diagnostic, not a complete
S3.1 implementation.

Each endpoint is first valid observed ASK within 30 seconds. Missingness is
reported for every arm/horizon. Label maturity never supplies decision features.
In a forward run, process only ticks whose time has already occurred; historical
CopyTicksRange label retrieval belongs to the labeler, not the decision engine.

## Gross labels, cost and risk scale

For actual entry BID b and exit ASK a:

- Executable move in price = b−a.
- Executable bps = 10,000(b−a)/b.
- Common-price paired diagnostic = 10,000(b−a)/b0, where b0 is CONTROL entry.
- Entry improvement = 10,000(b−b0)/b0; positive is a higher/better SELL entry.
- Mid displacement uses observed entry and exit midquotes, exported separately.
- Reference price stop scale s0 = 1.25×ATR(M5,14) from the completed original
  event bar. Reference R = (b−a)/s0. Never recompute ATR to improve delayed R.

The primary label has **no stop censoring or profit retention**, so entry timing
is isolated. Record a distinct diagnostic of an unchanged-distance reference
stop at each entry BID+s0, first touched by actual ASK, including first-touch
stop-through. Do not select delays based on that secondary stop diagnostic if
primary gross timing fails. Subsequent deployable stop design is another trial.

Apply cost c in {0,.5,1,1.5,2,2.5,3} bps once per arm's completed round trip.
Reference R cost = `(b*c/10000)/s0`, preserving actual entry notional. Spread is
already embedded in b−a. Keep actual commission separate or explicitly label
it included; no broker commission is currently calibrated by the M5 artifacts.
No compounding claim from uncensored return labels. Risk/growth needs the later
fixed-stop, complete-portfolio replay.

## MFE/MAE and path integrity

From actual entry through actual exit, over every valid executable ASK:

- MFE_price = max(0, entry BID − minimum ASK).
- MAE_price = max(0, maximum ASK − entry BID).
- Export bps at own entry and original entry, common-scale R, timestamps and
  ordering of extrema, plus time spent above/below cost-covered break-even.
- Record pre-entry BID improvement and pre-entry ASK path separately; neither
  is allowed to select entry in this trial.
- Common-deadline MAE can mechanically improve because exposure is shorter.
  Primary causal interpretation must also examine equal-hold MAE.

Export path start/end, tick count, quote flags, max intertick gap, invalid quote
count, session boundary status and real/generated provenance. A .tkc file or
Model=4 setting alone is not a coverage certificate. A full-price-path dataset
is needed before any path-risk result can pass. Data gaps cannot be filled with
bar high/low or evenly interpolated quotes.

Full rows remain available for missingness analysis. Statistics use a common
complete-case cohort across all four arms **per endpoint**, and show pairwise
availability counts as diagnostics. The denominator is not silently different
between control and delay. Deployment return for an opened position with a
missing exit cannot be set to zero.

Coverage acceptance is ≥99% among events permitted by known session/run-end
availability rules. Require no unresolved systematic missingness. Report a
sensitivity analysis using adverse observed tail outcomes for missing labels;
if the decision depends on the imputation, HOLD. This is a data robustness check,
not a claim to bound market losses. For incomplete live paths, fail closed on
new entries and preserve the open-position operational record.

## Statistical evaluation and frozen decision rules

The primary comparison is DELAY_3−CONTROL at equal 10m holding time. Report all
four arms and all specified endpoints, including failures. Trim 10% from **each**
tail, floor(0.10N) observations per tail. Ex-best/top3/top5 removal is performed
on opportunity totals or increments, not ticket rows.

Report gross/net mean, median, trimmed mean, ex-best1, ex-top3/top5, positive/
negative rates, average positive and negative price displacement, PF, paired
entry-price change, paired MAE change, and conditional continuation after entry.
Do not prioritize win rate. Show Jan–Mar, Apr–Jun, Jul–Aug and monthly results.
Every month is retained; no historical-hour/month filter can be derived here.

Use day-cluster paired bootstrap, 10,000 draws, frozen seed 3103, sampling whole
event days with replacement and retaining every paired event/arm within each
day. Keep opportunity weighting when recalculating each statistic. Add a
prespecified five-trading-day block-bootstrap sensitivity check for dependence
across days; do not select whichever CI is favorable. Daily clusters do not
prove events are independent across days.

Primary timing keep requires positive paired net mean and trimmed improvement,
positive ex-best1 improvement, paired mean improvement in all three chronology
blocks, leave-one-month-out mean improvement >0 and a day-cluster 95% lower bound
>0. If a secondary delay is promoted, use conservative 98.333% intervals for all
three delay comparisons. Secondary horizon success cannot overwrite a primary
10m failure without a separately registered horizon hypothesis.

Classify the mechanism explicitly:

- ENTRY_PRICE_SUPPORTED only if direct BID improvement has positive robust
  mean/trim/ex-best1 across chronology and a supportive paired interval.
- TIMING_PAYOFF_SUPPORTED if equal-hold return passes despite unsupported entry
  price; attribute the later-exit component rather than claiming better price.
- LOWER_MAE_ONLY is diagnostic; it cannot establish larger alpha.
- FAIL_TIMING if the primary keep conditions fail.

To earn BUILD_ALPHA_VALIDATION rather than a timing-research label, also satisfy
the report's absolute robust net-return and 3× full-cost economic gates. No
layer activation is permitted by timing improvement alone.

## Module integration and guardrails

Planned changes, not implemented:

1. Add one S31 research-only flag/config contract; OnInit rejects trading enabled,
   baseline trading and execution-test modes, incorrect chart/EMA/context, or
   absent output/provenance setup.
2. Consume the immutable original S3.0 event snapshot. Do not route through
   S2's history-dependent eligibility. Keep original rule version and event IDs.
3. On each tick, update pending entries and paths before the EA's new-M5-bar
   early return. The current architecture already has an every-tick research
   processing location; an M1 entry cannot live only in the new-M5 branch.
4. Separate causal scheduled-entry state from matured outcome labeling.
5. Export event/arm/outcome/status manifests with fixed schemas and explicit
   errors. Flush at safe boundaries. Do not expose CTrade in this module.
6. Compile only after design freeze and implementation authorization; validate
   known quote examples and same-deadline price identities, chronology,
   equal-millisecond ordering, missing-target handling, and unchanged control.
7. Run one bounded historical real-tick replay for the registered event list.
   Reconcile all events/rows to source. Freeze code/config/thresholds before a
   separate reserved validation run; no repeated historical optimizer.

No new strategy code or simulator has been implemented by the present audit.
