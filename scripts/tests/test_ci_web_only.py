# SPDX-License-Identifier: MIT
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "ci_web_only.py"
spec = importlib.util.spec_from_file_location("ci_web_only", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WebOnlyTests(unittest.TestCase):
    def test_web_and_cockpit_tests_only(self):
        self.assertTrue(module.web_only([b"desktop/cockpit/src/page.ts", b"desktop/tests/cockpit/a.spec.ts"]))

    def test_mixed_and_workflow_change(self):
        for path in (b"cli/a.go", b"desktop/native/a.swift", b".github/workflows/desktop.yml", b"desktop/cockpit-other/a"):
            with self.subTest(path=path):
                self.assertFalse(module.web_only([b"desktop/cockpit/web/index.html", path]))
        self.assertFalse(module.web_only([]))

    def test_real_diff_including_rename_outside_and_newline_filename(self):
        with tempfile.TemporaryDirectory() as tmp:
            def git(*args):
                return subprocess.check_output(["git", "-C", tmp, *args], stderr=subprocess.DEVNULL).decode().strip()
            git("init", "-q")
            git("config", "user.email", "test@example.invalid")
            git("config", "user.name", "Synthetic")
            root = Path(tmp)
            source = root / "desktop/cockpit/src/a.ts"
            source.parent.mkdir(parents=True)
            source.write_text("a")
            git("add", ".")
            git("commit", "-qm", "base")
            base = git("rev-parse", "HEAD")
            (source.parent / "line\nbreak.ts").write_text("b")
            git("add", ".")
            git("commit", "-qm", "web")
            web = git("rev-parse", "HEAD")
            previous = os.getcwd()
            try:
                os.chdir(tmp)
                self.assertTrue(module.classify(base, web))
                outside = root / "desktop/native/a.swift"
                outside.parent.mkdir(parents=True)
                source.rename(outside)
                git("add", "-A")
                git("commit", "-qm", "move")
                self.assertFalse(module.classify(base, git("rev-parse", "HEAD")))
                with self.assertRaises(subprocess.CalledProcessError):
                    module.classify("0" * 40, web)
            finally:
                os.chdir(previous)


if __name__ == "__main__":
    unittest.main()
