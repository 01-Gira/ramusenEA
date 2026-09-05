//+------------------------------------------------------------------+
//|                                              PositionManager.mqh |
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

#ifndef RAMUSEN_POSITION_MANAGER_MQH
#define RAMUSEN_POSITION_MANAGER_MQH

#include "Config.mqh"
#include "Types.mqh"

class CPositionManager
{
public:

   bool HasOwnPosition(const string symbol)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);

         if(ticket == 0)
            continue;

         if(!PositionSelectByTicket(ticket))
            continue;

         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;

         ulong magic =
            (ulong)PositionGetInteger(POSITION_MAGIC);

         if(magic == InpMagicNumber)
            return true;
      }

      return false;
   }


   bool GetOwnPosition(
      const string symbol,
      const ulong magic,
      PositionSnapshot &snapshot
   )
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);

         if(ticket == 0)
            continue;

         if(!PositionSelectByTicket(ticket))
            continue;

         string positionSymbol =
            PositionGetString(POSITION_SYMBOL);

         ulong positionMagic =
            (ulong)PositionGetInteger(POSITION_MAGIC);

         if(positionSymbol != symbol)
            continue;

         if(positionMagic != magic)
            continue;

         snapshot.ticket = ticket;
         snapshot.symbol = positionSymbol;
         snapshot.magic = positionMagic;

         snapshot.type =
            (ENUM_POSITION_TYPE)
            PositionGetInteger(POSITION_TYPE);

         snapshot.volume =
            PositionGetDouble(POSITION_VOLUME);

         snapshot.price_open =
            PositionGetDouble(POSITION_PRICE_OPEN);

         snapshot.sl =
            PositionGetDouble(POSITION_SL);

         snapshot.tp =
            PositionGetDouble(POSITION_TP);

         return true;
      }

      return false;
   }
};

#endif