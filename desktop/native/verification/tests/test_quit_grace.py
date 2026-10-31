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

    def terminate(self, quit_grace, report):
        return guardian.terminate(self.pid_file, lookup=self.lookup, send=self.send, clock=self.clock,
                                  sleep=self.clock.sleep, quit_grace=quit_grace, report=report)

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
        self.assertEqual(report, dict(quitGraceUsed=5.0, exitedDuringGrace=True))

    def test_child_that_ignores_the_grace_is_terminated_after_it(self):
        clock, child = self.child(); report = {}
        child.terminate.side_effect = lambda: report.setdefault('termAt', clock.t - 100.0)
        launch.supervise(child, self.config(quitGraceSeconds=30), sleep=clock.sleep, monotonic=clock, report=report)
        child.terminate.assert_called_once()
        self.assertGreaterEqual(report['termAt'], 10.0); self.assertLess(report['termAt'], 10.3)  # capped at 10
        self.assertEqual((report['quitGraceUsed'], report['exitedDuringGrace']), (10.0, False))

    def test_other_stop_reasons_get_no_grace(self):
        clock, child = self.child(); c = self.config(); Path(c['stopPath']).unlink()
        Path(c['leasePath']).write_text(json.dumps(dict(c['lease'], ownerPreempted=True)))
        child.terminate.side_effect = lambda: setattr(clock, 'hit', clock.t)
        self.assertEqual(launch.supervise(child, c, sleep=clock.sleep, monotonic=clock), 'lease-revoked')
        self.assertEqual(clock.hit, 100.0)


class AdmissionGraceTests(unittest.TestCase):
    def config(self, remaining, **extra):
        lease = dict(runID='r', epoch='e', notBefore=1000, expiresAt=1020 + remaining, guardianHeartbeatAt=1019.5,
                     ownerPreempted=False, exclusive=True)
        return dict(profile='synthetic', lease=lease, release=lease | dict(m1Released=True, approval='https://example.test/ok'),
                    requiredSeconds=10, stop=False, argv=['synthetic-app'], binarySHA256='a' * 64, **extra)

    def test_remaining_time_must_cover_grace_plus_reserve(self):
        self.assertTrue(admission.validate(self.config(30), 1020))  # 5 s default grace + 25 s reserve
        with self.assertRaisesRegex(ValueError, 'quit grace plus cleanup reserve'):
            admission.validate(self.config(29), 1020)
        with self.assertRaisesRegex(ValueError, 'quit grace plus cleanup reserve'):
            admission.validate(self.config(34, quitGraceSeconds=10), 1020)
        self.assertTrue(admission.validate(self.config(25, quitGraceSeconds=0), 1020))
        with self.assertRaisesRegex(ValueError, 'quitGraceSeconds'):
            admission.validate(self.config(600, quitGraceSeconds=-1), 1020)


if __name__ == '__main__':
    unittest.main()
