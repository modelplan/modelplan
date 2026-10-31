# SPDX-License-Identifier: MIT
import importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('u6_evidence',Path(__file__).parent/'bin/evidence-u6.py');u6=importlib.util.module_from_spec(spec);spec.loader.exec_module(u6)
class U6EvidenceTests(unittest.TestCase):
    def receipt(self): return dict(profile='synthetic',runID='run',epoch='epoch',headSHA='a'*40,binarySHA256='b'*64,packageSHA256='c'*64,profileSHA256='d'*64,durationSeconds=30,actionEvidenceFiles=['dock.png','menu.json'],**{key:True for key in u6.REQUIRED})
    def rows(self):
        key='aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'
        return [dict(runID='run',epoch='epoch',event='status-menu-action-arrived',checks=dict(actionID='refresh',requestID=key)),
            dict(runID='run',epoch='epoch',kind='refresh',phase='requested',requestId=key,rowsSequenceBefore=5,at=1),
            dict(runID='run',epoch='epoch',kind='refresh',phase='completed',requestId=key,rowsSequenceAfter=6,at=2),
            dict(runID='run',epoch='epoch',event='menu-begin',checks=dict(privateContent=True,instanceID='menu-1')),
            dict(runID='run',epoch='epoch',event='accepted-clear',checks=dict(priorPrivateContent=True,oldItemTitlesScrubbed=True,oldItemPrivateAttributesScrubbed=True,scrubbedInstanceIDs=['menu-1']))]
    def test_all_delivery_and_cleanup_receipts_required(self):
        self.assertEqual(u6.qualify(self.receipt(),self.rows()),'pass')
        for key in u6.REQUIRED:
            value=self.receipt();value[key]=False;self.assertEqual(u6.qualify(value,self.rows()),'not-run',key)
    def test_native_refresh_and_scrub_are_independent(self):
        rows=self.rows()
        self.assertEqual(u6.native_outcomes(rows,'run','epoch'),('pass','pass',None))
        self.assertEqual(u6.qualify(self.receipt(),rows[:1]),'not-run')
        no_arrival=rows[1:]
        self.assertEqual(u6.qualify(self.receipt(),no_arrival),'not-run')
        stale=[dict(x) for x in rows]; stale[2]['rowsSequenceAfter']=5
        self.assertEqual(u6.qualify(self.receipt(),stale),'not-run')
        failed=[dict(x) for x in rows];failed[2]=dict(failed[2],phase='failed',reason='engine-not-ready')
        self.assertEqual(u6.native_outcomes(failed,'run','epoch'),('fail','pass','engine-not-ready'))
        self.assertEqual(u6.qualify(self.receipt(),failed),'fail')
        wrong=[dict(x) for x in rows];wrong[4]=dict(wrong[4],checks=dict(wrong[4]['checks'],scrubbedInstanceIDs=[]))
        self.assertEqual(u6.qualify(self.receipt(),wrong),'not-run')
    def test_missing_evidence_and_bad_duration_are_not_run(self):
        for value in [None,0,-1,1201,float('inf'),True]:
            receipt=self.receipt();receipt['durationSeconds']=value;self.assertEqual(u6.qualify(receipt),'not-run')
        receipt=self.receipt();receipt['actionEvidenceFiles']=[];self.assertEqual(u6.qualify(receipt),'not-run')
    def test_unsupported_timeout_and_stop_are_distinct(self):
        for field,value,expected in [('inputCapability','unsupported','unsupported'),('timedOut',True,'timeout'),('stopped',True,'not-run')]:
            receipt=self.receipt();receipt[field]=value;self.assertEqual(u6.qualify(receipt),expected)
    def test_subject_pins_must_be_present(self):
        for key in ('headSHA','binarySHA256','packageSHA256','profileSHA256'):
            receipt=self.receipt();del receipt[key];self.assertEqual(u6.qualify(receipt),'not-run',key)
    def test_real_profile_is_rejected(self):
        receipt=self.receipt();receipt['profile']='owner'
        with self.assertRaises(ValueError):u6.qualify(receipt)
