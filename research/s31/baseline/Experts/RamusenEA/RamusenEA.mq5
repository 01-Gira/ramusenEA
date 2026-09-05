//+------------------------------------------------------------------+
//|                                                     RamusenEA.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ramusen EA"
#property version   "1.000"
#property strict

#include <RamusenEA/Config.mqh>
#include <RamusenEA/Types.mqh>
#include <RamusenEA/Market.mqh>
#include <RamusenEA/RiskManager.mqh>
#include <RamusenEA/Execution.mqh>
#include <RamusenEA/PositionManager.mqh>
#include <RamusenEA/TradeJournal.mqh>
#include <RamusenEA/SignalEngine.mqh>
#include <RamusenEA/SignalResearch.mqh>
#include <RamusenEA/ScalpingContext.mqh>
#include <RamusenEA/ScalpingEntryGate.mqh>
#include <RamusenEA/ScalpingExcursionResearch.mqh>
#include <RamusenEA/ScalpingTimeExitResearch.mqh>
#include <RamusenEA/ScalpingProfitRetentionResearch.mqh>
#include <RamusenEA/ScalpingAdaptiveProfitRetentionResearch.mqh>
#include <RamusenEA/ScalpingCandidateS2Research.mqh>
#include <RamusenEA/ScalpingControlledLayerResearch.mqh>
#include <RamusenEA/S30EventGeneratorControlResearch.mqh>

CMarket          Market;
CRiskManager     RiskManager;
CExecution       Execution;
CPositionManager PositionManager;
CTradeJournal    Journal;
CSignalEngine    SignalEngine;
CSignalResearch  SignalResearch;
CScalpingContext ScalpingContext;
CScalpingEntryGate ScalpingEntryGate;
CScalpingExcursionResearch ScalpingExcursionResearch;
CScalpingTimeExitResearch ScalpingTimeExitResearch;
CScalpingProfitRetentionResearch ScalpingProfitRetentionResearch;
CScalpingAdaptiveProfitRetentionResearch ScalpingAdaptiveProfitRetentionResearch;
CScalpingCandidateS2Research ScalpingCandidateS2Research;
CScalpingControlledLayerResearch ScalpingControlledLayerResearch;
CS30EventGeneratorControlResearch S30EventGeneratorControlResearch;

int OnInit()
{
   Journal.Info(
      StringFormat(
         "EA_INITIALIZED symbol=%s timeframe=%s trading=%s",
         _Symbol,
         EnumToString(_Period),
         InpEnableTrading ? "ENABLED" : "DISABLED"
      )
   );
   
   if(InpExecutionTest && InpBaselineStrategyEnabled)
   {
      Journal.Error(
         "CONFIG_CONFLICT execution_test_and_baseline_strategy_both_enabled"
      );
   
      return INIT_FAILED;
   }
   
   if(!SignalEngine.Initialize(
      _Symbol,
      (ENUM_TIMEFRAMES)_Period
   ))
   {
      Journal.Error(
         StringFormat(
            "SIGNAL_ENGINE_INIT_FAILED symbol=%s timeframe=%s fast=%d slow=%d",
            _Symbol,
            EnumToString(_Period),
            InpFastMAPeriod,
            InpSlowMAPeriod
         )
      );
   
      return INIT_FAILED;
   }
   
   Journal.Info(
      StringFormat(
         "SIGNAL_ENGINE_READY symbol=%s timeframe=%s fast_ema=%d slow_ema=%d",
         _Symbol,
         EnumToString(_Period),
         InpFastMAPeriod,
         InpSlowMAPeriod
      )
   );
   
   // =====================================================
   // PHASE 1.4 — TRADE JOURNAL CSV
   // =====================================================
   
   if(!Journal.InitializeCsv(
      _Symbol,
      (ENUM_TIMEFRAMES)_Period,
      InpMagicNumber
   ))
   {
      Journal.Error(
         "TRADE_CSV_INIT_FAILED"
      );
   
      return INIT_FAILED;
   }
   
   
   Journal.Info(
      StringFormat(
         "TRADE_CSV_READY file=%s directory=%s",
         Journal.CsvFileName(),
         Journal.CsvDirectory()
      )
   );
   
   // =====================================================
   // PHASE 2.2 — SIGNAL FORWARD RETURN RESEARCH
   // =====================================================
   
   if(InpSignalResearchEnabled)
   {
      if(
         !SignalResearch.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period,
            InpMagicNumber
         )
      )
      {
         Journal.Error(
            "SIGNAL_RESEARCH_INIT_FAILED"
         );
   
         return INIT_FAILED;
      }
   
   
      Journal.Info(
         StringFormat(
            "SIGNAL_RESEARCH_ENABLED file=%s directory=%s",
            SignalResearch.CsvFileName(),
            SignalResearch.CsvDirectory()
         )
      );
   }
   
   // =====================================================
   // P2F.3 — SCALPING CONTEXT RESEARCH
   // =====================================================
   
   if(InpScalpingContextResearchEnabled)
   {
      if(
         !ScalpingContext.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error(
            "SCALPING_CONTEXT_INIT_FAILED"
         );
   
         return INIT_FAILED;
      }
   
   
      Journal.Info(
         StringFormat(
            "SCALPING_CONTEXT_ENABLED file=%s directory=%s",
            ScalpingContext.CsvFileName(),
            ScalpingContext.CsvDirectory()
         )
      );
   }
   
   // =====================================================
   // P2F.4 — ENTRY QUALITY GATE
   // =====================================================
   
   if(InpP2F4EntryGateResearchEnabled)
   {
      if(
         !ScalpingEntryGate.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error(
            "P2F4_ENTRY_GATE_INIT_FAILED"
         );
   
         return INIT_FAILED;
      }
   
   
      Journal.Info(
         StringFormat(
            "P2F4_ENTRY_GATE_ENABLED file=%s directory=%s",
            ScalpingEntryGate.CsvFileName(),
            ScalpingEntryGate.CsvDirectory()
         )
      );
   }

   // =====================================================
   // P2F.12 — CANDIDATE S2 RESEARCH
   // =====================================================
   

   if(InpP2F12CandidateS2ResearchEnabled)
   {
      if(!InpP2F4EntryGateResearchEnabled)
      {
         Journal.Error("P2F12_REQUIRES_P2F4_ENTRY_GATE");
         return INIT_FAILED;
      }

      if(
         !ScalpingCandidateS2Research.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error("P2F12_S2_INIT_FAILED");
         return INIT_FAILED;
      }
   }

   // =====================================================
   // P2F.14A — CONTROLLED LAYER RESEARCH
   // =====================================================

   if(InpP2F14ControlledLayerResearchEnabled)
   {
      if(!InpP2F12CandidateS2ResearchEnabled)
      {
         Journal.Error(
            "P2F14_REQUIRES_P2F12_CANDIDATE_S2"
         );

         return INIT_FAILED;
      }

      if(
         !ScalpingControlledLayerResearch.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error(
            "P2F14_LAYER_RESEARCH_INIT_FAILED"
         );

         return INIT_FAILED;
      }

      Journal.Info(
         StringFormat(
            "P2F14_LAYER_RESEARCH_ENABLED summary=%s detail=%s directory=%s",
            ScalpingControlledLayerResearch.SummaryCsvFileName(),
            ScalpingControlledLayerResearch.DetailCsvFileName(),
            ScalpingControlledLayerResearch.CsvDirectory()
         )
      );
   }

   // =====================================================
   // S3.0 — EVENT GENERATOR CONTROL
   // =====================================================

   if(InpS30EventGeneratorControlResearchEnabled)
   {
      if(InpEnableTrading)
      {
         Journal.Error(
            "S30_RESEARCH_REQUIRES_TRADING_DISABLED"
         );

         return INIT_FAILED;
      }

      if(
         !S30EventGeneratorControlResearch.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error(
            "S30_EVENT_CONTROL_INIT_FAILED"
         );

         return INIT_FAILED;
      }

      Journal.Info(
         StringFormat(
            "S30_EVENT_CONTROL_ENABLED file=%s directory=%s",
            S30EventGeneratorControlResearch.CsvFileName(),
            S30EventGeneratorControlResearch.CsvDirectory()
         )
      );
   }

   // =====================================================
   // P2F.11C — ENTRY QUALITY GATE
   // =====================================================
   

   if(InpP2F11CAdaptiveRetentionResearchEnabled)
   {
      if(!InpP2F4EntryGateResearchEnabled)
      {
         Journal.Error(
            "P2F11C_REQUIRES_P2F4_ENTRY_GATE"
         );

         return INIT_FAILED;
      }

      if(
         !ScalpingAdaptiveProfitRetentionResearch.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error(
            "P2F11C_RETENTION_INIT_FAILED"
         );

         return INIT_FAILED;
      }

      Journal.Info(
         StringFormat(
            "P2F11C_RETENTION_ENABLED file=%s directory=%s",
            ScalpingAdaptiveProfitRetentionResearch.CsvFileName(),
            ScalpingAdaptiveProfitRetentionResearch.CsvDirectory()
         )
      );
   }

   
   // =====================================================
   // P2F.5A — EXCURSION RESEARCH
   // =====================================================
   
   if(InpP2F5ExcursionResearchEnabled)
   {
      if(!InpP2F4EntryGateResearchEnabled)
      {
         Journal.Error(
            "P2F5_REQUIRES_P2F4_ENTRY_GATE"
         );
   
         return INIT_FAILED;
      }
   
   
      if(
         !ScalpingExcursionResearch.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error(
            "P2F5_EXCURSION_INIT_FAILED"
         );
   
         return INIT_FAILED;
      }
   
   
      Journal.Info(
         StringFormat(
            "P2F5_EXCURSION_ENABLED file=%s",
            ScalpingExcursionResearch.CsvFileName()
         )
      );
   }
   
   // =====================================================
   // P2F.6
   // =====================================================
   
   if(InpP2F6TimeExitResearchEnabled)
   {
      if(!InpP2F4EntryGateResearchEnabled)
      {
         Journal.Error(
            "P2F6_REQUIRES_P2F4_ENTRY_GATE"
         );
   
         return INIT_FAILED;
      }
   
      if(
         !ScalpingTimeExitResearch.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error(
            "P2F6_TIME_EXIT_INIT_FAILED"
         );
   
         return INIT_FAILED;
      }
   
      Journal.Info(
         StringFormat(
            "P2F6_TIME_EXIT_ENABLED file=%s directory=%s",
            ScalpingTimeExitResearch.CsvFileName(),
            ScalpingTimeExitResearch.CsvDirectory()
         )
      );
   }
   
   // =====================================================
   // P2F.7
   // =====================================================
   

   if(InpP2F7ProfitRetentionResearchEnabled)
   {
      if(!InpP2F4EntryGateResearchEnabled)
      {
         Journal.Error(
            "P2F7_REQUIRES_P2F4_ENTRY_GATE"
         );
   
         return INIT_FAILED;
      }
   
      if(
         !ScalpingProfitRetentionResearch.Initialize(
            _Symbol,
            (ENUM_TIMEFRAMES)_Period
         )
      )
      {
         Journal.Error(
            "P2F7_RETENTION_INIT_FAILED"
         );
   
         return INIT_FAILED;
      }
   
      Journal.Info(
         StringFormat(
            "P2F7_RETENTION_ENABLED file=%s directory=%s",
            ScalpingProfitRetentionResearch.CsvFileName(),
            ScalpingProfitRetentionResearch.CsvDirectory()
         )
      );
   }

   // ------------------------------------------------------
   // PHASE 0.4 — STARTUP RECOVERY CHECK
   // ------------------------------------------------------

   int ownPositions =
      RiskManager.CountOwnPositions(
         _Symbol,
         InpMagicNumber
      );


   // Tidak ada posisi lama.
   if(ownPositions == 0)
   {
      Journal.Info(
         StringFormat(
            "RECOVERY_CHECK symbol=%s magic=%I64u own_positions=0 state=CLEAN",
            _Symbol,
            InpMagicNumber
         )
      );

      return INIT_SUCCEEDED;
   }


   // Ada lebih banyak posisi daripada yang diizinkan.
   if(ownPositions > InpMaxPositions)
   {
      Journal.Error(
         StringFormat(
            "RECOVERY_CHECK symbol=%s magic=%I64u own_positions=%d max_positions=%d state=CONFLICT",
            _Symbol,
            InpMagicNumber,
            ownPositions,
            InpMaxPositions
         )
      );

      // Jangan membuka trade baru.
      // CanTrade() juga akan memblokir karena limit posisi tercapai.

      return INIT_SUCCEEDED;
   }


   PositionSnapshot position;

   if(!PositionManager.GetOwnPosition(
      _Symbol,
      InpMagicNumber,
      position
   ))
   {
      Journal.Error(
         StringFormat(
            "RECOVERY_CHECK symbol=%s magic=%I64u own_positions=%d state=SNAPSHOT_FAILED",
            _Symbol,
            InpMagicNumber,
            ownPositions
         )
      );

      return INIT_SUCCEEDED;
   }


   string protectionState =
      position.sl > 0.0
      ? "PROTECTED"
      : "UNPROTECTED";


   Journal.Info(
      StringFormat(
         "RECOVERY_CHECK symbol=%s magic=%I64u own_positions=%d state=RECOVERED",
         _Symbol,
         InpMagicNumber,
         ownPositions
      )
   );


   Journal.Info(
      StringFormat(
         "RECOVERY_POSITION ticket=%I64u side=%s volume=%.4f open=%s sl=%s tp=%s protection=%s",
         position.ticket,
         position.type == POSITION_TYPE_BUY ? "BUY" : "SELL",
         position.volume,
         DoubleToString(position.price_open, _Digits),
         DoubleToString(position.sl, _Digits),
         DoubleToString(position.tp, _Digits),
         protectionState
      )
   );


   if(position.sl <= 0.0)
   {
      Journal.Error(
         StringFormat(
            "RECOVERY_UNPROTECTED ticket=%I64u reason=MISSING_STOP_LOSS",
            position.ticket
         )
      );
   }


   return INIT_SUCCEEDED;
}


void OnDeinit(const int reason)
{
   ScalpingProfitRetentionResearch.Shutdown();

   ScalpingTimeExitResearch.Shutdown();
   
   ScalpingExcursionResearch.Shutdown();
   
   SignalEngine.Shutdown();
   
   SignalResearch.Shutdown();
   
   ScalpingContext.Shutdown();

   ScalpingAdaptiveProfitRetentionResearch.Shutdown();
   
   ScalpingControlledLayerResearch.Shutdown();

   S30EventGeneratorControlResearch.Shutdown();

   ScalpingCandidateS2Research.Shutdown();

   ScalpingEntryGate.Shutdown();

   Journal.Info(
      StringFormat(
         "EA_STOPPED reason=%d",
         reason
      )
   );
   
   Journal.ShutdownCsv();
}

void OnTick()
{
   MarketSnapshot market;

   if(!Market.Snapshot(_Symbol, market))
   {
      Journal.Error("MARKET_SNAPSHOT_FAILED");
      return;
   }
   
   
   // =====================================================
   // P2F.5A — PROCESS PENDING EXCURSION
   //
   // Harus SEBELUM new-bar return.
   // =====================================================

   if(InpP2F5ExcursionResearchEnabled)
   {
      ScalpingExcursionResearch.Process(
         TimeCurrent()
      );
   }
   
   if(InpP2F6TimeExitResearchEnabled)
   {
      ScalpingTimeExitResearch.Process(
         TimeCurrent()
      );
   }
   
   if(InpP2F7ProfitRetentionResearchEnabled)
   {
      ScalpingProfitRetentionResearch.Process(
         TimeCurrent()
      );
   }

   if(InpP2F11CAdaptiveRetentionResearchEnabled)
   {
      ScalpingAdaptiveProfitRetentionResearch.Process(
         TimeCurrent()
      );
   }

   if(InpP2F12CandidateS2ResearchEnabled)
   {
      ScalpingCandidateS2Research.Process(
         TimeCurrent()
      );
   }


   if(InpP2F14ControlledLayerResearchEnabled)
   {
      ScalpingControlledLayerResearch.Process(
         TimeCurrent()
      );
   }



   if(InpS30EventGeneratorControlResearchEnabled)
   {
      S30EventGeneratorControlResearch.Process(
         TimeCurrent()
      );
   }



   // Hanya log sekali setiap candle baru,
   // supaya Journal tidak berisi jutaan baris.
   static datetime lastBarTime = 0;

   datetime currentBarTime = iTime(
      _Symbol,
      _Period,
      0
   );

   if(currentBarTime == lastBarTime)
      return;

   lastBarTime = currentBarTime;

   if(InpS30EventGeneratorControlResearchEnabled)
   {
      if(
         !S30EventGeneratorControlResearch.RecordCurrentBar(
            TimeCurrent(),
            currentBarTime,
            market
         )
      )
      {
         Journal.Error(
            "S30_EVENT_CONTROL_RECORD_FAILED"
         );
      }
   }

   int ownPositions =
      RiskManager.CountOwnPositions(
         _Symbol,
         InpMagicNumber
      );

   bool spreadAllowed =
      RiskManager.SpreadAllowed(market);

   bool canTrade =
      RiskManager.CanTrade(
         _Symbol,
         market
      );

   Journal.Info(
      StringFormat(
         "SAFETY_CHECK symbol=%s bid=%s ask=%s spread=%.1f spread_allowed=%s own_positions=%d trading_enabled=%s can_trade=%s",
         _Symbol,
         DoubleToString(market.bid, _Digits),
         DoubleToString(market.ask, _Digits),
         market.spread_points,
         spreadAllowed ? "YES" : "NO",
         ownPositions,
         InpEnableTrading ? "YES" : "NO",
         canTrade ? "YES" : "NO"
      )
   );
   
   double buyEntry =
      market.ask;
   
   double buyStop =
      buyEntry
      - (InpStopLossPoints * market.point);
   
   double buyVolume =
      RiskManager.CalculateVolume(
         _Symbol,
         ORDER_TYPE_BUY,
         buyEntry,
         buyStop
      );
   
   
   double sellEntry =
      market.bid;
   
   double sellStop =
      sellEntry
      + (InpStopLossPoints * market.point);
   
   double sellVolume =
      RiskManager.CalculateVolume(
         _Symbol,
         ORDER_TYPE_SELL,
         sellEntry,
         sellStop
      );
   
   
   Journal.Info(
      StringFormat(
         "RISK_SIZE balance=%.2f risk_pct=%.2f sl_points=%d buy_volume=%.4f sell_volume=%.4f",
         AccountInfoDouble(ACCOUNT_BALANCE),
         InpRiskPercent,
         InpStopLossPoints,
         buyVolume,
         sellVolume
      )
   );
   
   ENUM_RAMUSEN_SIGNAL baselineSignal =
      RAMUSEN_SIGNAL_NONE;
   
   double fastBar2 = 0.0;
   double slowBar2 = 0.0;
   
   double fastBar1 = 0.0;
   double slowBar1 = 0.0;
   
   bool signalReady =
      SignalEngine.GetSignal(
         baselineSignal,
         fastBar2,
         slowBar2,
         fastBar1,
         slowBar1
      );
   
   if(!signalReady)
   {
      Journal.Warning(
         "BASELINE_SIGNAL_NOT_READY"
      );
   }
   else
   {
      string signalText = "NONE";
   
      if(baselineSignal == RAMUSEN_SIGNAL_BUY)
         signalText = "BUY";
   
      if(baselineSignal == RAMUSEN_SIGNAL_SELL)
         signalText = "SELL";
   
      Journal.Info(
         StringFormat(
            "BASELINE_SIGNAL symbol=%s timeframe=%s fast_bar2=%.8f slow_bar2=%.8f fast_bar1=%.8f slow_bar1=%.8f signal=%s",
            _Symbol,
            EnumToString(_Period),
            fastBar2,
            slowBar2,
            fastBar1,
            slowBar1,
            signalText
         )
      );
   }
   
   // =====================================================
   // PHASE 2.2 — PROCESS EXISTING RESEARCH SIGNALS
   // =====================================================
   
   if(InpSignalResearchEnabled)
   {
      SignalResearch.Process(
         TimeCurrent()
      );
   }
   
   
   // =====================================================
   // PHASE 2.2 — RECORD NEW CROSSOVER
   // =====================================================
   
   if(
      InpSignalResearchEnabled
      &&
      signalReady
      &&
      (
         baselineSignal == RAMUSEN_SIGNAL_BUY
         ||
         baselineSignal == RAMUSEN_SIGNAL_SELL
      )
   )
   {
      if(
         !SignalResearch.RecordSignal(
            TimeCurrent(),
            currentBarTime,
   
            baselineSignal,
   
            market,
   
            fastBar2,
            slowBar2,
   
            fastBar1,
            slowBar1
         )
      )
      {
         Journal.Error(
            "SIGNAL_RESEARCH_RECORD_FAILED"
         );
      }
   }
   
   // =====================================================
   // P2F.3 — RECORD SCALPING CONTEXT
   // =====================================================
   
   if(
      InpScalpingContextResearchEnabled
      &&
      signalReady
      &&
      (
         baselineSignal == RAMUSEN_SIGNAL_BUY
         ||
         baselineSignal == RAMUSEN_SIGNAL_SELL
      )
   )
   {
      if(
         !ScalpingContext.CaptureAndWrite(
            TimeCurrent(),
   
            currentBarTime,
   
            baselineSignal,
   
            market,
   
            fastBar2,
            slowBar2,
   
            fastBar1,
            slowBar1
         )
      )
      {
         Journal.Error(
            "SCALPING_CONTEXT_RECORD_FAILED"
         );
      }
   }
   
   
   // =====================================================
   // P2F.4 — ENTRY QUALITY GATE S1
   // =====================================================
   
   bool p2f4Eligible =
      false;
   
   
   if(
      InpP2F4EntryGateResearchEnabled
      &&
      signalReady
      &&
      (
         baselineSignal == RAMUSEN_SIGNAL_BUY
         ||
         baselineSignal == RAMUSEN_SIGNAL_SELL
      )
   )
   {
      if(
         !ScalpingEntryGate.EvaluateAndWrite(
            TimeCurrent(),
   
            currentBarTime,
   
            baselineSignal,
   
            market,
   
            p2f4Eligible
         )
      )
      {
         Journal.Error(
            "P2F4_ENTRY_GATE_EVALUATION_FAILED"
         );
      }
   }

   // =====================================================
   // P2F.11 — CANDIDATE S2
   // =====================================================
   

   bool p2f12S2Eligible =
      false;

   ulong p2f12SignalTimeMsc =
      0;

   double p2f12AtrValue =
      0.0;

   if(
      InpP2F12CandidateS2ResearchEnabled
      &&
      p2f4Eligible
   )
   {
      if(
         !ScalpingCandidateS2Research.RecordEligibleS1(
            TimeCurrent(),
            currentBarTime,
            baselineSignal,
            market,
            p2f12S2Eligible,
            p2f12SignalTimeMsc,
            p2f12AtrValue
         )
      )
      {
         Journal.Error(
            "P2F12_S2_RECORD_FAILED"
         );
      }
      else if(
         InpP2F14ControlledLayerResearchEnabled
         &&
         p2f12S2Eligible
      )
      {
         if(
            !ScalpingControlledLayerResearch.RecordS2Eligible(
               TimeCurrent(),
               currentBarTime,
               p2f12SignalTimeMsc,
               market,
               p2f12AtrValue
            )
         )
         {
            Journal.Error(
               "P2F14_LAYER_RECORD_FAILED"
            );
         }
      }
   }
   
   if(
      InpP2F11CAdaptiveRetentionResearchEnabled
      &&
      p2f4Eligible
   )
   {
      if(
         !ScalpingAdaptiveProfitRetentionResearch.RecordEligible(
            TimeCurrent(),
            currentBarTime,
            baselineSignal,
            market
         )
      )
      {
         Journal.Error(
            "P2F11C_RETENTION_RECORD_FAILED"
         );
      }
   }

   
   // =====================================================
   // P2F.5A — RECORD ELIGIBLE S1
   // =====================================================
   
   if(
      InpP2F5ExcursionResearchEnabled
      &&
      p2f4Eligible
   )
   {
      if(
         !ScalpingExcursionResearch.RecordEligible(
            TimeCurrent(),
   
            currentBarTime,
   
            baselineSignal,
   
            market
         )
      )
      {
         Journal.Error(
            "P2F5_EXCURSION_RECORD_FAILED"
         );
      }
   }
   
   if(
      InpP2F6TimeExitResearchEnabled
      &&
      p2f4Eligible
   )
   {
      if(
         !ScalpingTimeExitResearch.RecordEligible(
            TimeCurrent(),
            currentBarTime,
            baselineSignal,
            market
         )
      )
      {
         Journal.Error(
            "P2F6_TIME_EXIT_RECORD_FAILED"
         );
      }
   }
   
   if(
      InpP2F7ProfitRetentionResearchEnabled
      &&
      p2f4Eligible
   )
   {
      if(
         !ScalpingProfitRetentionResearch.RecordEligible(
            TimeCurrent(),
            currentBarTime,
            baselineSignal,
            market
         )
      )
      {
         Journal.Error(
            "P2F7_RETENTION_RECORD_FAILED"
         );
      }
   }


   

   // =====================================================
   // PHASE 1.3 — BASELINE OPPOSITE SIGNAL EXIT
   // =====================================================
   
   PositionSnapshot ownPosition;
   
   bool hasOwnPosition =
      PositionManager.GetOwnPosition(
         _Symbol,
         InpMagicNumber,
         ownPosition
      );
   
   if(
      InpBaselineStrategyEnabled &&
      hasOwnPosition &&
      signalReady
   )
   {
      bool shouldClose = false;
   
      string exitSignal = "NONE";
   
      if(
         ownPosition.type == POSITION_TYPE_BUY &&
         baselineSignal == RAMUSEN_SIGNAL_SELL
      )
      {
         shouldClose = true;
         exitSignal = "SELL";
      }
   
      if(
         ownPosition.type == POSITION_TYPE_SELL &&
         baselineSignal == RAMUSEN_SIGNAL_BUY
      )
      {
         shouldClose = true;
         exitSignal = "BUY";
      }
   
      if(shouldClose)
      {
         Journal.Info(
            StringFormat(
               "BASELINE_EXIT_ATTEMPT ticket=%I64u position=%s opposite_signal=%s",
               ownPosition.ticket,
               ownPosition.type == POSITION_TYPE_BUY
                  ? "BUY"
                  : "SELL",
               exitSignal
            )
         );
         
         // =====================================================
         // P1.4B — SAVE STRATEGY CONTEXT BEFORE EXIT
         // =====================================================
         
         Journal.PrepareExitContext(
            TimeCurrent(),
            baselineSignal,
            market,
         
            fastBar2,
            slowBar2,
            fastBar1,
            slowBar1,
         
            ownPosition.sl,
            ownPosition.tp,
         
            "OPPOSITE_SIGNAL"
         );

   
         bool closed =
            Execution.ClosePosition(
               ownPosition.ticket
            );
   
         if(closed)
         {
            Journal.Info(
               StringFormat(
                  "BASELINE_POSITION_CLOSED ticket=%I64u reason=OPPOSITE_SIGNAL retcode=%u description=%s",
                  ownPosition.ticket,
                  Execution.LastRetcode(),
                  Execution.LastRetcodeDescription()
               )
            );
         }
         else
         {
            Journal.ClearPendingContext();
         
            Journal.Error(
               StringFormat(
                  "BASELINE_EXIT_FAILED ticket=%I64u retcode=%u description=%s",
                  ownPosition.ticket,
                  Execution.LastRetcode(),
                  Execution.LastRetcodeDescription()
               )
            );
         }
   
         // Jangan reverse pada candle yang sama.
         return;
      }
   }
   
   // =====================================================
   // PHASE 1.2 — BASELINE ENTRY ENGINE
   // =====================================================
   
   if(InpBaselineStrategyEnabled)
   {
      if(!signalReady)
      {
         Journal.Warning(
            "BASELINE_ENTRY_BLOCKED reason=SIGNAL_NOT_READY"
         );
         return;
      }
   
      if(baselineSignal == RAMUSEN_SIGNAL_NONE)
         return;
   
      if(!canTrade)
      {
         Journal.Warning(
            StringFormat(
               "BASELINE_ENTRY_BLOCKED reason=RISK_MANAGER signal=%s",
               baselineSignal == RAMUSEN_SIGNAL_BUY
                  ? "BUY"
                  : "SELL"
            )
         );
   
         return;
      }
   
      if(
         baselineSignal == RAMUSEN_SIGNAL_BUY &&
         !InpAllowLong
      )
      {
         Journal.Warning(
            "BASELINE_ENTRY_BLOCKED reason=LONG_DISABLED"
         );
         return;
      }
   
      if(
         baselineSignal == RAMUSEN_SIGNAL_SELL &&
         !InpAllowShort
      )
      {
         Journal.Warning(
            "BASELINE_ENTRY_BLOCKED reason=SHORT_DISABLED"
         );
         return;
      }
   
      if(baselineSignal == RAMUSEN_SIGNAL_BUY)
      {
         if(buyVolume <= 0.0)
         {
            Journal.Error(
               "BASELINE_ENTRY_FAILED reason=INVALID_BUY_VOLUME"
            );
            return;
         }
   
         double sl =
            buyEntry -
            (InpStopLossPoints * market.point);
   
         double tp =
            buyEntry +
            (InpTakeProfitPoints * market.point);
   
         sl = NormalizeDouble(sl, _Digits);
         tp = NormalizeDouble(tp, _Digits);
   
         Journal.Info(
            StringFormat(
               "BASELINE_ENTRY_ATTEMPT side=BUY volume=%.4f entry=%s sl=%s tp=%s",
               buyVolume,
               DoubleToString(buyEntry, _Digits),
               DoubleToString(sl, _Digits),
               DoubleToString(tp, _Digits)
            )
         );
         
         
         // =====================================================
         // P1.4B — SAVE STRATEGY CONTEXT BEFORE BUY
         // =====================================================
         
         Journal.PrepareEntryContext(
            TimeCurrent(),
            baselineSignal,
            market,
         
            fastBar2,
            slowBar2,
            fastBar1,
            slowBar1,
         
            sl,
            tp
         );

   
         bool success =
            Execution.Buy(
               _Symbol,
               buyVolume,
               sl,
               tp
            );
   
         if(success)
         {
            Journal.Info(
               StringFormat(
                  "BASELINE_ORDER_OPENED side=BUY volume=%.4f retcode=%u description=%s",
                  buyVolume,
                  Execution.LastRetcode(),
                  Execution.LastRetcodeDescription()
               )
            );
         }
         else
         {
            Journal.ClearPendingContext();
            Journal.Error(
               StringFormat(
                  "BASELINE_ORDER_FAILED side=BUY retcode=%u description=%s",
                  Execution.LastRetcode(),
                  Execution.LastRetcodeDescription()
               )
            );
         }
   
         return;
      }
   
      if(baselineSignal == RAMUSEN_SIGNAL_SELL)
      {
         if(sellVolume <= 0.0)
         {
            Journal.Error(
               "BASELINE_ENTRY_FAILED reason=INVALID_SELL_VOLUME"
            );
            return;
         }
   
         double sl =
            sellEntry +
            (InpStopLossPoints * market.point);
   
         double tp =
            sellEntry -
            (InpTakeProfitPoints * market.point);
   
         sl = NormalizeDouble(sl, _Digits);
         tp = NormalizeDouble(tp, _Digits);
   
         Journal.Info(
            StringFormat(
               "BASELINE_ENTRY_ATTEMPT side=SELL volume=%.4f entry=%s sl=%s tp=%s",
               sellVolume,
               DoubleToString(sellEntry, _Digits),
               DoubleToString(sl, _Digits),
               DoubleToString(tp, _Digits)
            )
         );
         
         // =====================================================
         // P1.4B — SAVE STRATEGY CONTEXT BEFORE SELL
         // =====================================================
         
         Journal.PrepareEntryContext(
            TimeCurrent(),
            baselineSignal,
            market,
         
            fastBar2,
            slowBar2,
            fastBar1,
            slowBar1,
         
            sl,
            tp
         );
   
         bool success =
            Execution.Sell(
               _Symbol,
               sellVolume,
               sl,
               tp
            );
   
         if(success)
         {
            Journal.Info(
               StringFormat(
                  "BASELINE_ORDER_OPENED side=SELL volume=%.4f retcode=%u description=%s",
                  sellVolume,
                  Execution.LastRetcode(),
                  Execution.LastRetcodeDescription()
               )
            );
         }
         else
         {
            Journal.ClearPendingContext();
            Journal.Error(
               StringFormat(
                  "BASELINE_ORDER_FAILED side=SELL retcode=%u description=%s",
                  Execution.LastRetcode(),
                  Execution.LastRetcodeDescription()
               )
            );
         }
   
         return;
      }
   }
   
   

   // ---------------------------------------------------------
   // PHASE 0.3 — EXECUTION SELF TEST
   // ---------------------------------------------------------
   
   static bool executionTestAttempted = false;
   
   // Tidak sedang melakukan execution test.
   if(!InpExecutionTest)
      return;
   
   // Pastikan hanya SATU kali mencoba order selama test.
   if(executionTestAttempted)
      return;
   
   // Safety layer tetap wajib mengizinkan trade.
   if(!canTrade)
   {
      Journal.Warning(
         "EXECUTION_TEST_BLOCKED reason=RISK_MANAGER"
      );
      return;
   }
   
   executionTestAttempted = true;
   
   
   // ---------------------------------------------------------
   // BUY TEST
   // ---------------------------------------------------------
   
   if(InpExecutionTestBuy)
   {
      if(!InpAllowLong)
      {
         Journal.Warning(
            "EXECUTION_TEST_BLOCKED reason=LONG_DISABLED"
         );
         return;
      }
   
      if(buyVolume <= 0.0)
      {
         Journal.Error(
            "EXECUTION_TEST_FAILED reason=INVALID_BUY_VOLUME"
         );
         return;
      }
   
      double buyTakeProfit =
         buyEntry
         + (InpTakeProfitPoints * market.point);
   
      buyStop =
         NormalizeDouble(
            buyStop,
            _Digits
         );
   
      buyTakeProfit =
         NormalizeDouble(
            buyTakeProfit,
            _Digits
         );
   
      Journal.Info(
         StringFormat(
            "EXECUTION_TEST_ATTEMPT side=BUY volume=%.4f entry=%s sl=%s tp=%s",
            buyVolume,
            DoubleToString(buyEntry, _Digits),
            DoubleToString(buyStop, _Digits),
            DoubleToString(buyTakeProfit, _Digits)
         )
      );
   
      bool success =
         Execution.Buy(
            _Symbol,
            buyVolume,
            buyStop,
            buyTakeProfit
         );
   
      if(success)
      {
         Journal.Info(
            StringFormat(
               "ORDER_OPENED side=BUY volume=%.4f retcode=%u description=%s",
               buyVolume,
               Execution.LastRetcode(),
               Execution.LastRetcodeDescription()
            )
         );
      }
      else
      {
         Journal.Error(
            StringFormat(
               "ORDER_FAILED side=BUY retcode=%u description=%s",
               Execution.LastRetcode(),
               Execution.LastRetcodeDescription()
            )
         );
      }
   
      return;
   }
   
   
   // ---------------------------------------------------------
   // SELL TEST
   // ---------------------------------------------------------
   
   if(!InpAllowShort)
   {
      Journal.Warning(
         "EXECUTION_TEST_BLOCKED reason=SHORT_DISABLED"
      );
      return;
   }
   
   if(sellVolume <= 0.0)
   {
      Journal.Error(
         "EXECUTION_TEST_FAILED reason=INVALID_SELL_VOLUME"
      );
      return;
   }
   
   double sellTakeProfit =
      sellEntry
      - (InpTakeProfitPoints * market.point);
   
   sellStop =
      NormalizeDouble(
         sellStop,
         _Digits
      );
   
   sellTakeProfit =
      NormalizeDouble(
         sellTakeProfit,
         _Digits
      );
   
   Journal.Info(
      StringFormat(
         "EXECUTION_TEST_ATTEMPT side=SELL volume=%.4f entry=%s sl=%s tp=%s",
         sellVolume,
         DoubleToString(sellEntry, _Digits),
         DoubleToString(sellStop, _Digits),
         DoubleToString(sellTakeProfit, _Digits)
      )
   );
   
   bool success =
      Execution.Sell(
         _Symbol,
         sellVolume,
         sellStop,
         sellTakeProfit
      );
   
   if(success)
   {
      Journal.Info(
         StringFormat(
            "ORDER_OPENED side=SELL volume=%.4f retcode=%u description=%s",
            sellVolume,
            Execution.LastRetcode(),
            Execution.LastRetcodeDescription()
         )
      );
   }
   else
   {
      Journal.Error(
         StringFormat(
            "ORDER_FAILED side=SELL retcode=%u description=%s",
            Execution.LastRetcode(),
            Execution.LastRetcodeDescription()
         )
      );
   }
}

// =====================================================
// PHASE 1.4 — REAL TRADE TRANSACTION JOURNAL
// =====================================================

void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result
)
{
   // Kita hanya tertarik ketika MT5 benar-benar
   // menghasilkan sebuah DEAL.
   if(
      trans.type !=
      TRADE_TRANSACTION_DEAL_ADD
   )
   {
      return;
   }


   if(trans.deal == 0)
      return;


   if(!Journal.LogDeal(
      trans.deal
   ))
   {
      Journal.Error(
         StringFormat(
            "TRADE_CSV_WRITE_FAILED deal=%I64u",
            trans.deal
         )
      );
   }
}