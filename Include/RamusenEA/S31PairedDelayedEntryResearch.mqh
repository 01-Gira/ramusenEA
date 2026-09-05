#ifndef RAMUSEN_S31_PAIRED_DELAYED_ENTRY_RESEARCH_MQH
#define RAMUSEN_S31_PAIRED_DELAYED_ENTRY_RESEARCH_MQH
#include "Config.mqh"
#include "Types.mqh"

// S31_PAIRED_DELAY_MECHANISM_V2. RESEARCH_ONLY / TRADING_DISABLED / FAIL_CLOSED.
// Historical labeler, not an execution engine. No S2 gate or trading dependency.
struct S31Event
{
   ulong time_msc;
   datetime m5_bar, m15_bar;
   double bid, ask, atr, fast2, slow2, fast1, slow1, context_fast, context_slow;
};

class CS31PairedDelayedEntryResearch
{
private:
   string symbol, prefix, columns[];
   int fast, slow, context_fast, context_slow, atr_handle;
   int output, tick_output, manifest;
   double point;
   bool ready, healthy, primed;
   datetime last_bar;
   ulong last_observed, event_count, row_count, ok_count, missing_count, pending_count;
   S31Event events[];

   ulong Cutoff() { return (ulong)D'2026.09.01 00:00:00'*1000ULL; }
   bool Valid(const MqlTick &t)
   {
      return t.time_msc>0 && MathIsValidNumber(t.bid) && MathIsValidNumber(t.ask)
         && t.bid>0 && t.ask>=t.bid;
   }
   string Num(const double v) { return DoubleToString(v,12); }
   string Stamp(const ulong t) { return TimeToString((datetime)(t/1000ULL),TIME_DATE|TIME_SECONDS); }
   bool Value(const int h,const int shift,double &v)
   {
      double b[1];
      if(h==INVALID_HANDLE || CopyBuffer(h,0,shift,1,b)!=1) return false;
      v=b[0];
      return MathIsValidNumber(v) && v!=EMPTY_VALUE;
   }
   void Fault(const string reason)
   {
      healthy=false;
      Print("[RAMUSEN][ERROR] S31_FATAL ",reason);
   }
   string Escape(string s)
   {
      if(StringFind(s,",")>=0 || StringFind(s,"\"")>=0 || StringFind(s,"\n")>=0)
      {
         StringReplace(s,"\"","\"\"");
         return "\""+s+"\"";
      }
      return s;
   }
   void Put(string &r[],const string name,const string value)
   {
      for(int i=0;i<ArraySize(columns);i++)
         if(columns[i]==name) { r[i]=value; return; }
      Fault("UNKNOWN_OUTPUT_COLUMN_"+name);
   }
   bool WriteCells(const int h,string &r[])
   {
      string line="";
      for(int i=0;i<ArraySize(r);i++) line+=(i==0 ? "" : ",")+Escape(r[i]);
      if(FileWriteString(h,line+"\r\n")==0) { Fault("CSV_WRITE_FAILED"); return false; }
      return true;
   }
   int FirstQuote(MqlTick &ticks[],const ulong target,const int start=0)
   {
      for(int i=start;i<ArraySize(ticks);i++)
      {
         if((ulong)ticks[i].time_msc<target) continue;
         if((ulong)ticks[i].time_msc-target>30000ULL) break;
         if(Valid(ticks[i])) return i;
      }
      return -1;
   }
   void EntryContext(const ulong time_msc,string &state,datetime &bar,double &f,double &s)
   {
      // Read the bar completed AS OF entry, not shift1 as of label maturation.
      int current=iBarShift(symbol,PERIOD_M15,(datetime)(time_msc/1000ULL),false);
      state="UNAVAILABLE"; bar=0; f=0; s=0;
      if(current<0) return;
      int shift=current+1;
      bar=iTime(symbol,PERIOD_M15,shift);
      if(bar<=0 || (ulong)(bar+900)*1000ULL>time_msc) return;
      if(!Value(context_fast,shift,f) || !Value(context_slow,shift,s)) return;
      state=(f<s ? "BEARISH" : (f>s ? "BULLISH" : "FLAT"));
   }
   void WriteArm(const S31Event &e,MqlTick &ticks[],const int arm,const int view,
                 const ulong observed_end,const string forced)
   {
      string names[4]={"CONTROL","DELAY_1","DELAY_3","DELAY_5"};
      int delays[4]={0,60,180,300};
      string r[]; ArrayResize(r,ArraySize(columns));
      for(int k=0;k<ArraySize(r);k++) r[k]="";
      ulong target=e.time_msc+(ulong)delays[arm]*1000ULL;
      ulong common=e.time_msc+600000ULL;
      Put(r,"schema_version","S31_V2"); Put(r,"run_id",prefix);
      Put(r,"original_event_time_msc",(string)e.time_msc);
      Put(r,"original_event_time",Stamp(e.time_msc));
      Put(r,"arm",names[arm]); Put(r,"exit_view",view==0 ? "COMMON_DEADLINE" : "EQUAL_HOLD");
      Put(r,"symbol",symbol); Put(r,"side","SELL"); Put(r,"point",Num(point));
      Put(r,"signal_m5_bar_time_msc",(string)((ulong)e.m5_bar*1000ULL));
      Put(r,"original_m15_bar_time_msc",(string)((ulong)e.m15_bar*1000ULL));
      Put(r,"m5_fast2",Num(e.fast2)); Put(r,"m5_slow2",Num(e.slow2));
      Put(r,"m5_fast1",Num(e.fast1)); Put(r,"m5_slow1",Num(e.slow1));
      Put(r,"original_context_fast",Num(e.context_fast)); Put(r,"original_context_slow",Num(e.context_slow));
      Put(r,"original_context","BEARISH");
      Put(r,"original_bid",Num(e.bid)); Put(r,"original_ask",Num(e.ask));
      Put(r,"original_atr",Num(e.atr)); Put(r,"stop_distance",Num(1.25*e.atr));
      Put(r,"entry_target_msc",(string)target); Put(r,"common_deadline_target_msc",(string)common);
      Put(r,"observed_path_end_msc",(string)observed_end);
      string status=forced;
      int entry=-1,exit=-1;
      if(status=="")
      {
         entry=FirstQuote(ticks,target);
         // The original event quote, rather than an earlier same-ms quote.
         if(arm==0 && entry>=0)
         {
            while(entry<ArraySize(ticks) && (ulong)ticks[entry].time_msc==e.time_msc
                  && (MathAbs(ticks[entry].bid-e.bid)>point*.01 || MathAbs(ticks[entry].ask-e.ask)>point*.01)) entry++;
            if(entry>=ArraySize(ticks) || (ulong)ticks[entry].time_msc!=e.time_msc)
            { status="ORIGINAL_QUOTE_MISMATCH"; Fault(status); entry=-1; }
         }
         if(entry<0 && status=="") status=(observed_end<target+30000ULL ? "PENDING_AT_SHUTDOWN" : "ENTRY_MISSING");
      }
      if(entry>=0)
      {
         MqlTick t=ticks[entry];
         ulong equal=(ulong)t.time_msc+600000ULL;
         ulong deadline=(view==0 ? common : equal);
         Put(r,"entry_time_msc",(string)t.time_msc); Put(r,"entry_time",Stamp((ulong)t.time_msc));
         Put(r,"entry_tick_index",IntegerToString(entry));
         Put(r,"entry_delay_ms",(string)((ulong)t.time_msc-target));
         Put(r,"entry_bid",Num(t.bid)); Put(r,"entry_ask",Num(t.ask));
         Put(r,"entry_spread_points",Num((t.ask-t.bid)/point));
         Put(r,"entry_spread_bps",Num((t.ask-t.bid)/((t.ask+t.bid)/2)*10000));
         Put(r,"entry_improvement_price",Num(t.bid-e.bid));
         Put(r,"entry_improvement_points",Num((t.bid-e.bid)/point));
         Put(r,"entry_improvement_bps",Num((t.bid-e.bid)/e.bid*10000));
         Put(r,"equal_hold_target_msc",(string)equal); Put(r,"exit_target_msc",(string)deadline);
         string state; datetime bar; double f,s;
         EntryContext((ulong)t.time_msc,state,bar,f,s);
         Put(r,"entry_context",state); Put(r,"entry_context_bar_time_msc",(string)((ulong)bar*1000ULL));
         Put(r,"entry_context_fast",Num(f)); Put(r,"entry_context_slow",Num(s));
         exit=FirstQuote(ticks,deadline,entry);
         if(exit<0) status=(observed_end<deadline+30000ULL ? "PENDING_AT_SHUTDOWN" : "EXIT_MISSING");
         if(exit>=0)
         {
            double best=t.ask,worst=t.ask;
            int best_i=entry,worst_i=entry,stop_i=-1;
            ulong max_gap=0;
            double stop=t.bid+1.25*e.atr;
            for(int i=entry;i<=exit;i++)
            {
               if(ticks[i].ask<best) { best=ticks[i].ask; best_i=i; }
               if(ticks[i].ask>worst) { worst=ticks[i].ask; worst_i=i; }
               if(stop_i<0 && ticks[i].ask>=stop) stop_i=i;
               if(i>entry) max_gap=MathMax(max_gap,(ulong)(ticks[i].time_msc-ticks[i-1].time_msc));
            }
            double favorable=MathMax(0,t.bid-best),adverse=MathMax(0,worst-t.bid);
            double gross=(t.bid-ticks[exit].ask)/t.bid*10000;
            Put(r,"exit_time_msc",(string)ticks[exit].time_msc); Put(r,"exit_time",Stamp((ulong)ticks[exit].time_msc));
            Put(r,"exit_tick_index",IntegerToString(exit));
            Put(r,"exit_delay_ms",(string)((ulong)ticks[exit].time_msc-deadline));
            Put(r,"exit_bid",Num(ticks[exit].bid)); Put(r,"exit_ask",Num(ticks[exit].ask));
            Put(r,"holding_ms",(string)(ticks[exit].time_msc-t.time_msc));
            Put(r,"gross_executable_bps",Num(gross));
            double entry_mid=(t.bid+t.ask)/2,exit_mid=(ticks[exit].bid+ticks[exit].ask)/2;
            Put(r,"mid_return_bps",Num((entry_mid-exit_mid)/entry_mid*10000));
            Put(r,"gross_r",Num((t.bid-ticks[exit].ask)/(1.25*e.atr)));
            Put(r,"mfe_bps",Num(favorable/t.bid*10000)); Put(r,"mae_bps",Num(adverse/t.bid*10000));
            Put(r,"mfe_atr",Num(favorable/e.atr)); Put(r,"mae_atr",Num(adverse/e.atr));
            Put(r,"best_ask",Num(best)); Put(r,"worst_ask",Num(worst));
            Put(r,"time_to_mfe_ms",favorable>0 ? (string)(ticks[best_i].time_msc-t.time_msc) : "-1");
            Put(r,"time_to_mae_ms",adverse>0 ? (string)(ticks[worst_i].time_msc-t.time_msc) : "-1");
            Put(r,"ticks_scanned",IntegerToString(exit-entry+1)); Put(r,"max_tick_gap_ms",(string)max_gap);
            Put(r,"stop_price",Num(stop)); Put(r,"stop_hit",stop_i>=0 ? "YES" : "NO");
            int risk_exit=(stop_i>=0 ? stop_i : exit);
            Put(r,"risk_exit_time_msc",(string)ticks[risk_exit].time_msc);
            Put(r,"risk_exit_ask",Num(ticks[risk_exit].ask));
            Put(r,"stop_r",Num((t.bid-ticks[risk_exit].ask)/(1.25*e.atr)));
            Put(r,"stop_time_msc",stop_i>=0 ? (string)ticks[stop_i].time_msc : "");
            Put(r,"stop_through_price",stop_i>=0 ? Num(ticks[stop_i].ask-stop) : "0");
            Put(r,"net_bps_0",Num(gross)); Put(r,"net_bps_0_5",Num(gross-.5));
            Put(r,"net_bps_1",Num(gross-1)); Put(r,"net_bps_1_5",Num(gross-1.5)); Put(r,"net_bps_2",Num(gross-2));
            status="OK";
         }
      }
      Put(r,"status",status);
      if(WriteCells(output,r)) row_count++;
      if(status=="OK") ok_count++;
      else if(status=="PENDING_AT_SHUTDOWN") pending_count++;
      else if(status=="ENTRY_MISSING" || status=="EXIT_MISSING") missing_count++;
   }
   void Analyze(const S31Event &e,const ulong available)
   {
      ulong end=MathMin(e.time_msc+960000ULL,MathMin(available,Cutoff()-1));
      MqlTick ticks[]; ResetLastError();
      int n=CopyTicksRange(symbol,ticks,COPY_TICKS_ALL,e.time_msc,end);
      int error=GetLastError(); string forced="";
      if(n<0 || error!=0) { forced="COPY_TICKS_ERROR_"+IntegerToString(error); Fault(forced); }
      else if(n==0) ArrayResize(ticks,0);
      if(forced=="")
      {
         for(int i=0;i<n;i++)
         {
            if(!Valid(ticks[i]) || (ulong)ticks[i].time_msc<e.time_msc || (ulong)ticks[i].time_msc>end
               || (i>0 && ticks[i].time_msc<ticks[i-1].time_msc))
            { forced="INVALID_TICK_PATH"; Fault(forced); break; }
         }
      }
      // Full original-opportunity tick stream, exported once, including same-ms order.
      if(forced=="")
         for(int i=0;i<n;i++)
         {
            string r[6]; r[0]=(string)e.time_msc; r[1]=IntegerToString(i);
            r[2]=(string)ticks[i].time_msc; r[3]=Num(ticks[i].bid); r[4]=Num(ticks[i].ask); r[5]=(string)ticks[i].flags;
            if(!WriteCells(tick_output,r)) { forced="TICK_EXPORT_FAILED"; break; }
         }
      for(int a=0;a<4;a++) for(int v=0;v<2;v++) WriteArm(e,ticks,a,v,end,forced);
      FileFlush(output); FileFlush(tick_output);
   }
   void RemoveFirst()
   {
      int n=ArraySize(events);
      for(int i=1;i<n;i++) events[i-1]=events[i];
      ArrayResize(events,n-1);
   }
   void Capture(const MqlTick &tick)
   {
      datetime bar=iTime(symbol,PERIOD_M5,0);
      if(!primed) { primed=true; last_bar=bar; return; }
      if(bar==last_bar) return;
      last_bar=bar;
      if(BarsCalculated(fast)<23 || BarsCalculated(slow)<23
         || BarsCalculated(context_fast)<52 || BarsCalculated(context_slow)<52) return;
      S31Event e;
      if(!Value(fast,2,e.fast2) || !Value(slow,2,e.slow2)
         || !Value(fast,1,e.fast1) || !Value(slow,1,e.slow1)
         || !Value(context_fast,1,e.context_fast) || !Value(context_slow,1,e.context_slow))
      { Fault("ORIGINAL_INDICATOR_READ_FAILED"); return; }
      if(e.context_fast>=e.context_slow || e.fast2<e.slow2 || e.fast1>=e.slow1) return;
      if(!Value(atr_handle,1,e.atr) || e.atr<=0) { Fault("ORIGINAL_ATR_FAILED"); return; }
      e.time_msc=(ulong)tick.time_msc; e.bid=tick.bid; e.ask=tick.ask;
      e.m5_bar=iTime(symbol,PERIOD_M5,1); e.m15_bar=iTime(symbol,PERIOD_M15,1);
      if(e.m5_bar<=0 || e.m15_bar<=0 || (ulong)(e.m5_bar+300)*1000ULL>e.time_msc
         || (ulong)(e.m15_bar+900)*1000ULL>e.time_msc) { Fault("BAR_ASOF_VIOLATION"); return; }
      int n=ArraySize(events); ArrayResize(events,n+1); events[n]=e; event_count++;
      Print("[RAMUSEN][INFO] S31_EVENT ",e.time_msc);
   }
public:
   CS31PairedDelayedEntryResearch()
   {
      fast=slow=context_fast=context_slow=atr_handle=INVALID_HANDLE;
      output=tick_output=manifest=INVALID_HANDLE;
      ready=false; healthy=true; primed=false; last_bar=0; last_observed=0;
      event_count=row_count=ok_count=missing_count=pending_count=0;
   }
   bool Initialize(const string new_symbol,const ENUM_TIMEFRAMES tf)
   {
      if(!MQLInfoInteger(MQL_TESTER) || InpEnableTrading || InpExecutionTest || InpBaselineStrategyEnabled
         || tf!=PERIOD_M5 || new_symbol!="XAUUSD" || InpFastMAPeriod!=9 || InpSlowMAPeriod!=21
         || InpScalpingContextTimeframe!=PERIOD_M15 || InpScalpingContextFastMAPeriod!=20
         || InpScalpingContextSlowMAPeriod!=50 || InpScalpingATRPeriod!=14
         || InpSignalResearchEnabled || InpScalpingContextResearchEnabled || InpP2F4EntryGateResearchEnabled
         || InpP2F5ExcursionResearchEnabled || InpP2F6TimeExitResearchEnabled || InpP2F7ProfitRetentionResearchEnabled
         || InpP2F11CAdaptiveRetentionResearchEnabled || InpP2F12CandidateS2ResearchEnabled
         || InpP2F14ControlledLayerResearchEnabled
         || TimeCurrent()<D'2026.01.01' || TimeCurrent()>=D'2026.09.01')
      { Print("[RAMUSEN][ERROR] S31_INIT_FAILED_RESEARCH_CONTRACT"); return false; }
      symbol=new_symbol; point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(point<=0) return false;
      fast=iMA(symbol,PERIOD_M5,9,0,MODE_EMA,PRICE_CLOSE);
      slow=iMA(symbol,PERIOD_M5,21,0,MODE_EMA,PRICE_CLOSE);
      context_fast=iMA(symbol,PERIOD_M15,20,0,MODE_EMA,PRICE_CLOSE);
      context_slow=iMA(symbol,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE);
      atr_handle=iATR(symbol,PERIOD_M5,14);
      if(fast==INVALID_HANDLE || slow==INVALID_HANDLE || context_fast==INVALID_HANDLE
         || context_slow==INVALID_HANDLE || atr_handle==INVALID_HANDLE) { Shutdown(); return false; }
      prefix=StringFormat("RamusenEA_s31_%I64d_%I64u",(long)TimeCurrent(),GetMicrosecondCount());
      output=FileOpen(prefix+".csv",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
      tick_output=FileOpen(prefix+"_ticks.csv",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
      manifest=FileOpen(prefix+"_manifest.txt",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
      if(output==INVALID_HANDLE || tick_output==INVALID_HANDLE || manifest==INVALID_HANDLE) { Shutdown(); return false; }
      string header="schema_version,run_id,original_event_time_msc,original_event_time,arm,exit_view,status,symbol,side,point,"
         "signal_m5_bar_time_msc,original_m15_bar_time_msc,m5_fast2,m5_slow2,m5_fast1,m5_slow1,original_context_fast,original_context_slow,original_context,"
         "original_bid,original_ask,original_atr,stop_distance,entry_target_msc,common_deadline_target_msc,observed_path_end_msc,"
         "entry_time_msc,entry_time,entry_tick_index,entry_delay_ms,entry_bid,entry_ask,entry_spread_points,entry_spread_bps,"
         "entry_improvement_price,entry_improvement_points,entry_improvement_bps,equal_hold_target_msc,exit_target_msc,"
         "entry_context,entry_context_bar_time_msc,entry_context_fast,entry_context_slow,exit_time_msc,exit_time,exit_tick_index,exit_delay_ms,exit_bid,exit_ask,holding_ms,"
         "gross_executable_bps,mid_return_bps,gross_r,mfe_bps,mae_bps,mfe_atr,mae_atr,best_ask,worst_ask,time_to_mfe_ms,time_to_mae_ms,ticks_scanned,max_tick_gap_ms,"
         "stop_price,stop_hit,risk_exit_time_msc,risk_exit_ask,stop_r,stop_time_msc,stop_through_price,net_bps_0,net_bps_0_5,net_bps_1,net_bps_1_5,net_bps_2";
      StringSplit(header,',',columns);
      if(FileWriteString(output,header+"\r\n")==0 || FileWriteString(tick_output,"original_event_time_msc,tick_index,time_msc,bid,ask,flags\r\n")==0)
      { Shutdown(); return false; }
      string text="experiment=S31_PAIRED_DELAY_MECHANISM_V2\r\ntrading=false\r\nlayering=false\r\nresearch_only=true\r\n"
         "cutoff_exclusive=2026.09.01\r\ntick_provenance=CopyTicksRange_requires_tester_log_verification\r\n"
         "delay_seconds=0,60,180,300\r\nviews=COMMON_DEADLINE,EQUAL_HOLD\r\nhold_seconds=600\r\n";
      text+="server="+AccountInfoString(ACCOUNT_SERVER)+"\r\nterminal_build="+(string)TerminalInfoInteger(TERMINAL_BUILD)+"\r\n";
      if(FileWriteString(manifest,text)==0) { Shutdown(); return false; }
      ready=true;
      Print("[RAMUSEN][INFO] S31_READY ",prefix," directory=",TerminalInfoString(TERMINAL_COMMONDATA_PATH),"\\Files");
      return true;
   }
   void OnTick()
   {
      if(!ready || !healthy) return;
      // Do not read a September quote, even for a pending August label.
      if(TimeCurrent()>=D'2026.09.01') { Fault("RESERVED_DATE_BOUNDARY"); return; }
      MqlTick tick;
      if(!SymbolInfoTick(symbol,tick) || !Valid(tick)) { Fault("INVALID_OBSERVED_QUOTE"); return; }
      if((ulong)tick.time_msc<last_observed) { Fault("NONMONOTONIC_OBSERVED_TIME"); return; }
      last_observed=(ulong)tick.time_msc;
      while(ArraySize(events)>0 && last_observed>=events[0].time_msc+960000ULL)
      {
         Analyze(events[0],last_observed); RemoveFirst();
         if(!healthy) return;
      }
      Capture(tick);
   }
   void Shutdown()
   {
      if(ready)
      {
         while(ArraySize(events)>0) { Analyze(events[0],last_observed); RemoveFirst(); }
         string footer=StringFormat("events=%I64u\r\nrows=%I64u\r\nok=%I64u\r\nmissing=%I64u\r\npending=%I64u\r\nintegrity=%s\r\n",
            event_count,row_count,ok_count,missing_count,pending_count,healthy ? "OK" : "CORRUPT");
         if(FileWriteString(manifest,footer)==0) Fault("MANIFEST_WRITE_FAILED");
         Print("[RAMUSEN][INFO] S31_SUMMARY ",footer);
      }
      if(output!=INVALID_HANDLE) { FileClose(output); output=INVALID_HANDLE; }
      if(tick_output!=INVALID_HANDLE) { FileClose(tick_output); tick_output=INVALID_HANDLE; }
      if(manifest!=INVALID_HANDLE) { FileClose(manifest); manifest=INVALID_HANDLE; }
      if(fast!=INVALID_HANDLE) { IndicatorRelease(fast); fast=INVALID_HANDLE; }
      if(slow!=INVALID_HANDLE) { IndicatorRelease(slow); slow=INVALID_HANDLE; }
      if(context_fast!=INVALID_HANDLE) { IndicatorRelease(context_fast); context_fast=INVALID_HANDLE; }
      if(context_slow!=INVALID_HANDLE) { IndicatorRelease(context_slow); context_slow=INVALID_HANDLE; }
      if(atr_handle!=INVALID_HANDLE) { IndicatorRelease(atr_handle); atr_handle=INVALID_HANDLE; }
      ready=false;
   }
};
#endif
