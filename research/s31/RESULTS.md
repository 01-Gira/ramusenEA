# S3.1 completed research: delay mechanism rejected

Date: 2026-09-05. Classification: **CONTAMINATED MECHANISM RESEARCH ONLY**.
Production remains blocked. S1/S2 remain failed; old P2F.14 remains
FAIL_KEEP_CONTROL. No additional delay values, filters, risk tuning or layers
were tested. September onward outcomes were not inspected.

The remaining equal-holding-time hypothesis fails the user's negative research
rule: all three existing delay arms have lower mean, trimmed mean and ex-best1
return than CONTROL. Their paired robust increments are negative too. Average
MAE increases with a full 10-minute hold. Close blanket delay research; retain
EMA9/21 only as the previously supported event/timing generator, not primary alpha.
Prepare the separate S3-B structural hypothesis; it has no measured edge yet.

## Completed implementation and evidence

- Separate research-only module: `Include/RamusenEA/S31PairedDelayedEntryResearch.mqh`.
  Config adds one default-false input. EA adds include/instance/init/tick/shutdown
  hooks. Production entry, order, exit and risk logic is unchanged; shared EA
  source files did change. All other original source hashes, including S30,
  remain unchanged. Sources match `build_manifest.json` and the tested EX5.
- MetaEditor compilation: **0 errors, 0 warnings** (`compile.log`).
- Trading-conflict negative test: **INIT_FAILED**, as required (`results/guard_log.txt`).
  Terminal-level live trading stayed disabled during this input-conflict test.
- S3.1A: January 1–6 exclusive, XAUUSD M5, real ticks; 1 original opportunity,
  8 rows, 9,312 path ticks; independently replayed integrity PASS.
- S3.1B: January 1–August 31 exclusive, matching the prior S30 export ending
  August 28. **433 opportunities; 3,464 rows; 3,435,431 exported path ticks**.
  Every original event and original quote matches S30. Full integrity PASS,
  zero errors. This is not a new validation sample.
- Isolated portable MetaQuotes-Demo tester, build 6180, Model=4, optimization,
  forward/cloud/remote disabled. Tester report: 100% real ticks, 109,219,435
  total tester ticks, 45,425 M5 bars, **0 trades**. The exported path ticks cover
  research-event windows only. Final simulated balance remained USD 10,000.
  See `results/full/tester_provenance.txt` and `tester_report_summary.json`.
- Independent evaluator tests: **11 passed**, including hand-calculated ASK
  stop-through, same-ms tick ordering, actual-entry exit clocks, late quotes,
  zero favorable excursion, classification and corrupted export rejection.

The module never calls an order API and cannot initialize outside the tester.
The compiled EA was staged separately; it was not installed into a live chart.

## Cohorts, missingness and decision-policy correction

3,438 output rows are OK; 24 EXIT_MISSING and 2 ENTRY_MISSING. No pending rows or
fatal corruption occurred. Complete all-four-arm cohorts are **430 common
deadline** and **428 equal hold**, respectively 99.307% and **98.845%** of 433.
An unavailable quote after the fixed 30-second target tolerance is not assigned
a zero outcome and is not retried indefinitely.

The five opportunities with some unavailable labels occurred at server times
February 2 23:55, February 10 23:45, March 2 23:50, June 1 22:45 and June 22
22:50. Missingness is concentrated near market closes; outcomes are not missing
at random by assumption. Maximum inter-tick gap within valid labeled paths is
31.952 seconds. The tester's real-tick flag and independent numeric replay do
not prove that the broker recorded every market update or reproduce live latency.

**Post-run evaluator correction is disclosed:** the initial implementation of
an added 99% completeness gate returned INCONCLUSIVE before checking any negative
rule. That result is preserved in `results/full/decision_pre_review.json`.
The user's explicit negative decision rule says to reject when all existing
delay arms fail robust improvement, and distinguishes normal missingness from
integrity corruption. The final classifier applies that negative rule to the
observed paired cohort, while retaining the failed 99% flag to block positive
support. The frozen manifest and original metrics were not rewritten; no
additional tester run, delay search or outcome filtering was performed for this
correction. `decision.json` preserves `coverage_and_sample_gate=false`.

Thus **DELAY_MECHANISM_REJECTED is the research-program disposition on observed
pairs**. It is not a claim that the five missing opportunities cannot change a
population estimate. Keeping the initial blanket coverage policy would leave
the formal label INCONCLUSIVE; either policy supplies no basis to adopt a delay.
All paired 95% intervals span zero, so the evidence does not establish universal
harm from delaying. It also provides no supportive positive mechanism evidence.

## Q1: entry price

SELL improvement = delayed BID minus CONTROL BID. Positive would be better.
These estimates use the common complete cohort of 430. Point size is 0.01.

| Arm | Mean price improvement | Points | bps |
|---|---:|---:|---:|
| DELAY_1 | -0.26823 | -26.823 | -0.54977 |
| DELAY_3 | -0.39858 | -39.858 | -0.82857 |
| DELAY_5 | -0.58826 | -58.826 | -1.23770 |

Waiting gives a lower, worse average SELL entry. DELAY_3 entry-improvement
day-cluster 95% CI is [-1.835, +0.116] bps, reproducing the independent snapshot
finding. All arms' full price/points/bps paired summaries are in `paired_metrics.csv`.

## Q2: common original deadline

Exit target is original event+10m; delayed arms have shorter actual holds.
N=430 for each arm. Returns use entry BID and first executable exit ASK.

| Arm | Mean bps | 10% trimmed mean | Mean increment vs CONTROL |
|---|---:|---:|---:|
| CONTROL | 2.29594 | 0.77262 | 0 |
| DELAY_1 | 1.74801 | 0.60808 | -0.54793 |
| DELAY_3 | 1.46913 | 0.50246 | -0.82681 |
| DELAY_5 | 1.05906 | 0.36214 | -1.23689 |

This reproduces the prior snapshot study. The small difference between entry
improvement bps and return increment reflects the return's arm-specific entry
denominator; it is not a separate alpha mechanism.

## Q3: equal actual holding time

Exit target is each arm's actual entry+10m. N=428 paired opportunities per arm.
No SL censors these primary returns.

| Arm | Mean bps | Median | Trimmed mean | Ex-best1 mean | Ex-top3 mean | Mean 95% day-cluster CI |
|---|---:|---:|---:|---:|---:|---|
| CONTROL | 2.29924 | 1.02590 | 0.77178 | 1.76990 | 1.16676 | [0.156, 4.775] |
| DELAY_1 | 1.78000 | 0.60354 | 0.74801 | 1.25871 | 0.69638 | [-0.238, 4.072] |
| DELAY_3 | 1.43990 | -0.49733 | -0.01108 | 0.98450 | 0.18605 | [-0.578, 3.659] |
| DELAY_5 | 0.98408 | -0.63926 | -0.37620 | 0.44503 | -0.37330 | [-1.117, 3.455] |

Paired increments, always aggregating by the same original event:

| Delay | Mean delta | Median delta | Trimmed delta | Ex-best1 delta | Ex-top3 delta | Positive / negative delta | Paired mean 95% CI |
|---|---:|---:|---:|---:|---:|---|---|
| 1m | -0.51924 | -0.58125 | -0.29782 | -0.59293 | -0.71427 | 45.33% / 54.67% | [-1.327, 0.317] |
| 3m | -0.85935 | 0.31455 | -0.17493 | -1.03993 | -1.30698 | 50.70% / 49.30% | [-2.079, 0.314] |
| 5m | -1.31516 | -0.31157 | -0.27385 | -1.68774 | -2.00099 | 48.13% / 51.87% | [-2.992, 0.268] |

DELAY_3's slightly positive paired median does not compensate for its negative
mean, trimmed and ex-tail increments. All three fail the relevant robust tests.
Bootstrap uses 10,000 resampled server-day clusters, seed 3103. Conservative
98.333% intervals for the three contrasts are also exported; none supports a
positive increment. Days, rather than tickets, are the resampling clusters;
serial dependence across different days remains a limitation.

## Q4–Q6: excursion and frozen-stop behavior

All numbers below use the equal-hold cohort of 428 and the original ATR14.
MFE/MAE use every observed ASK from actual entry through actual exit. Favorable
excursion is clipped at zero when no profitable executable excursion occurs.

| Arm | Mean MAE bps | Mean MFE bps | First-touch stop rate | Mean stopped-or-time-exit gross R |
|---|---:|---:|---:|---:|
| CONTROL | 10.16315 | 13.50950 | 17.76% | 0.05752 |
| DELAY_1 | 10.44495 | 13.06834 | 20.33% | 0.05192 |
| DELAY_3 | 10.50469 | 13.34874 | 18.93% | 0.05575 |
| DELAY_5 | 10.81751 | 13.01325 | 17.52% | 0.02738 |

Equal-hold mean MAE changes are +0.282/+0.342/+0.654 bps; MFE changes are
-0.441/-0.161/-0.496 bps. MFE is mostly preserved, but MAE does not improve.
The predefined 0.10 original-ATR excursion tolerances pass; this does not rescue
the failed return conditions.

Common-deadline MAE falls from 10.138 bps to 9.857/8.693/7.632, while MFE falls
from 13.480 to 12.127/10.490/8.643. The apparent adverse-excursion benefit under
the original deadline disappears after granting equal holding time.

Secondary stop = each entry BID + 1.25×ORIGINAL ATR. It uses actual first-touch
ASK, including spread and overshoot, with no idealized -1R fills. Equal-hold
mean stopped-R increments are -0.00560/-0.00177/-0.03015R. No stop-distance tuning
was performed. Full distributions and paired quality statistics are exported.

## Costs

Spread is already embedded in BID/ASK. These are additional round-trip costs
per one virtual ticket, not per side. They are stress scenarios, not a measured
broker commission/slippage calibration. Same bps costs cancel exactly in paired
bps differences; they still reduce each arm's absolute expectancy.

| Additional cost bps | CONTROL mean | DELAY_1 mean | DELAY_3 mean | DELAY_5 mean |
|---:|---:|---:|---:|---:|
| 0 | 2.29924 | 1.78000 | 1.43990 | 0.98408 |
| 0.5 | 1.79924 | 1.28000 | 0.93990 | 0.48408 |
| 1 | 1.29924 | 0.78000 | 0.43990 | -0.01592 |
| 1.5 | 0.79924 | 0.28000 | -0.06010 | -0.51592 |
| 2 | 0.29924 | -0.22000 | -0.56010 | -1.01592 |

At +1 bps, equal-hold trimmed means are -0.228/-0.252/-1.011/-1.376 bps.
No arm demonstrates robust cost-covered base alpha merely because its headline
mean remains positive. Delayed entries have no incremental advantage to preserve.

## Q7: chronological stability

| Partition | N | DELAY_1 mean delta | DELAY_3 mean delta | DELAY_5 mean delta |
|---|---:|---:|---:|---:|
| Jan–Mar | 146 | -1.2433 | -3.1052 | -3.4646 |
| Apr–Jun | 194 | -0.5205 | 0.0814 | -0.2208 |
| Jan–Jun | 340 | -0.8309 | -1.2870 | -1.6137 |
| Jul–Aug | 88 | 0.6847 | 0.7929 | -0.1617 |

July–August does not provide fresh validation; it is contaminated too. The
positive 1m/3m means there have intervals spanning zero. Omitting any single
month leaves the combined mean increment negative for every delay arm. Do not
select months or rescue fixed delay with a session/context/ATR filter.

## Complete metric files and reproducibility

Under `results/full/`:

- `arm_metrics.csv`: each arm/view, ALL, Jan–Jun, Jul–Aug, Jan–Mar, Apr–Jun and
  every month; N, mean, median, positive/negative rate, 10% each-tail trimmed
  mean, ex-best1/3/5, worst1, standard deviation and day-cluster intervals.
- `paired_metrics.csv`: same opportunity joins; return, entry improvement,
  excursion and frozen-stop differences; all required robust summaries.
- `excursion_stop_metrics.csv`: arm-level excursion and stopped-R distributions.
- `cost_metrics.csv`: all five cost scenarios for all arm/view/partition cells.
- `integrity.json`, `decision.json`, original CSV and full `_ticks.csv`: audit trail.

Exact full integrity/evaluation command (no new market-data fetch):

```sh
python3 research/s31/evaluate.py research/s31/results/full/RamusenEA_s31_1767225600_37588.csv --s30 data/RamusenEA_s30_event_control_XAUUSD_PERIOD_M5_1767225600.csv --require-full-reference --out research/s31/results/full
```

Add `--integrity-only` for a fast independent replay without recomputing bootstrap
tables. Schema and implementation/functional instructions are in `schema.csv`,
`README.md` and `DESIGN_REVIEW.md`. The trial history is in `TRIAL_REGISTER.md`.

## Integrity checklist disposition

| Check | Result / evidence |
|---|---|
| Compile/default disabled/no order API | PASS: compile log and source |
| Trading conflict fails initialization | PASS: actual negative tester run |
| Wrong symbol/timeframe/non-tester/legacy combinations | Guards inspected; each combination was not separately runtime-tested |
| Original event matches S30 | PASS: all 433 event timestamps, quotes and crossover values |
| Unique opportunity×arm×view / full arm set | PASS: 433×8 rows, no duplicates |
| Original ATR and closed-bar causal clocks | PASS: source and independent export checks |
| First quotes, target clocks, spreads, returns and holding time | PASS: independent tick replay |
| MFE/MAE / first-touch ASK stop-through | PASS: full replay and hand-calculated fixtures |
| Normal missingness bounded and distinct | PASS: 26 missing rows; no integrity errors |
| Pending at shutdown observable | Implemented/status validated; neither completed run exercised an immature shutdown |
| No reserved dates | PASS: hard cutoff and exported event/tick bounds |
| Real-tick provenance / zero actual orders | PASS: isolated tester log/report; live execution was not used |
| Coverage | WARNING: equal-hold 428/433 is below the added 99% support gate |
| Mechanism support | FAIL for all three delays; negative disposition described above |

No new L3/L5/L7/L10 engine is justified. A new layer remains a separate investment
in the remaining move; positive unrealized L1 PnL does not establish its edge.
Future layer research cap remains three, conditional on stronger base alpha.
The current active engine has one virtual ticket per arm and zero live tickets.
