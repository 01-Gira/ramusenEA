//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
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

#ifndef RAMUSEN_RISK_MANAGER_MQH
#define RAMUSEN_RISK_MANAGER_MQH

#include "Config.mqh"
#include "Types.mqh"

class CRiskManager
{
public:

   int CountOwnPositions(
      const string symbol,
      const ulong magic
   )
   {
      int count = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);

         if(ticket == 0)
            continue;

         if(!PositionSelectByTicket(ticket))
            continue;

         string position_symbol =
            PositionGetString(POSITION_SYMBOL);

         ulong position_magic =
            (ulong)PositionGetInteger(POSITION_MAGIC);

         if(
            position_symbol == symbol &&
            position_magic == magic
         )
         {
            count++;
         }
      }

      return count;
   }


   bool SpreadAllowed(
      const MarketSnapshot &market
   )
   {
      return market.spread_points <= InpMaxSpreadPoints;
   }


   bool CanTrade(
      const string symbol,
      const MarketSnapshot &market
   )
   {
      if(!InpEnableTrading)
         return false;

      if(!SpreadAllowed(market))
         return false;

      if(
         CountOwnPositions(symbol, InpMagicNumber)
         >= InpMaxPositions
      )
         return false;

      return true;
   }
   
   double CalculateVolume(
      const string symbol,
      const ENUM_ORDER_TYPE orderType,
      const double entryPrice,
      const double stopPrice
   )
   {
      if(InpRiskPercent <= 0.0)
         return 0.0;
   
      if(entryPrice <= 0.0 || stopPrice <= 0.0)
         return 0.0;
   
      double balance =
         AccountInfoDouble(ACCOUNT_BALANCE);
   
      if(balance <= 0.0)
         return 0.0;
   
      double riskMoney =
         balance * (InpRiskPercent / 100.0);
   
      double lossForOneLot = 0.0;
   
      if(!OrderCalcProfit(
         orderType,
         symbol,
         1.0,
         entryPrice,
         stopPrice,
         lossForOneLot
      ))
      {
         return 0.0;
      }
   
      lossForOneLot = MathAbs(lossForOneLot);
   
      if(lossForOneLot <= 0.0)
         return 0.0;
   
      double rawVolume =
         riskMoney / lossForOneLot;
   
      double volumeMin =
         SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   
      double volumeMax =
         SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
      double volumeStep =
         SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
      if(
         volumeMin <= 0.0 ||
         volumeMax <= 0.0 ||
         volumeStep <= 0.0
      )
      {
         return 0.0;
      }
   
      // Jangan naikkan volume ke minimum kalau minimum
      // justru membuat risiko melebihi batas.
      if(rawVolume < volumeMin)
         return 0.0;
   
      double volume =
         MathFloor(rawVolume / volumeStep)
         * volumeStep;
   
      if(volume > volumeMax)
         volume = volumeMax;
   
      volume = NormalizeDouble(volume, 8);
   
      return volume;
   }
};

#endif