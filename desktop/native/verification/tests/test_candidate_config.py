# SPDX-License-Identifier: MIT
import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path

PATH = Path(__file__).resolve().parents[1] / "bin" / "candidate_config.py"
SPEC = importlib.util.spec_from_file_location("candidate_config", PATH)
candidate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(candidate)


class CandidateConfigTests(unittest.TestCase):
    def test_config_accepts_only_new_install_and_pinned_source(self):
        with tempfile.TemporaryDirectory() as temp:
            config = {"candidate": "https://example.test/ModelPlan.zip", "sha256": "a" * 64,
                      "buildID": "synthetic", "installDir": str(Path(temp) / "unique")}
            self.assertEqual(candidate.validate_config(config), config)
            for field, value in (("candidate", "https://u:p@example.test/a"), ("candidate", "relative.zip"),
                                 ("sha256", "b" * 63), ("installDir", temp)):
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    candidate.validate_config({**config, field: value})

    def test_archive_hash_rejects_modified_data_and_links(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp) / "candidate.zip"
            archive.write_bytes(b"synthetic archive")
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertEqual(candidate.verify_archive(archive, digest), digest)
            archive.write_bytes(b"different")
            with self.assertRaises(ValueError):
                candidate.verify_archive(archive, digest)
            alias = Path(temp) / "link.zip"
            alias.symlink_to(archive)
            with self.assertRaises(ValueError):
                candidate.verify_archive(alias, digest)

    def test_caller_flags_cannot_claim_isolation(self):
        with self.assertRaisesRegex(RuntimeError, "launch denied"):
            candidate.require_isolation_proof({"isolated": True, "networkBlocked": True})


if __name__ == "__main__":
    unittest.main()
