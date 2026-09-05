#ifndef RAMUSEN_SCALPING_CONTROLLED_LAYER_RESEARCH_MQH
#define RAMUSEN_SCALPING_CONTROLLED_LAYER_RESEARCH_MQH

#include "Config.mqh"
#include "Types.mqh"

// =====================================================
// P2F.14A — CONTROLLED LAYER ENGINE RESEARCH
//
// PURPOSE
// -------
// Establish a deterministic, research-only pyramid
// benchmark on top of the FROZEN P2F.12 Candidate S2.
//
// No live orders are sent.
//
// Frozen base:
//   XAUUSD M5 SELL Candidate S2
//   SL = 1.25 ATR(M5,14)
//   TIME EXIT = 10 minutes
//   no base profit-retention changes
//
// Layer benchmark:
//   CONTROL = 1 layer
//   L3      = max 3 layers
//   L5      = max 5 layers
//   L7      = max 7 layers
//   L10     = max 10 layers
//
// Addition schedule is mathematical, not tuned:
//   for max N layers, additions are attempted at
//   k * (10 minutes / N), k=1..N-1.
//
// A new layer is allowed only if:
//   1) at least one prior layer is still active
//   2) no earlier layer has already stopped/protected out
//   3) ALL active layers are marked profitable at the
//      checkpoint using executable SELL exit (ASK)
//
// Before adding:
//   all existing active layers are protected at their own
//   entry price (break-even stop level).
//
// New layer:
//   SELL entry = checkpoint BID
//   hard SL distance = same frozen 1.25 * base-signal ATR
//
// This means only the newest layer carries a full,
// unprotected 1R stop. Previous active layers have
// break-even protection, while real first-touch ASK fills
// still capture gap/spread degradation.
//
// If any layer exits before the 10-minute horizon,
// the pyramid is marked BROKEN and no later layer may be
// added in that arm.
//
// IMPORTANT STATISTICAL RULE:
// One base S2 signal is ONE independent opportunity,
// regardless of how many layer tickets it creates.
// =====================================================


struct P2F14BaseEvent
{
   datetime signal_time;
   ulong signal_time_msc;
   datetime signal_bar_time;

   double entry_bid;
   double entry_ask;

   double atr_value;
   double stop_distance;

   int analyze_failures;
};


struct P2F14LayerState
{
   int layer_index;

   bool active;
   bool closed;

   ulong entry_time_msc;
   double entry_bid;

   double stop_price;
   bool protection_activated;
   ulong protection_time_msc;

   string exit_mode;
   ulong exit_time_msc;
   double exit_ask;

   double observed_r;
   double nominal_net_r_1bps;
   double stress_net_r_2bps;
};


class CScalpingControlledLayerResearch
{
private:

   int summaryHandle;
   int detailHandle;

   string summaryFileName;
   string detailFileName;

   string researchSymbol;
   ENUM_TIMEFRAMES entryTimeframe;

   bool ready;

   P2F14BaseEvent events[];

   ulong recordedCount;
   ulong completedCount;
   ulong failedCount;

   bool integrityDegraded;
   string lastAnalyzeError;


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
         const ulong tickTimeMsc =
            (ulong)ticks[i].time_msc;

         if(tickTimeMsc < targetTimeMsc)
            continue;

         if(!found || tickTimeMsc < earliest)
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
            (ulong)resultTick.time_msc -
            targetTimeMsc
         );

      status = "OK";

      return true;
   }


   void RemoveFirstEvent()
   {
      int total = ArraySize(events);

      if(total <= 0)
         return;

      for(int i = 1; i < total; i++)
         events[i - 1] = events[i];

      ArrayResize(events, total - 1);
   }


   bool AllActiveLayersProfitable(
      P2F14LayerState &layers[],
      const double currentAsk
   )
   {
      int activeCount = 0;

      for(int i = 0; i < ArraySize(layers); i++)
      {
         if(!layers[i].active)
            continue;

         activeCount++;

         // SELL layer is marked profitable only if it could
         // be closed executable at ASK below its entry BID.
         if(currentAsk >= layers[i].entry_bid)
            return false;
      }

      return activeCount > 0;
   }


   void ProtectAllActiveLayers(
      P2F14LayerState &layers[],
      const ulong protectionTimeMsc
   )
   {
      for(int i = 0; i < ArraySize(layers); i++)
      {
         if(!layers[i].active)
            continue;

         // For a SELL, a lower stop is tighter.
         if(layers[i].stop_price > layers[i].entry_bid)
            layers[i].stop_price = layers[i].entry_bid;

         if(!layers[i].protection_activated)
         {
            layers[i].protection_activated = true;
            layers[i].protection_time_msc = protectionTimeMsc;
         }
      }
   }


   void FinalizeLayer(
      P2F14LayerState &layer,
      const string exitMode,
      const ulong exitTimeMsc,
      const double exitAsk,
      const double stopDistance
   )
   {
      layer.active = false;
      layer.closed = true;

      layer.exit_mode = exitMode;
      layer.exit_time_msc = exitTimeMsc;
      layer.exit_ask = exitAsk;

      layer.observed_r =
         (
            layer.entry_bid -
            exitAsk
         )
         /
         stopDistance;

      double stopBps =
         (
            stopDistance /
            layer.entry_bid
         )
         *
         10000.0;

      if(stopBps > 0.0)
      {
         layer.nominal_net_r_1bps =
            layer.observed_r -
            (1.0 / stopBps);

         layer.stress_net_r_2bps =
            layer.observed_r -
            (2.0 / stopBps);
      }
      else
      {
         layer.nominal_net_r_1bps =
            layer.observed_r;

         layer.stress_net_r_2bps =
            layer.observed_r;
      }
   }


   void WriteLayerDetail(
      const P2F14BaseEvent &event,
      const string arm,
      const int maxLayers,
      const P2F14LayerState &layer
   )
   {
      FileWrite(
         detailHandle,

         StringFormat(
            "%I64u_SELL",
            event.signal_time_msc
         ),

         TimeToString(
            event.signal_time,
            TIME_DATE | TIME_SECONDS
         ),

         event.signal_time_msc,

         arm,
         maxLayers,

         layer.layer_index,

         layer.entry_time_msc,
         DoubleToString(layer.entry_bid, _Digits),

         layer.protection_activated ? "YES" : "NO",
         layer.protection_time_msc,

         layer.exit_mode,
         layer.exit_time_msc,
         DoubleToString(layer.exit_ask, _Digits),

         DoubleToString(layer.observed_r, 8),
         DoubleToString(layer.nominal_net_r_1bps, 8),
         DoubleToString(layer.stress_net_r_2bps, 8)
      );
   }


   bool SimulateArm(
      const P2F14BaseEvent &event,
      MqlTick &path[],
      const int copied,
      const MqlTick &targetTick,
      const int maxLayers,
      const string arm,
      double &grossTotalR,
      double &nominalTotalR,
      double &stressTotalR,
      int &layersOpened,
      int &protectedExitCount,
      int &hardStopExitCount,
      int &timeExitCount,
      int &checkpointPassCount,
      int &checkpointRejectCount,
      int &checkpointMissingCount,
      bool &pyramidBroken
   )
   {
      grossTotalR = 0.0;
      nominalTotalR = 0.0;
      stressTotalR = 0.0;

      layersOpened = 0;
      protectedExitCount = 0;
      hardStopExitCount = 0;
      timeExitCount = 0;

      checkpointPassCount = 0;
      checkpointRejectCount = 0;
      checkpointMissingCount = 0;

      pyramidBroken = false;

      if(event.stop_distance <= 0.0)
         return false;

      P2F14LayerState layers[];
      ArrayResize(layers, maxLayers);

      for(int i = 0; i < maxLayers; i++)
      {
         layers[i].layer_index = i + 1;
         layers[i].active = false;
         layers[i].closed = false;
         layers[i].entry_time_msc = 0;
         layers[i].entry_bid = 0.0;
         layers[i].stop_price = 0.0;
         layers[i].protection_activated = false;
         layers[i].protection_time_msc = 0;
         layers[i].exit_mode = "";
         layers[i].exit_time_msc = 0;
         layers[i].exit_ask = 0.0;
         layers[i].observed_r = 0.0;
         layers[i].nominal_net_r_1bps = 0.0;
         layers[i].stress_net_r_2bps = 0.0;
      }

      // Base S2 layer.
      layers[0].active = true;
      layers[0].entry_time_msc = event.signal_time_msc;
      layers[0].entry_bid = event.entry_bid;
      layers[0].stop_price =
         event.entry_bid +
         event.stop_distance;

      layersOpened = 1;

      int checkpointIndex = 1;
      int nextLayerSlot = 1;

      ulong nextCheckpointTimeMsc = 0;

      if(maxLayers > 1)
      {
         nextCheckpointTimeMsc =
            event.signal_time_msc
            +
            (
               10ULL *
               60ULL *
               1000ULL *
               (ulong)checkpointIndex
            )
            /
            (ulong)maxLayers;
      }

      const ulong targetTimeMsc =
         event.signal_time_msc
         +
         10ULL * 60ULL * 1000ULL;

      const ulong MAX_CHECKPOINT_DELAY_MSC = 30000ULL;

      for(int t = 0; t < copied; t++)
      {
         if(path[t].ask <= 0.0 || path[t].bid <= 0.0)
            continue;

         const ulong tickTimeMsc =
            (ulong)path[t].time_msc;

         // 1) Existing stops are always processed before a
         // scheduled add at the same observed tick.
         for(int i = 0; i < maxLayers; i++)
         {
            if(!layers[i].active)
               continue;

            if(path[t].ask >= layers[i].stop_price)
            {
               const bool wasProtected =
                  layers[i].protection_activated;

               FinalizeLayer(
                  layers[i],
                  wasProtected
                     ? "PROTECTED_STOP"
                     : "HARD_SL",
                  tickTimeMsc,
                  path[t].ask,
                  event.stop_distance
               );

               if(wasProtected)
                  protectedExitCount++;
               else
                  hardStopExitCount++;

               pyramidBroken = true;
            }
         }

         // 2) Scheduled additions.
         while(
            maxLayers > 1
            &&
            checkpointIndex < maxLayers
            &&
            tickTimeMsc >= nextCheckpointTimeMsc
         )
         {
            const ulong delayMsc =
               tickTimeMsc -
               nextCheckpointTimeMsc;

            if(delayMsc > MAX_CHECKPOINT_DELAY_MSC)
            {
               checkpointMissingCount++;
            }
            else if(pyramidBroken)
            {
               checkpointRejectCount++;
            }
            else if(
               !AllActiveLayersProfitable(
                  layers,
                  path[t].ask
               )
            )
            {
               checkpointRejectCount++;
            }
            else
            {
               // Protect all prior exposure before adding.
               ProtectAllActiveLayers(
                  layers,
                  tickTimeMsc
               );

               if(nextLayerSlot < maxLayers)
               {
                  layers[nextLayerSlot].active = true;
                  layers[nextLayerSlot].entry_time_msc =
                     tickTimeMsc;
                  layers[nextLayerSlot].entry_bid =
                     path[t].bid;
                  layers[nextLayerSlot].stop_price =
                     path[t].bid +
                     event.stop_distance;

                  nextLayerSlot++;
                  layersOpened++;
                  checkpointPassCount++;
               }
               else
               {
                  checkpointRejectCount++;
               }
            }

            checkpointIndex++;

            if(checkpointIndex < maxLayers)
            {
               nextCheckpointTimeMsc =
                  event.signal_time_msc
                  +
                  (
                     10ULL *
                     60ULL *
                     1000ULL *
                     (ulong)checkpointIndex
                  )
                  /
                  (ulong)maxLayers;
            }
         }

         if(tickTimeMsc >= targetTimeMsc)
            break;
      }

      // Time exit at the first executable target tick
      // near +10m, matching Candidate S2 semantics.
      for(int i = 0; i < maxLayers; i++)
      {
         if(!layers[i].active)
            continue;

         FinalizeLayer(
            layers[i],
            "TIME_EXIT",
            (ulong)targetTick.time_msc,
            targetTick.ask,
            event.stop_distance
         );

         timeExitCount++;
      }

      for(int i = 0; i < maxLayers; i++)
      {
         if(!layers[i].closed)
            continue;

         grossTotalR +=
            layers[i].observed_r;

         nominalTotalR +=
            layers[i].nominal_net_r_1bps;

         stressTotalR +=
            layers[i].stress_net_r_2bps;

         WriteLayerDetail(
            event,
            arm,
            maxLayers,
            layers[i]
         );
      }

      return true;
   }


   bool AnalyzeEvent(
      const P2F14BaseEvent &event
   )
   {
      lastAnalyzeError = "";

      const ulong targetTimeMsc =
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
            summaryHandle,

            StringFormat(
               "%I64u_SELL",
               event.signal_time_msc
            ),

            TimeToString(
               event.signal_time,
               TIME_DATE | TIME_SECONDS
            ),

            event.signal_time_msc,

            "ALL",
            0,
            targetStatus,

            DoubleToString(event.entry_bid, _Digits),
            DoubleToString(event.atr_value, _Digits),
            DoubleToString(event.stop_distance, _Digits),

            0, 0, 0, 0, 0, 0, 0,

            "", "", "",
            "", "", ""
         );

         FileFlush(summaryHandle);

         return true;
      }

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
         lastAnalyzeError = "NO_PATH_TICKS";
         return false;
      }

      const int ARM_COUNT = 5;

      // MQL5 local fixed-size arrays require a compile-time
      // literal size here. Using ARM_COUNT as the index size
      // triggers "invalid index value" in MetaEditor.
      int maxLayerArms[5];
      string armNames[5];

      maxLayerArms[0] = 1;
      maxLayerArms[1] = 3;
      maxLayerArms[2] = 5;
      maxLayerArms[3] = 7;
      maxLayerArms[4] = 10;

      armNames[0] = "CONTROL_L1";
      armNames[1] = "PYRAMID_L3";
      armNames[2] = "PYRAMID_L5";
      armNames[3] = "PYRAMID_L7";
      armNames[4] = "PYRAMID_L10";

      double controlGrossR = 0.0;
      double controlNominalR = 0.0;
      double controlStressR = 0.0;

      for(int a = 0; a < ARM_COUNT; a++)
      {
         double grossTotalR = 0.0;
         double nominalTotalR = 0.0;
         double stressTotalR = 0.0;

         int layersOpened = 0;
         int protectedExitCount = 0;
         int hardStopExitCount = 0;
         int timeExitCount = 0;

         int checkpointPassCount = 0;
         int checkpointRejectCount = 0;
         int checkpointMissingCount = 0;

         bool pyramidBroken = false;

         if(
            !SimulateArm(
               event,
               path,
               copied,
               targetTick,
               maxLayerArms[a],
               armNames[a],
               grossTotalR,
               nominalTotalR,
               stressTotalR,
               layersOpened,
               protectedExitCount,
               hardStopExitCount,
               timeExitCount,
               checkpointPassCount,
               checkpointRejectCount,
               checkpointMissingCount,
               pyramidBroken
            )
         )
         {
            lastAnalyzeError =
               StringFormat(
                  "SIMULATE_ARM_FAILED_%s",
                  armNames[a]
               );

            return false;
         }

         if(a == 0)
         {
            controlGrossR = grossTotalR;
            controlNominalR = nominalTotalR;
            controlStressR = stressTotalR;
         }

         FileWrite(
            summaryHandle,

            StringFormat(
               "%I64u_SELL",
               event.signal_time_msc
            ),

            TimeToString(
               event.signal_time,
               TIME_DATE | TIME_SECONDS
            ),

            event.signal_time_msc,

            armNames[a],
            maxLayerArms[a],

            "OK",

            DoubleToString(event.entry_bid, _Digits),
            DoubleToString(event.atr_value, _Digits),
            DoubleToString(event.stop_distance, _Digits),

            layersOpened,
            checkpointPassCount,
            checkpointRejectCount,
            checkpointMissingCount,

            protectedExitCount,
            hardStopExitCount,
            timeExitCount,

            DoubleToString(grossTotalR, 8),
            DoubleToString(nominalTotalR, 8),
            DoubleToString(stressTotalR, 8),

            DoubleToString(
               grossTotalR -
               controlGrossR,
               8
            ),

            DoubleToString(
               nominalTotalR -
               controlNominalR,
               8
            ),

            DoubleToString(
               stressTotalR -
               controlStressR,
               8
            )
         );
      }

      FileFlush(summaryHandle);
      FileFlush(detailHandle);

      return true;
   }


   void WriteTerminalStatusRow(
      const P2F14BaseEvent &event,
      const string status
   )
   {
      FileWrite(
         summaryHandle,

         StringFormat(
            "%I64u_SELL",
            event.signal_time_msc
         ),

         TimeToString(
            event.signal_time,
            TIME_DATE | TIME_SECONDS
         ),

         event.signal_time_msc,

         "ALL",
         0,
         status,

         DoubleToString(event.entry_bid, _Digits),
         DoubleToString(event.atr_value, _Digits),
         DoubleToString(event.stop_distance, _Digits),

         0, 0, 0, 0, 0, 0, 0,

         "", "", "",
         "", "", ""
      );

      FileFlush(summaryHandle);
   }


public:

   CScalpingControlledLayerResearch()
   {
      summaryHandle = INVALID_HANDLE;
      detailHandle = INVALID_HANDLE;

      summaryFileName = "";
      detailFileName = "";

      researchSymbol = "";
      entryTimeframe = PERIOD_CURRENT;

      ready = false;

      ArrayResize(events, 0);

      recordedCount = 0;
      completedCount = 0;
      failedCount = 0;

      integrityDegraded = false;
      lastAnalyzeError = "";
   }


   bool Initialize(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe
   )
   {
      Shutdown();

      researchSymbol = symbol;
      entryTimeframe = timeframe;

      ArrayResize(events, 0);

      recordedCount = 0;
      completedCount = 0;
      failedCount = 0;

      integrityDegraded = false;
      lastAnalyzeError = "";

      long sessionStamp =
         (long)TimeLocal();

      summaryFileName =
         StringFormat(
            "RamusenEA_controlled_layer_summary_%s_%s_%I64d.csv",
            researchSymbol,
            EnumToString(entryTimeframe),
            sessionStamp
         );

      detailFileName =
         StringFormat(
            "RamusenEA_controlled_layer_detail_%s_%s_%I64d.csv",
            researchSymbol,
            EnumToString(entryTimeframe),
            sessionStamp
         );

      ResetLastError();

      summaryHandle =
         FileOpen(
            summaryFileName,
            FILE_WRITE |
            FILE_CSV |
            FILE_COMMON |
            FILE_ANSI,
            ','
         );

      if(summaryHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F14_SUMMARY_CSV_OPEN_FAILED file=%s error=%d",
               summaryFileName,
               GetLastError()
            )
         );

         return false;
      }

      detailHandle =
         FileOpen(
            detailFileName,
            FILE_WRITE |
            FILE_CSV |
            FILE_COMMON |
            FILE_ANSI,
            ','
         );

      if(detailHandle == INVALID_HANDLE)
      {
         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F14_DETAIL_CSV_OPEN_FAILED file=%s error=%d",
               detailFileName,
               GetLastError()
            )
         );

         FileClose(summaryHandle);
         summaryHandle = INVALID_HANDLE;

         return false;
      }

      FileWrite(
         summaryHandle,

         "research_join_key",
         "signal_time",
         "signal_time_msc",

         "arm",
         "max_layers",
         "status",

         "base_entry_bid",
         "m5_atr",
         "stop_distance",

         "layers_opened",
         "checkpoint_pass_count",
         "checkpoint_reject_count",
         "checkpoint_missing_count",

         "protected_exit_count",
         "hard_sl_exit_count",
         "time_exit_count",

         "gross_total_r",
         "nominal_total_r_1bps",
         "stress_total_r_2bps",

         "incremental_gross_r_vs_control",
         "incremental_nominal_r_vs_control",
         "incremental_stress_r_vs_control"
      );

      FileWrite(
         detailHandle,

         "research_join_key",
         "signal_time",
         "signal_time_msc",

         "arm",
         "max_layers",

         "layer_index",

         "entry_time_msc",
         "entry_bid",

         "protection_activated",
         "protection_time_msc",

         "exit_mode",
         "exit_time_msc",
         "exit_ask",

         "observed_r",
         "nominal_net_r_1bps",
         "stress_net_r_2bps"
      );

      FileFlush(summaryHandle);
      FileFlush(detailHandle);

      ready = true;

      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F14_LAYER_RESEARCH_READY summary=%s detail=%s arms=1,3,5,7,10 horizon=10m protection=prior_layers_to_BE add_rule=all_active_profitable",
            summaryFileName,
            detailFileName
         )
      );

      return true;
   }


   bool RecordS2Eligible(
      const datetime signalTime,
      const datetime signalBarTime,
      const ulong signalTimeMsc,
      const MarketSnapshot &market,
      const double atrValue
   )
   {
      if(!ready)
         return false;

      if(signalTimeMsc == 0)
         return false;

      if(atrValue <= 0.0)
         return false;

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

      events[index].atr_value =
         atrValue;

      events[index].stop_distance =
         atrValue *
         1.25;

      events[index].analyze_failures =
         0;

      recordedCount++;

      Print(
         "[RAMUSEN][INFO] ",
         StringFormat(
            "P2F14_LAYER_RECORDED join=%I64u_SELL entry_bid=%s atr=%s stop=%s",
            signalTimeMsc,
            DoubleToString(
               market.bid,
               _Digits
            ),
            DoubleToString(
               atrValue,
               _Digits
            ),
            DoubleToString(
               events[index].stop_distance,
               _Digits
            )
         )
      );

      return true;
   }


   void Process(const datetime now)
   {
      if(!ready)
         return;

      const int MAX_ANALYZE_RETRIES = 3;

      while(ArraySize(events) > 0)
      {
         const ulong matureTimeMsc =
            events[0].signal_time_msc
            +
            10ULL * 60ULL * 1000ULL
            +
            30000ULL;

         const ulong nowTimeMsc =
            (ulong)now *
            1000ULL;

         if(nowTimeMsc < matureTimeMsc)
            break;

         if(AnalyzeEvent(events[0]))
         {
            completedCount++;
            RemoveFirstEvent();
            continue;
         }

         events[0].analyze_failures++;

         Print(
            "[RAMUSEN][WARN] ",
            StringFormat(
               "P2F14_ANALYZE_RETRY join=%I64u_SELL attempt=%d/%d reason=%s",
               events[0].signal_time_msc,
               events[0].analyze_failures,
               MAX_ANALYZE_RETRIES,
               lastAnalyzeError
            )
         );

         if(
            events[0].analyze_failures <
            MAX_ANALYZE_RETRIES
         )
         {
            break;
         }

         integrityDegraded = true;
         failedCount++;

         string terminalStatus =
            StringFormat(
               "ANALYZE_FAILED_%s",
               lastAnalyzeError
            );

         WriteTerminalStatusRow(
            events[0],
            terminalStatus
         );

         Print(
            "[RAMUSEN][ERROR] ",
            StringFormat(
               "P2F14_ANALYZE_QUARANTINED join=%I64u_SELL failures=%d reason=%s integrity=DEGRADED",
               events[0].signal_time_msc,
               events[0].analyze_failures,
               lastAnalyzeError
            )
         );

         RemoveFirstEvent();
      }
   }


   void Shutdown()
   {
      const int pending =
         ArraySize(events);

      if(
         ready
         &&
         summaryHandle != INVALID_HANDLE
         &&
         pending > 0
      )
      {
         for(int i = 0; i < pending; i++)
         {
            WriteTerminalStatusRow(
               events[i],
               "PENDING_AT_SHUTDOWN"
            );

            Print(
               "[RAMUSEN][WARN] ",
               StringFormat(
                  "P2F14_PENDING_AT_SHUTDOWN join=%I64u_SELL signal=%s mature_msc=%I64u",
                  events[i].signal_time_msc,
                  TimeToString(
                     events[i].signal_time,
                     TIME_DATE | TIME_SECONDS
                  ),
                  events[i].signal_time_msc
                  +
                  10ULL * 60ULL * 1000ULL
                  +
                  30000ULL
               )
            );
         }
      }

      if(ready)
      {
         Print(
            "[RAMUSEN][INFO] ",
            StringFormat(
               "P2F14_LAYER_SUMMARY recorded=%I64u completed=%I64u failed=%I64u pending=%d integrity=%s",
               recordedCount,
               completedCount,
               failedCount,
               pending,
               integrityDegraded
                  ? "DEGRADED"
                  : "OK"
            )
         );
      }

      if(summaryHandle != INVALID_HANDLE)
      {
         FileFlush(summaryHandle);
         FileClose(summaryHandle);
         summaryHandle = INVALID_HANDLE;
      }

      if(detailHandle != INVALID_HANDLE)
      {
         FileFlush(detailHandle);
         FileClose(detailHandle);
         detailHandle = INVALID_HANDLE;
      }

      ArrayResize(events, 0);

      ready = false;
   }


   string SummaryCsvFileName()
   {
      return summaryFileName;
   }


   string DetailCsvFileName()
   {
      return detailFileName;
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
