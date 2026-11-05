# SPDX-License-Identifier: MIT
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bin"))
import candidate_scratch
import packaged_candidate


class PackagedCandidateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / "candidate.zip"; self.archive.write_bytes(b"synthetic")
        self.manifest = self.root / "manifest.json"
        self.manifest.write_text(json.dumps({"sourceSHA": "a" * 40, "sha256": hashlib.sha256(b"synthetic").hexdigest()}))
        self.template = self.root / "template.json"
        self.template.write_text(json.dumps({"profile": "synthetic", "launchMode": "direct",
            "expectedLease": {"runID": "run", "epoch": "epoch"},
            **{k: str(self.root / k) for k in ("leasePath", "releasePath", "stopPath", "subjectPidPath", "candidateCleanupReceipt")}}))

    def prepare(self):
        return packaged_candidate.prepare(self.archive, self.manifest, self.template, self.root, self.root / "registry.json")

    def test_prepare_pins_archive_and_run_records_confirmed_cleanup(self):
        record = self.prepare(); config = json.loads(Path(record["launchConfig"]).read_text())
        self.assertEqual(config["subjectKind"], "app-zip")
        self.assertEqual(config["binarySHA256"], record["packageSHA256"])
        def runner(*args, **kwargs):
            result = candidate_scratch.cleanup(record["registry"], parent=self.root, run_id="run", epoch="epoch", subject_closed=True)
            Path(record["candidateCleanupReceipt"]).write_text(json.dumps(result))
            return SimpleNamespace(returncode=0)
        receipt = packaged_candidate.run(record, self.root / "receipt.json", runner=runner)
        self.assertTrue(receipt["cleaned"])
        self.assertEqual(receipt["sourceSHA"], "a" * 40)
        self.assertFalse(Path(record["registry"]["root"]).exists())

    def test_mismatch_before_prepare_creates_no_scratch(self):
        self.manifest.write_text(json.dumps({"sourceSHA": "a" * 40, "sha256": "0" * 64}))
        with self.assertRaisesRegex(ValueError, "mismatch"):
            self.prepare()
        self.assertFalse(list(self.root.glob("modelplan-candidate-*")))

    def test_unconfirmed_cleanup_fails_and_records_no_success(self):
        record = self.prepare()
        values = iter((0, 0, 0, 31, 32))
        with self.assertRaisesRegex(RuntimeError, "cleanup unconfirmed"):
            packaged_candidate.run(record, self.root / "receipt.json", runner=lambda *a, **kw: SimpleNamespace(returncode=0), clock=lambda: next(values))
        self.assertFalse(json.loads((self.root / "receipt.json").read_text())["cleaned"])
        self.assertTrue(Path(record["registry"]["root"]).exists())


if __name__ == "__main__":
    unittest.main()
