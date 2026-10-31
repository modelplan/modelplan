# SPDX-License-Identifier: MIT
import hashlib,importlib.util,json,os,subprocess,sys,tempfile,threading,time,unittest
from pathlib import Path
from unittest.mock import patch
BASE=Path(__file__).parent/'bin';sys.path.insert(0,str(BASE))
spec=importlib.util.spec_from_file_location('u6drive',BASE/'drive-u6.py');drive=importlib.util.module_from_spec(spec);spec.loader.exec_module(drive)
DISK=type('Disk',(),{'free':30*1024**3})()
def config(root,now=None):
    now=time.time() if now is None else now
    for name in ('batch','scratch','locks'):(root/name).mkdir(exist_ok=True)
    binary=root/'subject';binary.write_bytes(b'synthetic');scratch=root/'scratch'
    return dict(profile='synthetic',head='a'*40,binarySHA256=hashlib.sha256(b'synthetic').hexdigest(),
                argv=[str(binary),drive.FLAG,str(scratch/'native-guard.json')],
                expectedLease=dict(runID='run',epoch='epoch',notBefore=now-10,expiresAt=now+600),
                syntheticHome=str(scratch/'home'),syntheticTmp=str(scratch/'tmp'),scratch=str(scratch),batch=str(root/'batch'),
                locks=str(root/'locks'),resourceRoot=str(root),stopPath=str(root/'batch'/'stop.json'),leasePath=str(root/'lease'),
                releasePath=str(root/'release'),subjectPidPath=str(root/'subject.pid'),requiredSeconds=30,booking={})
def hold_locks(c):
    for name in drive.LOCKS:lock=Path(c['locks'])/name;lock.mkdir();drive.write(lock/'owner.json',dict(runID='run',epoch='epoch'))
def no_spawn(*a,**k):raise AssertionError('Drive must never start a process')
def no_signal(*a,**k):raise AssertionError('Drive must never signal a process')
class U6DriveAdmissionTests(unittest.TestCase):
    def setUp(self):self.dir=tempfile.TemporaryDirectory();self.root=Path(self.dir.name)
    def tearDown(self):self.dir.cleanup()
    def test_bound_contract(self):self.assertTrue(drive.admit(config(self.root,100),110))
    def test_expiry_and_maximum_window(self):
        c=config(self.root,100)
        for now in [89,700,800]:
            with self.assertRaises(ValueError):drive.admit(c,now)
        c['expectedLease']['expiresAt']=1400
        with self.assertRaises(ValueError):drive.admit(c,110)
    def test_non_synthetic_or_mismatched_home_rejected(self):
        for key,value in [('profile','owner'),('syntheticHome','/owner/home')]:
            c=config(self.root,100);c[key]=value
            with self.assertRaises(ValueError):drive.admit(c,110)
    def test_u6_flag_is_carried_by_the_launch_argv(self):
        for argv in [lambda c:c['argv'][:1],lambda c:[c['argv'][0],'--other',c['argv'][2]],lambda c:[c['argv'][0],drive.FLAG,str(self.root/'elsewhere.json')]]:
            c=config(self.root,100);c['argv']=argv(c)
            with self.assertRaisesRegex(ValueError,'u6-argv-mismatch'):drive.admit(c,110)
    def test_subject_registration_path_required(self):
        c=config(self.root,100);del c['subjectPidPath']
        with self.assertRaises(ValueError):drive.admit(c,110)
class U6PrepareTests(unittest.TestCase):
    def setUp(self):self.dir=tempfile.TemporaryDirectory();self.root=Path(self.dir.name);self.c=config(self.root)
    def tearDown(self):self.dir.cleanup()
    def prepare(self,disk=DISK):
        with patch.object(drive,'load_and_admit',return_value={}),patch.object(drive.shutil,'disk_usage',return_value=disk),patch.object(subprocess,'Popen',no_spawn):
            drive.prepare(self.c,time.time())
    def assert_refused_before_launch(self,reason):
        self.assertFalse(drive.native_contract(self.c).exists())
        self.assertTrue(Path(self.c['stopPath']).exists()) # launch.py admission refuses while the stop file exists
        self.assertFalse((self.root/'scratch'/'home').exists())
        result=json.loads((self.root/'batch'/'result.json').read_text())
        self.assertEqual((result['outcome'],result['appStarted'],result['reason']),('not-run',False,reason))
    def test_busy_slot_fails_before_launch_and_keeps_the_other_owner(self):
        slot=self.root/'locks'/'slot1';slot.mkdir();drive.write(slot/'owner.json',dict(runID='other',epoch='other'))
        with self.assertRaisesRegex(RuntimeError,'resource-busy-before-launch'):self.prepare()
        self.assert_refused_before_launch('resource-busy-before-launch')
        self.assertEqual(sorted(p.name for p in (self.root/'locks').iterdir()),['slot1'])
    def test_disk_floor_fails_before_launch_and_releases_own_locks(self):
        with self.assertRaisesRegex(RuntimeError,'resource-disk-floor'):self.prepare(type('Disk',(),{'free':1})())
        self.assert_refused_before_launch('resource-disk-floor')
        self.assertEqual(list((self.root/'locks').iterdir()),[])
    def test_success_holds_resources_and_writes_native_contract_for_launch(self):
        self.prepare()
        self.assertEqual(sorted(p.name for p in (self.root/'locks').iterdir()),sorted(drive.LOCKS))
        native=json.loads(drive.native_contract(self.c).read_text())
        self.assertEqual((native['runID'],native['lease'],native['stop']),('run',self.c['leasePath'],self.c['stopPath']))
        self.assertEqual(Path(self.c['argv'][2]).resolve(),drive.native_contract(self.c))
        self.assertFalse(Path(self.c['stopPath']).exists())
class U6DriveRegisteredSubjectTests(unittest.TestCase):
    def setUp(self):
        self.dir=tempfile.TemporaryDirectory();self.root=Path(self.dir.name);self.c=config(self.root);hold_locks(self.c)
        for name in ('home','tmp'):(self.root/'scratch'/name).mkdir()
        self.child=None
    def tearDown(self):
        if self.child and self.child.poll() is None:self.child.kill()
        if self.child:self.child.wait()
        self.dir.cleanup()
    def subject(self,mismatch=False,started=True):
        self.child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])
        ident=drive.identity(self.child.pid);ident['startSeconds']+=mismatch
        drive.write(self.c['subjectPidPath'],dict(state='running',launcher=drive.identity(os.getpid()),**ident))
        if started:(self.root/'batch'/'native-observations.jsonl').write_text(json.dumps(dict(runID='run',epoch='epoch',event='started'))+'\n')
    def launch_py_stops_on_stop_file(self):
        def watch():
            while not Path(self.c['stopPath']).exists():time.sleep(.05)
            self.child.terminate();self.child.wait()
        threading.Thread(target=watch,daemon=True).start()
    def run_drive(self,signals=True):
        config_path=self.root/'run.json';config_path.write_text(json.dumps(self.c))
        with patch.object(drive,'load_and_admit',return_value={}),patch.object(drive,'REGISTER_SECONDS',.4),patch.object(drive,'CLOSE_SECONDS',1),patch.object(subprocess,'Popen',no_spawn):
            if signals:status=drive.main(['drive','--config',str(config_path)])
            else:
                with patch.object(os,'kill',no_signal),patch.object(os,'killpg',no_signal):status=drive.main(['drive','--config',str(config_path)])
        return status,json.loads((self.root/'batch'/'result.json').read_text())
    def test_refuses_when_no_subject_is_registered(self):
        status,result=self.run_drive(signals=False)
        self.assertEqual((result['appStarted'],result['reason']),(False,'no-registered-subject'))
        self.assertFalse((self.root/'batch'/'launch.json').exists())
        self.assertTrue(result['cleanup']['ownedAppExited']) # nothing was launched
        self.assertEqual(status,0)
    def test_refuses_identity_mismatch_and_never_signals_that_process(self):
        self.subject(mismatch=True)
        status,result=self.run_drive(signals=False)
        self.assertEqual((result['appStarted'],result['reason']),(False,'subject-identity-mismatch'))
        self.assertIsNone(self.child.poll())
    def test_refuses_subject_without_this_runs_started_receipt(self):
        self.subject(started=False);self.launch_py_stops_on_stop_file()
        status,result=self.run_drive()
        self.assertEqual((result['appStarted'],result['reason']),(False,'subject-run-receipt-missing'))
    def test_drives_registered_subject_and_leaves_closing_to_the_stop_file(self):
        self.subject();self.launch_py_stops_on_stop_file()
        (self.root/'batch'/'operator-finish.json').write_text(json.dumps(dict(dockInputDelivered=True)))
        status,result=self.run_drive()
        self.assertEqual((result['outcome'],result['appStarted'],result['launchedBy']),('operator-finished',True,'launch.py'))
        self.assertEqual(json.loads((self.root/'batch'/'launch.json').read_text())['ownedPID'],self.child.pid)
        self.assertEqual(json.loads(Path(self.c['stopPath']).read_text())['reason'],'run-ended')
        self.assertEqual(result['cleanup'],dict(ownedAppExited=True,closedBy='launch.py+guardian',guardian='external-M1',resourcesReleased=True,leaseReleased=False,scratchRemoved=['home','tmp']))
        self.assertEqual(list((self.root/'locks').iterdir()),[])
        self.assertEqual(status,0)
    def test_unconfirmed_closure_keeps_resources_held(self):
        self.subject();(self.root/'batch'/'operator-finish.json').write_text('{}')
        status,result=self.run_drive(signals=False)
        self.assertIsNone(self.child.poll()) # Drive requested stop but never signalled
        self.assertEqual((result['cleanup']['ownedAppExited'],result['cleanup']['resourcesReleased'],result['cleanup']['scratchRemoved']),(False,False,[]))
        self.assertEqual(sorted(p.name for p in (self.root/'locks').iterdir()),sorted(drive.LOCKS))
        self.assertTrue((self.root/'scratch'/'home').exists())
        self.assertEqual(status,3)
    def test_source_has_no_process_start_or_signal(self):
        source=(BASE/'drive-u6.py').read_text()
        for word in ('subprocess','Popen','killpg','os.kill','signal.'):self.assertNotIn(word,source)
if __name__=='__main__':unittest.main()
