//+------------------------------------------------------------------+
//|                                                        Types.mqh |
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

#ifndef RAMUSEN_TYPES_MQH
#define RAMUSEN_TYPES_MQH

enum ENUM_RAMUSEN_SIGNAL
{
   RAMUSEN_SIGNAL_NONE = 0,
   RAMUSEN_SIGNAL_BUY,
   RAMUSEN_SIGNAL_SELL
};

struct MarketSnapshot
{
   double bid;
   double ask;
   double spread_points;
   double point;
};

struct PositionSnapshot
{
   ulong ticket;
   string symbol;
   ulong magic;

   ENUM_POSITION_TYPE type;

   double volume;
   double price_open;
   double sl;
   double tp;
};

#endif