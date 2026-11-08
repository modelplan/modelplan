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

    def test_codex_reading_binds_the_granted_consent(self):
        value = w.codex_reading(self.SEED, self.NOW, {"storeEpoch": "e", "generation": 3})
        self.assertEqual(value["admission"], {"storeEpoch": "e", "generation": 3, "scope": "codex.runtime_usage"})
        self.assertEqual(value["windows"][0]["usedPercent"], 37)

    def test_child_gets_the_synthetic_home_and_nothing_else_of_the_runner(self):
        env = w.child_environment(Path("profile"))
        self.assertEqual(set(env), {"HOME", "CFFIXED_USER_HOME", "TMPDIR", "PATH", "LANG"})
        self.assertEqual(env["HOME"], env["CFFIXED_USER_HOME"])


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
                         "card-empty-quota", "cockpit-toggle-close", "cockpit-reopen", "shutter-closed", "cockpit-detach",
                         "cockpit-drag-title", "help-map", "air-1440x900", "air-1470x956"} <= ids)

    def test_the_seed_has_a_ring_at_zero(self):
        seed = json.loads((ROOT / "seed.json").read_text(encoding="utf-8"))
        self.assertIn(0, [p["remainingPercent"] for p in seed["declared"]])

    def test_every_check_kind_is_known(self):
        known = {"differsFrom", "matches", "exists", "opened", "absent", "checked", "on", "moved", "changed", "cardNamed",
                 "collapsed", "allOnScreen", "fits", "newWindow", "noNewWindow", "windowClosed", "nonblank"}
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

    def test_unparseable_report_leaves_no_raw_text(self):
        self.assertIsNone(w.redact_crash_report("not json /Users/alice"))


if __name__ == "__main__":
    unittest.main()
