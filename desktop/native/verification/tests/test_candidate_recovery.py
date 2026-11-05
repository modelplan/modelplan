# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bin"))
import candidate_recovery
import candidate_scratch


class CandidateRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.parent = Path(self.tmp.name)
        self.registry = candidate_scratch.create(self.parent, "run", "epoch")
        self.lease = {"runID": "run", "epoch": "epoch"}
        self.guardian = {"pid": 20, "startSeconds": 3, "startMicroseconds": 0}
        self.subject = {"pid": 21, "startSeconds": 4, "startMicroseconds": 0}
        self.reservation = {"state": "running", "launchMode": "direct", **self.subject,
                            "launcher": {"pid": 22, "startSeconds": 5, "startMicroseconds": 0},
                            "scan": {"prefix": self.registry["root"], "helpers": []}}
        self.pid_file = self.parent / "subject.json"; self.pid_file.write_text(json.dumps(self.reservation))

    def test_dead_guardian_independent_close_and_empty_scan_allow_cleanup(self):
        result = candidate_recovery.recover(self.registry, self.lease, self.reservation, self.guardian,
            parent=self.parent, pid_file=self.pid_file, lookup=lambda _: None, scan=lambda _: [],
            close=lambda _: (True, "registered"))
        self.assertTrue(result["cleaned"])
        self.assertFalse(Path(self.registry["root"]).exists())

    def test_live_guardian_or_unscoped_subject_never_calls_close(self):
        calls = []
        def close(_): calls.append(True); return True, "registered"
        with self.assertRaisesRegex(ValueError, "still running"):
            candidate_recovery.recover(self.registry, self.lease, self.reservation, self.guardian,
                parent=self.parent, pid_file=self.pid_file, lookup=lambda _: self.guardian, scan=lambda _: [], close=close)
        with self.assertRaisesRegex(ValueError, "not in candidate scope"):
            candidate_recovery.recover(self.registry, self.lease, self.reservation, self.guardian,
                parent=self.parent, pid_file=self.pid_file,
                lookup=lambda pid: self.subject if pid == self.subject["pid"] else None,
                scan=lambda _: [], close=close)
        self.assertEqual(calls, [])
        self.assertTrue(Path(self.registry["root"]).is_dir())

    def test_scope_scan_failure_or_unconfirmed_close_keeps_scratch(self):
        def broken(_): raise OSError("unavailable")
        with self.assertRaises(OSError):
            candidate_recovery.recover(self.registry, self.lease, self.reservation, self.guardian,
                parent=self.parent, pid_file=self.pid_file, lookup=lambda _: None, scan=broken)
        with self.assertRaisesRegex(ValueError, "unconfirmed"):
            candidate_recovery.recover(self.registry, self.lease, self.reservation, self.guardian,
                parent=self.parent, pid_file=self.pid_file, lookup=lambda _: None, scan=lambda _: [],
                close=lambda _: (False, "unconfirmed"))
        self.assertTrue(Path(self.registry["root"]).is_dir())

    def test_wrong_registry_marker_never_calls_close(self):
        calls = []
        marker = Path(self.registry["root"]) / candidate_scratch.MARKER
        marker.write_text(json.dumps({**self.registry, "token": "wrong"}))
        with self.assertRaisesRegex(ValueError, "marker"):
            candidate_recovery.recover(self.registry, self.lease, self.reservation, self.guardian,
                parent=self.parent, pid_file=self.pid_file, lookup=lambda _: None, scan=lambda _: [],
                close=lambda _: calls.append(True))
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
