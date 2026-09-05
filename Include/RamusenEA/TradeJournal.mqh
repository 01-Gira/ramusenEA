#ifndef RAMUSEN_TRADE_JOURNAL_MQH
#define RAMUSEN_TRADE_JOURNAL_MQH

#include "Config.mqh"
#include "Types.mqh"
#include "TradeDiagnostics.mqh"


class CTradeJournal
{
private:

   // =====================================================
   // RAW DEAL CSV
   // =====================================================

   int    csvHandle;
   string csvFileName;


   // =====================================================
   // CLOSED TRADE CSV
   // =====================================================

   int    closedCsvHandle;
   string closedCsvFileName;


   // =====================================================
   // JOURNAL IDENTITY
   // =====================================================

   string journalSymbol;

   ENUM_TIMEFRAMES journalTimeframe;

   ulong journalMagic;


   bool csvReady;
   bool closedCsvReady;


   // =====================================================
   // P2.1 DIAGNOSTICS
   // =====================================================

   CTradeDiagnostics Diagnostics;


   // =====================================================
   // PENDING STRATEGY CONTEXT
   // =====================================================

   bool contextReady;

   string contextEvent;

   datetime contextTime;

   string contextSignal;


   double contextFastBar2;
   double contextSlowBar2;

   double contextFastBar1;
   double contextSlowBar1;


   double contextSpread;

   double contextBid;
   double contextAsk;


   double contextSL;
   double contextTP;


   string contextExitReason;


   // =====================================================
   // HELPERS
   // =====================================================

   string GetEventType(
      const ENUM_DEAL_ENTRY entryType
   )
   {
      if(entryType == DEAL_ENTRY_IN)
         return "ENTRY";


      if(
         entryType == DEAL_ENTRY_OUT ||
         entryType == DEAL_ENTRY_OUT_BY
      )
      {
         return "EXIT";
      }


      if(entryType == DEAL_ENTRY_INOUT)
         return "REVERSE";


      return "DEAL";
   }


   string GetPositionSide(
      const ENUM_DEAL_ENTRY entryType,
      const ENUM_DEAL_TYPE dealType
   )
   {
      // ==================================================
      // ENTRY
      // ==================================================

      if(entryType == DEAL_ENTRY_IN)
      {
         if(dealType == DEAL_TYPE_BUY)
            return "BUY";


         if(dealType == DEAL_TYPE_SELL)
            return "SELL";
      }


      // ==================================================
      // EXIT
      //
      // SELL deal closes BUY position.
      // BUY deal closes SELL position.
      // ==================================================

      if(
         entryType == DEAL_ENTRY_OUT ||
         entryType == DEAL_ENTRY_OUT_BY
      )
      {
         if(dealType == DEAL_TYPE_SELL)
            return "BUY";


         if(dealType == DEAL_TYPE_BUY)
            return "SELL";
      }


      // ==================================================
      // REVERSAL
      // ==================================================

      if(entryType == DEAL_ENTRY_INOUT)
      {
         if(dealType == DEAL_TYPE_BUY)
            return "BUY";


         if(dealType == DEAL_TYPE_SELL)
            return "SELL";
      }


      return "UNKNOWN";
   }


   string SignalToString(
      const ENUM_RAMUSEN_SIGNAL signal
   )
   {
      if(signal == RAMUSEN_SIGNAL_BUY)
         return "BUY";


      if(signal == RAMUSEN_SIGNAL_SELL)
         return "SELL";


      return "NONE";
   }


   string DealReasonToStrategyExitReason(
      const ENUM_DEAL_REASON reason
   )
   {
      if(reason == DEAL_REASON_SL)
         return "STOP_LOSS";


      if(reason == DEAL_REASON_TP)
         return "TAKE_PROFIT";


      if(reason == DEAL_REASON_SO)
         return "STOP_OUT";


      if(reason == DEAL_REASON_CLIENT)
         return "MANUAL_CLIENT";


      if(reason == DEAL_REASON_MOBILE)
         return "MANUAL_MOBILE";


      if(reason == DEAL_REASON_WEB)
         return "MANUAL_WEB";


      if(reason == DEAL_REASON_EXPERT)
         return "EXPERT";


      return EnumToString(
         reason
      );
   }


   // =====================================================
   // RECONSTRUCT CLOSED TRADE
   // =====================================================

   bool WriteClosedTrade(
      const ulong positionId,
      const string pendingStrategyExitReason
   )
   {
      if(!closedCsvReady)
         return false;


      if(positionId == 0)
         return false;


      // ==================================================
      // SELECT ENTIRE POSITION HISTORY
      // ==================================================

      ResetLastError();


      if(!HistorySelectByPosition(
         positionId
      ))
      {
         Warning(
            StringFormat(
               "CLOSED_TRADE_HISTORY_SELECT_FAILED position=%I64u error=%d",
               positionId,
               GetLastError()
            )
         );


         return false;
      }


      int totalDeals =
         HistoryDealsTotal();


      if(totalDeals <= 0)
      {
         Warning(
            StringFormat(
               "CLOSED_TRADE_NO_DEALS position=%I64u",
               positionId
            )
         );


         return false;
      }


      // ==================================================
      // RECONSTRUCTION STATE
      // ==================================================

      bool foundEntry =
         false;

      bool foundExit =
         false;

      bool reversalFound =
         false;


      ulong entryDealId =
         0;

      ulong exitDealId =
         0;


      ulong entryOrderId =
         0;

      ulong exitOrderId =
         0;


      datetime entryTime =
         0;

      datetime exitTime =
         0;


      ulong entryTimeMsc =
         0;

      ulong exitTimeMsc =
         0;


      ENUM_DEAL_TYPE entryDealType =
         DEAL_TYPE_BUY;


      ENUM_DEAL_REASON finalExitReason =
         DEAL_REASON_EXPERT;


      ulong entryMagic =
         0;


      double entryVolume =
         0.0;

      double exitVolume =
         0.0;


      double entryPriceWeighted =
         0.0;

      double exitPriceWeighted =
         0.0;


      double grossPnl =
         0.0;

      double commission =
         0.0;

      double swap =
         0.0;

      double fee =
         0.0;


      // ==================================================
      // READ ALL DEALS OF POSITION
      // ==================================================

      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket =
            HistoryDealGetTicket(
               i
            );


         if(dealTicket == 0)
            continue;


         ENUM_DEAL_TYPE dealType =
            (ENUM_DEAL_TYPE)
            HistoryDealGetInteger(
               dealTicket,
               DEAL_TYPE
            );


         // Ignore balance / credit / correction etc.
         if(
            dealType != DEAL_TYPE_BUY &&
            dealType != DEAL_TYPE_SELL
         )
         {
            continue;
         }


         ENUM_DEAL_ENTRY entryType =
            (ENUM_DEAL_ENTRY)
            HistoryDealGetInteger(
               dealTicket,
               DEAL_ENTRY
            );


         if(entryType == DEAL_ENTRY_INOUT)
         {
            reversalFound =
               true;

            continue;
         }


         datetime dealTime =
            (datetime)
            HistoryDealGetInteger(
               dealTicket,
               DEAL_TIME
            );


         ulong dealTimeMsc =
            (ulong)
            HistoryDealGetInteger(
               dealTicket,
               DEAL_TIME_MSC
            );


         double volume =
            HistoryDealGetDouble(
               dealTicket,
               DEAL_VOLUME
            );


         double price =
            HistoryDealGetDouble(
               dealTicket,
               DEAL_PRICE
            );


         // ===============================================
         // PNL + COST ACCOUNTING
         // ===============================================

         grossPnl +=
            HistoryDealGetDouble(
               dealTicket,
               DEAL_PROFIT
            );


         commission +=
            HistoryDealGetDouble(
               dealTicket,
               DEAL_COMMISSION
            );


         swap +=
            HistoryDealGetDouble(
               dealTicket,
               DEAL_SWAP
            );


         fee +=
            HistoryDealGetDouble(
               dealTicket,
               DEAL_FEE
            );


         // ===============================================
         // ENTRY DEAL
         // ===============================================

         if(entryType == DEAL_ENTRY_IN)
         {
            if(!foundEntry)
            {
               foundEntry =
                  true;


               entryDealId =
                  dealTicket;


               entryOrderId =
                  (ulong)
                  HistoryDealGetInteger(
                     dealTicket,
                     DEAL_ORDER
                  );


               entryTime =
                  dealTime;


               entryTimeMsc =
                  dealTimeMsc;


               entryDealType =
                  dealType;


               entryMagic =
                  (ulong)
                  HistoryDealGetInteger(
                     dealTicket,
                     DEAL_MAGIC
                  );
            }


            if(
               entryTimeMsc == 0 ||
               dealTimeMsc < entryTimeMsc
            )
            {
               entryTime =
                  dealTime;


               entryTimeMsc =
                  dealTimeMsc;


               entryDealId =
                  dealTicket;


               entryOrderId =
                  (ulong)
                  HistoryDealGetInteger(
                     dealTicket,
                     DEAL_ORDER
                  );


               entryDealType =
                  dealType;


               entryMagic =
                  (ulong)
                  HistoryDealGetInteger(
                     dealTicket,
                     DEAL_MAGIC
                  );
            }


            entryVolume +=
               volume;


            entryPriceWeighted +=
               price
               *
               volume;
         }


         // ===============================================
         // EXIT DEAL
         // ===============================================

         if(
            entryType == DEAL_ENTRY_OUT ||
            entryType == DEAL_ENTRY_OUT_BY
         )
         {
            if(!foundExit)
            {
               foundExit =
                  true;


               exitDealId =
                  dealTicket;


               exitOrderId =
                  (ulong)
                  HistoryDealGetInteger(
                     dealTicket,
                     DEAL_ORDER
                  );


               exitTime =
                  dealTime;


               exitTimeMsc =
                  dealTimeMsc;


               finalExitReason =
                  (ENUM_DEAL_REASON)
                  HistoryDealGetInteger(
                     dealTicket,
                     DEAL_REASON
                  );
            }


            if(
               exitTimeMsc == 0 ||
               dealTimeMsc >= exitTimeMsc
            )
            {
               exitTime =
                  dealTime;


               exitTimeMsc =
                  dealTimeMsc;


               exitDealId =
                  dealTicket;


               exitOrderId =
                  (ulong)
                  HistoryDealGetInteger(
                     dealTicket,
                     DEAL_ORDER
                  );


               finalExitReason =
                  (ENUM_DEAL_REASON)
                  HistoryDealGetInteger(
                     dealTicket,
                     DEAL_REASON
                  );
            }


            exitVolume +=
               volume;


            exitPriceWeighted +=
               price
               *
               volume;
         }
      }


      // ==================================================
      // VALIDATION
      // ==================================================

      if(reversalFound)
      {
         Warning(
            StringFormat(
               "CLOSED_TRADE_SKIPPED position=%I64u reason=REVERSAL_UNSUPPORTED",
               positionId
            )
         );


         return true;
      }


      if(!foundEntry)
      {
         Warning(
            StringFormat(
               "CLOSED_TRADE_SKIPPED position=%I64u reason=ENTRY_NOT_FOUND",
               positionId
            )
         );


         return true;
      }


      // Ownership is derived from original entry.
      if(entryMagic != journalMagic)
         return true;


      if(!foundExit)
         return true;


      if(entryVolume <= 0.0)
         return true;


      double volumeStep =
         SymbolInfoDouble(
            journalSymbol,
            SYMBOL_VOLUME_STEP
         );


      if(volumeStep <= 0.0)
      {
         volumeStep =
            0.00000001;
      }


      double volumeTolerance =
         volumeStep
         /
         2.0;


      // Partial close is not yet a completed trade.
      if(
         exitVolume
         +
         volumeTolerance
         <
         entryVolume
      )
      {
         Info(
            StringFormat(
               "CLOSED_TRADE_WAIT position=%I64u entry_volume=%.4f exit_volume=%.4f",
               positionId,
               entryVolume,
               exitVolume
            )
         );


         return true;
      }


      // ==================================================
      // WEIGHTED ENTRY / EXIT PRICE
      // ==================================================

      double entryPrice =
         entryPriceWeighted
         /
         entryVolume;


      double exitPrice =
         0.0;


      if(exitVolume > 0.0)
      {
         exitPrice =
            exitPriceWeighted
            /
            exitVolume;
      }


      string side =
         entryDealType == DEAL_TYPE_BUY
         ?
         "BUY"
         :
         "SELL";


      // ==================================================
      // HOLDING TIME
      // ==================================================

      long holdingSeconds =
         (long)(
            exitTime
            -
            entryTime
         );


      if(holdingSeconds < 0)
      {
         holdingSeconds =
            0;
      }


      double holdingHours =
         ((double)holdingSeconds)
         /
         3600.0;


      // ==================================================
      // NET PNL
      // ==================================================

      double netPnl =
         grossPnl
         +
         commission
         +
         swap
         +
         fee;


      // ==================================================
      // INITIAL SL / TP
      // ==================================================

      double initialSL =
         0.0;

      double initialTP =
         0.0;


      if(entryOrderId > 0)
      {
         if(
            HistoryOrderSelect(
               entryOrderId
            )
         )
         {
            initialSL =
               HistoryOrderGetDouble(
                  entryOrderId,
                  ORDER_SL
               );


            initialTP =
               HistoryOrderGetDouble(
                  entryOrderId,
                  ORDER_TP
               );
         }
      }


      // ==================================================
      // EXIT REASON
      // ==================================================

      string strategyExitReason =
         pendingStrategyExitReason;


      if(strategyExitReason == "")
      {
         strategyExitReason =
            DealReasonToStrategyExitReason(
               finalExitReason
            );
      }


      // ==================================================
      // P2.1 — MFE / MAE DIAGNOSTICS
      // ==================================================

      TradeExcursionDiagnostics excursion;


      bool diagnosticsReady =
         Diagnostics.Calculate(
            journalSymbol,
            side,

            entryTimeMsc,
            exitTimeMsc,

            entryPrice,
            initialSL,
            entryVolume,

            excursion
         );


      if(!diagnosticsReady)
      {
         Warning(
            StringFormat(
               "TRADE_DIAGNOSTICS_FAILED position=%I64u status=%s",
               positionId,
               excursion.status
            )
         );
      }
      else
      {
         Info(
            StringFormat(
               "TRADE_DIAGNOSTICS_READY position=%I64u ticks=%I64u mfe_points=%.1f mae_points=%.1f mfe_r=%.4f mae_r=%.4f",
               positionId,
               excursion.ticks_scanned,
               excursion.mfe_points,
               excursion.mae_points,
               excursion.mfe_r,
               excursion.mae_r
            )
         );
      }


      // ==================================================
      // WRITE ONE COMPLETED TRADE
      // ==================================================

      FileWrite(
         closedCsvHandle,

         positionId,

         journalSymbol,

         EnumToString(
            journalTimeframe
         ),

         journalMagic,

         side,


         entryDealId,
         exitDealId,

         entryOrderId,
         exitOrderId,


         TimeToString(
            entryTime,
            TIME_DATE |
            TIME_SECONDS
         ),

         TimeToString(
            exitTime,
            TIME_DATE |
            TIME_SECONDS
         ),


         holdingSeconds,

         DoubleToString(
            holdingHours,
            4
         ),


         DoubleToString(
            entryVolume,
            4
         ),

         DoubleToString(
            exitVolume,
            4
         ),


         DoubleToString(
            entryPrice,
            _Digits
         ),

         DoubleToString(
            exitPrice,
            _Digits
         ),


         DoubleToString(
            initialSL,
            _Digits
         ),

         DoubleToString(
            initialTP,
            _Digits
         ),


         DoubleToString(
            grossPnl,
            2
         ),

         DoubleToString(
            commission,
            2
         ),

         DoubleToString(
            swap,
            2
         ),

         DoubleToString(
            fee,
            2
         ),

         DoubleToString(
            netPnl,
            2
         ),


         EnumToString(
            finalExitReason
         ),

         strategyExitReason,


         DoubleToString(
            AccountInfoDouble(
               ACCOUNT_BALANCE
            ),
            2
         ),


         // ===============================================
         // P2.1 DIAGNOSTICS
         // ===============================================

         excursion.status,

         excursion.ticks_scanned,


         DoubleToString(
            excursion.best_price,
            _Digits
         ),

         DoubleToString(
            excursion.worst_price,
            _Digits
         ),


         DoubleToString(
            excursion.mfe_points,
            1
         ),

         DoubleToString(
            excursion.mae_points,
            1
         ),


         DoubleToString(
            excursion.mfe_money,
            2
         ),

         DoubleToString(
            excursion.mae_money,
            2
         ),


         DoubleToString(
            excursion.mfe_r,
            4
         ),

         DoubleToString(
            excursion.mae_r,
            4
         )
      );


      FileFlush(
         closedCsvHandle
      );


      Info(
         StringFormat(
            "CLOSED_TRADE_WRITTEN position=%I64u side=%s entry=%s exit=%s holding_hours=%.2f net_pnl=%.2f exit_reason=%s mfe_r=%.4f mae_r=%.4f",
            positionId,
            side,

            DoubleToString(
               entryPrice,
               _Digits
            ),

            DoubleToString(
               exitPrice,
               _Digits
            ),

            holdingHours,
            netPnl,
            strategyExitReason,
            excursion.mfe_r,
            excursion.mae_r
         )
      );


      return true;
   }


public:

   // =====================================================
   // CONSTRUCTOR
   // =====================================================

   CTradeJournal()
   {
      csvHandle =
         INVALID_HANDLE;


      closedCsvHandle =
         INVALID_HANDLE;


      csvFileName =
         "";


      closedCsvFileName =
         "";


      journalSymbol =
         "";


      journalTimeframe =
         PERIOD_CURRENT;


      journalMagic =
         0;


      csvReady =
         false;


      closedCsvReady =
         false;


      ClearPendingContext();
   }


   // =====================================================
   // CONSOLE LOGGING
   // =====================================================

   void Info(
      string message
   )
   {
      Print(
         "[RAMUSEN][INFO] ",
         message
      );
   }


   void Warning(
      string message
   )
   {
      Print(
         "[RAMUSEN][WARN] ",
         message
      );
   }


   void Error(
      string message
   )
   {
      Print(
         "[RAMUSEN][ERROR] ",
         message
      );
   }


   // =====================================================
   // ENTRY CONTEXT
   // =====================================================

   void PrepareEntryContext(
      const datetime decisionTime,
      const ENUM_RAMUSEN_SIGNAL signal,
      const MarketSnapshot &market,

      const double fastBar2,
      const double slowBar2,

      const double fastBar1,
      const double slowBar1,

      const double sl,
      const double tp
   )
   {
      contextReady =
         true;


      contextEvent =
         "ENTRY";


      contextTime =
         decisionTime;


      contextSignal =
         SignalToString(
            signal
         );


      contextFastBar2 =
         fastBar2;


      contextSlowBar2 =
         slowBar2;


      contextFastBar1 =
         fastBar1;


      contextSlowBar1 =
         slowBar1;


      contextSpread =
         market.spread_points;


      contextBid =
         market.bid;


      contextAsk =
         market.ask;


      contextSL =
         sl;


      contextTP =
         tp;


      contextExitReason =
         "";
   }


   // =====================================================
   // EXIT CONTEXT
   // =====================================================

   void PrepareExitContext(
      const datetime decisionTime,
      const ENUM_RAMUSEN_SIGNAL signal,
      const MarketSnapshot &market,

      const double fastBar2,
      const double slowBar2,

      const double fastBar1,
      const double slowBar1,

      const double sl,
      const double tp,

      const string exitReason
   )
   {
      contextReady =
         true;


      contextEvent =
         "EXIT";


      contextTime =
         decisionTime;


      contextSignal =
         SignalToString(
            signal
         );


      contextFastBar2 =
         fastBar2;


      contextSlowBar2 =
         slowBar2;


      contextFastBar1 =
         fastBar1;


      contextSlowBar1 =
         slowBar1;


      contextSpread =
         market.spread_points;


      contextBid =
         market.bid;


      contextAsk =
         market.ask;


      contextSL =
         sl;


      contextTP =
         tp;


      contextExitReason =
         exitReason;
   }


   // =====================================================
   // CLEAR CONTEXT
   // =====================================================

   void ClearPendingContext()
   {
      contextReady =
         false;


      contextEvent =
         "";


      contextTime =
         0;


      contextSignal =
         "";


      contextFastBar2 =
         0.0;


      contextSlowBar2 =
         0.0;


      contextFastBar1 =
         0.0;


      contextSlowBar1 =
         0.0;


      contextSpread =
         0.0;


      contextBid =
         0.0;


      contextAsk =
         0.0;


      contextSL =
         0.0;


      contextTP =
         0.0;


      contextExitReason =
         "";
   }


   // =====================================================
   // INITIALIZE CSV
   // =====================================================

   bool InitializeCsv(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      const ulong magic
   )
   {
      ShutdownCsv();


      journalSymbol =
         symbol;


      journalTimeframe =
         timeframe;


      journalMagic =
         magic;


      long sessionStamp =
         (long)TimeLocal();


      // ==================================================
      // RAW DEAL CSV
      // ==================================================

      csvFileName =
         StringFormat(
            "RamusenEA_trades_%s_%s_%I64d.csv",
            journalSymbol,
            EnumToString(
               journalTimeframe
            ),
            sessionStamp
         );


      ResetLastError();


      csvHandle =
         FileOpen(
            csvFileName,

            FILE_WRITE |
            FILE_CSV |
            FILE_COMMON |
            FILE_ANSI,

            ','
         );


      if(csvHandle == INVALID_HANDLE)
      {
         int errorCode =
            GetLastError();


         Error(
            StringFormat(
               "TRADE_CSV_OPEN_FAILED file=%s error=%d",
               csvFileName,
               errorCode
            )
         );


         return false;
      }


      FileWrite(
         csvHandle,

         "time",
         "event",

         "position_id",
         "deal_id",
         "order_id",

         "symbol",
         "timeframe",
         "magic",

         "position_side",
         "deal_side",
         "entry_type",

         "volume",
         "price",

         "profit",
         "commission",
         "swap",
         "fee",
         "net_pnl",

         "deal_reason",
         "balance_after",

         "decision_time",
         "strategy_signal",

         "fast_ema_bar2",
         "slow_ema_bar2",

         "fast_ema_bar1",
         "slow_ema_bar1",

         "spread_points",

         "decision_bid",
         "decision_ask",

         "planned_sl",
         "planned_tp",

         "strategy_exit_reason"
      );


      FileFlush(
         csvHandle
      );


      // ==================================================
      // CLOSED TRADE CSV
      // ==================================================

      closedCsvFileName =
         StringFormat(
            "RamusenEA_closed_trades_%s_%s_%I64d.csv",
            journalSymbol,
            EnumToString(
               journalTimeframe
            ),
            sessionStamp
         );


      ResetLastError();


      closedCsvHandle =
         FileOpen(
            closedCsvFileName,

            FILE_WRITE |
            FILE_CSV |
            FILE_COMMON |
            FILE_ANSI,

            ','
         );


      if(closedCsvHandle == INVALID_HANDLE)
      {
         int errorCode =
            GetLastError();


         Error(
            StringFormat(
               "CLOSED_TRADE_CSV_OPEN_FAILED file=%s error=%d",
               closedCsvFileName,
               errorCode
            )
         );


         FileClose(
            csvHandle
         );


         csvHandle =
            INVALID_HANDLE;


         return false;
      }


      FileWrite(
         closedCsvHandle,

         "position_id",

         "symbol",
         "timeframe",
         "magic",

         "side",

         "entry_deal_id",
         "exit_deal_id",

         "entry_order_id",
         "exit_order_id",

         "entry_time",
         "exit_time",

         "holding_seconds",
         "holding_hours",

         "entry_volume",
         "exit_volume",

         "entry_price",
         "exit_price",

         "initial_sl",
         "initial_tp",

         "gross_pnl",
         "commission",
         "swap",
         "fee",
         "net_pnl",

         "mt5_exit_reason",
         "strategy_exit_reason",

         "balance_after",


         // ===============================================
         // P2.1 MFE / MAE
         // ===============================================

         "diagnostics_status",
         "ticks_scanned",

         "best_price",
         "worst_price",

         "mfe_points",
         "mae_points",

         "mfe_money",
         "mae_money",

         "mfe_r",
         "mae_r"
      );


      FileFlush(
         closedCsvHandle
      );


      csvReady =
         true;


      closedCsvReady =
         true;


      ClearPendingContext();


      Info(
         StringFormat(
            "CLOSED_TRADE_CSV_READY file=%s",
            closedCsvFileName
         )
      );


      return true;
   }


   // =====================================================
   // SHUTDOWN
   // =====================================================

   void ShutdownCsv()
   {
      if(csvHandle != INVALID_HANDLE)
      {
         FileFlush(
            csvHandle
         );


         FileClose(
            csvHandle
         );


         csvHandle =
            INVALID_HANDLE;
      }


      if(closedCsvHandle != INVALID_HANDLE)
      {
         FileFlush(
            closedCsvHandle
         );


         FileClose(
            closedCsvHandle
         );


         closedCsvHandle =
            INVALID_HANDLE;
      }


      csvReady =
         false;


      closedCsvReady =
         false;


      ClearPendingContext();
   }


   // =====================================================
   // LOG REAL MT5 DEAL
   // =====================================================

   bool LogDeal(
      const ulong dealTicket
   )
   {
      if(!csvReady)
         return false;


      if(dealTicket == 0)
         return false;


      if(
         !HistoryDealSelect(
            dealTicket
         )
      )
      {
         Warning(
            StringFormat(
               "TRADE_CSV_DEAL_SELECT_FAILED deal=%I64u",
               dealTicket
            )
         );


         return false;
      }


      // ==================================================
      // EXECUTION TRUTH
      // ==================================================

      string dealSymbol =
         HistoryDealGetString(
            dealTicket,
            DEAL_SYMBOL
         );


      ulong dealMagic =
         (ulong)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_MAGIC
         );


      if(dealSymbol != journalSymbol)
         return true;


      if(dealMagic != journalMagic)
         return true;


      datetime dealTime =
         (datetime)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_TIME
         );


      ulong positionId =
         (ulong)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_POSITION_ID
         );


      ulong orderId =
         (ulong)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_ORDER
         );


      ENUM_DEAL_TYPE dealType =
         (ENUM_DEAL_TYPE)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_TYPE
         );


      ENUM_DEAL_ENTRY entryType =
         (ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_ENTRY
         );


      ENUM_DEAL_REASON dealReason =
         (ENUM_DEAL_REASON)
         HistoryDealGetInteger(
            dealTicket,
            DEAL_REASON
         );


      double volume =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_VOLUME
         );


      double price =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_PRICE
         );


      double profit =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_PROFIT
         );


      double commission =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_COMMISSION
         );


      double swap =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_SWAP
         );


      double fee =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_FEE
         );


      double netPnl =
         profit
         +
         commission
         +
         swap
         +
         fee;


      string eventType =
         GetEventType(
            entryType
         );


      string positionSide =
         GetPositionSide(
            entryType,
            dealType
         );


      string dealSide =
         EnumToString(
            dealType
         );


      // ==================================================
      // STRATEGY CONTEXT
      // ==================================================

      bool useContext =
         contextReady
         &&
         contextEvent == eventType;


      string decisionTimeText =
         "";


      string strategySignal =
         "";


      string fastBar2Text =
         "";

      string slowBar2Text =
         "";


      string fastBar1Text =
         "";

      string slowBar1Text =
         "";


      string spreadText =
         "";


      string bidText =
         "";

      string askText =
         "";


      string slText =
         "";

      string tpText =
         "";


      string strategyExitReason =
         "";


      if(useContext)
      {
         decisionTimeText =
            TimeToString(
               contextTime,
               TIME_DATE |
               TIME_SECONDS
            );


         strategySignal =
            contextSignal;


         fastBar2Text =
            DoubleToString(
               contextFastBar2,
               8
            );


         slowBar2Text =
            DoubleToString(
               contextSlowBar2,
               8
            );


         fastBar1Text =
            DoubleToString(
               contextFastBar1,
               8
            );


         slowBar1Text =
            DoubleToString(
               contextSlowBar1,
               8
            );


         spreadText =
            DoubleToString(
               contextSpread,
               1
            );


         bidText =
            DoubleToString(
               contextBid,
               _Digits
            );


         askText =
            DoubleToString(
               contextAsk,
               _Digits
            );


         slText =
            DoubleToString(
               contextSL,
               _Digits
            );


         tpText =
            DoubleToString(
               contextTP,
               _Digits
            );


         strategyExitReason =
            contextExitReason;
      }


      // ==================================================
      // WRITE RAW DEAL
      // ==================================================

      FileWrite(
         csvHandle,

         TimeToString(
            dealTime,
            TIME_DATE |
            TIME_SECONDS
         ),

         eventType,

         positionId,
         dealTicket,
         orderId,

         dealSymbol,

         EnumToString(
            journalTimeframe
         ),

         dealMagic,

         positionSide,
         dealSide,

         EnumToString(
            entryType
         ),

         DoubleToString(
            volume,
            4
         ),

         DoubleToString(
            price,
            _Digits
         ),

         DoubleToString(
            profit,
            2
         ),

         DoubleToString(
            commission,
            2
         ),

         DoubleToString(
            swap,
            2
         ),

         DoubleToString(
            fee,
            2
         ),

         DoubleToString(
            netPnl,
            2
         ),

         EnumToString(
            dealReason
         ),

         DoubleToString(
            AccountInfoDouble(
               ACCOUNT_BALANCE
            ),
            2
         ),

         decisionTimeText,
         strategySignal,

         fastBar2Text,
         slowBar2Text,

         fastBar1Text,
         slowBar1Text,

         spreadText,

         bidText,
         askText,

         slText,
         tpText,

         strategyExitReason
      );


      FileFlush(
         csvHandle
      );


      // ==================================================
      // P1.4C + P2.1
      //
      // When EXIT occurs:
      // reconstruct full trade then calculate MFE/MAE.
      // ==================================================

      if(eventType == "EXIT")
      {
         if(
            !WriteClosedTrade(
               positionId,
               strategyExitReason
            )
         )
         {
            Error(
               StringFormat(
                  "CLOSED_TRADE_WRITE_FAILED position=%I64u",
                  positionId
               )
            );
         }
      }


      // ==================================================
      // CLEAR MATCHED STRATEGY CONTEXT
      // ==================================================

      if(useContext)
      {
         ClearPendingContext();
      }


      Info(
         StringFormat(
            "TRADE_CSV_WRITTEN event=%s deal=%I64u position=%I64u side=%s volume=%.4f price=%s net_pnl=%.2f context=%s",
            eventType,
            dealTicket,
            positionId,
            positionSide,
            volume,

            DoubleToString(
               price,
               _Digits
            ),

            netPnl,

            useContext
            ?
            "YES"
            :
            "NO"
         )
      );


      return true;
   }


   // =====================================================
   // FILE INFO
   // =====================================================

   string CsvFileName()
   {
      return csvFileName;
   }


   string ClosedCsvFileName()
   {
      return closedCsvFileName;
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