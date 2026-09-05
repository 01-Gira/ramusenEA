"""Independent S3.1 tick replay, integrity gate and paired mechanism analysis.
Usage: python3 evaluate.py result.csv --s30 prior_s30.csv --out results/run
Reads only January–August 2026. No strategy parameter selection.
"""
import argparse,collections,csv,datetime,hashlib,json,math,pathlib,random,statistics as st
CUTOFF=1788220800000  # 2026-09-01, same epoch convention as MT5 CSV server timestamps
DELAYS={'CONTROL':0,'DELAY_1':60000,'DELAY_3':180000,'DELAY_5':300000}
VIEWS=['COMMON_DEADLINE','EQUAL_HOLD']
ROOT=pathlib.Path(__file__).resolve().parent

def first_quote(ticks,target,start=0):
 for i in range(start,len(ticks)):
  t,b,a=ticks[i]
  if t<target:continue
  if t-target>30000:return None
  if math.isfinite(b) and math.isfinite(a) and b>0 and a>=b:return i
 return None

def path_stats(ticks,entry,end,atr):
 et,b,ea=ticks[entry];xt,xb,xa=ticks[end];path=ticks[entry:end+1]
 lo=min(range(len(path)),key=lambda i:path[i][2]);hi=max(range(len(path)),key=lambda i:path[i][2])
 fav=max(0,b-path[lo][2]);adv=max(0,path[hi][2]-b);distance=atr*1.25
 stop=next((i for i in range(entry,end+1) if ticks[i][2]>=b+distance),None)
 risk_exit=stop if stop is not None else end
 return {'gross_executable_bps':(b-xa)/b*10000,'mid_return_bps':((b+ea)-(xb+xa))/(b+ea)*10000,
         'gross_r':(b-xa)/distance,'mfe_bps':fav/b*10000,'mae_bps':adv/b*10000,'mfe_atr':fav/atr,'mae_atr':adv/atr,
         'best_ask':path[lo][2],'worst_ask':path[hi][2],'time_to_mfe_ms':path[lo][0]-et if fav>0 else -1,
         'time_to_mae_ms':path[hi][0]-et if adv>0 else -1,'ticks_scanned':len(path),
         'max_tick_gap_ms':max((path[i][0]-path[i-1][0] for i in range(1,len(path))),default=0),
         'stop_price':b+distance,'stop_hit':'YES' if stop is not None else 'NO','stop_time_msc':ticks[stop][0] if stop is not None else '',
         'risk_exit_time_msc':ticks[risk_exit][0],'risk_exit_ask':ticks[risk_exit][2],
         'stop_r':(b-ticks[risk_exit][2])/distance,'stop_through_price':ticks[stop][2]-(b+distance) if stop is not None else 0}

def stats(x):
 if not x:return {'n':0}
 y=sorted(x);n=len(y);k=n//10
 def avg(a):return st.fmean(a) if a else None
 return {'n':n,'mean':avg(y),'median':st.median(y),'positive_rate':sum(v>1e-9 for v in y)/n,
         'negative_rate':sum(v< -1e-9 for v in y)/n,'trim10':avg(y[k:n-k]),'exbest1':avg(y[:-1]),
         'extop3':avg(y[:-3]),'extop5':avg(y[:-5]),'worst1':y[0],'stddev':st.stdev(y) if n>1 else None}

def bootstrap(dates,x,B=10000):
 by=collections.defaultdict(list)
 for d,v in zip(dates,x):by[d[:10]].append(v)
 groups=[(sum(v),len(v)) for d,v in sorted(by.items())];rng=random.Random(3103)
 if not groups:return {}
 draws=[]
 for _ in range(B):
  sample=rng.choices(groups,k=len(groups));draws.append(sum(s for s,n in sample)/sum(n for s,n in sample))
 draws.sort()
 return {'event_days':len(groups),'ci95_low':draws[int(B*.025)],'ci95_high':draws[int(B*.975)],
         'ci98333_low':draws[int(B/120)],'ci98333_high':draws[int(B*(1-1/120))]}

def write(path,rows):
 if not rows:return
 keys=list(dict.fromkeys(k for r in rows for k in r))
 with path.open('w') as f:
  w=csv.DictWriter(f,keys);w.writeheader();w.writerows(rows)

def validate(path,s30=None,full_reference=False):
 with path.open() as f:rows=list(csv.DictReader(f))
 events=collections.defaultdict(dict);errors=[];paths=collections.defaultdict(list)
 def need(condition,msg):
  if not condition:errors.append(msg)
 def close(a,b,msg):need(math.isclose(float(a),float(b),abs_tol=2e-7,rel_tol=1e-8),msg)
 for r in rows:
  need(None not in r and all(v is not None for v in r.values()),'malformed row')
  t=int(r['original_event_time_msc']);need(t<CUTOFF,'reserved event')
  k=(r['arm'],r['exit_view']);need(k not in events[t],f'duplicate {t} {k}');events[t][k]=r
 tp=path.with_name(path.stem+'_ticks.csv')
 with tp.open() as f:
  for r in csv.DictReader(f):
   t=int(r['original_event_time_msc']);tick=(int(r['time_msc']),float(r['bid']),float(r['ask']))
   need(tick[0]<CUTOFF,'reserved tick');need(int(r['tick_index'])==len(paths[t]),f'tick sequence {t}')
   need(t<=tick[0]<=t+960000,'tick bounds');need(tick[1]>0 and tick[2]>=tick[1] and all(math.isfinite(v) for v in tick),'invalid tick')
   need(not paths[t] or paths[t][-1][0]<=tick[0],'nonmonotonic ticks');paths[t].append(tick)
 need(set(paths).issubset(events),'orphan tick opportunity')
 status=collections.Counter()
 for t,arms in events.items():
  need(set(arms)=={(a,v) for a in DELAYS for v in VIEWS},f'incomplete arms {t}')
  baseline=arms.get(('CONTROL','COMMON_DEADLINE'))
  for (arm,view),r in arms.items():
   status[r['status']]+=1;need(arm in DELAYS and view in VIEWS,'unknown arm/view')
   for field in ['original_bid','original_ask','original_atr','m5_fast2','m5_slow2','m5_fast1','m5_slow1','original_context_fast','original_context_slow']:
    need(r[field]==baseline[field],f'original snapshot differs {t} {field}')
   need(float(r['m5_fast2'])>=float(r['m5_slow2']) and float(r['m5_fast1'])<float(r['m5_slow1']) and float(r['original_context_fast'])<float(r['original_context_slow']),'event predicate')
   close(r['stop_distance'],1.25*float(r['original_atr']),'frozen ATR')
   need(int(r['entry_target_msc'])==t+DELAYS[arm],'entry clock')
   need(int(r['common_deadline_target_msc'])==t+600000,'common clock')
   need(int(r['signal_m5_bar_time_msc'])+300000<=t,'unclosed event bar')
   need(int(r['original_m15_bar_time_msc'])+900000<=t,'unclosed context bar')
   if r['status'] not in ['OK','ENTRY_MISSING','EXIT_MISSING','PENDING_AT_SHUTDOWN']:need(False,f'corrupt status {r["status"]}')
   if r['entry_time_msc']:
    et=int(r['entry_time_msc']);i=int(r['entry_tick_index']);ticks=paths[t]
    need(et>=t+DELAYS[arm] and et-(t+DELAYS[arm])<=30000,'entry latency')
    need(int(r['equal_hold_target_msc'])==et+600000,'equal hold clock')
    need(int(r['exit_target_msc'])==(t+600000 if view=='COMMON_DEADLINE' else et+600000),'exit clock')
    need(ticks[i][0]==et,'entry sequence time');close(ticks[i][1],r['entry_bid'],'entry BID');close(ticks[i][2],r['entry_ask'],'entry ASK')
    close(r['entry_delay_ms'],et-int(r['entry_target_msc']),'entry delay field')
    bid,ask=ticks[i][1:]
    close(r['entry_spread_points'],(ask-bid)/float(r['point']),'entry spread points')
    close(r['entry_spread_bps'],(ask-bid)/((ask+bid)/2)*10000,'entry spread bps')
    if arm!='CONTROL':need(i==first_quote(ticks,t+DELAYS[arm]),'not first delayed quote')
    else:close(r['entry_bid'],r['original_bid'],'control BID');close(r['entry_ask'],r['original_ask'],'control ASK')
    if r['entry_context']!='UNAVAILABLE':
     need(int(r['entry_context_bar_time_msc'])+900000<=et,'future entry context')
     cf,cs=float(r['entry_context_fast']),float(r['entry_context_slow'])
     need(r['entry_context']==('BEARISH' if cf<cs else 'BULLISH' if cf>cs else 'FLAT'),'context state')
    for field,den in [('entry_improvement_price',1),('entry_improvement_points',float(r['point'])),('entry_improvement_bps',float(r['original_bid'])/10000)]:close(r[field],(float(r['entry_bid'])-float(r['original_bid']))/den,field)
   if r['status']=='OK':
    j=int(r['exit_tick_index']);need(j==first_quote(ticks,int(r['exit_target_msc']),i),'not first exit quote')
    need(ticks[j][0]==int(r['exit_time_msc']),'exit sequence time');close(ticks[j][2],r['exit_ask'],'exit ASK')
    close(ticks[j][1],r['exit_bid'],'exit BID')
    close(r['exit_delay_ms'],ticks[j][0]-int(r['exit_target_msc']),'exit delay field')
    close(r['holding_ms'],ticks[j][0]-et,'holding time field')
    for field,value in path_stats(ticks,i,j,float(r['original_atr'])).items():
     if isinstance(value,str):need(r[field]==value,field)
     else:close(r[field],value,f'{t} {arm} {view} {field}')
    for c in [0,.5,1,1.5,2]:close(r['net_bps_'+str(c).replace('.','_')],float(r['gross_executable_bps'])-c,'cost equation')
   else:
    target=int(r['exit_target_msc'] if r['entry_time_msc'] else r['entry_target_msc'])
    start=int(r['entry_tick_index']) if r['entry_time_msc'] else 0
    need(first_quote(paths[t],target,start) is None,'missing quote actually exists')
    expected='PENDING_AT_SHUTDOWN' if int(r['observed_path_end_msc'])<target+30000 else ('EXIT_MISSING' if r['entry_time_msc'] else 'ENTRY_MISSING')
    need(r['status']==expected,'missing versus pending status')
 ref_count=None
 if s30:
  ref={}
  with s30.open() as f:
   for r in csv.DictReader(f):
    if r['group']!='CROSSOVER_EVENT' or r['horizon_minutes']!='10':continue
    t=int(r['event_time_msc'])
    if t>=CUTOFF:raise ValueError('Reserved S30 outcome refused')
    if full_reference or (events and min(events)<=t<=max(events)):ref[t]=r
  ref_count=len(ref);need(set(ref)==set(events),'S30 event set mismatch in run interval')
  for t,r in ref.items():
   if t not in events:continue
   ours=events[t][('CONTROL','COMMON_DEADLINE')]
   for left,right in [('original_bid','entry_bid'),('original_ask','entry_ask'),('m5_fast2','m5_fast_ema_bar2'),('m5_slow2','m5_slow_ema_bar2'),('m5_fast1','m5_fast_ema_bar1'),('m5_slow1','m5_slow_ema_bar1')]:close(ours[left],r[right],'S30 '+left)
   if r['status']=='OK' and ours['status']=='OK':close(ours['exit_ask'],r['future_ask'],'S30 target ASK')
 mf=path.with_name(path.stem+'_manifest.txt').read_text();need('integrity=OK' in mf,'run manifest integrity');need(f'events={len(events)}\n' in mf,'event footer count')
 for key,count in [('rows',len(rows)),('ok',status['OK']),('missing',status['ENTRY_MISSING']+status['EXIT_MISSING']),('pending',status['PENDING_AT_SHUTDOWN'])]:need(f'{key}={count}\n' in mf,'footer '+key)
 result={'integrity':'PASS' if not errors else 'FAIL','events':len(events),'rows':len(rows),'ticks':sum(map(len,paths.values())),'status_counts':dict(status),'s30_matched_events':ref_count,'errors':errors[:100],'error_count':len(errors),'source_csv_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 return events,result

def mechanism_decision(mechanisms,n,coverage_ok):
 # User's negative mechanism rule is not a positive validation claim. Preserve
 # coverage warning separately; ordinary missingness is not integrity corruption.
 if n<20:return 'INCONCLUSIVE'
 if mechanisms and all(r['robust_failure'] for r in mechanisms.values()):return 'DELAY_MECHANISM_REJECTED'
 if coverage_ok and any(r['supported'] for r in mechanisms.values()):return 'DELAY_MECHANISM_SUPPORTED'
 return 'INCONCLUSIVE'

def evaluate(events,out,B=10000):
 abs_rows=[];pair_rows=[];quality=[];cost_rows=[];mechanisms={};cohorts={}
 def date(t):return datetime.datetime.fromtimestamp(t/1000,datetime.timezone.utc).strftime('%Y.%m.%d')
 def partitions(ids):
  return {'ALL':ids,'JAN_JUN':[t for t in ids if date(t)<'2026.07'],'JUL_AUG':[t for t in ids if date(t)>='2026.07'],
          'JAN_MAR':[t for t in ids if date(t)<'2026.04'],'APR_JUN':[t for t in ids if '2026.04'<=date(t)<'2026.07'],
          **{m:[t for t in ids if date(t).startswith(m)] for m in sorted({date(t)[:7] for t in ids})}}
 for view in VIEWS:
  ids=sorted(t for t,a in events.items() if all(a[(arm,view)]['status']=='OK' for arm in DELAYS));cohorts[view]=len(ids)
  for part,ts in partitions(ids).items():
   if not ts:continue
   dates=[date(t) for t in ts]
   for arm in DELAYS:
    x=[float(events[t][(arm,view)]['gross_executable_bps']) for t in ts];ci=bootstrap(dates,x,B)
    summary={'view':view,'arm':arm,'partition':part,**stats(x),**ci};abs_rows.append(summary)
    for c in [0,.5,1,1.5,2]:
     cost_rows.append({'view':view,'arm':arm,'partition':part,'extra_cost_bps':c,**stats([v-c for v in x]),'ci95_low':ci['ci95_low']-c,'ci95_high':ci['ci95_high']-c})
    for field in ['mae_bps','mfe_bps','mae_atr','mfe_atr','stop_r']:
     q=[float(events[t][(arm,view)][field]) for t in ts]
     quality.append({'view':view,'arm':arm,'partition':part,'metric':field,**stats(q),'stop_rate':st.fmean(events[t][(arm,view)]['stop_hit']=='YES' for t in ts)})
    if arm=='CONTROL':continue
    delta=[float(events[t][(arm,view)]['gross_executable_bps'])-float(events[t][('CONTROL',view)]['gross_executable_bps']) for t in ts]
    pair_rows.append({'view':view,'arm':arm,'partition':part,'metric':'gross_executable_bps',**stats(delta),**bootstrap(dates,delta,B)})
    for field in ['mae_bps','mfe_bps','mae_atr','mfe_atr','stop_r','entry_improvement_price','entry_improvement_points','entry_improvement_bps']:
     delta=[float(events[t][(arm,view)][field])-float(events[t][('CONTROL',view)][field]) for t in ts]
     row={'view':view,'arm':arm,'partition':part,'metric':field,**stats(delta)}
     if part=='ALL':row.update(bootstrap(dates,delta,B))
     pair_rows.append(row)
 # Mechanism decision uses all delays equally, declared noninferiority margins.
 def get(rows,arm,part='ALL',metric=None):
  return next(r for r in rows if r['view']=='EQUAL_HOLD' and r['arm']==arm and r['partition']==part and (metric is None or r['metric']==metric))
 sufficient=cohorts.get('EQUAL_HOLD',0)>=20 and cohorts.get('EQUAL_HOLD',0)/max(1,len(events))>=.99
 for arm in list(DELAYS)[1:]:
  if not cohorts['EQUAL_HOLD']:continue
  a=get(abs_rows,arm);c=get(abs_rows,'CONTROL');p=get(pair_rows,arm,metric='gross_executable_bps')
  def val(k):return p.get(k) is not None and p[k]>0
  ids=sorted(t for t,arms in events.items() if all(arms[(a,'EQUAL_HOLD')]['status']=='OK' for a in DELAYS))
  delta={t:float(events[t][(arm,'EQUAL_HOLD')]['gross_executable_bps'])-float(events[t][('CONTROL','EQUAL_HOLD')]['gross_executable_bps']) for t in ids}
  months=sorted({date(t)[:7] for t in ids});lom={m:st.fmean(v for t,v in delta.items() if not date(t).startswith(m)) for m in months if any(not date(t).startswith(m) for t in ids)}
  chron=[]
  for block in ['JAN_MAR','APR_JUN','JUL_AUG']:
   matched=[r for r in pair_rows if r['view']=='EQUAL_HOLD' and r['arm']==arm and r['partition']==block and r['metric']=='gross_executable_bps']
   chron.append(bool(matched) and matched[0]['mean']>0)
  criteria={'mean':a['mean']>c['mean'],'absolute_trim':a['trim10']>c['trim10'],
            'absolute_exbest1':a['exbest1'] is not None and a['exbest1']>c['exbest1'],
            'paired_trim':val('trim10'),'paired_exbest1':val('exbest1'),'paired_extop3':val('extop3'),
            'simultaneous_ci':p['ci98333_low']>0,'mae_noninferior':get(pair_rows,arm,metric='mae_atr')['mean']<=.10,
            'mfe_noninferior':get(pair_rows,arm,metric='mfe_atr')['mean']>=-.10,'chronology':all(chron),
            'leave_one_month_out':len(lom)>=3 and min(lom.values())>0}
  mechanisms[arm]={'criteria':criteria,'supported':all(criteria.values()),'robust_failure':p['mean']<=0 or p['trim10']<=0 or (p['exbest1'] is not None and p['exbest1']<=0),'leave_one_month_out_means':lom}
 decision=mechanism_decision(mechanisms,cohorts.get('EQUAL_HOLD',0),sufficient)
 write(out/'arm_metrics.csv',abs_rows);write(out/'paired_metrics.csv',pair_rows);write(out/'excursion_stop_metrics.csv',quality);write(out/'cost_metrics.csv',cost_rows)
 result={'decision':decision,'classification':'CONTAMINATED_MECHANISM_RESEARCH_ONLY','cohort_counts':cohorts,'complete_case_coverage':{v:n/max(1,len(events)) for v,n in cohorts.items()},'coverage_and_sample_gate':sufficient,'coverage_note':'A failed 99% coverage flag blocks support, not the user-defined negative verdict on observed paired opportunities; missing outcomes remain unknown.','delays':mechanisms,'cost_note':'Same one-ticket bps charge cancels in paired bps differences; absolute net expectancy still deteriorates.'}
 (out/'decision.json').write_text(json.dumps(result,indent=2)+'\n');return result

def main():
 ap=argparse.ArgumentParser();ap.add_argument('csv',type=pathlib.Path);ap.add_argument('--s30',type=pathlib.Path);ap.add_argument('--out',type=pathlib.Path,required=True);ap.add_argument('--integrity-only',action='store_true');ap.add_argument('--require-full-reference',action='store_true');args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
 events,integrity=validate(args.csv,args.s30,args.require_full_reference);(args.out/'integrity.json').write_text(json.dumps(integrity,indent=2)+'\n');print(json.dumps(integrity,indent=2))
 if integrity['integrity']!='PASS':raise SystemExit(1)
 if not args.integrity_only:print(json.dumps(evaluate(events,args.out),indent=2))
if __name__=='__main__':main()
