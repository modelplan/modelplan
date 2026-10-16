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


class Pace(unittest.TestCase):
    """The pace contract shared with cli/internal/quota TestPaceCasesSharedWithThePythonReader."""

    def test_shared_cases(self):
        cases = json.loads((FIX / "pace-cases.json").read_text())["cases"]
        self.assertTrue(cases)
        for c in cases:
            resets = NOW + dt.timedelta(minutes=c["resetsInMinutes"]) if "resetsInMinutes" in c else None
            w = quota.window(c["kind"], c["used"], resets, NOW, 0, c.get("resetMode", "fixed"))
            quota.eval_window(w, NOW)
            self.assertEqual(c["pace"], w["pace"], c["name"])


class ClaudeSession(unittest.TestCase):
    """Same key and attribution as cli/internal/quota TestClaudeCodeSnapshotNamesWhoseSessionItIs."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        (self.dir / "observed").mkdir()
        shutil.copy(FIX / "claude-code-snapshot.json", self.dir / "observed" / "claude-code.json")

    def tearDown(self):
        shutil.rmtree(self.dir)

    def attribution(self, session):
        accounts, _ = quota.read_claude_code(str(self.dir), session)
        return accounts[0]["harness"].get("attribution", "")

    def test_attribution(self):
        self.assertEqual(["current-thread", "recent-thread", ""], [self.attribution(s) for s in ("secret-session", "another", "")])


class Threads(unittest.TestCase):
    """Same fixture and expectation as cli/internal/quota TestCodexThreadsKeepTheirOwnModel."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        shutil.copytree(FIX / "threads", self.dir / "home")
        day = self.dir / "home" / ".codex" / "sessions" / "2026" / "10" / "14"
        names = sorted(os.listdir(day))
        for i, name in enumerate(names):
            t = NOW.timestamp() + (i - len(names)) * 600
            os.utime(day / name, (t, t))
        self.home = str(self.dir / "home" / ".codex")

    def tearDown(self):
        shutil.rmtree(self.dir)

    def codex(self, thread=""):
        return quota.report(str(self.dir / "none"), self.home, str(self.dir / "none.json"), NOW, thread)

    def test_matches_go_expectation(self):
        want = json.loads((FIX / "expected-threads.json").read_text())
        self.assertEqual(want, json.loads(json.dumps(self.codex())))

    def test_background_review_is_not_the_chat(self):
        h = self.codex()["accounts"][0]["harness"]
        self.assertEqual(("gpt-6-sol", "medium", "recent-thread", "cli"), (h["model"], h["effort"], h["attribution"], h["origin"]))

    def test_named_thread_wins(self):
        h = self.codex("01a14000-aaaa-7000-8000-00000000000a")["accounts"][0]["harness"]
        self.assertEqual(("gpt-6-astra", "high", "fast", "current-thread"), (h["model"], h["effort"], h["serviceTier"], h["attribution"]))

    def test_windows_keep_limit_ids_and_their_own_age(self):
        ws = {(w.get("limit", ""), w["kind"]): w for w in self.codex()["accounts"][0]["windows"]}
        self.assertEqual(45, ws[("", "five_hour")]["usedPercent"])
        self.assertEqual((20, 59), (ws[("", "weekly")]["usedPercent"], ws[("", "weekly")]["ageMinutes"]))
        self.assertEqual(10, ws[("codex_sol", "five_hour")]["usedPercent"])

    def test_instructions_never_printed(self):
        text = json.dumps(self.codex())
        self.assertNotIn("secret", text)
        self.assertNotIn("/home/u", text)


if __name__ == "__main__":
    unittest.main()
