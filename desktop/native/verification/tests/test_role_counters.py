# SPDX-License-Identifier: MIT
import sys,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).parents[1]/'bin'))
import role_counters as R
class Roles(unittest.TestCase):
 def fixtures(self):
  b=dict(scope='effective-user-WebKit-family',sessionID='synthetic',processes=[])
  w=dict(status='attributed',kind='WebContent',pid=2,startSeconds=100,startMicroseconds=1)
  g=dict(kind='GPU',helper='com.apple.WebKit.GPU',pid=3,startSeconds=100,startMicroseconds=2)
  return b,w,g
 def test_unique_diff_and_logged_wc(self):
  b,w,g=self.fixtures();r=R.qualify(b,b|dict(processes=[w,g]),w)
  self.assertEqual(r['GPU']['status'],'attributed');self.assertEqual(r['WebContent']['pid'],2)
 def test_existing_or_ambiguous_gpu_never_guessed(self):
  b,w,g=self.fixtures()
  self.assertEqual(R.qualify(b|dict(processes=[g]),b|dict(processes=[w,g]),w)['GPU']['status'],'unsupported')
  self.assertEqual(R.qualify(b,b|dict(processes=[w,g,g|dict(pid=4)]),w)['GPU']['status'],'unsupported')
  self.assertIn('WindowServer',R.qualify(b,b|dict(processes=[w]),w)['reason'])
 def test_retained_owned_helpers_not_foreign(self):
  b,w,g=self.fixtures();before=b|dict(processes=[w,g]);self.assertEqual(R.qualify(before,b|dict(processes=[w,g]),w,[w,g])['GPU']['status'],'attributed')
 def test_resident_units_and_reuse(self):
  _,w,_=self.fixtures()
  with patch.object(R.subprocess,'run',return_value=type('Result',(),dict(returncode=0,stdout='123\n'))()):
   self.assertEqual(R.rss(w,lambda _:w),123*1024)
   calls=iter([w,w|dict(startSeconds=999)])
   self.assertIsNone(R.rss(w,lambda _:next(calls)))
