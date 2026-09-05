# S3.1 design review and implementation freeze

The current user specification supersedes the earlier proposed S31 contract.
All 0/1/3/5-minute arms are contaminated mechanism research, equally eligible
for assessment; DELAY_3 has no privileged confirmatory status. DELAY_5 means
exactly t0+300 seconds. Only common-original+10m and actual-entry+10m exits and
0/.5/1/1.5/2 bps round-trip extra cost are studied. No optional filter or layer.

The frozen machine-readable contract is manifest.json. To make “material”
excursion deterioration deterministic before observing equal-hold results,
noninferiority tolerances are 0.10 ORIGINAL ATR for mean MAE increase and mean
MFE reduction. These are declared practical tolerances, not PnL-optimized values.
Support also requires positive paired trimmed/ex-tail statistics, all three
chronological blocks, leave-one-month-out means and a simultaneous conservative
98.333% day-cluster interval. Report ordinary 95% intervals too. Insufficient
coverage or inconsistent paths blocks a mechanism decision.

Source tracing: RamusenEA OnTick runs research processing before its new-M5
return; S31 uses that location. S30 detects events independently of S2 on closed
M5 EMA shifts2/1 and M15 shift1, primes its initial bar clock and uses the first
new-bar tick. S31 mirrors that event definition without modifying S30 and verifies
all event timestamps and quotes against its CSV. Original ATR is captured at the
event, never from the delayed bar. Existing SignalEngine has the same crossover
predicate; ScalpingContext/EntryGate supply the same closed context conventions.
S2 is history-dependent and must not feed S31. ExcursionResearch demonstrates
chronological CopyTicksRange ASK extrema; ControlledLayerResearch confirms ASK
first-touch fills but is excluded. MarketSnapshot provides quotes/point;
RiskManager/Execution have no role in S31 virtual outcomes.

Implementation: a separate module owns indicator handles, original event queue,
bounded tick retrieval and output. Scheduled quote selection is deterministic
and uses no outcome-dependent eligibility. Once the maximum 16m label window
matures, retrieve historical ticks only through that known time. Reconstruct
M15 at entry using the completed bar as-of the entry time, record its timestamp
and values without gating. This retrospective labeler does not send orders.
At shutdown, evaluate only already observed ticks and emit immature statuses.
Missing quotes are normal data availability statuses; invalid quotes, copy errors,
nonmonotonic time or inconsistent event quotes mark a corrupt run and halt new
event capture. No endless retry. A footer distinguishes missing/pending from fatal.

Initialization rejects non-tester use, September+ starts, wrong symbol/timeframe,
trading/baseline/execution-test enabled, S2/layers/retention and other legacy
research enabled. S30 may run alongside for direct event pairing. Runtime stops
before September label access. Production order methods are never called.

Changes: new S31PairedDelayedEntryResearch.mqh; one default-false Config input;
include/instance/guarded initialize/tick/shutdown hooks in the EA only. Preserve
original files and hashes because this workspace is not a Git repository.

Verification sequence: hand-calculated independent Python tick fixtures (RED then
GREEN); MetaEditor compile; negative initialization tests; January1–6 real-tick
functional replay with S30; verify eight rows per event, exact event/arm clocks,
quote/math/stop/MAE/MFE replay and missing/pending cases. Only then one full
January1–August31-exclusive replay matching the prior S30 coverage. No September
outcomes. If the mechanism rejects, close fixed delays and prepare S3-B's frozen
specification; do not mix S3-B implementation into this experiment.

Completion note, 2026-09-05: the implementation and both authorized tester stages
are complete; see RESULTS.md. The original blanket coverage wording above is
preserved as design history. A disclosed post-run classifier correction applies
the user's negative rule on observed pairs while retaining the 99% coverage flag
to block positive support. Raw data and frozen manifest/thresholds are unchanged.
