# SPDX-License-Identifier: MIT
"""Fail-closed U6 action handoff; no UI or pointer process is started."""
import importlib.util,json,tempfile,types,unittest,subprocess
from pathlib import Path
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('u6_actions',Path(__file__).parent/'U6/action_runner.py')
actions=importlib.util.module_from_spec(spec);spec.loader.exec_module(actions)
import admission,book # bin/ is on sys.path through the runner

APPROVAL='https://example.test/coordinator#issuecomment-1'

class U6ActionRunnerTests(unittest.TestCase):
    def test_pointer_signal_and_stderr_are_bounded_and_private(self):
        with tempfile.TemporaryDirectory() as directory:
            config=dict(batch=directory,expectedLease=dict(runID='run',epoch='epoch'))
            result=types.SimpleNamespace(returncode=-5,stdout='',stderr='Fatal error: Not enough bits /private/secret '+('x'*9000))
            with patch.object(actions,'still_admitted'),patch.object(actions.subprocess,'run',return_value=result):
                with self.assertRaisesRegex(ValueError,'not-delivered'):
                    actions.command(['unused'],config,diagnostic='status-pointer')
            data=(Path(directory)/'status-pointer.stderr').read_text();receipt=json.loads(data)
            self.assertLess(len(data),1024);self.assertNotIn('secret',data)
            self.assertEqual(receipt['exitStatus'],-5);self.assertEqual(receipt['signal'],5)
            self.assertIn('integer-out-of-range',receipt['stderrCodes']);self.assertTrue(receipt['stderrTruncated'])
    def test_pointer_timeout_diagnostic_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            config=dict(batch=directory,expectedLease=dict(runID='run',epoch='epoch'))
            with patch.object(actions,'still_admitted'),patch.object(actions.subprocess,'run',side_effect=subprocess.TimeoutExpired('unused',1,stderr=b'private')):
                with self.assertRaises(subprocess.TimeoutExpired):actions.command(['unused'],config,diagnostic='status-pointer')
            receipt=json.loads((Path(directory)/'status-pointer.stderr').read_text())
            self.assertIsNone(receipt['exitStatus']);self.assertEqual(receipt['stderrCodes'],['timeout'])
    def test_failed_park_planning_leaves_log_and_refusal_without_pointer(self):
        with tempfile.TemporaryDirectory() as directory:
            config=dict(batch=directory,expectedLease=dict(runID='run',epoch='epoch'))
            args=['python','-B','u6-pointer-plan.py','make','--kind','park','--purpose','start']
            result=types.SimpleNamespace(returncode=1,stdout='',stderr='ValueError: park-geometry-missing')
            with patch.object(actions,'still_admitted'),patch.object(actions.subprocess,'run',return_value=result):
                with self.assertRaises(ValueError):actions.command(args,config)
            root=Path(directory);rows=[json.loads(line) for line in (root/'action-log.jsonl').read_text().splitlines()]
            self.assertEqual([r['phase'] for r in rows],['started','refused'])
            self.assertEqual(rows[-1]['reason'],'park-geometry-missing')
            self.assertTrue((root/'action-refusal-park-start-plan.json').exists())
    def test_refused_admission_writes_failure_handoff_and_stop(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);config=dict(batch=str(root),stopPath=str(root/'stop.json'),
                subjectPidPath=str(root/'subject.json'),expectedLease=dict(runID='run',epoch='epoch'))
            path=root/'run.json';path.write_text(json.dumps(config))
            with patch.object(actions,'still_admitted',side_effect=ValueError('not-admitted')),patch.object(actions,'uptime',lambda:100.0):
                with self.assertRaises(SystemExit) as error:actions.run(path,root/'unused-pointer')
                self.assertEqual(error.exception.code,3)
            self.assertTrue((root/'stop.json').is_file())
            self.assertEqual(json.loads((root/'stop.json').read_text())['reason'],'unknown')
            finish=json.loads((root/'operator-finish.json').read_text())
            self.assertEqual((finish['schema'],finish['runID'],finish['outcome']),('u6-actions/1','run','not-run'))
            self.assertTrue(all(x=='not-run' for x in finish['steps'].values()))
            self.assertEqual(finish['reason'],'unknown')
            self.assertEqual(finish['mono'],100.0)

class ActionPhaseAdmissionTests(unittest.TestCase):
    """macrev-332-18: a run admitted at exactly 330 s (300 actions + 5 grace + 25 reserve) keeps its action phase."""
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);root=self.root=Path(self.temp.name)
        self.lease=dict(runID='run',epoch='epoch',notBefore=1000,expiresAt=1350,guardian=True,guardianHeartbeatAt=1020,
                        ownerPreempted=False,exclusive=True)
        (root/'release.json').write_text(json.dumps({k:self.lease[k] for k in admission.IDENTITY_FIELDS}|dict(m1Released=True,approval=APPROVAL)))
        (root/'subject.json').write_text(json.dumps(dict(pid=4242,runID='run',epoch='epoch',state='running')))
        (root/'synthetic-seed.json').write_text(json.dumps(dict(titleSHA256='t'*64)))
        row=lambda **r:json.dumps(dict(runID='run',epoch='epoch',pid=4242)|r)
        (root/'native-observations.jsonl').write_text('\n'.join([
            row(event='started',seq=1),row(event='menu-begin',seq=2,checks=dict(surface='status',sessionID='A')),
            row(kind='refresh',phase='completed',sessionID='A',seq=3),row(event='menu-end',seq=4,checks=dict(sessionID='A')),
            row(event='menu-begin',seq=5,checks=dict(surface='status',sessionID='B')),
            row(event='menu-private-title-visible',seq=6,checks=dict(sessionID='B',titleSHA256='t'*64)),
            row(event='accepted-clear',seq=7,checks=dict(scrubbedSessionIDs=['B'])),
            row(event='menu-scrubbed',seq=8,checks=dict(sessionID='B'))])+'\n')
        self.config=dict(profile='synthetic',binarySHA256='a'*64,argv=['app'],requiredSeconds=300,quitGraceSeconds=5,
                         batch=str(root),leasePath=str(root/'lease.json'),releasePath=str(root/'release.json'),
                         stopPath=str(root/'stop.json'),subjectPidPath=str(root/'subject.json'),
                         booking=dict(id='b',lane='M1',unit='U6',scenario='s',ledger='x'),
                         expectedLease={k:self.lease[k] for k in admission.IDENTITY_FIELDS})
        self.path=root/'run.json';self.path.write_text(json.dumps(self.config))
        self.now=1020.0;self.checks=[];self.revoke_at=None
    def live(self,config):
        """The real still_admitted on the run's files; each command takes 10 s and the guardian keeps beating."""
        self.checks.append(self.now)
        revoked=self.revoke_at is not None and len(self.checks)>=self.revoke_at
        (self.root/'lease.json').write_text(json.dumps(self.lease|dict(guardianHeartbeatAt=self.now,ownerPreempted=revoked)))
        try:return admission.still_admitted(config,clock=lambda:self.now)
        finally:self.now+=10
    def run_actions(self):
        delivered=types.SimpleNamespace(returncode=0,stdout='',stderr='')
        with patch.object(actions,'still_admitted',side_effect=self.live), \
             patch.object(admission,'load_and_admit',side_effect=AssertionError('full admission after launch')), \
             patch.object(book,'admit'),patch.object(actions.subprocess,'run',return_value=delivered) as spawn:
            actions.run(self.path,self.root/'pointer')
        return spawn
    def test_actions_continue_through_the_phase_and_never_reapply_launch_admission(self):
        spawn=self.run_actions()
        self.assertFalse(hasattr(actions,'load_and_admit')) # the runner cannot reach the launch budget at all
        finish=json.loads((self.root/'operator-finish.json').read_text())
        self.assertEqual(finish['outcome'],'pass',finish);self.assertTrue(all(v=='pass' for v in finish['steps'].values()))
        self.assertEqual(len(self.checks),spawn.call_count+1) # before the first step and before every command
        self.assertGreater(self.checks[-1]-self.checks[0],150) # far past the zero surplus the launch budget left
        self.assertFalse((self.root/'stop.json').exists())
    def test_closing_budget_cut_still_refuses_and_requests_stop(self):
        self.now=1300.0 # 50 s left: park checks reach the reserve cut; the guarded end park refuses too
        with self.assertRaises(SystemExit) as error:self.run_actions()
        self.assertEqual(error.exception.code,3);self.assertEqual(len(self.checks),5)
        finish=json.loads((self.root/'operator-finish.json').read_text())
        self.assertEqual((finish['outcome'],finish['steps']['dock']),('not-run','not-run'))
        self.assertIn(json.loads((self.root/'stop.json').read_text())['reason'],actions.BOUNDED_CODES)
    def test_revoked_lease_refuses_the_next_action(self):
        self.revoke_at=3
        with self.assertRaises(SystemExit):self.run_actions()
        self.assertEqual(len(self.checks),4)
        self.assertIn(json.loads((self.root/'stop.json').read_text())['reason'],actions.BOUNDED_CODES)
        self.assertEqual(json.loads((self.root/'operator-finish.json').read_text())['outcome'],'not-run')
    def test_real_runner_parks_expanded_start_before_sliver_wait_and_reveal(self):
        pointer_spec=importlib.util.spec_from_file_location('runner_park_pointer',Path(__file__).parent/'bin/u6-pointer-plan.py')
        pointer=importlib.util.module_from_spec(pointer_spec);pointer_spec.loader.exec_module(pointer)
        now=[100.1];seq=[21];order=[]
        def append(state):
            seq[0]+=1
            row=dict(event='dock-surface-frame',runID='run',epoch='epoch',pid=4242,seq=seq[0],mono=now[0],
                checks=dict(state=state,coordinateSpace='cg-screen',x=2556 if state=='sliver' else 2320,
                    y=1080,width=4 if state=='sliver' else 240,height=88,windowNumber=77,displayBounds=[0,0,2560,1440]))
            with (self.root/'native-observations.jsonl').open('a') as out:out.write(json.dumps(row)+'\n')
        append('expanded')
        with (self.root/'native-observations.jsonl').open('a') as out:
            out.write(json.dumps(dict(event='status-item-frame',runID='run',epoch='epoch',pid=4242,seq=23,mono=100.1,
                checks=dict(settled=False,visible=True,windowNumber=1<<32,frameGeneration=1,observedCGFrame=[1800,2,18,18])))+'\n')
        seq[0]=23
        def fake_run(args,**_):
            if len(args)>3 and Path(args[2]).name=='u6-pointer-plan.py' and args[args.index('--kind')+1] in ('park','dock'):
                mode=args[3];kind=args[args.index('--kind')+1]
                purpose=args[args.index('--purpose')+1] if '--purpose' in args else 'refresh'
                if mode=='make':
                    if kind=='dock':order.append('sliver-wait')
                    pointer.make(self.config,kind,purpose,clock=lambda:now[0],sleep=lambda t:now.__setitem__(0,now[0]+t))
                else:pointer.check(self.config,kind,purpose,clock=lambda:now[0],sleep=lambda t:now.__setitem__(0,now[0]+t))
            elif '--plan' in args and (Path(args[-1]).name.startswith('park-pointer') or Path(args[-1]).name=='dock-pointer-plan.json'):
                plan=json.loads(Path(args[-1]).read_text());park=plan.get('purpose')=='park';order.append('park-'+plan['parkPhase'] if park else 'reveal')
                now[0]+=.1
                rows=[dict(event='mouse-moved-posted',kind='move',runID='run',epoch='epoch',targetPID=4242,mono=now[0],purpose='park' if park else 'drive'),
                    dict(event='pointer-result',outcome='posted',runID='run',epoch='epoch',targetPID=4242,purpose='park' if park else 'drive')]
                Path(plan['output']).write_text(''.join(json.dumps(r)+'\n' for r in rows));now[0]+=.05;append('sliver' if park else 'expanded')
            return types.SimpleNamespace(returncode=0,stdout='',stderr='')
        with patch.object(actions,'still_admitted'),patch.object(actions,'uptime',lambda:now[0]), \
             patch.object(actions.subprocess,'run',side_effect=fake_run),patch.object(pointer,'still_admitted'), \
             patch.object(pointer,'identity',return_value=dict(pid=4242)),patch.object(pointer.cleanup,'matches',return_value=True), \
             patch.object(pointer,'launcher_lost',return_value=False):
            actions.run(self.path,self.root/'fake-pointer')
        self.assertEqual(order,['park-start','sliver-wait','reveal','park-end'])
        self.assertEqual(json.loads((self.root/'operator-finish.json').read_text())['outcome'],'pass')
        log=[json.loads(line) for line in (self.root/'action-log.jsonl').read_text().splitlines()]
        self.assertTrue(any(r['substep']=='park-start-plan' and r['phase']=='completed' for r in log))
        self.assertTrue(any(r['substep']=='sliver-wait' and r['phase']=='completed' for r in log))

if __name__=='__main__':unittest.main()
