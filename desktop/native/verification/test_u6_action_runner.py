# SPDX-License-Identifier: MIT
"""Fail-closed U6 action handoff; no UI or pointer process is started."""
import importlib.util,json,tempfile,types,unittest
from pathlib import Path
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('u6_actions',Path(__file__).parent/'U6/action_runner.py')
actions=importlib.util.module_from_spec(spec);spec.loader.exec_module(actions)
import admission,book # bin/ is on sys.path through the runner

APPROVAL='https://example.test/coordinator#issuecomment-1'

class U6ActionRunnerTests(unittest.TestCase):
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
        """The real still_admitted on the run's files; each step takes 20 s and the guardian keeps beating."""
        self.checks.append(self.now)
        revoked=self.revoke_at is not None and len(self.checks)>=self.revoke_at
        (self.root/'lease.json').write_text(json.dumps(self.lease|dict(guardianHeartbeatAt=self.now,ownerPreempted=revoked)))
        try:return admission.still_admitted(config,clock=lambda:self.now)
        finally:self.now+=20
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
        self.assertGreater(self.checks[-1]-self.checks[0],250) # far past the zero surplus the launch budget left
        self.assertFalse((self.root/'stop.json').exists())
    def test_closing_budget_cut_still_refuses_and_requests_stop(self):
        self.now=1300.0 # 50 s left: two checks fit, the third leaves less than grace + 25 s
        with self.assertRaises(SystemExit) as error:self.run_actions()
        self.assertEqual(error.exception.code,3);self.assertEqual(len(self.checks),3)
        finish=json.loads((self.root/'operator-finish.json').read_text())
        self.assertEqual((finish['outcome'],finish['steps']['dock']),('not-run','not-run'))
        self.assertIn(json.loads((self.root/'stop.json').read_text())['reason'],actions.BOUNDED_CODES)
    def test_revoked_lease_refuses_the_next_action(self):
        self.revoke_at=3
        with self.assertRaises(SystemExit):self.run_actions()
        self.assertEqual(len(self.checks),3)
        self.assertIn(json.loads((self.root/'stop.json').read_text())['reason'],actions.BOUNDED_CODES)
        self.assertEqual(json.loads((self.root/'operator-finish.json').read_text())['outcome'],'not-run')

if __name__=='__main__':unittest.main()
