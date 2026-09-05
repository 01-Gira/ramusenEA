"""Stage/compile S31 and run an isolated portable historical tester.
Never changes installed trading source or copies live chart profiles.
Wine launch requires desktop/sandbox authorization. No credentials are printed.
"""
import argparse,pathlib,shutil,subprocess,os,json,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
MT=pathlib.Path('/Users/ramusen/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5')
WINE='/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine'
PREFIX='/Users/ramusen/Library/Application Support/net.metaquotes.wine.metatrader5'
STAGE=pathlib.Path('/private/tmp/ramusen-s31-mt5')
def env():
 e=os.environ.copy();e['WINEPREFIX']=PREFIX;e['WINEDEBUG']='-all';e['MVK_CONFIG_LOG_LEVEL']='0';return e

def stage():
 STAGE.mkdir(exist_ok=True)
 for exe in ['terminal64.exe','metaeditor64.exe','metatester64.exe']:
  dst=STAGE/exe
  if not dst.exists():shutil.copy2(MT/exe,dst)
 shutil.copytree(MT/'MQL5/Include',STAGE/'MQL5/Include',dirs_exist_ok=True)
 shutil.copytree(ROOT/'Include/RamusenEA',STAGE/'MQL5/Include/RamusenEA',dirs_exist_ok=True)
 (STAGE/'MQL5/Experts/S31Research').mkdir(parents=True,exist_ok=True)
 shutil.copy2(ROOT/'Experts/RamusenEA/RamusenEA.mq5',STAGE/'MQL5/Experts/S31Research/RamusenEA.mq5')
 # Isolated portable terminal: only feed configuration/cache, never charts/EAs.
 for folder in ['config','Bases/MetaQuotes-Demo']:
  def ignore(directory,names):
   return [n for n in names if n.startswith('202609') or n in ['terminal.ini','community.ini']]
  if (MT/folder).exists():shutil.copytree(MT/folder,STAGE/folder,dirs_exist_ok=True,ignore=ignore)
 (STAGE/'MQL5/Profiles/Tester').mkdir(parents=True,exist_ok=True)
 vals={'InpS31PairedDelayedEntryResearchEnabled':'true','InpS30EventGeneratorControlResearchEnabled':'true',
       'InpEnableTrading':'false','InpExecutionTest':'false','InpBaselineStrategyEnabled':'false',
       'InpSignalResearchEnabled':'false','InpScalpingContextResearchEnabled':'false','InpP2F4EntryGateResearchEnabled':'false',
       'InpP2F5ExcursionResearchEnabled':'false','InpP2F6TimeExitResearchEnabled':'false','InpP2F7ProfitRetentionResearchEnabled':'false',
       'InpP2F11CAdaptiveRetentionResearchEnabled':'false','InpP2F12CandidateS2ResearchEnabled':'false','InpP2F14ControlledLayerResearchEnabled':'false',
       'InpFastMAPeriod':'9','InpSlowMAPeriod':'21','InpScalpingContextTimeframe':'15','InpScalpingContextFastMAPeriod':'20','InpScalpingContextSlowMAPeriod':'50','InpScalpingATRPeriod':'14'}
 for test in ['functional','full','guard']:
  v=dict(vals)
  if test=='guard':v['InpEnableTrading']='true' # OnInit must fail before any market/order processing.
  (STAGE/'MQL5/Profiles/Tester'/f's31_{test}.set').write_text('\n'.join(f'{k}={val}' for k,val in v.items())+'\n')
  to='2026.08.31' if test=='full' else '2026.01.06'
  config=f'''[Common]
Server=MetaQuotes-Demo
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
[Tester]
Expert=S31Research\\RamusenEA.ex5
ExpertParameters=s31_{test}.set
Symbol=XAUUSD
Period=M5
Model=4
ExecutionMode=0
Optimization=0
FromDate=2026.01.01
ToDate={to}
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Visual=0
Report=s31_{test}_report
ReplaceReport=1
ShutdownTerminal=1
'''
  (STAGE/f'{test}.ini').write_text(config)
  shutil.copy2(STAGE/f'{test}.ini',ROOT/f'research/s31/{test}.ini')
  shutil.copy2(STAGE/'MQL5/Profiles/Tester'/f's31_{test}.set',ROOT/f'research/s31/s31_{test}.set')
 print('Isolated staging ready:',STAGE)

def compile_code():
 source='Z:\\private\\tmp\\ramusen-s31-mt5\\MQL5\\Experts\\S31Research\\RamusenEA.mq5'
 inc='Z:\\private\\tmp\\ramusen-s31-mt5\\MQL5'
 r=subprocess.run([WINE,str(STAGE/'metaeditor64.exe'),'/portable','/compile:'+source,'/include:'+inc,'/log'],env=env(),cwd=STAGE,timeout=120)
 log=STAGE/'MQL5/Experts/S31Research/RamusenEA.log'
 if log.exists():
  text=log.read_bytes().decode('utf-16',errors='replace');print(text)
  (ROOT/'research/s31/compile.log').write_text(text)
  if '0 errors' not in text:raise SystemExit(1)
 else:raise SystemExit('Compiler did not produce a log')
 binary=STAGE/'MQL5/Experts/S31Research/RamusenEA.ex5'
 shutil.copy2(binary,ROOT/'research/s31/RamusenEA_S31.ex5')
 data={'compiled_ex5_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in list((ROOT/'Include/RamusenEA').glob('*.mqh'))+[ROOT/'Experts/RamusenEA/RamusenEA.mq5']}}
 (ROOT/'research/s31/build_manifest.json').write_text(json.dumps(data,indent=2))

def run(test):
 if test not in ['guard','functional','full']:raise ValueError(test)
 if test=='full':
  evidence=ROOT/'research/s31/results/functional/integrity.json'
  if not evidence.exists() or json.loads(evidence.read_text())['integrity']!='PASS':raise SystemExit('Functional gate not passed')
 print('Starting isolated historical tester:',test,flush=True)
 return subprocess.call([WINE,str(STAGE/'terminal64.exe'),'/portable','/config:Z:\\private\\tmp\\ramusen-s31-mt5\\'+test+'.ini'],cwd=STAGE,env=env())
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['stage','compile','guard','functional','full']);a=p.parse_args()
 if a.action=='stage':stage()
 elif a.action=='compile':compile_code()
 else:raise SystemExit(run(a.action))
