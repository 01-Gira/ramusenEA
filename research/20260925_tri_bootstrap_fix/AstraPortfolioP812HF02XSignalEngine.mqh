// ASTRA P812 + HF02X — raw-pass MT5 validation signal engine.
// Reuses frozen V5.4 raw-signal/regime/tail semantics, exact P812 V5.5 quality gates, and HF02X causal quality gate.
// Jan-Sep 2026 are consumed development data. Parity fixes only; no tuning before October OOS.

#ifndef __ASTRA_P812_HF02X_SIGNAL_ENGINE_MQH__
#define __ASTRA_P812_HF02X_SIGNAL_ENGINE_MQH__

#define V54_RING_CAP 512
#define V54_M30_RING_CAP 96
#define V54_DAY_RING_CAP 32
#define V54_INVALID 1.0e308

struct SV54Bar
  {
   long   time_sec;
   double o,h,l,c;
   long   v;
   double tr;
   double ret;
   double atr5,atr7,atr10,atr14,atr21,atr28,atr30;
   double ema5,ema10,ema20;
   double act3,act5,act20,act30;
   double mean10,std10;
   double vwap;
   double asia_hi,asia_lo;
   int    hour;
   double day_range_ratio;
   double atr_bps,atr_ratio,activity_ratio,vol_ratio,eff30,trend30;
   // V5.5C quality-only Python-prefix equivalent. V5.4 regime continues to use atr_ratio above.
   double v55c_atr_ratio_py;
   double h1_c,h1_ema20,h1_ema50;
   double m15_c,m15_ema20;
   double m5_o,m5_h,m5_l,m5_c,m5_ema20;
   double m30_sup48,m30_dem48,m30_atr14;
   double tick_disp60,tick_disp5,tick_cnt60,tick_cnt5;
  };

struct SV54Agg
  {
   bool   active;
   long   bucket;
   double o,h,l,c;
   long   v;
   long   count;
   double ema20;
   double ema50;
   bool   ema20_ready;
   bool   ema50_ready;
   bool   prev_close_ready;
   double prev_close;
  };

SV54Bar g_v54_ring[V54_RING_CAP];
long     g_v54_bar_count=0;
SV54Agg  g_v54_h5,g_v54_h15,g_v54_h30,g_v54_h60;

// M1 streaming EMA state.
bool   g_v54_m1_ema_ready=false;
double g_v54_m1_ema5=0.0,g_v54_m1_ema10=0.0,g_v54_m1_ema20=0.0;

// Rolling sums. They always describe the most recent completed bars after append.
double g_v54_trsum5=0.0,g_v54_trsum7=0.0,g_v54_trsum10=0.0,g_v54_trsum14=0.0,g_v54_trsum21=0.0,g_v54_trsum28=0.0,g_v54_trsum30=0.0;
double g_v54_volsum3=0.0,g_v54_volsum5=0.0,g_v54_volsum20=0.0,g_v54_volsum30=0.0,g_v54_volsum60=0.0;
double g_v54_closesum10=0.0,g_v54_closesq10=0.0;
double g_v54_retsum30=0.0;
double g_v54_atr14sum240=0.0;
int    g_v54_atr14cnt240=0;

// V5.5C P812 FIX2: reproduce Python np.cumsum/subtraction arithmetic path for ATR14 -> prev240 ATR mean.
// This is quality-overlay state only; V5.4 raw/regime calculations stay untouched.
double g_v55c_tr_cum=0.0;
double g_v55c_atr14_cum=0.0;
long   g_v55c_atr14_count=0;
double g_v55c_tr_cum_after[V54_RING_CAP];
double g_v55c_atr14_cum_after[V54_RING_CAP];
long   g_v55c_atr14_count_after[V54_RING_CAP];

// Focused HF12 diagnostic, populated once per completed bar if HF12 reaches the frozen V5.3 regime gate.
bool   g_v55c_hf12_regime_seen=false;
bool   g_v55c_hf12_quality_pass=false;
int    g_v55c_hf12_side=0;
double g_v55c_hf12_atr=0.0;
double g_v55c_hf12_dir_mom5=V54_INVALID;
double g_v55c_hf12_close_loc=V54_INVALID;
double g_v55c_hf12_atr_ratio_legacy=V54_INVALID;
double g_v55c_hf12_atr_ratio_py=V54_INVALID;

// Daily/session state.
long   g_v54_day=-1;
double g_v54_day_hi=0.0,g_v54_day_lo=0.0;
double g_v54_vwap_pv=0.0,g_v54_vwap_v=0.0;
double g_v54_asia_hi=0.0,g_v54_asia_lo=0.0;
bool   g_v54_asia_has=false;
double g_v54_day_ranges[V54_DAY_RING_CAP];
int    g_v54_day_range_count=0;
int    g_v54_day_range_head=0;

// Last-completed HTF mapped values.
double g_v54_map_h1_c=V54_INVALID,g_v54_map_h1_e20=V54_INVALID,g_v54_map_h1_e50=V54_INVALID;
double g_v54_map_m15_c=V54_INVALID,g_v54_map_m15_e20=V54_INVALID;
double g_v54_map_m5_o=V54_INVALID,g_v54_map_m5_h=V54_INVALID,g_v54_map_m5_l=V54_INVALID,g_v54_map_m5_c=V54_INVALID,g_v54_map_m5_e20=V54_INVALID;
double g_v54_map_m30_sup48=V54_INVALID,g_v54_map_m30_dem48=V54_INVALID,g_v54_map_m30_atr14=V54_INVALID;

// M30 history required for prior-48 supply/demand and ATR14.
double g_v54_m30_high[V54_M30_RING_CAP],g_v54_m30_low[V54_M30_RING_CAP],g_v54_m30_tr[V54_M30_RING_CAP];
long   g_v54_m30_count=0;

long g_v54_history_first_bar=0;
long g_v54_history_last_bar=0;
long g_v54_exact_tick_bars=0;
long g_v54_tick_fallback_bars=0;

bool V54Valid(const double x)
  {
   return(MathIsValidNumber(x) && x>-1.0e300 && x<1.0e300);
  }

double V54SafeRatio(const double a,const double b)
  {
   if(!V54Valid(a) || !V54Valid(b) || b<=0.0) return(0.0);
   return(a/b);
  }

int V54RingIndexAbs(const long abs_index)
  {
   long z=abs_index%V54_RING_CAP;
   if(z<0) z+=V54_RING_CAP;
   return((int)z);
  }

bool V54GetAbs(const long abs_index,SV54Bar &out)
  {
   if(abs_index<0 || abs_index>=g_v54_bar_count) return(false);
   if(g_v54_bar_count-abs_index>V54_RING_CAP) return(false);
   out=g_v54_ring[V54RingIndexAbs(abs_index)];
   return(true);
  }

bool V54GetBack(const int back,SV54Bar &out)
  {
   return(V54GetAbs(g_v54_bar_count-1-back,out));
  }

void V54ResetAgg(SV54Agg &a)
  {
   a.active=false; a.bucket=0; a.o=0.0; a.h=0.0; a.l=0.0; a.c=0.0; a.v=0;
   a.count=0; a.ema20=0.0; a.ema50=0.0; a.ema20_ready=false; a.ema50_ready=false;
   a.prev_close_ready=false; a.prev_close=0.0;
  }

void V54ResetSignalEngine()
  {
   g_v54_bar_count=0;
   g_v54_m1_ema_ready=false;
   g_v54_m1_ema5=g_v54_m1_ema10=g_v54_m1_ema20=0.0;
   g_v54_trsum5=g_v54_trsum7=g_v54_trsum10=g_v54_trsum14=g_v54_trsum21=g_v54_trsum28=g_v54_trsum30=0.0;
   g_v54_volsum3=g_v54_volsum5=g_v54_volsum20=g_v54_volsum30=g_v54_volsum60=0.0;
   g_v54_closesum10=g_v54_closesq10=0.0;
   g_v54_retsum30=0.0;
   g_v54_atr14sum240=0.0; g_v54_atr14cnt240=0;
   g_v55c_tr_cum=0.0; g_v55c_atr14_cum=0.0; g_v55c_atr14_count=0;
   ArrayInitialize(g_v55c_tr_cum_after,0.0); ArrayInitialize(g_v55c_atr14_cum_after,0.0); ArrayInitialize(g_v55c_atr14_count_after,0);
   g_v55c_hf12_regime_seen=false; g_v55c_hf12_quality_pass=false; g_v55c_hf12_side=0; g_v55c_hf12_atr=0.0;
   g_v55c_hf12_dir_mom5=g_v55c_hf12_close_loc=g_v55c_hf12_atr_ratio_legacy=g_v55c_hf12_atr_ratio_py=V54_INVALID;
   g_v54_day=-1; g_v54_day_hi=0.0; g_v54_day_lo=0.0; g_v54_vwap_pv=0.0; g_v54_vwap_v=0.0;
   g_v54_asia_hi=0.0; g_v54_asia_lo=0.0; g_v54_asia_has=false;
   ArrayInitialize(g_v54_day_ranges,0.0); g_v54_day_range_count=0; g_v54_day_range_head=0;
   V54ResetAgg(g_v54_h5); V54ResetAgg(g_v54_h15); V54ResetAgg(g_v54_h30); V54ResetAgg(g_v54_h60);
   g_v54_map_h1_c=g_v54_map_h1_e20=g_v54_map_h1_e50=V54_INVALID;
   g_v54_map_m15_c=g_v54_map_m15_e20=V54_INVALID;
   g_v54_map_m5_o=g_v54_map_m5_h=g_v54_map_m5_l=g_v54_map_m5_c=g_v54_map_m5_e20=V54_INVALID;
   g_v54_map_m30_sup48=g_v54_map_m30_dem48=g_v54_map_m30_atr14=V54_INVALID;
   g_v54_m30_count=0; ArrayInitialize(g_v54_m30_high,0.0); ArrayInitialize(g_v54_m30_low,0.0); ArrayInitialize(g_v54_m30_tr,0.0);
   g_v54_history_first_bar=0; g_v54_history_last_bar=0; g_v54_exact_tick_bars=0; g_v54_tick_fallback_bars=0;
  }

double V54EMA(const double prev,const double x,const int n)
  {
   double a=2.0/(n+1.0);
   return(a*x+(1.0-a)*prev);
  }

void V54FinalizeM30(SV54Agg &a)
  {
   double sup=V54_INVALID,dem=V54_INVALID;
   if(g_v54_m30_count>=48)
     {
      sup=-1.0e300; dem=1.0e300;
      for(int j=1;j<=48;j++)
        {
         long ai=g_v54_m30_count-j;
         int ri=(int)(ai%V54_M30_RING_CAP);
         if(ri<0) ri+=V54_M30_RING_CAP;
         if(g_v54_m30_high[ri]>sup) sup=g_v54_m30_high[ri];
         if(g_v54_m30_low[ri]<dem) dem=g_v54_m30_low[ri];
        }
     }
   double tr=a.h-a.l;
   if(a.prev_close_ready)
      tr=MathMax(tr,MathMax(MathAbs(a.h-a.prev_close),MathAbs(a.l-a.prev_close)));
   double atr14=V54_INVALID;
   if(g_v54_m30_count+1>=14)
     {
      double s=tr;
      for(int j=1;j<14;j++)
        {
         long ai=g_v54_m30_count-j;
         int ri=(int)(ai%V54_M30_RING_CAP);
         if(ri<0) ri+=V54_M30_RING_CAP;
         s+=g_v54_m30_tr[ri];
        }
      atr14=s/14.0;
     }
   int wi=(int)(g_v54_m30_count%V54_M30_RING_CAP);
   g_v54_m30_high[wi]=a.h; g_v54_m30_low[wi]=a.l; g_v54_m30_tr[wi]=tr;
   g_v54_m30_count++;
   g_v54_map_m30_sup48=sup; g_v54_map_m30_dem48=dem; g_v54_map_m30_atr14=atr14;
   a.prev_close=a.c; a.prev_close_ready=true;
   a.count++;
  }

void V54FinalizeAgg(SV54Agg &a,const int tf_min)
  {
   if(!a.active) return;
   if(tf_min==30)
     {
      V54FinalizeM30(a);
      return;
     }
   if(!a.ema20_ready) { a.ema20=a.c; a.ema20_ready=true; }
   else a.ema20=V54EMA(a.ema20,a.c,20);
   if(tf_min==60)
     {
      if(!a.ema50_ready) { a.ema50=a.c; a.ema50_ready=true; }
      else a.ema50=V54EMA(a.ema50,a.c,50);
      g_v54_map_h1_c=a.c; g_v54_map_h1_e20=a.ema20; g_v54_map_h1_e50=a.ema50;
     }
   else if(tf_min==15)
     {
      g_v54_map_m15_c=a.c; g_v54_map_m15_e20=a.ema20;
     }
   else if(tf_min==5)
     {
      g_v54_map_m5_o=a.o; g_v54_map_m5_h=a.h; g_v54_map_m5_l=a.l; g_v54_map_m5_c=a.c; g_v54_map_m5_e20=a.ema20;
     }
   a.prev_close=a.c; a.prev_close_ready=true;
   a.count++;
  }

void V54AggAdd(SV54Agg &a,const MqlRates &r,const int tf_min)
  {
   long bucket=(long)r.time/(tf_min*60);
   if(a.active && bucket!=a.bucket)
     {
      V54FinalizeAgg(a,tf_min);
      a.active=false;
     }
   if(!a.active)
     {
      a.active=true; a.bucket=bucket; a.o=r.open; a.h=r.high; a.l=r.low; a.c=r.close; a.v=(long)r.tick_volume;
     }
   else
     {
      if(r.high>a.h) a.h=r.high;
      if(r.low<a.l) a.l=r.low;
      a.c=r.close; a.v+=(long)r.tick_volume;
     }
   if((((long)r.time+60)%(tf_min*60))==0)
     {
      V54FinalizeAgg(a,tf_min);
      a.active=false;
     }
  }

void V54PushCompletedDayRange(const double r)
  {
   if(r<0.0 || !MathIsValidNumber(r)) return;
   g_v54_day_ranges[g_v54_day_range_head]=r;
   g_v54_day_range_head=(g_v54_day_range_head+1)%V54_DAY_RING_CAP;
   if(g_v54_day_range_count<V54_DAY_RING_CAP) g_v54_day_range_count++;
  }

double V54Prev20DayMean()
  {
   if(g_v54_day_range_count<20) return(V54_INVALID);
   double s=0.0;
   for(int j=1;j<=20;j++)
     {
      int idx=g_v54_day_range_head-j;
      while(idx<0) idx+=V54_DAY_RING_CAP;
      s+=g_v54_day_ranges[idx];
     }
   return(s/20.0);
  }

bool V54ExactMinuteFromTicks(const long bar_start_sec,MqlRates &r,double &disp60,double &disp5,double &cnt60,double &cnt5)
  {
   ulong from_msc=(ulong)bar_start_sec*1000;
   ulong to_msc=(ulong)(bar_start_sec+60)*1000-1;
   MqlTick ticks[];
   int n=CopyTicksRange(_Symbol,ticks,COPY_TICKS_ALL,from_msc,to_msc);
   if(n<=0) return(false);
   double o=ticks[0].bid,h=o,l=o,c=o;
   for(int i=1;i<n;i++)
     {
      double b=ticks[i].bid;
      if(b>h) h=b;
      if(b<l) l=b;
      c=b;
     }
   r.open=o; r.high=h; r.low=l; r.close=c; r.tick_volume=n;
   cnt60=(double)n; disp60=ticks[n-1].bid-ticks[0].bid;
   ulong s5=(ulong)(bar_start_sec+55)*1000;
   int i5=0;
   while(i5<n && ticks[i5].time_msc<s5) i5++;
   if(i5<n)
     {
      cnt5=(double)(n-i5); disp5=ticks[n-1].bid-ticks[i5].bid;
     }
   else
     {
      cnt5=0.0; disp5=0.0;
     }
   return(true);
  }

double V54OldTR(const int n)
  {
   if(g_v54_bar_count<n) return(0.0);
   SV54Bar z; if(!V54GetAbs(g_v54_bar_count-n,z)) return(0.0); return(z.tr);
  }

double V54OldVol(const int n)
  {
   if(g_v54_bar_count<n) return(0.0);
   SV54Bar z; if(!V54GetAbs(g_v54_bar_count-n,z)) return(0.0); return((double)z.v);
  }

double V54OldClose(const int n)
  {
   if(g_v54_bar_count<n) return(0.0);
   SV54Bar z; if(!V54GetAbs(g_v54_bar_count-n,z)) return(0.0); return(z.c);
  }

double V54OldRet(const int n)
  {
   if(g_v54_bar_count<n) return(0.0);
   SV54Bar z; if(!V54GetAbs(g_v54_bar_count-n,z)) return(0.0); return(z.ret);
  }

double V54OldATR14(const int n)
  {
   if(g_v54_bar_count<n) return(V54_INVALID);
   SV54Bar z; if(!V54GetAbs(g_v54_bar_count-n,z)) return(V54_INVALID); return(z.atr14);
  }

bool V54AppendBar(const MqlRates &rin,const bool exact_ticks,const bool exact_required,SV54Bar &f)
  {
   MqlRates r; r=rin;
   double d60=0.0,d5=0.0,c60=0.0,c5=0.0;
   bool exact=false;
   if(exact_ticks) exact=V54ExactMinuteFromTicks((long)r.time,r,d60,d5,c60,c5);
   if(exact) g_v54_exact_tick_bars++;
   else
     {
      g_v54_tick_fallback_bars++;
      c60=(double)r.tick_volume;
      if(exact_required) return(false);
     }

   f.time_sec=(long)r.time; f.o=r.open; f.h=r.high; f.l=r.low; f.c=r.close; f.v=(long)r.tick_volume;
   f.tick_disp60=d60; f.tick_disp5=d5; f.tick_cnt60=c60; f.tick_cnt5=c5;
   if(g_v54_bar_count==0) f.tr=f.h-f.l;
   else
     {
      SV54Bar p; V54GetBack(0,p);
      f.tr=MathMax(f.h-f.l,MathMax(MathAbs(f.h-p.c),MathAbs(f.l-p.c)));
     }
   f.ret=0.0;
   if(g_v54_bar_count>0) { SV54Bar p; V54GetBack(0,p); f.ret=MathAbs(f.c-p.c); }

   // Previous-bar means, exactly matching rolling_prev_* exclusion of current bar.
   f.act3=(g_v54_bar_count>=3 && g_v54_volsum3>0.0 ? f.v/(g_v54_volsum3/3.0) : V54_INVALID);
   f.act5=(g_v54_bar_count>=5 && g_v54_volsum5>0.0 ? f.v/(g_v54_volsum5/5.0) : V54_INVALID);
   f.act20=(g_v54_bar_count>=20 && g_v54_volsum20>0.0 ? f.v/(g_v54_volsum20/20.0) : V54_INVALID);
   f.act30=(g_v54_bar_count>=30 && g_v54_volsum30>0.0 ? f.v/(g_v54_volsum30/30.0) : V54_INVALID);
   f.activity_ratio=(g_v54_bar_count>=60 && g_v54_volsum60>0.0 ? f.v/(g_v54_volsum60/60.0) : V54_INVALID);
   if(g_v54_bar_count>=10)
     {
      f.mean10=g_v54_closesum10/10.0;
      double vv=g_v54_closesq10/10.0-f.mean10*f.mean10;
      if(vv<0.0 && vv>-1e-9) vv=0.0;
      f.std10=(vv>=0.0 ? MathSqrt(vv) : V54_INVALID);
     }
   else { f.mean10=V54_INVALID; f.std10=V54_INVALID; }

   // ATR rolling sums including current TR.
   double s5=g_v54_trsum5+f.tr-(g_v54_bar_count>=5 ? V54OldTR(5) : 0.0);
   double s7=g_v54_trsum7+f.tr-(g_v54_bar_count>=7 ? V54OldTR(7) : 0.0);
   double s10=g_v54_trsum10+f.tr-(g_v54_bar_count>=10 ? V54OldTR(10) : 0.0);
   double s14=g_v54_trsum14+f.tr-(g_v54_bar_count>=14 ? V54OldTR(14) : 0.0);
   double s21=g_v54_trsum21+f.tr-(g_v54_bar_count>=21 ? V54OldTR(21) : 0.0);
   double s28=g_v54_trsum28+f.tr-(g_v54_bar_count>=28 ? V54OldTR(28) : 0.0);
   double s30=g_v54_trsum30+f.tr-(g_v54_bar_count>=30 ? V54OldTR(30) : 0.0);
   f.atr5=(g_v54_bar_count+1>=5 ? s5/5.0 : V54_INVALID);
   f.atr7=(g_v54_bar_count+1>=7 ? s7/7.0 : V54_INVALID);
   f.atr10=(g_v54_bar_count+1>=10 ? s10/10.0 : V54_INVALID);
   f.atr14=(g_v54_bar_count+1>=14 ? s14/14.0 : V54_INVALID);
   f.atr21=(g_v54_bar_count+1>=21 ? s21/21.0 : V54_INVALID);
   f.atr28=(g_v54_bar_count+1>=28 ? s28/28.0 : V54_INVALID);
   f.atr30=(g_v54_bar_count+1>=30 ? s30/30.0 : V54_INVALID);

   // V5.5C quality-only ATR ratio: exact algorithmic counterpart of Python:
   // atr14 = (TR_cumsum[i+1]-TR_cumsum[i+1-14])/14
   // prev_atr = mean(previous 240 finite atr14) via ATR14 cumulative-sum subtraction.
   // The parent V5.4 f.atr14/f.atr_ratio above are intentionally NOT changed.
   double v55c_tr_cum_after_current=g_v55c_tr_cum+f.tr;
   double v55c_tr_prefix_before=0.0;
   if(g_v54_bar_count>=14)
     {
      long ai=g_v54_bar_count-14;
      v55c_tr_prefix_before=g_v55c_tr_cum_after[V54RingIndexAbs(ai)];
     }
   double v55c_atr14_py=V54_INVALID;
   if(g_v54_bar_count+1>=14) v55c_atr14_py=(v55c_tr_cum_after_current-v55c_tr_prefix_before)/14.0;

   double v55c_prev_atr_py=V54_INVALID;
   if(g_v54_bar_count>=240)
     {
      double old_sum=0.0; long old_count=0;
      if(g_v54_bar_count>240)
        {
         long ai=g_v54_bar_count-241;
         int ri=V54RingIndexAbs(ai);
         old_sum=g_v55c_atr14_cum_after[ri];
         old_count=g_v55c_atr14_count_after[ri];
        }
      double ws=g_v55c_atr14_cum-old_sum;
      long wc=g_v55c_atr14_count-old_count;
      if(wc>0) v55c_prev_atr_py=ws/(double)wc;
     }
   f.v55c_atr_ratio_py=(V54Valid(v55c_atr14_py) && V54Valid(v55c_prev_atr_py) && v55c_prev_atr_py>0.0 ? v55c_atr14_py/v55c_prev_atr_py : V54_INVALID);

   // Recursive EMA exactly seeded with the first raw M1 close.
   if(!g_v54_m1_ema_ready)
     {
      g_v54_m1_ema5=f.c; g_v54_m1_ema10=f.c; g_v54_m1_ema20=f.c; g_v54_m1_ema_ready=true;
     }
   else
     {
      g_v54_m1_ema5=V54EMA(g_v54_m1_ema5,f.c,5);
      g_v54_m1_ema10=V54EMA(g_v54_m1_ema10,f.c,10);
      g_v54_m1_ema20=V54EMA(g_v54_m1_ema20,f.c,20);
     }
   f.ema5=g_v54_m1_ema5; f.ema10=g_v54_m1_ema10; f.ema20=g_v54_m1_ema20;

   // Daily range, session VWAP, Asia 00-06 UTC/session-axis range.
   long day=f.time_sec/86400;
   int hour=(int)((f.time_sec%86400)/3600); if(hour<0) hour+=24; f.hour=hour;
   if(g_v54_day!=day)
     {
      if(g_v54_day>=0) V54PushCompletedDayRange(g_v54_day_hi-g_v54_day_lo);
      g_v54_day=day; g_v54_day_hi=f.h; g_v54_day_lo=f.l;
      g_v54_vwap_pv=0.0; g_v54_vwap_v=0.0;
      g_v54_asia_hi=0.0; g_v54_asia_lo=0.0; g_v54_asia_has=false;
     }
   else
     {
      if(f.h>g_v54_day_hi) g_v54_day_hi=f.h;
      if(f.l<g_v54_day_lo) g_v54_day_lo=f.l;
     }
   double prev20=V54Prev20DayMean();
   f.day_range_ratio=(V54Valid(prev20) && prev20>0.0 ? (g_v54_day_hi-g_v54_day_lo)/prev20 : V54_INVALID);
   double w=(f.v>0 ? (double)f.v : 1.0);
   double tp=(f.h+f.l+f.c)/3.0; g_v54_vwap_pv+=tp*w; g_v54_vwap_v+=w;
   f.vwap=(g_v54_vwap_v>0.0 ? g_v54_vwap_pv/g_v54_vwap_v : V54_INVALID);
   if(hour>=0 && hour<6)
     {
      if(!g_v54_asia_has) { g_v54_asia_hi=f.h; g_v54_asia_lo=f.l; g_v54_asia_has=true; }
      else { if(f.h>g_v54_asia_hi) g_v54_asia_hi=f.h; if(f.l<g_v54_asia_lo) g_v54_asia_lo=f.l; }
     }
   if(hour>=6 && g_v54_asia_has) { f.asia_hi=g_v54_asia_hi; f.asia_lo=g_v54_asia_lo; }
   else { f.asia_hi=V54_INVALID; f.asia_lo=V54_INVALID; }

   // Finalize HTF bars as they become causally available at this M1 bar's close.
   V54AggAdd(g_v54_h5,r,5); V54AggAdd(g_v54_h15,r,15); V54AggAdd(g_v54_h30,r,30); V54AggAdd(g_v54_h60,r,60);
   f.h1_c=g_v54_map_h1_c; f.h1_ema20=g_v54_map_h1_e20; f.h1_ema50=g_v54_map_h1_e50;
   f.m15_c=g_v54_map_m15_c; f.m15_ema20=g_v54_map_m15_e20;
   f.m5_o=g_v54_map_m5_o; f.m5_h=g_v54_map_m5_h; f.m5_l=g_v54_map_m5_l; f.m5_c=g_v54_map_m5_c; f.m5_ema20=g_v54_map_m5_e20;
   f.m30_sup48=g_v54_map_m30_sup48; f.m30_dem48=g_v54_map_m30_dem48; f.m30_atr14=g_v54_map_m30_atr14;

   // Regime features.
   f.atr_bps=(V54Valid(f.atr14) && f.c>0.0 ? f.atr14/f.c*10000.0 : V54_INVALID);
   double prevatr=(g_v54_bar_count>=240 && g_v54_atr14cnt240>0 ? g_v54_atr14sum240/g_v54_atr14cnt240 : V54_INVALID);
   f.atr_ratio=(V54Valid(prevatr) && prevatr>0.0 && V54Valid(f.atr14) ? f.atr14/prevatr : V54_INVALID);
   f.vol_ratio=(V54Valid(f.atr7) && V54Valid(f.atr28) && f.atr28>0.0 ? f.atr7/f.atr28 : V54_INVALID);
   f.eff30=V54_INVALID; f.trend30=V54_INVALID;
   double new_ret_sum=g_v54_retsum30+f.ret-(g_v54_bar_count>=30 ? V54OldRet(30) : 0.0);
   if(g_v54_bar_count>=30)
     {
      double c30=V54OldClose(30);
      double disp=MathAbs(f.c-c30);
      if(new_ret_sum>0.0) f.eff30=disp/new_ret_sum;
      if(V54Valid(f.atr14) && f.atr14>0.0) f.trend30=disp/f.atr14;
     }

   // Commit bar to ring.
   int wi=V54RingIndexAbs(g_v54_bar_count);
   g_v54_ring[wi]=f;
   g_v54_bar_count++;
   if(g_v54_history_first_bar==0) g_v54_history_first_bar=f.time_sec;
   g_v54_history_last_bar=f.time_sec;

   // Commit rolling sums for next bar.
   g_v54_trsum5=s5; g_v54_trsum7=s7; g_v54_trsum10=s10; g_v54_trsum14=s14; g_v54_trsum21=s21; g_v54_trsum28=s28; g_v54_trsum30=s30;
   g_v54_volsum3=g_v54_volsum3+f.v-(g_v54_bar_count-1>=3 ? V54OldVol(4) : 0.0);
   g_v54_volsum5=g_v54_volsum5+f.v-(g_v54_bar_count-1>=5 ? V54OldVol(6) : 0.0);
   g_v54_volsum20=g_v54_volsum20+f.v-(g_v54_bar_count-1>=20 ? V54OldVol(21) : 0.0);
   g_v54_volsum30=g_v54_volsum30+f.v-(g_v54_bar_count-1>=30 ? V54OldVol(31) : 0.0);
   g_v54_volsum60=g_v54_volsum60+f.v-(g_v54_bar_count-1>=60 ? V54OldVol(61) : 0.0);
   g_v54_closesum10=g_v54_closesum10+f.c-(g_v54_bar_count-1>=10 ? V54OldClose(11) : 0.0);
   g_v54_closesq10=g_v54_closesq10+f.c*f.c-(g_v54_bar_count-1>=10 ? MathPow(V54OldClose(11),2.0) : 0.0);
   g_v54_retsum30=new_ret_sum;
   double olda=(g_v54_bar_count-1>=240 ? V54OldATR14(241) : V54_INVALID);
   if(V54Valid(olda)) { g_v54_atr14sum240-=olda; g_v54_atr14cnt240--; }
   if(V54Valid(f.atr14)) { g_v54_atr14sum240+=f.atr14; g_v54_atr14cnt240++; }

   // Commit Python-prefix quality state after all current-bar features have been calculated.
   g_v55c_tr_cum=v55c_tr_cum_after_current;
   if(V54Valid(v55c_atr14_py)) { g_v55c_atr14_cum+=v55c_atr14_py; g_v55c_atr14_count++; }
   int v55c_pri=V54RingIndexAbs(g_v54_bar_count-1);
   g_v55c_tr_cum_after[v55c_pri]=g_v55c_tr_cum;
   g_v55c_atr14_cum_after[v55c_pri]=g_v55c_atr14_cum;
   g_v55c_atr14_count_after[v55c_pri]=g_v55c_atr14_count;
   return(true);
  }

bool V54PassBound(const double x,const double lo,const double hi)
  {
   bool active_lo=(lo>-1.0e90),active_hi=(hi<1.0e90);
   if((active_lo || active_hi) && !V54Valid(x)) return(false);
   if(active_lo && x<lo) return(false);
   if(active_hi && x>hi) return(false);
   return(true);
  }

bool V54PassSession(const int hour,const int sid)
  {
   if(sid==0) return(true);
   if(sid==1) return(hour>=0 && hour<6);
   if(sid==2) return(hour>=6 && hour<12);
   if(sid==3) return(hour>=12 && hour<17);
   if(sid==4) return(hour>=17 && hour<22);
   if(sid==5) return(hour>=6 && hour<22);
   if(sid==6) return(hour>=6 && hour<17);
   if(sid==7) return(hour>=12 && hour<22);
   if(sid==8) return(hour>=6);
   return(true);
  }

bool V54PassGate(const int src,const SV54Bar &f,const int side)
  {
   if(!V54PassBound(f.atr_bps,V54_GATE_ATR_BPS_LO[src],V54_GATE_ATR_BPS_HI[src])) return(false);
   if(!V54PassBound(f.atr_ratio,V54_GATE_ATR_RATIO_LO[src],V54_GATE_ATR_RATIO_HI[src])) return(false);
   if(!V54PassBound(f.activity_ratio,V54_GATE_ACTIVITY_RATIO_LO[src],V54_GATE_ACTIVITY_RATIO_HI[src])) return(false);
   if(!V54PassBound(f.vol_ratio,V54_GATE_VOL_RATIO_LO[src],V54_GATE_VOL_RATIO_HI[src])) return(false);
   if(!V54PassBound(f.eff30,V54_GATE_EFF30_LO[src],V54_GATE_EFF30_HI[src])) return(false);
   if(!V54PassBound(f.trend30,V54_GATE_TREND30_LO[src],V54_GATE_TREND30_HI[src])) return(false);
   if(!V54PassBound(f.day_range_ratio,V54_GATE_DAY_RANGE_RATIO_LO[src],V54_GATE_DAY_RANGE_RATIO_HI[src])) return(false);
   if(!V54PassSession(f.hour,V54_GATE_SESSION_ID[src])) return(false);
   int sm=V54_GATE_SIDE_MODE[src]; if(sm!=0 && side!=sm) return(false);
   return(true);
  }

double V54BodyRatio(const SV54Bar &f)
  {
   double r=f.h-f.l; return(r>0.0 ? MathAbs(f.c-f.o)/r : 0.0);
  }

double V54UpperWickRatio(const double o,const double h,const double l,const double c)
  {
   double r=h-l; if(r<=0.0) return(0.0); return((h-MathMax(o,c))/r);
  }

double V54LowerWickRatio(const double o,const double h,const double l,const double c)
  {
   double r=h-l; if(r<=0.0) return(0.0); return((MathMin(o,c)-l)/r);
  }

double V54ATRByN(const SV54Bar &f,const int n)
  {
   if(n==5) return(f.atr5); if(n==7) return(f.atr7); if(n==10) return(f.atr10); if(n==14) return(f.atr14);
   if(n==21) return(f.atr21); if(n==28) return(f.atr28); if(n==30) return(f.atr30); return(V54_INVALID);
  }

double V54ActByN(const SV54Bar &f,const int n)
  {
   if(n==3) return(f.act3); if(n==5) return(f.act5); if(n==20) return(f.act20); if(n==30) return(f.act30); return(V54_INVALID);
  }

bool V54RawSignal(const int src,const SV54Bar &f,int &side,double &atr)
  {
   side=0; atr=V54ATRByN(f,V54_SIG_ATR_N[src]);
   if(!V54Valid(atr) || atr<=0.0) return(false);
   double rng=f.h-f.l, br=V54BodyRatio(f);
   double uw=V54UpperWickRatio(f.o,f.h,f.l,f.c),lw=V54LowerWickRatio(f.o,f.h,f.l,f.c);
   double act=V54ActByN(f,V54_SIG_ACTIVITY_N[src]);
   SV54Bar p1,p2,p3;

   if(src==0) // HF02 breakout -> retest sleeve (P812-HF02X)
     {
      if(!V54GetBack(1,p1) || !V54Valid(act)) return(false);
      int lb=V54_SIG_LOOKBACK[src];
      if(lb<1) return(false);
      double levelh=-1.0e100, levell=1.0e100;
      for(int j=2;j<=lb+1;j++)
        {
         SV54Bar pj; if(!V54GetBack(j,pj)) return(false);
         if(pj.h>levelh) levelh=pj.h;
         if(pj.l<levell) levell=pj.l;
        }
      double p1atr=V54ATRByN(p1,V54_SIG_ATR_N[src]);
      if(!V54Valid(p1atr) || p1atr<=0.0) return(false);
      bool broke_up=(p1.c>levelh+V54_SIG_X1[src]*p1atr);
      bool broke_dn=(p1.c<levell-V54_SIG_X1[src]*p1atr);
      bool buy=broke_up && f.l<=levelh+V54_SIG_X3[src]*atr && f.c>levelh && f.c>f.o && br>=V54_SIG_X2[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      bool sell=broke_dn && f.h>=levell-V54_SIG_X3[src]*atr && f.c<levell && f.c<f.o && br>=V54_SIG_X2[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      if(buy) side=1; if(sell) side=-1;
     }
   else if(src==1) // HF05 EMA compression -> expansion
     {
      if(!V54GetBack(1,p1) || !V54Valid(act)) return(false);
      double spread_prev=MathMax(p1.ema5,MathMax(p1.ema10,p1.ema20))-MathMin(p1.ema5,MathMin(p1.ema10,p1.ema20));
      bool prev_comp=V54Valid(p1.atr21) && spread_prev<=V54_SIG_X1[src]*p1.atr21;
      bool common=prev_comp && rng>=V54_SIG_X2[src]*atr && br>=V54_SIG_X3[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      if(common && f.c>f.o) side=1; else if(common && f.c<f.o) side=-1;
     }
   else if(src==2) // HF14 inside bar expansion
     {
      if(!V54GetBack(1,p1) || !V54GetBack(2,p2) || !V54Valid(act)) return(false);
      bool inside=(p1.h<=p2.h && p1.l>=p2.l);
      bool common=inside && rng>=V54_SIG_X3[src]*atr && br>=V54_SIG_X2[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      if(common && f.c>p1.h+V54_SIG_X1[src]*atr) side=1;
      else if(common && f.c<p1.l-V54_SIG_X1[src]*atr) side=-1;
     }
   else if(src==3) // HF17 M30 supply/demand + completed M5 rejection
     {
      if(!V54Valid(f.m30_atr14) || !V54Valid(f.act20)) return(false);
      long entry_sec=f.time_sec+60;
      if((entry_sec%(5*60))!=0) return(false);
      double m5rng=f.m5_h-f.m5_l;
      if(!V54Valid(f.m5_o) || m5rng<=0.0) return(false);
      double m5uw=V54UpperWickRatio(f.m5_o,f.m5_h,f.m5_l,f.m5_c);
      double m5lw=V54LowerWickRatio(f.m5_o,f.m5_h,f.m5_l,f.m5_c);
      double m5body=MathAbs(f.m5_c-f.m5_o)/m5rng;
      bool common=(f.act20>=V54_SIG_MIN_ACTIVITY[src]);
      bool zsell=V54Valid(f.m30_sup48) && f.m5_h>=f.m30_sup48-V54_SIG_ZONE_WIDTH[src]*f.m30_atr14 && f.m5_c<f.m30_sup48;
      bool zbuy =V54Valid(f.m30_dem48) && f.m5_l<=f.m30_dem48+V54_SIG_ZONE_WIDTH[src]*f.m30_atr14 && f.m5_c>f.m30_dem48;
      bool rsell=(m5uw>=V54_SIG_WICK_MIN[src] && m5body>=V54_SIG_BODY_MIN[src] && f.m5_c<f.m5_o);
      bool rbuy =(m5lw>=V54_SIG_WICK_MIN[src] && m5body>=V54_SIG_BODY_MIN[src] && f.m5_c>f.m5_o);
      if(common && zbuy && rbuy) side=1;
      if(common && zsell && rsell) side=-1; // same assignment order as Python
     }
   else if(src==4) // HF08 Asia sweep fade
     {
      if(!V54Valid(f.asia_hi) || !V54Valid(act)) return(false);
      bool active=(f.hour>=6 && f.hour<18);
      bool buy=active && f.l<=f.asia_lo-V54_SIG_X1[src]*atr && f.c>f.asia_lo && lw>=V54_SIG_X3[src] && br>=V54_SIG_X2[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      bool sell=active && f.h>=f.asia_hi+V54_SIG_X1[src]*atr && f.c<f.asia_hi && uw>=V54_SIG_X3[src] && br>=V54_SIG_X2[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      if(buy) side=1; if(sell) side=-1;
     }
   else if(src==5) // HF09 Asia sweep continuation/retest
     {
      if(!V54Valid(f.asia_hi) || !V54Valid(act) || !V54GetBack(1,p1)) return(false);
      bool active=(f.hour>=6 && f.hour<18);
      double buf=V54_SIG_X1[src]*atr;
      bool buy=active && p1.c>f.asia_hi+buf && f.l<=f.asia_hi+buf && f.c>f.asia_hi && f.c>f.o && br>=V54_SIG_X2[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      bool sell=active && p1.c<f.asia_lo-buf && f.h>=f.asia_lo-buf && f.c<f.asia_lo && f.c<f.o && br>=V54_SIG_X2[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      if(buy) side=1; if(sell) side=-1;
     }
   else if(src==6) // HF10 micro mean reversion
     {
      if(!V54Valid(f.mean10) || !V54Valid(f.std10) || !V54Valid(act)) return(false);
      double z=V54SafeRatio(f.c-f.mean10,f.std10);
      bool common=(rng<=V54_SIG_X3[src]*atr && act>=V54_SIG_MIN_ACTIVITY[src]);
      if(common && z<=-V54_SIG_X1[src] && lw>=V54_SIG_X2[src] && f.c>f.o) side=1;
      if(common && z>= V54_SIG_X1[src] && uw>=V54_SIG_X2[src] && f.c<f.o) side=-1;
     }
   else if(src==7) // HF01 MTF trend pullback
     {
      if(!V54GetBack(3,p3) || !V54Valid(act) || !V54Valid(f.h1_c) || !V54Valid(f.h1_ema20) || !V54Valid(f.h1_ema50) || !V54Valid(f.m15_c) || !V54Valid(f.m15_ema20) || !V54Valid(f.m5_ema20) || !V54Valid(p3.h1_ema20)) return(false);
      double slope=(f.h1_ema20-p3.h1_ema20)/MathMax(atr,1e-9);
      bool buy=(f.h1_ema20>f.h1_ema50 && f.h1_c>f.h1_ema20 && f.m15_c>f.m15_ema20 && f.l<=f.m5_ema20+V54_SIG_X1[src]*atr && f.c>f.m5_ema20 && f.c>f.o && br>=V54_SIG_X2[src] && slope>=V54_SIG_X3[src] && act>=V54_SIG_MIN_ACTIVITY[src]);
      bool sell=(f.h1_ema20<f.h1_ema50 && f.h1_c<f.h1_ema20 && f.m15_c<f.m15_ema20 && f.h>=f.m5_ema20-V54_SIG_X1[src]*atr && f.c<f.m5_ema20 && f.c<f.o && br>=V54_SIG_X2[src] && slope<=-V54_SIG_X3[src] && act>=V54_SIG_MIN_ACTIVITY[src]);
      if(buy) side=1; if(sell) side=-1;
     }
   else if(src==8) // HF12 tick acceleration reversal
     {
      if(f.tick_cnt60<=0.0 || f.tick_cnt5<=0.0) return(false);
      double burst=V54SafeRatio(f.tick_cnt5,f.tick_cnt60/12.0);
      if(f.tick_disp60<=-V54_SIG_X1[src]*atr && f.tick_disp5>=V54_SIG_X2[src]*atr && burst>=V54_SIG_X3[src]) side=1;
      if(f.tick_disp60>= V54_SIG_X1[src]*atr && f.tick_disp5<=-V54_SIG_X2[src]*atr && burst>=V54_SIG_X3[src]) side=-1;
     }
   else if(src==9) // HF04 VWAP trend pullback
     {
      if(!V54GetBack(3,p3) || !V54Valid(act) || !V54Valid(f.vwap) || !V54Valid(f.h1_ema20) || !V54Valid(f.h1_ema50) || !V54Valid(p3.h1_ema20)) return(false);
      double dist=MathAbs(f.l-f.vwap)/MathMax(atr,1e-9);
      double dist2=MathAbs(f.h-f.vwap)/MathMax(atr,1e-9);
      double slope=(f.h1_ema20-p3.h1_ema20)/MathMax(atr,1e-9);
      bool buy=(f.h1_ema20>f.h1_ema50 && dist<=V54_SIG_X1[src] && f.c>f.vwap && f.c>f.o && br>=V54_SIG_X2[src] && slope>=V54_SIG_X3[src] && act>=V54_SIG_MIN_ACTIVITY[src]);
      bool sell=(f.h1_ema20<f.h1_ema50 && dist2<=V54_SIG_X1[src] && f.c<f.vwap && f.c<f.o && br>=V54_SIG_X2[src] && slope<=-V54_SIG_X3[src] && act>=V54_SIG_MIN_ACTIVITY[src]);
      if(buy) side=1; if(sell) side=-1;
     }
   else if(src==10) // HF07 impulse shallow pullback
     {
      if(!V54GetBack(1,p1) || !V54GetBack(2,p2) || !V54Valid(act) || !V54Valid(p1.atr5)) return(false);
      double imp=p1.c-p2.c;
      bool up=imp>=V54_SIG_X1[src]*p1.atr5;
      bool dn=imp<=-V54_SIG_X1[src]*p1.atr5;
      double retr_up=MathMax(0.0,p1.c-f.l), retr_dn=MathMax(0.0,f.h-p1.c);
      bool buy=up && retr_up<=V54_SIG_X2[src]*MathAbs(imp) && f.c>f.o && br>=V54_SIG_X3[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      bool sell=dn && retr_dn<=V54_SIG_X2[src]*MathAbs(imp) && f.c<f.o && br>=V54_SIG_X3[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      if(buy) side=1; if(sell) side=-1;
     }
   else if(src==11) // HF06 volatility squeeze release, frozen SELL-only regime gate later
     {
      if(!V54GetBack(1,p1) || !V54Valid(act) || !V54Valid(p1.atr5) || !V54Valid(p1.atr30) || !V54Valid(f.atr30)) return(false);
      double ratio=V54SafeRatio(p1.atr5,p1.atr30);
      bool prevsq=(ratio<=V54_SIG_X1[src]);
      bool common=prevsq && rng>=V54_SIG_X2[src]*f.atr30 && br>=V54_SIG_X3[src] && act>=V54_SIG_MIN_ACTIVITY[src];
      if(common && f.c>f.o) side=1; if(common && f.c<f.o) side=-1;
     }
   if(side==0) return(false);
   return(true);
  }

double V55CAlignedMom(const SV54Bar &f,const int side,const int lag)
  {
   if(!V54Valid(f.atr14) || f.atr14<=0.0) return(V54_INVALID);
   SV54Bar p; if(!V54GetBack(lag,p)) return(V54_INVALID);
   return(side*(f.c-p.c)/f.atr14);
  }

bool V55CPassQuality(const int src,const SV54Bar &f,const int side)
  {
   if(src<0 || src>=V54_CONFIG_COUNT) return(false);
   double rng=f.h-f.l;
   double dir_mom5=V55CAlignedMom(f,side,5);
   double dir_mom15=V55CAlignedMom(f,side,15);
   double dir_trend30=V55CAlignedMom(f,side,30);
   double dir_body1=(V54Valid(f.atr14) && f.atr14>0.0 ? side*(f.c-f.o)/f.atr14 : V54_INVALID);
   double close_loc=V54_INVALID;
   if(rng>0.0) close_loc=(side>0 ? (f.c-f.l)/rng : (f.h-f.c)/rng);
   double range_atr=(V54Valid(f.atr14) && f.atr14>0.0 ? rng/f.atr14 : V54_INVALID);
   if(!V54PassBound(dir_mom5,V55C_Q_DIR_MOM5_LO[src],V55C_Q_DIR_MOM5_HI[src])) return(false);
   if(!V54PassBound(dir_mom15,V55C_Q_DIR_MOM15_LO[src],V55C_Q_DIR_MOM15_HI[src])) return(false);
   if(!V54PassBound(dir_trend30,V55C_Q_DIR_TREND30_LO[src],V55C_Q_DIR_TREND30_HI[src])) return(false);
   if(!V54PassBound(dir_body1,V55C_Q_DIR_BODY1_LO[src],V55C_Q_DIR_BODY1_HI[src])) return(false);
   if(!V54PassBound(close_loc,V55C_Q_CLOSE_LOC_LO[src],V55C_Q_CLOSE_LOC_HI[src])) return(false);
   if(!V54PassBound(range_atr,V55C_Q_RANGE_ATR_LO[src],V55C_Q_RANGE_ATR_HI[src])) return(false);
   if(!V54PassBound(f.v55c_atr_ratio_py,V55C_Q_ATR_RATIO_LO[src],V55C_Q_ATR_RATIO_HI[src])) return(false);
   if(!V54PassBound(f.activity_ratio,V55C_Q_ACTIVITY_RATIO_LO[src],V55C_Q_ACTIVITY_RATIO_HI[src])) return(false);
   if(!V54PassBound(f.vol_ratio,V55C_Q_VOL_RATIO_LO[src],V55C_Q_VOL_RATIO_HI[src])) return(false);
   if(!V54PassBound(f.eff30,V55C_Q_EFF30_LO[src],V55C_Q_EFF30_HI[src])) return(false);
   if(!V54PassBound(f.day_range_ratio,V55C_Q_DAY_RANGE_RATIO_LO[src],V55C_Q_DAY_RANGE_RATIO_HI[src])) return(false);
   return(true);
  }

int V54GenerateUnion(const SV54Bar &f,int &chosen_src,int &chosen_side,double &chosen_atr,int &raw_candidates,int &regime_candidates,int &quality_candidates,bool &conflict,int &candidate_src[],int &candidate_side[],double &candidate_atr[])
  {
   raw_candidates=0; regime_candidates=0; quality_candidates=0; conflict=false; chosen_src=-1; chosen_side=0; chosen_atr=0.0;
   g_v55c_hf12_regime_seen=false; g_v55c_hf12_quality_pass=false; g_v55c_hf12_side=0; g_v55c_hf12_atr=0.0;
   g_v55c_hf12_dir_mom5=g_v55c_hf12_close_loc=g_v55c_hf12_atr_ratio_legacy=g_v55c_hf12_atr_ratio_py=V54_INVALID;
   int pos_count=0,neg_count=0;
   for(int src=0;src<V54_CONFIG_COUNT;src++)
     {
      if(V54_F_SELECTED[src]==0) continue;
      int side=0; double atr=0.0;
      if(!V54RawSignal(src,f,side,atr)) continue;
      raw_candidates++;
      if(!V54PassGate(src,f,side)) continue;
      regime_candidates++;
      if(src==8)
        {
         g_v55c_hf12_regime_seen=true; g_v55c_hf12_side=side; g_v55c_hf12_atr=atr;
         g_v55c_hf12_dir_mom5=V55CAlignedMom(f,side,5);
         double rr=f.h-f.l;
         g_v55c_hf12_close_loc=(rr>0.0 ? (side>0 ? (f.c-f.l)/rr : (f.h-f.c)/rr) : V54_INVALID);
         g_v55c_hf12_atr_ratio_legacy=f.atr_ratio;
         g_v55c_hf12_atr_ratio_py=f.v55c_atr_ratio_py;
        }
      bool qpass=V55CPassQuality(src,f,side);
      if(src==8) g_v55c_hf12_quality_pass=qpass;
      if(!qpass) continue;
      if(quality_candidates<12)
        {
         candidate_src[quality_candidates]=src; candidate_side[quality_candidates]=side; candidate_atr[quality_candidates]=atr;
        }
      quality_candidates++;
      if(side>0) pos_count++; else if(side<0) neg_count++;
     }
   if(quality_candidates<=0) return(0);
   if(pos_count>0 && neg_count>0) { conflict=true; return(0); }
   int best=0;
   for(int j=1;j<quality_candidates && j<12;j++)
      if(V55C_P812_PRIORITY_SCORE[candidate_src[j]]>V55C_P812_PRIORITY_SCORE[candidate_src[best]]) best=j;
   chosen_src=candidate_src[best]; chosen_side=candidate_side[best]; chosen_atr=candidate_atr[best];
   return(1);
  }

#endif