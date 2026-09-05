#ifndef RAMUSEN_SIGNAL_ENGINE_MQH
#define RAMUSEN_SIGNAL_ENGINE_MQH

#include "Config.mqh"
#include "Types.mqh"

class CSignalEngine
{
private:
   int fastHandle;
   int slowHandle;

   string symbol;
   ENUM_TIMEFRAMES timeframe;

   bool ReadMAValue(
      const int handle,
      const int shift,
      double &value
   )
   {
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

public:
   CSignalEngine()
   {
      fastHandle = INVALID_HANDLE;
      slowHandle = INVALID_HANDLE;

      symbol = "";
      timeframe = PERIOD_CURRENT;
   }

   bool Initialize(
      const string newSymbol,
      const ENUM_TIMEFRAMES newTimeframe
   )
   {
      Shutdown();

      if(InpFastMAPeriod <= 0)
         return false;

      if(InpSlowMAPeriod <= 0)
         return false;

      if(InpFastMAPeriod >= InpSlowMAPeriod)
         return false;

      symbol = newSymbol;
      timeframe = newTimeframe;

      ResetLastError();

      fastHandle =
         iMA(
            NULL,
            timeframe,
            InpFastMAPeriod,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );
      
      if(fastHandle == INVALID_HANDLE)
      {
         int errorCode = GetLastError();
      
         PrintFormat(
            "[RAMUSEN][ERROR] FAST_EMA_CREATE_FAILED symbol=%s timeframe=%s period=%d error=%d",
            symbol,
            EnumToString(timeframe),
            InpFastMAPeriod,
            errorCode
         );
      
         Shutdown();
         return false;
      }
      
      ResetLastError();
      
      slowHandle =
         iMA(
            NULL,
            timeframe,
            InpSlowMAPeriod,
            0,
            MODE_EMA,
            PRICE_CLOSE
         );
      
      if(slowHandle == INVALID_HANDLE)
      {
         int errorCode = GetLastError();
      
         PrintFormat(
            "[RAMUSEN][ERROR] SLOW_EMA_CREATE_FAILED symbol=%s timeframe=%s period=%d error=%d",
            symbol,
            EnumToString(timeframe),
            InpSlowMAPeriod,
            errorCode
         );
      
         Shutdown();
         return false;
      }

      return true;
   }

   void Shutdown()
   {
      if(fastHandle != INVALID_HANDLE)
      {
         IndicatorRelease(fastHandle);
         fastHandle = INVALID_HANDLE;
      }

      if(slowHandle != INVALID_HANDLE)
      {
         IndicatorRelease(slowHandle);
         slowHandle = INVALID_HANDLE;
      }
   }

   bool GetSignal(
      ENUM_RAMUSEN_SIGNAL &signal,
      double &fastBar2,
      double &slowBar2,
      double &fastBar1,
      double &slowBar1
   )
   {
      signal = RAMUSEN_SIGNAL_NONE;

      if(
         fastHandle == INVALID_HANDLE ||
         slowHandle == INVALID_HANDLE
      )
      {
         return false;
      }

      int minimumBars =
         InpSlowMAPeriod + 2;

      if(BarsCalculated(fastHandle) < minimumBars)
         return false;

      if(BarsCalculated(slowHandle) < minimumBars)
         return false;

      // bar 1 = candle terakhir yang sudah CLOSE
      // bar 2 = candle sebelum bar 1

      if(!ReadMAValue(
         fastHandle,
         2,
         fastBar2
      ))
      {
         return false;
      }

      if(!ReadMAValue(
         slowHandle,
         2,
         slowBar2
      ))
      {
         return false;
      }

      if(!ReadMAValue(
         fastHandle,
         1,
         fastBar1
      ))
      {
         return false;
      }

      if(!ReadMAValue(
         slowHandle,
         1,
         slowBar1
      ))
      {
         return false;
      }

      // Bullish crossover
      if(
         fastBar2 <= slowBar2 &&
         fastBar1 > slowBar1
      )
      {
         signal = RAMUSEN_SIGNAL_BUY;
         return true;
      }

      // Bearish crossover
      if(
         fastBar2 >= slowBar2 &&
         fastBar1 < slowBar1
      )
      {
         signal = RAMUSEN_SIGNAL_SELL;
         return true;
      }

      signal = RAMUSEN_SIGNAL_NONE;

      return true;
   }
};

#endif