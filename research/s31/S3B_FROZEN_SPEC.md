# S3-B V1 — confirmed lower-high rejection continuation

Status: **FROZEN NEXT-STAGE RESEARCH SPECIFICATION; NOT IMPLEMENTED OR TESTED**.
Frozen 2026-09-05 after S3.1's negative disposition. This is a separate market
structure hypothesis, not a filter rescue for a fixed delay. No S3-B outcomes
were inspected to select these definitions. Research-only, trading-disabled,
fail-closed. January–August remains contaminated; September onward remains
reserved. No layer research is included.

## Hypothesis and economic mechanism

A bearish context plus a completed pullback that fails below the previous swing
high may identify renewed selling with more remaining displacement than a
moving-average crossover. The entry waits for observable rejection/breakdown;
elapsed time alone never authorizes it. This may improve selection of continuation
opportunities, but paying for breakdown confirmation may also worsen entry price
or arrive after most of the move. Larger gross edge is a hypothesis to falsify.

## Exact causal price structure

Use XAUUSD M5 completed BID OHLC bars, increasing chronological indices. No M1
confirmation, tick-optimized threshold, session filter, ATR gate or S2 state.
Maintain a rolling chronological record; never rescan later bars to choose a
more attractive historical swing.

1. A strict one-left/one-right pivot high at index j requires
   `High[j] > High[j-1] && High[j] > High[j+1]`. A pivot low requires
   `Low[j] < Low[j-1] && Low[j] < Low[j+1]`. It becomes known only when bar j+1
   completes. Equal highs/lows are not pivots. If a bar meets both definitions,
   record it diagnostically and exclude it from the structural pivot sequence;
   intrabar high/low ordering must not be invented from OHLC.
2. When a new high Q is confirmed, P is the immediately preceding recognized
   pivot high in chronological order. L is the most recent recognized pivot
   low strictly between P and Q. No alternative P or L may be selected if this
   pair fails. Require P.index < L.index < Q.index, Q.high < P.high and
   L.low < Q.low. These define downward impulse P→L and retracement L→Q.
   No minimum ATR amplitude is used in V1.
3. At the first tick after Q's right neighbor C completes, Q is causally
   confirmed. Require the latest fully completed M15 EMA20 < EMA50 at this
   arming instant. Freeze P, L, Q, C, their times/prices, completed context,
   ORIGINAL M5 ATR14 and arming BID/ASK. This defines one base opportunity.
   No historical EMA crossover is required. Record the most recent crossover
   time diagnostically; it cannot change eligibility.
4. Freeze the breakdown level `B = Low[C]`. Q's confirmation proves the local
   high turned down; a subsequent close below B supplies separate continuation
   evidence. Arm without using the future close or future extremum.
5. Inspect the next three completed M5 bars after C, in order. The first bar K
   satisfying `Close[K] < B && Close[K-1] >= B` triggers continuation. Equality
   to B does not trigger. The completed M15 context must still be bearish at K's
   close; if it is not, terminate this opportunity as CONTEXT_FAILED rather than
   waiting for a later successful attempt.
6. Before considering a trigger on each inspected bar, invalidate if its close
   is at or above Q.high. Invalidation has priority. Expire after the third bar
   if no trigger. Three M5 bars gives one 15-minute pullback-resolution window,
   selected for the intraday design, not by outcome comparison. Do not sweep it.
7. Entry is the first valid executable BID after trigger bar K completes,
   within 30 seconds; record actual ASK/spread. If the first valid quote is
   already at or above the frozen structural stop, mark INVALID_ENTRY and do
   not retry. Do not require a better BID than the arming control: price paid
   for confirmation is part of the result.

One opportunity per Q timestamp. Subsequent confirmed pivots cannot replace the
frozen levels of an already armed opportunity. Overlapping opportunities may be
labeled independently for alpha research, with concurrency recorded and day
clusters used statistically. They are not an executable combined portfolio.

## Frozen research arms and accounting

Exactly two arms, on each eligible Q:

- **ARMING_CONTROL:** enter at Q's causal arming instant, without waiting for
  the additional close-below-B continuation confirmation.
- **S3B_CONFIRMED:** enter only if the frozen breakdown rule triggers; otherwise
  abstain. An abstention has zero PnL in the all-base-opportunity policy view and
  no transaction cost. It is not a winning or losing executed trade.

Primary labels: ten minutes from each arm's actual entry, entry BID to exit ASK.
No other horizon in V1; 15/30-minute studies require a new registered experiment.
Primary gross returns are uncensored by stops. Record the entire entry–exit ASK
path, MFE/MAE, time to extrema, original ATR units and executable entry improvement.

Report both (a) all eligible Q opportunities, including explicit abstentions,
and (b) the triggered subset with paired arming-control outcomes. The second
view conditions on information learned after arming and cannot by itself prove
an ex-ante policy improvement. Missing quotes are missing data, never abstentions
or zero PnL. One Q remains one observation. Report eligible count, trigger rate,
abstention reasons, missingness, overlap and actual holding/arming-to-exit time.

The S30 crossover cohort is an external descriptive benchmark with different
event selection. Do not claim paired improvement over S30 or count more events
as evidence of alpha. This experiment isolates the added breakdown decision
within a new structural family; it does not causally attribute all differences
between that family and the old crossover strategy.

## Frozen secondary stop and cost view

Stop reference: maximum observed ASK during the completed Q pivot bar plus one
symbol trade tick. Capture it using ticks available by arming; never use a
future spread or a BID high as an ideal executable SELL stop. Missing Q-bar ASK
history makes the secondary stop view unavailable, without changing primary
gross eligibility. Stop price stays frozen for both arms. Risk distance is that
stop minus the arm's actual entry BID and must be positive. Record original ATR
for normalization; do not optimize an ATR stop simultaneously.

First touch is ASK >= stop; fill at that actual observed ASK, including overshoot.
If untouched, exit on the same ten-minute target. No trailing, retention, partial
exit or layering. Report actual R, not a forced -1R stop. This is a research risk
diagnostic; it establishes no production sizing or account-growth claim.

Executable spread is embedded. Additional one-ticket round-trip stress is fixed
at 0, 0.5, 1, 1.5 and 2 bps. No two-sided double charge. Report all results;
broker cost calibration and any clean-validation hurdle are frozen separately
before reserved outcomes may be accessed.

## Falsification and promotion boundary

Reject V1 continuation confirmation if it fails to improve gross all-opportunity
mean and trimmed policy return over ARMING_CONTROL, or any apparent improvement
depends on the best opportunity/month. Positive triggered-trade mean alone is
insufficient. Report mean/median, each-tail 10% trim, ex-best1/3/5, worst, positive
rate, month and Jan–Mar/Apr–Jun/Jul–Aug partitions, paired day-cluster 95% intervals
(10,000 draws, seed 3103), and all fixed cost scenarios.

A candidate can be retained for subsequent cost research only if triggered
absolute mean, median, trim and ex-best1 are positive, the all-opportunity paired
mean/trim/ex-best1/ex-top3 are positive, the paired day-cluster lower bound is
positive, the improvement survives each chronological block and omission of each
month, and +1 bps mean/trim remain positive. These are contaminated discovery
criteria, never a production pass. Report gross-move/cost margin continuously;
a tiny positive remainder is not the desired materially stronger alpha.

Record failure modes explicitly: late breakdown entry, stop distance too large,
small shallow pivots dominated by spread, false breakdown/reversal, missed moves
during expiration, clustered overlapping signals, and insufficient opportunities.
No parameter rescue follows a failed V1 under the same trial identifier.

## Separate implementation stage

Proposed module: `Include/RamusenEA/S3BLowerHighContinuationResearch.mqh`.
Own completed-bar state, event queue and labels; default-false enable input and
minimal orchestration only. Reuse conventions, not mutable strategy state, from
S30 and S31: completed indicators, first executable quotes, ASK paths, bounded
missing statuses and tick export. No production execution dependency.

Required CSV additions beyond S31-style clocks/path fields: P/L/Q/C indices,
bar open/close times, pivot recognition times, pivot BID OHLC, Q-bar ASK maximum,
frozen breakdown/stop level, arming context and ATR, each inspected close/context,
expiration/invalidation reason, trigger recognition time, arm status, abstention
indicator, overlap count and opportunity identity. Store recognition timestamps
separately from pivot timestamps to expose look-ahead mistakes.

First action in that separate stage: implement the frozen module and evaluator,
then XAUUSD M5 real-tick January 1–6 exclusive functional test. Verify pivots by
independent completed-bar replay, no hindsight replacement, invalidation priority,
three-bar expiration, first quote and missing/abstention distinction. Only after
that passes may its one registered January–August discovery run start. Do not
combine implementation or outcomes with the completed S3.1 experiment.

Layering remains disabled. If a stronger base alpha eventually survives its cost
gate and future validation design, first layer research is CONTROL_L1 versus
L3_FIXED_TIME versus L3_MARKET_STATE. Maximum new cap is three; L5/L7/L10 remain
blocked until robust opportunity-level incremental edge is demonstrated.
