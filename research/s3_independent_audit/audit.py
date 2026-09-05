"""Frozen, standard-library offline audit. Never reads September outcomes.
No EA changes, strategy implementation, parameter sweeps, or new tick simulation.
"""
import csv, pathlib, statistics as st, math, random, collections, json, hashlib
ROOT=pathlib.Path(__file__).resolve().parents[2]; OUT=pathlib.Path(__file__).resolve().parent
CUTOFF='2026.09.01'; manifest=[]
def read(name):
 p=ROOT/'data'/name
 manifest.append({'file':name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 with p.open() as f:
  for r in csv.DictReader(f):
   date=r.get('event_time',r.get('signal_time',r.get('entry_time',r.get('time',''))))
   if date and date>=CUTOFF: continue
   yield r
def write(name,rows):
 if not rows:return
 with (OUT/name).open('w') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def mean(x):return st.fmean(x) if x else None
def metrics(x):
 if not x:return {'n':0}
 s=sorted(x);n=len(x);k=int(n*.1);pos=sum(v for v in x if v>0);neg=-sum(v for v in x if v<0)
 return dict(n=n,mean=mean(x),median=st.median(x),trim10=mean(s[k:n-k]),exbest1=mean(s[:-1]),extop3=mean(s[:-3]),extop5=mean(s[:-5]),worst1=s[0],worst3_sum=sum(s[:3]),pf=pos/neg if neg else None,positive=sum(v>1e-10 for v in x)/n,negative=sum(v< -1e-10 for v in x)/n)
def growth(x,dates,f):
 eq=peak=1.;dd=0.;logs=[];run=maxrun=0;daily=collections.defaultdict(float)
 for v,d in zip(x,dates):
  if 1+f*v<=0:return {'risk':f,'ruin':True}
  logs.append(math.log1p(f*v));eq*=1+f*v;peak=max(peak,eq);dd=min(dd,eq/peak-1);run=run+1 if v<0 else 0;maxrun=max(maxrun,run);daily[d[:10]]+=v
 return dict(reference_risk=f,compounded_return=eq-1,closed_opportunity_max_dd=dd,mean_log_growth=mean(logs),worst_day_R=min(daily.values()),max_consecutive_losses=maxrun)
def partition(t):return 'JAN_JUN' if t<'2026.07' else 'JUL_AUG'
def bootstrap(pairs,seed=3103,B=10000):
 # pairs=(day,value). Resample days, preserve all events in sampled day.
 a=collections.defaultdict(list)
 for day,v in pairs:a[day].append(v)
 vals=[(sum(a[d]),len(a[d])) for d in sorted(a)];rng=random.Random(seed);out=[]
 for _ in range(B):
  samp=rng.choices(vals,k=len(vals));out.append(sum(v for v,n in samp)/sum(n for v,n in samp))
 out.sort()
 return dict(days=len(vals),bootstrap_B=B,ci95_low=out[int(B*.025)],ci95_high=out[int(B*.975)],ci98333_low=out[int(B/120)],ci98333_high=out[int(B*(1-1/120))])
# Inventory is outcome-date bounded. Deduplication is explicit by run/split.
s2=[];layers=[];detail=[]
for stamp in ['1767312000','1780272000']:
 for r in read(f'RamusenEA_candidate_s2_XAUUSD_PERIOD_M5_{stamp}.csv'):
  if stamp=='1780272000' and r['signal_time']<'2026.07':continue
  s2.append(r)
 for r in read(f'RamusenEA_controlled_layer_summary_XAUUSD_PERIOD_M5_{stamp}.csv'):
  if stamp=='1780272000' and r['signal_time']<'2026.07':continue
  layers.append(r)
 for r in read(f'RamusenEA_controlled_layer_detail_XAUUSD_PERIOD_M5_{stamp}.csv'):
  if stamp=='1780272000' and r['signal_time']<'2026.07':continue
  detail.append(r)
res={};s2out=[]
for part in ['JAN_JUN','JUL_AUG','ALL']:
 a=sorted([r for r in s2 if r['status']=='OK' and r['s2_gate']=='ELIGIBLE' and (part=='ALL' or partition(r['signal_time'])==part)],key=lambda r:r['signal_time'])
 for c in [0,.5,1,1.5,2,2.5,3]:
  x=[float(r['observed_r'])-c/(float(r['stop_distance'])/float(r['entry_bid'])*10000) for r in a]
  s2out.append({'partition':part,'extra_cost_bps':c,**metrics(x),**growth(x,[r['signal_time'] for r in a],.005)})
 res['s2_'+part]={'shadow':metrics([float(r['shadow_10m_bps']) for r in a]),'stop_bps_median':st.median(float(r['stop_distance'])/float(r['entry_bid'])*10000 for r in a),'gross_stopped_bps':metrics([(float(r['entry_bid'])-float(r['exit_ask']))/float(r['entry_bid'])*10000 for r in a])}
write('s2_metrics.csv',s2out)
layerout=[];layeropp=[];layergrowth=[];layermonth=[]
for part in ['JAN_JUN','JUL_AUG','ALL']:
 a=[r for r in layers if r['status']=='OK' and (part=='ALL' or partition(r['signal_time'])==part)]
 controls={r['research_join_key']:r for r in a if r['max_layers']=='1'}
 for cap in [1,3,5,7,10]:
  ar=sorted([r for r in a if int(r['max_layers'])==cap],key=lambda r:r['signal_time'])
  for c in [0,.5,1,1.5,2,2.5,3]:
   def net(r):return float(r['gross_total_r'])-c*(float(r['gross_total_r'])-float(r['nominal_total_r_1bps']))
   x=[net(r) for r in ar];inc=[net(r)-net(controls[r['research_join_key']]) for r in ar]
   layerout.append({'partition':part,'cap':cap,'extra_cost_bps':c,'avg_tickets':mean([int(r['layers_opened']) for r in ar]),'max_tickets':max(int(r['layers_opened']) for r in ar),**{'total_'+k:v for k,v in metrics(x).items()},**{'inc_'+k:v for k,v in metrics(inc).items()}})
   for f in [.0025,.005]:layergrowth.append({'partition':part,'cap':cap,'extra_cost_bps':c,**growth(x,[r['signal_time'] for r in ar],f)})
   if part=='ALL':
    for r,v,d in zip(ar,x,inc):layeropp.append({'opportunity':r['research_join_key'],'time':r['signal_time'],'cap':cap,'extra_cost_bps':c,'tickets':r['layers_opened'],'total_R':v,'incremental_R':d})
   if part=='ALL' and c==1:
    for m in sorted({r['signal_time'][:7] for r in ar}):
     vals=[d for r,d in zip(ar,inc) if r['signal_time'].startswith(m)]
     layermonth.append({'month':m,'cap':cap,**metrics(vals)})
write('old_layer_metrics.csv',layerout);write('old_layer_opportunities.csv',layeropp);write('old_layer_growth.csv',layergrowth);write('old_layer_months.csv',layermonth)
# Check detail aggregates against source summaries.
sums=collections.defaultdict(lambda:[0.,0.,0]); maxerrs=[0.,0.,0.]
for r in detail:
 a=sums[(r['research_join_key'],r['max_layers'])];a[0]+=float(r['observed_r']);a[1]+=float(r['nominal_net_r_1bps']);a[2]+=1
for r in layers:
 if r['status']!='OK':continue
 a=sums[(r['research_join_key'],r['max_layers'])]
 for i,k in enumerate(['gross_total_r','nominal_total_r_1bps','layers_opened']):maxerrs[i]=max(maxerrs[i],abs(a[i]-float(r[k])))
res['layer_detail_summary_max_errors']=maxerrs
# S3.0 full inventory and paired return decomposition.
events=collections.defaultdict(dict);status=collections.Counter();raw=[];consistency=0.;dups=0
for r in read('RamusenEA_s30_event_control_XAUUSD_PERIOD_M5_1767225600.csv'):
 h=int(r['horizon_minutes']);status[(h,r['status'])]+=1
 if h in events[r['event_key']]:dups+=1
 events[r['event_key']][h]=r
 if r['status']=='OK':
  calc=(float(r['entry_bid'])-float(r['future_ask']))/float(r['entry_bid'])*10000
  consistency=max(consistency,abs(calc-float(r['executable_return_bps'])))
res['s30_integrity']={'events':len(events),'crossovers':sum(e[10]['group']=='CROSSOVER_EVENT' for e in events.values()),'duplicate_event_horizon':dups,'return_recalc_max_error':consistency,'status':{str(k):v for k,v in status.items()}}
for part in ['JAN_JUN','JUL_AUG','ALL']:
 for group in ['CROSSOVER_EVENT','CONTEXT_ONLY']:
  for h in [1,3,5,10,15,30,60,90]:
   a=[e[h] for e in events.values() if e[h]['status']=='OK' and e[h]['group']==group and (part=='ALL' or partition(e[h]['event_time'])==part)]
   raw.append({'partition':part,'group':group,'horizon':h,**metrics([float(r['executable_return_bps']) for r in a])})
write('s30_raw_returns.csv',raw)
paired=[];pairedmetrics=[];monthly=[];ci=[]
for h in [10,15,30]:
 cohort=[e for e in events.values() if e[h]['group']=='CROSSOVER_EVENT' and all(e[v]['status']=='OK' for v in [1,3,5,h])]
 for e in cohort:
  base=e[h];b0=float(base['entry_bid']);ask=float(base['future_ask']);r0=(b0-ask)/b0*10000
  for d in [0,1,3,5]:
   bid=b0 if d==0 else float(e[d]['future_bid']);rd=(bid-ask)/bid*10000
   paired.append({'opportunity':base['event_key'],'time':base['event_time'],'partition':partition(base['event_time']),'deadline_minutes':h,'delay_minutes':d,'entry_bid':bid,'exit_ask':ask,'gross_executable_bps':rd,'control_bps':r0,'incremental_bps':rd-r0,'entry_improvement_original_bps':(bid-b0)/b0*10000,'entry_delay_ms':0 if d==0 else int(e[d]['delay_milliseconds'])})
for part in ['JAN_JUN','JUL_AUG','ALL']:
 for h in [10,15,30]:
  for d in [0,1,3,5]:
   a=[r for r in paired if r['deadline_minutes']==h and r['delay_minutes']==d and (part=='ALL' or r['partition']==part)]
   pairedmetrics.append({'partition':part,'deadline_minutes':h,'delay_minutes':d,**{'gross_'+k:v for k,v in metrics([r['gross_executable_bps'] for r in a]).items()},**{'inc_'+k:v for k,v in metrics([r['incremental_bps'] for r in a]).items()}})
for d in [0,1,3,5]:
 for m in sorted({r['time'][:7] for r in paired}):
  a=[r for r in paired if r['deadline_minutes']==10 and r['delay_minutes']==d and r['time'].startswith(m)]
  monthly.append({'month':m,'delay_minutes':d,**{'gross_'+k:v for k,v in metrics([r['gross_executable_bps'] for r in a]).items()},'inc_mean':mean([r['incremental_bps'] for r in a])})
for d in [1,3,5]:
 a=[r for r in paired if r['deadline_minutes']==10 and r['delay_minutes']==d]
 ci.append({'delay_minutes':d,'entry_improvement_mean':mean([r['entry_improvement_original_bps'] for r in a]),**bootstrap([(r['time'][:10],r['entry_improvement_original_bps']) for r in a])})
write('paired_snapshot_opportunities.csv',paired);write('paired_snapshot_metrics.csv',pairedmetrics);write('paired_snapshot_months.csv',monthly);write('paired_entry_bootstrap.csv',ci)
# Exact context join by event milliseconds; no nearest-time joins and no thresholds.
contexts={}
for stamp in ['1767312000','1780272000']:
 for r in read(f'RamusenEA_scalping_context_XAUUSD_PERIOD_M5_{stamp}.csv'):
  if stamp=='1780272000' and r['signal_time']<'2026.07':continue
  if r['side']=='SELL':contexts[r['signal_time_msc']]=r
feat=[]
for e in events.values():
 r=e[10]
 if r['group']!='CROSSOVER_EVENT' or r['status']!='OK':continue
 c=contexts.get(r['event_time_msc'])
 if not c:continue
 try:
  o,h,l,cl=[float(c['m5_bar1_'+s]) for s in ['open','high','low','close']];span=h-l
  vals={s:float(c[s]) for s in ['m5_atr_bps','spread_to_atr_ratio','m5_fast_slope_points','m15_fast_slope_points','m15_ema_separation_bps','m5_signal_momentum_3bar_bps','m5_bar1_body_to_range','m5_bar1_range_to_atr']}
  vals['sell_close_location']=(h-cl)/span;vals['upper_minus_lower_wick_ratio']=((h-max(o,cl))-(min(o,cl)-l))/span
  feat.append({'time':r['event_time'],'partition':partition(r['event_time']),'return_bps':float(r['executable_return_bps']),**vals})
 except (ValueError,ZeroDivisionError):pass

def ranks(x):
 ix=sorted(range(len(x)),key=lambda i:x[i]);out=[0.]*len(x);i=0
 while i<len(ix):
  j=i+1
  while j<len(ix) and x[ix[j]]==x[ix[i]]:j+=1
  for k in ix[i:j]:out[k]=(i+j-1)/2
  i=j
 return out

def corr(x,y):
 a=ranks(x);b=ranks(y);ma=mean(a);mb=mean(b);den=math.sqrt(sum((v-ma)**2 for v in a)*sum((v-mb)**2 for v in b))
 return sum((v-ma)*(w-mb) for v,w in zip(a,b))/den if den else None
featureout=[]
if feat:
 for key in list(feat[0])[3:]:
  for part in ['JAN_JUN','JUL_AUG','ALL']:
   a=[r for r in feat if part=='ALL' or r['partition']==part]
   featureout.append({'feature':key,'partition':part,'n':len(a),'spearman':corr([r[key] for r in a],[r['return_bps'] for r in a])})
write('feature_rank_screen.csv',featureout)
res['context_joined_crossovers']=len(feat)
# S3.0 control estimator supplied without its hash/sampling implementation: do NOT
# claim to reproduce that CI. Raw context comparison is explicitly a different estimator.
res['s30_matched_control_reproduction']='NOT_REPRODUCIBLE: daily selection/hash rule and original analysis script absent'
(OUT/'audit_summary.json').write_text(json.dumps(res,indent=2))
write('input_manifest.csv',manifest)
print(json.dumps(res,indent=2))
print('Saved',len(paired),'paired snapshot rows; no MQL5 changes.')
