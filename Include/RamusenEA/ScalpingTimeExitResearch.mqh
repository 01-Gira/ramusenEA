#ifndef RAMUSEN_SCALPING_TIME_EXIT_RESEARCH_MQH
#define RAMUSEN_SCALPING_TIME_EXIT_RESEARCH_MQH

#include "Config.mqh"
#include "Types.mqh"

// =====================================================
// P2F.6 — TIME EXIT RESEARCH
//
// Candidate:
//   P2F4_CANDIDATE_S1
//
// Direction:
//   SELL only
//
// Fixed risk envelope:
//   Hard SL = 1.25 ATR(M5,14) from entry
//
// Time-exit challengers:
//   5m / 10m / 15m
//
// Research only.
// NEVER sends orders.
// =====================================================

struct ScalpingTimeExitEvent
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

   bool h5_done;
   bool h10_done;
   bool h15_done;
};


class CScalpingTimeExitResearch
{
private:

   int csvHandle;
   string csvFileName;

   string researchSymbol;
   ENUM_TIMEFRAMES entryTimeframe;

   int atrHandle;

   bool ready;

   ScalpingTimeExitEvent events[];

   ulong recordedCount;
   ulong rowCount;


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
            1, // completed M5 bar only
            1,
            buffer
         );

      if(copied != 1)
         return false;

      value = buffer[0];

      return value > 0.0;
   }


   bool FindTargetTick(
      const ulong targetTimeMsc,
      MqlTick &resultTick,
      long &delayMilliseconds,
      string &status
   )
   {
      const ulong MAX_DELAY_MSC = 30000;

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


   void WriteMissing(
      const ScalpingTimeExitEvent &event,
      const int horizonMinutes,
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

         horizonMinutes,
         status,

         DoubleToString(event.entry_bid, _Digits),
         DoubleToString(event.entry_ask, _Digits),
         DoubleToString(event.entry_mid, _Digits),
         DoubleToString(event.spread_points, 1),

         DoubleToString(event.atr_value, _Digits),
         DoubleToString(event.atr_points, 2),

         "1.250000",

         "", "", "",
         "", "", "", "",
         "", "", "", "",
         "", "", "",
         "", "", "",
         "", "", "", "",
         "", "", "", ""
      );

      FileFlush(csvHandle);
      rowCount++;
   }


   bool AnalyzeAndWrite(
      const ScalpingTimeExitEvent &event,
      const int horizonMinutes
   )
   {
      ulong horizonMsc =
         (ulong)horizonMinutes *
         60ULL *
         1000ULL;

      ulong targetTimeMsc =
         event.signal_time_msc +
         horizonMsc;


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
         // CopyTicks infrastructure error: retry later.
         return false;
      }


      if(targetStatus != "OK")
      {
         WriteMissing(
            event,
            horizonMinutes,
            targetStatus
         );

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
               "P2F6_PATH_COPY_FAILED horizon=%dm error=%d",
               horizonMinutes,
               GetLastError()
            )
         );

         return false;
      }


      if(copied == 0)
      {
         WriteMissing(
            event,
            horizonMinutes,
            "NO_PATH_TICKS"
         );

         return true;
      }


      double point =
         SymbolInfoDouble(
            researchSymbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
      {
         WriteMissing(
            event,
            horizonMinutes,
            "INVALID_POINT"
         );

         return true;
      }


      const double STOP_ATR_MULTIPLIER =
         1.25;


      double stopDistance =
         event.atr_value *
         STOP_ATR_MULTIPLIER;


      if(stopDistance <= 0.0)
      {
         WriteMissing(
            event,
            horizonMinutes,
            "INVALID_STOP_DISTANCE"
         );

         return true;
      }


      double stopPrice =
         event.entry_bid +
         stopDistance;


      double maxFavorableDistance = 0.0;
      double maxAdverseDistance = 0.0;

      double bestExitAsk = event.entry_ask;
      double worstExitAsk = event.entry_ask;

      ulong mfeTimeMsc = event.signal_time_msc;
      ulong maeTimeMsc = event.signal_time_msc;

      bool stopHit = false;
      ulong stopHitTimeMsc = 0;
      double stopHitAsk = 0.0;

      int validTicks = 0;


      for(int i = 0; i < copied; i++)
      {
         double ask = ticks[i].ask;

         if(ask <= 0.0)
            continue;

         validTicks++;


         double favorableDistance =
            event.entry_bid -
            ask;

         if(favorableDistance > maxFavorableDistance)
         {
            maxFavorableDistance =
               favorableDistance;

            bestExitAsk =
               ask;

            mfeTimeMsc =
               ticks[i].time_msc;
         }


         double adverseDistance =
            ask -
            event.entry_bid;

         if(adverseDistance > maxAdverseDistance)
         {
            maxAdverseDistance =
               adverseDistance;

            worstExitAsk =
               ask;

            maeTimeMsc =
               ticks[i].time_msc;
         }


         // First touch of the provisional 1.25 ATR hard SL.
         if(
            !stopHit &&
            ask >= stopPrice
         )
         {
            stopHit = true;
            stopHitTimeMsc = ticks[i].time_msc;
            stopHitAsk = ask;
         }
      }


      if(validTicks == 0)
      {
         WriteMissing(
            event,
            horizonMinutes,
            "NO_VALID_ASK_TICKS"
         );

         return true;
      }


      double mfePoints =
         maxFavorableDistance /
         point;

      double maePoints =
         maxAdverseDistance /
         point;


      double mfeBps = 0.0;
      double maeBps = 0.0;


      if(event.entry_bid > 0.0)
      {
         mfeBps =
            (
               maxFavorableDistance /
               event.entry_bid
            ) * 10000.0;

         maeBps =
            (
               maxAdverseDistance /
               event.entry_bid
            ) * 10000.0;
      }


      double mfeATR =
         maxFavorableDistance /
         event.atr_value;

      double maeATR =
         maxAdverseDistance /
         event.atr_value;


      double timeToMfeSeconds =
         (
            (double)(
               mfeTimeMsc -
               event.signal_time_msc
            )
         ) / 1000.0;


      double timeToMaeSeconds =
         (
            (double)(
               maeTimeMsc -
               event.signal_time_msc
            )
         ) / 1000.0;


      double timeToStopSeconds = -1.0;

      if(stopHit)
      {
         timeToStopSeconds =
            (
               (double)(
                  stopHitTimeMsc -
                  event.signal_time_msc
               )
            ) / 1000.0;
      }


      double targetDistance =
         event.entry_bid -
         targetTick.ask;


      double timeExitReturnPoints =
         targetDistance /
         point;


      double timeExitReturnBps = 0.0;

      if(event.entry_bid > 0.0)
      {
         timeExitReturnBps =
            (
               targetDistance /
               event.entry_bid
            ) * 10000.0;
      }


      double timeExitReturnR =
         targetDistance /
         stopDistance;


      string simulatedExitMode =
         stopHit
         ? "HARD_SL"
         : "TIME_EXIT";


      // Research assumption:
      // if hard SL is touched, idealized result = -1R.
      // Slippage/cost stress belongs to P2F.8.
      double simulatedReturnR =
         stopHit
         ? -1.0
         : timeExitReturnR;


      double simulatedReturnBps =
         stopHit
         ? (
              -stopDistance /
              event.entry_bid
           ) * 10000.0
         : timeExitReturnBps;


      string joinKey =
         StringFormat(
            "%I64u_SELL",
            event.signal_time_msc
         );


      string stopHitTimeText = "";
      string stopHitTimeMscText = "";
      string stopHitAskText = "";
      string timeToStopText = "";


      if(stopHit)
      {
         stopHitTimeText =
            TimeToString(
               (datetime)(
                  stopHitTimeMsc /
                  1000ULL
               ),
               TIME_DATE | TIME_SECONDS
            );

         stopHitTimeMscText =
            (string)stopHitTimeMsc;

         stopHitAskText =
            DoubleToString(
               stopHitAsk,
               _Digits
            );

         timeToStopText =
            DoubleToString(
               timeToStopSeconds,
               3
            );
      }


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

         horizonMinutes,
         "OK",

         DoubleToString(event.entry_bid, _Digits),
         DoubleToString(event.entry_ask, _Digits),
         DoubleToString(event.entry_mid, _Digits),
         DoubleToString(event.spread_points, 1),

         DoubleToString(event.atr_value, _Digits),
         DoubleToString(event.atr_points, 2),

         DoubleToString(
            STOP_ATR_MULTIPLIER,
            6
         ),

         DoubleToString(
            stopDistance,
            _Digits
         ),

         DoubleToString(
            stopPrice,
            _Digits
         ),

         stopHit ? "YES" : "NO",

         stopHitTimeText,
         stopHitTimeMscText,
         stopHitAskText,
         timeToStopText,

         validTicks,

         DoubleToString(bestExitAsk, _Digits),
         DoubleToString(worstExitAsk, _Digits),

         DoubleToString(mfePoints, 2),
         DoubleToString(maePoints, 2),

         DoubleToString(mfeBps, 4),
         DoubleToString(maeBps, 4),

         DoubleToString(mfeATR, 6),
         DoubleToString(maeATR, 6),

         DoubleToString(timeToMfeSeconds, 3),
         DoubleToString(timeToMaeSeconds, 3),

         TimeToString(
            targetTick.time,
            TIME_DATE | TIME_SECONDS
         ),

         targetTick.time_msc,
         targetDelayMilliseconds,

         DoubleToString(
            targetTick.ask,
            _Digits
         ),

         DoubleToString(
            timeExitReturnPoints,
            2
         ),

         DoubleToString(
            timeExitReturnBps,
            4
         ),

         DoubleToString(
            timeExitReturnR,
            6
         ),

         simulatedExitMode,

         DoubleToString(
            simulatedReturnBps,
            4
         ),

         DoubleToString(
            simulatedReturnR,
            6
         )
      );


      FileFlush(csvHandle);

      rowCount++;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F6_TIME_EXIT_WRITTEN join=%s horizon=%dm stop_hit=%s exit=%s raw_r=%.4f sim_r=%.4f mfe_atr=%.4f mae_atr=%.4f",
            joinKey,
            horizonMinutes,
            stopHit ? "YES" : "NO",
            simulatedExitMode,
            timeExitReturnR,
            simulatedReturnR,
            mfeATR,
            maeATR
         )
      );


      return true;
   }


   void ProcessHorizon(
      ScalpingTimeExitEvent &event,
      const datetime now,
      const int horizonMinutes,
      bool &done
   )
   {
      if(done)
         return;


      ulong targetTimeMsc =
         event.signal_time_msc +
         (
            (ulong)horizonMinutes *
            60ULL *
            1000ULL
         );


      ulong maturityMsc =
         targetTimeMsc +
         30000ULL;


      ulong nowMsc =
         (ulong)now *
         1000ULL;


      if(nowMsc < maturityMsc)
         return;


      if(
         AnalyzeAndWrite(
            event,
            horizonMinutes
         )
      )
      {
         done = true;
      }
   }


   bool IsComplete(
      const ScalpingTimeExitEvent &event
   )
   {
      return
         event.h5_done &&
         event.h10_done &&
         event.h15_done;
   }


   void RemoveEvent(
      const int index
   )
   {
      int total =
         ArraySize(events);


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

   CScalpingTimeExitResearch()
   {
      csvHandle = INVALID_HANDLE;
      csvFileName = "";

      researchSymbol = "";
      entryTimeframe = PERIOD_CURRENT;

      atrHandle = INVALID_HANDLE;

      ready = false;

      recordedCount = 0;
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


      researchSymbol =
         symbol;

      entryTimeframe =
         timeframe;


      // =================================================
      // EXPERIMENT LOCK
      // =================================================

      if(entryTimeframe != PERIOD_M5)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F6_CONFIG_INVALID reason=ENTRY_TIMEFRAME_NOT_M5"
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
            "P2F6_CONFIG_INVALID reason=ENTRY_EMA_NOT_9_21"
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
            "P2F6_CONFIG_INVALID reason=CONTEXT_NOT_M15_EMA20_50"
         );

         return false;
      }


      if(InpScalpingATRPeriod != 14)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F6_CONFIG_INVALID reason=ATR_NOT_14 actual=%d",
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
               "P2F6_ATR_CREATE_FAILED error=%d",
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
            "RamusenEA_time_exit_%s_%s_%I64d.csv",
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
               "P2F6_CSV_OPEN_FAILED file=%s error=%d",
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

         "entry_bid",
         "entry_ask",
         "entry_mid",
         "spread_points",

         "m5_atr",
         "m5_atr_points",

         "stop_atr_multiplier",
         "stop_distance",
         "stop_price",

         "stop_hit",
         "stop_hit_time",
         "stop_hit_time_msc",
         "stop_hit_ask",
         "time_to_stop_seconds",

         "ticks_scanned",

         "best_exit_ask",
         "worst_exit_ask",

         "mfe_points",
         "mae_points",

         "mfe_bps",
         "mae_bps",

         "mfe_atr",
         "mae_atr",

         "time_to_mfe_seconds",
         "time_to_mae_seconds",

         "observed_time",
         "observed_time_msc",
         "observation_delay_milliseconds",

         "future_ask",

         "time_exit_return_points",
         "time_exit_return_bps",
         "time_exit_return_r",

         "simulated_exit_mode",
         "simulated_return_bps",
         "simulated_return_r"
      );


      FileFlush(csvHandle);


      ArrayResize(
         events,
         0
      );


      recordedCount = 0;
      rowCount = 0;

      ready = true;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F6_TIME_EXIT_READY candidate=P2F4_CANDIDATE_S1 horizons=5m,10m,15m stop=1.25ATR risk=research_only file=%s",
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
            "P2F6_RECORD_REJECTED reason=NOT_SELL"
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
                  "P2F6_DUPLICATE_EVENT signal_time_msc=%I64u",
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
            "P2F6_ATR_NOT_READY"
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

      events[index].h5_done = false;
      events[index].h10_done = false;
      events[index].h15_done = false;


      recordedCount++;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F6_TIME_EXIT_RECORDED join=%I64u_SELL entry_bid=%s atr=%.5f",
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


   void Process(
      const datetime now
   )
   {
      if(!ready)
         return;


      for(
         int i =
            ArraySize(events) - 1;
         i >= 0;
         i--
      )
      {
         ProcessHorizon(
            events[i],
            now,
            5,
            events[i].h5_done
         );


         ProcessHorizon(
            events[i],
            now,
            10,
            events[i].h10_done
         );


         ProcessHorizon(
            events[i],
            now,
            15,
            events[i].h15_done
         );


         if(IsComplete(events[i]))
            RemoveEvent(i);
      }
   }


   void Shutdown()
   {
      if(ready)
      {
         Print(
            "[RAMUSEN][INFO] ",
            StringFormat(
               "P2F6_TIME_EXIT_SUMMARY recorded=%I64u rows=%I64u pending=%d",
               recordedCount,
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
