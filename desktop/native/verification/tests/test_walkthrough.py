# SPDX-License-Identifier: MIT
import argparse
import datetime
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1] / "walkthrough"
sys.path.insert(0, str(ROOT))
import walkthrough as w  # noqa: E402


def ring(name, y):
    return {"id": "dock.subscription." + name, "role": "AXButton", "value": "50%", "frame": [10.0, y, 44.0, 44.0]}


def widget(grip_y, ring_ys):
    children = [ring(str(i), y) for i, y in enumerate(ring_ys)]
    children.append({"id": "dock.grip.0", "frame": [12.0, grip_y, 30.0, 20.0]})
    return {"role": "AXWindow", "frame": [0.0, 100.0, 90.0, 300.0], "children": children}


class FakeHost:
    def __init__(self, tree=None, windows=(), stats=None):
        self.tree, self.windows, self.calls, self.clock = tree or {}, list(windows), [], 0.0
        self.stats = stats or {"colours": 500, "dominantShare": 0.4}
        self.share = 0.0

    def helper(self, *arguments):
        self.calls.append(arguments)
        if arguments[0] == "tree":
            return json.loads(json.dumps(self.tree))
        if arguments[0] == "windows":
            return self.windows
        if arguments[0] == "stats":
            return self.stats
        if arguments[0] == "press":
            return {"pressed": True}
        if arguments[0] == "diff":
            return {"changedShare": self.share}
        return {}

    def capture(self, path, rect=None):
        Path(path).write_bytes(b"png")

    def run(self, command, env, stdin=None, timeout=120):
        self.calls.append(("run", command))
        return mock.Mock(returncode=0, stdout=json.dumps({"storeEpoch": "e", "generation": 1}), stderr="")

    def capture_window(self, path, window_id):
        self.calls.append(("capture_window", window_id))
        Path(path).write_bytes(b"png")

    def sleep(self, seconds):
        self.clock += seconds

    def now(self):
        self.clock += 0.01
        return self.clock


def walker(host, out, steps):
    walk = w.Walkthrough(host, "App.app", out, steps, {}, (1000, 800))
    walk.pid = 42
    return walk


class Targets(unittest.TestCase):
    TREE = {"windows": [{"role": "AXWindow", "frame": [0, 0, 100, 100], "children": [
                {"id": "a", "label": "Close", "frame": [1, 2, 3, 4]},
                {"id": "closed", "frame": [0, 768, 0, 0]}]}],
            "extras": {"children": [{"role": "AXMenuBarItem", "frame": [700, 0, 60, 24]}]}}

    def test_kinds(self):
        self.assertEqual(w.resolve(self.TREE, "ax:a")["id"], "a")
        self.assertEqual(w.resolve(self.TREE, "label:Close")["id"], "a")
        self.assertEqual(w.resolve(self.TREE, "status-item")["frame"], [700, 0, 60, 24])
        self.assertEqual(w.resolve(self.TREE, "window-of:ax:a")["role"], "AXWindow")

    def test_label_prefix_and_contains(self):
        self.assertEqual(w.resolve(self.TREE, "label^:Clo")["id"], "a")
        self.assertEqual(w.resolve(self.TREE, "label~:los")["id"], "a")
        self.assertIsNone(w.resolve(self.TREE, "label^:los"))

    def test_click_first_takes_the_first_target_on_screen_and_fails_when_none_is(self):
        run = w.Walkthrough(FakeHost(tree=self.TREE), "App.app", "out", [], {}, (1000, 800))
        run.op_clickFirst({"targets": ["label:Nope", "label:Close"]})
        self.assertEqual(run.host.calls[-1][0], "click")
        with self.assertRaises(w.WalkthroughError):
            run.op_clickFirst({"targets": ["label:Nope"]})

    def test_a_closed_menu_item_exists_but_is_not_on_screen(self):
        self.assertIsNone(w.resolve(self.TREE, "ax:closed"))
        self.assertEqual(len(w.resolve_all(self.TREE, "ax:closed")), 1)

    def test_unknown_kind_is_an_error_not_a_miss(self):
        with self.assertRaises(w.WalkthroughError):
            w.resolve(self.TREE, "nonsense:x")


class Mirror(unittest.TestCase):
    def test_reflects_inside_the_widget_window_only_when_the_grip_reports_above_the_rings(self):
        tree = {"windows": [widget(110.0, [200.0, 300.0])]}
        self.assertTrue(w.unmirror_widget(tree))
        frames = {c["id"]: c["frame"] for c in tree["windows"][0]["children"]}
        self.assertEqual(frames["dock.grip.0"][1], 370.0)
        self.assertEqual(frames["dock.subscription.0"][1], 256.0)

    def test_true_frames_are_left_alone(self):
        tree = {"windows": [widget(370.0, [156.0, 256.0])]}
        self.assertFalse(w.unmirror_widget(tree))
        self.assertEqual(tree["windows"][0]["children"][0]["frame"][1], 156.0)


class Bundle(unittest.TestCase):
    INFO = {"CFBundleExecutable": w.APP_EXECUTABLE, "ModelPlanCockpitEntryEnabled": True, "ModelPlanPublicSource": "a" * 40}

    def test_owner_test_package_passes(self):
        self.assertEqual(w.check_bundle(self.INFO, "a" * 40), [])

    def test_release_package_and_wrong_source_are_refused(self):
        self.assertTrue(w.check_bundle({**self.INFO, "ModelPlanCockpitEntryEnabled": False}, None))
        self.assertTrue(w.check_bundle(self.INFO, "b" * 40))


class Seed(unittest.TestCase):
    NOW = datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc)
    SEED = json.loads((ROOT / "seed.json").read_text(encoding="utf-8"))

    def test_declared_shape(self):
        value = w.declared_quota(self.SEED, self.NOW)
        self.assertEqual(len(value["plans"]), len(value["windows"]))
        self.assertTrue(all(p["planId"].startswith("synthetic-") for p in value["plans"]))
        self.assertEqual(value["windows"][0]["observedAt"], "2025-12-31T23:59:45Z")

    def test_codex_runtime_stand_in_answers_the_app_server_with_invented_numbers(self):
        script = w.codex_runtime_script(self.SEED, self.NOW)
        self.assertTrue(script.startswith("#!/bin/sh"))
        self.assertIn('"usedPercent":96', script)  # 4% left in the five-hour window
        self.assertIn('"balance":"420"', script)  # the reserve line
        self.assertIn("synthetic-credit-1", script)
        self.assertNotIn("%(", script)
        answer = [line for line in script.splitlines() if "account/rateLimits/read" in line][0]
        body = answer[answer.index('{"id":2,"result":') + len('{"id":2,"result":'):answer.rindex("}'")]
        self.assertEqual(json.loads(body)["rateLimitsByLimitId"]["codex"]["planType"], "pro")

    def test_perf_ledger_has_seven_days_and_enough_sessions_for_six_ranked_rows(self):
        ledger = w.perf_ledger(self.SEED, self.NOW, {"storeEpoch": "e"})
        self.assertEqual(ledger["schemaVersion"], 1)
        self.assertEqual({r["day"] for r in ledger["rows"]}, {(self.NOW - datetime.timedelta(days=d)).strftime("%Y-%m-%d") for d in range(7)})
        self.assertGreaterEqual(len(ledger["sessions"]), 6)
        self.assertTrue(all(r["grantEpoch"] == {"storeEpoch": "e", "revokedGeneration": 0} for r in ledger["rows"] + ledger["sessions"]))
        self.assertTrue(all(len(x["ref"]) == 16 and len(x["projectRef"]) == 16 for x in ledger["sessions"]))
        self.assertLess(datetime.datetime.strptime(ledger["since"], "%Y-%m-%dT%H:%M:%SZ"), self.NOW.replace(tzinfo=None) - datetime.timedelta(days=7))

    def test_seed_marks_three_or_more_tools_for_the_first_run_list(self):
        self.assertGreaterEqual(len(self.SEED["markers"]), 3)
        self.assertTrue(all(m.startswith(".") for m in self.SEED["markers"]))
        self.assertIn("codex.runtime_usage", self.SEED["consent"])
        self.assertNotIn(".claude", self.SEED["markers"])  # Claude Code would show a ring that vanishes mid-walk

    def test_live_session_ends_on_a_tool_output_so_the_turn_is_still_running(self):
        lines = [json.loads(line) for line in w.live_session_lines(self.NOW, 3, "/x/alpha", "gpt-6-astra").splitlines()]
        self.assertEqual(lines[0]["type"], "session_meta")
        self.assertEqual(lines[1]["payload"]["type"], "task_started")
        self.assertEqual(lines[2]["payload"]["model"], "gpt-6-astra")
        self.assertTrue(w.live_session_lines(self.NOW, 1, "/x", "m").startswith('{"timestamp":"'))  # compact, as the parser matches it
        self.assertEqual(lines[-1]["payload"]["type"], "function_call_output")
        self.assertTrue(all(line["timestamp"] <= w.stamp_micro(self.NOW) for line in lines))
        more = w.live_session_lines(self.NOW, 2, "/x/alpha", "m", first=False)
        self.assertNotIn("task_started", more)

    def test_live_session_writes_a_rollout_under_the_codex_sessions_folder_of_the_profile(self):
        with tempfile.TemporaryDirectory() as home:
            session = w.LiveSession(Path(home), self.SEED, clock=lambda: self.NOW.timestamp())
            session.append(2)
            session.append(2)
            text = session.path.read_text(encoding="utf-8")
            self.assertIn(".codex/sessions/2026/01/01", str(session.path))
            self.assertEqual(text.count("task_started"), 1)
            self.assertEqual(text.count("function_call_output"), 4)
            self.assertTrue((Path(session.cwd) / ".git").is_dir())

    def test_live_record_lands_in_the_ledger_atomically_and_replaces_itself(self):
        with tempfile.TemporaryDirectory() as home:
            observed = Path(home) / "Library/Caches/modelplan/observed"
            observed.mkdir(parents=True)
            (observed / "perf.json").write_text(json.dumps(w.perf_ledger(self.SEED, self.NOW, {"storeEpoch": "e"})), encoding="utf-8")
            session = w.LiveSession(Path(home), self.SEED, clock=lambda: self.NOW.timestamp())
            session.record = ("e", "0123456789abcdef")
            session.append(2)
            session.append(2)
            ledger = json.loads((observed / "perf.json").read_text(encoding="utf-8"))
            self.assertEqual(len(ledger["live"]), 1)
            live = ledger["live"][0]
            self.assertTrue(live["running"])
            self.assertEqual((live["subscriptionRef"], live["source"], live["grantEpoch"]["storeEpoch"]), ("0123456789abcdef", "codex", "e"))
            self.assertEqual(len(ledger["sessions"]), 8)  # the history stays
            self.assertFalse((observed / "perf.json.walkthrough").exists())

    def test_child_gets_the_synthetic_home_and_only_the_stand_in_runtime_of_the_runner(self):
        env = w.child_environment(Path("profile"))
        self.assertEqual(set(env), {"HOME", "CFFIXED_USER_HOME", "TMPDIR", "PATH", "LANG", "MODELPLAN_CODEX"})
        self.assertEqual(env["HOME"], env["CFFIXED_USER_HOME"])
        self.assertTrue(env["MODELPLAN_CODEX"].startswith("profile"))
        self.assertTrue(env["PATH"].startswith("profile"))


class Script(unittest.TestCase):
    STEPS = json.loads((ROOT / "steps.json").read_text(encoding="utf-8"))["steps"]

    def test_every_step_has_what_the_manifest_needs_and_only_known_verbs(self):
        ids = [s["id"] for s in self.STEPS]
        self.assertEqual(len(ids), len(set(ids)))
        for index, step in enumerate(self.STEPS):
            self.assertTrue(step["title"] and step["expected"])
            self.assertTrue(set(step.get("requires", [])) <= set(ids[:index]), step["id"])
            actions = list(step.get("actions", []))
            while actions:
                action = actions.pop()
                self.assertTrue(hasattr(w.Walkthrough, "op_" + action["op"]), action["op"])
                actions.extend(action.get("then", []))

    def test_covers_the_agreed_walkthrough(self):
        ids = {s["id"] for s in self.STEPS}
        self.assertTrue({"widget-rest", "widget-hover", "popup-card", "drag-snap", "status-menu-right", "first-use-hint",
                         "cockpit-open", "porthole-enlarged", "hud-select", "faders"} <= ids)

    def test_covers_the_build_12_checklist(self):
        ids = {s["id"] for s in self.STEPS}
        self.assertTrue({"first-run-window", "widget-collapse", "widget-reveal", "card-third-ring", "card-pointer-away",
                         "card-empty-quota", "cockpit-toggle-close", "cockpit-reopen", "shutter-closed",
                         "cockpit-drag-title", "help-map", "air-1440x900", "air-1470x956"} <= ids)
        self.assertFalse({"cockpit-detach", "cockpit-put-back"} & ids, "the detach button is gone (G3-54)")

    def test_covers_the_build_14_checklist_on_the_seeded_profile(self):
        ids = {s["id"] for s in self.STEPS}
        self.assertTrue({"first-run-window", "first-run-login-off", "s-unreadable-no-ring", "s-reserve-card", "s-bells-idle", "s-bells-working",
                         "s-tab-marks", "s-fader-drag-compare", "s-compare-back", "s-fader-drag-esc", "s-menubar-stable",
                         "s-reset-home", "s-reset-displace-widget", "s-reset-position"} <= ids)

    def test_the_session_starts_after_the_idle_bells_were_photographed(self):
        ids = [s["id"] for s in self.STEPS]
        self.assertLess(ids.index("s-bells-idle"), ids.index("s-bells-working"))
        working = next(s for s in self.STEPS if s["id"] == "s-bells-working")
        self.assertEqual(working["actions"][0]["op"], "startSession")

    def test_open_at_login_is_unticked_only_once_and_before_done(self):
        presses = [s["id"] for s in self.STEPS for a in s.get("actions", []) if a.get("op") == "press" and a.get("value") == "firstRun.login"]
        self.assertEqual(presses, ["first-run-login-off"])

    def test_the_seed_has_a_ring_at_zero(self):
        seed = json.loads((ROOT / "seed.json").read_text(encoding="utf-8"))
        self.assertIn(0, [p["remainingPercent"] for p in seed["declared"]])

    def test_every_check_kind_is_known(self):
        known = {"differsFrom", "matches", "exists", "opened", "absent", "checked", "on", "moved", "changed", "cardNamed",
                 "collapsed", "allOnScreen", "fits", "newWindow", "noNewWindow", "windowClosed", "nonblank",
                 "anyExists", "underStatusItem", "nearNamed", "countAtLeast", "stable", "valueIs", "regionShot", "regionDiffers", "markSizes"}
        for step in self.STEPS:
            for check in step.get("checks", []):
                self.assertIn(next(iter(check)), known, step["id"])


class Steps(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.out = Path(directory.name)

    def test_a_pass_writes_the_picture_tree_and_crop_named_in_the_manifest(self):
        host = FakeHost({"windows": [{"frame": [0, 0, 9, 9], "children": [{"id": "x", "frame": [1, 1, 2, 2]}]}]})
        step = {"id": "s", "title": "t", "expected": "e", "shot": {"crop": "ax:x"}, "checks": [{"exists": "ax:x"}]}
        record = walker(host, self.out, [step]).walk_steps()[0]
        self.assertEqual(record["status"], "pass")
        for key in ("file", "crop", "tree"):
            self.assertTrue((self.out / record[key]).exists())

    def test_window_shot_captures_the_smallest_window_holding_the_target(self):
        host = FakeHost({"windows": [{"frame": [0, 0, 900, 900], "children": [{"id": "x", "frame": [110, 110, 20, 20]}]}]},
                        windows=[{"id": 7, "onScreen": True, "bounds": [0, 0, 900, 900]},
                                 {"id": 9, "onScreen": True, "bounds": [100, 100, 300, 300]},
                                 {"id": 11, "onScreen": False, "bounds": [105, 105, 50, 50]}])
        step = {"id": "s", "title": "t", "expected": "e", "shot": {"window": "ax:x"}}
        record = walker(host, self.out, [step]).walk_steps()[0]
        self.assertIn(("capture_window", 9), host.calls)
        self.assertEqual(record["window"]["bounds"], [100, 100, 300, 300])
        self.assertTrue((self.out / record["window"]["file"]).exists())

    def test_a_failed_action_is_still_photographed_and_blocks_dependents(self):
        steps = [{"id": "a", "title": "t", "expected": "e", "actions": [{"op": "click", "target": "ax:gone"}]},
                 {"id": "b", "title": "t", "expected": "e", "requires": ["a"]}]
        first, second = walker(FakeHost(), self.out, steps).walk_steps()
        self.assertEqual(first["status"], "fail")
        self.assertIn("ax:gone", first["reason"])
        self.assertTrue((self.out / first["file"]).exists())
        self.assertEqual((second["status"], second["file"]), ("not-run", None))
        self.assertEqual(second["reason"], "needs a")

    def test_when_runs_nested_actions_only_for_the_flow_on_screen(self):
        tree = {"windows": [{"frame": [0, 0, 9, 9], "children": [{"id": "pick", "frame": [1, 1, 2, 2]},
                                                                  {"id": "tool.a", "frame": [3, 3, 2, 2]}]}]}
        host = FakeHost(tree)
        walk = walker(host, self.out, [])
        walk.op_when({"op": "when", "present": "ax:pick", "then": [{"op": "click", "target": "ax^:tool."}]})
        walk.op_when({"op": "when", "absent": "ax:pick", "then": [{"op": "click", "target": "ax:gone"}]})
        walk.op_when({"op": "when", "present": "ax:gone", "then": [{"op": "click", "target": "ax:gone"}]})
        self.assertEqual([c for c in host.calls if c[0] == "click"], [("click", 4.0, 4.0)])

    def test_when_equals_reads_the_control_value(self):
        tree = {"windows": [{"frame": [0, 0, 9, 9], "children": [{"id": "on", "value": "On", "frame": [1, 1, 2, 2]},
                                                                  {"id": "off", "value": "Off", "frame": [5, 5, 2, 2]}]}]}
        host = FakeHost(tree)
        walk = walker(host, self.out, [])
        walk.op_when({"op": "when", "equals": {"target": "ax:off", "value": "On"}, "then": [{"op": "click", "target": "ax:off"}]})
        walk.op_when({"op": "when", "equals": {"target": "ax:on", "value": "On"}, "then": [{"op": "click", "target": "ax:on"}]})
        self.assertEqual([c for c in host.calls if c[0] == "click"], [("click", 2.0, 2.0)])

    def test_await_absent_fails_when_the_target_stays(self):
        host = FakeHost({"windows": [{"frame": [0, 0, 9, 9], "children": [{"id": "looking", "frame": [1, 1, 2, 2]}]}]})
        walk = walker(host, self.out, [])
        walk.op_awaitAbsent({"target": "ax:gone"})
        with self.assertRaises(w.WalkthroughError):
            walk.op_awaitAbsent({"target": "ax:looking", "timeout": 2})

    def test_blank_render_fails(self):
        host = FakeHost({"windows": [{"frame": [0, 0, 9, 9], "id": "x"}]}, stats={"colours": 2, "dominantShare": 0.99})
        step = {"id": "s", "title": "t", "expected": "e", "checks": [{"nonblank": "ax:x"}]}
        record = walker(host, self.out, [step]).walk_steps()[0]
        self.assertEqual(record["status"], "fail")
        self.assertIn("blank", record["reason"])

    def test_new_window_is_measured_against_the_start_of_the_step(self):
        host = FakeHost(windows=[{"id": 1, "onScreen": True}])
        step = {"id": "s", "title": "t", "expected": "e", "checks": [{"newWindow": True}]}
        self.assertEqual(walker(host, self.out, [step]).walk_steps()[0]["status"], "fail")


    def crop_steps(self, check):
        crop = {"crop": "ax:x"}
        return [{"id": "a", "title": "t", "expected": "e", "shot": crop},
                {"id": "b", "title": "t", "expected": "e", "shot": crop, "checks": [check]}]

    def compared(self, share, check):
        host = FakeHost({"windows": [{"frame": [0, 0, 9, 9], "id": "x"}]})
        host.share = share
        return walker(host, self.out, self.crop_steps(check)).walk_steps()[1]

    def test_pixel_comparison_is_recorded_and_decides(self):
        record = self.compared(0.002, {"differsFrom": {"step": "a", "min": 0.01}})
        self.assertEqual(record["status"], "fail")
        self.assertEqual(record["measures"]["changedShareFrom:a"], 0.002)
        self.assertEqual(self.compared(0.02, {"differsFrom": {"step": "a", "min": 0.01}})["status"], "pass")
        self.assertEqual(self.compared(0.02, {"matches": {"step": "a", "max": 0.005}})["status"], "fail")

    def test_comparing_with_a_step_that_has_no_crop_fails(self):
        step = {"id": "b", "title": "t", "expected": "e", "shot": {"crop": "ax:x"},
                "checks": [{"matches": {"step": "nothing", "max": 1}}]}
        host = FakeHost({"windows": [{"frame": [0, 0, 9, 9], "id": "x"}]})
        self.assertEqual(walker(host, self.out, [step]).walk_steps()[0]["status"], "fail")


class NewChecks(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.out = Path(directory.name)

    def one(self, host, step):
        return walker(host, self.out, [{"id": "s", "title": "t", "expected": "e", **step}]).walk_steps()[0]

    def test_a_host_without_the_display_mode_skips_and_does_not_fail(self):
        class Modes(FakeHost):
            def helper(self, *arguments):
                if arguments[0] == "modes":
                    return [{"width": 1920, "height": 1080}]
                return super().helper(*arguments)
        record = self.one(Modes(), {"actions": [{"op": "setDisplay", "size": [1470, 956]}]})
        self.assertEqual(record["status"], "skipped")
        self.assertIn("1920x1080", record["reason"])
        self.assertEqual(w.failures({"steps": [record], "checks": []}), [])

    def test_card_named_after_the_clicked_ring(self):
        tree = {"windows": [{"frame": [0, 0, 90, 300], "children": [
            {"id": "dock.subscription.a", "label": "A", "frame": [0, 10, 40, 40]},
            {"id": "dock.subscription.b", "label": "B", "frame": [0, 60, 40, 40]},
            {"id": "dock.card.text.name", "value": "A", "frame": [100, 10, 80, 20]}]}]}
        self.assertEqual(self.one(FakeHost(tree), {"actions": [{"op": "clickRing", "index": 0}],
                                                   "checks": [{"cardNamed": True}]})["status"], "pass")
        record = self.one(FakeHost(tree), {"actions": [{"op": "clickRing", "index": 1}], "checks": [{"cardNamed": True}]})
        self.assertEqual(record["status"], "fail")
        self.assertIn("'B'", record["reason"])

    def test_collapsed_means_gone_or_much_smaller(self):
        big = {"windows": [{"frame": [0, 0, 90, 300], "children": [{"id": "g", "frame": [1, 1, 5, 5]}]}]}
        step = {"actions": [{"op": "remember", "target": "window-of:ax:g"}], "checks": [{"collapsed": "window-of:ax:g"}]}
        self.assertEqual(self.one(FakeHost(big), step)["status"], "fail")
        walk = walker(FakeHost({}), self.out, [])
        walk.remembered = [0, 0, 90, 300]
        walk.check({"collapsed": "window-of:ax:g"}, self.out, {})

    def test_fits_uses_the_visible_area_below_the_menu_bar_and_above_the_dock(self):
        facts = {"screens": [{"frame": [0, 0, 1440, 900], "visible": [0, 70, 1440, 805]}]}
        self.assertEqual(w.visible_area(facts), [0, 25, 1440, 805])
        tall = {"windows": [{"frame": [800, 25, 600, 860], "label": "ModelPlan Cockpit"}]}
        walk = walker(FakeHost(tall), self.out, [])
        walk.facts = facts
        with self.assertRaises(w.WalkthroughError):
            walk.check({"fits": "label:ModelPlan Cockpit"}, self.out, {})

    def test_a_harness_fault_fails_the_step_and_the_walk_goes_on(self):
        class Broken(FakeHost):
            def helper(self, *arguments):
                if arguments[0] == "move":
                    raise TypeError("boom")
                return super().helper(*arguments)
        steps = [{"id": "a", "title": "t", "expected": "e", "actions": [{"op": "park"}]},
                 {"id": "b", "title": "t", "expected": "e"}]
        first, second = walker(Broken(), self.out, steps).walk_steps()
        self.assertEqual(first["status"], "fail")
        self.assertIn("TypeError", first["reason"])
        self.assertEqual(second["status"], "pass")

    def test_stable_needs_the_same_reading_every_time_under_the_pointer(self):
        node = {"role": "AXMenuBarItem", "title": "0%", "help": "tip", "frame": [100, 0, 60, 24]}
        tree = {"windows": [], "extras": {"children": [node]}}
        step = {"actions": [{"op": "watch", "target": "status-item", "seconds": 3, "every": 0.5, "hover": True}], "checks": [{"stable": "status-item"}]}
        record = self.one(FakeHost(tree), step)
        self.assertEqual(record["status"], "pass")
        self.assertGreaterEqual(len(record["measures"]["samples"]), 3)

        class Jumping(FakeHost):
            def helper(self, *arguments):
                if arguments[0] == "tree":
                    self.tree["extras"]["children"][0]["title"] = "0" if len(self.calls) % 2 else "0%"
                return super().helper(*arguments)
        record = self.one(Jumping(json.loads(json.dumps(tree))), step)
        self.assertEqual(record["status"], "fail")
        self.assertIn("changed under the pointer", record["reason"])

    def test_value_is_and_count_at_least_and_any_exists(self):
        tree = {"windows": [{"frame": [0, 0, 500, 500], "children": [
            {"id": "firstRun.login", "value": "0", "frame": [1, 1, 5, 5]},
            {"id": "scope.firstRun.tool.a", "frame": [1, 10, 5, 5]}, {"id": "scope.firstRun.tool.b", "frame": [1, 20, 5, 5]},
            {"id": "scope.firstRun.tool.c", "frame": [1, 30, 5, 5]}, {"role": "AXStaticText", "value": "Reserve", "frame": [1, 40, 5, 5]}]}]}
        ok = {"checks": [{"valueIs": {"target": "ax:firstRun.login", "is": "0"}}, {"countAtLeast": {"target": "ax^:scope.firstRun.tool.", "min": 3}},
                         {"anyExists": ["label:nothing", "value~:Reserv"]}]}
        self.assertEqual(self.one(FakeHost(tree), ok)["status"], "pass")
        for bad in ({"valueIs": {"target": "ax:firstRun.login", "is": "1"}}, {"countAtLeast": {"target": "ax^:scope.firstRun.tool.", "min": 4}},
                    {"anyExists": ["label:nothing"]}):
            self.assertEqual(self.one(FakeHost(tree), {"checks": [bad]})["status"], "fail")

    def test_under_the_status_item_and_near_a_remembered_frame(self):
        icon = {"role": "AXMenuBarItem", "title": "5%", "frame": [1000, 0, 60, 24]}
        cockpit = {"frame": [700, 30, 540, 700], "label": "ModelPlan Cockpit"}
        widget = {"frame": [0, 300, 90, 340], "children": [{"id": "dock.grip.0", "frame": [10, 600, 30, 20]}]}
        tree = {"windows": [{"frame": cockpit["frame"], "children": [cockpit]}, widget], "extras": {"children": [icon]}}
        here = {"underStatusItem": {"target": "window-of:label:ModelPlan Cockpit", "slack": 10}}
        self.assertEqual(self.one(FakeHost(tree), {"checks": [here]})["status"], "pass")
        far = json.loads(json.dumps(tree))
        far["windows"][0]["frame"] = [100, 30, 540, 700]
        far["windows"][0]["children"][0]["frame"] = [100, 30, 540, 700]
        self.assertEqual(self.one(FakeHost(far), {"checks": [here]})["status"], "fail")
        self.assertEqual(self.one(FakeHost(far), {"checks": [{"underStatusItem": {**here["underStatusItem"], "is": False}}]})["status"], "pass")
        step = {"actions": [{"op": "rememberNamed", "name": "home", "target": "window-of:ax:dock.grip.0"}],
                "checks": [{"nearNamed": {"name": "home", "target": "window-of:ax:dock.grip.0", "axes": "y", "slack": 5}}]}
        self.assertEqual(self.one(FakeHost(tree), step)["status"], "pass")

    def test_region_differs_from_an_earlier_region_and_marks_are_measured_by_glyph(self):
        tree = {"windows": [{"frame": [0, 0, 400, 300], "label": "ModelPlan Cockpit", "children": [
            {"frame": [10, 10, 100, 26], "label": "Codex · Shortcut key 1"}, {"frame": [120, 10, 100, 26], "label": "Gemini CLI · Shortcut key 2"}]}]}

        class Pixels(FakeHost):
            glyphs = [{"width": 14, "height": 14}, {"width": 13, "height": 15}]
            def helper(self, *arguments):
                if arguments[0] == "glyph":
                    self.calls.append(arguments)
                    return self.glyphs.pop(0)
                return super().helper(*arguments)
        host = Pixels(tree)
        host.share = 0.01
        walk = walker(host, self.out, [
            {"id": "idle", "title": "t", "expected": "e", "checks": [{"regionShot": {"target": "label:ModelPlan Cockpit", "at": [0, 0.9, 1, 0.1]}}]},
            {"id": "busy", "title": "t", "expected": "e", "checks": [
                {"regionDiffers": {"target": "label:ModelPlan Cockpit", "at": [0, 0.9, 1, 0.1], "step": "idle", "min": 0.005}},
                {"markSizes": {"targets": ["label^:Codex ·", "label^:Gemini CLI ·"], "within": 0.35}}]}])
        first, second = walk.walk_steps()
        self.assertEqual((first["status"], second["status"]), ("pass", "pass"), second.get("reason"))
        self.assertEqual(second["measures"]["marks"]["label^:Codex ·"]["width"], 14)
        self.assertTrue((self.out / second["region"]).exists())
        host.share = 0.0
        host.glyphs = [{"width": 14, "height": 14}, {"width": 24, "height": 24}]
        walk2 = walker(host, self.out, [
            {"id": "idle", "title": "t", "expected": "e", "checks": [{"regionShot": {"target": "label:ModelPlan Cockpit", "at": [0, 0.9, 1, 0.1]}}]},
            {"id": "busy", "title": "t", "expected": "e", "checks": [
                {"regionDiffers": {"target": "label:ModelPlan Cockpit", "at": [0, 0.9, 1, 0.1], "step": "idle", "min": 0.005}},
                {"markSizes": {"targets": ["label^:Codex ·", "label^:Gemini CLI ·"], "within": 0.35}}]}])
        _, bad = walk2.walk_steps()
        self.assertEqual(bad["status"], "fail")
        self.assertIn("looks the same", bad["reason"])
        self.assertIn("mark sizes differ", bad["reason"])

    def test_the_session_op_needs_a_profile_and_starts_one_thread_once(self):
        walk = walker(FakeHost({}), self.out, [])
        with self.assertRaises(w.WalkthroughError):
            walk.op_startSession({})
        with tempfile.TemporaryDirectory() as home:
            walk.home, walk.seed = Path(home), json.loads((ROOT / "seed.json").read_text(encoding="utf-8"))
            walk.op_startSession({})
            first = walk.live.thread
            walk.op_startSession({})
            self.assertIs(walk.live.thread, first)
            walk.live.stop()
            self.assertTrue(walk.live.path.exists())

    def test_matchers_value_contains_and_help_contains(self):
        node = {"value": "420 credits", "help": "What the reserve means"}
        self.assertTrue(w.matcher("value~:credits")(node))
        self.assertFalse(w.matcher("value~:money")(node))
        self.assertTrue(w.matcher("help~:reserve")({"help": "the reserve"}))


class Guard(unittest.TestCase):
    def test_refuses_to_post_input_outside_a_hosted_runner(self):
        args = argparse.Namespace(out="unused", home="unused", app="unused")
        with mock.patch.dict(os.environ, {"RUNNER_ENVIRONMENT": "self-hosted"}):
            with self.assertRaises(SystemExit):
                w.run(args, FakeHost())


class CrashReportRedactionTests(unittest.TestCase):
    def sample(self):
        header = {"app_name": "ModelPlan", "app_version": "1.0", "incident_id": "6F0E2C1A-1111-2222-3333-444455556666"}
        body = {"procPath": "/Users/alice/Library/Developer/ModelPlan.app/Contents/MacOS/ModelPlan", "userID": 501,
                "hostName": "alices-mbp.local", "crashReporterKey": "ABCDEF12-3456-7890-ABCD-EF1234567890",
                "bundleInfo": {"CFBundleShortVersionString": "1.0", "CFBundleVersion": "14"},
                "exception": {"type": "EXC_BAD_ACCESS", "signal": "SIGSEGV", "codes": "0x0000000000000001, 0x0000000000000000"},
                "usedImages": [{"name": "ModelPlan", "path": "/Users/alice/ModelPlan.app/Contents/MacOS/ModelPlan",
                                "uuid": "11111111-2222-3333-4444-555555555555"},
                               {"name": "libsystem_kernel.dylib", "path": "/usr/lib/system/libsystem_kernel.dylib"}],
                "faultingThread": 1,
                "threads": [{"frames": [{"imageIndex": 1, "imageOffset": 1}]},
                            {"frames": [{"imageIndex": 0, "imageOffset": 4096, "symbol": "Cockpit.draw", "symbolLocation": 12},
                                        {"imageIndex": 1, "imageOffset": 77, "symbol": "mach_msg"}]}]}
        return json.dumps(header) + "\n" + json.dumps(body)

    def test_redacts_identifying_text_and_keeps_crashing_frames(self):
        out = w.redact_crash_report(self.sample(), ["alice", "alices-mbp.local"])
        text = json.dumps(out)
        for leaked in ("alice", "/Users", "alices-mbp", "11111111-2222", "6F0E2C1A", "ABCDEF12", "procPath", "501"):
            self.assertNotIn(leaked, text)
        self.assertEqual(out["exceptionType"], "EXC_BAD_ACCESS")
        self.assertEqual(out["appVersion"], "1.0")
        self.assertEqual([f["symbol"] for f in out["frames"]], ["Cockpit.draw", "mach_msg"])
        self.assertEqual(out["frames"][0]["image"], "ModelPlan")
        self.assertEqual(out["frames"][0]["imageOffset"], 4096)

    def test_scrub_text_removes_paths_uuids_and_names(self):
        text = w.scrub_text("at /Users/bob/x/y.swift:3 id 11111111-2222-3333-4444-555555555555 host mac-1", ["bob", "mac-1"])
        for leaked in ("/Users", "bob", "11111111", "mac-1"):
            self.assertNotIn(leaked, text)

    def test_keep_writes_only_redacted_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, out = Path(tmp) / "alice", Path(tmp) / "out"
            reports = home / "Library/Logs/DiagnosticReports"
            reports.mkdir(parents=True)
            out.mkdir()
            (reports / (w.APP_EXECUTABLE + "-1.ips")).write_text(self.sample(), encoding="utf-8")
            w.keep_crash_reports(home, [w.APP_EXECUTABLE + "-1.ips"], out)
            files = list((out / "crash-reports").iterdir())
            self.assertEqual([f.suffix for f in files], [".json"])
            self.assertNotIn("alice", files[0].read_text(encoding="utf-8"))

    def test_spaced_and_non_ascii_names_leave_no_fragment(self):
        for name in ("John Smith", "J\u00fcrgen M\u00fcller", "\u5f20\u4f1f"):
            body = json.loads(self.sample().split("\n", 1)[1])
            body["exception"]["type"] = "crash by " + name
            body["threads"][1]["frames"][0]["symbol"] = "open %s.txt" % name
            raw = "{}\n" + json.dumps(body)
            out = w.redact_crash_report(raw, [name])
            text = json.dumps(out, ensure_ascii=False) + json.dumps(out)
            for part in [name] + name.split():
                self.assertNotIn(part, text)
            self.assertEqual(out["frames"][0]["image"], "ModelPlan")
        self.assertNotIn("Smith", w.scrub_text("hello smith", ["John Smith"]))

    def test_unparseable_report_leaves_no_raw_text(self):
        self.assertIsNone(w.redact_crash_report("not json /Users/alice"))


if __name__ == "__main__":
    unittest.main()
