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
            obs = NOW - dt.timedelta(minutes=c.get("observedMinutesAgo", 0))
            w = quota.window(c["kind"], c["used"], resets, obs, 0, c.get("resetMode", "fixed"))
            w["_recent"] = [{"at": obs - dt.timedelta(minutes=x[0]), "used": x[1],
                             "resetsAt": resets + dt.timedelta(minutes=x[2] if len(x) > 2 else 0) if resets else None} for x in c.get("recent", [])]
            quota.eval_window(w, NOW)
            self.assertEqual(c["pace"], w["pace"], c["name"])
            self.assertNotIn("_recent", w)
            if "recent" in c:
                self.assertEqual((c["rate"], c["runsOut"]), (w["recentPercentPerHour"], w["runsOutInMinutes"]), c["name"])


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

    def test_each_session_reads_its_own(self):
        """Same case as cli/internal/quota TestClaudeCodeSessionsEachReadTheirOwnModelAndEffort."""
        path = self.dir / "observed" / "claude-code.json"
        snap = json.loads(path.read_text())
        b = dict(snap["harness"], effort="high")
        snap.update(sessionKey=quota.session_key("session-b"), harness=b, sessions=[
            {"sessionKey": quota.session_key("session-b"), "observedAt": "2026-10-14T09:59:00Z", "harness": b},
            {"sessionKey": quota.session_key("session-a"), "observedAt": "2026-10-14T09:57:00Z", "harness": dict(b, effort="medium")}])
        path.write_text(json.dumps(snap))
        got = {}
        for s in ("session-a", "session-b", "session-c", ""):
            h = quota.read_claude_code(str(self.dir), s)[0][0]["harness"]
            got[s] = (h["effort"], h.get("attribution", ""))
        self.assertEqual({"session-a": ("medium", "current-thread"), "session-b": ("high", "current-thread"),
                          "session-c": ("high", "recent-thread"), "": ("high", "")}, got)


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


class ReservePool(unittest.TestCase):
    """GPT Reserve is its own weekly pool (as cli/internal/quota/pool_test.go)."""
    now = dt.datetime(2026, 10, 17, 12, 0, tzinfo=dt.timezone.utc)

    def report(self, main_last):
        d = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, d)
        day = d / "codex" / "sessions" / "2026" / "10" / "17"
        day.mkdir(parents=True)
        week = self.now + dt.timedelta(days=3)

        def tc(at, lid, name, used, minutes, resets):
            rl = {"limit_id": lid, "limit_name": name, "plan_type": "plus",
                  "primary": {"used_percent": used, "window_minutes": minutes, "resets_at": int(resets.timestamp())}, "secondary": None}
            return json.dumps({"timestamp": quota.iso(at), "type": "event_msg", "payload": {"type": "token_count", "rate_limits": rl}})
        main = [tc(self.now - dt.timedelta(minutes=50), "codex", None, 20, 300, self.now + dt.timedelta(hours=2)),
                tc(self.now - dt.timedelta(minutes=50), "codex", None, 30, 10080, week)]
        reserve = [tc(self.now - dt.timedelta(minutes=40), "base_model_inference", "gpt-reserve", 100, 10080, week + dt.timedelta(hours=1))]
        lines = ['{"timestamp":"2026-10-17T11:00:00Z","type":"session_meta","payload":{"id":"t1","source":"cli"}}',
                 '{"timestamp":"2026-10-17T11:01:00Z","type":"turn_context","payload":{"model":"gpt-6-sol","effort":"medium"}}']
        lines += reserve + main if main_last else main + reserve
        (day / "rollout-2026-10-17T11-00-00-t1.jsonl").write_text("\n".join(lines) + "\n")
        r = quota.report(str(d / "none"), str(d / "codex"), str(d / "none.json"), self.now)
        return json.loads(json.dumps(r, default=str))["accounts"][0]

    def test_pool_decides_headroom(self):
        for main_last, pool, room, deciding in ((False, "reserve", "exhausted", "weekly"), (True, None, "spend", "weekly")):
            a = self.report(main_last)
            self.assertEqual({"/five_hour", "/weekly", "reserve/weekly"}, {w.get("limit", "") + "/" + w["kind"] for w in a["windows"]})
            self.assertEqual((pool, room, deciding), (a.get("pool"), a["headroom"], a.get("deciding")))


class ClaudeSubscription(unittest.TestCase):
    """The subscription reference the CLI's status line records travels as it is (identity.go)."""

    def test_reference_is_passed_through(self):
        d = Path(tempfile.mkdtemp())
        try:
            (d / "observed").mkdir()
            snap = json.loads((FIX / "claude-code-snapshot.json").read_text())
            snap["identity"] = {"subscriptionRef": "5d1c0a3b7e9f2468", "fileSize": 120, "fileTime": "2026-10-14T09:00:00Z", "observedAt": "2026-10-14T09:58:00Z"}
            (d / "observed" / "claude-code.json").write_text(json.dumps(snap))
            accts, _ = quota.read_claude_code(str(d))
            self.assertEqual(("5d1c0a3b7e9f2468", "verified", "claude-config"),
                             tuple(accts[0]["subscription"][k] for k in ("subscriptionRef", "status", "basis")))
            snap["identity"]["subscriptionRef"] = "person@example.com"
            (d / "observed" / "claude-code.json").write_text(json.dumps(snap))
            self.assertNotIn("subscription", quota.read_claude_code(str(d))[0][0])
        finally:
            shutil.rmtree(d)


class ResetFreshness(unittest.TestCase):
    def test_before_reset_expired_and_refreshed(self):
        reset = NOW + dt.timedelta(minutes=1)
        w = quota.window("monthly", 80, reset, NOW)
        quota.eval_window(w, NOW)
        self.assertEqual(20, w["remainingPercent"])
        for at in (reset, reset + dt.timedelta(seconds=1)):
            quota.eval_window(w, at)
            self.assertIsNone(w["usedPercent"])
            self.assertIsNone(w["remainingPercent"])
            self.assertEqual("reset_passed", w["unknownReason"])
        w = quota.window("monthly", 5, reset + dt.timedelta(days=30), reset)
        quota.eval_window(w, reset + dt.timedelta(seconds=1))
        self.assertEqual(95, w["remainingPercent"])
        self.assertNotIn("unknownReason", w)
