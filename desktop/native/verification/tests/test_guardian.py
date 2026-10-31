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
        pid_file.write_text(json.dumps(dict(pid=child.pid)))
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


if __name__ == '__main__':
    unittest.main()
