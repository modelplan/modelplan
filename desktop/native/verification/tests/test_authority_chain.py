# SPDX-License-Identifier: MIT
"""The end-to-end authority invariant (macrev2-574-5, macrevb-574-6, macrevb-574-8): authority is
re-read after every blocking call (probe, dwell, menu drive, relaunch wait, dialog query,
restoration) and once more before a receipt is written; a STOP observed anywhere makes the ID
NOT-RUN with a supervisor-* reason and the run exit 2, while the recorded baseline is still
restored. The launcher re-admits across the old child's shutdown and immediately before releasing
the exec gate. A successful relaunch hands later steps exactly the subject fields they read.
Linux-safe: OS queries and desktop actions are faked; the runner, Session, supervisor, authority
reader and receipt writer are the production code."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock

TESTS = Path(__file__).resolve().parent
BIN = TESTS.parent / 'bin'
sys.path.insert(0, str(TESTS))
sys.path.insert(0, str(BIN))

import guardian  # noqa: E402
import launch  # noqa: E402
import process_scan  # noqa: E402
import test_verify_run as harness  # noqa: E402

vr = harness.verify_run
SNAPSHOT = ('runID', 'epoch', 'notBefore', 'expiresAt')


def live_lease(directory, now):
    lease = dict(runID='r', epoch='e', notBefore=now - 10, expiresAt=now + 600, guardianHeartbeatAt=now,
                 ownerPreempted=False, exclusive=True)
    lease_path, stop_path = directory / 'lease.json', directory / 'STOP'
    lease_path.write_text(json.dumps(lease))
    return lease, dict(runID='r', epoch='e', leasePath=str(lease_path), stopPath=str(stop_path),
                       leaseSnapshot={k: lease[k] for k in SNAPSHOT})


def context(profile='synthetic'):
    return dict(profile=profile, sha='a' * 40, layout='single', markers=[], displays=[],
                baseline=dict(appearance='light'))


class RunnerBlockingBoundaryTests(unittest.TestCase):
    """STOP injected during each blocking call of run_id: no later capture or setting change, the
    baseline is restored, the receipt is NOT-RUN supervisor-stop-file, and StopRun propagates."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def run_with_stop_in(self, boundary, profile='synthetic'):
        now = time.time()
        work = self.root / boundary; work.mkdir()
        _, authority = live_lease(work, now)
        stop = Path(authority['stopPath'])
        events = []

        class Inject(harness.FakeActions):
            def __init__(self):
                super().__init__(at=now)
                self.restoring = False

            def fire(self, name):
                if name == boundary:
                    stop.write_text('synthetic-stop')

            def capture(self, subject, directory, wait):
                events.append(('capture', subject['pid']))
                report = super().capture(subject, directory, wait)
                self.fire('capture')
                return report

            def sleep(self, value):
                events.append(('dwell',))
                self.fire('dwell')

            def status_menu(self, subject, item, action, directory):
                events.append(('menu',))
                self.fire('status-menu')
                return {}

            def relaunch(self, subject):
                events.append(('relaunch',))
                self.fire('relaunch')
                return dict(subject, pid=subject['pid'] + 1, registeredAt=now)

            def dialogs(self):
                events.append(('dialogs',))
                self.fire('dialogs')
                return []

            def set_appearance(self, value):
                events.append(('appearance', value))
                if self.restoring or value == 'light':
                    self.fire('restore')

        subject = dict(pid=111, bundle='/synthetic/app', home='/synthetic/home', registeredAt=now, **authority)
        steps = dict(steps=[dict(name='dark', action='set-appearance', value='dark'),
                            dict(name='shot', action='capture-window'),
                            dict(name='wait', action='dwell', seconds=1),
                            dict(name='menu', action='status-menu', item='Refresh', menuAction='refresh'),
                            dict(name='again', action='relaunch'),
                            dict(name='last', action='capture-window')])
        with self.assertRaises(vr.StopRun) as stopped:
            vr.run_id('X-01', steps, dict(flavour='release'), subject, context(profile), Inject(), work)
        self.assertEqual(str(stopped.exception), 'supervisor-stop-file')
        receipt = json.loads((work / 'X-01' / 'receipt.json').read_text())
        self.assertEqual((receipt['outcome'], receipt['reason']), ('NOT-RUN', 'supervisor-stop-file'))
        self.assertEqual(events[-1], ('appearance', 'light'))  # the baseline restore ran last
        self.assertTrue(any(s.get('step') == 'restore' and s.get('restored') for s in receipt['steps']))
        return events

    def test_stop_during_each_blocking_call_is_not_run_and_restores(self):
        order = ['capture', 'dialogs', 'dwell', 'status-menu', 'relaunch']
        for boundary in order:
            with self.subTest(boundary=boundary):
                events = self.run_with_stop_in(boundary)
                index = next(i for i, e in enumerate(events) if e[0] == boundary.replace('status-', ''))
                after = events[index + 1:-1]  # between the STOP and the restore
                self.assertEqual(after, [], f'{boundary}: work continued after STOP: {after}')

    def test_stop_during_the_final_restoration_is_not_run(self):
        events = self.run_with_stop_in('restore')
        self.assertIn(('capture', 112), events)  # the whole ID ran; only the terminal check stopped it

    def test_real_profile_restores_on_a_stop_too(self):
        self.run_with_stop_in('dialogs', profile='real')

    def test_unexpected_error_still_restores_the_baseline(self):
        now = time.time()
        _, authority = live_lease(self.root, now)
        appearances = []

        class Broken(harness.FakeActions):
            def set_appearance(self, value):
                appearances.append(value)

            def capture(self, *args):
                raise OSError('probe crashed')

        subject = dict(pid=111, registeredAt=now, **authority)
        steps = dict(steps=[dict(name='dark', action='set-appearance', value='dark'),
                            dict(name='shot', action='capture-window')])
        with self.assertRaises(OSError):
            vr.run_id('X-01', steps, dict(flavour='release'), subject, context('real'), Broken(at=now), self.root)
        self.assertEqual(appearances, ['dark', 'light'])


class FinalDialogThroughExecuteTests(unittest.TestCase):
    """The reviewers' control through execute(): STOP during V-01's last dialog query (the actual
    Actions.dialogs wrapper, synthetic osascript output) is exit 2 and NOT-RUN, never REVIEW/0."""

    def test_stop_during_the_last_dialog_query_exits_2(self):
        class FinalDialogStop(harness.FakeActions):
            queries = 0

            def dialogs(self):
                FinalDialogStop.queries += 1

                def os_query(command, **kwargs):
                    if FinalDialogStop.queries == 5:
                        Path(harness.FakeSession.lease['stopPath']).write_text('synthetic-stop')
                    return SimpleNamespace(returncode=0, stdout='[]')
                with mock.patch.object(vr.subprocess, 'run', side_effect=os_query):
                    return vr.Actions.dialogs(self)

        case = harness.VerifyRunTests('test_smoke_ring_outcomes_and_output_contract')
        case.setUp(); self.addCleanup(case.doCleanups)
        code, lines, _ = case.go(ids=('V-01',), actions=FinalDialogStop())
        self.assertEqual(code, 2)
        self.assertTrue(lines['V-01'].startswith('NOT-RUN V-01'), lines['V-01'])
        self.assertIn('supervisor-stop-file', lines['V-01'])
        receipt = json.loads((case.out / 'V-01' / 'receipt.json').read_text())
        self.assertEqual(receipt['outcome'], 'NOT-RUN')


class SuccessfulRelaunchContractTests(unittest.TestCase):
    """macrevb-574-8: the actual Session.relaunch -> Actions.relaunch -> run_id composition with a
    valid new-PID announcement continues under the same lease, for this ID and a later one."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.now = time.time()
        self.run = self.root / 'session'; self.run.mkdir()
        self.lease, self.authority = live_lease(self.run, self.now)
        (self.run / 'subject.json').write_text(json.dumps(dict(state='running', pid=222)))
        first = dict(runID='r', epoch='e', ownedPID=111, bundle='/synthetic/app', home='/synthetic/home')
        again = dict(first, ownedPID=222, relaunch=1)
        (self.run / 'launch.out').write_text(json.dumps(first) + '\n' + json.dumps(again) + '\n')
        self.session = vr.Session(dict(profile='synthetic'), dict(flavour='release', ids=['X-01', 'X-02']), 1)
        self.session.local = self.run
        self.session.paths = dict(subjectPidPath=str(self.run / 'subject.json'),
                                  relaunchPath=str(self.run / 'relaunch'))
        self.session.procs = {'run': SimpleNamespace(poll=lambda: None)}
        self.original = dict(pid=111, bundle='/synthetic/app', home='/synthetic/home', registeredAt=self.now,
                             **self.authority)
        self.captures = []
        session, captures = self.session, self.captures

        class RealRelaunch(harness.FakeActions):
            def capture(self, subject, *args):
                captures.append(subject['pid'])
                return super().capture(subject, *args)
        self.actions = RealRelaunch(at=self.now)
        # The production Actions.relaunch delegates to the Session's relauncher, as execute() wires it.
        self.actions.relauncher = session.relaunch
        self.actions.relaunch = vr.Actions.relaunch.__get__(self.actions)

    def test_valid_relaunch_continues_this_id_and_the_next(self):
        steps = dict(steps=[dict(name='restart', action='relaunch'), dict(name='capture', action='capture-window')])
        outcome, reason, current = vr.run_id('X-01', steps, dict(flavour='release'), self.original,
                                             context(), self.actions, self.root)
        self.assertEqual((outcome, reason, current['pid']), ('REVIEW', None, 222))
        self.assertEqual(self.captures, [222])
        # Exactly the consumer's fields: the original subject with only the launch identity swapped.
        self.assertEqual(set(current), set(self.original))
        self.assertEqual(current['leaseSnapshot'], self.original['leaseSnapshot'])
        for key in ('runID', 'epoch', 'leasePath', 'stopPath'):
            self.assertEqual(current[key], self.original[key])
        later = dict(steps=[dict(name='capture', action='capture-window')])
        outcome, reason, _ = vr.run_id('X-02', later, dict(flavour='release'), current, context(),
                                       self.actions, self.root)
        self.assertEqual((outcome, self.captures), ('REVIEW', [222, 222]))

    def test_a_replaced_lease_still_refuses_the_relaunched_subject(self):
        replaced = dict(self.lease, epoch='other')
        Path(self.authority['leasePath']).write_text(json.dumps(replaced))
        steps = dict(steps=[dict(name='restart', action='relaunch'), dict(name='capture', action='capture-window')])
        with self.assertRaises(vr.StopRun) as stopped:
            # the first step's pre-check already sees the replacement; relaunch() itself too
            self.session.relaunch(self.original)
        self.assertEqual(str(stopped.exception), 'supervisor-lease-identity-changed')
        with self.assertRaises(vr.StopRun):
            vr.run_id('X-01', steps, dict(flavour='release'), self.original, context(), self.actions, self.root)
        self.assertEqual(self.captures, [])


class LauncherReadmissionTests(unittest.TestCase):
    """macrev2-574-5: the launcher never spawns or releases exec after authority is withdrawn."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        now = time.time()
        lease = dict(runID='r', epoch='e', notBefore=now - 10, expiresAt=now + 600, guardianHeartbeatAt=now,
                     ownerPreempted=False, exclusive=True)
        (self.root / 'lease.json').write_text(json.dumps(lease))
        self.config = dict(stopPath=str(self.root / 'STOP'), leasePath=str(self.root / 'lease.json'),
                           lease={k: lease[k] for k in SNAPSHOT}, relaunchPath=str(self.root / 'relaunch'))
        (self.root / 'relaunch').write_text('1')

    def test_stop_during_the_old_childs_shutdown_wait_spawns_nothing(self):
        stop = Path(self.config['stopPath'])

        class OldChild:
            pid, returncode, alive = 111, None, True
            def poll(self):
                return None if self.alive else 0
            def terminate(self):
                pass
            def wait(self, timeout=None):  # the blocking shutdown wait: STOP lands here
                stop.write_text('synthetic-stop'); self.alive = False

        spawned = []
        outcome = launch.supervise(OldChild(), self.config, poll=0, sleep=lambda _: None,
                                   spawn=lambda: spawned.append(1), announce=lambda *a: spawned.append(a))
        self.assertEqual(outcome, 'stop-file')
        self.assertEqual(spawned, [])

    def test_a_child_that_ends_while_authority_is_withdrawn_is_a_stop(self):
        stop = Path(self.config['stopPath'])

        class Ends:
            pid, returncode = 5, None
            def poll(self):
                return 0 if stop.exists() else None
        outcome = launch.supervise(Ends(), dict(self.config, relaunchPath=None), poll=0,
                                   sleep=lambda _: stop.write_text('stop'))
        self.assertEqual(outcome, 'stop-file')

    def gated(self, admit):
        run_dir = self.root / 'gate'; run_dir.mkdir(exist_ok=True)
        pid_file = run_dir / 'subject.json'
        if pid_file.exists():
            pid_file.unlink()
        marker = self.root / 'executed'
        gate = [sys.executable, '-I', '-c', launch.GATE, sys.executable, '-c',
                f'open({str(marker)!r}, "w").write("ran")']
        launcher = guardian.mark_launching(pid_file, scope=process_scan.scope_for(prefix=run_dir), mode='direct')
        refused = []
        child = launch.spawn_gated(gate, {'PATH': '/usr/bin:/bin'}, pid_file, launcher,
                                   lambda: refused.append(True), admit=admit)
        child.wait(10)
        return marker, refused

    def test_authority_withdrawn_before_exec_release_never_runs_the_subject(self):
        marker, refused = self.gated(admit=lambda: 'stop-file')
        self.assertEqual(refused, [True])
        self.assertFalse(marker.exists())  # no side effect after revocation

    def test_live_authority_releases_the_gate(self):
        marker, refused = self.gated(admit=lambda: None)
        self.assertEqual(refused, [])
        self.assertTrue(marker.exists())

    def test_relaunch_spawn_reads_authority_before_release(self):
        # The real stop_reason as admit: a STOP written after registration refuses the exec.
        Path(self.config['stopPath']).write_text('synthetic-stop')
        marker, refused = self.gated(admit=lambda: launch.stop_reason(self.config, time.time()))
        self.assertEqual(refused, [True])
        self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main()
