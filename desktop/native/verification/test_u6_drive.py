# SPDX-License-Identifier: MIT
import hashlib,importlib.util,json,os,subprocess,sys,tempfile,threading,time,unittest
from pathlib import Path
from unittest.mock import patch
BASE=Path(__file__).parent/'bin';sys.path.insert(0,str(BASE))
spec=importlib.util.spec_from_file_location('u6drive',BASE/'drive-u6.py');drive=importlib.util.module_from_spec(spec);spec.loader.exec_module(drive)
import launch,scenario
DISK=type('Disk',(),{'free':30*1024**3})();LOW=type('Disk',(),{'free':1})()
REAL_KILL=os.kill
def config(root,now=None,name=''):
    now=time.time() if now is None else now;batch=root/(name+'batch');scratch=root/(name+'scratch')
    for d in (batch,scratch,root/'locks'):d.mkdir(exist_ok=True)
    binary=root/'subject';binary.write_bytes(b'synthetic')
    return dict(profile='synthetic',scenario='u6',head='a'*40,binarySHA256=hashlib.sha256(b'synthetic').hexdigest(),
                argv=[str(binary),drive.FLAG,str(scratch/'native-guard.json')],
                expectedLease=dict(runID='run',epoch='epoch',notBefore=now-10,expiresAt=now+600),
                syntheticHome=str(scratch/'home'),syntheticTmp=str(scratch/'tmp'),scratch=str(scratch),batch=str(batch),
                locks=str(root/'locks'),resourceRoot=str(root),stopPath=str(batch/'stop.json'),preparedReceiptPath=str(batch/'prepared.json'),
                leasePath=str(root/'lease'),releasePath=str(root/'release'),subjectPidPath=str(root/(name+'subject.pid')),requiredSeconds=30,booking={})
def prepare(c,disk=DISK,admission=None,binary=None):
    if binary is not None:Path(c['argv'][0]).write_bytes(binary)
    with patch.object(drive,'load_and_admit',side_effect=admission or (lambda c:{})),patch.object(drive.shutil,'disk_usage',return_value=disk),patch.object(subprocess,'Popen',no_spawn):
        drive.prepare(c,time.time())
def launch_execute(c,root):
    """launch.py --execute on the same run config, with live admission granted: only preparation can refuse."""
    path=root/'launch-run.json';path.write_text(json.dumps(c))
    with patch.object(sys,'argv',['launch','--config',str(path),'--execute']),patch.object(launch,'load_and_admit',lambda c:dict(c,lease=dict(runID='run',epoch='epoch'))), \
         patch.object(launch.subprocess,'Popen',no_spawn),patch.object(launch,'mark_launching',no_spawn):
        launch.main()
def locks_of(c):return {p.name:json.loads((p/'owner.json').read_text())['attempt'] for p in Path(c['locks']).iterdir()}
def no_spawn(*a,**k):raise AssertionError('no subject may be started')
def main_thread_never_signals(pid,sig):
    if threading.current_thread() is threading.main_thread():raise AssertionError('Drive must never signal a process')
    return REAL_KILL(pid,sig)
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
    def test_registry_entry_matches_this_driver(self):
        self.assertEqual(scenario.load()['u6'],dict(argvFlag=drive.FLAG,prepare='drive-u6.py prepare',drive='drive-u6.py drive',receipt=True))
    def test_registration_scenario_and_prepared_receipt_paths_required(self):
        c=config(self.root,100);c['scenario']='other'
        with self.assertRaisesRegex(ValueError,'scenario-must-be-u6'):drive.admit(c,110)
        for key in ('subjectPidPath','preparedReceiptPath','scenario'):
            c=config(self.root,100);del c[key]
            with self.assertRaises(ValueError):drive.admit(c,110)
class U6PrepareTests(unittest.TestCase):
    def setUp(self):self.dir=tempfile.TemporaryDirectory();self.root=Path(self.dir.name);self.c=config(self.root)
    def tearDown(self):self.dir.cleanup()
    def assert_refused_and_unlaunchable(self,reason):
        self.assertFalse(Path(self.c['preparedReceiptPath']).exists())
        self.assertFalse(drive.native_contract(self.c).exists())
        self.assertTrue(Path(self.c['stopPath']).exists()) # admission also refuses while the stop file exists
        result=json.loads((Path(self.c['batch'])/'result.json').read_text())
        self.assertEqual((result['outcome'],result['appStarted'],result['reason']),('not-run',False,reason))
        with self.assertRaisesRegex(ValueError,'preparation receipt missing'):launch_execute(self.c,self.root)
        self.assertFalse(Path(self.c['syntheticHome']).exists())
    def test_busy_slot_refusal_keeps_the_other_owner_and_launch_refuses(self):
        slot=Path(self.c['locks'])/'slot1';slot.mkdir();drive.write(slot/'owner.json',dict(runID='other',epoch='other',attempt='other'))
        with self.assertRaisesRegex(RuntimeError,'resource-busy-before-launch'):prepare(self.c)
        self.assert_refused_and_unlaunchable('resource-busy-before-launch')
        self.assertEqual(locks_of(self.c),{'slot1':'other'})
    def test_low_disk_refusal_releases_own_locks_and_launch_refuses(self):
        with self.assertRaisesRegex(RuntimeError,'resource-disk-floor'):prepare(self.c,disk=LOW)
        self.assert_refused_and_unlaunchable('resource-disk-floor')
        self.assertEqual(locks_of(self.c),{})
    def test_failed_admission_refusal_and_launch_refuses(self):
        def denied(c):raise ValueError('booking denied')
        with self.assertRaisesRegex(ValueError,'booking denied'):prepare(self.c,admission=denied)
        self.assert_refused_and_unlaunchable('ValueError')
        self.assertEqual(locks_of(self.c),{})
    def test_bad_hash_refusal_and_launch_refuses(self):
        with self.assertRaisesRegex(ValueError,'binary identity changed'):prepare(self.c,binary=b'changed')
        self.assert_refused_and_unlaunchable('ValueError')
    def test_launch_requires_the_receipt_however_the_u6_config_is_edited(self):
        prepare(self.c) # a valid receipt exists, but each edited config must still refuse before HOME or spawn
        cases=[('absent',lambda c:c.pop('preparedReceiptPath'),'preparation receipt required'),
               ('blanked',lambda c:c.update(preparedReceiptPath=''),'preparation receipt required'),
               ('scenario dropped, flag remains',lambda c:(c.pop('scenario'),c.pop('preparedReceiptPath')),'preparation receipt required'),
               ('flag under another scenario name',lambda c:c.update(scenario='other'),'unknown scenario'),
               ('scenario blanked',lambda c:c.update(scenario=''),'unknown scenario'),
               ('u6 without its flag',lambda c:c.update(argv=c['argv'][:1]),'scenario/argv mismatch')]
        for label,edit,error in cases:
            with self.subTest(label):
                c=json.loads(json.dumps(self.c));edit(c)
                with self.assertRaisesRegex(ValueError,error):launch_execute(c,self.root)
                self.assertFalse(Path(c['syntheticHome']).exists())
    def test_success_writes_receipt_launch_accepts_only_while_its_locks_are_held(self):
        prepare(self.c);receipt=json.loads(Path(self.c['preparedReceiptPath']).read_text())
        self.assertEqual(locks_of(self.c),{name:receipt['attempt'] for name in drive.LOCKS})
        native=json.loads(drive.native_contract(self.c).read_text())
        self.assertEqual((native['runID'],native['lease'],native['stop']),('run',self.c['leasePath'],self.c['stopPath']))
        self.assertFalse(Path(self.c['stopPath']).exists())
        live=dict(self.c,lease=dict(runID='run',epoch='epoch'));launch.check_prepared(live)
        for change in [dict(binarySHA256='c'*64),dict(lease=dict(runID='run',epoch='other'))]:
            with self.assertRaisesRegex(ValueError,'preparation receipt mismatch'):launch.check_prepared(dict(live,**change))
        slot=Path(self.c['locks'])/'slot1';drive.write(slot/'owner.json',dict(runID='run',epoch='epoch',attempt='someone-else'))
        with self.assertRaisesRegex(ValueError,'prepared resources not held'):launch.check_prepared(live)
class U6DriveRegisteredSubjectTests(unittest.TestCase):
    def setUp(self):
        self.dir=tempfile.TemporaryDirectory();self.root=Path(self.dir.name);self.c=config(self.root);prepare(self.c)
        for name in ('home','tmp'):Path(self.c['scratch'],name).mkdir()
        self.attempt=json.loads(Path(self.c['preparedReceiptPath']).read_text())['attempt'];self.child=None
    def tearDown(self):
        if self.child and self.child.poll() is None:self.child.kill()
        if self.child:self.child.wait()
        self.dir.cleanup()
    def subject(self,mismatch=False,started=True):
        self.child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])
        ident=drive.identity(self.child.pid);ident['startSeconds']+=mismatch
        drive.write(self.c['subjectPidPath'],dict(state='running',launcher=drive.identity(os.getpid()),**ident))
        if started:Path(self.c['batch'],'native-observations.jsonl').write_text(json.dumps(dict(runID='run',epoch='epoch',event='started'))+'\n')
    def launch_py_stops_on_stop_file(self):
        def watch():
            while not Path(self.c['stopPath']).exists():time.sleep(.05)
            self.child.terminate();self.child.wait()
        threading.Thread(target=watch,daemon=True).start()
    def run_drive(self,c=None,disk=DISK):
        c=c or self.c;path=Path(c['batch'])/'run.json';path.write_text(json.dumps(c))
        with patch.object(drive,'load_and_admit',return_value={}),patch.object(drive,'REGISTER_SECONDS',.4),patch.object(drive,'CLOSE_SECONDS',1), \
             patch.object(drive.shutil,'disk_usage',return_value=disk),patch.object(subprocess,'Popen',no_spawn), \
             patch.object(os,'kill',main_thread_never_signals),patch.object(os,'killpg',main_thread_never_signals):
            status=drive.main(['drive','--config',str(path)])
        return status,json.loads((Path(c['batch'])/'result.json').read_text())
    def test_refuses_when_no_subject_is_registered(self):
        status,result=self.run_drive()
        self.assertEqual((result['appStarted'],result['reason']),(False,'no-registered-subject'))
        self.assertFalse(Path(self.c['batch'],'launch.json').exists())
        self.assertTrue(result['cleanup']['ownedAppExited']) # nothing was launched
        self.assertEqual(status,0)
    def test_refuses_identity_mismatch_and_never_signals_that_process(self):
        self.subject(mismatch=True)
        status,result=self.run_drive()
        self.assertEqual((result['appStarted'],result['reason']),(False,'subject-identity-mismatch'))
        self.assertIsNone(self.child.poll())
    def test_refuses_subject_without_this_runs_started_receipt(self):
        self.subject(started=False);self.launch_py_stops_on_stop_file()
        status,result=self.run_drive()
        self.assertEqual((result['appStarted'],result['reason']),(False,'subject-run-receipt-missing'))
    def test_drives_registered_subject_and_leaves_closing_to_the_stop_file(self):
        self.subject();self.launch_py_stops_on_stop_file()
        Path(self.c['batch'],'operator-finish.json').write_text(json.dumps(dict(dockInputDelivered=True)))
        status,result=self.run_drive()
        self.assertEqual((result['outcome'],result['appStarted'],result['launchedBy']),('operator-finished',True,'launch.py'))
        self.assertEqual(json.loads(Path(self.c['batch'],'launch.json').read_text())['ownedPID'],self.child.pid)
        self.assertEqual(json.loads(Path(self.c['stopPath']).read_text())['reason'],'run-ended')
        self.assertEqual(result['cleanup'],dict(ownedAppExited=True,closedBy='launch.py+guardian',guardian='external-M1',resourcesReleased=True,leaseReleased=False,scratchRemoved=['home','tmp']))
        self.assertEqual(locks_of(self.c),{})
        self.assertEqual(status,0)
    def test_unconfirmed_closure_keeps_resources_held(self):
        self.subject();Path(self.c['batch'],'operator-finish.json').write_text('{}')
        status,result=self.run_drive()
        self.assertIsNone(self.child.poll()) # Drive requested stop but never signalled
        self.assertEqual((result['cleanup']['ownedAppExited'],result['cleanup']['resourcesReleased'],result['cleanup']['scratchRemoved']),(False,False,[]))
        self.assertEqual(locks_of(self.c),{name:self.attempt for name in drive.LOCKS})
        self.assertTrue(Path(self.c['syntheticHome']).exists())
        self.assertEqual(status,3)
    def test_refused_second_attempt_never_releases_the_first_attempts_locks(self):
        other=config(self.root,name='b-') # same booking: same run/epoch and lock directory, its own batch
        with self.assertRaisesRegex(RuntimeError,'resource-busy-before-launch'):prepare(other)
        self.assertEqual(locks_of(self.c),{name:self.attempt for name in drive.LOCKS})
        status,result=self.run_drive(other) # B's drive: nothing registered, nothing prepared
        self.assertTrue(result['cleanup']['resourcesReleased'])
        self.assertEqual(locks_of(self.c),{name:self.attempt for name in drive.LOCKS})
        self.subject();self.launch_py_stops_on_stop_file();Path(self.c['batch'],'operator-finish.json').write_text('{}')
        status,result=self.run_drive() # A's locks go only once A's subject is confirmed closed
        self.assertTrue(result['cleanup']['ownedAppExited']);self.assertEqual(locks_of(self.c),{})
    def test_disk_floor_breach_mid_run_requests_stop_without_signalling(self):
        self.subject();self.launch_py_stops_on_stop_file()
        status,result=self.run_drive(disk=LOW)
        self.assertEqual(json.loads(Path(self.c['stopPath']).read_text())['reason'],'resource-disk-floor')
        self.assertEqual((result['appStarted'],result['outcome'],result['reason']),(True,'not-run','resource-disk-floor'))
        self.assertTrue(result['cleanup']['ownedAppExited'])
    def test_source_has_no_process_start_or_signal(self):
        source=(BASE/'drive-u6.py').read_text()
        for word in ('subprocess','Popen','killpg','os.kill','signal.'):self.assertNotIn(word,source)
if __name__=='__main__':unittest.main()
