//+------------------------------------------------------------------+
//|                                                    Execution.mqh |
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

#ifndef RAMUSEN_EXECUTION_MQH
#define RAMUSEN_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include "Config.mqh"

class CExecution
{
private:

   CTrade trade;


public:

   CExecution()
   {
      trade.SetExpertMagicNumber(InpMagicNumber);
   }


   bool Buy(
      const string symbol,
      const double volume,
      const double sl,
      const double tp
   )
   {
      return trade.Buy(
         volume,
         symbol,
         0.0,
         sl,
         tp,
         "RAMUSEN_EA"
      );
   }


   bool Sell(
      const string symbol,
      const double volume,
      const double sl,
      const double tp
   )
   {
      return trade.Sell(
         volume,
         symbol,
         0.0,
         sl,
         tp,
         "RAMUSEN_EA"
      );
   }


   uint LastRetcode()
   {
      return trade.ResultRetcode();
   }


   string LastRetcodeDescription()
   {
      return trade.ResultRetcodeDescription();
   }
   
   bool ClosePosition(const ulong ticket)
   {
      return trade.PositionClose(ticket);
   }
};

#endif