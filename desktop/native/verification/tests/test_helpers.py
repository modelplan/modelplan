# SPDX-License-Identifier: MIT
import sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]/'bin'))
from doctor import doctor,CONDITIONS
from launch import validate
from evidence import manifest
from attribute_webkit import attribute

class Helpers(unittest.TestCase):
    def test_doctor_separates_conditions_with_timestamp_and_actual_call(self):
        d={k:True for k in CONDITIONS}|dict(WebKitPID=314,timestamp='2026-01-01T00:00:00Z',activationCall='not-invoked')
        for k in CONDITIONS:
            r=doctor(d|{k:False});self.assertEqual(r['outcome'],'not-run');self.assertEqual(r['checks'][k]['status'],'fail')
            self.assertEqual(sum(x['status']=='fail' for x in r['checks'].values()),1)
        with self.assertRaises(ValueError):doctor(d|{'activationCall':''})
    def test_launch_uses_budget_not_start_offset(self):
        lease=dict(runID='fixture',epoch='new',notBefore=1000,expiresAt=1900,guardianHeartbeatAt=1019.5,ownerPreempted=False,exclusive=True)
        c=dict(profile='synthetic',lease=lease,release=lease|dict(m1Released=True,m0DirectedAnnouncementConfirmed=True),requiredSeconds=632,stop=False,argv=['synthetic-app'],binarySHA256='a'*64)
        self.assertTrue(validate(c,1020))
        with self.assertRaises(ValueError):validate(c|{'binarySHA256':''},1020)
        with self.assertRaises(ValueError):validate(c|{'requiredSeconds':881},1020)
        with self.assertRaises(ValueError):validate(c|{'stop':True},1020)
        with self.assertRaises(ValueError):validate(c,1900)
    def test_evidence_missing_windows_is_not_budget_fail(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'sample.txt').write_text('synthetic')
            c=dict(headSHA='a'*40,profile='synthetic',attributionMethod='fixture',files=['sample.txt'],scenarios=[dict(id='U11a-A',outcome='fail',gate=True,frameProof=False,postClose=True)])
            r=manifest(c,root);self.assertEqual(r['scenarios'][0]['outcome'],'not-run');self.assertEqual(r['files'][0]['bytes'],9)
            with self.assertRaises(ValueError):manifest(c|{'files':['../outside']},root)
            (root/'link').symlink_to(root/'sample.txt')
            with self.assertRaises(ValueError):manifest(c|{'files':['link']},root)
    def test_attribution_never_guesses_ambiguous_or_shared_hosts(self):
        before=dict(scope='isolated-synthetic-WebKit',sessionID='synthetic',processes=[])
        wc=dict(pid=2,startSeconds=100,startMicroseconds=1,kind='WebContent')
        gpu=dict(pid=3,startSeconds=101,startMicroseconds=1,kind='GPU')
        after=before|dict(processes=[wc,gpu])
        self.assertEqual(attribute(before,after,wc)['GPU']['status'],'attributed')
        self.assertEqual(attribute(before,after|dict(processes=[wc,gpu,gpu|dict(pid=4)]),wc)['GPU']['status'],'unsupported')
        self.assertEqual(attribute(before|dict(processes=[gpu]),after,wc)['WebContent']['status'],'unsupported')
        self.assertEqual(attribute(before,after,wc|dict(startSeconds=200))['WebContent']['status'],'unsupported')

if __name__=='__main__':unittest.main()
