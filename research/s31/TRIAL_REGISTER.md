# S3.1 trial register

2026-09-05. All January–August data contaminated. Zero clean validation trials.
This continues `research/s3_independent_audit/TRIAL_REGISTER.md`; its historical
snapshot findings and earlier proposed design remain preserved.

1. **S31-V2 freeze:** current user contract supersedes the earlier DELAY_3-focused
   proposal. Four pre-existing arms only: CONTROL, DELAY_1, DELAY_3, DELAY_5.
   Two views only: original+10m and actual-entry+10m. Three paired delay contrasts
   per view, six reported contrasts; these are not six independent discoveries.
   One frozen ATR×1.25 secondary stop diagnostic; five non-spread cost scenarios.
   No new filter, additional delay, stop search, hour/month selection or layer arm.
2. **Engineering:** initial hand-calculated Python fixtures RED then GREEN;
   native MetaEditor compile 0 errors/0 warnings. One trading-conflict test
   produced INIT_FAILED. Initial tester launch configuration included Login=0
   and failed to start correctly; removing that runner-only override used the
   existing copied demo configuration. No EA rule or alpha parameter changed.
3. **S31-A functional:** January1–6 exclusive; 1 opportunity, 8 rows, 9,312 path
   ticks, integrity PASS. A smoke run is not an expectancy observation set.
4. **S31-B full:** January1–August31 exclusive, prior S30 coverage ending Aug28.
   433 opportunities, 3,464 rows, 3,435,431 path ticks. Integrity PASS. Normal
   missing rows: 26. All-arm complete cohorts: common430/equal428. Zero orders.
5. **Decision-policy correction after full run:** initial evaluator applied the
   added 99% completeness gate before any negative decision, yielding
   INCONCLUSIVE; preserved in `results/full/decision_pre_review.json`. Corrected
   ordering applies the user's explicit negative rule on observed paired cases,
   while the failed 99% coverage flag still blocks positive support. Outcome
   tables, raw data, frozen manifest, contrasts and thresholds remain unchanged.
   Three regression tests protect this distinction. Final research disposition:
   **DELAY_MECHANISM_REJECTED on observed pairs**, with coverage limitation.
   This correction is not a fresh or preregistered statistical result.
6. **Export-validator review:** added spread/holding-clock corruption fixtures,
   observed RED, added checks and obtained GREEN. Strengthened recorded latency,
   exit BID, orphan-path, manifest-count and pending/missing checks. Eleven tests
   pass; full stored tick export revalidated. No new MT5 run or hypothesis trial.
7. **Delay family closed:** no DELAY_2/4/6, seconds search or filter rescue.
   `S3B_FROZEN_SPEC.md` is the separate next-stage hypothesis specification.
   S3-B outcome tests and MQL5 implementations in S3.1: **ZERO**.

Current production status: BLOCKED. New layer experiments: ZERO. Future initial
layer cap: 3 only after stronger base alpha; no L5/L7/L10 implementation now.
