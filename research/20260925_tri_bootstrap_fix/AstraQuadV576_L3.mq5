#property copyright "OpenAI / ASTRA research"
#property version   "5.76"
#property strict
#property description "ASTRA Portfolio: frozen ALL3 + LBMA-PM4R event-time sleeve; deterministic bootstrap; no parent alpha tuning."
#property description "P812 + HF02X + KAGURA G10 frozen; LBMA-PM4R fixed 0.01, hard SL, 20m max hold, 10% balance-risk gate."

#include <Trade/Trade.mqh>
#include "AstraPortfolioP812HF02XConfig.mqh"
#include "AstraPortfolioP812HF02XSignalEngine.mqh"

enum ENUM_ASTRA_TRI_MODE
  {
   TRI_P812_ONLY=0,
   TRI_P812_HF02X=1,
   TRI_KAGURA_ONLY=2,
   TRI_P812_KAGURA_G10=3,
   TRI_P812_HF02X_KAGURA_G10=4,
   TRI_LBMA_PM4R_ONLY=5,
   TRI_P812_HF02X_LBMA_PM4R=6,
   TRI_P812_HF02X_KAGURA_G10_LBMA_PM4R=7
  };
input ENUM_ASTRA_TRI_MODE InpPortfolioMode=TRI_P812_HF02X_KAGURA_G10_LBMA_PM4R;

bool PortfolioPrimaryActive()
  { return(InpPortfolioMode!=TRI_KAGURA_ONLY && InpPortfolioMode!=TRI_LBMA_PM4R_ONLY); }
bool PortfolioHF02XActive()
  { return(InpPortfolioMode==TRI_P812_HF02X || InpPortfolioMode==TRI_P812_HF02X_KAGURA_G10 || InpPortfolioMode==TRI_P812_HF02X_LBMA_PM4R || InpPortfolioMode==TRI_P812_HF02X_KAGURA_G10_LBMA_PM4R); }
bool PortfolioKaguraActive()
  { return(InpPortfolioMode==TRI_KAGURA_ONLY || InpPortfolioMode==TRI_P812_KAGURA_G10 || InpPortfolioMode==TRI_P812_HF02X_KAGURA_G10 || InpPortfolioMode==TRI_P812_HF02X_KAGURA_G10_LBMA_PM4R); }
bool PortfolioLBMAActive()
  { return(InpPortfolioMode==TRI_LBMA_PM4R_ONLY || InpPortfolioMode==TRI_P812_HF02X_LBMA_PM4R || InpPortfolioMode==TRI_P812_HF02X_KAGURA_G10_LBMA_PM4R); }

long g_pf_overlap_signals=0,g_pf_same_side=0,g_pf_opposite_side=0;
long g_pf_p812_fills=0,g_pf_hf02x_fills=0,g_pf_p812_trades=0,g_pf_hf02x_trades=0;
double g_pf_p812_py_net=0.0,g_pf_hf02x_py_net=0.0,g_pf_p812_deal_net=0.0,g_pf_hf02x_deal_net=0.0;
int g_pf_summary=INVALID_HANDLE;

input double InpFixedLot                    = 0.01;
input long   InpMagic                       = 55081202;
input double InpMaxTradeRiskPct             = 50.0;
input double InpMarginCapPct                = 92.0;
input bool   InpTradeEnabled                = true;
input bool   InpStrictEnvironment           = true;
input bool   InpDemoOnly                    = true;
input bool   InpRequireBalance20            = true;
input bool   InpRequireHedging              = true;
input bool   InpRequireExactSignalTicks      = true;
input int    InpWarmupExactBars             = 300;
input bool   InpDeterministicBootstrap      = true;
input long   InpBootstrapHistoryStartSec    = 1767218220; // baseline first state bar: 2025-12-31 21:57 UTC
input long   InpFrozenSignalStartSec        = 1767348060; // earliest frozen actionable bar: 2026-01-02 10:01 UTC
input bool   InpWriteAuditCommon            = true;
input bool   InpWriteCandidateAudit         = true;
input bool   InpVerbose                     = false;

// V576 research-only primary pyramiding. Default OFF = V575-equivalent control.
input bool   PYR_InpEnabled                    = false;
input long   PYR_InpMagic                      = 55081226;
input double PYR_InpLot                        = 0.01;
input double PYR_InpL2TriggerR                 = 0.50;
input double PYR_InpL3TriggerR                 = 1.00;
input double PYR_InpCostBufferUSD              = 0.25;
input double PYR_InpMaxRemainingRiskPct        = 10.0;
input bool   PYR_InpExcludeHF08                = true;
input bool   PYR_InpRiskAcrossAllSymbolPos     = true;
input bool   PYR_InpWriteCSV                   = true;

#define V54_HISTORY_ANCHOR_SEC 1767348060 // legacy cache anchor
#define V54_BASELINE_PREHISTORY_SEC 1767218220 // deterministic P812 parity prehistory

CTrade g_trade;

struct SV54PositionState
  {
   bool   open;
   ulong  ticket;
   long   identifier;
   int    src;
   int    side;
   long   signal_msc;
   long   open_msc;
   double entry;
   double risk_price;
   double initial_sl;
   double initial_tp;
   double stop;
   double tp;
   double mfe_r;
  };

SV54PositionState g_pos;
long g_cooldown_until[V54_CONFIG_COUNT];
long g_last_minute_id=-1;
long g_last_processed_bar_sec=0;
long g_current_day=-1;
string g_pending_close_reason="";
double g_last_saved_mfe=-999.0;

int g_h_signals=INVALID_HANDLE;
int g_h_candidates=INVALID_HANDLE;
int g_h_hf12=INVALID_HANDLE;
int g_h_events=INVALID_HANDLE;
int g_h_trades=INVALID_HANDLE;
int g_h_summary=INVALID_HANDLE;

long g_bars_live_processed=0;
long g_union_signals=0;
long g_raw_candidates=0;
long g_regime_candidates=0;
long g_quality_candidates=0;
long g_conflicts=0;
long g_blocked_open=0;
long g_cooldown_skips=0;
long g_actionable=0;
long g_skip_spread=0;
long g_skip_margin=0;
long g_skip_risk=0;
long g_order_fails=0;
long g_fills=0;
long g_trades=0;
long g_wins=0;
long g_losses=0;
double g_gp=0.0;
double g_gl=0.0;
double g_sim_balance=20.0;
double g_max_loss_usd=0.0;
double g_max_loss_r=0.0;
long g_exit_sl=0,g_exit_tp=0,g_exit_tail_cash=0,g_exit_tail_r=0,g_exit_tail_mae=0,g_exit_tail_time=0,g_exit_tail_giveback=0;
long g_exit_base_early=0,g_exit_base_stagn=0,g_exit_base_time=0,g_exit_day=0,g_exit_other=0;

string V54GVPrefix()
  {
   return("ASTRA_P812_HF02X_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+_Symbol+"_"+IntegerToString(InpMagic)+"_");
  }

void V54GVSet(const string key,const double value) { GlobalVariableSet(V54GVPrefix()+key,value); }
bool V54GVGet(const string key,double &value)
  {
   string n=V54GVPrefix()+key; if(!GlobalVariableCheck(n)) return(false); value=GlobalVariableGet(n); return(true);
  }
void V54GVDel(const string key) { string n=V54GVPrefix()+key; if(GlobalVariableCheck(n)) GlobalVariableDel(n); }

void ResetPositionState()
  {
   g_pos.open=false; g_pos.ticket=0; g_pos.identifier=0; g_pos.src=-1; g_pos.side=0;
   g_pos.signal_msc=0; g_pos.open_msc=0; g_pos.entry=0.0; g_pos.risk_price=0.0;
   g_pos.initial_sl=0.0; g_pos.initial_tp=0.0; g_pos.stop=0.0; g_pos.tp=0.0; g_pos.mfe_r=0.0;
   g_last_saved_mfe=-999.0;
  }

void PersistPositionState()
  {
   if(!g_pos.open) { V54GVSet("OPEN",0.0); return; }
   V54GVSet("OPEN",1.0); V54GVSet("SRC",g_pos.src); V54GVSet("SIDE",g_pos.side);
   V54GVSet("SIGNAL_MSC",(double)g_pos.signal_msc); V54GVSet("OPEN_MSC",(double)g_pos.open_msc);
   V54GVSet("ENTRY",g_pos.entry); V54GVSet("RISK",g_pos.risk_price); V54GVSet("ISL",g_pos.initial_sl); V54GVSet("ITP",g_pos.initial_tp);
   V54GVSet("MFE",g_pos.mfe_r); V54GVSet("IDENT",(double)g_pos.identifier);
   g_last_saved_mfe=g_pos.mfe_r;
  }

void ClearPersistedPosition()
  {
   V54GVSet("OPEN",0.0);
   string ks[]={"SRC","SIDE","SIGNAL_MSC","OPEN_MSC","ENTRY","RISK","ISL","ITP","MFE","IDENT"};
   for(int i=0;i<ArraySize(ks);i++) V54GVDel(ks[i]);
  }

void LoadCooldowns()
  {
   ArrayInitialize(g_cooldown_until,0);
   for(int s=0;s<V54_CONFIG_COUNT;s++)
     {
      double z=0.0; if(V54GVGet("CD"+IntegerToString(s),z)) g_cooldown_until[s]=(long)z;
     }
  }

void SaveCooldown(const int src)
  {
   if(src>=0 && src<V54_CONFIG_COUNT) V54GVSet("CD"+IntegerToString(src),(double)g_cooldown_until[src]);
  }

void ClearPersistentRuntimeStateForTester()
  {
   // Strategy Tester runs must start from a clean state. Terminal Global Variables
   // can survive between tester invocations, which would otherwise leak future
   // cooldown/MFE state into a historical replay. Live/demo charts keep state.
   if(!(bool)MQLInfoInteger(MQL_TESTER)) return;
   string keys[]={"OPEN","SRC","SIDE","SIGNAL_MSC","OPEN_MSC","ENTRY","RISK","ISL","ITP","MFE","IDENT"};
   for(int i=0;i<ArraySize(keys);i++) V54GVDel(keys[i]);
   for(int s=0;s<V54_CONFIG_COUNT;s++) V54GVDel("CD"+IntegerToString(s));
  }

bool FindOwnPosition(ulong &ticket)
  {
   ticket=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      ticket=t; return(true);
     }
   return(false);
  }

int ParseSrcFromComment(const string c)
  {
   string key="P812-HF02X-"; int p=StringFind(c,key); if(p<0) return(-1);
   return((int)StringToInteger(StringSubstr(c,p+StringLen(key))));
  }

bool RestorePositionState()
  {
   ulong t=0;
   if(!FindOwnPosition(t)) { ClearPersistedPosition(); ResetPositionState(); return(true); }
   if(!PositionSelectByTicket(t)) return(false);
   double op=0.0; bool has=V54GVGet("OPEN",op) && op>0.5;
   int src=-1,side=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1);
   if(has)
     {
      double z=0.0;
      if(V54GVGet("SRC",z)) src=(int)z;
      g_pos.open=true; g_pos.ticket=t; g_pos.identifier=PositionGetInteger(POSITION_IDENTIFIER); g_pos.src=src; g_pos.side=side;
      if(V54GVGet("SIGNAL_MSC",z)) g_pos.signal_msc=(long)z;
      if(V54GVGet("OPEN_MSC",z)) g_pos.open_msc=(long)z; else g_pos.open_msc=PositionGetInteger(POSITION_TIME_MSC);
      if(V54GVGet("ENTRY",z)) g_pos.entry=z; else g_pos.entry=PositionGetDouble(POSITION_PRICE_OPEN);
      if(V54GVGet("RISK",z)) g_pos.risk_price=z;
      if(V54GVGet("ISL",z)) g_pos.initial_sl=z;
      if(V54GVGet("ITP",z)) g_pos.initial_tp=z;
      if(V54GVGet("MFE",z)) g_pos.mfe_r=z; else g_pos.mfe_r=0.0;
     }
   else
     {
      src=ParseSrcFromComment(PositionGetString(POSITION_COMMENT));
      if(src<0 || src>=V54_CONFIG_COUNT)
        {
         Print("[P812-HF02X][FATAL] Own open position exists but source state cannot be recovered. ticket=",t);
         return(false);
        }
      g_pos.open=true; g_pos.ticket=t; g_pos.identifier=PositionGetInteger(POSITION_IDENTIFIER); g_pos.src=src; g_pos.side=side;
      g_pos.signal_msc=PositionGetInteger(POSITION_TIME_MSC); g_pos.open_msc=PositionGetInteger(POSITION_TIME_MSC);
      g_pos.entry=PositionGetDouble(POSITION_PRICE_OPEN); g_pos.initial_sl=PositionGetDouble(POSITION_SL); g_pos.initial_tp=PositionGetDouble(POSITION_TP);
      g_pos.risk_price=MathAbs(g_pos.entry-g_pos.initial_sl); g_pos.mfe_r=0.0;
      Print("[P812-HF02X][WARN] Position state reconstructed approximately from live position; original MFE unavailable.");
     }
   if(g_pos.src<0 || g_pos.src>=V54_CONFIG_COUNT || g_pos.risk_price<=0.0) return(false);
   g_pos.stop=PositionGetDouble(POSITION_SL); g_pos.tp=PositionGetDouble(POSITION_TP);
   g_current_day=g_pos.open_msc/86400000; PersistPositionState();
   Print("[P812-HF02X][RECOVER] ticket=",g_pos.ticket," family=",V54_FAMILY_NAME[g_pos.src]," entry=",DoubleToString(g_pos.entry,_Digits)," risk=",DoubleToString(g_pos.risk_price,6)," mfeR=",DoubleToString(g_pos.mfe_r,3));
   return(true);
  }

bool TradeRetcodeOK()
  {
   uint r=g_trade.ResultRetcode();
   return(r==TRADE_RETCODE_DONE || r==TRADE_RETCODE_DONE_PARTIAL || r==TRADE_RETCODE_PLACED);
  }

double RoundCents(const double x) { return(MathRound(x*100.0)/100.0); }

int AuditFlags()
  {
   int flags=FILE_WRITE|FILE_CSV|FILE_ANSI; if(InpWriteAuditCommon) flags|=FILE_COMMON; return(flags);
  }

bool OpenAuditFiles()
  {
   int flags=AuditFlags(); string b="ASTRA_P812_HF02X_RAWPASS";
   g_h_signals=FileOpen(b+"_SIGNALS.csv",flags,',');
   g_h_events=FileOpen(b+"_EVENTS.csv",flags,',');
   g_h_trades=FileOpen(b+"_TRADES.csv",flags,',');
   g_h_summary=FileOpen(b+"_SUMMARY.csv",flags,',');
   if(InpWriteCandidateAudit) g_h_candidates=FileOpen(b+"_CANDIDATES.csv",flags,',');
   if(InpWriteCandidateAudit) g_h_hf12=FileOpen(b+"_HF12_AUDIT.csv",flags,',');
   if(g_h_signals==INVALID_HANDLE || g_h_events==INVALID_HANDLE || g_h_trades==INVALID_HANDLE || g_h_summary==INVALID_HANDLE || (InpWriteCandidateAudit && (g_h_candidates==INVALID_HANDLE || g_h_hf12==INVALID_HANDLE)))
     { Print("[P812-HF02X][FATAL] Cannot open audit files err=",GetLastError()); return(false); }
   FileWrite(g_h_signals,"event_no","signal_msc","bar_msc","src","family_id","family","side","atr","raw_candidates","regime_candidates","quality_candidates","conflict","exact_ticks");
   if(g_h_candidates!=INVALID_HANDLE) FileWrite(g_h_candidates,"signal_msc","bar_msc","src","family_id","family","side","atr","candidate_index","quality_complexity","priority_score","chosen","conflict");
   if(g_h_hf12!=INVALID_HANDLE) FileWrite(g_h_hf12,"signal_msc","bar_msc","side","atr","dir_mom5","close_loc","atr_ratio_legacy","atr_ratio_py","thr_dir_mom5_lo","thr_close_loc_lo","thr_close_loc_hi","thr_atr_ratio_lo","quality_pass");
   FileWrite(g_h_events,"event_no","signal_msc","observed_msc","src","family_id","family","side","status","bid","ask","spread","sl","tp","retcode","detail");
   FileWrite(g_h_trades,"trade_no","signal_msc","open_msc","close_msc","src","family_id","family","side","entry","exit","risk_price","initial_sl","initial_tp","mfe_r","python_like_pnl","realized_r","deal_profit","commission","swap","fee","deal_net","close_reason","deal_reason");
   FileWrite(g_h_summary,"profile","bars_live","union_signals","raw_candidates","regime_candidates","quality_candidates","conflicts","fills","trades","wins","losses","python_like_final_balance","account_final_balance","gross_profit","gross_loss","pf","wr","avg_win","avg_loss","loss_to_win","max_loss_usd","max_loss_r","blocked_open","cooldown_skips","actionable","skip_spread","skip_margin","skip_risk","order_fails","exit_sl","exit_tp","exit_tail_cash","exit_tail_r","exit_tail_mae","exit_tail_time","exit_tail_giveback","exit_base_early","exit_base_stagn","exit_base_time","exit_day","exit_other","history_bars","history_first_sec","history_last_sec","exact_tick_bars","tick_fallback_bars","deinit_reason");
   return(true);
  }

void CloseAuditFiles()
  {
   if(g_h_signals!=INVALID_HANDLE) { FileClose(g_h_signals); g_h_signals=INVALID_HANDLE; }
   if(g_h_candidates!=INVALID_HANDLE) { FileClose(g_h_candidates); g_h_candidates=INVALID_HANDLE; }
   if(g_h_hf12!=INVALID_HANDLE) { FileClose(g_h_hf12); g_h_hf12=INVALID_HANDLE; }
   if(g_h_events!=INVALID_HANDLE) { FileClose(g_h_events); g_h_events=INVALID_HANDLE; }
   if(g_h_trades!=INVALID_HANDLE) { FileClose(g_h_trades); g_h_trades=INVALID_HANDLE; }
   if(g_h_summary!=INVALID_HANDLE) { FileClose(g_h_summary); g_h_summary=INVALID_HANDLE; }
  }

bool FindOwnPositionDummy();

string DealReasonText(const long reason)
  {
   switch((ENUM_DEAL_REASON)reason)
     {
      case DEAL_REASON_SL: return("BROKER_SL"); case DEAL_REASON_TP: return("BROKER_TP"); case DEAL_REASON_SO: return("STOP_OUT");
      case DEAL_REASON_EXPERT: return("EXPERT"); case DEAL_REASON_CLIENT: return("CLIENT"); case DEAL_REASON_MOBILE: return("MOBILE"); case DEAL_REASON_WEB: return("WEB");
      default: return("DEAL_REASON_"+IntegerToString(reason));
     }
  }

bool ValidateEnvironment()
  {
   bool ok=true; bool tester=(bool)MQLInfoInteger(MQL_TESTER);
   if(_Symbol!="XAUUSDm") { Print("[P812-HF02X][FATAL] Expected XAUUSDm got ",_Symbol); ok=false; }
   if(_Period!=PERIOD_M1) { Print("[P812-HF02X][FATAL] Attach/test on M1."); ok=false; }
   if(_Digits!=3 || MathAbs(_Point-0.001)>1e-12) { Print("[P812-HF02X][FATAL] Expected digits=3 point=.001"); ok=false; }
   if(AccountInfoInteger(ACCOUNT_LEVERAGE)!=500) { Print("[P812-HF02X][FATAL] Frozen research assumes leverage 1:500."); ok=false; }
   if(InpRequireHedging && (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) { Print("[P812-HF02X][FATAL] Hedging account required."); ok=false; }
   double cs=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); if(MathAbs(cs-100.0)>1e-6) { Print("[P812-HF02X][FATAL] Expected contract size 100 got ",cs); ok=false; }
   if(MathAbs(InpFixedLot-0.01)>1e-12) { Print("[P812-HF02X][FATAL] Frozen lot is 0.01."); ok=false; }
   if(InpRequireBalance20 && MathAbs(AccountInfoDouble(ACCOUNT_BALANCE)-20.0)>0.05 && !FindOwnPositionDummy()) { Print("[P812-HF02X][FATAL] Expected initial balance $20. Current=",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)); ok=false; }
   if(InpDemoOnly && !tester && (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) { Print("[P812-HF02X][FATAL] Demo-only guard is enabled."); ok=false; }
   if(!tester && InpTradeEnabled && (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))) { Print("[P812-HF02X][FATAL] Algo trading is not allowed."); ok=false; }
   return(ok || !InpStrictEnvironment);
  }

bool FindOwnPositionDummy()
  {
   ulong t=0; return(FindOwnPosition(t));
  }

bool WarmupSignalEngine()
  {
   V54ResetSignalEngine();
   datetime current_open=iTime(_Symbol,PERIOD_M1,0);
   if(current_open<=0)
     {
      datetime now=TimeCurrent(); current_open=(datetime)(((long)now/60)*60);
     }

   const bool tester=(bool)MQLInfoInteger(MQL_TESTER);
   long history_start=(InpDeterministicBootstrap ? InpBootstrapHistoryStartSec : (long)V54_HISTORY_ANCHOR_SEC);
   long signal_start =(InpDeterministicBootstrap ? InpFrozenSignalStartSec     : (long)V54_HISTORY_ANCHOR_SEC);

   if(InpDeterministicBootstrap)
     {
      if(history_start<=0 || signal_start<=0 || history_start>signal_start)
        {
         Print("[P812-HF02X][FATAL] Invalid deterministic bootstrap anchors history_start=",history_start,
               " signal_start=",signal_start);
         return(false);
        }
      // A historical parity run must begin no later than the frozen signal start.
      // Otherwise trades between signal_start and the tester's first bar could only be retro-simulated,
      // which this EA deliberately forbids.
      if(tester && (long)current_open>signal_start)
        {
         Print("[P812-HF02X][FATAL] Tester starts after frozen signal anchor. current_open=",(long)current_open,
               " signal_start=",signal_start,
               ". Start the Strategy Tester before the earliest frozen actionable bar.");
         return(false);
        }
     }

   datetime stop=current_open-1;
   if((long)stop<history_start)
     {
      g_last_processed_bar_sec=0;
      g_last_minute_id=(long)current_open/60;
      Print("[P812-HF02X][BOOTSTRAP] no preload required current_open=",(long)current_open,
            " history_start=",history_start," signal_start=",signal_start);
      return(true);
     }

   MqlRates rr[]; ArraySetAsSeries(rr,false);
   ResetLastError();
   int n=CopyRates(_Symbol,PERIOD_M1,(datetime)history_start,stop,rr);
   if(n<=0)
     {
      Print("[P812-HF02X][FATAL] CopyRates deterministic warmup failed history_start=",history_start,
            " stop=",(long)stop," err=",GetLastError());
      return(false);
     }

   int exact_from=MathMax(0,n-MathMax(0,InpWarmupExactBars));
   for(int i=0;i<n;i++)
     {
      SV54Bar f; bool exact=(i>=exact_from);
      if(!V54AppendBar(rr[i],exact,false,f))
        {
         Print("[P812-HF02X][FATAL] warmup append failed at ",TimeToString(rr[i].time));
         return(false);
        }
     }

   g_last_processed_bar_sec=(long)rr[n-1].time;
   g_last_minute_id=(long)current_open/60;
   Print("[P812-HF02X][WARMUP] bars=",n,
         " first=",TimeToString(rr[0].time,TIME_DATE|TIME_MINUTES),
         " last=",TimeToString(rr[n-1].time,TIME_DATE|TIME_MINUTES),
         " exact_tail=",MathMin(n,InpWarmupExactBars),
         " engine_count=",g_v54_bar_count,
         " deterministic=",(InpDeterministicBootstrap?"YES":"NO"),
         " signal_start=",signal_start);

   if(InpStrictEnvironment && (long)rr[0].time!=history_start)
     {
      Print("[P812-HF02X][FATAL] Warmup history did not start at required anchor. got=",(long)rr[0].time,
            " expected=",history_start);
      return(false);
     }

   // The 602-trade P812 control was generated with this prehistory state.
   // Refuse silent state drift when deterministic bootstrap is enabled.
   if(InpDeterministicBootstrap && InpStrictEnvironment && g_v54_history_first_bar!=history_start)
     {
      Print("[P812-HF02X][FATAL] Signal-engine history_first mismatch got=",g_v54_history_first_bar,
            " expected=",history_start);
      return(false);
     }
   return(true);
  }

void CaptureOpenedPosition(const int src,const int side,const long signal_msc,const double risk_price,const double requested_sl,const double requested_tp)
  {
   ulong t=0; if(!FindOwnPosition(t) || !PositionSelectByTicket(t)) return;
   g_pos.open=true; g_pos.ticket=t; g_pos.identifier=PositionGetInteger(POSITION_IDENTIFIER); g_pos.src=src; g_pos.side=side;
   g_pos.signal_msc=signal_msc; g_pos.open_msc=PositionGetInteger(POSITION_TIME_MSC); g_pos.entry=PositionGetDouble(POSITION_PRICE_OPEN);
   g_pos.risk_price=risk_price; g_pos.initial_sl=requested_sl; g_pos.initial_tp=requested_tp; g_pos.stop=PositionGetDouble(POSITION_SL); g_pos.tp=PositionGetDouble(POSITION_TP); g_pos.mfe_r=0.0;
   g_current_day=g_pos.open_msc/86400000; PersistPositionState();
  }

bool CloseOwnPosition(const string reason)
  {
   if(!g_pos.open || !PositionSelectByTicket(g_pos.ticket)) return(false);
   g_pending_close_reason=reason;
   bool ok=g_trade.PositionClose(g_pos.ticket);
   if(!ok || !TradeRetcodeOK()) { if(InpVerbose) Print("[P812-HF02X][CLOSE_FAIL] ",reason," ret=",g_trade.ResultRetcode()," ",g_trade.ResultRetcodeDescription()); g_pending_close_reason=""; return(false); }
   return(true);
  }

bool FindClosingDealForCurrentPosition(ulong &deal_ticket)
  {
   deal_ticket=0;
   if(!g_pos.open || g_pos.identifier<=0) return(false);
   if(!HistorySelectByPosition(g_pos.identifier)) return(false);
   int n=HistoryDealsTotal(); long best_msc=-1;
   for(int i=0;i<n;i++)
     {
      ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
      if(HistoryDealGetInteger(d,DEAL_POSITION_ID)!=g_pos.identifier) continue;
      ENUM_DEAL_ENTRY et=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
      if(et!=DEAL_ENTRY_OUT && et!=DEAL_ENTRY_OUT_BY) continue;
      long tm=HistoryDealGetInteger(d,DEAL_TIME_MSC);
      if(tm<g_pos.open_msc) continue;
      if(tm>best_msc) { best_msc=tm; deal_ticket=d; }
     }
   return(deal_ticket!=0);
  }

bool FinalizeClosedDeal(const ulong deal_ticket)
  {
   if(deal_ticket==0 || !g_pos.open) return(false);
   if(!HistoryDealSelect(deal_ticket)) return(false);
   if(HistoryDealGetString(deal_ticket,DEAL_SYMBOL)!=_Symbol) return(false);
   ENUM_DEAL_ENTRY et=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
   if(et!=DEAL_ENTRY_OUT && et!=DEAL_ENTRY_OUT_BY) return(false);
   long pid=HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID);
   if(pid!=g_pos.identifier) return(false);

   long close_msc=HistoryDealGetInteger(deal_ticket,DEAL_TIME_MSC);
   double exit_price=HistoryDealGetDouble(deal_ticket,DEAL_PRICE);
   double deal_profit=HistoryDealGetDouble(deal_ticket,DEAL_PROFIT);
   double commission=HistoryDealGetDouble(deal_ticket,DEAL_COMMISSION);
   double swap=HistoryDealGetDouble(deal_ticket,DEAL_SWAP);
   double fee=HistoryDealGetDouble(deal_ticket,DEAL_FEE);
   double deal_net=deal_profit+commission+swap+fee;
   int closed_src=g_pos.src;
   if(closed_src==0) { g_pf_hf02x_trades++; g_pf_hf02x_deal_net+=deal_net; }
   else { g_pf_p812_trades++; g_pf_p812_deal_net+=deal_net; }
   long deal_reason=HistoryDealGetInteger(deal_ticket,DEAL_REASON);
   double py_pnl=RoundCents((exit_price-g_pos.entry)*g_pos.side*100.0*InpFixedLot);
   if(closed_src==0) g_pf_hf02x_py_net+=py_pnl; else g_pf_p812_py_net+=py_pnl;
   double realized_r=(g_pos.risk_price>0.0 ? py_pnl/(g_pos.risk_price*100.0*InpFixedLot) : 0.0);

   g_sim_balance=RoundCents(g_sim_balance+py_pnl);
   if(py_pnl>0.0) { g_gp+=py_pnl; g_wins++; }
   else if(py_pnl<0.0)
     {
      double loss=-py_pnl; g_gl+=loss; g_losses++;
      if(loss>g_max_loss_usd) g_max_loss_usd=loss;
      if(-realized_r>g_max_loss_r) g_max_loss_r=-realized_r;
      if(V54_COOLDOWN_TRIGGER_R[g_pos.src]<90.0 && -realized_r>=V54_COOLDOWN_TRIGGER_R[g_pos.src] && V54_COOLDOWN_MIN[g_pos.src]>0.0)
        {
         g_cooldown_until[g_pos.src]=close_msc+(long)MathRound(V54_COOLDOWN_MIN[g_pos.src]*60000.0);
         SaveCooldown(g_pos.src);
        }
     }

   g_trades++;
   string reason=g_pending_close_reason;
   if(reason=="")
     {
      if(deal_reason==DEAL_REASON_SL) reason="BROKER_SL";
      else if(deal_reason==DEAL_REASON_TP) reason="BROKER_TP";
      else if(deal_reason==DEAL_REASON_SO) reason="STOP_OUT";
      else reason="OTHER";
     }
   if(reason=="BROKER_SL") g_exit_sl++;
   else if(reason=="BROKER_TP") g_exit_tp++;
   else if(reason=="TAIL_CASH") g_exit_tail_cash++;
   else if(reason=="TAIL_R") g_exit_tail_r++;
   else if(reason=="TAIL_MAE") g_exit_tail_mae++;
   else if(reason=="TAIL_TIME") g_exit_tail_time++;
   else if(reason=="TAIL_GIVEBACK") g_exit_tail_giveback++;
   else if(reason=="BASE_EARLY") g_exit_base_early++;
   else if(reason=="BASE_STAGN") g_exit_base_stagn++;
   else if(reason=="BASE_TIME") g_exit_base_time++;
   else if(reason=="DAY_EXIT") g_exit_day++;
   else g_exit_other++;

   if(g_h_trades!=INVALID_HANDLE)
     {
      FileWrite(g_h_trades,g_trades,g_pos.signal_msc,g_pos.open_msc,close_msc,g_pos.src,V54_FAMILY_ID[g_pos.src],V54_FAMILY_NAME[g_pos.src],g_pos.side,
                DoubleToString(g_pos.entry,_Digits),DoubleToString(exit_price,_Digits),DoubleToString(g_pos.risk_price,6),DoubleToString(g_pos.initial_sl,_Digits),DoubleToString(g_pos.initial_tp,_Digits),DoubleToString(g_pos.mfe_r,6),DoubleToString(py_pnl,2),DoubleToString(realized_r,6),DoubleToString(deal_profit,2),DoubleToString(commission,2),DoubleToString(swap,2),DoubleToString(fee,2),DoubleToString(deal_net,2),reason,DealReasonText(deal_reason));
      FileFlush(g_h_trades);
     }
   if(InpVerbose) Print("[P812-HF02X][CLOSE] #",g_trades," ",V54_FAMILY_NAME[g_pos.src]," reason=",reason," pnl=",DoubleToString(py_pnl,2)," R=",DoubleToString(realized_r,3));
   g_pending_close_reason="";
   ClearPersistedPosition();
   ResetPositionState();
   return(true);
  }

void ManageOpenPosition(const MqlTick &tick)
  {
   if(!g_pos.open) return;
   if(!PositionSelectByTicket(g_pos.ticket))
     {
      // A broker-side SL/TP can remove the position before OnTradeTransaction is
      // delivered. Never discard g_pos here: doing so loses the closing deal,
      // trade audit and family cooldown. Reconcile the OUT deal from history.
      ulong close_deal=0;
      if(FindClosingDealForCurrentPosition(close_deal)) FinalizeClosedDeal(close_deal);
      return;
     }
   long day=tick.time_msc/86400000;
   if(g_current_day>=0 && day!=g_current_day) { CloseOwnPosition("DAY_EXIT"); return; }
   double px=(g_pos.side==1 ? tick.bid : tick.ask);
   double fav=(px-g_pos.entry)*g_pos.side;
   double rnow=(g_pos.risk_price>0.0 ? fav/g_pos.risk_price : -999.0);
   if(rnow>g_pos.mfe_r)
     {
      g_pos.mfe_r=rnow;
      if(g_pos.mfe_r-g_last_saved_mfe>=0.02) PersistPositionState();
     }
   double age_min=(tick.time_msc-g_pos.open_msc)/60000.0, age_sec=(tick.time_msc-g_pos.open_msc)/1000.0;
   double pnl_cash=fav*100.0*InpFixedLot; int s=g_pos.src;

   // The broker-side SL/TP is already live. Tail exits are only earlier exits.
   if(V54_CASH_CAP_USD[s]>0.0 && pnl_cash<=-V54_CASH_CAP_USD[s]) { CloseOwnPosition("TAIL_CASH"); return; }
   if(V54_R_CAP[s]<90.0 && rnow<=-V54_R_CAP[s]) { CloseOwnPosition("TAIL_R"); return; }
   if(V54_MAE_CUT_R[s]<90.0 && age_sec>=V54_MAE_MIN_AGE_SEC[s] && rnow<=-V54_MAE_CUT_R[s] && g_pos.mfe_r<=V54_MAE_MFE_MAX_R[s]) { CloseOwnPosition("TAIL_MAE"); return; }
   if(V54_TIME_LOSS_MIN[s]>0.0 && age_min>=V54_TIME_LOSS_MIN[s] && rnow<=-V54_TIME_LOSS_R[s] && g_pos.mfe_r<=V54_TIME_LOSS_MFE_MAX_R[s]) { CloseOwnPosition("TAIL_TIME"); return; }
   if(V54_GIVEBACK_START_R[s]<90.0 && g_pos.mfe_r>=V54_GIVEBACK_START_R[s] && rnow<=V54_GIVEBACK_FLOOR_R[s]) { CloseOwnPosition("TAIL_GIVEBACK"); return; }
   if(V54_EARLY_CUT_MIN[s]>0.0 && age_min>=V54_EARLY_CUT_MIN[s] && rnow<=V54_EARLY_CUT_R[s]) { CloseOwnPosition("BASE_EARLY"); return; }
   if(V54_STAGNATION_MIN[s]>0.0 && age_min>=V54_STAGNATION_MIN[s] && g_pos.mfe_r<V54_STAGNATION_MFE_R[s]) { CloseOwnPosition("BASE_STAGN"); return; }
   if(V54_MAX_HOLD[s]>0.0 && age_min>=V54_MAX_HOLD[s]) { CloseOwnPosition("BASE_TIME"); return; }

   double old_stop=PositionGetDouble(POSITION_SL),desired=old_stop;
   if(V54_BE_START[s]<90.0 && rnow>=V54_BE_START[s]) { double z=g_pos.entry+g_pos.side*V54_BE_LOCK[s]*g_pos.risk_price; if((g_pos.side==1&&z>desired)||(g_pos.side==-1&&z<desired)) desired=z; }
   if(V54_LOCK1_START[s]<90.0 && rnow>=V54_LOCK1_START[s]) { double z=g_pos.entry+g_pos.side*V54_LOCK1_PROFIT[s]*g_pos.risk_price; if((g_pos.side==1&&z>desired)||(g_pos.side==-1&&z<desired)) desired=z; }
   if(V54_LOCK2_START[s]<90.0 && rnow>=V54_LOCK2_START[s]) { double z=g_pos.entry+g_pos.side*V54_LOCK2_PROFIT[s]*g_pos.risk_price; if((g_pos.side==1&&z>desired)||(g_pos.side==-1&&z<desired)) desired=z; }
   if(V54_TRAIL_START[s]<90.0 && rnow>=V54_TRAIL_START[s])
     {
      double dist=V54_TRAIL_DIST[s]; if(V54_TIGHTEN_START[s]<90.0 && rnow>=V54_TIGHTEN_START[s]) dist=V54_TIGHTEN_DIST[s];
      double z=px-g_pos.side*dist*g_pos.risk_price; double improve=(z-desired)*g_pos.side; if(improve>=V54_TRAIL_STEP[s]*g_pos.risk_price) desired=z;
     }
   double safe=2.0*_Point; long stops_level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL); double broker_safe=(stops_level+1)*_Point; if(broker_safe>safe) safe=broker_safe;
   if(g_pos.side==1 && desired>px-safe) desired=px-safe; if(g_pos.side==-1 && desired<px+safe) desired=px+safe; desired=NormalizeDouble(desired,_Digits);
   bool improves=(g_pos.side==1 ? desired>old_stop+0.5*_Point : desired<old_stop-0.5*_Point);
   if(improves)
     {
      double cur_tp=PositionGetDouble(POSITION_TP); bool ok=g_trade.PositionModify(g_pos.ticket,desired,cur_tp);
      if(ok && TradeRetcodeOK() && PositionSelectByTicket(g_pos.ticket)) { g_pos.stop=PositionGetDouble(POSITION_SL); PersistPositionState(); }
      else if(InpVerbose) Print("[P812-HF02X][MODIFY_FAIL] src=",s," ret=",g_trade.ResultRetcode()," ",g_trade.ResultRetcodeDescription());
     }
  }

void WriteEvent(const long event_no,const long signal_msc,const long observed_msc,const int src,const int side,const string status,const MqlTick &tick,const double sl,const double tp,const long retcode,const string detail)
  {
   if(g_h_events==INVALID_HANDLE) return;
   FileWrite(g_h_events,event_no,signal_msc,observed_msc,src,V54_FAMILY_ID[src],V54_FAMILY_NAME[src],side,status,
             DoubleToString(tick.bid,_Digits),DoubleToString(tick.ask,_Digits),DoubleToString(tick.ask-tick.bid,_Digits),DoubleToString(sl,_Digits),DoubleToString(tp,_Digits),retcode,detail);
   FileFlush(g_h_events);
  }

void ProcessGeneratedEvent(const long event_no,const long signal_msc,const int src,const int side,const double atr,const MqlTick &tick)
  {
   if(g_pos.open) { g_blocked_open++; WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"BLOCKED_OPEN",tick,0,0,0,""); return; }
   if(AccountInfoDouble(ACCOUNT_BALANCE)<=0.0) { WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"DEAD_BALANCE",tick,0,0,0,""); return; }
   if(tick.time_msc<g_cooldown_until[src]) { g_cooldown_skips++; WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"COOLDOWN",tick,0,0,0,""); return; }
   g_actionable++;
   double spread=tick.ask-tick.bid;
   if(spread<=0.0 || spread>V54_MAX_SPREAD[src]) { g_skip_spread++; WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"SKIP_SPREAD",tick,0,0,0,""); return; }
   if(!MathIsValidNumber(atr) || atr<=0.0) { g_order_fails++; WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"BAD_ATR",tick,0,0,0,""); return; }
   double req=(side==1 ? tick.ask : tick.bid);
   double sd=MathMax(V54_STOP_ATR[src]*atr,MathMax(V54_MIN_STOP[src],spread+2.0*_Point));
   double sl=NormalizeDouble(req-side*sd,_Digits),tp=NormalizeDouble(req+side*V54_RR[src]*sd,_Digits);
   double balance=AccountInfoDouble(ACCOUNT_BALANCE),risk_cash=sd*100.0*InpFixedLot;
   if(risk_cash>balance*InpMaxTradeRiskPct/100.0) { g_skip_risk++; WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"SKIP_RISK",tick,sl,tp,0,""); return; }
   double margin=req*100.0*InpFixedLot/(double)AccountInfoInteger(ACCOUNT_LEVERAGE);
   if(margin>balance*InpMarginCapPct/100.0) { g_skip_margin++; WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"SKIP_MARGIN",tick,sl,tp,0,""); return; }
   if(!InpTradeEnabled) { WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"SIGNAL_ONLY",tick,sl,tp,0,""); return; }
   string comment="P812-HF02X-"+IntegerToString(src);
   ResetLastError(); bool ok=(side==1 ? g_trade.Buy(InpFixedLot,_Symbol,0.0,sl,tp,comment) : g_trade.Sell(InpFixedLot,_Symbol,0.0,sl,tp,comment)); uint ret=g_trade.ResultRetcode();
   if(!ok || !TradeRetcodeOK()) { g_order_fails++; WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"ORDER_FAIL",tick,sl,tp,ret,g_trade.ResultRetcodeDescription()); return; }
   CaptureOpenedPosition(src,side,signal_msc,sd,sl,tp);
   if(!g_pos.open) { g_order_fails++; WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"NO_POSITION_AFTER_ORDER",tick,sl,tp,ret,""); return; }
   g_fills++;
   if(src==0) g_pf_hf02x_fills++; else g_pf_p812_fills++;
   WriteEvent(event_no,signal_msc,tick.time_msc,src,side,"FILLED",tick,sl,tp,ret,"fill="+DoubleToString(g_pos.entry,_Digits)+" open_msc="+IntegerToString(g_pos.open_msc));
  }

bool ProcessNewCompletedBar(const MqlTick &tick)
  {
   MqlRates r[]; ArraySetAsSeries(r,false); int n=CopyRates(_Symbol,PERIOD_M1,1,1,r); if(n!=1) return(false);
   long bt=(long)r[0].time; if(bt<=g_last_processed_bar_sec) return(false);
   // If bars were missed due to terminal/EA downtime, warm them causally but never retro-trade them.
   MqlRates miss[]; ArraySetAsSeries(miss,false);
   int nm=CopyRates(_Symbol,PERIOD_M1,(datetime)(g_last_processed_bar_sec>0 ? g_last_processed_bar_sec+60 : bt),(datetime)bt,miss);
   if(nm<=0) { ArrayResize(miss,1); miss[0]=r[0]; nm=1; }
   for(int i=0;i<nm;i++)
     {
      bool last=(i==nm-1); SV54Bar f; long exact_before=g_v54_exact_tick_bars;
      if(!V54AppendBar(miss[i],true,false,f)) return(false);
      bool exact_used=(g_v54_exact_tick_bars>exact_before);
      g_last_processed_bar_sec=(long)miss[i].time;
      if(!last) continue;
      g_bars_live_processed++;
      if(InpDeterministicBootstrap && (long)miss[i].time<InpFrozenSignalStartSec)
        {
         if(InpVerbose) Print("[P812-HF02X][BOOTSTRAP_ONLY] ",TimeToString(miss[i].time,TIME_DATE|TIME_MINUTES));
         continue;
        }
      if(InpRequireExactSignalTicks && !exact_used)
        {
         if(InpVerbose) Print("[P812-HF02X][SKIP] exact ticks unavailable for signal bar ",TimeToString(miss[i].time,TIME_DATE|TIME_MINUTES));
         continue;
        }
      int csrc[12],cside[12]; double catr[12]; int rawc=0,src=-1,side=0; double atr=0.0; bool conflict=false;
      int regimec=0,qualityc=0;
      int has=V54GenerateUnion(f,src,side,atr,rawc,regimec,qualityc,conflict,csrc,cside,catr);
      g_raw_candidates+=rawc; g_regime_candidates+=regimec; g_quality_candidates+=qualityc; if(conflict) g_conflicts++;
      long signal_msc=tick.time_msc,bar_msc=(long)miss[i].time*1000;
      if(g_h_hf12!=INVALID_HANDLE && g_v55c_hf12_regime_seen)
        {
         FileWrite(g_h_hf12,signal_msc,bar_msc,g_v55c_hf12_side,DoubleToString(g_v55c_hf12_atr,17),
                   DoubleToString(g_v55c_hf12_dir_mom5,17),DoubleToString(g_v55c_hf12_close_loc,17),
                   DoubleToString(g_v55c_hf12_atr_ratio_legacy,17),DoubleToString(g_v55c_hf12_atr_ratio_py,17),
                   DoubleToString(V55C_Q_DIR_MOM5_LO[8],17),DoubleToString(V55C_Q_CLOSE_LOC_LO[8],17),
                   DoubleToString(V55C_Q_CLOSE_LOC_HI[8],17),DoubleToString(V55C_Q_ATR_RATIO_LO[8],17),(g_v55c_hf12_quality_pass?1:0));
         FileFlush(g_h_hf12);
        }
      if(g_h_candidates!=INVALID_HANDLE)
        {
         for(int j=0;j<qualityc && j<12;j++)
            FileWrite(g_h_candidates,signal_msc,bar_msc,csrc[j],V54_FAMILY_ID[csrc[j]],V54_FAMILY_NAME[csrc[j]],cside[j],DoubleToString(catr[j],12),V55C_P812_CANDIDATE_INDEX[csrc[j]],V55C_P812_QUALITY_COMPLEXITY[csrc[j]],DoubleToString(V55C_P812_PRIORITY_SCORE[csrc[j]],3),(has&&csrc[j]==src?1:0),(conflict?1:0));
         FileFlush(g_h_candidates);
        }
      if(!has) continue;
      g_union_signals++;
      if(g_h_signals!=INVALID_HANDLE)
        {
         FileWrite(g_h_signals,g_union_signals,signal_msc,bar_msc,src,V54_FAMILY_ID[src],V54_FAMILY_NAME[src],side,DoubleToString(atr,12),rawc,regimec,qualityc,(conflict?1:0),(exact_used?1:0));
         FileFlush(g_h_signals);
        }
      ProcessGeneratedEvent(g_union_signals,signal_msc,src,side,atr,tick);
     }
   return(true);
  }


// ===== KAGURA G10 PARITY ENGINE (frozen reconstructed rules) =====


input double K_InpFixedLot=0.01;
input long   K_InpMagic=34001001;
input bool   K_InpTradeEnabled=true;
input bool   K_InpG10Enabled=true;
input double K_InpG10RiskCapPct=10.0;
input int    K_InpDailyATRPeriod=14;
input int    K_InpM1ATRPeriod=14;
input double K_InpMinBoxATR=0.30;
input double K_InpMaxBoxATR=1.50;
input double K_InpActivityATRFrac=0.03;
input double K_InpSLBufferDailyATR=0.10;
input int    K_InpBoxStartHour=3;
input int    K_InpBoxEndHour=9;
input int    K_InpTradeEndHour=16;
input int    K_InpForceCloseHour=22;
input bool   K_InpProspectiveAfterFrozenEnd=true;
input bool   K_InpProspectiveSessionCloseGuard=true;
input int    K_InpSessionCloseLeadMinutes=5;
input bool   K_InpDemoOnly=true;
input bool   K_InpRequireHedging=true;
input bool   K_InpVerbose=false;
input bool   K_InpCsvAudit=true;
input bool   K_InpFrozenParityPopulationGuard=true; // historical oracle coverage only; disable for prospective Oct+
input int    K_InpFrozenStartDay=20260120;
input int    K_InpFrozenEndDay=20260923;
input string K_InpCsvPrefix="TRI_KAGURA_G10";

CTrade K_trade;
int K_hATR_D1=INVALID_HANDLE,K_hATR_M1=INVALID_HANDLE;
datetime K_last_m5=0;
int K_day_key=-1;
bool K_day_consumed=false;
int K_fh_summary=INVALID_HANDLE,K_fh_signals=INVALID_HANDLE,K_fh_trades=INVALID_HANDLE,K_fh_g10=INVALID_HANDLE,K_fh_events=INVALID_HANDLE;
long K_cnt_signals=0,K_cnt_g10_accept=0,K_cnt_g10_skip=0,K_cnt_open=0,K_cnt_close=0,K_cnt_order_fail=0;
long K_cnt_session_guard_close=0,K_cnt_session_info_fallback=0;
double K_realized_net=0.0;
datetime K_run_start=0;


string K_TS(datetime t){return TimeToString(t,TIME_DATE|TIME_SECONDS);}
void K_CsvFlushAll(){if(K_fh_summary!=INVALID_HANDLE)FileFlush(K_fh_summary);if(K_fh_signals!=INVALID_HANDLE)FileFlush(K_fh_signals);if(K_fh_trades!=INVALID_HANDLE)FileFlush(K_fh_trades);if(K_fh_g10!=INVALID_HANDLE)FileFlush(K_fh_g10);if(K_fh_events!=INVALID_HANDLE)FileFlush(K_fh_events);}
int K_CsvOpen(string name){return FileOpen(K_InpCsvPrefix+"_"+name+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');}
void K_CsvEvent(string ev,string detail){if(K_fh_events==INVALID_HANDLE)return;FileWrite(K_fh_events,K_TS(TimeCurrent()),ev,detail);FileFlush(K_fh_events);}
bool K_CsvInit(){
 if(!K_InpCsvAudit)return true;
 K_fh_summary=K_CsvOpen("SUMMARY");K_fh_signals=K_CsvOpen("SIGNALS");K_fh_trades=K_CsvOpen("TRADES");K_fh_g10=K_CsvOpen("G10_DECISIONS");K_fh_events=K_CsvOpen("EVENTS");
 if(K_fh_summary==INVALID_HANDLE||K_fh_signals==INVALID_HANDLE||K_fh_trades==INVALID_HANDLE||K_fh_g10==INVALID_HANDLE||K_fh_events==INVALID_HANDLE){PrintFormat("[KAGURA][CSV_FATAL] common=%s err=%d",TerminalInfoString(TERMINAL_COMMONDATA_PATH),GetLastError());return false;}
 FileWrite(K_fh_summary,"metric","value");
 FileWrite(K_fh_signals,"time","day","side","closed_m5_time","closed_m5_close","box_hi","box_lo","box_height","daily_atr","m1_atr","entry_quote","sl","tp","risk_usd","balance","risk_pct","g10_enabled","decision");
 FileWrite(K_fh_trades,"time","event","position_id","deal_ticket","side","volume","price","sl","tp","profit","swap","commission","fee","net","balance","comment");
 FileWrite(K_fh_g10,"time","day","side","risk_usd","balance","risk_pct","cap_pct","decision","reason","box_height","daily_atr","m1_atr");
 FileWrite(K_fh_events,"time","event","detail");K_CsvFlushAll();return true;
}
void K_CsvSummary(){if(K_fh_summary==INVALID_HANDLE)return;
 FileWrite(K_fh_summary,"build","RECONSTRUCTED_FROM_FROZEN_SPEC_CSV2_PARITY_POPULATION");FileWrite(K_fh_summary,"symbol",_Symbol);FileWrite(K_fh_summary,"magic",K_InpMagic);FileWrite(K_fh_summary,"K_run_start",K_TS(K_run_start));FileWrite(K_fh_summary,"run_end",K_TS(TimeCurrent()));
 FileWrite(K_fh_summary,"g10_enabled",K_InpG10Enabled);FileWrite(K_fh_summary,"g10_cap_pct",DoubleToString(K_InpG10RiskCapPct,4));FileWrite(K_fh_summary,"fixed_lot",DoubleToString(K_InpFixedLot,2));FileWrite(K_fh_summary,"frozen_parity_population_guard",K_InpFrozenParityPopulationGuard);
 FileWrite(K_fh_summary,"prospective_after_frozen_end",K_InpProspectiveAfterFrozenEnd);FileWrite(K_fh_summary,"prospective_session_close_guard",K_InpProspectiveSessionCloseGuard);FileWrite(K_fh_summary,"session_close_lead_minutes",K_InpSessionCloseLeadMinutes);FileWrite(K_fh_summary,"session_guard_closes",K_cnt_session_guard_close);FileWrite(K_fh_summary,"session_info_fallbacks",K_cnt_session_info_fallback);
 FileWrite(K_fh_summary,"signals",K_cnt_signals);FileWrite(K_fh_summary,"g10_accept",K_cnt_g10_accept);FileWrite(K_fh_summary,"g10_skip",K_cnt_g10_skip);FileWrite(K_fh_summary,"opens",K_cnt_open);FileWrite(K_fh_summary,"closes",K_cnt_close);FileWrite(K_fh_summary,"order_fail",K_cnt_order_fail);FileWrite(K_fh_summary,"K_realized_net",DoubleToString(K_realized_net,2));FileWrite(K_fh_summary,"final_balance",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));FileWrite(K_fh_summary,"final_equity",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));FileFlush(K_fh_summary);
}
void K_CsvClose(){K_CsvSummary();K_CsvFlushAll();if(K_fh_summary!=INVALID_HANDLE)FileClose(K_fh_summary);if(K_fh_signals!=INVALID_HANDLE)FileClose(K_fh_signals);if(K_fh_trades!=INVALID_HANDLE)FileClose(K_fh_trades);if(K_fh_g10!=INVALID_HANDLE)FileClose(K_fh_g10);if(K_fh_events!=INVALID_HANDLE)FileClose(K_fh_events);}

int K_DayKey(datetime t){ MqlDateTime x; TimeToStruct(t,x); return x.year*10000+x.mon*100+x.day; }
datetime K_DayAt(datetime t,int hour){ MqlDateTime x; TimeToStruct(t,x); x.hour=hour;x.min=0;x.sec=0; return StructToTime(x); }

bool K_OwnPosition(ulong &ticket)
{
 ticket=0;
 for(int i=PositionsTotal()-1;i>=0;i--){ ulong z=PositionGetTicket(i); if(z==0) continue;
  if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==K_InpMagic){ticket=z;return true;}}
 return false;
}

bool K_ATRValue(int handle,int shift,double &v)
{
 double a[]; ArraySetAsSeries(a,true); if(CopyBuffer(handle,0,shift,1,a)!=1) return false; v=a[0]; return MathIsValidNumber(v)&&v>0;
}

bool K_BuildBox(datetime now,double &hi,double &lo)
{
 datetime a=K_DayAt(now,K_InpBoxStartHour), b=K_DayAt(now,K_InpBoxEndHour);
 MqlRates r[]; int n=CopyRates(_Symbol,PERIOD_M5,a,b-1,r); if(n<=0) return false;
 hi=-DBL_MAX;lo=DBL_MAX;
 for(int i=0;i<n;i++){if(r[i].high>hi)hi=r[i].high;if(r[i].low<lo)lo=r[i].low;}
 return hi>lo && hi<DBL_MAX && lo>0;
}

bool K_InitialRiskUSD(int side,double entry,double sl,double &risk)
{
 double p=0; ENUM_ORDER_TYPE typ=(side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
 if(!OrderCalcProfit(typ,_Symbol,K_InpFixedLot,entry,sl,p)) return false;
 risk=MathAbs(p); return MathIsValidNumber(risk)&&risk>0;
}

int K_SecOfDay(datetime t){MqlDateTime x;TimeToStruct(t,x);return x.hour*3600+x.min*60+x.sec;}
datetime K_DayStart(datetime t){MqlDateTime x;TimeToStruct(t,x);x.hour=0;x.min=0;x.sec=0;return StructToTime(x);}
bool K_LatestBrokerSessionClose(datetime now,datetime &session_close)
{
 MqlDateTime cur;TimeToStruct(now,cur);int latest_end=-1;
 for(uint idx=0;idx<16;idx++)
 {
  datetime sf=0,st=0;if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)cur.day_of_week,idx,sf,st))break;
  int a=K_SecOfDay(sf),b=K_SecOfDay(st);if(b==0&&a>0)b=86400;if(b<=a)b+=86400;if(b>latest_end)latest_end=b;
 }
 if(latest_end<0)return false;session_close=K_DayStart(now)+(datetime)latest_end;return true;
}
datetime K_EffectiveForceClose(datetime now,bool &session_guard,datetime &broker_close)
{
 session_guard=false;broker_close=0;datetime configured=K_DayAt(now,K_InpForceCloseHour);int dk=K_DayKey(now);
 if(!K_InpProspectiveSessionCloseGuard||dk<=K_InpFrozenEndDay)return configured;
 if(!K_LatestBrokerSessionClose(now,broker_close)){K_cnt_session_info_fallback++;return configured;}
 datetime guarded=broker_close-(datetime)(K_InpSessionCloseLeadMinutes*60);
 if(guarded<configured){session_guard=true;return guarded;}return configured;
}
void K_ForceCloseIfNeeded(datetime now)
{
 ulong ticket=0;if(!K_OwnPosition(ticket))return;
 bool session_guard=false;datetime broker_close=0;datetime target=K_EffectiveForceClose(now,session_guard,broker_close);
 if(now<target)return;
 K_trade.SetExpertMagicNumber(K_InpMagic);ResetLastError();bool ok=K_trade.PositionClose(ticket);
 if(ok){if(session_guard)K_cnt_session_guard_close++;K_CsvEvent((session_guard?"SESSION_CLOSE_GUARD":"FORCE_CLOSE_REQUEST"),StringFormat("ticket=%I64u now=%s target=%s broker_close=%s lead_min=%d prospective=%s",ticket,K_TS(now),K_TS(target),(broker_close>0?K_TS(broker_close):"NA"),K_InpSessionCloseLeadMinutes,(K_DayKey(now)>K_InpFrozenEndDay?"YES":"NO")));}
 else {K_CsvEvent("FORCE_CLOSE_FAIL",StringFormat("ticket=%I64u now=%s target=%s ret=%u %s",ticket,K_TS(now),K_TS(target),K_trade.ResultRetcode(),K_trade.ResultRetcodeDescription()));if(K_InpVerbose)Print("[KAGURA][FORCE_CLOSE_FAIL] ",K_trade.ResultRetcodeDescription());}
}

void K_EvaluateClosedM5(datetime now)
{
 int dk=K_DayKey(now); if(dk!=K_day_key){K_day_key=dk;K_day_consumed=false;}
 // This is NOT an alpha filter. It reproduces the exact historical population present
 // in PC34_KAGURA_EXACT_RAWTICK_JANSEP_TRADES.csv. The frozen oracle contains data
 // from 2026-01-20 through 2026-09-23 and has no 2026-07-31 observation.
 // Keep this ON only for historical parity. It MUST be OFF for prospective Oct+ trading.
 if(K_InpFrozenParityPopulationGuard)
 {
  if(dk<K_InpFrozenStartDay) return;
  if(dk<=K_InpFrozenEndDay){if(dk==20260731)return;}
  else if(!K_InpProspectiveAfterFrozenEnd) return;
 }
 if(K_day_consumed)return;
 ulong existing=0;if(K_OwnPosition(existing))return;
 datetime trade_start=K_DayAt(now,K_InpBoxEndHour), trade_end=K_DayAt(now,K_InpTradeEndHour);
 if(now<trade_start || now>=trade_end)return;

 MqlRates m5[];ArraySetAsSeries(m5,true);if(CopyRates(_Symbol,PERIOD_M5,1,1,m5)!=1)return;
 double box_hi,box_lo;if(!K_BuildBox(now,box_hi,box_lo))return;
 double datr=0,m1atr=0;if(!K_ATRValue(K_hATR_D1,1,datr)||!K_ATRValue(K_hATR_M1,1,m1atr))return;
 double box=box_hi-box_lo;if(box<K_InpMinBoxATR*datr || box>K_InpMaxBoxATR*datr)return;
 if(m1atr<K_InpActivityATRFrac*datr)return;
 int side=0;if(m5[0].close>box_hi)side=1;else if(m5[0].close<box_lo)side=-1;else return;

 MqlTick q;if(!SymbolInfoTick(_Symbol,q))return;double entry=(side>0?q.ask:q.bid);
 double sl=(side>0?box_lo-K_InpSLBufferDailyATR*datr:box_hi+K_InpSLBufferDailyATR*datr);
 double tp=(side>0?box_hi+box:box_lo-box);
 int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);sl=NormalizeDouble(sl,digits);tp=NormalizeDouble(tp,digits);
 if((side>0 && !(sl<entry && tp>entry)) || (side<0 && !(sl>entry && tp<entry)))return;

 double risk=0;if(!K_InitialRiskUSD(side,entry,sl,risk))return;
 double bal=AccountInfoDouble(ACCOUNT_BALANCE);double risk_pct=(bal>0?100.0*risk/bal:DBL_MAX);
 K_cnt_signals++;
 if(PortfolioPrimaryActive() && g_pos.open) { g_pf_overlap_signals++; if(g_pos.side==side) g_pf_same_side++; else g_pf_opposite_side++; K_CsvEvent("PORTFOLIO_OVERLAP",StringFormat("p812_src=%d p812_side=%d kagura_side=%d",g_pos.src,g_pos.side,side)); }
 string decision=(K_InpG10Enabled && risk_pct>K_InpG10RiskCapPct?"SKIP_G10":(K_InpTradeEnabled?"ACCEPT":"SIGNAL_ONLY"));
 if(K_fh_signals!=INVALID_HANDLE){FileWrite(K_fh_signals,K_TS(now),dk,(side>0?"BUY":"SELL"),K_TS(m5[0].time),m5[0].close,box_hi,box_lo,box,datr,m1atr,entry,sl,tp,risk,bal,risk_pct,K_InpG10Enabled,decision);FileFlush(K_fh_signals);}
 if(K_InpG10Enabled && risk_pct>K_InpG10RiskCapPct){K_cnt_g10_skip++;if(K_fh_g10!=INVALID_HANDLE){FileWrite(K_fh_g10,K_TS(now),dk,(side>0?"BUY":"SELL"),risk,bal,risk_pct,K_InpG10RiskCapPct,"SKIP","RISK_CAP",box,datr,m1atr);FileFlush(K_fh_g10);}K_day_consumed=true;PrintFormat("[KAGURA][G10_SKIP] day=%d side=%d risk=%.2f bal=%.2f risk_pct=%.4f box=%.3f datr=%.3f m1atr=%.3f",dk,side,risk,bal,risk_pct,box,datr,m1atr);return;}
 K_cnt_g10_accept++;if(K_fh_g10!=INVALID_HANDLE){FileWrite(K_fh_g10,K_TS(now),dk,(side>0?"BUY":"SELL"),risk,bal,risk_pct,K_InpG10RiskCapPct,"ACCEPT",(K_InpG10Enabled?"WITHIN_CAP":"G10_OFF"),box,datr,m1atr);FileFlush(K_fh_g10);}
 if(!K_InpTradeEnabled){K_day_consumed=true;PrintFormat("[KAGURA][SIGNAL_ONLY] day=%d side=%d risk_pct=%.4f",dk,side,risk_pct);return;}

 K_trade.SetExpertMagicNumber(K_InpMagic);K_trade.SetTypeFillingBySymbol(_Symbol);K_trade.SetDeviationInPoints(50);
 string c="PC34-KAGURA-G10";bool ok=(side>0?K_trade.Buy(K_InpFixedLot,_Symbol,0,sl,tp,c):K_trade.Sell(K_InpFixedLot,_Symbol,0,sl,tp,c));
 K_day_consumed=true;
 if(ok){K_cnt_open++;K_CsvEvent("OPEN_REQUEST_OK",StringFormat("day=%d side=%d price=%.3f sl=%.3f tp=%.3f",dk,side,K_trade.ResultPrice(),sl,tp));PrintFormat("[KAGURA][OPEN] day=%d side=%d entry=%.3f sl=%.3f tp=%.3f risk=%.2f bal=%.2f risk_pct=%.4f",dk,side,K_trade.ResultPrice(),sl,tp,risk,bal,risk_pct);}
 else {K_cnt_order_fail++;K_CsvEvent("ORDER_FAIL",StringFormat("day=%d side=%d ret=%u %s",dk,side,K_trade.ResultRetcode(),K_trade.ResultRetcodeDescription()));PrintFormat("[KAGURA][ORDER_FAIL] day=%d side=%d ret=%u %s",dk,side,K_trade.ResultRetcode(),K_trade.ResultRetcodeDescription());}
}

int K_OnInit()
{
 if(K_InpDemoOnly && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL){Print("[KAGURA][FATAL] REAL account blocked");return INIT_FAILED;}
 if(K_InpRequireHedging && AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){Print("[KAGURA][FATAL] hedging account required");return INIT_FAILED;}
 K_hATR_D1=iATR(_Symbol,PERIOD_D1,K_InpDailyATRPeriod);K_hATR_M1=iATR(_Symbol,PERIOD_M1,K_InpM1ATRPeriod);
 if(K_hATR_D1==INVALID_HANDLE||K_hATR_M1==INVALID_HANDLE)return INIT_FAILED;
 K_trade.SetExpertMagicNumber(K_InpMagic);K_run_start=TimeCurrent();if(!K_CsvInit())return INIT_FAILED;K_CsvEvent("INIT",StringFormat("magic=%I64d G10=%s cap=%.2f lot=%.2f common=%s",K_InpMagic,(K_InpG10Enabled?"ON":"OFF"),K_InpG10RiskCapPct,K_InpFixedLot,TerminalInfoString(TERMINAL_COMMONDATA_PATH)));
 PrintFormat("[KAGURA][READY] RECONSTRUCTED_FROM_FROZEN_SPEC_CSV2 magic=%I64d G10=%s cap=%.2f%% lot=%.2f CSV=%s COMMON=%s",K_InpMagic,(K_InpG10Enabled?"ON":"OFF"),K_InpG10RiskCapPct,K_InpFixedLot,(K_InpCsvAudit?"ON":"OFF"),TerminalInfoString(TERMINAL_COMMONDATA_PATH));
 return INIT_SUCCEEDED;
}
void K_OnDeinit(const int reason){K_CsvEvent("DEINIT",StringFormat("reason=%d",reason));K_CsvClose();if(K_hATR_D1!=INVALID_HANDLE)IndicatorRelease(K_hATR_D1);if(K_hATR_M1!=INVALID_HANDLE)IndicatorRelease(K_hATR_M1);}
void K_OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
 if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0)return;
 if(!HistoryDealSelect(trans.deal))return;
 if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol)return;
 if((long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=K_InpMagic)return;
 long entry=(long)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
 long typ=(long)HistoryDealGetInteger(trans.deal,DEAL_TYPE);
 string side=(typ==DEAL_TYPE_BUY?"BUY":(typ==DEAL_TYPE_SELL?"SELL":"OTHER"));
 double vol=HistoryDealGetDouble(trans.deal,DEAL_VOLUME),price=HistoryDealGetDouble(trans.deal,DEAL_PRICE),profit=HistoryDealGetDouble(trans.deal,DEAL_PROFIT),swap=HistoryDealGetDouble(trans.deal,DEAL_SWAP),comm=HistoryDealGetDouble(trans.deal,DEAL_COMMISSION),fee=HistoryDealGetDouble(trans.deal,DEAL_FEE),net=profit+swap+comm+fee;
 ulong posid=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);string comment=HistoryDealGetString(trans.deal,DEAL_COMMENT);string ev=(entry==DEAL_ENTRY_IN?"DEAL_IN":(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY?"DEAL_OUT":"DEAL_OTHER"));
 if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY){K_cnt_close++;K_realized_net+=net;}
 if(K_fh_trades!=INVALID_HANDLE){FileWrite(K_fh_trades,K_TS((datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME)),ev,posid,trans.deal,side,vol,price,0,0,profit,swap,comm,fee,net,AccountInfoDouble(ACCOUNT_BALANCE),comment);FileFlush(K_fh_trades);}
}

void K_OnTick()
{
 datetime now=TimeCurrent();K_ForceCloseIfNeeded(now);
 datetime cur=iTime(_Symbol,PERIOD_M5,0);if(cur<=0||cur==K_last_m5)return;K_last_m5=cur;K_EvaluateClosedM5(now);
}
// ===== END KAGURA ENGINE =====


// ===== LBMA PM 4-MINUTE IMPULSE REVERSAL SLEEVE =====
// Frozen research candidate:
//   15:00 Europe/London benchmark event, observe first 4 minutes.
//   |impulse| >= 10 bps => fade; fixed 0.01; hard SL distance 2.50;
//   no fixed TP; force time-exit after 20 minutes; max spread 0.75;
//   admit only when initial SL risk <= 10% of realized account balance.
// This block is additive only. It MUST NOT mutate P812/HF02X/KAGURA rules.

input double LB_InpFixedLot=0.01;
input long   LB_InpMagic=55081204;
input bool   LB_InpTradeEnabled=true;
input double LB_InpRiskCapPct=10.0;
input double LB_InpImpulseThresholdBps=10.0;
input int    LB_InpObserveMinutes=4;
input double LB_InpSLDistance=2.50;
input double LB_InpMaxHoldMinutes=20.0;
input double LB_InpMaxSpread=0.75;
input int    LB_InpStartCaptureWindowSec=10; // first valid tick at/after event boundary, frozen raw convention
input int    LB_InpInvalidStopsRetries=2;
input int    LB_InpServerUTCOffsetMinutes=0; // Exness trial parity assumption; historical tester timestamps are UTC-aligned.
input bool   LB_InpDemoOnly=true;
input bool   LB_InpRequireHedging=true;
input bool   LB_InpCsvAudit=true;
input bool   LB_InpVerbose=false;
input bool   LB_InpFrozenParityPopulationGuard=true;
input bool   LB_InpProspectiveAfterFrozenEnd=true; // historical raw research coverage only; OFF prospective/live.
input int    LB_InpFrozenStartDay=20260102;
input int    LB_InpFrozenEndDay=20260923;
input string LB_InpCsvPrefix="QUAD_LBMA_PM4R";

CTrade LB_trade;
int LB_fh_summary=INVALID_HANDLE,LB_fh_signals=INVALID_HANDLE,LB_fh_trades=INVALID_HANDLE,LB_fh_events=INVALID_HANDLE;
long LB_cnt_observations=0,LB_cnt_signals=0,LB_cnt_spread_skip=0,LB_cnt_risk_accept=0,LB_cnt_risk_skip=0;
long LB_cnt_open=0,LB_cnt_close=0,LB_cnt_order_fail=0,LB_cnt_missed_start=0;
long LB_overlap_primary=0,LB_overlap_kagura=0,LB_primary_same=0,LB_primary_opposite=0,LB_kagura_same=0,LB_kagura_opposite=0;
double LB_realized_net=0.0;
int LB_day_key=-1;
bool LB_start_captured=false,LB_day_consumed=false;
double LB_start_bid=0.0;
long LB_start_msc=0;

string LB_TS(datetime t){return TimeToString(t,TIME_DATE|TIME_SECONDS);}
int LB_CsvOpen(string name){return FileOpen(LB_InpCsvPrefix+"_"+name+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');}
void LB_CsvFlushAll(){if(LB_fh_summary!=INVALID_HANDLE)FileFlush(LB_fh_summary);if(LB_fh_signals!=INVALID_HANDLE)FileFlush(LB_fh_signals);if(LB_fh_trades!=INVALID_HANDLE)FileFlush(LB_fh_trades);if(LB_fh_events!=INVALID_HANDLE)FileFlush(LB_fh_events);}
void LB_CsvEvent(string ev,string detail){if(LB_fh_events==INVALID_HANDLE)return;FileWrite(LB_fh_events,LB_TS(TimeCurrent()),ev,detail);FileFlush(LB_fh_events);}

bool LB_CsvInit()
{
 if(!LB_InpCsvAudit)return true;
 LB_fh_summary=LB_CsvOpen("SUMMARY");LB_fh_signals=LB_CsvOpen("SIGNALS");LB_fh_trades=LB_CsvOpen("TRADES");LB_fh_events=LB_CsvOpen("EVENTS");
 if(LB_fh_summary==INVALID_HANDLE||LB_fh_signals==INVALID_HANDLE||LB_fh_trades==INVALID_HANDLE||LB_fh_events==INVALID_HANDLE){PrintFormat("[LBMA][CSV_FATAL] common=%s err=%d",TerminalInfoString(TERMINAL_COMMONDATA_PATH),GetLastError());return false;}
 FileWrite(LB_fh_summary,"metric","value");
 FileWrite(LB_fh_signals,"time","day","event_start","event_end","london_dst","start_bid","end_bid","impulse_bps","side","spread","entry_quote","sl","risk_usd","balance","risk_pct","decision","primary_open","kagura_open");
 FileWrite(LB_fh_trades,"time","event","position_id","deal_ticket","side","volume","price","profit","swap","commission","fee","net","balance","deal_reason","comment");
 FileWrite(LB_fh_events,"time","event","detail");LB_CsvFlushAll();return true;
}

void LB_CsvSummary()
{
 if(LB_fh_summary==INVALID_HANDLE)return;
 FileWrite(LB_fh_summary,"build","LBMA_PM4R_RAW_SLEEVE_V1_MT5");
 FileWrite(LB_fh_summary,"symbol",_Symbol);FileWrite(LB_fh_summary,"magic",LB_InpMagic);
 FileWrite(LB_fh_summary,"fixed_lot",DoubleToString(LB_InpFixedLot,2));
 FileWrite(LB_fh_summary,"impulse_threshold_bps",DoubleToString(LB_InpImpulseThresholdBps,4));
 FileWrite(LB_fh_summary,"observe_minutes",LB_InpObserveMinutes);
 FileWrite(LB_fh_summary,"sl_distance",DoubleToString(LB_InpSLDistance,3));
 FileWrite(LB_fh_summary,"max_hold_minutes",DoubleToString(LB_InpMaxHoldMinutes,2));
 FileWrite(LB_fh_summary,"max_spread",DoubleToString(LB_InpMaxSpread,3));
 FileWrite(LB_fh_summary,"risk_cap_pct",DoubleToString(LB_InpRiskCapPct,4));
 FileWrite(LB_fh_summary,"server_utc_offset_minutes",LB_InpServerUTCOffsetMinutes);FileWrite(LB_fh_summary,"boundary_mode","FIRST_VALID_TICK_AT_OR_AFTER");FileWrite(LB_fh_summary,"impulse_price_mode","BID");FileWrite(LB_fh_summary,"start_capture_window_sec",LB_InpStartCaptureWindowSec);
 FileWrite(LB_fh_summary,"frozen_parity_population_guard",LB_InpFrozenParityPopulationGuard);FileWrite(LB_fh_summary,"prospective_after_frozen_end",LB_InpProspectiveAfterFrozenEnd);
 FileWrite(LB_fh_summary,"observations",LB_cnt_observations);FileWrite(LB_fh_summary,"signals",LB_cnt_signals);
 FileWrite(LB_fh_summary,"spread_skip",LB_cnt_spread_skip);FileWrite(LB_fh_summary,"risk_accept",LB_cnt_risk_accept);FileWrite(LB_fh_summary,"risk_skip",LB_cnt_risk_skip);
 FileWrite(LB_fh_summary,"opens",LB_cnt_open);FileWrite(LB_fh_summary,"closes",LB_cnt_close);FileWrite(LB_fh_summary,"order_fail",LB_cnt_order_fail);FileWrite(LB_fh_summary,"missed_start",LB_cnt_missed_start);
 FileWrite(LB_fh_summary,"realized_net",DoubleToString(LB_realized_net,2));
 FileWrite(LB_fh_summary,"signal_while_primary_open",LB_overlap_primary);FileWrite(LB_fh_summary,"signal_while_kagura_open",LB_overlap_kagura);
 FileWrite(LB_fh_summary,"primary_same_side",LB_primary_same);FileWrite(LB_fh_summary,"primary_opposite_side",LB_primary_opposite);
 FileWrite(LB_fh_summary,"kagura_same_side",LB_kagura_same);FileWrite(LB_fh_summary,"kagura_opposite_side",LB_kagura_opposite);
 FileWrite(LB_fh_summary,"final_balance",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));FileWrite(LB_fh_summary,"final_equity",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));FileFlush(LB_fh_summary);
}
void LB_CsvClose(){LB_CsvSummary();LB_CsvFlushAll();if(LB_fh_summary!=INVALID_HANDLE)FileClose(LB_fh_summary);if(LB_fh_signals!=INVALID_HANDLE)FileClose(LB_fh_signals);if(LB_fh_trades!=INVALID_HANDLE)FileClose(LB_fh_trades);if(LB_fh_events!=INVALID_HANDLE)FileClose(LB_fh_events);LB_fh_summary=LB_fh_signals=LB_fh_trades=LB_fh_events=INVALID_HANDLE;}

int LB_DaysInMonth(int y,int m)
{
 if(m==2){bool leap=((y%4==0&&y%100!=0)||(y%400==0));return(leap?29:28);}
 if(m==4||m==6||m==9||m==11)return 30;
 return 31;
}
datetime LB_LastSundayUTC(int y,int m)
{
 MqlDateTime x;ZeroMemory(x);x.year=y;x.mon=m;x.day=LB_DaysInMonth(y,m);x.hour=1;
 datetime t=StructToTime(x);MqlDateTime z;TimeToStruct(t,z);return(t-(datetime)(z.day_of_week*86400));
}
bool LB_LondonDSTFromUTC(datetime utc)
{
 MqlDateTime x;TimeToStruct(utc,x);
 datetime start=LB_LastSundayUTC(x.year,3),finish=LB_LastSundayUTC(x.year,10);
 return(utc>=start&&utc<finish);
}
datetime LB_UTCFromServer(datetime server_time){return(server_time-(datetime)(LB_InpServerUTCOffsetMinutes*60));}
int LB_DayKey(datetime server_time)
{
 datetime utc=LB_UTCFromServer(server_time);MqlDateTime x;TimeToStruct(utc,x);return(x.year*10000+x.mon*100+x.day);
}
datetime LB_EventStartServer(datetime server_now)
{
 datetime utc=LB_UTCFromServer(server_now);MqlDateTime x;TimeToStruct(utc,x);
 bool dst=LB_LondonDSTFromUTC(utc);x.hour=(dst?14:15);x.min=0;x.sec=0;
 datetime event_utc=StructToTime(x);return(event_utc+(datetime)(LB_InpServerUTCOffsetMinutes*60));
}

bool LB_OwnPosition(ulong &ticket)
{
 ticket=0;
 for(int i=PositionsTotal()-1;i>=0;i--){ulong z=PositionGetTicket(i);if(z==0)continue;if(PositionGetString(POSITION_SYMBOL)==_Symbol&&PositionGetInteger(POSITION_MAGIC)==LB_InpMagic){ticket=z;return true;}}
 return false;
}
bool LB_InitialRiskUSD(int side,double entry,double sl,double &risk)
{
 double p=0;ENUM_ORDER_TYPE typ=(side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
 if(!OrderCalcProfit(typ,_Symbol,LB_InpFixedLot,entry,sl,p))return false;
 risk=MathAbs(p);return(MathIsValidNumber(risk)&&risk>0);
}
void LB_ResetDay(int dk){LB_day_key=dk;LB_start_captured=false;LB_day_consumed=false;LB_start_bid=0.0;LB_start_msc=0;}

void LB_RecordOverlap(int side,bool &primary_open,bool &kagura_open)
{
 primary_open=false;kagura_open=false;
 if(PortfolioPrimaryActive()&&g_pos.open){primary_open=true;LB_overlap_primary++;if(g_pos.side==side)LB_primary_same++;else LB_primary_opposite++;}
 ulong kt=0;if(PortfolioKaguraActive()&&K_OwnPosition(kt)){kagura_open=true;LB_overlap_kagura++;if(PositionSelectByTicket(kt)){int ks=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1);if(ks==side)LB_kagura_same++;else LB_kagura_opposite++;}}
}

void LB_ManageOpenPosition(const MqlTick &q)
{
 ulong ticket=0;if(!LB_OwnPosition(ticket)||!PositionSelectByTicket(ticket))return;
 long open_msc=(long)PositionGetInteger(POSITION_TIME_MSC);if(open_msc<=0)open_msc=(long)PositionGetInteger(POSITION_TIME)*1000;
 double age_min=(q.time_msc-open_msc)/60000.0;
 if(age_min<LB_InpMaxHoldMinutes)return;
 LB_trade.SetExpertMagicNumber(LB_InpMagic);
 if(LB_trade.PositionClose(ticket)){LB_CsvEvent("TIME_EXIT_REQUEST",StringFormat("ticket=%I64u age_min=%.3f",ticket,age_min));}
 else {LB_CsvEvent("TIME_EXIT_FAIL",StringFormat("ticket=%I64u ret=%u %s",ticket,LB_trade.ResultRetcode(),LB_trade.ResultRetcodeDescription()));}
}

void LB_EvaluateEvent(const MqlTick &q,datetime event_start)
{
 if(LB_day_consumed||!LB_start_captured)return;
 long event_end_msc=((long)event_start+LB_InpObserveMinutes*60)*1000;
 if(q.time_msc<event_end_msc)return;

 // Frozen raw research convention:
 //   start = BID from first valid tick at/after event_start
 //   end   = BID from first valid tick at/after event_start + 4 minutes
 // This is causal and matches the original tick simulator's boundary selection.
 LB_day_consumed=true;LB_cnt_observations++;
 double end_bid=q.bid;
 if(LB_start_bid<=0.0||end_bid<=0.0)return;
 double bps=(end_bid/LB_start_bid-1.0)*10000.0;
 LB_CsvEvent("BOUNDARY_QUOTES",StringFormat("day=%d start_target=%I64d start_tick=%I64d end_target=%I64d end_tick=%I64d start_bid=%.6f end_bid=%.6f bps=%.9f",
             LB_day_key,(long)event_start*1000,LB_start_msc,event_end_msc,q.time_msc,LB_start_bid,end_bid,bps));

 if(MathAbs(bps)+1e-12<LB_InpImpulseThresholdBps){LB_CsvEvent("NO_TRIGGER",StringFormat("day=%d bps=%.9f",LB_day_key,bps));return;}
 int side=(bps>0.0?-1:1);LB_cnt_signals++;

 double spread=q.ask-q.bid;double entry=(side>0?q.ask:q.bid);double sl=NormalizeDouble(entry-side*LB_InpSLDistance,_Digits);
 double risk=0,balance=AccountInfoDouble(ACCOUNT_BALANCE),risk_pct=DBL_MAX;
 if(LB_InitialRiskUSD(side,entry,sl,risk)&&balance>0)risk_pct=100.0*risk/balance;

 bool primary_open=false,kagura_open=false;LB_RecordOverlap(side,primary_open,kagura_open);
 string decision="ACCEPT";
 if(spread<=0||spread>LB_InpMaxSpread){LB_cnt_spread_skip++;decision="SKIP_SPREAD";}
 else if(!MathIsValidNumber(risk)||risk<=0){LB_cnt_order_fail++;decision="BAD_RISK";}
 else if(risk_pct>LB_InpRiskCapPct){LB_cnt_risk_skip++;decision="SKIP_RISK";}
 else {LB_cnt_risk_accept++;if(!LB_InpTradeEnabled)decision="SIGNAL_ONLY";}

 if(LB_fh_signals!=INVALID_HANDLE)
   {
    FileWrite(LB_fh_signals,LB_TS(TimeCurrent()),LB_day_key,LB_TS(event_start),
              LB_TS((datetime)((long)event_start+LB_InpObserveMinutes*60)),
              LB_LondonDSTFromUTC(LB_UTCFromServer(event_start)),
              LB_start_bid,end_bid,bps,(side>0?"BUY":"SELL"),spread,entry,sl,risk,balance,risk_pct,decision,primary_open,kagura_open);
    FileFlush(LB_fh_signals);
   }
 if(decision!="ACCEPT")return;

 LB_trade.SetExpertMagicNumber(LB_InpMagic);LB_trade.SetTypeFillingBySymbol(_Symbol);LB_trade.SetDeviationInPoints(50);
 string c="LBMA-PM4R"; bool ok=false; uint ret=0; double fill=0,final_sl=0; ulong ticket=0;
 for(int a=0;a<=LB_InpInvalidStopsRetries;a++)
   {
    MqlTick oq;if(!SymbolInfoTick(_Symbol,oq))break;
    double rq=(side>0?oq.ask:oq.bid),esl=NormalizeDouble(rq-side*LB_InpSLDistance,_Digits);
    ResetLastError();
    ok=(side>0?LB_trade.Buy(LB_InpFixedLot,_Symbol,0,esl,0,c):LB_trade.Sell(LB_InpFixedLot,_Symbol,0,esl,0,c));
    ret=LB_trade.ResultRetcode();
    if(ok)break;
    if(ret!=TRADE_RETCODE_INVALID_STOPS)break;
    LB_CsvEvent("INVALID_STOPS_RETRY",StringFormat("day=%d side=%d attempt=%d quote=%.3f sl=%.3f",LB_day_key,side,a,rq,esl));
   }
 if(ok && LB_OwnPosition(ticket) && PositionSelectByTicket(ticket))
   {
    LB_cnt_open++;fill=PositionGetDouble(POSITION_PRICE_OPEN);final_sl=NormalizeDouble(fill-side*LB_InpSLDistance,_Digits);
    MqlTick nq;bool safe=SymbolInfoTick(_Symbol,nq);double px=(side>0?nq.bid:nq.ask);
    if(!safe || (side>0?px<=final_sl:px>=final_sl) || !LB_trade.PositionModify(ticket,final_sl,0))
      {
       LB_CsvEvent("SL_REALIGN_FAIL",StringFormat("day=%d side=%d fill=%.3f target_sl=%.3f ret=%u %s",LB_day_key,side,fill,final_sl,LB_trade.ResultRetcode(),LB_trade.ResultRetcodeDescription()));
       LB_trade.PositionClose(ticket);
      }
    else LB_CsvEvent("SL_REALIGN_OK",StringFormat("day=%d side=%d fill=%.3f final_sl=%.3f",LB_day_key,side,fill,final_sl));
   }
 else
   {
    LB_cnt_order_fail++;
    LB_CsvEvent("ORDER_FAIL",StringFormat("day=%d side=%d ret=%u %s",LB_day_key,side,ret,LB_trade.ResultRetcodeDescription()));
   }
}

int LB_OnInit()
{
 if(LB_InpDemoOnly&&AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL){Print("[LBMA][FATAL] REAL account blocked");return INIT_FAILED;}
 if(LB_InpRequireHedging&&AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){Print("[LBMA][FATAL] hedging account required");return INIT_FAILED;}
 if(MathAbs(LB_InpFixedLot-0.01)>1e-12||LB_InpImpulseThresholdBps<=0||LB_InpObserveMinutes<=0||LB_InpSLDistance<=0||LB_InpMaxHoldMinutes<=0||LB_InpRiskCapPct<=0||LB_InpStartCaptureWindowSec<=0){Print("[LBMA][FATAL] invalid frozen inputs");return INIT_FAILED;}
 LB_trade.SetExpertMagicNumber(LB_InpMagic);LB_trade.SetTypeFillingBySymbol(_Symbol);LB_trade.SetDeviationInPoints(50);
 if(!LB_CsvInit())return INIT_FAILED;
 PrintFormat("[LBMA][READY] PM4R threshold=%.2f bps observe=%dm SL=%.2f hold=%.1fm cap=%.2f%% spread<=%.2f magic=%I64d",LB_InpImpulseThresholdBps,LB_InpObserveMinutes,LB_InpSLDistance,LB_InpMaxHoldMinutes,LB_InpRiskCapPct,LB_InpMaxSpread,LB_InpMagic);
 return INIT_SUCCEEDED;
}
void LB_OnDeinit(const int reason){LB_CsvEvent("DEINIT",StringFormat("reason=%d",reason));LB_CsvClose();}

void LB_OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
 if(trans.type!=TRADE_TRANSACTION_DEAL_ADD||trans.deal==0)return;if(!HistoryDealSelect(trans.deal))return;
 if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol||(long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=LB_InpMagic)return;
 long entry=(long)HistoryDealGetInteger(trans.deal,DEAL_ENTRY),typ=(long)HistoryDealGetInteger(trans.deal,DEAL_TYPE);
 string side=(typ==DEAL_TYPE_BUY?"BUY":(typ==DEAL_TYPE_SELL?"SELL":"OTHER"));string ev=(entry==DEAL_ENTRY_IN?"DEAL_IN":(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY?"DEAL_OUT":"DEAL_OTHER"));
 double vol=HistoryDealGetDouble(trans.deal,DEAL_VOLUME),price=HistoryDealGetDouble(trans.deal,DEAL_PRICE),profit=HistoryDealGetDouble(trans.deal,DEAL_PROFIT),swap=HistoryDealGetDouble(trans.deal,DEAL_SWAP),comm=HistoryDealGetDouble(trans.deal,DEAL_COMMISSION),fee=HistoryDealGetDouble(trans.deal,DEAL_FEE),net=profit+swap+comm+fee;
 if(entry==DEAL_ENTRY_OUT||entry==DEAL_ENTRY_OUT_BY){LB_cnt_close++;LB_realized_net+=net;}
 if(LB_fh_trades!=INVALID_HANDLE){FileWrite(LB_fh_trades,LB_TS((datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME)),ev,(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID),trans.deal,side,vol,price,profit,swap,comm,fee,net,AccountInfoDouble(ACCOUNT_BALANCE),(long)HistoryDealGetInteger(trans.deal,DEAL_REASON),HistoryDealGetString(trans.deal,DEAL_COMMENT));FileFlush(LB_fh_trades);}
}

void LB_OnTick()
{
 MqlTick q;if(!SymbolInfoTick(_Symbol,q))return;
 LB_ManageOpenPosition(q);

 datetime now=TimeCurrent();int dk=LB_DayKey(now);
 if(dk!=LB_day_key)LB_ResetDay(dk);
 if(LB_InpFrozenParityPopulationGuard){if(dk<LB_InpFrozenStartDay)return;if(dk>LB_InpFrozenEndDay&&!LB_InpProspectiveAfterFrozenEnd)return;}
 if(LB_day_consumed)return;

 datetime event_start=LB_EventStartServer(now);
 long event_start_msc=(long)event_start*1000;

 if(!LB_start_captured)
   {
    if(q.time_msc<event_start_msc)return;
    if(q.time_msc>event_start_msc+(long)LB_InpStartCaptureWindowSec*1000)
      {
       LB_day_consumed=true;LB_cnt_missed_start++;
       LB_CsvEvent("MISSED_EVENT_START",StringFormat("day=%d first_msc=%I64d expected=%I64d",dk,q.time_msc,event_start_msc));
       return;
      }
    if(q.bid<=0.0||q.ask<=0.0||q.ask<q.bid)return;
    LB_start_captured=true;LB_start_bid=q.bid;LB_start_msc=q.time_msc;
    LB_CsvEvent("START_CAPTURE",StringFormat("day=%d event=%s actual_msc=%I64d bid=%.6f ask=%.6f spread=%.6f dst=%s",
                dk,LB_TS(event_start),q.time_msc,q.bid,q.ask,q.ask-q.bid,
                (LB_LondonDSTFromUTC(LB_UTCFromServer(event_start))?"YES":"NO")));
   }

 LB_EvaluateEvent(q,event_start);
}

// ===== END LBMA PM4R SLEEVE =====


// ===== V576 PRIMARY PROFIT-FUNDED PYRAMID RESEARCH =====
CTrade PYR_trade;
long PYR_parent_id=0;
bool PYR_l2_attempted=false,PYR_l3_attempted=false,PYR_l2_seen=false,PYR_l3_seen=false;
int PYR_fh_events=INVALID_HANDLE;
bool PYR_init=false;
long PYR_l2_triggers=0,PYR_l3_triggers=0,PYR_l2_opens=0,PYR_l3_opens=0;
long PYR_block_risk=0,PYR_protect_fail=0,PYR_order_fail=0,PYR_close_req=0;

bool PYR_RetcodeOK(uint r){return(r==TRADE_RETCODE_DONE||r==TRADE_RETCODE_DONE_PARTIAL||r==TRADE_RETCODE_PLACED);}
double PYR_CS(){double z=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);return(z>0?z:100.0);}
double PYR_Safe(){double z=2.0*_Point;double b=(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+1)*_Point;return(b>z?b:z);}
double PYR_CostPrice(double vol){double d=PYR_CS()*vol;return(d>0?PYR_InpCostBufferUSD/d:0.0);}
string PYR_TS(long m){return TimeToString((datetime)(m/1000),TIME_DATE|TIME_SECONDS);}

void PYR_EnsureInit()
{
 if(PYR_init)return;PYR_init=true;PYR_trade.SetExpertMagicNumber(PYR_InpMagic);PYR_trade.SetAsyncMode(false);PYR_trade.SetTypeFillingBySymbol(_Symbol);PYR_trade.SetMarginMode();
 if(PYR_InpEnabled&&PYR_InpWriteCSV)
 {
  int f=FILE_WRITE|FILE_CSV|FILE_ANSI;if(InpWriteAuditCommon)f|=FILE_COMMON;
  PYR_fh_events=FileOpen("QUAD_V576_LAYER_EVENTS.csv",f,',');
  if(PYR_fh_events!=INVALID_HANDLE){FileWrite(PYR_fh_events,"time","event","parent_id","src","family_id","family","rnow","layer","ticket","price","sl","tp","balance","remaining_risk","detail");FileFlush(PYR_fh_events);}
 }
}
void PYR_Event(const MqlTick &q,string ev,int layer,ulong ticket,double price,double sl,double tp,double risk,string detail)
{
 if(PYR_fh_events==INVALID_HANDLE)return;int src=(g_pos.open?g_pos.src:-1),fam=(src>=0&&src<V54_CONFIG_COUNT?V54_FAMILY_ID[src]:-1);string fn=(src>=0&&src<V54_CONFIG_COUNT?V54_FAMILY_NAME[src]:"NA");
 double rr=-999.0;if(g_pos.open&&g_pos.risk_price>0){double px=(g_pos.side==1?q.bid:q.ask);rr=((px-g_pos.entry)*g_pos.side)/g_pos.risk_price;}
 FileWrite(PYR_fh_events,PYR_TS(q.time_msc),ev,PYR_parent_id,src,fam,fn,rr,layer,ticket,price,sl,tp,AccountInfoDouble(ACCOUNT_BALANCE),risk,detail);FileFlush(PYR_fh_events);
}
bool PYR_Find(int layer,ulong &ticket)
{
 ticket=0;string c=(layer==2?"ASTRA-V576-L2":"ASTRA-V576-L3");
 for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t==0)continue;if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue;if(PositionGetInteger(POSITION_MAGIC)!=PYR_InpMagic)continue;if(PositionGetString(POSITION_COMMENT)!=c)continue;ticket=t;return true;}return false;
}
bool PYR_Any(){ulong t=0;return(PYR_Find(2,t)||PYR_Find(3,t));}
double PYR_RemainingRisk()
{
 double total=0.0,cs=PYR_CS();
 for(int i=PositionsTotal()-1;i>=0;i--){ulong t=PositionGetTicket(i);if(t==0)continue;if(PositionGetString(POSITION_SYMBOL)!=_Symbol)continue;long mg=PositionGetInteger(POSITION_MAGIC);if(!PYR_InpRiskAcrossAllSymbolPos&&mg!=InpMagic&&mg!=PYR_InpMagic)continue;
  double e=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),v=PositionGetDouble(POSITION_VOLUME);if(sl<=0||v<=0)return -1.0;int side=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1);double p=(sl-e)*side*cs*v;if(p<0)total+=-p;}
 return total;
}
bool PYR_Protect(ulong ticket,int side,double target)
{
 if(ticket==0||!PositionSelectByTicket(ticket))return false;double old=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);if(old>0&&((side==1&&old>=target-0.5*_Point)||(side==-1&&old<=target+0.5*_Point)))return true;
 MqlTick q;if(!SymbolInfoTick(_Symbol,q))return false;double px=(side==1?q.bid:q.ask),safe=PYR_Safe();if((side==1&&target>px-safe)||(side==-1&&target<px+safe))return false;
 double sl=NormalizeDouble(target,_Digits);bool ok=PYR_trade.PositionModify(ticket,sl,tp);uint ret=PYR_trade.ResultRetcode();if(!ok||!PYR_RetcodeOK(ret)||!PositionSelectByTicket(ticket))return false;
 double a=PositionGetDouble(POSITION_SL);if(ticket==g_pos.ticket){g_pos.stop=a;PersistPositionState();}return(side==1?a>=sl-0.5*_Point:a<=sl+0.5*_Point);
}
bool PYR_RiskGate(int side,double entry,double sl,double vol,double &after)
{
 double ex=PYR_RemainingRisk();if(ex<0){after=-1;return false;}double p=(entry-sl)*side*PYR_CS()*vol;after=ex+(p<0?-p:0);double b=AccountInfoDouble(ACCOUNT_BALANCE);return(b>0&&after<=b*PYR_InpMaxRemainingRiskPct/100.0+1e-8);
}
bool PYR_Open(int layer,const MqlTick &q,double requested_sl)
{
 double spread=q.ask-q.bid;if(spread<=0||spread>V54_MAX_SPREAD[g_pos.src]){PYR_Event(q,"BLOCK_SPREAD",layer,0,0,requested_sl,0,PYR_RemainingRisk(),"");return false;}
 double req=(g_pos.side==1?q.ask:q.bid),sl=NormalizeDouble(requested_sl,_Digits),safe=PYR_Safe();
 if((g_pos.side==1&&sl>q.bid-safe)||(g_pos.side==-1&&sl<q.ask+safe)){PYR_Event(q,"BLOCK_STOP_DISTANCE",layer,0,req,sl,0,PYR_RemainingRisk(),"");return false;}
 double after=0;if(!PYR_RiskGate(g_pos.side,req,sl,PYR_InpLot,after)){PYR_block_risk++;PYR_Event(q,"BLOCK_RISK",layer,0,req,sl,0,after,"");return false;}
 double tp=0;if(g_pos.initial_tp>0){if(g_pos.side==1&&g_pos.initial_tp>q.ask+safe)tp=NormalizeDouble(g_pos.initial_tp,_Digits);if(g_pos.side==-1&&g_pos.initial_tp<q.bid-safe)tp=NormalizeDouble(g_pos.initial_tp,_Digits);}
 string c=(layer==2?"ASTRA-V576-L2":"ASTRA-V576-L3");PYR_trade.SetExpertMagicNumber(PYR_InpMagic);ResetLastError();bool ok=(g_pos.side==1?PYR_trade.Buy(PYR_InpLot,_Symbol,0,sl,tp,c):PYR_trade.Sell(PYR_InpLot,_Symbol,0,sl,tp,c));uint ret=PYR_trade.ResultRetcode();
 if(!ok||!PYR_RetcodeOK(ret)){PYR_order_fail++;PYR_Event(q,"ORDER_FAIL",layer,0,req,sl,tp,after,PYR_trade.ResultRetcodeDescription());return false;}
 ulong t=0;if(!PYR_Find(layer,t)){PYR_order_fail++;PYR_Event(q,"NO_POSITION_AFTER_ORDER",layer,0,req,sl,tp,after,"");return false;}
 if(layer==2){PYR_l2_opens++;PYR_l2_seen=true;}else{PYR_l3_opens++;PYR_l3_seen=true;}if(PositionSelectByTicket(t)){req=PositionGetDouble(POSITION_PRICE_OPEN);sl=PositionGetDouble(POSITION_SL);tp=PositionGetDouble(POSITION_TP);}
 PYR_Event(q,"LAYER_OPENED",layer,t,req,sl,tp,PYR_RemainingRisk(),"");return true;
}
void PYR_CloseAll(const MqlTick &q,string why)
{
 for(int l=3;l>=2;l--){ulong t=0;if(!PYR_Find(l,t))continue;bool ok=PYR_trade.PositionClose(t);uint r=PYR_trade.ResultRetcode();if(ok&&PYR_RetcodeOK(r))PYR_close_req++;PYR_Event(q,(ok&&PYR_RetcodeOK(r)?"LAYER_CLOSE_REQUEST":"LAYER_CLOSE_FAIL"),l,t,0,0,0,PYR_RemainingRisk(),why);}
}
void PYR_Reset(long id,const MqlTick &q){PYR_parent_id=id;PYR_l2_attempted=false;PYR_l3_attempted=false;PYR_l2_seen=false;PYR_l3_seen=false;PYR_Event(q,"NEW_PARENT",0,0,g_pos.entry,g_pos.stop,g_pos.tp,PYR_RemainingRisk(),"");}
void PYR_OnTick(const MqlTick &q)
{
 if(!PYR_InpEnabled)return;PYR_EnsureInit();
 if(!g_pos.open){if(PYR_Any())PYR_CloseAll(q,"PARENT_CLOSED");if(!PYR_Any())PYR_parent_id=0;return;}
 if(PYR_parent_id!=g_pos.identifier){if(PYR_Any()){PYR_CloseAll(q,"STALE_LAYER_NEW_PARENT");return;}PYR_Reset(g_pos.identifier,q);}
 if(PYR_InpExcludeHF08&&V54_FAMILY_ID[g_pos.src]==8)return;
 double px=(g_pos.side==1?q.bid:q.ask),r=((px-g_pos.entry)*g_pos.side)/g_pos.risk_price,cost=PYR_CostPrice(InpFixedLot);
 ulong l2=0,l3=0;bool h2=PYR_Find(2,l2),h3=PYR_Find(3,l3);
 if(PYR_l2_seen&&!h2){PYR_Event(q,"L2_GONE",2,0,0,0,0,PYR_RemainingRisk(),"NO_REENTRY");PYR_l2_seen=false;}if(PYR_l3_seen&&!h3){PYR_Event(q,"L3_GONE",3,0,0,0,0,PYR_RemainingRisk(),"NO_REENTRY");PYR_l3_seen=false;}
 if(!PYR_l2_attempted&&r>=PYR_InpL2TriggerR){PYR_l2_attempted=true;PYR_l2_triggers++;PYR_Event(q,"L2_TRIGGER",2,0,px,0,0,PYR_RemainingRisk(),"");double lock=g_pos.entry+g_pos.side*cost;if(!PYR_Protect(g_pos.ticket,g_pos.side,lock)){PYR_protect_fail++;PYR_Event(q,"L2_BLOCK_PARENT_PROTECT",2,g_pos.ticket,px,lock,0,PYR_RemainingRisk(),"");}else PYR_Open(2,q,g_pos.entry);}
 h2=PYR_Find(2,l2);
 if(!PYR_l3_attempted&&r>=PYR_InpL3TriggerR){PYR_l3_attempted=true;PYR_l3_triggers++;PYR_Event(q,"L3_TRIGGER",3,0,px,0,0,PYR_RemainingRisk(),"");if(!h2){PYR_Event(q,"L3_BLOCK_NO_L2",3,0,px,0,0,PYR_RemainingRisk(),"");}else{double b=g_pos.entry+g_pos.side*0.50*g_pos.risk_price;bool bo=PYR_Protect(g_pos.ticket,g_pos.side,b),lo=false;if(PositionSelectByTicket(l2)){int sd=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1);double e=PositionGetDouble(POSITION_PRICE_OPEN),v=PositionGetDouble(POSITION_VOLUME);lo=PYR_Protect(l2,sd,e+sd*PYR_CostPrice(v));}if(!bo||!lo){PYR_protect_fail++;PYR_Event(q,"L3_BLOCK_PROTECT",3,0,px,b,0,PYR_RemainingRisk(),"");}else PYR_Open(3,q,b);}}
}
void PYR_WriteSummary(int reason)
{
 if(!PYR_InpEnabled)return;HistorySelect(0,TimeCurrent()+86400);long ins=0,outs=0,w=0,l=0;double gp=0,gl=0,net=0;
 for(int i=0;i<HistoryDealsTotal();i++){ulong d=HistoryDealGetTicket(i);if(d==0||HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol||HistoryDealGetInteger(d,DEAL_MAGIC)!=PYR_InpMagic)continue;long e=HistoryDealGetInteger(d,DEAL_ENTRY);if(e==DEAL_ENTRY_IN||e==DEAL_ENTRY_INOUT)ins++;if(e==DEAL_ENTRY_OUT||e==DEAL_ENTRY_OUT_BY||e==DEAL_ENTRY_INOUT){outs++;double x=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);net+=x;if(x>1e-8){w++;gp+=x;}else if(x<-1e-8){l++;gl+=-x;}}}
 double pf=(gl>0?gp/gl:(gp>0?99:0));int f=FILE_WRITE|FILE_CSV|FILE_ANSI;if(InpWriteAuditCommon)f|=FILE_COMMON;int h=FileOpen("QUAD_V576_LAYER_SUMMARY.csv",f,',');
 if(h!=INVALID_HANDLE){FileWrite(h,"metric","value");FileWrite(h,"build","P812_HF02X_KAGURA_G10_LBMA_PM4R_QUAD_V576_L3_RESEARCH_20260926");FileWrite(h,"enabled",PYR_InpEnabled);FileWrite(h,"l2_triggers",PYR_l2_triggers);FileWrite(h,"l3_triggers",PYR_l3_triggers);FileWrite(h,"l2_opens",PYR_l2_opens);FileWrite(h,"l3_opens",PYR_l3_opens);FileWrite(h,"block_risk",PYR_block_risk);FileWrite(h,"protect_fail",PYR_protect_fail);FileWrite(h,"order_fail",PYR_order_fail);FileWrite(h,"close_requests",PYR_close_req);FileWrite(h,"in_deals",ins);FileWrite(h,"out_deals",outs);FileWrite(h,"wins",w);FileWrite(h,"losses",l);FileWrite(h,"gross_profit",gp);FileWrite(h,"gross_loss",gl);FileWrite(h,"net",net);FileWrite(h,"pf",pf);FileWrite(h,"final_balance",AccountInfoDouble(ACCOUNT_BALANCE));FileWrite(h,"deinit_reason",reason);FileClose(h);}
 if(PYR_fh_events!=INVALID_HANDLE){FileFlush(PYR_fh_events);FileClose(PYR_fh_events);PYR_fh_events=INVALID_HANDLE;}PrintFormat("[V576-L3][SUMMARY] L2=%d/%d L3=%d/%d net=%.2f PF=%.4f",PYR_l2_opens,PYR_l2_triggers,PYR_l3_opens,PYR_l3_triggers,net,pf);
}
// ===== END V576 PYRAMID RESEARCH =====


int OnInit()
  {
   ClearPersistentRuntimeStateForTester(); ResetPositionState(); LoadCooldowns();
   g_sim_balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(!ValidateEnvironment()) return(INIT_FAILED);

   // Family 0 is HF02X. This switch is portfolio-only; frozen family rules remain unchanged.
   V54_F_SELECTED[0]=(PortfolioHF02XActive() ? 1 : 0);
   for(int s=1;s<V54_CONFIG_COUNT;s++) V54_F_SELECTED[s]=1;

   if(PortfolioPrimaryActive())
     {
      g_trade.SetExpertMagicNumber(InpMagic); g_trade.SetAsyncMode(false); g_trade.SetTypeFillingBySymbol(_Symbol); g_trade.SetMarginMode();
      if(!OpenAuditFiles()) return(INIT_FAILED);
      if(!WarmupSignalEngine()) { CloseAuditFiles(); return(INIT_FAILED); }
      if(!RestorePositionState()) { CloseAuditFiles(); return(INIT_FAILED); }
      PrintFormat("[TRI][PRIMARY_READY] P812=ON HF02X=%s magic=%I64d",(PortfolioHF02XActive()?"ON":"OFF"),InpMagic);
     }

   if(PortfolioKaguraActive())
     {
      int kr=K_OnInit();
      if(kr!=INIT_SUCCEEDED)
        {
         Print("[TRI][FATAL] KAGURA init failed");
         if(PortfolioPrimaryActive()) CloseAuditFiles();
         return(INIT_FAILED);
        }
     }

   if(PortfolioLBMAActive())
     {
      int lr=LB_OnInit();
      if(lr!=INIT_SUCCEEDED)
        {
         Print("[QUAD][FATAL] LBMA-PM4R init failed");
         if(PortfolioKaguraActive()) K_OnDeinit(REASON_INITFAILED);
         if(PortfolioPrimaryActive()) CloseAuditFiles();
         return(INIT_FAILED);
        }
     }

   if(InpWriteAuditCommon)
     {
      g_pf_summary=FileOpen("ASTRA_P812_HF02X_KAGURA_LBMA_PORTFOLIO_SUMMARY.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
      if(g_pf_summary!=INVALID_HANDLE) FileWrite(g_pf_summary,"metric","value");
     }

   PrintFormat("[QUAD][READY] mode=%d P812=%s HF02X=%s KAGURA=%s LBMA=%s G10=%s cap=%.2f%%",
               (int)InpPortfolioMode,(PortfolioPrimaryActive()?"ON":"OFF"),(PortfolioHF02XActive()?"ON":"OFF"),
               (PortfolioKaguraActive()?"ON":"OFF"),(PortfolioLBMAActive()?"ON":"OFF"),(K_InpG10Enabled?"ON":"OFF"),K_InpG10RiskCapPct);
   Print("[QUAD][FREEZE] ALL3 parent frozen exactly; LBMA-PM4R is additive sleeve only. No parent alpha tuning in this build.");
   PrintFormat("[TRI][BOOTSTRAP] deterministic=%s history_start=%I64d signal_start=%I64d",
               (InpDeterministicBootstrap?"ON":"OFF"),InpBootstrapHistoryStartSec,InpFrozenSignalStartSec);
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   if(PortfolioKaguraActive()) K_OnTick();
   if(PortfolioLBMAActive()) LB_OnTick();
   if(!PortfolioPrimaryActive()) return;

   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   ManageOpenPosition(tick);
   PYR_OnTick(tick);
   long minute_id=tick.time_msc/60000;
   if(g_last_minute_id<0) { g_last_minute_id=minute_id; return; }
   if(minute_id!=g_last_minute_id)
     {
      g_last_minute_id=minute_id;
      ProcessNewCompletedBar(tick);
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(PortfolioKaguraActive()) K_OnTradeTransaction(trans,request,result);
   if(PortfolioLBMAActive()) LB_OnTradeTransaction(trans,request,result);
   if(!PortfolioPrimaryActive()) return;
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   FinalizeClosedDeal(trans.deal);
  }

void WriteSummary(const int reason)
  {
   if(g_h_summary==INVALID_HANDLE) return;
   double pf=(g_gl>0.0 ? g_gp/g_gl : (g_gp>0.0 ? 99.0 : 0.0)),wr=(g_wins+g_losses>0 ? 100.0*g_wins/(g_wins+g_losses) : 0.0),avg_win=(g_wins>0?g_gp/g_wins:0.0),avg_loss=(g_losses>0?g_gl/g_losses:0.0),ltw=(avg_win>0?avg_loss/avg_win:99.0);
   FileWrite(g_h_summary,"P812_HF02X_TRI_PORTFOLIO",g_bars_live_processed,g_union_signals,g_raw_candidates,g_regime_candidates,g_quality_candidates,g_conflicts,g_fills,g_trades,g_wins,g_losses,DoubleToString(g_sim_balance,2),DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2),DoubleToString(g_gp,2),DoubleToString(g_gl,2),DoubleToString(pf,8),DoubleToString(wr,6),DoubleToString(avg_win,6),DoubleToString(avg_loss,6),DoubleToString(ltw,6),DoubleToString(g_max_loss_usd,2),DoubleToString(g_max_loss_r,6),g_blocked_open,g_cooldown_skips,g_actionable,g_skip_spread,g_skip_margin,g_skip_risk,g_order_fails,g_exit_sl,g_exit_tp,g_exit_tail_cash,g_exit_tail_r,g_exit_tail_mae,g_exit_tail_time,g_exit_tail_giveback,g_exit_base_early,g_exit_base_stagn,g_exit_base_time,g_exit_day,g_exit_other,g_v54_bar_count,g_v54_history_first_bar,g_v54_history_last_bar,g_v54_exact_tick_bars,g_v54_tick_fallback_bars,reason);
   FileFlush(g_h_summary);
   Print("[TRI][PRIMARY_SUMMARY] signals=",g_union_signals," trades=",g_trades," P812_trades=",g_pf_p812_trades," HF02X_trades=",g_pf_hf02x_trades," account_final=",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)," PF=",DoubleToString(pf,4));
  }

void OnDeinit(const int reason)
  {
   PYR_WriteSummary(reason);
   if(PortfolioLBMAActive()) LB_OnDeinit(reason);
   if(PortfolioKaguraActive()) K_OnDeinit(reason);
   if(PortfolioPrimaryActive() && g_pos.open) PersistPositionState();
   if(PortfolioPrimaryActive()) WriteSummary(reason);

   if(g_pf_summary!=INVALID_HANDLE)
     {
      FileWrite(g_pf_summary,"build","P812_HF02X_KAGURA_G10_LBMA_PM4R_QUAD_V576_L3_RESEARCH_20260926");
      FileWrite(g_pf_summary,"pyr_enabled",PYR_InpEnabled);
      FileWrite(g_pf_summary,"pyr_l2_triggers",PYR_l2_triggers);
      FileWrite(g_pf_summary,"pyr_l3_triggers",PYR_l3_triggers);
      FileWrite(g_pf_summary,"pyr_l2_opens",PYR_l2_opens);
      FileWrite(g_pf_summary,"pyr_l3_opens",PYR_l3_opens);
      FileWrite(g_pf_summary,"deterministic_bootstrap",InpDeterministicBootstrap);
      FileWrite(g_pf_summary,"bootstrap_history_start_sec",InpBootstrapHistoryStartSec);
      FileWrite(g_pf_summary,"frozen_signal_start_sec",InpFrozenSignalStartSec);
      FileWrite(g_pf_summary,"mode",(int)InpPortfolioMode);
      FileWrite(g_pf_summary,"p812_enabled",PortfolioPrimaryActive());
      FileWrite(g_pf_summary,"hf02x_enabled",PortfolioHF02XActive());
      FileWrite(g_pf_summary,"kagura_enabled",PortfolioKaguraActive());
      FileWrite(g_pf_summary,"lbma_enabled",PortfolioLBMAActive());
      FileWrite(g_pf_summary,"primary_union_signals",g_union_signals);
      FileWrite(g_pf_summary,"primary_quality_candidates",g_quality_candidates);
      FileWrite(g_pf_summary,"primary_conflicts",g_conflicts);
      FileWrite(g_pf_summary,"p812_fills",g_pf_p812_fills);
      FileWrite(g_pf_summary,"p812_trades",g_pf_p812_trades);
      FileWrite(g_pf_summary,"p812_python_like_net",DoubleToString(g_pf_p812_py_net,2));
      FileWrite(g_pf_summary,"p812_deal_net",DoubleToString(g_pf_p812_deal_net,2));
      FileWrite(g_pf_summary,"hf02x_fills",g_pf_hf02x_fills);
      FileWrite(g_pf_summary,"hf02x_trades",g_pf_hf02x_trades);
      FileWrite(g_pf_summary,"hf02x_python_like_net",DoubleToString(g_pf_hf02x_py_net,2));
      FileWrite(g_pf_summary,"hf02x_deal_net",DoubleToString(g_pf_hf02x_deal_net,2));
      FileWrite(g_pf_summary,"kagura_signals",K_cnt_signals);
      FileWrite(g_pf_summary,"kagura_g10_accept",K_cnt_g10_accept);
      FileWrite(g_pf_summary,"kagura_g10_skip",K_cnt_g10_skip);
      FileWrite(g_pf_summary,"kagura_opens",K_cnt_open);
      FileWrite(g_pf_summary,"kagura_closes",K_cnt_close);
      FileWrite(g_pf_summary,"kagura_order_fail",K_cnt_order_fail);
      FileWrite(g_pf_summary,"kagura_realized_net",DoubleToString(K_realized_net,2));
      FileWrite(g_pf_summary,"kagura_signal_while_primary_open",g_pf_overlap_signals);
      FileWrite(g_pf_summary,"same_side_overlap",g_pf_same_side);
      FileWrite(g_pf_summary,"opposite_side_overlap",g_pf_opposite_side);
      FileWrite(g_pf_summary,"lbma_observations",LB_cnt_observations);
      FileWrite(g_pf_summary,"lbma_signals",LB_cnt_signals);
      FileWrite(g_pf_summary,"lbma_spread_skip",LB_cnt_spread_skip);
      FileWrite(g_pf_summary,"lbma_risk_accept",LB_cnt_risk_accept);
      FileWrite(g_pf_summary,"lbma_risk_skip",LB_cnt_risk_skip);
      FileWrite(g_pf_summary,"lbma_opens",LB_cnt_open);
      FileWrite(g_pf_summary,"lbma_closes",LB_cnt_close);
      FileWrite(g_pf_summary,"lbma_order_fail",LB_cnt_order_fail);
      FileWrite(g_pf_summary,"lbma_missed_start",LB_cnt_missed_start);
      FileWrite(g_pf_summary,"lbma_realized_net",DoubleToString(LB_realized_net,2));
      FileWrite(g_pf_summary,"lbma_signal_while_primary_open",LB_overlap_primary);
      FileWrite(g_pf_summary,"lbma_signal_while_kagura_open",LB_overlap_kagura);
      FileWrite(g_pf_summary,"lbma_primary_same_side",LB_primary_same);
      FileWrite(g_pf_summary,"lbma_primary_opposite_side",LB_primary_opposite);
      FileWrite(g_pf_summary,"lbma_kagura_same_side",LB_kagura_same);
      FileWrite(g_pf_summary,"lbma_kagura_opposite_side",LB_kagura_opposite);
      FileWrite(g_pf_summary,"final_balance",DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));
      FileWrite(g_pf_summary,"final_equity",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2));
      FileFlush(g_pf_summary); FileClose(g_pf_summary); g_pf_summary=INVALID_HANDLE;
     }
   if(PortfolioPrimaryActive()) CloseAuditFiles();
  }