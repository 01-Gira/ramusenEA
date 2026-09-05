#ifndef RAMUSEN_SCALPING_CANDIDATE_S2_RESEARCH_MQH
#define RAMUSEN_SCALPING_CANDIDATE_S2_RESEARCH_MQH

#include "Config.mqh"
#include "Types.mqh"

// =====================================================
// P2F.12 — CANDIDATE S2 EDGE-STATE RESEARCH
//
// Base:
//   SELL M5 EMA9/21 bearish crossover
//   M15 EMA20 < EMA50
//
// Adaptive gate:
//   Warmup = 20 valid completed SHADOW S1 outcomes
//   last20 mean executable 10m return > +1.0 bps
//   last20 median executable 10m return > 0
//   last5  mean executable 10m return > 0
//
// Every S1 candidate is shadow-observed even when S2
// rejects it. This avoids self-starvation and allows
// the state gate to recover when alpha returns.
//
// Risk path:
//   1.25 ATR(M5,14) hard SL
//   10m time exit
//   no profit retention
//
// Research only. No real orders.
// =====================================================

struct S2ResearchEvent
{
   datetime signal_time;
   ulong signal_time_msc;
   datetime signal_bar_time;

   double entry_bid;
   double entry_ask;
   double entry_mid;
   double spread_points;

   double atr_value;

   bool s2_eligible;
   string gate_reason;

   int history_count;
   double mean20_bps;
   double median20_bps;
   double mean5_bps;

   int analyze_failures;
};


class CScalpingCandidateS2Research
{
private:

   int csvHandle;
   string csvFileName;

   string researchSymbol;
   ENUM_TIMEFRAMES entryTimeframe;

   int atrHandle;
   bool ready;

   S2ResearchEvent events[];

   double shadowHistoryBps[];

   ulong recordedCount;
   ulong completedCount;
   ulong eligibleCount;
   ulong failedCount;

   bool integrityDegraded;
   string lastAnalyzeError;


   bool ReadATR(double &value)
   {
      if(atrHandle == INVALID_HANDLE)
         return false;

      double buffer[1];

      int copied =
         CopyBuffer(
            atrHandle,
            0,
            1,
            1,
            buffer
         );

      if(copied != 1)
         return false;

      value = buffer[0];

      return value > 0.0;
   }


   double MeanLast(const int count)
   {
      int total = ArraySize(shadowHistoryBps);

      if(total < count || count <= 0)
         return 0.0;

      double sum = 0.0;

      for(int i = total - count; i < total; i++)
         sum += shadowHistoryBps[i];

      return sum / (double)count;
   }


   double MedianLast(const int count)
   {
      int total = ArraySize(shadowHistoryBps);

      if(total < count || count <= 0)
         return 0.0;

      double work[];

      ArrayResize(work, count);

      int start = total - count;

      for(int i = 0; i < count; i++)
         work[i] = shadowHistoryBps[start + i];

      ArraySort(work);

      if((count % 2) == 1)
         return work[count / 2];

      return
         (
            work[(count / 2) - 1]
            +
            work[count / 2]
         )
         /
         2.0;
   }


   void AppendShadowOutcome(const double bps)
   {
      int n = ArraySize(shadowHistoryBps);

      ArrayResize(
         shadowHistoryBps,
         n + 1
      );

      shadowHistoryBps[n] = bps;
   }


   bool FindTargetTick(
      const ulong targetTimeMsc,
      MqlTick &resultTick,
      long &delayMilliseconds,
      string &status
   )
   {
      const ulong MAX_DELAY_MSC = 30000ULL;

      MqlTick ticks[];

      ResetLastError();

      int copied =
         CopyTicksRange(
            researchSymbol,
            ticks,
            COPY_TICKS_ALL,
            targetTimeMsc,
            targetTimeMsc + MAX_DELAY_MSC
         );

      if(copied < 0)
      {
         status =
            StringFormat(
               "COPY_TARGET_FAILED_%d",
               GetLastError()
            );

         return false;
      }

      if(copied == 0)
      {
         status = "NO_TICK_NEAR_TARGET";
         return true;
      }

      bool found = false;
      ulong earliest = 0;

      for(int i = 0; i < copied; i++)
      {
         if((ulong)ticks[i].time_msc < targetTimeMsc)
            continue;

         if(!found || (ulong)ticks[i].time_msc < earliest)
         {
            found = true;
            earliest = (ulong)ticks[i].time_msc;
            resultTick = ticks[i];
         }
      }

      if(!found)
      {
         status = "NO_TICK_NEAR_TARGET";
         return true;
      }

      delayMilliseconds =
         (long)(
            resultTick.time_msc -
            targetTimeMsc
         );

      status = "OK";

      return true;
   }


   // ==================================================
   // Write one terminal research-status row.
   //
   // Used for explicit data-quality failures and for
   // pending events that are still immature at shutdown.
   //
   // IMPORTANT:
   // These rows NEVER update shadowHistoryBps because
   // there is no valid completed 10-minute outcome.
   // ==================================================

   void WriteTerminalStatusRow(
      const S2ResearchEvent &event,
      const string status
   )
   {
      FileWrite(
         csvHandle,

         StringFormat(
            "%I64u_SELL",
            event.signal_time_msc
         ),

         TimeToString(
            event.signal_time,
            TIME_DATE | TIME_SECONDS
         ),

         event.signal_time_msc,

         "SELL",

         event.s2_eligible ? "ELIGIBLE" : "REJECT",
         event.gate_reason,

         event.history_count,

         DoubleToString(event.mean20_bps, 6),
         DoubleToString(event.median20_bps, 6),
         DoubleToString(event.mean5_bps, 6),

         status,

         DoubleToString(event.entry_bid, _Digits),
         DoubleToString(event.entry_ask, _Digits),

         "", // target_ask
         "", // shadow_10m_bps

         DoubleToString(event.atr_value, _Digits),

         "", // stop_distance
         "", // exit_mode
         "", // exit_time_msc
         "", // exit_ask
         "", // observed_r
         "", // nominal_net_r_1bps
         ""  // stress_net_r_2bps
      );

      FileFlush(csvHandle);
   }


   bool AnalyzeEvent(
      const S2ResearchEvent &event
   )
   {
      lastAnalyzeError = "";

      const double STOP_MULTIPLIER = 1.25;

      ulong targetTimeMsc =
         event.signal_time_msc
         +
         10ULL * 60ULL * 1000ULL;


      MqlTick targetTick;
      long targetDelayMilliseconds = 0;
      string targetStatus = "";


      if(
         !FindTargetTick(
            targetTimeMsc,
            targetTick,
            targetDelayMilliseconds,
            targetStatus
         )
      )
      {
         lastAnalyzeError =
            targetStatus != ""
            ? targetStatus
            : "TARGET_TICK_LOOKUP_FAILED";

         return false;
      }


      if(targetStatus != "OK")
      {
         FileWrite(
            csvHandle,

            StringFormat(
               "%I64u_SELL",
               event.signal_time_msc
            ),

            TimeToString(
               event.signal_time,
               TIME_DATE | TIME_SECONDS
            ),

            event.signal_time_msc,

            "SELL",

            event.s2_eligible ? "ELIGIBLE" : "REJECT",
            event.gate_reason,

            event.history_count,

            DoubleToString(event.mean20_bps, 6),
            DoubleToString(event.median20_bps, 6),
            DoubleToString(event.mean5_bps, 6),

            targetStatus,

            DoubleToString(event.entry_bid, _Digits),
            DoubleToString(event.entry_ask, _Digits),

            "",
            "",
            "",
            "",
            "",
            "",
            "",
            ""
         );

         FileFlush(csvHandle);

         return true;
      }


      double shadow10mBps =
         (
            event.entry_bid -
            targetTick.ask
         )
         /
         event.entry_bid
         *
         10000.0;


      double stopDistance =
         event.atr_value *
         STOP_MULTIPLIER;


      double hardStopPrice =
         event.entry_bid +
         stopDistance;


      MqlTick path[];

      ResetLastError();

      int copied =
         CopyTicksRange(
            researchSymbol,
            path,
            COPY_TICKS_ALL,
            event.signal_time_msc,
            targetTimeMsc
         );


      if(copied < 0)
      {
         lastAnalyzeError =
            StringFormat(
               "COPY_PATH_FAILED_%d",
               GetLastError()
            );

         return false;
      }


      if(copied == 0)
      {
         lastAnalyzeError =
            "NO_PATH_TICKS";

         return false;
      }


      string exitMode = "TIME_EXIT";
      ulong exitTimeMsc = targetTick.time_msc;
      double exitAsk = targetTick.ask;


      for(int i = 0; i < copied; i++)
      {
         if(path[i].ask <= 0.0)
            continue;

         if(path[i].ask >= hardStopPrice)
         {
            exitMode = "HARD_SL";
            exitTimeMsc = path[i].time_msc;
            exitAsk = path[i].ask;
            break;
         }
      }


      double observedR =
         (
            event.entry_bid -
            exitAsk
         )
         /
         stopDistance;


      double stopBps =
         stopDistance /
         event.entry_bid *
         10000.0;


      double nominalNetR =
         observedR -
         1.0 / stopBps;


      double stressNetR =
         observedR -
         2.0 / stopBps;


      FileWrite(
         csvHandle,

         StringFormat(
            "%I64u_SELL",
            event.signal_time_msc
         ),

         TimeToString(
            event.signal_time,
            TIME_DATE | TIME_SECONDS
         ),

         event.signal_time_msc,

         "SELL",

         event.s2_eligible ? "ELIGIBLE" : "REJECT",
         event.gate_reason,

         event.history_count,

         DoubleToString(event.mean20_bps, 6),
         DoubleToString(event.median20_bps, 6),
         DoubleToString(event.mean5_bps, 6),

         "OK",

         DoubleToString(event.entry_bid, _Digits),
         DoubleToString(event.entry_ask, _Digits),

         DoubleToString(
            targetTick.ask,
            _Digits
         ),

         DoubleToString(
            shadow10mBps,
            6
         ),

         DoubleToString(
            event.atr_value,
            _Digits
         ),

         DoubleToString(
            stopDistance,
            _Digits
         ),

         exitMode,

         exitTimeMsc,

         DoubleToString(
            exitAsk,
            _Digits
         ),

         DoubleToString(
            observedR,
            6
         ),

         DoubleToString(
            nominalNetR,
            6
         ),

         DoubleToString(
            stressNetR,
            6
         )
      );


      FileFlush(csvHandle);


      // IMPORTANT:
      // Every valid S1 outcome updates the SHADOW history,
      // whether S2 traded it or rejected it.
      AppendShadowOutcome(
         shadow10mBps
      );


      return true;
   }


   void RemoveFirstEvent()
   {
      int total = ArraySize(events);

      if(total <= 0)
         return;

      for(int i = 0; i < total - 1; i++)
         events[i] = events[i + 1];

      ArrayResize(
         events,
         total - 1
      );
   }


public:

   CScalpingCandidateS2Research()
   {
      csvHandle = INVALID_HANDLE;
      csvFileName = "";

      researchSymbol = "";
      entryTimeframe = PERIOD_CURRENT;

      atrHandle = INVALID_HANDLE;
      ready = false;

      recordedCount = 0;
      completedCount = 0;
      eligibleCount = 0;
      failedCount = 0;

      integrityDegraded = false;
      lastAnalyzeError = "";

      ArrayResize(events, 0);
      ArrayResize(shadowHistoryBps, 0);
   }


   bool Initialize(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe
   )
   {
      Shutdown();

      researchSymbol = symbol;
      entryTimeframe = timeframe;


      if(entryTimeframe != PERIOD_M5)
         return false;


      if(
         InpFastMAPeriod != 9
         ||
         InpSlowMAPeriod != 21
      )
      {
         return false;
      }


      if(
         InpScalpingContextTimeframe != PERIOD_M15
         ||
         InpScalpingContextFastMAPeriod != 20
         ||
         InpScalpingContextSlowMAPeriod != 50
      )
      {
         return false;
      }


      if(InpScalpingATRPeriod != 14)
         return false;


      atrHandle =
         iATR(
            researchSymbol,
            PERIOD_M5,
            14
         );


      if(atrHandle == INVALID_HANDLE)
         return false;


      long sessionStamp =
         (long)TimeLocal();


      csvFileName =
         StringFormat(
            "RamusenEA_candidate_s2_%s_%s_%I64d.csv",
            researchSymbol,
            EnumToString(entryTimeframe),
            sessionStamp
         );


      csvHandle =
         FileOpen(
            csvFileName,
            FILE_WRITE |
            FILE_CSV |
            FILE_COMMON |
            FILE_ANSI,
            ','
         );


      if(csvHandle == INVALID_HANDLE)
         return false;


      FileWrite(
         csvHandle,

         "research_join_key",
         "signal_time",
         "signal_time_msc",
         "side",

         "s2_gate",
         "gate_reason",

         "history_count",
         "mean20_shadow_bps",
         "median20_shadow_bps",
         "mean5_shadow_bps",

         "status",

         "entry_bid",
         "entry_ask",
         "target_ask",
         "shadow_10m_bps",

         "m5_atr",
         "stop_distance",

         "exit_mode",
         "exit_time_msc",
         "exit_ask",

         "observed_r",
         "nominal_net_r_1bps",
         "stress_net_r_2bps"
      );


      FileFlush(csvHandle);

      ArrayResize(events, 0);
      ArrayResize(shadowHistoryBps, 0);

      recordedCount = 0;
      completedCount = 0;
      eligibleCount = 0;
      failedCount = 0;

      integrityDegraded = false;
      lastAnalyzeError = "";

      ready = true;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F12_S2_READY warmup=20 mean20_gt=1bps median20_gt=0 mean5_gt=0 file=%s",
            csvFileName
         )
      );


      return true;
   }


   bool RecordEligibleS1(
      const datetime signalTime,
      const datetime signalBarTime,
      const ENUM_RAMUSEN_SIGNAL signal,
      const MarketSnapshot &market,
      bool &s2EligibleOut,
      ulong &signalTimeMscOut,
      double &atrValueOut
   )
   {
      s2EligibleOut = false;
      signalTimeMscOut = 0;
      atrValueOut = 0.0;

      if(!ready)
         return false;


      if(signal != RAMUSEN_SIGNAL_SELL)
         return false;


      ulong signalTimeMsc =
         (ulong)signalTime *
         1000ULL;


      MqlTick currentTick;

      if(
         SymbolInfoTick(
            researchSymbol,
            currentTick
         )
         &&
         currentTick.time_msc > 0
      )
      {
         signalTimeMsc =
            currentTick.time_msc;
      }


      double atrValue = 0.0;

      if(!ReadATR(atrValue))
         return false;


      int historyCount =
         ArraySize(
            shadowHistoryBps
         );


      double mean20 = 0.0;
      double median20 = 0.0;
      double mean5 = 0.0;

      bool eligible = false;
      string reason = "WARMUP";


      if(historyCount >= 20)
      {
         mean20 = MeanLast(20);
         median20 = MedianLast(20);
         mean5 = MeanLast(5);


         if(mean20 <= 1.0)
         {
            reason =
               "MEAN20_NOT_ABOVE_1BPS";
         }
         else if(median20 <= 0.0)
         {
            reason =
               "MEDIAN20_NOT_POSITIVE";
         }
         else if(mean5 <= 0.0)
         {
            reason =
               "MEAN5_NOT_POSITIVE";
         }
         else
         {
            eligible = true;
            reason = "EDGE_STATE_PASS";
         }
      }


      s2EligibleOut = eligible;
      signalTimeMscOut = signalTimeMsc;
      atrValueOut = atrValue;

      int index =
         ArraySize(events);

      ArrayResize(
         events,
         index + 1
      );


      events[index].signal_time =
         signalTime;

      events[index].signal_time_msc =
         signalTimeMsc;

      events[index].signal_bar_time =
         signalBarTime;

      events[index].entry_bid =
         market.bid;

      events[index].entry_ask =
         market.ask;

      events[index].entry_mid =
         (
            market.bid +
            market.ask
         ) / 2.0;

      events[index].spread_points =
         market.spread_points;

      events[index].atr_value =
         atrValue;

      events[index].s2_eligible =
         eligible;

      events[index].gate_reason =
         reason;

      events[index].history_count =
         historyCount;

      events[index].mean20_bps =
         mean20;

      events[index].median20_bps =
         median20;

      events[index].mean5_bps =
         mean5;

      events[index].analyze_failures =
         0;


      recordedCount++;

      if(eligible)
         eligibleCount++;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F12_S2_RECORDED join=%I64u_SELL gate=%s reason=%s hist=%d mean20=%.3f median20=%.3f mean5=%.3f",
            signalTimeMsc,
            eligible ? "ELIGIBLE" : "REJECT",
            reason,
            historyCount,
            mean20,
            median20,
            mean5
         )
      );


      return true;
   }


   // Compatibility wrapper for callers that do not need
   // the contemporaneous frozen S2 gate decision.
   bool RecordEligibleS1(
      const datetime signalTime,
      const datetime signalBarTime,
      const ENUM_RAMUSEN_SIGNAL signal,
      const MarketSnapshot &market
   )
   {
      bool ignoredEligible = false;
      ulong ignoredSignalTimeMsc = 0;
      double ignoredAtrValue = 0.0;

      return RecordEligibleS1(
         signalTime,
         signalBarTime,
         signal,
         market,
         ignoredEligible,
         ignoredSignalTimeMsc,
         ignoredAtrValue
      );
   }


   void Process(const datetime now)
   {
      if(!ready)
         return;


      ulong nowMsc =
         (ulong)now *
         1000ULL;


      const ulong MATURITY_MSC =
         (
            10ULL *
            60ULL *
            1000ULL
         )
         +
         30000ULL;


      // Events are appended chronologically.
      // Process oldest matured event first so shadow
      // history remains strictly causal.
      while(ArraySize(events) > 0)
      {
         ulong maturity =
            events[0].signal_time_msc
            +
            MATURITY_MSC;


         if(nowMsc < maturity)
            break;


         if(!AnalyzeEvent(events[0]))
         {
            const int MAX_ANALYZE_FAILURES = 3;

            events[0].analyze_failures++;

            string failureStatus =
               lastAnalyzeError != ""
               ? lastAnalyzeError
               : "ANALYZE_EVENT_FAILED";


            if(
               events[0].analyze_failures <
               MAX_ANALYZE_FAILURES
            )
            {
               Print(
                  "[RAMUSEN][WARN] ",
                  StringFormat(
                     "P2F12_S2_EVENT_RETRY join=%I64u_SELL status=%s attempt=%d/%d signal_time=%s",
                     events[0].signal_time_msc,
                     failureStatus,
                     events[0].analyze_failures,
                     MAX_ANALYZE_FAILURES,
                     TimeToString(
                        events[0].signal_time,
                        TIME_DATE | TIME_SECONDS
                     )
                  )
               );

               // Preserve strict chronological state while a
               // transient history/tick failure is retried.
               // Retry is bounded so the FIFO cannot stall forever.
               break;
            }


            WriteTerminalStatusRow(
               events[0],
               failureStatus
            );

            Print(
               "[RAMUSEN][ERROR] ",
               StringFormat(
                  "P2F12_S2_EVENT_QUARANTINED join=%I64u_SELL status=%s attempts=%d signal_time=%s history=%d gate=%s",
                  events[0].signal_time_msc,
                  failureStatus,
                  events[0].analyze_failures,
                  TimeToString(
                     events[0].signal_time,
                     TIME_DATE | TIME_SECONDS
                  ),
                  events[0].history_count,
                  events[0].s2_eligible ? "ELIGIBLE" : "REJECT"
               )
            );

            failedCount++;
            integrityDegraded = true;

            // Terminally quarantine after bounded retries so one
            // permanent CopyTicksRange failure cannot stall the
            // entire FIFO. No shadow outcome is appended.
            RemoveFirstEvent();

            continue;
         }


         completedCount++;

         RemoveFirstEvent();
      }
   }


   void Shutdown()
   {
      int pendingCount =
         ArraySize(events);


      if(ready && pendingCount > 0)
      {
         integrityDegraded = true;

         for(int i = 0; i < pendingCount; i++)
         {
            ulong maturityTimeMsc =
               events[i].signal_time_msc
               +
               (
                  10ULL *
                  60ULL *
                  1000ULL
               )
               +
               30000ULL;

            Print(
               "[RAMUSEN][WARN] ",
               StringFormat(
                  "P2F12_S2_PENDING_AT_SHUTDOWN join=%I64u_SELL signal_time=%s maturity_time_msc=%I64u gate=%s reason=%s history=%d",
                  events[i].signal_time_msc,
                  TimeToString(
                     events[i].signal_time,
                     TIME_DATE | TIME_SECONDS
                  ),
                  maturityTimeMsc,
                  events[i].s2_eligible ? "ELIGIBLE" : "REJECT",
                  events[i].gate_reason,
                  events[i].history_count
               )
            );

            if(csvHandle != INVALID_HANDLE)
            {
               WriteTerminalStatusRow(
                  events[i],
                  "PENDING_AT_SHUTDOWN"
               );
            }
         }
      }


      if(ready)
      {
         Print(
            integrityDegraded
            ? "[RAMUSEN][WARN] "
            : "[RAMUSEN][INFO] ",

            StringFormat(
               "P2F12_S2_SUMMARY recorded=%I64u completed=%I64u failed=%I64u eligible=%I64u history=%d pending=%d integrity=%s",
               recordedCount,
               completedCount,
               failedCount,
               eligibleCount,
               ArraySize(shadowHistoryBps),
               pendingCount,
               integrityDegraded ? "DEGRADED" : "OK"
            )
         );
      }


      if(atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(atrHandle);
         atrHandle = INVALID_HANDLE;
      }


      if(csvHandle != INVALID_HANDLE)
      {
         FileFlush(csvHandle);
         FileClose(csvHandle);
         csvHandle = INVALID_HANDLE;
      }


      ArrayResize(events, 0);
      ArrayResize(shadowHistoryBps, 0);

      ready = false;
   }


   string CsvFileName()
   {
      return csvFileName;
   }


   string CsvDirectory()
   {
      return
         TerminalInfoString(
            TERMINAL_COMMONDATA_PATH
         )
         +
         "\\Files\\";
   }
};


#endif
