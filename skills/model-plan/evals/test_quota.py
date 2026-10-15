"""scripts/quota.py must give the same report as the Go client (cli/internal/quota) for the shared fixtures."""
import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FIX = ROOT / "cli" / "internal" / "quota" / "testdata"
spec = importlib.util.spec_from_file_location("quota", HERE.parent / "scripts" / "quota.py")
quota = importlib.util.module_from_spec(spec)
spec.loader.exec_module(quota)
NOW = dt.datetime(2026, 10, 14, 10, 0, tzinfo=dt.timezone.utc)


class SharedFixture(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        shutil.copytree(FIX / "home", self.dir / "home")
        s = self.dir / "home" / ".codex" / "sessions" / "2026" / "10"
        for name, age in (("13/rollout-2026-10-13T09-00-00-old.jsonl", 86400), ("14/rollout-2026-10-14T09-30-00-new.jsonl", 300)):
            t = NOW.timestamp() - age
            os.utime(s / name, (t, t))
        (self.dir / "cache" / "observed").mkdir(parents=True)
        shutil.copy(FIX / "claude-code-snapshot.json", self.dir / "cache" / "observed" / "claude-code.json")

    def tearDown(self):
        shutil.rmtree(self.dir)

    def run_report(self):
        return quota.report(str(self.dir / "cache"), str(self.dir / "home" / ".codex"),
                            str(self.dir / "home" / ".config" / "modelplan" / "local.json"), NOW)

    def test_matches_go_expectation(self):
        got = self.run_report()
        want = json.loads((FIX / "expected.json").read_text())
        self.assertEqual(want, json.loads(json.dumps(got)))

    def test_private_fields_never_printed(self):
        text = json.dumps(self.run_report())
        for leak in ("secret", "/home/u", "sk-should", "ignore previous", "please do not"):
            self.assertNotIn(leak, text)

    def test_missing_sources_are_reported(self):
        empty = self.dir / "empty"
        r = quota.report(str(empty), str(empty / "codex"), str(empty / "local.json"), NOW)
        self.assertEqual([], r["accounts"])
        self.assertEqual({"missing"}, {s["status"] for s in r["sources"]})

    def test_symlinked_local_state_is_refused(self):
        link = self.dir / "link.json"
        link.symlink_to(FIX / "home" / ".config" / "modelplan" / "local.json")
        self.assertEqual("unsafe_path", quota.read_local(str(link), NOW)[1]["status"])


if __name__ == "__main__":
    unittest.main()
