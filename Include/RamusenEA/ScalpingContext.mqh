#ifndef RAMUSEN_SCALPING_CONTEXT_MQH
#define RAMUSEN_SCALPING_CONTEXT_MQH

#include "Config.mqh"
#include "Types.mqh"


class CScalpingContext
{
private:

   int csvHandle;

   string csvFileName;

   string symbol;

   ENUM_TIMEFRAMES entryTimeframe;
   ENUM_TIMEFRAMES contextTimeframe;

   int contextFastHandle;
   int contextSlowHandle;

   int entryATRHandle;

   bool ready;


   // ==================================================
   // SIGNAL STRING
   // ==================================================

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


   // ==================================================
   // INDICATOR BUFFER
   // ==================================================

   bool ReadValue(
      const int handle,
      const int shift,
      double &value
   )
   {
      if(handle == INVALID_HANDLE)
         return false;


      double buffer[1];


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


      value =
         buffer[0];


      return true;
   }


   // ==================================================
   // TREND
   // ==================================================

   string TrendToString(
      const double fastValue,
      const double slowValue
   )
   {
      if(fastValue > slowValue)
         return "BULLISH";


      if(fastValue < slowValue)
         return "BEARISH";


      return "NEUTRAL";
   }


   // ==================================================
   // SIGNAL VS M15 CONTEXT
   // ==================================================

   string AlignmentToString(
      const ENUM_RAMUSEN_SIGNAL signal,
      const string trend
   )
   {
      if(
         signal == RAMUSEN_SIGNAL_BUY
         &&
         trend == "BULLISH"
      )
      {
         return "ALIGNED";
      }


      if(
         signal == RAMUSEN_SIGNAL_SELL
         &&
         trend == "BEARISH"
      )
      {
         return "ALIGNED";
      }


      if(trend == "NEUTRAL")
         return "NEUTRAL";


      return "COUNTER";
   }


   // ==================================================
   // CANDLE DIRECTION
   // ==================================================

   string CandleDirection(
      const double openPrice,
      const double closePrice
   )
   {
      if(closePrice > openPrice)
         return "BULLISH";


      if(closePrice < openPrice)
         return "BEARISH";


      return "DOJI";
   }


public:

   // ==================================================
   // CONSTRUCTOR
   // ==================================================

   CScalpingContext()
   {
      csvHandle =
         INVALID_HANDLE;


      csvFileName =
         "";


      symbol =
         "";


      entryTimeframe =
         PERIOD_CURRENT;


      contextTimeframe =
         PERIOD_M15;


      contextFastHandle =
         INVALID_HANDLE;


      contextSlowHandle =
         INVALID_HANDLE;


      entryATRHandle =
         INVALID_HANDLE;


      ready =
         false;
   }


   // ==================================================
   // INITIALIZE
   // ==================================================

   bool Initialize(
      const string newSymbol,
      const ENUM_TIMEFRAMES newEntryTimeframe
   )
   {
      Shutdown();


      symbol =
         newSymbol;


      entryTimeframe =
         newEntryTimeframe;


      contextTimeframe =
         InpScalpingContextTimeframe;


      // =================================================
      // VALIDATE CONFIG
      // =================================================

      if(InpScalpingContextFastMAPeriod <= 0)
         return false;


      if(InpScalpingContextSlowMAPeriod <= 0)
         return false;


      if(
         InpScalpingContextFastMAPeriod
         >=
         InpScalpingContextSlowMAPeriod
      )
      {
         return false;
      }


      if(InpScalpingATRPeriod <= 0)
         return false;


      // =================================================
      // M15 CONTEXT EMA
      // =================================================

      ResetLastError();


      contextFastHandle =
         iMA(
            symbol,
            contextTimeframe,
            InpScalpingContextFastMAPeriod,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );


      if(contextFastHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "SCALPING_CONTEXT_FAST_EMA_CREATE_FAILED error=%d",
               GetLastError()
            )
         );


         Shutdown();

         return false;
      }


      ResetLastError();


      contextSlowHandle =
         iMA(
            symbol,
            contextTimeframe,
            InpScalpingContextSlowMAPeriod,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );


      if(contextSlowHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "SCALPING_CONTEXT_SLOW_EMA_CREATE_FAILED error=%d",
               GetLastError()
            )
         );


         Shutdown();

         return false;
      }


      // =================================================
      // M5 ATR
      // =================================================

      ResetLastError();


      entryATRHandle =
         iATR(
            symbol,
            entryTimeframe,
            InpScalpingATRPeriod
         );


      if(entryATRHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "SCALPING_CONTEXT_ATR_CREATE_FAILED error=%d",
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
            "RamusenEA_scalping_context_%s_%s_%I64d.csv",
            symbol,
            EnumToString(
               entryTimeframe
            ),
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
               "SCALPING_CONTEXT_CSV_OPEN_FAILED file=%s error=%d",
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

         "join_key",

         "symbol",

         "entry_timeframe",
         "context_timeframe",

         "signal_time",
         "signal_time_msc",

         "signal_bar_time",

         "side",

         "context_status",

         "server_hour",
         "server_minute",
         "server_day_of_week",


         // ===============================================
         // EXECUTION CONTEXT
         // ===============================================

         "entry_bid",
         "entry_ask",
         "entry_mid",

         "spread_points",
         "spread_bps",


         // ===============================================
         // M5 EMA CONTEXT
         // ===============================================

         "m5_fast_ema_bar2",
         "m5_slow_ema_bar2",

         "m5_fast_ema_bar1",
         "m5_slow_ema_bar1",

         "m5_fast_slope_points",
         "m5_slow_slope_points",

         "m5_ema_separation_points",
         "m5_ema_separation_bps",

         "m5_signal_separation_bps",


         // ===============================================
         // VOLATILITY
         // ===============================================

         "m5_atr_points",
         "m5_atr_bps",

         "spread_to_atr_ratio",


         // ===============================================
         // COMPLETED SIGNAL CANDLE — BAR 1
         // ===============================================

         "m5_bar1_open",
         "m5_bar1_high",
         "m5_bar1_low",
         "m5_bar1_close",

         "m5_bar1_direction",

         "m5_bar1_body_points",
         "m5_bar1_range_points",

         "m5_bar1_body_to_range",

         "m5_bar1_range_to_atr",


         // ===============================================
         // SHORT MOMENTUM
         // ===============================================

         "m5_momentum_3bar_bps",

         "m5_signal_momentum_3bar_bps",


         // ===============================================
         // M15 REGIME
         // ===============================================

         "m15_fast_ema_bar2",
         "m15_slow_ema_bar2",

         "m15_fast_ema_bar1",
         "m15_slow_ema_bar1",

         "m15_fast_slope_points",
         "m15_slow_slope_points",

         "m15_ema_separation_points",
         "m15_ema_separation_bps",

         "m15_trend",

         "m15_signal_alignment"
      );


      FileFlush(
         csvHandle
      );


      ready =
         true;


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "SCALPING_CONTEXT_READY file=%s entry_tf=%s context_tf=%s context_ema=%d/%d atr=%d",
            csvFileName,
            EnumToString(
               entryTimeframe
            ),
            EnumToString(
               contextTimeframe
            ),
            InpScalpingContextFastMAPeriod,
            InpScalpingContextSlowMAPeriod,
            InpScalpingATRPeriod
         )
      );


      return true;
   }


   // ==================================================
   // CAPTURE ONE CROSSOVER CONTEXT
   // ==================================================

   bool CaptureAndWrite(
      const datetime signalTime,
      const datetime signalBarTime,

      const ENUM_RAMUSEN_SIGNAL signal,

      const MarketSnapshot &market,

      const double fastBar2,
      const double slowBar2,

      const double fastBar1,
      const double slowBar1
   )
   {
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


      double point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
         return false;


      // =================================================
      // SIGNAL TIME MSC
      // =================================================

      ulong signalTimeMsc =
         (ulong)signalTime
         *
         1000;


      MqlTick currentTick;


      if(
         SymbolInfoTick(
            symbol,
            currentTick
         )
      )
      {
         if(currentTick.time_msc > 0)
         {
            signalTimeMsc =
               currentTick.time_msc;
         }
      }


      string side =
         SignalToString(
            signal
         );


      string joinKey =
         StringFormat(
            "%s_%s",

            TimeToString(
               signalBarTime,
               TIME_DATE |
               TIME_MINUTES
            ),

            side
         );


      // =================================================
      // SERVER TIME
      // =================================================

      MqlDateTime timeParts;


      TimeToStruct(
         signalTime,
         timeParts
      );


      // =================================================
      // MARKET / SPREAD
      // =================================================

      double entryMid =
         (
            market.bid
            +
            market.ask
         )
         /
         2.0;


      double spreadBps =
         0.0;


      if(entryMid > 0.0)
      {
         spreadBps =
            (
               (
                  market.ask
                  -
                  market.bid
               )
               /
               entryMid
            )
            *
            10000.0;
      }


      // =================================================
      // M5 EMA FEATURES
      // =================================================

      double m5FastSlopePoints =
         (
            fastBar1
            -
            fastBar2
         )
         /
         point;


      double m5SlowSlopePoints =
         (
            slowBar1
            -
            slowBar2
         )
         /
         point;


      double m5Separation =
         fastBar1
         -
         slowBar1;


      double m5SeparationPoints =
         m5Separation
         /
         point;


      double m5SeparationBps =
         0.0;


      if(entryMid > 0.0)
      {
         m5SeparationBps =
            (
               m5Separation
               /
               entryMid
            )
            *
            10000.0;
      }


      double m5SignalSeparationBps =
         m5SeparationBps;


      if(signal == RAMUSEN_SIGNAL_SELL)
      {
         m5SignalSeparationBps =
            -m5SignalSeparationBps;
      }


      // =================================================
      // STATUS
      // =================================================

      string contextStatus =
         "OK";


      // =================================================
      // ATR
      // =================================================

      double atrValue =
         0.0;


      if(
         !ReadValue(
            entryATRHandle,
            1,
            atrValue
         )
         ||
         atrValue <= 0.0
      )
      {
         contextStatus =
            "ATR_NOT_READY";

         atrValue =
            0.0;
      }


      double atrPoints =
         0.0;


      double atrBps =
         0.0;


      if(atrValue > 0.0)
      {
         atrPoints =
            atrValue
            /
            point;


         if(entryMid > 0.0)
         {
            atrBps =
               (
                  atrValue
                  /
                  entryMid
               )
               *
               10000.0;
         }
      }


      double spreadToATR =
         0.0;


      if(atrPoints > 0.0)
      {
         spreadToATR =
            market.spread_points
            /
            atrPoints;
      }


      // =================================================
      // COMPLETED M5 BAR 1
      // =================================================

      double barOpen =
         iOpen(
            symbol,
            entryTimeframe,
            1
         );


      double barHigh =
         iHigh(
            symbol,
            entryTimeframe,
            1
         );


      double barLow =
         iLow(
            symbol,
            entryTimeframe,
            1
         );


      double barClose =
         iClose(
            symbol,
            entryTimeframe,
            1
         );


      double close4 =
         iClose(
            symbol,
            entryTimeframe,
            4
         );


      if(
         barOpen <= 0.0
         ||
         barHigh <= 0.0
         ||
         barLow <= 0.0
         ||
         barClose <= 0.0
         ||
         close4 <= 0.0
      )
      {
         if(contextStatus == "OK")
         {
            contextStatus =
               "BAR_DATA_NOT_READY";
         }
      }


      double bodyPoints =
         0.0;


      double rangePoints =
         0.0;


      if(
         barOpen > 0.0
         &&
         barClose > 0.0
      )
      {
         bodyPoints =
            MathAbs(
               barClose
               -
               barOpen
            )
            /
            point;
      }


      if(
         barHigh > 0.0
         &&
         barLow > 0.0
      )
      {
         rangePoints =
            (
               barHigh
               -
               barLow
            )
            /
            point;
      }


      double bodyToRange =
         0.0;


      if(rangePoints > 0.0)
      {
         bodyToRange =
            bodyPoints
            /
            rangePoints;
      }


      double rangeToATR =
         0.0;


      if(atrPoints > 0.0)
      {
         rangeToATR =
            rangePoints
            /
            atrPoints;
      }


      string barDirection =
         CandleDirection(
            barOpen,
            barClose
         );


      // =================================================
      // THREE-BAR MOMENTUM
      //
      // close1 vs close4:
      // uses only completed bars.
      // =================================================

      double momentum3BarBps =
         0.0;


      if(close4 > 0.0)
      {
         momentum3BarBps =
            (
               (
                  barClose
                  -
                  close4
               )
               /
               close4
            )
            *
            10000.0;
      }


      double signalMomentum3BarBps =
         momentum3BarBps;


      if(signal == RAMUSEN_SIGNAL_SELL)
      {
         signalMomentum3BarBps =
            -signalMomentum3BarBps;
      }


      // =================================================
      // M15 CONTEXT EMA
      // =================================================

      double m15FastBar2 =
         0.0;


      double m15SlowBar2 =
         0.0;


      double m15FastBar1 =
         0.0;


      double m15SlowBar1 =
         0.0;


      bool m15Ready =
         true;


      if(
         !ReadValue(
            contextFastHandle,
            2,
            m15FastBar2
         )
      )
      {
         m15Ready =
            false;
      }


      if(
         !ReadValue(
            contextSlowHandle,
            2,
            m15SlowBar2
         )
      )
      {
         m15Ready =
            false;
      }


      if(
         !ReadValue(
            contextFastHandle,
            1,
            m15FastBar1
         )
      )
      {
         m15Ready =
            false;
      }


      if(
         !ReadValue(
            contextSlowHandle,
            1,
            m15SlowBar1
         )
      )
      {
         m15Ready =
            false;
      }


      if(
         !m15Ready
         &&
         contextStatus == "OK"
      )
      {
         contextStatus =
            "M15_EMA_NOT_READY";
      }


      double m15FastSlopePoints =
         0.0;


      double m15SlowSlopePoints =
         0.0;


      double m15SeparationPoints =
         0.0;


      double m15SeparationBps =
         0.0;


      if(m15Ready)
      {
         m15FastSlopePoints =
            (
               m15FastBar1
               -
               m15FastBar2
            )
            /
            point;


         m15SlowSlopePoints =
            (
               m15SlowBar1
               -
               m15SlowBar2
            )
            /
            point;


         double m15Separation =
            m15FastBar1
            -
            m15SlowBar1;


         m15SeparationPoints =
            m15Separation
            /
            point;


         if(entryMid > 0.0)
         {
            m15SeparationBps =
               (
                  m15Separation
                  /
                  entryMid
               )
               *
               10000.0;
         }
      }


      string m15Trend =
         "UNKNOWN";


      string m15Alignment =
         "UNKNOWN";


      if(m15Ready)
      {
         m15Trend =
            TrendToString(
               m15FastBar1,
               m15SlowBar1
            );


         m15Alignment =
            AlignmentToString(
               signal,
               m15Trend
            );
      }


      // =================================================
      // WRITE ONE ROW PER CROSSOVER
      // =================================================

      FileWrite(
         csvHandle,

         joinKey,

         symbol,

         EnumToString(
            entryTimeframe
         ),

         EnumToString(
            contextTimeframe
         ),

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

         contextStatus,

         timeParts.hour,
         timeParts.min,
         timeParts.day_of_week,


         // ===============================================
         // MARKET
         // ===============================================

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
         ),

         DoubleToString(
            spreadBps,
            4
         ),


         // ===============================================
         // M5 EMA
         // ===============================================

         DoubleToString(
            fastBar2,
            8
         ),

         DoubleToString(
            slowBar2,
            8
         ),

         DoubleToString(
            fastBar1,
            8
         ),

         DoubleToString(
            slowBar1,
            8
         ),

         DoubleToString(
            m5FastSlopePoints,
            2
         ),

         DoubleToString(
            m5SlowSlopePoints,
            2
         ),

         DoubleToString(
            m5SeparationPoints,
            2
         ),

         DoubleToString(
            m5SeparationBps,
            4
         ),

         DoubleToString(
            m5SignalSeparationBps,
            4
         ),


         // ===============================================
         // ATR
         // ===============================================

         DoubleToString(
            atrPoints,
            2
         ),

         DoubleToString(
            atrBps,
            4
         ),

         DoubleToString(
            spreadToATR,
            6
         ),


         // ===============================================
         // BAR
         // ===============================================

         DoubleToString(
            barOpen,
            _Digits
         ),

         DoubleToString(
            barHigh,
            _Digits
         ),

         DoubleToString(
            barLow,
            _Digits
         ),

         DoubleToString(
            barClose,
            _Digits
         ),

         barDirection,

         DoubleToString(
            bodyPoints,
            2
         ),

         DoubleToString(
            rangePoints,
            2
         ),

         DoubleToString(
            bodyToRange,
            6
         ),

         DoubleToString(
            rangeToATR,
            6
         ),


         // ===============================================
         // MOMENTUM
         // ===============================================

         DoubleToString(
            momentum3BarBps,
            4
         ),

         DoubleToString(
            signalMomentum3BarBps,
            4
         ),


         // ===============================================
         // M15
         // ===============================================

         DoubleToString(
            m15FastBar2,
            8
         ),

         DoubleToString(
            m15SlowBar2,
            8
         ),

         DoubleToString(
            m15FastBar1,
            8
         ),

         DoubleToString(
            m15SlowBar1,
            8
         ),

         DoubleToString(
            m15FastSlopePoints,
            2
         ),

         DoubleToString(
            m15SlowSlopePoints,
            2
         ),

         DoubleToString(
            m15SeparationPoints,
            2
         ),

         DoubleToString(
            m15SeparationBps,
            4
         ),

         m15Trend,

         m15Alignment
      );


      FileFlush(
         csvHandle
      );


      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "SCALPING_CONTEXT_WRITTEN side=%s join_key=%s status=%s m15=%s alignment=%s atr_points=%.1f spread_atr=%.4f momentum=%.4f",
            side,
            joinKey,
            contextStatus,
            m15Trend,
            m15Alignment,
            atrPoints,
            spreadToATR,
            signalMomentum3BarBps
         )
      );


      return true;
   }


   // ==================================================
   // SHUTDOWN
   // ==================================================

   void Shutdown()
   {
      if(contextFastHandle != INVALID_HANDLE)
      {
         IndicatorRelease(
            contextFastHandle
         );


         contextFastHandle =
            INVALID_HANDLE;
      }


      if(contextSlowHandle != INVALID_HANDLE)
      {
         IndicatorRelease(
            contextSlowHandle
         );


         contextSlowHandle =
            INVALID_HANDLE;
      }


      if(entryATRHandle != INVALID_HANDLE)
      {
         IndicatorRelease(
            entryATRHandle
         );


         entryATRHandle =
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


      ready =
         false;
   }


   // ==================================================
   // FILE INFO
   // ==================================================

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