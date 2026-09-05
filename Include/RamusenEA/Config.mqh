//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+

#ifndef RAMUSEN_CONFIG_MQH
#define RAMUSEN_CONFIG_MQH

input ulong  InpMagicNumber       = 26090401;
input double InpRiskPercent       = 0.50;

input int   InpStopLossPoints    = 500;
input int   InpTakeProfitPoints  = 1000;

input int   InpMaxSpreadPoints   = 100;
input int   InpMaxPositions      = 1;

input bool  InpAllowLong         = true;
input bool  InpAllowShort        = true;

input bool  InpEnableTrading     = false;
input bool  InpExecutionTest    = false;
input bool  InpExecutionTestBuy = true;

// =====================================================
// PHASE 1 — BASELINE STRATEGY
// =====================================================

input int InpFastMAPeriod = 9;
input int InpSlowMAPeriod = 21;

input bool InpBaselineStrategyEnabled = false;

// =====================================================
// PHASE 2 — RESEARCH / DIAGNOSTICS
// =====================================================

input bool InpSignalResearchEnabled = false;

// =====================================================
// P2F.3 — SCALPING CONTEXT RESEARCH
// =====================================================

input bool InpScalpingContextResearchEnabled = false;

input ENUM_TIMEFRAMES InpScalpingContextTimeframe =
   PERIOD_M15;

input int InpScalpingContextFastMAPeriod = 20;
input int InpScalpingContextSlowMAPeriod = 50;

input int InpScalpingATRPeriod = 14;

// =====================================================
// P2F.4 — ENTRY QUALITY GATE
// =====================================================

input bool InpP2F4EntryGateResearchEnabled = false;

// =====================================================
// P2F.5A — SCALPING EXCURSION RESEARCH
// =====================================================

input bool InpP2F5ExcursionResearchEnabled = false;

input bool InpP2F6TimeExitResearchEnabled = false;

input bool InpP2F7ProfitRetentionResearchEnabled = false;

input bool InpP2F11CAdaptiveRetentionResearchEnabled = false;

input bool InpP2F12CandidateS2ResearchEnabled = false;

// =====================================================
// P2F.14A — CONTROLLED LAYER RESEARCH
//
// Research-only. No real orders.
// Requires P2F.12 Candidate S2 research.
// =====================================================

input bool InpP2F14ControlledLayerResearchEnabled = false;


// =====================================================
// S3.0 — M15 BEARISH CONTEXT EVENT-GENERATOR CONTROL
//
// Research only.
// Measures whether M5 EMA9/21 bearish crossover adds
// timing information beyond the M15 bearish context.
// =====================================================

input bool InpS30EventGeneratorControlResearchEnabled = false;

// S3.1 paired timing mechanism: research only, no orders or layers.
input bool InpS31PairedDelayedEntryResearchEnabled = false;

#endif