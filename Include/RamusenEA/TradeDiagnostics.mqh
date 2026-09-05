#ifndef RAMUSEN_TRADE_DIAGNOSTICS_MQH
#define RAMUSEN_TRADE_DIAGNOSTICS_MQH


struct TradeExcursionDiagnostics
{
   bool   success;
   string status;

   ulong ticks_scanned;

   double best_price;
   double worst_price;

   double mfe_points;
   double mae_points;

   double mfe_money;
   double mae_money;

   double mfe_r;
   double mae_r;
};


class CTradeDiagnostics
{
private:

   void ResetResult(
      TradeExcursionDiagnostics &result,
      const double entryPrice
   )
   {
      result.success = false;
      result.status = "NOT_CALCULATED";

      result.ticks_scanned = 0;

      result.best_price = entryPrice;
      result.worst_price = entryPrice;

      result.mfe_points = 0.0;
      result.mae_points = 0.0;

      result.mfe_money = 0.0;
      result.mae_money = 0.0;

      result.mfe_r = 0.0;
      result.mae_r = 0.0;
   }


public:

   bool Calculate(
      const string symbol,
      const string side,

      const ulong entryTimeMsc,
      const ulong exitTimeMsc,

      const double entryPrice,
      const double initialSL,
      const double volume,

      TradeExcursionDiagnostics &result
   )
   {
      ResetResult(
         result,
         entryPrice
      );


      // ==================================================
      // BASIC VALIDATION
      // ==================================================

      if(symbol == "")
      {
         result.status =
            "INVALID_SYMBOL";

         return false;
      }


      if(
         side != "BUY" &&
         side != "SELL"
      )
      {
         result.status =
            "INVALID_SIDE";

         return false;
      }


      if(entryPrice <= 0.0)
      {
         result.status =
            "INVALID_ENTRY_PRICE";

         return false;
      }


      if(volume <= 0.0)
      {
         result.status =
            "INVALID_VOLUME";

         return false;
      }


      if(
         entryTimeMsc == 0 ||
         exitTimeMsc == 0 ||
         exitTimeMsc < entryTimeMsc
      )
      {
         result.status =
            "INVALID_TIME_RANGE";

         return false;
      }


      double point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
      {
         result.status =
            "INVALID_POINT";

         return false;
      }


      // ==================================================
      // EXCURSION STATE
      //
      // BUY:
      // posisi ditutup pada BID.
      //
      // SELL:
      // posisi ditutup pada ASK.
      //
      // Jadi kita menggunakan executable-side price,
      // bukan mid price.
      // ==================================================

      double bestPrice =
         entryPrice;

      double worstPrice =
         entryPrice;


      ulong totalTicks =
         0;


      // ==================================================
      // SCAN REAL TICK HISTORY IN SMALL CHUNKS
      //
      // Jangan CopyTicksRange seluruh multi-day trade
      // sekaligus karena bisa memakan memory besar.
      // ==================================================

      const ulong CHUNK_MILLISECONDS =
         3600000; // 1 jam


      ulong cursor =
         entryTimeMsc;


      while(cursor <= exitTimeMsc)
      {
         ulong chunkEnd =
            cursor +
            CHUNK_MILLISECONDS -
            1;


         if(
            chunkEnd < cursor ||
            chunkEnd > exitTimeMsc
         )
         {
            chunkEnd =
               exitTimeMsc;
         }


         MqlTick ticks[];


         ResetLastError();


         int copied =
            CopyTicksRange(
               symbol,
               ticks,
               COPY_TICKS_ALL,
               cursor,
               chunkEnd
            );


         if(copied < 0)
         {
            result.status =
               StringFormat(
                  "COPY_TICKS_FAILED_%d",
                  GetLastError()
               );

            return false;
         }


         for(int i = 0; i < copied; i++)
         {
            double executablePrice =
               0.0;


            if(side == "BUY")
            {
               executablePrice =
                  ticks[i].bid;
            }
            else
            {
               executablePrice =
                  ticks[i].ask;
            }


            if(executablePrice <= 0.0)
               continue;


            totalTicks++;


            // =============================================
            // BUY
            // favorable = price naik
            // adverse   = price turun
            // =============================================

            if(side == "BUY")
            {
               if(executablePrice > bestPrice)
               {
                  bestPrice =
                     executablePrice;
               }


               if(executablePrice < worstPrice)
               {
                  worstPrice =
                     executablePrice;
               }
            }


            // =============================================
            // SELL
            // favorable = price turun
            // adverse   = price naik
            // =============================================

            else
            {
               if(executablePrice < bestPrice)
               {
                  bestPrice =
                     executablePrice;
               }


               if(executablePrice > worstPrice)
               {
                  worstPrice =
                     executablePrice;
               }
            }
         }


         if(chunkEnd >= exitTimeMsc)
            break;


         cursor =
            chunkEnd +
            1;
      }


      // ==================================================
      // VALIDATE TICK DATA
      // ==================================================

      result.ticks_scanned =
         totalTicks;


      if(totalTicks == 0)
      {
         result.status =
            "NO_TICKS";

         return false;
      }


      result.best_price =
         bestPrice;

      result.worst_price =
         worstPrice;


      // ==================================================
      // PRICE EXCURSION
      // ==================================================

      double mfeDistance =
         0.0;

      double maeDistance =
         0.0;


      if(side == "BUY")
      {
         mfeDistance =
            bestPrice -
            entryPrice;

         maeDistance =
            entryPrice -
            worstPrice;
      }
      else
      {
         mfeDistance =
            entryPrice -
            bestPrice;

         maeDistance =
            worstPrice -
            entryPrice;
      }


      if(mfeDistance < 0.0)
         mfeDistance = 0.0;


      if(maeDistance < 0.0)
         maeDistance = 0.0;


      result.mfe_points =
         mfeDistance /
         point;


      result.mae_points =
         maeDistance /
         point;


      // ==================================================
      // MONEY EXCURSION
      //
      // Gunakan OrderCalcProfit agar contract specification
      // symbol tetap dihormati.
      // ==================================================

      ENUM_ORDER_TYPE orderType =
         side == "BUY"
         ? ORDER_TYPE_BUY
         : ORDER_TYPE_SELL;


      double bestProfit =
         0.0;


      if(
         OrderCalcProfit(
            orderType,
            symbol,
            volume,
            entryPrice,
            bestPrice,
            bestProfit
         )
      )
      {
         if(bestProfit > 0.0)
         {
            result.mfe_money =
               bestProfit;
         }
      }


      double worstProfit =
         0.0;


      if(
         OrderCalcProfit(
            orderType,
            symbol,
            volume,
            entryPrice,
            worstPrice,
            worstProfit
         )
      )
      {
         if(worstProfit < 0.0)
         {
            result.mae_money =
               MathAbs(
                  worstProfit
               );
         }
      }


      // ==================================================
      // R MULTIPLE
      //
      // 1R = initial entry → initial SL distance.
      // ==================================================

      double riskDistance =
         0.0;


      if(initialSL > 0.0)
      {
         if(side == "BUY")
         {
            riskDistance =
               entryPrice -
               initialSL;
         }
         else
         {
            riskDistance =
               initialSL -
               entryPrice;
         }
      }


      if(riskDistance > 0.0)
      {
         result.mfe_r =
            mfeDistance /
            riskDistance;


         result.mae_r =
            maeDistance /
            riskDistance;


         result.status =
            "OK";
      }
      else
      {
         // MFE/MAE tetap valid.
         // Hanya R multiple yang tidak bisa dihitung.
         result.mfe_r =
            0.0;

         result.mae_r =
            0.0;

         result.status =
            "OK_NO_INITIAL_RISK";
      }


      result.success =
         true;


      return true;
   }
};


#endif