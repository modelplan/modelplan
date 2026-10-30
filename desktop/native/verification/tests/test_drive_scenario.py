# SPDX-License-Identifier: MIT
import importlib.util,sys,unittest
from pathlib import Path
B=Path(__file__).parents[1]/'bin'
sys.path.insert(0,str(B))
def load(name):
 s=importlib.util.spec_from_file_location(name,B/(name+'.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
D=load('drive-scenario');E=load('export-native')
class Drive(unittest.TestCase):
 def test_three_cycles_and_grant(self):
  self.assertEqual(len(D.plan()),9);self.assertEqual(sum(x[2] for x in D.plan()),540)
  c=dict(GO=True,announcementID='synthetic',start=1000,expiresAt=2200)
  self.assertTrue(D.valid(c,1020));self.assertFalse(D.valid(c,2200));self.assertFalse(D.valid(c|dict(GO=False),1020))
 def test_native_source_export_has_absent_initial_cpu_and_explicit_cycle_views(self):
  rows=[dict(event='app-sample',pid=1,cycle=1,phase='before-open',elapsedSeconds=0,timestampUnix=1000,cpuSeconds=1,rssBytes=100),dict(event='app-sample',pid=1,cycle=1,phase='open',elapsedSeconds=1,timestampUnix=1001,cpuSeconds=1.1,rssBytes=120)]
  exported=E.export(rows,'synthetic');self.assertIsNone(exported[0]['cpu_percent']);self.assertAlmostEqual(exported[2]['cpu_percent'],10)
  self.assertEqual(exported[1]['phase'],'repeated-open-close')
