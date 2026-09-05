# S3 independent audit — analysis plan recorded before new calculations

Date: 2026-09-05. All January–August 2026 observations are contaminated research.
No September-onward outcome inspection. No production source changes. Offline
analysis only; the proposed MQL5 experiment remains unimplemented.

Frozen audit calculations:
- AUDIT-S2: reproduce supplied development and July–August statistics; deduplicate
  overlapping June exports and preserve source/run differences.
- AUDIT-LAYERS: reaggregate the five existing P2F.14 arms by base opportunity;
  7 cost scenarios (0, .5, 1, 1.5, 2, 2.5, 3 bps per round-trip ticket).
  This audits historical arms, not a new layer search.
- A1-SNAPSHOT: all S3.0 crossover events; delays 0,1,3,5 minutes; shared original
  event deadlines 10,15,30 minutes. Nine paired comparisons versus delay 0.
  Main diagnostic: delay 3 at event+10m, motivated by the supplied 1–3m clue.
  All three delay price-improvement CIs use day clusters; report 95% and
  Bonferroni 98.333% intervals for three distinct delay hypotheses. Exit horizons
  share the same entry improvement and are not independent corroborations.
  These are common-deadline diagnostics, NOT equal holding-time experiments.
  A 5m snapshot is not guaranteed to be exactly the next M5 boundary.
- A7/A8-FEATURE: descriptive rank association at 10m for 10 prespecified causal
  features where context joins exist: ATR bps, spread/ATR, M5 fast EMA slope,
  M15 fast EMA slope, M15 EMA separation, 3-bar sell-directed momentum,
  body/range, sell close-location, upper-minus-lower wick/range, range/ATR.
  No PnL threshold search, no filter candidates selected from quantiles.
- A2/A3/A4/A5/A6: inventory causal feature availability and specify falsifiable
  hypotheses; no outcome test without required historical bar/tick paths.

New MQL5 implementation trials in this audit: ZERO.
New layer-trigger backtests in this audit: ZERO.
Clean validation trials in this audit: ZERO.

## Completed audit dispositions

- AUDIT-S2: REPRODUCED_FAIL. 94 development / 25 July–August valid eligible
  opportunities. Later-run June excluded from pooled outcomes.
- AUDIT-LAYERS: REPRODUCED_FAIL_KEEP_CONTROL for every existing added-layer arm.
  Detail/summary reconciliation error <=1.1e-8 R. Seven fixed-path cost scenarios
  report all results; no cost-aware new trigger replay was performed.
- A1-SNAPSHOT: completed nine paired contrasts on common cohorts of
  430/428/424 opportunities at event+10/+15/+30m. All combined mean increments
  negative. DELAY_3 10m contrast -0.8268 bps; direct entry-price bootstrap does not
  support positive improvement. HOLD/FAIL as a general entry-price repair.
- A7/A8-FEATURE: ten rank associations, three reported chronological aggregations
  each, 428 exact joined events. No thresholds, p-value selection or promotions.
- A2/A3/A4/A5/A6: NOT_OUTCOME_TESTED. Exact proposed structural/compression/breakout
  hypotheses documented; incomplete portable bar/tick paths prevent claims.

The next S31 contract is specified for review in FROZEN_S31_DESIGN.md; MQL5
implementation and forward validation have not started. Proposed future layer
triggers, risk models, caps and exits are registered design slots, not tested arms.

## Subsequent S3.1 implementation (2026-09-05)

The paragraphs above describe the completed independent audit at its original
cutoff. S3.1 was subsequently authorized, frozen under the user's revised equal
arm contract, implemented and run separately. See `../s31/TRIAL_REGISTER.md` and
`../s31/RESULTS.md`. Full replay matched all 433 original opportunities, with
430 common-deadline and 428 equal-hold complete pairs. All three equal-hold delay
increments and robust paired trimmed statistics were negative. Final disposition:
DELAY_MECHANISM_REJECTED on observed pairs; the missingness/coverage warning and
post-run decision-classifier correction are disclosed in that register. No new
delay, layer or clean-validation trials. S3-B specification prepared separately;
its implementation and outcome testing were not part of S3.1.
