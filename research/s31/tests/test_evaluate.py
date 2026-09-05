import sys,unittest,csv,tempfile,shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from evaluate import path_stats, first_quote, stats, mechanism_decision, validate

class PathMath(unittest.TestCase):
 def test_sell_ask_extrema_and_stop_through(self):
  ticks=[(1000,100.,100.2),(2000,99.,99.2),(3000,101.4,101.6),(4000,98.,98.2)]
  x=path_stats(ticks,0,3,1.)
  self.assertAlmostEqual(x['gross_executable_bps'],180.)
  self.assertAlmostEqual(x['mfe_bps'],180.)
  self.assertAlmostEqual(x['mae_bps'],160.)
  self.assertAlmostEqual(x['stop_r'],-1.28)
  self.assertEqual(x['stop_time_msc'],3000)
  self.assertEqual(x['time_to_mfe_ms'],3000)
 def test_equal_hold_uses_actual_delayed_quote_time(self):
  ticks=[(1000,100.,100.2),(61050,101.,101.2),(601000,99.,99.2),(661060,98.,98.2)]
  entry=first_quote(ticks,61000);self.assertEqual(entry,1)
  self.assertEqual(first_quote(ticks,ticks[entry][0]+600000),3)
  self.assertEqual(first_quote(ticks,601000),2)
 def test_missing_late_quote_does_not_become_fill(self):
  self.assertIsNone(first_quote([(90000,100.,101.)],1000))
 def test_same_millisecond_order_controls_first_touch(self):
  ticks=[(1000,100.,100.2),(2000,101.2,101.4),(2000,102.,102.2)]
  self.assertAlmostEqual(path_stats(ticks,0,2,1.)['stop_r'],-1.12)
 def test_favorable_excursion_is_zero_when_never_profitable(self):
  x=path_stats([(1000,100.,100.2),(2000,100.1,100.3)],0,1,1.)
  self.assertEqual(x['mfe_bps'],0)
  self.assertEqual(x['time_to_mfe_ms'],-1)
 def test_trim_removes_ten_percent_each_tail(self):
  self.assertAlmostEqual(stats([-100]+[1]*8+[100])['trim10'],1)
class DecisionPolicy(unittest.TestCase):
 def test_normal_missingness_does_not_override_user_rejection_rule(self):
  arms={a:{'robust_failure':True,'supported':False} for a in ['DELAY_1','DELAY_3','DELAY_5']}
  self.assertEqual(mechanism_decision(arms,428,False),'DELAY_MECHANISM_REJECTED')
 def test_low_coverage_cannot_promote_a_positive_result(self):
  self.assertEqual(mechanism_decision({'DELAY_1':{'robust_failure':False,'supported':True}},428,False),'INCONCLUSIVE')
 def test_small_functional_smoke_run_has_no_mechanism_verdict(self):
  self.assertEqual(mechanism_decision({'DELAY_1':{'robust_failure':True,'supported':False}},1,True),'INCONCLUSIVE')
class ExportIntegrity(unittest.TestCase):
 def corrupted_export(self,field,value):
  source=Path(__file__).resolve().parents[1]/'results/functional/RamusenEA_s31_1767225600_34521.csv'
  with tempfile.TemporaryDirectory() as td:
   target=Path(td)/source.name
   for suffix in ['_ticks.csv','_manifest.txt']:
    shutil.copyfile(source.with_name(source.stem+suffix),target.with_name(target.stem+suffix))
   with source.open() as f:rows=list(csv.DictReader(f))
   rows[0][field]=value
   with target.open('w') as f:
    writer=csv.DictWriter(f,rows[0].keys());writer.writeheader();writer.writerows(rows)
   return validate(target)[1]
 def test_recorded_spread_must_match_executable_quotes(self):
  self.assertEqual(self.corrupted_export('entry_spread_bps','999')['integrity'],'FAIL')
 def test_recorded_holding_time_must_match_actual_clocks(self):
  self.assertEqual(self.corrupted_export('holding_ms','1')['integrity'],'FAIL')
if __name__=='__main__':unittest.main()
