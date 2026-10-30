# SPDX-License-Identifier: MIT
import importlib.util,tempfile,unittest
from pathlib import Path
s=importlib.util.spec_from_file_location('cleanup_test',Path(__file__).parents[1]/'bin/cleanup-run.py');C=importlib.util.module_from_spec(s);s.loader.exec_module(C)
class Cleanup(unittest.TestCase):
 def test_pid_reuse_is_never_killed(self):
  expected=dict(pid=1,startSeconds=100,startMicroseconds=1);calls=[]
  self.assertEqual(C.stop_owned(expected,lookup=lambda _:expected|dict(startSeconds=101),send=lambda *a:calls.append(a)),'unknown-identity-changed');self.assertEqual(calls,[])
 def test_only_explicit_scratch_not_evidence(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);(root/'home').mkdir();(root/'home/prefs').write_text('synthetic');(root/'evidence.csv').write_text('retain')
   C.remove_scratch(root,['home']);self.assertTrue((root/'evidence.csv').exists())
   for bad in ['../x','evidence.csv']:
    with self.assertRaises(ValueError):C.remove_scratch(root,[bad])
