# SPDX-License-Identifier: MIT
"""Admission during the action phase (macrev-332-18): launch admission checks the full additive budget once;
every later action step only checks `still_admitted` (identity, revocation, stop, heartbeat, closing budget)."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))
import admission  # noqa: E402
import book  # noqa: E402

APPROVAL = 'https://example.test/coordinator#issuecomment-1'


class StillAdmittedTests(unittest.TestCase):
    """File-backed lease/release/stop with a synthetic clock; the booking check is recorded, not replayed."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.lease_path, self.release_path, self.stop = root / 'lease.json', root / 'release.json', root / 'stop.json'
        self.lease = dict(runID='r', epoch='e', notBefore=1000, expiresAt=1350, guardian=True,
                          guardianHeartbeatAt=1020, ownerPreempted=False, exclusive=True)
        self.write_lease()
        self.release_path.write_text(json.dumps({k: self.lease[k] for k in admission.IDENTITY_FIELDS}
                                                | dict(m1Released=True, approval=APPROVAL)))
        self.config = dict(profile='synthetic', binarySHA256='a' * 64, argv=['synthetic-app'], requiredSeconds=300,
                           quitGraceSeconds=5, leasePath=str(self.lease_path), releasePath=str(self.release_path),
                           stopPath=str(self.stop), booking=dict(id='b', lane='M1', unit='U6', scenario='s', ledger='x'),
                           expectedLease={k: self.lease[k] for k in admission.IDENTITY_FIELDS})
        self.booked = []
        patcher = patch.object(book, 'admit', side_effect=lambda c: self.booked.append(c['requiredSeconds']))
        patcher.start(); self.addCleanup(patcher.stop)

    def write_lease(self, **fields):
        self.lease_path.write_text(json.dumps(self.lease | fields))

    def at(self, now, **fields):
        """still_admitted at `now`, with the guardian's heartbeat at `now` unless `fields` override it."""
        self.write_lease(**(dict(guardianHeartbeatAt=now) | fields))
        return admission.still_admitted(self.config, clock=lambda: now)

    def test_admitted_at_the_launch_boundary_keeps_the_whole_action_phase(self):
        # Launch admission at exactly 330 s remaining (300 actions + 5 grace + 25 reserve) admits once ...
        current = admission.live_records(self.config)
        self.assertTrue(admission.validate(current, 1020))
        # ... and the review's probe: the full budget re-applied 6 s later refuses.
        self.write_lease(guardianHeartbeatAt=1026)
        with self.assertRaisesRegex(ValueError, 'insufficient time for action phase'):
            admission.validate(admission.live_records(self.config), 1026)
        # The action steps instead keep going through the original 300 s phase, in legitimate steps.
        for now in range(1026, 1321, 15):
            self.assertEqual(self.at(now)['lease']['runID'], 'r')
        self.assertEqual(set(self.booked), {30})  # the booking check covers the closing budget, not 300 s again

    def test_closing_budget_boundary(self):
        need = admission.closing_budget(self.config)
        self.assertEqual(need, 30)
        self.assertTrue(self.at(1350 - need))  # exactly quit grace + 25 s left still closes inside the lease
        for now in (1350 - need + 0.01, 1349, 1350):
            with self.subTest(now=now), self.assertRaisesRegex(ValueError, 'insufficient time to quit and close|outside window'):
                self.at(now)
        # The grace is capped at 10, so the closing budget is at most 35 s; zero grace leaves the 25 s reserve.
        self.assertEqual(admission.closing_budget(dict(self.config, quitGraceSeconds=30)), 35)
        self.assertEqual(admission.closing_budget(dict(self.config, quitGraceSeconds=0)), 25)

    def test_heartbeat_boundary(self):
        self.assertTrue(self.at(1100, guardianHeartbeatAt=1098))
        for beat in (1097.99, 1100.01):
            with self.subTest(beat=beat), self.assertRaisesRegex(ValueError, 'heartbeat stale'):
                self.at(1100, guardianHeartbeatAt=beat)
        with self.assertRaisesRegex(ValueError, 'guardian not running'):
            self.at(1100, guardian=False)

    def test_identity_revocation_and_stop_refuse_immediately(self):
        for fields, error in [(dict(epoch='other'), 'identity'), (dict(runID='other'), 'identity'),
                              (dict(expiresAt=1349), 'identity'), (dict(ownerPreempted=True), 'stopped/not exclusive'),
                              (dict(exclusive=False), 'stopped/not exclusive')]:
            with self.subTest(fields=fields), self.assertRaisesRegex(ValueError, error):
                self.at(1100, **fields)
        self.stop.write_text('{"stop": true}')
        with self.assertRaisesRegex(ValueError, 'stopped/not exclusive'):
            self.at(1100)
        self.stop.unlink()
        for expected in (None, {}, {k: v for k, v in self.config['expectedLease'].items() if k != 'expiresAt'}):
            with self.subTest(expected=expected), self.assertRaisesRegex(ValueError, 'identity'):
                admission.still_admitted(dict(self.config, expectedLease=expected), clock=lambda: 1100)
        self.release_path.write_text(json.dumps(dict(m1Released=False)))
        with self.assertRaisesRegex(ValueError, 'M1 release missing'):
            self.at(1100)
        self.assertEqual(self.booked, [])  # nothing reached the booking check

    def test_ended_booking_refuses(self):
        book.admit.side_effect = ValueError('booking cannot cover the absolute lease')
        with self.assertRaisesRegex(ValueError, 'booking cannot cover'):
            self.at(1100)


if __name__ == '__main__':
    unittest.main()
