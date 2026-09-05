//+------------------------------------------------------------------+
//|                                                       Market.mqh |
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

#ifndef RAMUSEN_MARKET_MQH
#define RAMUSEN_MARKET_MQH

#include "Types.mqh"

class CMarket
{
public:

   bool Snapshot(const string symbol, MarketSnapshot &snapshot)
   {
      MqlTick tick;

      if(!SymbolInfoTick(symbol, tick))
         return false;

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(point <= 0)
         return false;

      snapshot.bid = tick.bid;
      snapshot.ask = tick.ask;
      snapshot.point = point;

      snapshot.spread_points =
         (tick.ask - tick.bid) / point;

      return true;
   }
};

#endif