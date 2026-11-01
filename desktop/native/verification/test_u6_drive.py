# SPDX-License-Identifier: MIT
import importlib.util,sys,unittest
from pathlib import Path
BASE=Path(__file__).parent/'bin';sys.path.insert(0,str(BASE))
spec=importlib.util.spec_from_file_location('u6drive',BASE/'drive-u6.py');drive=importlib.util.module_from_spec(spec);spec.loader.exec_module(drive)
class U6DriveAdmissionTests(unittest.TestCase):
    def config(self):return dict(profile='synthetic',GO=True,announcementID='synthetic-receipt',start=100,expiresAt=200,head='a'*40,binarySHA256='b'*64,scratch='/synthetic/run',home='/synthetic/run/home',tmp='/synthetic/run/tmp',environment={'HOME':'/synthetic/run/home','TMPDIR':'/synthetic/run/tmp/'})
    def test_bound_contract(self):self.assertTrue(drive.admit(self.config(),110))
    def test_no_announcement_or_go_rejected(self):
        for key in ['GO','announcementID']:
            c=self.config();c[key]=False
            with self.assertRaises(ValueError):drive.admit(c,110)
    def test_expiry_and_maximum_window(self):
        for now in [99,200,300]:
            with self.assertRaises(ValueError):drive.admit(self.config(),now)
        c=self.config();c['expiresAt']=1400
        with self.assertRaises(ValueError):drive.admit(c,110)
    def test_non_synthetic_or_mismatched_home_rejected(self):
        for key,value in [('profile','owner'),('home','/owner/home')]:
            c=self.config();c[key]=value
            with self.assertRaises(ValueError):drive.admit(c,110)
