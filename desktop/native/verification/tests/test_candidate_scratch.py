# SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "bin" / "candidate_scratch.py"
SPEC = importlib.util.spec_from_file_location("candidate_scratch", MODULE)
scratch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scratch)


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


if __name__ == "__main__":
    unittest.main()
