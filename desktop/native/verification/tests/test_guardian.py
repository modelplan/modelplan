# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'bin'))
import guardian  # noqa: E402


class Clock:
    def __init__(self, t): self.t = t
    def __call__(self): return self.t
    def sleep(self, s): self.t += s


class GuardianTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.lease = self.dir / 'lease.json'
        self.stop = self.dir / 'STOP'
        self.base = dict(runID='r1', epoch='e1', notBefore=1000.0, expiresAt=1100.0,
                         exclusive=True, ownerPreempted=False, guardianHeartbeatAt=1000.0)
        self.lease.write_text(json.dumps(self.base))

    def test_keeps_heartbeat_fresh_and_identity_unchanged(self):
        clock = Clock(1000.0); seen = []
        def sleep(s):
            clock.sleep(s); record = json.loads(self.lease.read_text()); seen.append(record['guardianHeartbeatAt'])
            if clock.t >= 1010: self.stop.write_text('{}')
        self.assertEqual(guardian.run(self.lease, self.stop, clock=clock, sleep=sleep), 'stopped')
        record = json.loads(self.lease.read_text())
        self.assertEqual({k: record[k] for k in guardian.IDENTITY}, {k: self.base[k] for k in guardian.IDENTITY})
        self.assertTrue(all(b - a <= 1.0 for a, b in zip(seen, seen[1:])))

    def test_deadline_writes_stop_and_stops_heartbeat(self):
        clock = Clock(1080.0)
        self.assertEqual(guardian.run(self.lease, self.stop, clock=clock, sleep=clock.sleep), 'deadline')
        self.assertTrue(json.loads(self.stop.read_text())['stop'])
        self.assertLess(json.loads(self.lease.read_text())['guardianHeartbeatAt'], 1100.0 - 15)

    def test_signal_writes_stop(self):
        clock = Clock(1000.0)
        self.assertEqual(guardian.run(self.lease, self.stop, clock=clock, sleep=clock.sleep, running=lambda: False), 'signalled')
        self.assertEqual(json.loads(self.stop.read_text())['reason'], 'guardian-signalled')

    def test_refuses_identity_change(self):
        clock = Clock(1000.0)
        def sleep(s):
            clock.sleep(s); self.lease.write_text(json.dumps(dict(self.base, epoch='other')))
        with self.assertRaises(ValueError):
            guardian.run(self.lease, self.stop, clock=clock, sleep=sleep)

    def test_refuses_interval_beyond_admission_tolerance(self):
        with self.assertRaises(ValueError):
            guardian.run(self.lease, self.stop, interval=3, clock=Clock(1000.0), sleep=lambda s: None)


if __name__ == '__main__':
    unittest.main()
