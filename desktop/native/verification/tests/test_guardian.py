# SPDX-License-Identifier: MIT
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import unittest.mock
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'bin'))
import guardian  # noqa: E402
import launch  # noqa: E402


class Clock:
    def __init__(self, t): self.t = t
    def __call__(self): return self.t
    def sleep(self, s): self.t += s


def no_kill(pid_file): return True


class GuardianTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.lease = self.dir / 'lease.json'
        self.stop = self.dir / 'STOP'
        self.base = dict(runID='r1', epoch='e1', notBefore=1000.0, expiresAt=1100.0,
                         exclusive=True, ownerPreempted=False, guardianHeartbeatAt=1000.0)
        self.lease.write_text(json.dumps(self.base))

    def test_keeps_heartbeat_fresh_marks_guardian_and_identity_unchanged(self):
        clock = Clock(1000.0); seen = []
        def sleep(s):
            clock.sleep(s); seen.append(json.loads(self.lease.read_text())['guardianHeartbeatAt'])
            if clock.t >= 1010: self.stop.write_text('{}')
        self.assertEqual(guardian.run(self.lease, self.stop, clock=clock, sleep=sleep, kill=no_kill), ('stopped', True))
        record = json.loads(self.lease.read_text())
        self.assertIs(record['guardian'], True)
        self.assertEqual({k: record[k] for k in guardian.IDENTITY}, {k: self.base[k] for k in guardian.IDENTITY})
        self.assertTrue(all(b - a <= 1.0 for a, b in zip(seen, seen[1:])))

    def test_deadline_writes_stop_and_stops_heartbeat(self):
        clock = Clock(1086.0)  # past expiresAt minus the 15 s reserve: no further beats
        self.assertEqual(guardian.run(self.lease, self.stop, clock=clock, sleep=clock.sleep, kill=no_kill)[0], 'deadline')
        self.assertTrue(json.loads(self.stop.read_text())['stop'])
        self.assertNotIn('guardian', json.loads(self.lease.read_text()))

    def test_signal_writes_stop(self):
        clock = Clock(1000.0)
        outcome = guardian.run(self.lease, self.stop, clock=clock, sleep=clock.sleep, running=lambda: False, kill=no_kill)
        self.assertEqual(outcome[0], 'signalled')
        self.assertEqual(json.loads(self.stop.read_text())['reason'], 'guardian-signalled')

    def test_concurrent_revocation_is_never_overwritten(self):
        # A beat paused after its read must not restore an identity or clear a preemption (MACREV P1).
        for change in (dict(epoch='other'), dict(ownerPreempted=True)):
            self.lease.write_text(json.dumps(self.base))
            if self.stop.exists(): self.stop.unlink()
            clock = Clock(1000.0)
            def sleep(s, change=change):
                clock.sleep(s)
                guardian.update_lease(self.lease, lambda r: r | change)  # another writer, same lock
            outcome = guardian.run(self.lease, self.stop, clock=clock, sleep=sleep, kill=no_kill)
            record = json.loads(self.lease.read_text())
            self.assertEqual(outcome[0], 'revoked')
            for k, v in change.items(): self.assertEqual(record[k], v)
            self.assertTrue(self.stop.exists())

    def test_beat_waits_for_the_lease_lock(self):
        lease_lock = guardian.locked(self.lease)
        lease_lock.__enter__()
        done = threading.Event()
        threading.Thread(target=lambda: (guardian.beat(self.lease, {k: self.base[k] for k in guardian.IDENTITY}, 1001.0), done.set())).start()
        time.sleep(0.2); self.assertFalse(done.is_set())
        lease_lock.__exit__(None, None, None)
        self.assertTrue(done.wait(2))

    def test_error_path_still_stops_and_terminates_subject(self):
        pid_file = self.dir / 'subject.pid'
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
        guardian.register(pid_file, child.pid)
        self.lease.write_text('{not json')
        with self.assertRaises(ValueError):
            guardian.run(self.lease, self.stop, pid_file=pid_file, clock=Clock(1000.0))
        self.assertTrue(self.stop.exists())
        self.assertIsNotNone(child.wait(5))

    def test_refuses_interval_beyond_admission_tolerance(self):
        with self.assertRaises(ValueError):
            guardian.run(self.lease, self.stop, interval=3, clock=Clock(1000.0), sleep=lambda s: None, kill=no_kill)


class LaunchSupervisionTests(unittest.TestCase):
    def config(self, lease, stop):
        d = Path(tempfile.mkdtemp())
        (d / 'lease.json').write_text(json.dumps(lease))
        c = dict(lease=lease, leasePath=str(d / 'lease.json'), stopPath=str(d / 'STOP'))
        if stop: Path(c['stopPath']).write_text('{}')
        return c

    def lease(self, **k):
        now = time.time()
        return dict(runID='r', epoch='e', notBefore=now - 10, expiresAt=now + 600, exclusive=True,
                    ownerPreempted=False, guardian=True, guardianHeartbeatAt=now) | k

    def run_child(self, c):
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
        reason = launch.supervise(child, c, poll=0.05)
        return reason, child.poll()

    def test_stale_heartbeat_stops_the_child(self):
        # A killed guardian leaves the heartbeat stale; the launched subject must still be stopped (MACREV P1).
        reason, code = self.run_child(self.config(self.lease(guardianHeartbeatAt=time.time() - 10), False))
        self.assertEqual(reason, 'guardian-heartbeat-stale'); self.assertIsNotNone(code)

    def test_stop_file_and_revocation_stop_the_child(self):
        self.assertEqual(self.run_child(self.config(self.lease(), True))[0], 'stop-file')
        self.assertEqual(self.run_child(self.config(self.lease(ownerPreempted=True), False))[0], 'lease-revoked')

    def test_child_that_exits_itself_is_not_flagged(self):
        child = Mock(); child.poll.return_value = 0
        self.assertIsNone(launch.supervise(child, self.config(self.lease(), False)))


class OwnedSubjectTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp()); self.pid_file = self.dir / 'subject.pid'

    def test_reused_pid_is_never_signalled(self):
        # Exited subject, PID reused by an unrelated process: identity differs, so no signal (MACREV P1 #3).
        sent = []
        self.pid_file.write_text(json.dumps(dict(state='running', pid=4242, startSeconds=1, startMicroseconds=0)))
        other = lambda pid: dict(pid=pid, startSeconds=999, startMicroseconds=0)
        self.assertTrue(guardian.terminate(self.pid_file, lookup=other, send=lambda *a: sent.append(a)))
        self.assertEqual(sent, [])

    def test_invalid_or_ambiguous_registration_is_unconfirmed(self):
        for record in (dict(state='launching'), dict(state='running', pid=0), dict(state='running', pid=-1)):
            self.pid_file.write_text(json.dumps(record))
            self.assertFalse(guardian.terminate(self.pid_file, send=lambda *a: self.fail('signalled')))
        self.pid_file.write_text('{broken')
        self.assertFalse(guardian.terminate(self.pid_file))

    def test_real_subject_is_stopped_and_confirmed(self):
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
        guardian.register(self.pid_file, child.pid)
        self.assertTrue(guardian.terminate(self.pid_file, grace=5))
        self.assertIsNotNone(child.wait(5))

    def test_stop_write_failure_still_stops_subject(self):
        killed = []
        lease = self.dir / 'lease.json'
        lease.write_text(json.dumps(dict(runID='r', epoch='e', notBefore=1.0, expiresAt=100.0, exclusive=True, ownerPreempted=False)))
        bad_stop = self.dir / 'missing-dir' / 'STOP'  # cannot be written
        outcome = guardian.run(lease, bad_stop, clock=Clock(1.0), sleep=lambda s: None, running=lambda: False,
                               kill=lambda f: killed.append(f) or True)
        self.assertEqual(outcome[0], 'signalled'); self.assertEqual(len(killed), 1)

    def test_launch_kills_child_when_registration_fails(self):
        d = self.dir
        lease = dict(runID='r', epoch='e', notBefore=time.time() - 5, expiresAt=time.time() + 600)
        c = dict(syntheticHome=str(d / 'home'), syntheticTmp=str(d / 'tmp'), argv=[sys.executable, '-c', 'import time; time.sleep(60)'],
                 binarySHA256=__import__('hashlib').sha256(Path(sys.executable).resolve().read_bytes()).hexdigest(),
                 subjectPidPath=str(self.pid_file), lease=lease)
        cfg = d / 'run.json'; cfg.write_text(json.dumps(c))
        spawned = []
        real = subprocess.Popen
        def popen(*a, **k):
            p = real(*a, **k); spawned.append(p); return p
        with unittest.mock.patch.object(sys, 'argv', ['launch', '--config', str(cfg), '--execute']), \
             unittest.mock.patch.object(launch, 'load_and_admit', side_effect=lambda x: x), \
             unittest.mock.patch.object(launch.subprocess, 'Popen', side_effect=popen), \
             unittest.mock.patch.object(launch, 'register', side_effect=ValueError('identity unavailable')):
            with self.assertRaises(SystemExit) as done:
                launch.main()
        self.assertEqual(done.exception.code, 3)
        self.assertIsNotNone(spawned[0].poll())
        self.assertEqual(json.loads(self.pid_file.read_text())['state'], 'launching')  # guardian: unconfirmed


class RoundThreeTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())

    def test_exec_gate_never_runs_subject_if_launch_dies_before_registration(self):
        marker = self.dir / 'ran'
        child = subprocess.Popen([sys.executable, '-I', '-c', launch.GATE, '/usr/bin/touch', str(marker)], stdin=subprocess.PIPE)
        child.stdin.close()  # launch killed before releasing the gate
        self.assertEqual(child.wait(5), 97)
        self.assertFalse(marker.exists())

    def test_exec_gate_runs_subject_with_same_pid_after_release(self):
        marker = self.dir / 'ran'
        child = subprocess.Popen([sys.executable, '-I', '-c', launch.GATE, '/usr/bin/touch', str(marker)], stdin=subprocess.PIPE)
        child.stdin.write(b'g'); child.stdin.close()
        self.assertEqual(child.wait(5), 0)
        self.assertTrue(marker.exists())

    def test_guardian_stops_subject_when_launcher_is_lost(self):
        lease = self.dir / 'lease.json'; stop = self.dir / 'STOP'; pid_file = self.dir / 'subject.pid'
        now = time.time()
        lease.write_text(json.dumps(dict(runID='r', epoch='e', notBefore=now - 5, expiresAt=now + 600, exclusive=True, ownerPreempted=False)))
        dead = subprocess.Popen([sys.executable, '-c', 'pass']); launcher = guardian.identity(dead.pid); dead.wait()
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
        guardian.register(pid_file, child.pid, launcher or dict(pid=dead.pid, startSeconds=-1, startMicroseconds=0))
        outcome = guardian.run(lease, stop, pid_file=pid_file, sleep=lambda s: time.sleep(0.05))
        self.assertEqual(outcome, ('launcher-lost', True))
        self.assertIsNotNone(child.wait(5))

    def test_reserve_must_cover_termination(self):
        lease = self.dir / 'lease.json'
        lease.write_text(json.dumps(dict(runID='r', epoch='e', notBefore=1.0, expiresAt=1000.0, exclusive=True, ownerPreempted=False)))
        for reserve in (5.0, float('nan'), 2000.0):
            with self.assertRaises(ValueError):
                guardian.run(lease, self.dir / 'STOP', reserve=reserve, clock=Clock(10.0), sleep=lambda s: None, kill=no_kill)


class OneControllerTests(unittest.TestCase):
    def test_second_controller_refused_while_first_subject_alive(self):
        d = Path(tempfile.mkdtemp()); pid_file = d / 'subject.pid'
        first = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
        try:
            guardian.register(pid_file, first.pid, guardian.identity(os.getpid()))
            with self.assertRaisesRegex(ValueError, 'one controller per booking'):
                guardian.mark_launching(pid_file)
            self.assertEqual(json.loads(pid_file.read_text())['pid'], first.pid)  # registration not replaced
        finally:
            first.kill(); first.wait()
        guardian.mark_launching(pid_file)  # the first subject has exited: the next subject may register
        self.assertEqual(json.loads(pid_file.read_text())['state'], 'launching')

    def test_other_live_controller_mid_handoff_is_refused(self):
        d = Path(tempfile.mkdtemp()); pid_file = d / 'subject.pid'
        other = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
        try:
            pid_file.write_text(json.dumps(dict(state='launching', launcher=guardian.identity(other.pid))))
            with self.assertRaisesRegex(ValueError, 'another controller is launching'):
                guardian.mark_launching(pid_file)
        finally:
            other.kill(); other.wait()


if __name__ == '__main__':
    unittest.main()
