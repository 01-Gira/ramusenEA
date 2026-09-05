#ifndef RAMUSEN_SCALPING_PROFIT_RETENTION_RESEARCH_MQH
#define RAMUSEN_SCALPING_PROFIT_RETENTION_RESEARCH_MQH

#include "Config.mqh"
#include "Types.mqh"

// =====================================================
// P2F.7 — PROFIT RETENTION RESEARCH
//
// Frozen candidate:
//   P2F4_CANDIDATE_S1
//
// Direction:
//   SELL only
//
// Frozen risk / exit:
//   Hard SL  = 1.25 ATR(M5,14)
//   TimeExit = 10 minutes
//
// Pre-registered arms:
//   CONTROL         : no retention
//   BE_050          : at +0.50R, stop -> 0.00R
//   LOCK_075_025    : at +0.75R, stop -> +0.25R
//   TRAIL_100_050   : at +1.00R, trail 0.50R behind best R
//
// Research only.
// NEVER sends/modifies/closes real orders.
// =====================================================

struct ScalpingProfitRetentionEvent
{
   datetime signal_time;
   ulong    signal_time_msc;
   datetime signal_bar_time;

   double entry_bid;
   double entry_ask;
   double entry_mid;
   double spread_points;

   double atr_value;
   double atr_points;
};


struct ProfitRetentionPolicyState
{
   string policy_id;
   string policy_type;

   double trigger_r;
   double lock_r;
   double trail_gap_r;

   bool activated;
   ulong activation_time_msc;

   double max_favorable_r;

   double stop_price;
   double locked_r;

   bool exited;
   string exit_mode;

   ulong exit_time_msc;
   double exit_ask;
   double exit_r;
};


class CScalpingProfitRetentionResearch
{
private:

   int csvHandle;
   string csvFileName;

   string researchSymbol;
   ENUM_TIMEFRAMES entryTimeframe;

   int atrHandle;

   bool ready;

   ScalpingProfitRetentionEvent events[];

   ulong recordedCount;
   ulong completedEventCount;
   ulong rowCount;


   // ==================================================
   // ATR — completed M5 bar only
   // ==================================================

   bool ReadATR(double &value)
   {
      if(atrHandle == INVALID_HANDLE)
         return false;

      double buffer[1];

      ResetLastError();

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


   // ==================================================
   // First real tick at / after exact +10m target.
   // Maximum accepted delay = 30 seconds.
   // ==================================================

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
               "COPY_TARGET_TICKS_FAILED_%d",
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
   // Policy initialization
   // ==================================================

   void InitPolicy(
      ProfitRetentionPolicyState &state,
      const string policyId,
      const string policyType,
      const double triggerR,
      const double lockR,
      const double trailGapR,
      const double hardStopPrice
   )
   {
      state.policy_id = policyId;
      state.policy_type = policyType;

      state.trigger_r = triggerR;
      state.lock_r = lockR;
      state.trail_gap_r = trailGapR;

      state.activated = false;
      state.activation_time_msc = 0;

      state.max_favorable_r = 0.0;

      state.stop_price = hardStopPrice;
      state.locked_r = -1.0;

      state.exited = false;
      state.exit_mode = "";

      state.exit_time_msc = 0;
      state.exit_ask = 0.0;
      state.exit_r = 0.0;
   }


   // ==================================================
   // Tighten SELL stop.
   //
   // SELL:
   //   hard stop is ABOVE entry.
   //   profit-lock stop moves DOWN as profit increases.
   //
   // lower stop price = tighter / more profit locked.
   // ==================================================

   void TightenSellStop(
      ProfitRetentionPolicyState &state,
      const double entryBid,
      const double stopDistance,
      const double desiredLockedR
   )
   {
      double normalizedLockedR =
         desiredLockedR;

      if(normalizedLockedR < 0.0)
         normalizedLockedR = 0.0;

      double desiredStopPrice =
         entryBid -
         (
            normalizedLockedR *
            stopDistance
         );

      // For SELL, only move stop downward.
      if(desiredStopPrice < state.stop_price)
      {
         state.stop_price =
            desiredStopPrice;

         state.locked_r =
            normalizedLockedR;
      }
   }


   // ==================================================
   // Process one tick for one policy.
   //
   // IMPORTANT ORDER:
   // 1. Existing stop is checked first.
   // 2. If trade survives, current favorable R is read.
   // 3. Retention may then activate/tighten for FUTURE ticks.
   //
   // This avoids retroactively applying a new stop to the
   // same tick that first created the trigger.
   // ==================================================

   void ProcessPolicyTick(
      ProfitRetentionPolicyState &state,
      const MqlTick &tick,
      const double entryBid,
      const double stopDistance
   )
   {
      if(state.exited)
         return;

      double ask = tick.ask;

      if(ask <= 0.0)
         return;


      // Existing stop hit?
      if(ask >= state.stop_price)
      {
         state.exited = true;

         state.exit_mode =
            state.activated
            ? "RETENTION_STOP"
            : "HARD_SL";

         state.exit_time_msc =
            tick.time_msc;

         state.exit_ask =
            ask;

         // Observed first-touch accounting.
         //
         // The actual tick ASK may cross beyond the intended
         // stop price, so realized R must use the executable
         // first-touch tick rather than an idealized locked_r
         // or exact -1.0R hard stop.
         state.exit_r =
            (
               entryBid -
               ask
            )
            /
            stopDistance;

         return;
      }


      double currentR =
         (
            entryBid -
            ask
         )
         /
         stopDistance;


      if(currentR > state.max_favorable_r)
         state.max_favorable_r = currentR;


      // CONTROL has no retention activation.
      if(state.policy_type == "CONTROL")
         return;


      // First activation.
      if(!state.activated)
      {
         if(currentR < state.trigger_r)
            return;

         state.activated = true;
         state.activation_time_msc =
            tick.time_msc;


         if(state.policy_type == "BREAK_EVEN")
         {
            TightenSellStop(
               state,
               entryBid,
               stopDistance,
               0.0
            );

            return;
         }


         if(state.policy_type == "LOCK")
         {
            TightenSellStop(
               state,
               entryBid,
               stopDistance,
               state.lock_r
            );

            return;
         }


         if(state.policy_type == "TRAIL")
         {
            double desiredLockedR =
               state.max_favorable_r -
               state.trail_gap_r;

            TightenSellStop(
               state,
               entryBid,
               stopDistance,
               desiredLockedR
            );

            return;
         }

         return;
      }


      // After activation, only trailing arm moves again.
      if(state.policy_type == "TRAIL")
      {
         double desiredLockedR =
            state.max_favorable_r -
            state.trail_gap_r;

         TightenSellStop(
            state,
            entryBid,
            stopDistance,
            desiredLockedR
         );
      }
   }


   // ==================================================
   // Write one missing row per policy
   // ==================================================

   void WriteMissingPolicy(
      const ScalpingProfitRetentionEvent &event,
      const string policyId,
      const string policyType,
      const double triggerR,
      const double lockR,
      const double trailGapR,
      const string status
   )
   {
      string joinKey =
         StringFormat(
            "%I64u_SELL",
            event.signal_time_msc
         );

      FileWrite(
         csvHandle,

         "P2F4_CANDIDATE_S1",
         joinKey,

         researchSymbol,
         EnumToString(entryTimeframe),

         TimeToString(
            event.signal_time,
            TIME_DATE | TIME_SECONDS
         ),

         event.signal_time_msc,

         TimeToString(
            event.signal_bar_time,
            TIME_DATE | TIME_SECONDS
         ),

         "SELL",

         10,
         status,

         "1.250000",

         DoubleToString(
            event.atr_value,
            _Digits
         ),

         DoubleToString(
            event.atr_points,
            2
         ),

         DoubleToString(
            event.entry_bid,
            _Digits
         ),

         DoubleToString(
            event.entry_ask,
            _Digits
         ),

         DoubleToString(
            event.entry_mid,
            _Digits
         ),

         DoubleToString(
            event.spread_points,
            1
         ),

         policyId,
         policyType,

         DoubleToString(triggerR, 6),
         DoubleToString(lockR, 6),
         DoubleToString(trailGapR, 6),

         "", "", "", "", "",

         "", "", "", "",

         "", "", "", "",

         "", "", "",

         "", "", "", ""
      );

      rowCount++;
   }


   // ==================================================
   // Write one completed policy row
   // ==================================================

   void WritePolicyRow(
      const ScalpingProfitRetentionEvent &event,
      const ProfitRetentionPolicyState &state,
      const double stopDistance,
      const double hardStopPrice,
      const MqlTick &targetTick,
      const long targetDelayMilliseconds,
      const int ticksScanned
   )
   {
      string joinKey =
         StringFormat(
            "%I64u_SELL",
            event.signal_time_msc
         );


      string activationTimeText = "";
      string activationTimeMscText = "";
      string activationDelayText = "";


      if(state.activated)
      {
         activationTimeText =
            TimeToString(
               (datetime)(
                  state.activation_time_msc /
                  1000ULL
               ),
               TIME_DATE | TIME_SECONDS
            );

         activationTimeMscText =
            (string)state.activation_time_msc;

         activationDelayText =
            DoubleToString(
               (
                  (double)(
                     state.activation_time_msc -
                     event.signal_time_msc
                  )
               ) / 1000.0,
               3
            );
      }


      ulong finalExitTimeMsc =
         state.exited
         ? state.exit_time_msc
         : targetTick.time_msc;


      double finalExitAsk =
         state.exited
         ? state.exit_ask
         : targetTick.ask;


      string finalExitMode =
         state.exited
         ? state.exit_mode
         : "TIME_EXIT";


      double finalExitR =
         state.exited
         ? state.exit_r
         : (
              (
                 event.entry_bid -
                 targetTick.ask
              )
              /
              stopDistance
           );


      double finalExitBps =
         0.0;


      if(event.entry_bid > 0.0)
      {
         finalExitBps =
            (
               finalExitR *
               stopDistance /
               event.entry_bid
            )
            *
            10000.0;
      }


      double holdSeconds =
         (
            (double)(
               finalExitTimeMsc -
               event.signal_time_msc
            )
         )
         /
         1000.0;


      FileWrite(
         csvHandle,

         "P2F4_CANDIDATE_S1",
         joinKey,

         researchSymbol,
         EnumToString(entryTimeframe),

         TimeToString(
            event.signal_time,
            TIME_DATE | TIME_SECONDS
         ),

         event.signal_time_msc,

         TimeToString(
            event.signal_bar_time,
            TIME_DATE | TIME_SECONDS
         ),

         "SELL",

         10,
         "OK",

         "1.250000",

         DoubleToString(
            event.atr_value,
            _Digits
         ),

         DoubleToString(
            event.atr_points,
            2
         ),

         DoubleToString(
            event.entry_bid,
            _Digits
         ),

         DoubleToString(
            event.entry_ask,
            _Digits
         ),

         DoubleToString(
            event.entry_mid,
            _Digits
         ),

         DoubleToString(
            event.spread_points,
            1
         ),

         state.policy_id,
         state.policy_type,

         DoubleToString(
            state.trigger_r,
            6
         ),

         DoubleToString(
            state.lock_r,
            6
         ),

         DoubleToString(
            state.trail_gap_r,
            6
         ),

         state.activated
            ? "YES"
            : "NO",

         activationTimeText,
         activationTimeMscText,
         activationDelayText,

         DoubleToString(
            state.max_favorable_r,
            6
         ),

         DoubleToString(
            stopDistance,
            _Digits
         ),

         DoubleToString(
            hardStopPrice,
            _Digits
         ),

         DoubleToString(
            state.stop_price,
            _Digits
         ),

         DoubleToString(
            state.locked_r,
            6
         ),

         finalExitMode,

         TimeToString(
            (datetime)(
               finalExitTimeMsc /
               1000ULL
            ),
            TIME_DATE | TIME_SECONDS
         ),

         finalExitTimeMsc,

         DoubleToString(
            finalExitAsk,
            _Digits
         ),

         DoubleToString(
            holdSeconds,
            3
         ),

         DoubleToString(
            finalExitR,
            6
         ),

         DoubleToString(
            finalExitBps,
            4
         ),

         ticksScanned,

         TimeToString(
            targetTick.time,
            TIME_DATE | TIME_SECONDS
         ),

         targetTick.time_msc,

         targetDelayMilliseconds,

         DoubleToString(
            targetTick.ask,
            _Digits
         )
      );

      rowCount++;
   }


   // ==================================================
   // Analyze exact 10-minute real-tick path
   // ==================================================

   bool AnalyzeAndWrite(
      const ScalpingProfitRetentionEvent &event
   )
   {
      const ulong HORIZON_MSC =
         10ULL *
         60ULL *
         1000ULL;


      const double STOP_ATR_MULTIPLIER =
         1.25;


      ulong targetTimeMsc =
         event.signal_time_msc +
         HORIZON_MSC;


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
         // Infrastructure error. Retry next tick.
         return false;
      }


      if(targetStatus != "OK")
      {
         WriteMissingPolicy(
            event,
            "CONTROL",
            "CONTROL",
            0.0,
            0.0,
            0.0,
            targetStatus
         );

         WriteMissingPolicy(
            event,
            "BE_050",
            "BREAK_EVEN",
            0.50,
            0.0,
            0.0,
            targetStatus
         );

         WriteMissingPolicy(
            event,
            "LOCK_075_025",
            "LOCK",
            0.75,
            0.25,
            0.0,
            targetStatus
         );

         WriteMissingPolicy(
            event,
            "TRAIL_100_050",
            "TRAIL",
            1.00,
            0.0,
            0.50,
            targetStatus
         );

         FileFlush(csvHandle);

         return true;
      }


      MqlTick ticks[];

      ResetLastError();

      int copied =
         CopyTicksRange(
            researchSymbol,
            ticks,
            COPY_TICKS_ALL,
            event.signal_time_msc,
            targetTimeMsc
         );


      if(copied < 0)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F7_PATH_COPY_FAILED error=%d",
               GetLastError()
            )
         );

         return false;
      }


      if(copied == 0)
      {
         WriteMissingPolicy(
            event,
            "CONTROL",
            "CONTROL",
            0.0,
            0.0,
            0.0,
            "NO_PATH_TICKS"
         );

         WriteMissingPolicy(
            event,
            "BE_050",
            "BREAK_EVEN",
            0.50,
            0.0,
            0.0,
            "NO_PATH_TICKS"
         );

         WriteMissingPolicy(
            event,
            "LOCK_075_025",
            "LOCK",
            0.75,
            0.25,
            0.0,
            "NO_PATH_TICKS"
         );

         WriteMissingPolicy(
            event,
            "TRAIL_100_050",
            "TRAIL",
            1.00,
            0.0,
            0.50,
            "NO_PATH_TICKS"
         );

         FileFlush(csvHandle);

         return true;
      }


      double stopDistance =
         event.atr_value *
         STOP_ATR_MULTIPLIER;


      if(stopDistance <= 0.0)
         return false;


      double hardStopPrice =
         event.entry_bid +
         stopDistance;


      ProfitRetentionPolicyState states[4];


      InitPolicy(
         states[0],
         "CONTROL",
         "CONTROL",
         0.0,
         0.0,
         0.0,
         hardStopPrice
      );


      InitPolicy(
         states[1],
         "BE_050",
         "BREAK_EVEN",
         0.50,
         0.0,
         0.0,
         hardStopPrice
      );


      InitPolicy(
         states[2],
         "LOCK_075_025",
         "LOCK",
         0.75,
         0.25,
         0.0,
         hardStopPrice
      );


      InitPolicy(
         states[3],
         "TRAIL_100_050",
         "TRAIL",
         1.00,
         0.0,
         0.50,
         hardStopPrice
      );


      int validTicks = 0;


      for(int i = 0; i < copied; i++)
      {
         if(ticks[i].ask <= 0.0)
            continue;

         validTicks++;


         for(int p = 0; p < 4; p++)
         {
            ProcessPolicyTick(
               states[p],
               ticks[i],
               event.entry_bid,
               stopDistance
            );
         }
      }


      if(validTicks == 0)
         return false;


      for(int p = 0; p < 4; p++)
      {
         WritePolicyRow(
            event,
            states[p],
            stopDistance,
            hardStopPrice,
            targetTick,
            targetDelayMilliseconds,
            validTicks
         );
      }


      FileFlush(csvHandle);


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F7_RETENTION_WRITTEN join=%I64u_SELL ticks=%d control_r=%.4f be_r=%.4f lock_r=%.4f trail_r=%.4f",
            event.signal_time_msc,
            validTicks,
            states[0].exited
               ? states[0].exit_r
               : (
                    (
                       event.entry_bid -
                       targetTick.ask
                    ) / stopDistance
                 ),
            states[1].exited
               ? states[1].exit_r
               : (
                    (
                       event.entry_bid -
                       targetTick.ask
                    ) / stopDistance
                 ),
            states[2].exited
               ? states[2].exit_r
               : (
                    (
                       event.entry_bid -
                       targetTick.ask
                    ) / stopDistance
                 ),
            states[3].exited
               ? states[3].exit_r
               : (
                    (
                       event.entry_bid -
                       targetTick.ask
                    ) / stopDistance
                 )
         )
      );


      return true;
   }


   void RemoveEvent(const int index)
   {
      int total = ArraySize(events);

      if(index < 0 || index >= total)
         return;

      for(int i = index; i < total - 1; i++)
         events[i] = events[i + 1];

      ArrayResize(
         events,
         total - 1
      );
   }


public:

   CScalpingProfitRetentionResearch()
   {
      csvHandle = INVALID_HANDLE;
      csvFileName = "";

      researchSymbol = "";
      entryTimeframe = PERIOD_CURRENT;

      atrHandle = INVALID_HANDLE;

      ready = false;

      recordedCount = 0;
      completedEventCount = 0;
      rowCount = 0;

      ArrayResize(
         events,
         0
      );
   }


   bool Initialize(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe
   )
   {
      Shutdown();


      researchSymbol = symbol;
      entryTimeframe = timeframe;


      // =================================================
      // EXPERIMENT LOCK
      // =================================================

      if(entryTimeframe != PERIOD_M5)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F7_CONFIG_INVALID reason=ENTRY_TIMEFRAME_NOT_M5"
         );

         return false;
      }


      if(
         InpFastMAPeriod != 9 ||
         InpSlowMAPeriod != 21
      )
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F7_CONFIG_INVALID reason=ENTRY_EMA_NOT_9_21"
         );

         return false;
      }


      if(
         InpScalpingContextTimeframe != PERIOD_M15 ||
         InpScalpingContextFastMAPeriod != 20 ||
         InpScalpingContextSlowMAPeriod != 50
      )
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F7_CONFIG_INVALID reason=CONTEXT_NOT_M15_EMA20_50"
         );

         return false;
      }


      if(InpScalpingATRPeriod != 14)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F7_CONFIG_INVALID reason=ATR_NOT_14 actual=%d",
               InpScalpingATRPeriod
            )
         );

         return false;
      }


      ResetLastError();

      atrHandle =
         iATR(
            researchSymbol,
            PERIOD_M5,
            14
         );


      if(atrHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F7_ATR_CREATE_FAILED error=%d",
               GetLastError()
            )
         );

         Shutdown();

         return false;
      }


      long sessionStamp =
         (long)TimeLocal();


      csvFileName =
         StringFormat(
            "RamusenEA_profit_retention_%s_%s_%I64d.csv",
            researchSymbol,
            EnumToString(entryTimeframe),
            sessionStamp
         );


      ResetLastError();

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
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F7_CSV_OPEN_FAILED file=%s error=%d",
               csvFileName,
               GetLastError()
            )
         );

         Shutdown();

         return false;
      }


      FileWrite(
         csvHandle,

         "candidate_id",
         "research_join_key",

         "symbol",
         "entry_timeframe",

         "signal_time",
         "signal_time_msc",
         "signal_bar_time",

         "side",

         "horizon_minutes",
         "status",

         "stop_atr_multiplier",

         "m5_atr",
         "m5_atr_points",

         "entry_bid",
         "entry_ask",
         "entry_mid",
         "spread_points",

         "policy_id",
         "policy_type",

         "trigger_r",
         "initial_lock_r",
         "trail_gap_r",

         "activated",
         "activation_time",
         "activation_time_msc",
         "time_to_activation_seconds",

         "max_favorable_r",

         "stop_distance",
         "hard_stop_price",
         "final_stop_price",
         "final_locked_r",

         "exit_mode",
         "exit_time",
         "exit_time_msc",
         "exit_ask",
         "holding_seconds",

         "realized_r",
         "realized_bps",

         "ticks_scanned",

         "target_time",
         "target_time_msc",
         "target_delay_milliseconds",
         "target_ask"
      );


      FileFlush(csvHandle);


      ArrayResize(
         events,
         0
      );


      recordedCount = 0;
      completedEventCount = 0;
      rowCount = 0;

      ready = true;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F7_RETENTION_READY candidate=P2F4_CANDIDATE_S1 stop=1.25ATR time_exit=10m policies=CONTROL,BE_050,LOCK_075_025,TRAIL_100_050 file=%s",
            csvFileName
         )
      );


      return true;
   }


   bool RecordEligible(
      const datetime signalTime,
      const datetime signalBarTime,
      const ENUM_RAMUSEN_SIGNAL signal,
      const MarketSnapshot &market
   )
   {
      if(!ready)
         return false;


      if(signal != RAMUSEN_SIGNAL_SELL)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F7_RECORD_REJECTED reason=NOT_SELL"
         );

         return false;
      }


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


      for(int i = 0; i < ArraySize(events); i++)
      {
         if(
            events[i].signal_time_msc ==
            signalTimeMsc
         )
         {
            Print(
               "[RAMUSEN][WARN] ",
               StringFormat(
                  "P2F7_DUPLICATE_EVENT signal_time_msc=%I64u",
                  signalTimeMsc
               )
            );

            return true;
         }
      }


      double point =
         SymbolInfoDouble(
            researchSymbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
         return false;


      double atrValue = 0.0;


      if(!ReadATR(atrValue))
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F7_ATR_NOT_READY"
         );

         return false;
      }


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

      events[index].atr_points =
         atrValue /
         point;


      recordedCount++;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F7_RETENTION_RECORDED join=%I64u_SELL entry_bid=%s atr=%.5f",
            signalTimeMsc,
            DoubleToString(
               market.bid,
               _Digits
            ),
            atrValue
         )
      );


      return true;
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


      for(
         int i = ArraySize(events) - 1;
         i >= 0;
         i--
      )
      {
         ulong maturity =
            events[i].signal_time_msc +
            MATURITY_MSC;


         if(nowMsc < maturity)
            continue;


         if(AnalyzeAndWrite(events[i]))
         {
            completedEventCount++;

            RemoveEvent(i);
         }
      }
   }


   void Shutdown()
   {
      if(ready)
      {
         Print(
            "[RAMUSEN][INFO] ",
            StringFormat(
               "P2F7_RETENTION_SUMMARY recorded=%I64u completed=%I64u rows=%I64u pending=%d",
               recordedCount,
               completedEventCount,
               rowCount,
               ArraySize(events)
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


      ArrayResize(
         events,
         0
      );

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
