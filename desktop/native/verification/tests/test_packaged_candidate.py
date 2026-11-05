# SPDX-License-Identifier: MIT
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bin"))
import candidate_scratch
import packaged_candidate
import guardian


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

    def test_launcher_failure_before_registration_still_cleans_scratch(self):
        record = self.prepare()
        config = json.loads(Path(record["launchConfig"]).read_text())
        def finish_guardian(_):
            args = ["--lease", config["leasePath"], "--stop", config["stopPath"],
                    "--subject-pid-file", config["subjectPidPath"],
                    "--candidate-registry", str(self.root / "registry.json"),
                    "--candidate-parent", str(self.root),
                    "--candidate-cleanup-receipt", config["candidateCleanupReceipt"]]
            with patch.object(guardian, "run", return_value=("stopped", True, "none")), \
                 patch.object(guardian.process_scan, "scan", return_value=[]):
                self.assertEqual(guardian.main(args), 0)
        Path(config["leasePath"]).write_text(json.dumps({"runID": "run", "epoch": "epoch"}))
        with self.assertRaisesRegex(RuntimeError, "launch failed"):
            packaged_candidate.run(record, self.root / "receipt.json",
                                   runner=lambda *a, **kw: SimpleNamespace(returncode=2), wait=finish_guardian)
        self.assertTrue(json.loads((self.root / "receipt.json").read_text())["cleaned"])
        self.assertFalse(Path(record["registry"]["root"]).exists())

    def test_guardian_without_pre_registration_receipt_keeps_scratch(self):
        record = self.prepare()
        config = json.loads(Path(record["launchConfig"]).read_text())
        Path(config["leasePath"]).write_text(json.dumps({"runID": "run", "epoch": "epoch"}))
        args = ["--lease", config["leasePath"], "--stop", config["stopPath"],
                "--subject-pid-file", config["subjectPidPath"],
                "--candidate-registry", str(self.root / "registry.json"),
                "--candidate-parent", str(self.root), "--candidate-cleanup-receipt", config["candidateCleanupReceipt"]]
        with patch.object(guardian, "run", return_value=("stopped", True, "none")):
            self.assertEqual(guardian.main(args), 3)
        self.assertTrue(Path(record["registry"]["root"]).is_dir())
        self.assertFalse(Path(config["candidateCleanupReceipt"]).exists())

    def test_real_launcher_admission_failure_never_registers_and_is_cleaned(self):
        record = self.prepare()
        config = json.loads(Path(record["launchConfig"]).read_text())
        # Missing release causes the real launcher to fail before registration;
        # no app, GUI, or credentials are started or read.
        Path(config["leasePath"]).write_text(json.dumps({"runID": "run", "epoch": "epoch"}))
        def finish_guardian(_):
            args = ["--lease", config["leasePath"], "--stop", config["stopPath"],
                    "--subject-pid-file", config["subjectPidPath"],
                    "--candidate-registry", str(self.root / "registry.json"),
                    "--candidate-parent", str(self.root), "--candidate-cleanup-receipt", config["candidateCleanupReceipt"]]
            with patch.object(guardian, "run", return_value=("stopped", True, "none")), \
                 patch.object(guardian.process_scan, "scan", return_value=[]):
                self.assertEqual(guardian.main(args), 0)
        with self.assertRaisesRegex(RuntimeError, "launch failed"):
            packaged_candidate.run(record, self.root / "receipt.json", wait=finish_guardian)
        self.assertFalse(Path(config["subjectPidPath"]).exists())
        self.assertTrue(json.loads((self.root / "receipt.json").read_text())["cleaned"])
        self.assertFalse(Path(record["registry"]["root"]).exists())


if __name__ == "__main__":
    unittest.main()
