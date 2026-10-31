# SPDX-License-Identifier: MIT
"""Quit grace: after the stop file, launch.py and the guardian let the subject quit by itself before any signal."""
import json
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'bin'))
import admission  # noqa: E402
import guardian  # noqa: E402
import launch  # noqa: E402


class Clock:
    def __init__(self, t=100.0): self.t = t
    def __call__(self): return self.t
    def sleep(self, s): self.t += s


SUBJECT = dict(state='running', pid=4242, startSeconds=7, startMicroseconds=0)


class GuardianGraceTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(); self.pid_file = Path(self.dir.name) / 'subject.pid'
        self.pid_file.write_text(json.dumps(SUBJECT))
        self.clock = Clock(); self.sent = []; self.exit_at = None

    def tearDown(self):
        self.dir.cleanup()

    def lookup(self, pid):
        if self.exit_at is not None and self.clock.t >= self.exit_at:
            return None
        return dict(pid=pid, startSeconds=7, startMicroseconds=0)

    def send(self, pid, sig):
        self.sent.append((round(self.clock.t - 100.0, 1), sig))
        if sig == signal.SIGTERM:
            self.exit_at = self.clock.t + 0.5  # exits shortly after TERM

    def terminate(self, quit_grace, report, urgent=lambda: False):
        return guardian.terminate(self.pid_file, lookup=self.lookup, send=self.send, clock=self.clock,
                                  sleep=self.clock.sleep, quit_grace=quit_grace, report=report, urgent=urgent)

    def test_urgent_condition_ends_the_grace_at_once(self):  # macrev-332-7
        report = {}
        self.assertTrue(self.terminate(5.0, report, urgent=lambda: self.clock.t >= 101.0))
        at, sig = self.sent[0]
        self.assertEqual(sig, signal.SIGTERM); self.assertLess(at, 1.3)

    def test_revocation_outranks_an_existing_stop_file(self):  # macrev-332-7
        lease = Path(self.dir.name) / 'lease.json'; stop = Path(self.dir.name) / 'STOP'
        lease.write_text(json.dumps(dict(runID='r', epoch='e', notBefore=1000.0, expiresAt=1100.0, exclusive=False,
                                         ownerPreempted=True, guardianHeartbeatAt=1000.0)))
        stop.write_text('{}'); calls = []
        def kill(pid_file, **grace): calls.append(grace); return True
        outcome, _ = guardian.run(lease, stop, pid_file=self.pid_file, clock=Clock(1000.0), kill=kill, quit_grace=5.0, report={})
        self.assertEqual(outcome, 'revoked'); self.assertEqual(calls, [{}])

    def test_subject_that_quits_within_the_grace_is_never_signalled(self):
        self.exit_at = 102.0; report = {}
        self.assertTrue(self.terminate(5.0, report))
        self.assertEqual(self.sent, [])
        self.assertEqual(report, dict(quitGraceUsed=5.0, exitedDuringGrace=True))

    def test_subject_that_ignores_the_grace_gets_term_after_it(self):
        report = {}
        self.assertTrue(self.terminate(5.0, report))
        self.assertEqual(len(self.sent), 1)
        at, sig = self.sent[0]
        self.assertEqual(sig, signal.SIGTERM); self.assertGreaterEqual(at, 5.0); self.assertLess(at, 5.3)
        self.assertEqual(report, dict(quitGraceUsed=5.0, exitedDuringGrace=False))

    def test_only_a_stop_file_ending_gets_the_grace(self):
        lease = Path(self.dir.name) / 'lease.json'; stop = Path(self.dir.name) / 'STOP'
        lease.write_text(json.dumps(dict(runID='r', epoch='e', notBefore=1000.0, expiresAt=1100.0, exclusive=True,
                                         ownerPreempted=False, guardianHeartbeatAt=1000.0)))
        calls = []
        def kill(pid_file, **grace): calls.append(grace); return True
        stop.write_text('{}')
        guardian.run(lease, stop, pid_file=self.pid_file, clock=Clock(1000.0), kill=kill, quit_grace=5.0, report={})
        stop.unlink()
        guardian.run(lease, stop, pid_file=self.pid_file, clock=Clock(1086.0), kill=kill, quit_grace=5.0, report={})  # deadline
        guardian.run(lease, stop, pid_file=self.pid_file, clock=Clock(1000.0), kill=kill, quit_grace=5.0, running=lambda: False)
        self.assertEqual([c.get('quit_grace') for c in calls], [5.0, None, None])

    def guardian_urgent(self, start, expires=1100.0):
        lease = Path(self.dir.name) / 'lease.json'; stop = Path(self.dir.name) / 'STOP'
        lease.write_text(json.dumps(dict(runID='r', epoch='e', notBefore=1000.0, expiresAt=expires, exclusive=True,
                                         ownerPreempted=False, guardianHeartbeatAt=start)))
        stop.write_text('{}'); seen = {}; clock = Clock(start)
        def kill(pid_file, **kw): seen.update(kw); return True
        guardian.run(lease, stop, pid_file=self.pid_file, clock=clock, kill=kill, quit_grace=10.0, report={})
        return seen['urgent'], clock, lease

    def test_grace_ends_while_the_minimum_reserve_remains(self):  # macrev-332-7
        urgent, clock, _ = self.guardian_urgent(start=1069.0)  # 31 s left, 10 s grace allowed by config
        clock.t = 1074.9; self.assertFalse(urgent())  # 25.1 s left
        clock.t = 1075.0; self.assertTrue(urgent())   # exactly MIN_RESERVE (25 s) left: grace over

    def test_guardian_keeps_beating_during_the_grace(self):  # macrev-332-9
        urgent, clock, lease = self.guardian_urgent(start=1000.0)
        c = dict(lease=json.loads(lease.read_text()), leasePath=str(lease), stopPath=str(Path(self.dir.name) / 'STOP'))
        for _ in range(60):  # 6 s of grace with wall time advancing for both supervisors
            clock.t += 0.1
            self.assertFalse(urgent())
            self.assertIsNone(launch.urgent_reason(c, clock.t), f'launch saw a stale guardian at +{clock.t - 1000.0:.1f}s')
        self.assertGreaterEqual(json.loads(lease.read_text())['guardianHeartbeatAt'], 1005.4)

    def test_grace_defaults_to_5_and_is_capped_at_10(self):
        self.assertEqual((guardian.quit_grace(None), guardian.quit_grace(0), guardian.quit_grace(7), guardian.quit_grace(30)),
                         (5.0, 0.0, 7.0, 10.0))
        for bad in (-1, float('nan'), float('inf'), '5', True):
            with self.assertRaises(ValueError):
                guardian.quit_grace(bad)

    def test_cli_reports_grace_fields(self):
        lease = Path(self.dir.name) / 'lease.json'; stop = Path(self.dir.name) / 'STOP'
        now = time.time()
        lease.write_text(json.dumps(dict(runID='r', epoch='e', notBefore=now - 1, expiresAt=now + 600, exclusive=True,
                                         ownerPreempted=False, guardianHeartbeatAt=now)))
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
        try:
            self.pid_file.write_text(json.dumps(dict(state='running', **guardian.identity(child.pid))))
            stop.write_text('{}')
            out = subprocess.run([sys.executable, '-B', str(Path(guardian.__file__)), '--lease', str(lease), '--stop', str(stop),
                                  '--subject-pid-file', str(self.pid_file), '--quit-grace', '30'],
                                 capture_output=True, text=True, timeout=40)
        finally:
            child.kill(); child.wait()
        self.assertEqual(json.loads(out.stdout), dict(guardian='stopped', subjectClosed=True, quitGraceUsed=10.0, exitedDuringGrace=False))


class LaunchGraceTests(unittest.TestCase):
    def config(self, **extra):
        d = Path(tempfile.mkdtemp()); now = time.time()
        lease = dict(runID='r', epoch='e', notBefore=now - 10, expiresAt=now + 600, exclusive=True,
                     ownerPreempted=False, guardian=True, guardianHeartbeatAt=now)
        (d / 'lease.json').write_text(json.dumps(lease)); (d / 'STOP').write_text('{}')
        return dict(lease=lease, leasePath=str(d / 'lease.json'), stopPath=str(d / 'STOP'), **extra)

    def child(self, exits_after=None):
        clock = Clock(); child = Mock()
        child.poll.side_effect = lambda: 0 if exits_after is not None and clock.t >= 100.0 + exits_after else None
        return clock, child

    def test_child_that_quits_within_the_grace_is_never_terminated(self):
        clock, child = self.child(exits_after=2.0); report = {}
        reason = launch.supervise(child, self.config(), sleep=clock.sleep, monotonic=clock, report=report)
        self.assertEqual(reason, 'stop-file'); child.terminate.assert_not_called(); child.kill.assert_not_called()
        self.assertEqual(report, dict(quitGraceUsed=5.0, exitedDuringGrace=True, graceCutBy=None))

    def test_child_that_ignores_the_grace_is_terminated_after_it(self):
        clock, child = self.child(); report = {}
        child.terminate.side_effect = lambda: report.setdefault('termAt', clock.t - 100.0)
        launch.supervise(child, self.config(quitGraceSeconds=30), sleep=clock.sleep, monotonic=clock, report=report)
        child.terminate.assert_called_once()
        self.assertGreaterEqual(report['termAt'], 10.0); self.assertLess(report['termAt'], 10.3)  # capped at 10
        self.assertEqual((report['quitGraceUsed'], report['exitedDuringGrace']), (10.0, False))

    def test_revoked_lease_with_a_stop_file_present_gets_no_grace(self):  # macrev-332-7
        clock, child = self.child(); c = self.config()
        Path(c['leasePath']).write_text(json.dumps(dict(c['lease'], ownerPreempted=True)))
        child.terminate.side_effect = lambda: setattr(clock, 'hit', clock.t)
        self.assertEqual(launch.supervise(child, c, sleep=clock.sleep, monotonic=clock), 'lease-revoked')
        self.assertEqual(clock.hit, 100.0)

    def test_revocation_during_the_grace_ends_it(self):  # macrev-332-7
        clock, child = self.child(); c = self.config(); report = {}
        def tick(s):
            clock.sleep(s)
            if clock.t >= 102.0: Path(c['leasePath']).write_text(json.dumps(dict(c['lease'], ownerPreempted=True)))
        child.terminate.side_effect = lambda: setattr(clock, 'hit', clock.t)
        self.assertEqual(launch.supervise(child, c, sleep=tick, monotonic=clock, report=report), 'lease-revoked')
        self.assertLess(clock.hit - 100.0, 2.5); self.assertEqual(report['graceCutBy'], 'lease-revoked')

    def test_other_stop_reasons_get_no_grace(self):
        clock, child = self.child(); c = self.config(); Path(c['stopPath']).unlink()
        Path(c['leasePath']).write_text(json.dumps(dict(c['lease'], ownerPreempted=True)))
        child.terminate.side_effect = lambda: setattr(clock, 'hit', clock.t)
        self.assertEqual(launch.supervise(child, c, sleep=clock.sleep, monotonic=clock), 'lease-revoked')
        self.assertEqual(clock.hit, 100.0)


class ReserveCutTests(unittest.TestCase):
    """C2.2 section 4: both supervisors end the quit grace once only MIN_RESERVE (25 s) remains before expiresAt."""
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(); root = Path(self.dir.name)
        self.lease, self.stop, self.pid_file = root / 'lease.json', root / 'STOP', root / 'subject.pid'
        self.pid_file.write_text(json.dumps(SUBJECT))

    def tearDown(self):
        self.dir.cleanup()

    def write_lease(self, heartbeat, expires=1100.0):
        self.lease.write_text(json.dumps(dict(runID='r', epoch='e', notBefore=1000.0, expiresAt=expires, exclusive=True,
                                              ownerPreempted=False, guardianHeartbeatAt=heartbeat)))

    def launch_config(self, **extra):
        return dict(lease=json.loads(self.lease.read_text()), leasePath=str(self.lease), stopPath=str(self.stop), **extra)

    def child(self, clock):
        child = Mock(); child.ended = None
        child.poll.side_effect = lambda: None if child.ended is None else 0
        child.terminate.side_effect = lambda: setattr(child, 'ended', clock.t)
        return child

    def test_reserve_crossing_during_the_grace_cuts_both_supervisors_at_once(self):
        self.write_lease(1069.0); self.stop.write_text('{}'); clock = Clock(1069.0)  # 31 s left, grace 10 configured
        seen = {}
        def kill(pid_file, **kw): seen.update(kw); return True
        guardian.run(self.lease, self.stop, pid_file=self.pid_file, clock=clock, kill=kill, quit_grace=10.0, report={})
        guardian_urgent = seen['urgent']; guardian_cut = []; stale = []
        c = self.launch_config(quitGraceSeconds=10)
        def tick(s):  # one shared wall clock; the guardian's grace loop runs alongside launch.py's
            clock.sleep(s)
            if not guardian_cut and guardian_urgent(): guardian_cut.append(clock.t)
            reason = launch.urgent_reason(c, clock.t)
            if reason == 'guardian-heartbeat-stale': stale.append(clock.t)
        child = self.child(clock); report = {}
        reason = launch.supervise(child, c, clock=clock, sleep=tick, monotonic=clock, report=report)
        self.assertEqual(reason, 'deadline')
        self.assertAlmostEqual(child.ended, 1075.0, delta=0.11)  # TERM once 25 s remain, not at the grace end (1079)
        self.assertAlmostEqual(guardian_cut[0], 1075.0, delta=0.11)
        self.assertEqual(stale, [])  # the guardian kept beating through the grace (macrev-332-9)
        self.assertEqual((report['quitGraceUsed'], report['exitedDuringGrace'], report['graceCutBy']), (10.0, False, 'deadline'))

    def test_launch_deadline_is_the_reserve_not_the_absolute_expiry(self):
        self.write_lease(1070.0); clock = Clock(1070.0); c = self.launch_config()
        def tick(s):
            clock.sleep(s); self.write_lease(clock.t)  # a live guardian
            c['lease'] = dict(c['lease'])
        child = self.child(clock)
        self.assertEqual(launch.supervise(child, c, clock=clock, sleep=tick, monotonic=clock), 'deadline')
        self.assertAlmostEqual(child.ended, 1075.0, delta=0.51)  # no stop file: TERM at the reserve cut
        self.assertIsNone(launch.urgent_reason(c, 1074.9))
        self.assertEqual(launch.urgent_reason(c, 1075.0), 'deadline')

    def test_launch_reports_only_fixed_stop_codes(self):  # C2.2 section 5
        self.write_lease(1000.0); c = self.launch_config()
        seen = {launch.urgent_reason(c, 1000.0), launch.urgent_reason(c, 1010.0),
                launch.stop_reason(dict(c, stopPath=str(self.lease)), 1000.0)}
        self.write_lease(1080.0); seen.add(launch.urgent_reason(c, 1080.0))
        self.lease.write_text(json.dumps(dict(c['lease'], ownerPreempted=True))); seen.add(launch.urgent_reason(c, 1000.0))
        self.lease.write_text(json.dumps(dict(c['lease'], epoch='other'))); seen.add(launch.urgent_reason(c, 1000.0))
        self.lease.write_text('{'); seen.add(launch.urgent_reason(c, 1000.0))
        self.assertEqual(seen - {None}, set(launch.STOP_REASONS))
        self.assertEqual(guardian.reason_code('engine said: token expired for alice', launch.STOP_REASONS), 'unknown')
        self.assertEqual(guardian.reason_code('timeout', launch.STOP_REASONS), 'timeout')


class AdmissionGraceTests(unittest.TestCase):
    def config(self, remaining, **extra):
        lease = dict(runID='r', epoch='e', notBefore=1000, expiresAt=1020 + remaining, guardianHeartbeatAt=1019.5,
                     ownerPreempted=False, exclusive=True)
        return dict(profile='synthetic', lease=lease, release=lease | dict(m1Released=True, approval='https://example.test/ok'),
                    stop=False, argv=['synthetic-app'], binarySHA256='a' * 64, **dict(dict(requiredSeconds=10), **extra))

    def admits(self, remaining, **extra):
        try:
            return admission.validate(self.config(remaining, **extra), 1020)
        except ValueError as error:
            self.assertEqual(str(error), 'insufficient time for action phase plus quit grace plus cleanup reserve')
            return False

    def test_one_additive_budget_action_plus_grace_plus_reserve(self):  # macrev-332-11, codex-kit-9
        # requiredSeconds 10 (actions only) + default grace 5 + MIN_RESERVE 25 = 40, as one sum.
        self.assertEqual([self.admits(r) for r in (39.5, 40, 40.5)], [False, True, True])
        self.assertFalse(self.admits(30))  # the reviewed example: the old separate minima admitted it
        # Grace configured 30 is capped at 10: 10 + 10 + 25 = 45.
        self.assertEqual([self.admits(r, quitGraceSeconds=30) for r in (44.9, 45, 45.1)], [False, True, True])
        self.assertEqual([self.admits(r, quitGraceSeconds=0) for r in (34.9, 35)], [False, True])
        self.assertEqual(admission.budget(self.config(100, requiredSeconds=90, quitGraceSeconds=10)), 125)
        self.assertFalse(self.admits(100, requiredSeconds=90, quitGraceSeconds=10))  # codex-kit-9 probe

    def test_required_seconds_and_grace_must_be_valid(self):
        with self.assertRaisesRegex(ValueError, 'action phase only'):
            admission.validate(self.config(600, requiredSeconds=0), 1020)
        with self.assertRaisesRegex(ValueError, 'quitGraceSeconds'):
            admission.validate(self.config(600, quitGraceSeconds=-1), 1020)

if __name__ == '__main__':
    unittest.main()
