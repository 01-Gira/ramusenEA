#ifndef RAMUSEN_S30_EVENT_GENERATOR_CONTROL_RESEARCH_MQH
#define RAMUSEN_S30_EVENT_GENERATOR_CONTROL_RESEARCH_MQH

#include "Config.mqh"
#include "Types.mqh"

// =====================================================
// S3.0 — M15 BEARISH CONTEXT EVENT-GENERATOR CONTROL
//
// RESEARCH ONLY.
// NO ORDER SEND.
// NO SL / TP.
// NO S2 GATE.
// NO LAYERING.
//
// Research question:
//
// Does the M5 EMA9/21 bearish crossover add incremental
// timing information beyond simply observing an M5 bar
// while the completed M15 state is bearish
// (EMA20 < EMA50)?
//
// Population:
//   every completed M5 bar boundary for which the latest
//   COMPLETED M15 bar has EMA20 < EMA50.
//
// Group:
//   CROSSOVER_EVENT
//      completed M5 EMA9/21 bearish crossover
//
//   CONTEXT_ONLY
//      same M15 bearish context, but no bearish crossover
//
// Direction for all forward-return labels:
//   hypothetical SELL
//
// Entry:
//   BID at the first observed tick of the NEW M5 bar,
//   after the previous M5 bar has completed.
//
// Exit:
//   ASK at the first tick on/after each target horizon,
//   with a maximum +30 second lookup window.
//
// Horizons:
//   1m, 3m, 5m, 10m, 15m, 30m, 60m, 90m.
//
// Causality:
//   M5 EMA values use shifts 2 / 1.
//   M15 EMA context uses completed shifts 2 / 1.
// =====================================================


struct S30Event
{
   ulong event_id;

   datetime event_time;
   ulong event_time_msc;

   datetime completed_m5_bar_time;
   datetime completed_m15_bar_time;

   bool bearish_crossover;

   double entry_bid;
   double entry_ask;
   double entry_mid;

   double entry_spread_points;
   double entry_spread_bps;

   double m5_fast_bar2;
   double m5_slow_bar2;
   double m5_fast_bar1;
   double m5_slow_bar1;

   double m15_fast_bar2;
   double m15_slow_bar2;
   double m15_fast_bar1;
   double m15_slow_bar1;

   bool m1_done;
   bool m3_done;
   bool m5_done;
   bool m10_done;
   bool m15_done;
   bool m30_done;
   bool m60_done;
   bool m90_done;
};


class CS30EventGeneratorControlResearch
{
private:

   int csvHandle;
   string csvFileName;

   string symbol;
   ENUM_TIMEFRAMES entryTimeframe;
   ENUM_TIMEFRAMES contextTimeframe;

   int m5FastHandle;
   int m5SlowHandle;

   int m15FastHandle;
   int m15SlowHandle;

   bool ready;

   bool barClockPrimed;
   datetime lastObservedCurrentBarTime;

   ulong nextEventId;

   S30Event events[];

   ulong m5BarChecks;
   ulong bearishContextEvents;
   ulong bearishCrossoverEvents;

   ulong horizonRowsWritten;
   ulong horizonOkRows;
   ulong horizonMissingRows;
   ulong horizonPendingRows;
   ulong horizonErrorRows;

   bool integrityDegraded;


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

      value = buffer[0];

      return true;
   }


   void RemoveEvent(
      const int index
   )
   {
      int total =
         ArraySize(events);

      if(
         index < 0
         ||
         index >= total
      )
      {
         return;
      }

      for(int i = index; i < total - 1; i++)
         events[i] = events[i + 1];

      ArrayResize(
         events,
         total - 1
      );
   }


   bool IsComplete(
      const S30Event &event
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
         event.m60_done
         &&
         event.m90_done;
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
            symbol,
            ticks,
            COPY_TICKS_ALL,
            targetTimeMsc,
            targetTimeMsc + MAX_DELAY_MSC
         );

      if(copied < 0)
      {
         status =
            StringFormat(
               "COPY_TICKS_FAILED_%d",
               GetLastError()
            );

         return true;
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
         const ulong tickTimeMsc =
            (ulong)ticks[i].time_msc;

         if(tickTimeMsc < targetTimeMsc)
            continue;

         if(
            !found
            ||
            tickTimeMsc < earliest
         )
         {
            found = true;
            earliest = tickTimeMsc;
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
            (ulong)resultTick.time_msc
            -
            targetTimeMsc
         );

      if(delayMilliseconds > 30000)
      {
         status = "TICK_TOO_LATE";
         return true;
      }

      status = "OK";

      return true;
   }


   void WriteRow(
      const S30Event &event,
      const int horizonMinutes,
      const string status,
      const ulong targetTimeMsc,
      const MqlTick &futureTick,
      const long delayMilliseconds,
      const bool hasFutureTick
   )
   {
      string observedTimeText = "";
      string observedTimeMscText = "";
      string delayText = "";

      string futureBidText = "";
      string futureAskText = "";
      string futureMidText = "";

      string futureSpreadPointsText = "";
      string futureSpreadBpsText = "";

      string midReturnBpsText = "";
      string executableReturnBpsText = "";
      string spreadDragBpsText = "";

      if(hasFutureTick)
      {
         double point =
            SymbolInfoDouble(
               symbol,
               SYMBOL_POINT
            );

         double futureBid =
            futureTick.bid;

         double futureAsk =
            futureTick.ask;

         if(
            point > 0.0
            &&
            futureBid > 0.0
            &&
            futureAsk > 0.0
         )
         {
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

            double futureSpreadBps = 0.0;

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

            // All S3.0 outcomes are SELL-positive.
            double midDistance =
               event.entry_mid
               -
               futureMid;

            double midReturnBps = 0.0;

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

            double executableDistance =
               event.entry_bid
               -
               futureAsk;

            double executableReturnBps = 0.0;

            if(event.entry_bid > 0.0)
            {
               executableReturnBps =
                  (
                     executableDistance
                     /
                     event.entry_bid
                  )
                  *
                  10000.0;
            }

            double spreadDragBps =
               midReturnBps
               -
               executableReturnBps;

            observedTimeText =
               TimeToString(
                  futureTick.time,
                  TIME_DATE | TIME_SECONDS
               );

            observedTimeMscText =
               (string)(
                  (ulong)futureTick.time_msc
               );

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
                  6
               );

            midReturnBpsText =
               DoubleToString(
                  midReturnBps,
                  8
               );

            executableReturnBpsText =
               DoubleToString(
                  executableReturnBps,
                  8
               );

            spreadDragBpsText =
               DoubleToString(
                  spreadDragBps,
                  8
               );
         }
      }

      const string groupName =
         event.bearish_crossover
         ? "CROSSOVER_EVENT"
         : "CONTEXT_ONLY";

      string eventKey =
         StringFormat(
            "%I64u_CTXSELL",
            event.event_time_msc
         );

      datetime targetTime =
         (datetime)(
            targetTimeMsc
            /
            1000ULL
         );

      FileWrite(
         csvHandle,

         eventKey,
         event.event_id,

         symbol,
         EnumToString(entryTimeframe),
         EnumToString(contextTimeframe),

         TimeToString(
            event.event_time,
            TIME_DATE | TIME_SECONDS
         ),
         event.event_time_msc,

         TimeToString(
            event.completed_m5_bar_time,
            TIME_DATE | TIME_MINUTES
         ),

         TimeToString(
            event.completed_m15_bar_time,
            TIME_DATE | TIME_MINUTES
         ),

         groupName,
         event.bearish_crossover ? "YES" : "NO",

         "SELL",
         "BEARISH",

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
            event.entry_spread_bps,
            8
         ),

         DoubleToString(
            event.m5_fast_bar2,
            8
         ),
         DoubleToString(
            event.m5_slow_bar2,
            8
         ),
         DoubleToString(
            event.m5_fast_bar1,
            8
         ),
         DoubleToString(
            event.m5_slow_bar1,
            8
         ),

         DoubleToString(
            event.m15_fast_bar2,
            8
         ),
         DoubleToString(
            event.m15_slow_bar2,
            8
         ),
         DoubleToString(
            event.m15_fast_bar1,
            8
         ),
         DoubleToString(
            event.m15_slow_bar1,
            8
         ),

         horizonMinutes,

         TimeToString(
            targetTime,
            TIME_DATE | TIME_SECONDS
         ),
         targetTimeMsc,

         observedTimeText,
         observedTimeMscText,
         delayText,

         status,

         futureBidText,
         futureAskText,
         futureMidText,

         futureSpreadPointsText,
         futureSpreadBpsText,

         midReturnBpsText,
         executableReturnBpsText,
         spreadDragBpsText
      );

      FileFlush(csvHandle);

      horizonRowsWritten++;

      if(status == "OK")
      {
         horizonOkRows++;
      }
      else if(
         status == "NO_TICK_NEAR_TARGET"
         ||
         status == "TICK_TOO_LATE"
      )
      {
         horizonMissingRows++;
      }
      else if(status == "PENDING_AT_SHUTDOWN")
      {
         horizonPendingRows++;
      }
      else
      {
         horizonErrorRows++;
         integrityDegraded = true;
      }
   }


   void WritePendingRow(
      const S30Event &event,
      const int horizonMinutes
   )
   {
      ulong targetTimeMsc =
         event.event_time_msc
         +
         (
            (ulong)horizonMinutes
            *
            60ULL
            *
            1000ULL
         );

      MqlTick emptyTick;
      ZeroMemory(emptyTick);

      WriteRow(
         event,
         horizonMinutes,
         "PENDING_AT_SHUTDOWN",
         targetTimeMsc,
         emptyTick,
         0,
         false
      );
   }


   bool WriteHorizon(
      S30Event &event,
      const int horizonMinutes
   )
   {
      ulong targetTimeMsc =
         event.event_time_msc
         +
         (
            (ulong)horizonMinutes
            *
            60ULL
            *
            1000ULL
         );

      MqlTick futureTick;
      ZeroMemory(futureTick);

      long delayMilliseconds = 0;

      string status = "";

      if(
         !FindTargetTick(
            targetTimeMsc,
            futureTick,
            delayMilliseconds,
            status
         )
      )
      {
         status = "TARGET_LOOKUP_INTERNAL_ERROR";
      }

      bool hasFutureTick =
         status == "OK";

      WriteRow(
         event,
         horizonMinutes,
         status,
         targetTimeMsc,
         futureTick,
         delayMilliseconds,
         hasFutureTick
      );

      return true;
   }


   void ProcessHorizon(
      S30Event &event,
      const datetime now,
      const int horizonMinutes,
      bool &done
   )
   {
      if(done)
         return;

      ulong targetTimeMsc =
         event.event_time_msc
         +
         (
            (ulong)horizonMinutes
            *
            60ULL
            *
            1000ULL
         );

      ulong matureTimeMsc =
         targetTimeMsc
         +
         30000ULL;

      ulong nowTimeMsc =
         (ulong)now
         *
         1000ULL;

      if(nowTimeMsc < matureTimeMsc)
         return;

      if(
         WriteHorizon(
            event,
            horizonMinutes
         )
      )
      {
         done = true;
      }
   }


public:

   CS30EventGeneratorControlResearch()
   {
      csvHandle = INVALID_HANDLE;
      csvFileName = "";

      symbol = "";

      entryTimeframe = PERIOD_M5;
      contextTimeframe = PERIOD_M15;

      m5FastHandle = INVALID_HANDLE;
      m5SlowHandle = INVALID_HANDLE;

      m15FastHandle = INVALID_HANDLE;
      m15SlowHandle = INVALID_HANDLE;

      ready = false;

      barClockPrimed = false;
      lastObservedCurrentBarTime = 0;

      nextEventId = 1;

      ArrayResize(
         events,
         0
      );

      m5BarChecks = 0;
      bearishContextEvents = 0;
      bearishCrossoverEvents = 0;

      horizonRowsWritten = 0;
      horizonOkRows = 0;
      horizonMissingRows = 0;
      horizonPendingRows = 0;
      horizonErrorRows = 0;

      integrityDegraded = false;
   }


   bool Initialize(
      const string newSymbol,
      const ENUM_TIMEFRAMES newEntryTimeframe
   )
   {
      Shutdown();

      symbol = newSymbol;

      entryTimeframe =
         newEntryTimeframe;

      contextTimeframe =
         InpScalpingContextTimeframe;

      // S3.0 freeze guard.
      if(entryTimeframe != PERIOD_M5)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            "S30_REQUIRES_M5"
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
               "S30_FREEZE_VIOLATION_M5_EMA expected=9/21 actual=%d/%d",
               InpFastMAPeriod,
               InpSlowMAPeriod
            )
         );

         return false;
      }

      if(
         contextTimeframe != PERIOD_M15
         ||
         InpScalpingContextFastMAPeriod != 20
         ||
         InpScalpingContextSlowMAPeriod != 50
      )
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "S30_FREEZE_VIOLATION_M15_CONTEXT tf=%s ema=%d/%d",
               EnumToString(contextTimeframe),
               InpScalpingContextFastMAPeriod,
               InpScalpingContextSlowMAPeriod
            )
         );

         return false;
      }

      ResetLastError();

      m5FastHandle =
         iMA(
            symbol,
            entryTimeframe,
            InpFastMAPeriod,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );

      if(m5FastHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "S30_M5_FAST_EMA_CREATE_FAILED error=%d",
               GetLastError()
            )
         );

         Shutdown();
         return false;
      }

      ResetLastError();

      m5SlowHandle =
         iMA(
            symbol,
            entryTimeframe,
            InpSlowMAPeriod,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );

      if(m5SlowHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "S30_M5_SLOW_EMA_CREATE_FAILED error=%d",
               GetLastError()
            )
         );

         Shutdown();
         return false;
      }

      ResetLastError();

      m15FastHandle =
         iMA(
            symbol,
            contextTimeframe,
            InpScalpingContextFastMAPeriod,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );

      if(m15FastHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "S30_M15_FAST_EMA_CREATE_FAILED error=%d",
               GetLastError()
            )
         );

         Shutdown();
         return false;
      }

      ResetLastError();

      m15SlowHandle =
         iMA(
            symbol,
            contextTimeframe,
            InpScalpingContextSlowMAPeriod,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );

      if(m15SlowHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "S30_M15_SLOW_EMA_CREATE_FAILED error=%d",
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
            "RamusenEA_s30_event_control_%s_%s_%I64d.csv",
            symbol,
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
               "S30_CSV_OPEN_FAILED file=%s error=%d",
               csvFileName,
               GetLastError()
            )
         );

         Shutdown();
         return false;
      }

      FileWrite(
         csvHandle,

         "event_key",
         "event_id",

         "symbol",
         "entry_timeframe",
         "context_timeframe",

         "event_time",
         "event_time_msc",

         "completed_m5_bar_time",
         "completed_m15_bar_time",

         "group",
         "is_bearish_crossover",

         "research_side",
         "m15_context",

         "entry_bid",
         "entry_ask",
         "entry_mid",

         "entry_spread_points",
         "entry_spread_bps",

         "m5_fast_ema_bar2",
         "m5_slow_ema_bar2",
         "m5_fast_ema_bar1",
         "m5_slow_ema_bar1",

         "m15_fast_ema_bar2",
         "m15_slow_ema_bar2",
         "m15_fast_ema_bar1",
         "m15_slow_ema_bar1",

         "horizon_minutes",

         "target_time",
         "target_time_msc",

         "observed_time",
         "observed_time_msc",
         "delay_milliseconds",

         "status",

         "future_bid",
         "future_ask",
         "future_mid",

         "future_spread_points",
         "future_spread_bps",

         "mid_return_bps",
         "executable_return_bps",
         "spread_drag_bps"
      );

      FileFlush(csvHandle);

      ready = true;

      barClockPrimed = false;
      lastObservedCurrentBarTime = 0;

      nextEventId = 1;

      ArrayResize(
         events,
         0
      );

      m5BarChecks = 0;
      bearishContextEvents = 0;
      bearishCrossoverEvents = 0;

      horizonRowsWritten = 0;
      horizonOkRows = 0;
      horizonMissingRows = 0;
      horizonPendingRows = 0;
      horizonErrorRows = 0;

      integrityDegraded = false;

      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "S30_EVENT_CONTROL_READY file=%s population=ALL_M5_BARS_WHEN_COMPLETED_M15_EMA20_LT_EMA50 event=EMA9_21_BEARISH_CROSS horizons=1,3,5,10,15,30,60,90",
            csvFileName
         )
      );

      return true;
   }


   bool RecordCurrentBar(
      const datetime now,
      const datetime currentBarTime,
      const MarketSnapshot &market
   )
   {
      if(!ready)
         return false;

      // The first OnTick after tester/EA startup may occur
      // in the middle of an already-open M5 bar.
      // Prime the bar clock and deliberately do not create
      // a research event from that partial startup state.
      if(!barClockPrimed)
      {
         barClockPrimed = true;
         lastObservedCurrentBarTime =
            currentBarTime;

         Print(
            "[RAMUSEN][INFO] ",
            StringFormat(
               "S30_BAR_CLOCK_PRIMED current_bar=%s",
               TimeToString(
                  currentBarTime,
                  TIME_DATE | TIME_MINUTES
               )
            )
         );

         return true;
      }

      if(
         currentBarTime
         ==
         lastObservedCurrentBarTime
      )
      {
         return true;
      }

      lastObservedCurrentBarTime =
         currentBarTime;

      m5BarChecks++;

      int minimumM5Bars =
         InpSlowMAPeriod
         +
         2;

      int minimumM15Bars =
         InpScalpingContextSlowMAPeriod
         +
         2;

      if(
         BarsCalculated(m5FastHandle)
         <
         minimumM5Bars
         ||
         BarsCalculated(m5SlowHandle)
         <
         minimumM5Bars
         ||
         BarsCalculated(m15FastHandle)
         <
         minimumM15Bars
         ||
         BarsCalculated(m15SlowHandle)
         <
         minimumM15Bars
      )
      {
         return true;
      }

      double m5Fast2 = 0.0;
      double m5Slow2 = 0.0;
      double m5Fast1 = 0.0;
      double m5Slow1 = 0.0;

      double m15Fast2 = 0.0;
      double m15Slow2 = 0.0;
      double m15Fast1 = 0.0;
      double m15Slow1 = 0.0;

      if(
         !ReadValue(
            m5FastHandle,
            2,
            m5Fast2
         )
         ||
         !ReadValue(
            m5SlowHandle,
            2,
            m5Slow2
         )
         ||
         !ReadValue(
            m5FastHandle,
            1,
            m5Fast1
         )
         ||
         !ReadValue(
            m5SlowHandle,
            1,
            m5Slow1
         )
         ||
         !ReadValue(
            m15FastHandle,
            2,
            m15Fast2
         )
         ||
         !ReadValue(
            m15SlowHandle,
            2,
            m15Slow2
         )
         ||
         !ReadValue(
            m15FastHandle,
            1,
            m15Fast1
         )
         ||
         !ReadValue(
            m15SlowHandle,
            1,
            m15Slow1
         )
      )
      {
         integrityDegraded = true;

         Print(
            "[RAMUSEN][ERROR] ",
            "S30_INDICATOR_READ_FAILED integrity=DEGRADED"
         );

         return false;
      }

      // Primary control population:
      // latest COMPLETED M15 bar is bearish.
      if(m15Fast1 >= m15Slow1)
         return true;

      datetime completedM5BarTime =
         iTime(
            symbol,
            entryTimeframe,
            1
         );

      datetime completedM15BarTime =
         iTime(
            symbol,
            contextTimeframe,
            1
         );

      if(
         completedM5BarTime <= 0
         ||
         completedM15BarTime <= 0
      )
      {
         integrityDegraded = true;

         Print(
            "[RAMUSEN][ERROR] ",
            "S30_BAR_TIME_READ_FAILED integrity=DEGRADED"
         );

         return false;
      }

      ulong eventTimeMsc =
         (ulong)now
         *
         1000ULL;

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
            eventTimeMsc =
               (ulong)currentTick.time_msc;
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

      double entrySpreadBps = 0.0;

      if(entryMid > 0.0)
      {
         entrySpreadBps =
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

      bool bearishCrossover =
         (
            m5Fast2 >= m5Slow2
            &&
            m5Fast1 < m5Slow1
         );

      int index =
         ArraySize(events);

      ArrayResize(
         events,
         index + 1
      );

      events[index].event_id =
         nextEventId;

      nextEventId++;

      events[index].event_time =
         now;

      events[index].event_time_msc =
         eventTimeMsc;

      events[index].completed_m5_bar_time =
         completedM5BarTime;

      events[index].completed_m15_bar_time =
         completedM15BarTime;

      events[index].bearish_crossover =
         bearishCrossover;

      events[index].entry_bid =
         market.bid;

      events[index].entry_ask =
         market.ask;

      events[index].entry_mid =
         entryMid;

      events[index].entry_spread_points =
         market.spread_points;

      events[index].entry_spread_bps =
         entrySpreadBps;

      events[index].m5_fast_bar2 =
         m5Fast2;

      events[index].m5_slow_bar2 =
         m5Slow2;

      events[index].m5_fast_bar1 =
         m5Fast1;

      events[index].m5_slow_bar1 =
         m5Slow1;

      events[index].m15_fast_bar2 =
         m15Fast2;

      events[index].m15_slow_bar2 =
         m15Slow2;

      events[index].m15_fast_bar1 =
         m15Fast1;

      events[index].m15_slow_bar1 =
         m15Slow1;

      events[index].m1_done = false;
      events[index].m3_done = false;
      events[index].m5_done = false;
      events[index].m10_done = false;
      events[index].m15_done = false;
      events[index].m30_done = false;
      events[index].m60_done = false;
      events[index].m90_done = false;

      bearishContextEvents++;

      if(bearishCrossover)
         bearishCrossoverEvents++;

      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "S30_EVENT_RECORDED id=%I64u group=%s m5_bar=%s m15_bar=%s bid=%s ask=%s",
            events[index].event_id,
            bearishCrossover
               ? "CROSSOVER_EVENT"
               : "CONTEXT_ONLY",
            TimeToString(
               completedM5BarTime,
               TIME_DATE | TIME_MINUTES
            ),
            TimeToString(
               completedM15BarTime,
               TIME_DATE | TIME_MINUTES
            ),
            DoubleToString(
               market.bid,
               _Digits
            ),
            DoubleToString(
               market.ask,
               _Digits
            )
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
            1,
            events[i].m1_done
         );

         ProcessHorizon(
            events[i],
            now,
            3,
            events[i].m3_done
         );

         ProcessHorizon(
            events[i],
            now,
            5,
            events[i].m5_done
         );

         ProcessHorizon(
            events[i],
            now,
            10,
            events[i].m10_done
         );

         ProcessHorizon(
            events[i],
            now,
            15,
            events[i].m15_done
         );

         ProcessHorizon(
            events[i],
            now,
            30,
            events[i].m30_done
         );

         ProcessHorizon(
            events[i],
            now,
            60,
            events[i].m60_done
         );

         ProcessHorizon(
            events[i],
            now,
            90,
            events[i].m90_done
         );

         if(
            IsComplete(
               events[i]
            )
         )
         {
            RemoveEvent(i);
         }
      }
   }


   void Shutdown()
   {
      int pendingEvents =
         ArraySize(events);

      if(
         ready
         &&
         csvHandle != INVALID_HANDLE
         &&
         pendingEvents > 0
      )
      {
         for(int i = 0; i < pendingEvents; i++)
         {
            if(!events[i].m1_done)
               WritePendingRow(events[i], 1);

            if(!events[i].m3_done)
               WritePendingRow(events[i], 3);

            if(!events[i].m5_done)
               WritePendingRow(events[i], 5);

            if(!events[i].m10_done)
               WritePendingRow(events[i], 10);

            if(!events[i].m15_done)
               WritePendingRow(events[i], 15);

            if(!events[i].m30_done)
               WritePendingRow(events[i], 30);

            if(!events[i].m60_done)
               WritePendingRow(events[i], 60);

            if(!events[i].m90_done)
               WritePendingRow(events[i], 90);
         }
      }

      if(ready)
      {
         Print(
            "[RAMUSEN][INFO] ",
            StringFormat(
               "S30_SUMMARY m5_bar_checks=%I64u bearish_context_events=%I64u bearish_crossovers=%I64u rows=%I64u ok=%I64u missing=%I64u pending_rows=%I64u error=%I64u pending_events=%d integrity=%s",
               m5BarChecks,
               bearishContextEvents,
               bearishCrossoverEvents,
               horizonRowsWritten,
               horizonOkRows,
               horizonMissingRows,
               horizonPendingRows,
               horizonErrorRows,
               pendingEvents,
               integrityDegraded
                  ? "DEGRADED"
                  : "OK"
            )
         );
      }

      if(csvHandle != INVALID_HANDLE)
      {
         FileFlush(csvHandle);
         FileClose(csvHandle);
         csvHandle = INVALID_HANDLE;
      }

      if(m5FastHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m5FastHandle);
         m5FastHandle = INVALID_HANDLE;
      }

      if(m5SlowHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m5SlowHandle);
         m5SlowHandle = INVALID_HANDLE;
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

      ArrayResize(
         events,
         0
      );

      ready = false;
      barClockPrimed = false;
      lastObservedCurrentBarTime = 0;
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
