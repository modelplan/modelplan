"""Exercise the pinned Skill installer without network access or a real CLI."""
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest


SKILL = Path(__file__).resolve().parents[1]


class InstallCLI(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.skill = self.root / "skill"
        shutil.copytree(SKILL / "scripts", self.skill / "scripts")
        self.archive = self.root / "cli.tar.gz"
        body = b'#!/bin/sh\necho "modelplan 9.9.9"\n'
        with tarfile.open(self.archive, "w:gz") as archive:
            info = tarfile.TarInfo("modelplan_linux_amd64/modelplan")
            info.size, info.mode = len(body), 0o755
            archive.addfile(info, io.BytesIO(body))
        self.checksum = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in {
            "uname": '#!/bin/sh\ncase "$1" in -s) echo Linux;; -m) echo x86_64;; esac\n',
            "curl": '''#!/bin/sh
set -eu
out=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift;;
    https://*) [ "$1" = https://example.invalid/v9.9.9/modelplan_linux_amd64.tar.gz ] || exit 7;;
  esac
  shift
done
cp "$TEST_ARCHIVE" "$out"
''',
        }.items():
            path = self.bin / name
            path.write_text(body)
            path.chmod(0o755)
        self.env = {**os.environ, "HOME": str(self.home),
                    "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
                    "TEST_ARCHIVE": str(self.archive), "MODELPLAN_PLUGIN_CLI": "off"}

    def run_install(self, checksum):
        (self.skill / "cli-pin.json").write_text(json.dumps({
            "version": "9.9.9", "release": "https://example.invalid/v9.9.9",
            "sha256": {"linux_amd64": checksum}}, indent=2) + "\n")
        return subprocess.run(["sh", str(self.skill / "scripts/install-cli.sh")],
                              env=self.env, capture_output=True, text=True, timeout=10)

    def test_current_or_newer_cli_is_kept_without_downloading(self):
        binary = self.home / ".local/bin/modelplan"
        binary.parent.mkdir(parents=True)
        # A fetch would fail its checksum; keeping an installation must return first.
        for version in ("9.9.9", "9.9.10", "10.0.0", "10.0.0-dev", "9.9.9+build.1"):
            with self.subTest(version=version):
                body = '#!/bin/sh\necho "modelplan ' + version + '"\n'
                binary.write_text(body)
                binary.chmod(0o755)
                before = binary.stat().st_mtime_ns
                result = self.run_install("0" * 64)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual("already installed (v" + version + ")\n", result.stdout)
                self.assertEqual(body, binary.read_text())
                self.assertEqual(before, binary.stat().st_mtime_ns)
                self.assertFalse((self.home / ".cache/modelplan-cli").exists())

    def test_older_cli_or_equal_prerelease_is_upgraded_to_pin(self):
        binary = self.home / ".local/bin/modelplan"
        binary.parent.mkdir(parents=True)
        for version in ("9.9.8", "9.9.9-dev"):
            with self.subTest(version=version):
                binary.write_text('#!/bin/sh\necho "modelplan ' + version + '"\n')
                binary.chmod(0o755)
                result = self.run_install(self.checksum)
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertEqual("modelplan 9.9.9", subprocess.check_output(
                    [str(binary), "version"], text=True).strip())

    def test_installs_verified_pin_into_local_bin_without_profiles(self):
        result = self.run_install(self.checksum)
        self.assertEqual(0, result.returncode, result.stderr)
        binary = self.home / ".local/bin/modelplan"
        self.assertTrue(os.access(binary, os.X_OK))
        version = subprocess.check_output([str(binary), "version"], text=True).strip()
        self.assertEqual("modelplan 9.9.9", version)
        self.assertIn("Add " + str(binary.parent) + " to your PATH.", result.stdout)
        self.assertFalse((self.home / ".profile").exists())
        self.assertFalse((self.home / ".bashrc").exists())
        self.assertFalse((self.home / ".zshrc").exists())

    def test_checksum_mismatch_preserves_existing_install(self):
        binary = self.home / ".local/bin/modelplan"
        binary.parent.mkdir(parents=True)
        binary.write_text("existing CLI")
        result = self.run_install("0" * 64)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("checksum mismatch", result.stderr)
        self.assertEqual("existing CLI", binary.read_text())
        self.assertFalse((self.home / ".cache/modelplan-cli/9.9.9/modelplan").exists())

    def test_skill_and_plugins_share_fetcher_and_pin(self):
        repo = SKILL.parents[1]
        for plugin in ("claude-code", "codex"):
            self.assertEqual((SKILL / "scripts/fetch-cli.sh").read_bytes(),
                             (repo / plugin / "hooks/fetch-cli.sh").read_bytes())
            self.assertEqual((SKILL / "cli-pin.json").read_bytes(),
                             (repo / plugin / "cli-pin.json").read_bytes())
