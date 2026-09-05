#ifndef RAMUSEN_SIGNAL_RESEARCH_MQH
#define RAMUSEN_SIGNAL_RESEARCH_MQH

#include "Config.mqh"
#include "Types.mqh"


// =====================================================
// P2F — FAST / SCALPING SIGNAL RESEARCH EVENT
// =====================================================

struct SignalResearchEvent
{
   ulong id;

   datetime signal_time;
   ulong    signal_time_msc;

   datetime signal_bar_time;

   string side;

   double entry_bid;
   double entry_ask;
   double entry_mid;

   double entry_spread_points;

   double fast_bar2;
   double slow_bar2;

   double fast_bar1;
   double slow_bar1;

   bool m1_done;
   bool m3_done;
   bool m5_done;
   bool m10_done;
   bool m15_done;
   bool m30_done;
   bool m60_done;
};


// =====================================================
// P2F — FAST SIGNAL FORWARD-RETURN RESEARCH
// =====================================================

class CSignalResearch
{
private:

   int csvHandle;

   string csvFileName;

   string researchSymbol;

   ENUM_TIMEFRAMES researchTimeframe;

   ulong researchMagic;

   bool ready;

   ulong nextSignalId;

   SignalResearchEvent events[];


   // ==================================================
   // SIGNAL TO STRING
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
   // FIND FIRST REAL TICK NEAR TARGET
   //
   // Scalping research requires much tighter timing
   // than the old hourly research.
   //
   // Maximum accepted delay:
   // 30 seconds after requested horizon.
   // ==================================================

   bool FindTickNearTarget(
      const ulong targetTimeMsc,

      MqlTick &resultTick,

      long &delayMilliseconds,

      string &status
   )
   {
      const ulong SEARCH_WINDOW_MSC =
         30000; // 30 seconds


      ulong endTimeMsc =
         targetTimeMsc
         +
         SEARCH_WINDOW_MSC;


      if(endTimeMsc < targetTimeMsc)
      {
         status =
            "TIME_OVERFLOW";

         return false;
      }


      MqlTick ticks[];


      ResetLastError();


      int copied =
         CopyTicksRange(
            researchSymbol,
            ticks,
            COPY_TICKS_ALL,
            targetTimeMsc,
            endTimeMsc
         );


      if(copied < 0)
      {
         status =
            StringFormat(
               "COPY_TICKS_FAILED_%d",
               GetLastError()
            );

         return false;
      }


      if(copied == 0)
      {
         status =
            "NO_TICK_NEAR_TARGET";

         return false;
      }


      bool found =
         false;


      ulong earliestTimeMsc =
         0;


      for(int i = 0; i < copied; i++)
      {
         ulong tickTimeMsc =
            ticks[i].time_msc;


         if(tickTimeMsc < targetTimeMsc)
            continue;


         if(
            !found
            ||
            tickTimeMsc < earliestTimeMsc
         )
         {
            found =
               true;


            earliestTimeMsc =
               tickTimeMsc;


            resultTick =
               ticks[i];
         }
      }


      if(!found)
      {
         status =
            "NO_TICK_AFTER_TARGET";

         return false;
      }


      delayMilliseconds =
         (long)(
            resultTick.time_msc
            -
            targetTimeMsc
         );


      if(delayMilliseconds > 30000)
      {
         status =
            "TICK_TOO_LATE";

         return false;
      }


      status =
         "OK";


      return true;
   }


   // ==================================================
   // WRITE ONE FORWARD HORIZON
   //
   // One crossover produces:
   //
   // +1m
   // +3m
   // +5m
   // +10m
   // +15m
   // +30m
   // +60m
   // ==================================================

   bool WriteHorizon(
      SignalResearchEvent &event,

      const int horizonMinutes
   )
   {
      if(!ready)
         return false;


      ulong horizonMsc =
         (ulong)horizonMinutes
         *
         60
         *
         1000;


      ulong targetTimeMsc =
         event.signal_time_msc
         +
         horizonMsc;


      if(targetTimeMsc < event.signal_time_msc)
      {
         return false;
      }


      datetime targetTime =
         (datetime)(
            targetTimeMsc
            /
            1000
         );


      // ==================================================
      // FUTURE TICK
      // ==================================================

      MqlTick futureTick;


      long delayMilliseconds =
         0;


      string status =
         "";


      bool found =
         FindTickNearTarget(
            targetTimeMsc,

            futureTick,

            delayMilliseconds,

            status
         );


      // ==================================================
      // EMPTY CSV VALUES
      // ==================================================

      string observedTimeText =
         "";


      string observedTimeMscText =
         "";


      string delayText =
         "";


      string futureBidText =
         "";


      string futureAskText =
         "";


      string futureMidText =
         "";


      string futureSpreadPointsText =
         "";


      string futureSpreadBpsText =
         "";


      string midReturnPointsText =
         "";


      string executableReturnPointsText =
         "";


      string midReturnBpsText =
         "";


      string executableReturnBpsText =
         "";


      string spreadDragBpsText =
         "";


      // ==================================================
      // ENTRY SPREAD BPS
      // ==================================================

      double entrySpreadBps =
         0.0;


      if(event.entry_mid > 0.0)
      {
         entrySpreadBps =
            (
               (
                  event.entry_ask
                  -
                  event.entry_bid
               )
               /
               event.entry_mid
            )
            *
            10000.0;
      }


      // ==================================================
      // CALCULATE FORWARD RETURN
      // ==================================================

      if(found)
      {
         double point =
            SymbolInfoDouble(
               researchSymbol,
               SYMBOL_POINT
            );


         if(point <= 0.0)
         {
            status =
               "INVALID_POINT";
         }
         else
         {
            double futureBid =
               futureTick.bid;


            double futureAsk =
               futureTick.ask;


            if(
               futureBid <= 0.0
               ||
               futureAsk <= 0.0
            )
            {
               status =
                  "INVALID_FUTURE_PRICE";
            }
            else
            {
               // =========================================
               // FUTURE MID
               // =========================================

               double futureMid =
                  (
                     futureBid
                     +
                     futureAsk
                  )
                  /
                  2.0;


               double futureSpreadPoints =
                  (
                     futureAsk
                     -
                     futureBid
                  )
                  /
                  point;


               double futureSpreadBps =
                  0.0;


               if(futureMid > 0.0)
               {
                  futureSpreadBps =
                     (
                        (
                           futureAsk
                           -
                           futureBid
                        )
                        /
                        futureMid
                     )
                     *
                     10000.0;
               }


               // =========================================
               // MID-TO-MID DIRECTIONAL RETURN
               //
               // Measures raw directional alpha,
               // without executable spread penalty.
               // =========================================

               double midDistance =
                  0.0;


               if(event.side == "BUY")
               {
                  midDistance =
                     futureMid
                     -
                     event.entry_mid;
               }
               else
               {
                  midDistance =
                     event.entry_mid
                     -
                     futureMid;
               }


               double midReturnPoints =
                  midDistance
                  /
                  point;


               double midReturnBps =
                  0.0;


               if(event.entry_mid > 0.0)
               {
                  midReturnBps =
                     (
                        midDistance
                        /
                        event.entry_mid
                     )
                     *
                     10000.0;
               }


               // =========================================
               // EXECUTABLE RETURN
               //
               // BUY:
               // enter ASK → exit BID
               //
               // SELL:
               // enter BID → exit ASK
               //
               // This is much more relevant for scalping.
               // =========================================

               double executableEntryPrice =
                  0.0;


               double executableDistance =
                  0.0;


               if(event.side == "BUY")
               {
                  executableEntryPrice =
                     event.entry_ask;


                  executableDistance =
                     futureBid
                     -
                     event.entry_ask;
               }
               else
               {
                  executableEntryPrice =
                     event.entry_bid;


                  executableDistance =
                     event.entry_bid
                     -
                     futureAsk;
               }


               double executableReturnPoints =
                  executableDistance
                  /
                  point;


               double executableReturnBps =
                  0.0;


               if(executableEntryPrice > 0.0)
               {
                  executableReturnBps =
                     (
                        executableDistance
                        /
                        executableEntryPrice
                     )
                     *
                     10000.0;
               }


               // =========================================
               // SPREAD DRAG
               //
               // How many bps are lost when moving
               // from theoretical mid-return to an
               // actually executable return.
               // =========================================

               double spreadDragBps =
                  midReturnBps
                  -
                  executableReturnBps;


               // =========================================
               // CSV TEXT
               // =========================================

               observedTimeText =
                  TimeToString(
                     futureTick.time,

                     TIME_DATE |
                     TIME_SECONDS
                  );


               observedTimeMscText =
                  (string)futureTick.time_msc;


               delayText =
                  IntegerToString(
                     (int)delayMilliseconds
                  );


               futureBidText =
                  DoubleToString(
                     futureBid,
                     _Digits
                  );


               futureAskText =
                  DoubleToString(
                     futureAsk,
                     _Digits
                  );


               futureMidText =
                  DoubleToString(
                     futureMid,
                     _Digits
                  );


               futureSpreadPointsText =
                  DoubleToString(
                     futureSpreadPoints,
                     1
                  );


               futureSpreadBpsText =
                  DoubleToString(
                     futureSpreadBps,
                     4
                  );


               midReturnPointsText =
                  DoubleToString(
                     midReturnPoints,
                     1
                  );


               executableReturnPointsText =
                  DoubleToString(
                     executableReturnPoints,
                     1
                  );


               midReturnBpsText =
                  DoubleToString(
                     midReturnBps,
                     4
                  );


               executableReturnBpsText =
                  DoubleToString(
                     executableReturnBps,
                     4
                  );


               spreadDragBpsText =
                  DoubleToString(
                     spreadDragBps,
                     4
                  );


               status =
                  "OK";
            }
         }
      }


      // ==================================================
      // WRITE RESEARCH ROW
      // ==================================================

      FileWrite(
         csvHandle,

         event.id,

         researchSymbol,

         EnumToString(
            researchTimeframe
         ),

         researchMagic,


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


         event.side,


         horizonMinutes,


         TimeToString(
            targetTime,

            TIME_DATE |
            TIME_SECONDS
         ),

         targetTimeMsc,


         observedTimeText,

         observedTimeMscText,

         delayText,

         status,


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
            event.entry_spread_points,
            1
         ),

         DoubleToString(
            entrySpreadBps,
            4
         ),


         futureBidText,

         futureAskText,

         futureMidText,

         futureSpreadPointsText,

         futureSpreadBpsText,


         midReturnPointsText,

         executableReturnPointsText,

         midReturnBpsText,

         executableReturnBpsText,

         spreadDragBpsText,


         DoubleToString(
            event.fast_bar2,
            8
         ),

         DoubleToString(
            event.slow_bar2,
            8
         ),

         DoubleToString(
            event.fast_bar1,
            8
         ),

         DoubleToString(
            event.slow_bar1,
            8
         )
      );


      FileFlush(
         csvHandle
      );


      // ==================================================
      // LOG
      // ==================================================

      Print(
         "[RAMUSEN][INFO] ",

         StringFormat(
            "FAST_SIGNAL_FORWARD_WRITTEN signal_id=%I64u side=%s horizon=%dm status=%s mid_bps=%s exec_bps=%s spread_drag_bps=%s delay_ms=%s",
            event.id,
            event.side,
            horizonMinutes,
            status,

            midReturnBpsText,
            executableReturnBpsText,
            spreadDragBpsText,

            delayText
         )
      );


      // Missing market observation is still final.
      // Do not retry forever.
      return true;
   }


   // ==================================================
   // PROCESS HORIZON WHEN MATURE
   // ==================================================

   void ProcessHorizon(
      SignalResearchEvent &event,

      const datetime now,

      const int horizonMinutes,

      bool &done
   )
   {
      if(done)
         return;


      ulong targetTimeMsc =
         event.signal_time_msc
         +
         (
            (ulong)horizonMinutes
            *
            60
            *
            1000
         );


      // Wait until the complete 30-second
      // observation window is in the past.
      ulong matureTimeMsc =
         targetTimeMsc
         +
         30000;


      ulong nowTimeMsc =
         (ulong)now
         *
         1000;


      if(nowTimeMsc < matureTimeMsc)
         return;


      if(
         WriteHorizon(
            event,
            horizonMinutes
         )
      )
      {
         done =
            true;
      }
   }


   // ==================================================
   // EVENT COMPLETE?
   // ==================================================

   bool IsComplete(
      const SignalResearchEvent &event
   )
   {
      return
         event.m1_done
         &&
         event.m3_done
         &&
         event.m5_done
         &&
         event.m10_done
         &&
         event.m15_done
         &&
         event.m30_done
         &&
         event.m60_done;
   }


   // ==================================================
   // REMOVE COMPLETED EVENT
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

   CSignalResearch()
   {
      csvHandle =
         INVALID_HANDLE;


      csvFileName =
         "";


      researchSymbol =
         "";


      researchTimeframe =
         PERIOD_CURRENT;


      researchMagic =
         0;


      ready =
         false;


      nextSignalId =
         1;


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

      const ENUM_TIMEFRAMES timeframe,

      const ulong magic
   )
   {
      Shutdown();


      researchSymbol =
         symbol;


      researchTimeframe =
         timeframe;


      researchMagic =
         magic;


      nextSignalId =
         1;


      ArrayResize(
         events,
         0
      );


      long sessionStamp =
         (long)TimeLocal();


      csvFileName =
         StringFormat(
            "RamusenEA_signal_research_%s_%s_%I64d.csv",

            researchSymbol,

            EnumToString(
               researchTimeframe
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
               "FAST_SIGNAL_RESEARCH_CSV_OPEN_FAILED file=%s error=%d",
               csvFileName,
               GetLastError()
            )
         );


         return false;
      }


      // =================================================
      // CSV HEADER
      // =================================================

      FileWrite(
         csvHandle,

         "signal_id",

         "symbol",
         "timeframe",
         "magic",

         "signal_time",
         "signal_time_msc",

         "signal_bar_time",

         "side",

         "horizon_minutes",

         "target_time",
         "target_time_msc",

         "observed_time",
         "observed_time_msc",

         "delay_milliseconds",

         "status",

         "entry_bid",
         "entry_ask",
         "entry_mid",

         "entry_spread_points",
         "entry_spread_bps",

         "future_bid",
         "future_ask",
         "future_mid",

         "future_spread_points",
         "future_spread_bps",

         "mid_return_points",

         "executable_return_points",

         "mid_return_bps",

         "executable_return_bps",

         "spread_drag_bps",

         "fast_ema_bar2",
         "slow_ema_bar2",

         "fast_ema_bar1",
         "slow_ema_bar1"
      );


      FileFlush(
         csvHandle
      );


      ready =
         true;


      Print(
         "[RAMUSEN][INFO] ",

         StringFormat(
            "FAST_SIGNAL_RESEARCH_READY file=%s horizons=1m,3m,5m,10m,15m,30m,60m tick_window=30s",
            csvFileName
         )
      );


      return true;
   }


   // ==================================================
   // RECORD NEW CROSSOVER
   // ==================================================

   bool RecordSignal(
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


      // =================================================
      // HIGH-PRECISION SIGNAL TIMESTAMP
      // =================================================

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
      )
      {
         if(currentTick.time_msc > 0)
         {
            signalTimeMsc =
               currentTick.time_msc;
         }
      }


      // =================================================
      // ADD EVENT
      // =================================================

      int index =
         ArraySize(
            events
         );


      ArrayResize(
         events,
         index + 1
      );


      events[index].id =
         nextSignalId;


      nextSignalId++;


      events[index].signal_time =
         signalTime;


      events[index].signal_time_msc =
         signalTimeMsc;


      events[index].signal_bar_time =
         signalBarTime;


      events[index].side =
         SignalToString(
            signal
         );


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


      events[index].entry_spread_points =
         market.spread_points;


      events[index].fast_bar2 =
         fastBar2;


      events[index].slow_bar2 =
         slowBar2;


      events[index].fast_bar1 =
         fastBar1;


      events[index].slow_bar1 =
         slowBar1;


      events[index].m1_done =
         false;


      events[index].m3_done =
         false;


      events[index].m5_done =
         false;


      events[index].m10_done =
         false;


      events[index].m15_done =
         false;


      events[index].m30_done =
         false;


      events[index].m60_done =
         false;


      Print(
         "[RAMUSEN][INFO] ",

         StringFormat(
            "FAST_SIGNAL_RESEARCH_RECORDED signal_id=%I64u side=%s time=%s time_msc=%I64u bid=%s ask=%s spread=%.1f",
            events[index].id,

            events[index].side,

            TimeToString(
               signalTime,

               TIME_DATE |
               TIME_SECONDS
            ),

            events[index].signal_time_msc,

            DoubleToString(
               market.bid,
               _Digits
            ),

            DoubleToString(
               market.ask,
               _Digits
            ),

            market.spread_points
         )
      );


      return true;
   }


   // ==================================================
   // PROCESS MATURE SIGNALS
   // ==================================================

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
         // ==============================================
         // +1 MINUTE
         // ==============================================

         ProcessHorizon(
            events[i],
            now,
            1,
            events[i].m1_done
         );


         // ==============================================
         // +3 MINUTES
         // ==============================================

         ProcessHorizon(
            events[i],
            now,
            3,
            events[i].m3_done
         );


         // ==============================================
         // +5 MINUTES
         // ==============================================

         ProcessHorizon(
            events[i],
            now,
            5,
            events[i].m5_done
         );


         // ==============================================
         // +10 MINUTES
         // ==============================================

         ProcessHorizon(
            events[i],
            now,
            10,
            events[i].m10_done
         );


         // ==============================================
         // +15 MINUTES
         // ==============================================

         ProcessHorizon(
            events[i],
            now,
            15,
            events[i].m15_done
         );


         // ==============================================
         // +30 MINUTES
         // ==============================================

         ProcessHorizon(
            events[i],
            now,
            30,
            events[i].m30_done
         );


         // ==============================================
         // +60 MINUTES
         // ==============================================

         ProcessHorizon(
            events[i],
            now,
            60,
            events[i].m60_done
         );


         if(
            IsComplete(
               events[i]
            )
         )
         {
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
      int pending =
         ArraySize(
            events
         );


      if(
         pending > 0
         &&
         ready
      )
      {
         Print(
            "[RAMUSEN][INFO] ",

            StringFormat(
               "FAST_SIGNAL_RESEARCH_PENDING_AT_SHUTDOWN count=%d",
               pending
            )
         );
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