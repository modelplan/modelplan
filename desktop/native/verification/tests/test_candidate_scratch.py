# SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / "bin" / "candidate_scratch.py"
sys.path.insert(0, str(MODULE.parent))
SPEC = importlib.util.spec_from_file_location("candidate_scratch", MODULE)
scratch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scratch)
import guardian


class CandidateScratchTests(unittest.TestCase):
    def test_cleanup_requires_closure_and_removes_only_owned_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary)
            keep = parent / "keep"; keep.mkdir(); (keep / "data").write_text("preserve")
            registry = scratch.create(parent, "run", "epoch")
            root = Path(registry["root"])
            (root / "home").mkdir(); (root / "home" / "link").symlink_to(keep, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "closure"):
                scratch.cleanup(registry, parent=parent, run_id="run", epoch="epoch", subject_closed=False)
            receipt = scratch.cleanup(registry, parent=parent, run_id="run", epoch="epoch", subject_closed=True)
            self.assertTrue(receipt["cleaned"])
            self.assertEqual((keep / "data").read_text(), "preserve")

    def test_changed_identity_or_marker_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary); registry = scratch.create(parent, "run", "epoch")
            root = Path(registry["root"])
            with self.assertRaisesRegex(ValueError, "identity"):
                scratch.cleanup(registry, parent=parent, run_id="other", epoch="epoch", subject_closed=True)
            marker = root / scratch.MARKER
            marker.write_text(json.dumps({**registry, "token": "changed"}))
            with self.assertRaisesRegex(ValueError, "marker"):
                scratch.cleanup(registry, parent=parent, run_id="run", epoch="epoch", subject_closed=True)
            self.assertTrue(root.is_dir())

    def test_registered_cleanup_rejects_live_launcher_or_subject_scope(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary); registry = scratch.create(parent, "run", "epoch")
            launcher = {"pid": 100, "startSeconds": 5, "startMicroseconds": 1}
            reservation = {"state": "running", "launchMode": "direct", "launcher": launcher,
                           "scan": {"prefix": registry["root"], "helpers": []}}
            args = dict(parent=parent, run_id="run", epoch="epoch", subject_closed=True)
            with self.assertRaisesRegex(ValueError, "launcher still running"):
                scratch.cleanup_registered(registry, reservation, lookup=lambda _: launcher, scan=lambda _: [], launcher_wait=0, **args)
            with self.assertRaisesRegex(ValueError, "not empty"):
                scratch.cleanup_registered(registry, reservation, lookup=lambda _: None, scan=lambda _: [launcher], **args)
            with self.assertRaisesRegex(ValueError, "only direct"):
                scratch.cleanup_registered(registry, {**reservation, "launchMode": "launchservices"},
                                           lookup=lambda _: None, scan=lambda _: [], **args)
            result = scratch.cleanup_registered(registry, reservation, lookup=lambda _: None, scan=lambda _: [], **args)
            self.assertTrue(result["cleaned"])

    def test_guardian_produces_cleanup_receipt_after_closure(self):
        with tempfile.TemporaryDirectory() as temporary:
            parent = Path(temporary); registry = scratch.create(parent, "run", "epoch")
            registry_path = parent / "registry.json"; registry_path.write_text(json.dumps(registry))
            lease = parent / "lease.json"; lease.write_text(json.dumps({"runID": "run", "epoch": "epoch"}))
            pid = parent / "subject.json"; pid.write_text(json.dumps({
                "state": "running", "launchMode": "direct",
                "launcher": {"pid": 100, "startSeconds": 5, "startMicroseconds": 1},
                "scan": {"prefix": registry["root"], "helpers": []}}))
            receipt = parent / "cleanup.json"
            argv = ["guardian.py", "--lease", str(lease), "--stop", str(parent / "stop"),
                    "--subject-pid-file", str(pid), "--candidate-registry", str(registry_path),
                    "--candidate-parent", str(parent), "--candidate-cleanup-receipt", str(receipt)]
            with patch.object(sys, "argv", argv), patch.object(guardian, "run", return_value=("stopped", True, "registered")), \
                 patch.object(guardian, "identity", return_value=None), patch.object(guardian.process_scan, "scan", return_value=[]):
                self.assertEqual(guardian.main(), 0)
            self.assertEqual(json.loads(receipt.read_text()), {"runID": "run", "epoch": "epoch", "cleaned": True})
            self.assertFalse(Path(registry["root"]).exists())


if __name__ == "__main__":
    unittest.main()
