#ifndef RAMUSEN_SCALPING_ENTRY_GATE_MQH
#define RAMUSEN_SCALPING_ENTRY_GATE_MQH

#include "Config.mqh"
#include "Types.mqh"


// =====================================================
// P2F.4 — CANDIDATE S1
//
// Trigger:
//   M5 EMA9/21 crossover
//
// Eligible:
//   SELL
//   AND
//   completed M15 EMA20 < EMA50
//
// Research horizon:
//   10 minutes
//
// IMPORTANT:
//   - Research only.
//   - Never sends orders.
//   - Never reads future prices.
// =====================================================

class CScalpingEntryGate
{
private:

   int csvHandle;
   string csvFileName;

   string gateSymbol;
   ENUM_TIMEFRAMES entryTimeframe;

   int m15FastHandle;
   int m15SlowHandle;

   bool ready;

   ulong rawCount;
   ulong eligibleCount;
   ulong rejectBuyCount;
   ulong rejectContextCount;
   ulong contextErrorCount;


   bool ReadValue(
      const int handle,
      const int shift,
      double &value
   )
   {
      if(handle == INVALID_HANDLE)
         return false;

      double buffer[1];

      ResetLastError();

      int copied =
         CopyBuffer(
            handle,
            0,
            shift,
            1,
            buffer
         );

      if(copied != 1)
         return false;

      value = buffer[0];

      return true;
   }


   string SignalToString(
      const ENUM_RAMUSEN_SIGNAL signal
   )
   {
      if(signal == RAMUSEN_SIGNAL_BUY)
         return "BUY";

      if(signal == RAMUSEN_SIGNAL_SELL)
         return "SELL";

      return "NONE";
   }


public:

   CScalpingEntryGate()
   {
      csvHandle = INVALID_HANDLE;
      csvFileName = "";

      gateSymbol = "";
      entryTimeframe = PERIOD_CURRENT;

      m15FastHandle = INVALID_HANDLE;
      m15SlowHandle = INVALID_HANDLE;

      ready = false;

      rawCount = 0;
      eligibleCount = 0;
      rejectBuyCount = 0;
      rejectContextCount = 0;
      contextErrorCount = 0;
   }


   bool Initialize(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe
   )
   {
      Shutdown();

      gateSymbol = symbol;
      entryTimeframe = timeframe;

      // =================================================
      // EXPERIMENT LOCK
      // =================================================

      if(entryTimeframe != PERIOD_M5)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F4_CONFIG_INVALID reason=ENTRY_TIMEFRAME_NOT_M5"
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
            StringFormat(
               "P2F4_CONFIG_INVALID reason=ENTRY_EMA_NOT_9_21 actual=%d/%d",
               InpFastMAPeriod,
               InpSlowMAPeriod
            )
         );

         return false;
      }


      if(
         InpScalpingContextTimeframe
         !=
         PERIOD_M15
      )
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "P2F4_CONFIG_INVALID reason=CONTEXT_TIMEFRAME_NOT_M15"
         );

         return false;
      }


      if(
         InpScalpingContextFastMAPeriod != 20
         ||
         InpScalpingContextSlowMAPeriod != 50
      )
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F4_CONFIG_INVALID reason=CONTEXT_EMA_NOT_20_50 actual=%d/%d",
               InpScalpingContextFastMAPeriod,
               InpScalpingContextSlowMAPeriod
            )
         );

         return false;
      }


      ResetLastError();

      m15FastHandle =
         iMA(
            gateSymbol,
            PERIOD_M15,
            20,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );


      if(m15FastHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F4_M15_FAST_EMA_CREATE_FAILED error=%d",
               GetLastError()
            )
         );

         Shutdown();

         return false;
      }


      ResetLastError();

      m15SlowHandle =
         iMA(
            gateSymbol,
            PERIOD_M15,
            50,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );


      if(m15SlowHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F4_M15_SLOW_EMA_CREATE_FAILED error=%d",
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
            "RamusenEA_entry_gate_%s_%s_%I64d.csv",
            gateSymbol,
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
               "P2F4_CSV_OPEN_FAILED file=%s error=%d",
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

         "gate_result",
         "gate_reason",

         "research_horizon_minutes",

         "m15_fast_ema_bar1",
         "m15_slow_ema_bar1",
         "m15_trend",

         "entry_bid",
         "entry_ask",
         "entry_mid",

         "spread_points"
      );


      FileFlush(csvHandle);


      rawCount = 0;
      eligibleCount = 0;
      rejectBuyCount = 0;
      rejectContextCount = 0;
      contextErrorCount = 0;

      ready = true;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F4_ENTRY_GATE_READY candidate=P2F4_CANDIDATE_S1 symbol=%s entry_tf=M5 entry_ema=9/21 context_tf=M15 context_ema=20/50 direction=SELL horizon=10m file=%s",
            gateSymbol,
            csvFileName
         )
      );


      return true;
   }


   bool EvaluateAndWrite(
      const datetime signalTime,
      const datetime signalBarTime,
      const ENUM_RAMUSEN_SIGNAL signal,
      const MarketSnapshot &market,
      bool &isEligible
   )
   {
      isEligible = false;

      if(!ready)
         return false;


      if(
         signal != RAMUSEN_SIGNAL_BUY
         &&
         signal != RAMUSEN_SIGNAL_SELL
      )
      {
         return true;
      }


      rawCount++;


      string side =
         SignalToString(signal);


      ulong signalTimeMsc =
         (ulong)signalTime
         *
         1000;


      MqlTick currentTick;


      if(
         SymbolInfoTick(
            gateSymbol,
            currentTick
         )
      )
      {
         if(currentTick.time_msc > 0)
            signalTimeMsc = currentTick.time_msc;
      }


      string researchJoinKey =
         StringFormat(
            "%I64u_%s",
            signalTimeMsc,
            side
         );


      string gateResult = "REJECT";
      string gateReason = "";

      double m15FastBar1 = 0.0;
      double m15SlowBar1 = 0.0;

      string m15Trend = "UNKNOWN";


      if(signal == RAMUSEN_SIGNAL_BUY)
      {
         gateReason = "SIDE_NOT_SELL";
         rejectBuyCount++;
      }
      else
      {
         bool fastReady =
            ReadValue(
               m15FastHandle,
               1,
               m15FastBar1
            );


         bool slowReady =
            ReadValue(
               m15SlowHandle,
               1,
               m15SlowBar1
            );


         if(
            !fastReady
            ||
            !slowReady
         )
         {
            gateReason =
               "M15_CONTEXT_NOT_READY";

            contextErrorCount++;
         }
         else
         {
            if(m15FastBar1 < m15SlowBar1)
            {
               m15Trend = "BEARISH";

               gateResult = "ELIGIBLE";
               gateReason = "S1_SELL_M15_BEARISH";

               eligibleCount++;
               isEligible = true;
            }
            else
            {
               if(m15FastBar1 > m15SlowBar1)
                  m15Trend = "BULLISH";
               else
                  m15Trend = "NEUTRAL";

               gateReason = "M15_NOT_BEARISH";
               rejectContextCount++;
            }
         }
      }


      double entryMid =
         (
            market.bid
            +
            market.ask
         )
         /
         2.0;


      FileWrite(
         csvHandle,

         "P2F4_CANDIDATE_S1",
         researchJoinKey,
         gateSymbol,
         EnumToString(entryTimeframe),

         TimeToString(
            signalTime,
            TIME_DATE |
            TIME_SECONDS
         ),

         signalTimeMsc,

         TimeToString(
            signalBarTime,
            TIME_DATE |
            TIME_SECONDS
         ),

         side,

         gateResult,
         gateReason,

         10,

         DoubleToString(
            m15FastBar1,
            8
         ),

         DoubleToString(
            m15SlowBar1,
            8
         ),

         m15Trend,

         DoubleToString(
            market.bid,
            _Digits
         ),

         DoubleToString(
            market.ask,
            _Digits
         ),

         DoubleToString(
            entryMid,
            _Digits
         ),

         DoubleToString(
            market.spread_points,
            1
         )
      );


      FileFlush(csvHandle);


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F4_GATE_DECISION side=%s result=%s reason=%s m15=%s fast=%.5f slow=%.5f",
            side,
            gateResult,
            gateReason,
            m15Trend,
            m15FastBar1,
            m15SlowBar1
         )
      );


      return true;
   }


   void Shutdown()
   {
      if(ready)
      {
         Print(
            "[RAMUSEN][INFO] ",
            StringFormat(
               "P2F4_GATE_SUMMARY raw=%I64u eligible=%I64u reject_buy=%I64u reject_context=%I64u context_error=%I64u",
               rawCount,
               eligibleCount,
               rejectBuyCount,
               rejectContextCount,
               contextErrorCount
            )
         );
      }


      if(m15FastHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m15FastHandle);
         m15FastHandle = INVALID_HANDLE;
      }


      if(m15SlowHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m15SlowHandle);
         m15SlowHandle = INVALID_HANDLE;
      }


      if(csvHandle != INVALID_HANDLE)
      {
         FileFlush(csvHandle);
         FileClose(csvHandle);
         csvHandle = INVALID_HANDLE;
      }


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
