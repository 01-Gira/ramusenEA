#ifndef RAMUSEN_SCALPING_EXCURSION_RESEARCH_MQH
#define RAMUSEN_SCALPING_EXCURSION_RESEARCH_MQH

#include "Config.mqh"
#include "Types.mqh"


// =====================================================
// P2F.5A — 10-MINUTE EXECUTABLE EXCURSION
//
// Candidate:
//   P2F4_CANDIDATE_S1
//
// Direction:
//   SELL only
//
// Entry:
//   executable SELL entry = BID
//
// Exit path:
//   executable SELL close = ASK
//
// Horizon:
//   10 minutes
//
// Research only.
// NEVER sends orders.
// =====================================================

struct ScalpingExcursionEvent
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


class CScalpingExcursionResearch
{
private:

   int csvHandle;

   string csvFileName;

   string researchSymbol;

   ENUM_TIMEFRAMES entryTimeframe;

   int atrHandle;

   bool ready;

   ScalpingExcursionEvent events[];

   ulong recordedCount;
   ulong completedCount;


   // ==================================================
   // READ ATR
   // ==================================================

   bool ReadATR(
      double &value
   )
   {
      if(atrHandle == INVALID_HANDLE)
         return false;


      double buffer[1];


      ResetLastError();


      int copied =
         CopyBuffer(
            atrHandle,
            0,
            1,       // completed M5 bar only
            1,
            buffer
         );


      if(copied != 1)
         return false;


      value =
         buffer[0];


      return value > 0.0;
   }


   // ==================================================
   // FIND FIRST ACTUAL TICK AT / AFTER +10 MINUTES
   //
   // Same 30-second tolerance used by SignalResearch.
   // ==================================================

   bool FindTargetTick(
      const ulong targetTimeMsc,
      MqlTick &resultTick,
      long &delayMilliseconds,
      string &status
   )
   {
      const ulong MAX_DELAY_MSC =
         30000;


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
         status =
            "NO_TICK_NEAR_TARGET";

         return true;
      }


      bool found =
         false;


      ulong earliest =
         0;


      for(int i = 0; i < copied; i++)
      {
         if((ulong)ticks[i].time_msc < targetTimeMsc)
            continue;


         if(
            !found
            ||
            (ulong)ticks[i].time_msc < earliest
         )
         {
            found =
               true;

            earliest =
               (ulong)ticks[i].time_msc;

            resultTick =
               ticks[i];
         }
      }


      if(!found)
      {
         status =
            "NO_TICK_NEAR_TARGET";

         return true;
      }


      delayMilliseconds =
         (long)(
            resultTick.time_msc
            -
            targetTimeMsc
         );


      status =
         "OK";


      return true;
   }


   // ==================================================
   // WRITE INVALID / UNOBSERVED ROW
   // ==================================================

   void WriteMissingObservation(
      const ScalpingExcursionEvent &event,
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

         EnumToString(
            entryTimeframe
         ),

         TimeToString(
            event.signal_time,
            TIME_DATE |
            TIME_SECONDS
         ),

         event.signal_time_msc,

         TimeToString(
            event.signal_bar_time,
            TIME_DATE |
            TIME_SECONDS
         ),

         "SELL",

         10,

         status,

         "",

         "",

         0,

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

         DoubleToString(
            event.atr_value,
            _Digits
         ),

         DoubleToString(
            event.atr_points,
            2
         ),

         "", "",

         "", "",

         "", "",

         "", "",

         "", "",

         "", "",

         "", "",

         "", ""
      );


      FileFlush(
         csvHandle
      );
   }


   // ==================================================
   // ANALYZE ONE COMPLETE 10-MINUTE PATH
   // ==================================================

   bool AnalyzeAndWrite(
      const ScalpingExcursionEvent &event
   )
   {
      const ulong HORIZON_MSC =
         10ULL
         *
         60ULL
         *
         1000ULL;


      ulong targetTimeMsc =
         event.signal_time_msc
         +
         HORIZON_MSC;


      // =================================================
      // TARGET TICK
      // =================================================

      MqlTick targetTick;


      long targetDelayMilliseconds =
         0;


      string targetStatus =
         "";


      if(
         !FindTargetTick(
            targetTimeMsc,
            targetTick,
            targetDelayMilliseconds,
            targetStatus
         )
      )
      {
         // Actual CopyTicks error.
         // Keep event so it can retry.
         return false;
      }


      if(targetStatus != "OK")
      {
         WriteMissingObservation(
            event,
            targetStatus
         );


         return true;
      }


      // =================================================
      // PATH:
      //
      // Signal tick → first observed tick at +10m.
      //
      // Usually delay is milliseconds.
      // Maximum allowed delay = 30 seconds.
      // =================================================

      MqlTick ticks[];


      ResetLastError();


      int copied =
         CopyTicksRange(
            researchSymbol,
            ticks,
            COPY_TICKS_ALL,
            event.signal_time_msc,
            targetTick.time_msc
         );


      if(copied < 0)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F5_PATH_COPY_FAILED error=%d",
               GetLastError()
            )
         );


         return false;
      }


      if(copied == 0)
      {
         WriteMissingObservation(
            event,
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
         WriteMissingObservation(
            event,
            "INVALID_POINT"
         );


         return true;
      }


      // =================================================
      // SELL EXECUTABLE PATH
      //
      // Enter:
      //   BID
      //
      // Exit:
      //   ASK
      //
      // favorable:
      //   entry_bid - future_ask
      //
      // adverse:
      //   future_ask - entry_bid
      // =================================================

      double maxFavorableDistance =
         0.0;


      double maxAdverseDistance =
         0.0;


      double bestExitAsk =
         event.entry_ask;


      double worstExitAsk =
         event.entry_ask;


      ulong mfeTimeMsc =
         event.signal_time_msc;


      ulong maeTimeMsc =
         event.signal_time_msc;


      int validTicks =
         0;


      for(int i = 0; i < copied; i++)
      {
         double ask =
            ticks[i].ask;


         if(ask <= 0.0)
            continue;


         validTicks++;


         double favorableDistance =
            event.entry_bid
            -
            ask;


         if(
            favorableDistance
            >
            maxFavorableDistance
         )
         {
            maxFavorableDistance =
               favorableDistance;


            bestExitAsk =
               ask;


            mfeTimeMsc =
               ticks[i].time_msc;
         }


         double adverseDistance =
            ask
            -
            event.entry_bid;


         if(
            adverseDistance
            >
            maxAdverseDistance
         )
         {
            maxAdverseDistance =
               adverseDistance;


            worstExitAsk =
               ask;


            maeTimeMsc =
               ticks[i].time_msc;
         }
      }


      if(validTicks == 0)
      {
         WriteMissingObservation(
            event,
            "NO_VALID_ASK_TICKS"
         );


         return true;
      }


      // =================================================
      // MFE / MAE
      // =================================================

      double mfePoints =
         maxFavorableDistance
         /
         point;


      double maePoints =
         maxAdverseDistance
         /
         point;


      double mfeBps =
         0.0;


      double maeBps =
         0.0;


      if(event.entry_bid > 0.0)
      {
         mfeBps =
            (
               maxFavorableDistance
               /
               event.entry_bid
            )
            *
            10000.0;


         maeBps =
            (
               maxAdverseDistance
               /
               event.entry_bid
            )
            *
            10000.0;
      }


      // =================================================
      // ATR NORMALIZATION
      // =================================================

      double mfeATR =
         0.0;


      double maeATR =
         0.0;


      if(event.atr_value > 0.0)
      {
         mfeATR =
            maxFavorableDistance
            /
            event.atr_value;


         maeATR =
            maxAdverseDistance
            /
            event.atr_value;
      }


      // =================================================
      // TIME TO EXTREMES
      // =================================================

      ulong timeToMfeMsc =
         mfeTimeMsc
         -
         event.signal_time_msc;


      ulong timeToMaeMsc =
         maeTimeMsc
         -
         event.signal_time_msc;


      double timeToMfeSeconds =
         (
            double
         )
         timeToMfeMsc
         /
         1000.0;


      double timeToMaeSeconds =
         (
            double
         )
         timeToMaeMsc
         /
         1000.0;


      // =================================================
      // +10 MINUTE EXECUTABLE RETURN
      // =================================================

      double targetDistance =
         event.entry_bid
         -
         targetTick.ask;


      double return10mPoints =
         targetDistance
         /
         point;


      double return10mBps =
         0.0;


      if(event.entry_bid > 0.0)
      {
         return10mBps =
            (
               targetDistance
               /
               event.entry_bid
            )
            *
            10000.0;
      }


      // =================================================
      // JOIN KEY
      // =================================================

      string joinKey =
         StringFormat(
            "%I64u_SELL",
            event.signal_time_msc
         );


      // =================================================
      // WRITE
      // =================================================

      FileWrite(
         csvHandle,

         "P2F4_CANDIDATE_S1",

         joinKey,

         researchSymbol,

         EnumToString(
            entryTimeframe
         ),

         TimeToString(
            event.signal_time,
            TIME_DATE |
            TIME_SECONDS
         ),

         event.signal_time_msc,

         TimeToString(
            event.signal_bar_time,
            TIME_DATE |
            TIME_SECONDS
         ),

         "SELL",

         10,

         "OK",

         TimeToString(
            targetTick.time,
            TIME_DATE |
            TIME_SECONDS
         ),

         targetTick.time_msc,

         targetDelayMilliseconds,

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

         DoubleToString(
            event.atr_value,
            _Digits
         ),

         DoubleToString(
            event.atr_points,
            2
         ),

         validTicks,

         DoubleToString(
            bestExitAsk,
            _Digits
         ),

         DoubleToString(
            worstExitAsk,
            _Digits
         ),

         DoubleToString(
            mfePoints,
            2
         ),

         DoubleToString(
            maePoints,
            2
         ),

         DoubleToString(
            mfeBps,
            4
         ),

         DoubleToString(
            maeBps,
            4
         ),

         DoubleToString(
            mfeATR,
            6
         ),

         DoubleToString(
            maeATR,
            6
         ),

         timeToMfeMsc,

         timeToMaeMsc,

         DoubleToString(
            timeToMfeSeconds,
            3
         ),

         DoubleToString(
            timeToMaeSeconds,
            3
         ),

         DoubleToString(
            targetTick.ask,
            _Digits
         ),

         DoubleToString(
            return10mPoints,
            2
         ),

         DoubleToString(
            return10mBps,
            4
         )
      );


      FileFlush(
         csvHandle
      );


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F5_EXCURSION_WRITTEN join=%s ticks=%d mfe_bps=%.4f mae_bps=%.4f mfe_atr=%.4f mae_atr=%.4f t_mfe=%.1fs t_mae=%.1fs return10m=%.4f",
            joinKey,
            validTicks,
            mfeBps,
            maeBps,
            mfeATR,
            maeATR,
            timeToMfeSeconds,
            timeToMaeSeconds,
            return10mBps
         )
      );


      return true;
   }


   // ==================================================
   // REMOVE EVENT
   // ==================================================

   void RemoveEvent(
      const int index
   )
   {
      int total =
         ArraySize(
            events
         );


      if(
         index < 0
         ||
         index >= total
      )
      {
         return;
      }


      for(
         int i = index;
         i < total - 1;
         i++
      )
      {
         events[i] =
            events[i + 1];
      }


      ArrayResize(
         events,
         total - 1
      );
   }


public:

   // ==================================================
   // CONSTRUCTOR
   // ==================================================

   CScalpingExcursionResearch()
   {
      csvHandle =
         INVALID_HANDLE;


      csvFileName =
         "";


      researchSymbol =
         "";


      entryTimeframe =
         PERIOD_CURRENT;


      atrHandle =
         INVALID_HANDLE;


      ready =
         false;


      recordedCount =
         0;


      completedCount =
         0;


      ArrayResize(
         events,
         0
      );
   }


   // ==================================================
   // INITIALIZE
   // ==================================================

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
      // P2F.5A EXPERIMENT LOCK
      // =================================================

      if(entryTimeframe != PERIOD_M5)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F5_CONFIG_INVALID reason=ENTRY_TIMEFRAME_NOT_M5"
         );


         return false;
      }


      if(
         InpFastMAPeriod != 9
         ||
         InpSlowMAPeriod != 21
      )
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F5_CONFIG_INVALID reason=ENTRY_EMA_NOT_9_21"
         );


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
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F5_CONFIG_INVALID reason=CONTEXT_NOT_M15_EMA20_50"
         );


         return false;
      }


      // =================================================
      // ATR M5
      // =================================================

      atrHandle =
         iATR(
            researchSymbol,
            PERIOD_M5,
            InpScalpingATRPeriod
         );


      if(atrHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F5_ATR_CREATE_FAILED error=%d",
               GetLastError()
            )
         );


         Shutdown();

         return false;
      }


      // =================================================
      // CSV
      // =================================================

      long sessionStamp =
         (long)TimeLocal();


      csvFileName =
         StringFormat(
            "RamusenEA_scalping_excursion_%s_%s_%I64d.csv",
            researchSymbol,
            EnumToString(
               entryTimeframe
            ),
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
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F5_CSV_OPEN_FAILED file=%s error=%d",
               csvFileName,
               GetLastError()
            )
         );


         Shutdown();

         return false;
      }


      // =================================================
      // HEADER
      // =================================================

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

         "observed_time",
         "observed_time_msc",
         "observation_delay_milliseconds",

         "entry_bid",
         "entry_ask",
         "entry_mid",

         "spread_points",

         "m5_atr",
         "m5_atr_points",

         "ticks_scanned",

         "best_exit_ask",
         "worst_exit_ask",

         "mfe_points",
         "mae_points",

         "mfe_bps",
         "mae_bps",

         "mfe_atr",
         "mae_atr",

         "time_to_mfe_milliseconds",
         "time_to_mae_milliseconds",

         "time_to_mfe_seconds",
         "time_to_mae_seconds",

         "future_ask_10m",

         "return_10m_points",
         "return_10m_bps"
      );


      FileFlush(
         csvHandle
      );


      ArrayResize(
         events,
         0
      );


      recordedCount =
         0;


      completedCount =
         0;


      ready =
         true;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F5_EXCURSION_READY candidate=P2F4_CANDIDATE_S1 symbol=%s tf=M5 direction=SELL horizon=10m atr=%d file=%s",
            researchSymbol,
            InpScalpingATRPeriod,
            csvFileName
         )
      );


      return true;
   }


   // ==================================================
   // RECORD S1 ELIGIBLE SIGNAL
   // ==================================================

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
            "P2F5_RECORD_REJECTED reason=NOT_SELL"
         );


         return false;
      }


      ulong signalTimeMsc =
         (ulong)signalTime
         *
         1000;


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


      // =================================================
      // DUPLICATE GUARD
      // =================================================

      for(
         int i = 0;
         i < ArraySize(events);
         i++
      )
      {
         if(
            events[i].signal_time_msc
            ==
            signalTimeMsc
         )
         {
            Print(
               "[RAMUSEN][WARN] ",
               StringFormat(
                  "P2F5_DUPLICATE_EVENT signal_time_msc=%I64u",
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


      double atrValue =
         0.0;


      if(!ReadATR(atrValue))
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F5_ATR_NOT_READY"
         );


         return false;
      }


      int index =
         ArraySize(
            events
         );


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
            market.bid
            +
            market.ask
         )
         /
         2.0;


      events[index].spread_points =
         market.spread_points;


      events[index].atr_value =
         atrValue;


      events[index].atr_points =
         atrValue
         /
         point;


      recordedCount++;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F5_EXCURSION_RECORDED join=%I64u_SELL entry_bid=%s atr=%.5f atr_points=%.1f",
            signalTimeMsc,
            DoubleToString(
               market.bid,
               _Digits
            ),
            atrValue,
            events[index].atr_points
         )
      );


      return true;
   }


   // ==================================================
   // PROCESS MATURE EVENTS
   // ==================================================

   void Process(
      const datetime now
   )
   {
      if(!ready)
         return;


      ulong nowMsc =
         (ulong)now
         *
         1000;


      const ulong MATURITY_MSC =
         (
            10ULL
            *
            60ULL
            *
            1000ULL
         )
         +
         30000ULL;


      for(
         int i =
            ArraySize(events) - 1;

         i >= 0;

         i--
      )
      {
         ulong maturity =
            events[i].signal_time_msc
            +
            MATURITY_MSC;


         if(nowMsc < maturity)
            continue;


         if(
            AnalyzeAndWrite(
               events[i]
            )
         )
         {
            completedCount++;


            RemoveEvent(
               i
            );
         }
      }
   }


   // ==================================================
   // SHUTDOWN
   // ==================================================

   void Shutdown()
   {
      if(ready)
      {
         Print(
            "[RAMUSEN][INFO] ",
            StringFormat(
               "P2F5_EXCURSION_SUMMARY recorded=%I64u completed=%I64u pending=%d",
               recordedCount,
               completedCount,
               ArraySize(events)
            )
         );
      }


      if(atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(
            atrHandle
         );


         atrHandle =
            INVALID_HANDLE;
      }


      if(csvHandle != INVALID_HANDLE)
      {
         FileFlush(
            csvHandle
         );


         FileClose(
            csvHandle
         );


         csvHandle =
            INVALID_HANDLE;
      }


      ArrayResize(
         events,
         0
      );


      ready =
         false;
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