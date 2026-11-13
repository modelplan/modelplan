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

    def test_stage_checks_hash_and_never_overwrites_an_existing_file(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source.zip"; source.write_bytes(b"synthetic")
            target = Path(temp) / "target.zip"
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValueError, "mismatch"):
                candidate.stage_local_archive(source, target, "a" * 64)
            self.assertFalse(target.exists())
            self.assertEqual(candidate.stage_local_archive(source, target, digest), digest)
            self.assertEqual(target.read_bytes(), b"synthetic")
            with self.assertRaises(FileExistsError):
                candidate.stage_local_archive(source, target, digest)
            self.assertEqual(target.read_bytes(), b"synthetic")

    def test_stage_refuses_symlink_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source.zip"; source.write_bytes(b"synthetic")
            alias = Path(temp) / "alias.zip"; alias.symlink_to(source)
            with self.assertRaises(OSError):
                candidate.stage_local_archive(alias, Path(temp) / "target.zip", "a" * 64)


if __name__ == "__main__":
    unittest.main()
