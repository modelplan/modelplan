# SPDX-License-Identifier: MIT
import importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('u6_evidence',Path(__file__).parent/'bin/evidence-u6.py');u6=importlib.util.module_from_spec(spec);spec.loader.exec_module(u6)
class U6EvidenceTests(unittest.TestCase):
    def receipt(self): return dict(profile='synthetic',headSHA='a'*40,binarySHA256='b'*64,packageSHA256='c'*64,profileSHA256='d'*64,durationSeconds=30,actionEvidenceFiles=['dock.png','menu.json'],**{key:True for key in u6.REQUIRED})
    def test_all_delivery_and_cleanup_receipts_required(self):
        self.assertEqual(u6.qualify(self.receipt()),'pass')
        for key in u6.REQUIRED:
            value=self.receipt();value[key]=False;self.assertEqual(u6.qualify(value),'not-run',key)
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
