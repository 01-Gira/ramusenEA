# S3.1 paired delayed-entry mechanism research

Research-only. Default disabled. All January–August results are contaminated.
No production or layer approval can be produced by this experiment.

## Files and changes

- `Include/RamusenEA/S31PairedDelayedEntryResearch.mqh`: separate virtual labeler.
- `Include/RamusenEA/Config.mqh`: one default-false enable flag.
- `Experts/RamusenEA/RamusenEA.mq5`: guarded initialize, every-tick and shutdown
  calls plus module include/instance. Production entry/exit/risk rules unchanged.
- `evaluate.py`: independent complete tick-path replay, integrity and statistical
  evaluation; no MQL5-derived metric is accepted without recomputation.
- `manifest.json`: frozen design; `DESIGN_REVIEW.md`: review and dependencies.
- `baseline/`: original changed files and source hashes, since no Git repository
  is present. S30 must remain byte-identical to baseline hash.
- `build_manifest.json`, `compile.log`, `RamusenEA_S31.ex5`: generated build evidence.
- `mt5_runner.py`: isolated portable compile/test runner; never installs the EA
  into existing live charts. Local demo-feed settings are copied privately to
  temporary terminal storage; no credentials are printed or exported here.

## Functional test instructions

1. Compile the EA with the new include tree in MetaEditor. Require 0 errors and
   0 warnings; preserve source/EX5 hashes. The supplied runner stages it in
   `/private/tmp/ramusen-s31-mt5` and uses a separate `S31Research` expert path.
2. Negative guard: S31=true and InpEnableTrading=true must return INIT_FAILED
   before any order processing. Terminal-level live trading remains disabled
   even during this negative input test. Also inspect code guards for wrong
   timeframe/symbol, legacy module combinations and non-tester operation.
3. Load `s31_functional.set`: S31 and S30 true; every other research strategy,
   execution test, baseline and trading flag false. XAUUSD M5, real-tick Model=4,
   optimization/forward/cloud/remote OFF. January 1–6 exclusive, 2026.
4. Confirm the tester has completed and S31 prints a terminal summary. Preserve
   the CSV, `_ticks.csv` and `_manifest.txt` files with the same stem from the
   terminal COMMON Files directory. S31's unique run stem prevents overwrites.
5. Run `python3 -m unittest discover -s research/s31/tests -v` and:

   `python3 research/s31/evaluate.py PATH_TO_S31.csv --s30 data/RamusenEA_s30_event_control_XAUUSD_PERIOD_M5_1767225600.csv --out research/s31/results/functional --integrity-only`

6. Require eight rows per original opportunity, exact S30 pairing, first actual
   delayed/exit quotes, frozen ATR, independently identical returns/extrema/stop
   fills and no reserved date. A one-event smoke run does not test strategy
   expectancy; use synthetic and subsequent full-run edge cases for missingness.
7. Only after functional integrity passes, use `s31_full.set`/`full.ini` for
   January 1–August 31 exclusive, matching prior S30's 433-opportunity coverage.
   August 31 itself was absent from the prior export; do not silently add it.
   Run the evaluator without `--integrity-only`. Require full event-set coverage
   against all 433 reference crossover events, not just the observed interior.
8. Preserve operational tester logs supporting Model=4, real-tick coverage,
   simulation dates, test completion and zero orders. The custom labeler does
   not inherit order-delay settings as virtual slippage; use explicit bps costs.

The runner actions are `stage`, `compile`, `guard`, `functional`, `full`. Wine
launches require desktop permission. `full` refuses to start without a passing
functional `integrity.json`. It does not optimize or start forward validation.

## CSV schema

One outcome row = original opportunity × arm × exit view; 4×2 rows per event,
including explicit missing/pending status rows. Primary key:
`original_event_time_msc,arm,exit_view`. Run stem distinguishes repetitions;
repeated runs are never additional independent opportunities.

Header is generated verbatim in `schema.csv`. Groups:

- Identity/provenance: schema_version, run_id, symbol, SELL side, original time,
  signal/context closed-bar times, completed EMA values, frozen original quotes
  and ATR, point and fixed stop distance.
- Clocks: entry target/actual/time/latency/index; common-original+10m target;
  actual-entry+10m target; selected exit target/actual/time/latency/index and
  actual holding milliseconds. Preserve native order for same-ms ticks.
- Entry: executable BID/ASK, spread points/bps, higher-BID improvement in
  price/points/bps; delayed M15 completed bar time and EMA/state diagnostic.
- Uncensored labels: gross executable bps/R, mid return, ASK extrema, clipped
  MFE/MAE in bps and ORIGINAL ATR, first-extreme time, tick count/max gap.
  `time_to_mfe_ms=-1` means no positive executable excursion occurred.
- Frozen-risk secondary labels: entry BID +1.25 ORIGINAL ATR stop, first-touch
  hit/time/actual ASK, stop-through, and stopped-or-time-exit R. `stop_r` is the
  actual risk-view result even when no stop was hit; consult `stop_hit`.
- Costs: net_bps_0/0_5/1/1_5/2. One round-trip charge per arm, not per side;
  spread already embedded. These are non-spread-cost scenarios, not calibrated
  broker commission claims.
- Status: OK, ENTRY_MISSING, EXIT_MISSING, PENDING_AT_SHUTDOWN, or explicit fatal
  corruption/copy errors. Empty unavailable values are never zero returns.

The ticks companion records original event, sequential tick index, milliseconds,
BID, ASK and flags. It contains the entire observed event window through at most
16m, exported once per base event rather than once per arm. It may contain
post-exit ticks; the evaluator uses the exact entry–exit subpath only. Label
maturity does not make any future feature eligible at entry.

## Integrity PASS/FAIL checklist

- [ ] Compile cleanly; default enable flag false; no order API in S31.
- [ ] Trading conflict returns INIT_FAILED; no legacy layer/retention interaction.
- [ ] S30 source unchanged; exact original event/quote/predicate reproduction.
- [ ] Eight unique arm/view rows for each event; no missing rows masquerading as
      unavailable outcomes, and no duplicated statistical opportunities.
- [ ] Original ATR identical across arms; no future context bar at entry.
- [ ] First executable quotes and actual holding clocks agree with raw paths.
- [ ] Return, spread, entry improvement, MFE/MAE and stopped R recompute.
- [ ] ASK first-touch uses actual stop-through, including same-ms tick ordering.
- [ ] Pending at shutdown observable; missing targets bounded to 30 seconds.
- [ ] Normal missingness counted separately from corruption; zero infinite retry.
- [ ] No September+ event/tick/label access; complete full reference cohort.
- [ ] Tester provenance checked separately from numeric consistency; max gaps and
      missingness reported. CopyTicksRange alone is not proof of every real tick.
- [ ] Mechanism decision uses paired complete cohorts and multiplicity-aware CIs;
      no production approval, no new delay search, no layer enablement.

Actual completed checks and limitations are recorded in RESULTS.md and the
per-run integrity/decision JSON files. Never assume an unchecked item passed.
