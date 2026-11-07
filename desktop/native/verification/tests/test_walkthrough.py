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
            for action in step.get("actions", []):
                self.assertTrue(hasattr(w.Walkthrough, "op_" + action["op"]), action["op"])

    def test_covers_the_agreed_walkthrough(self):
        ids = {s["id"] for s in self.STEPS}
        self.assertTrue({"widget-rest", "widget-hover", "popup-card", "drag-snap", "status-menu-right", "ring-centred-on",
                         "ring-centred-off", "first-use-hint", "cockpit-open", "porthole-enlarged", "hud-select", "faders"} <= ids)


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

    def test_a_failed_action_is_still_photographed_and_blocks_dependents(self):
        steps = [{"id": "a", "title": "t", "expected": "e", "actions": [{"op": "click", "target": "ax:gone"}]},
                 {"id": "b", "title": "t", "expected": "e", "requires": ["a"]}]
        first, second = walker(FakeHost(), self.out, steps).walk_steps()
        self.assertEqual(first["status"], "fail")
        self.assertIn("ax:gone", first["reason"])
        self.assertTrue((self.out / first["file"]).exists())
        self.assertEqual((second["status"], second["file"]), ("not-run", None))
        self.assertEqual(second["reason"], "needs a")

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


class Guard(unittest.TestCase):
    def test_refuses_to_post_input_outside_a_hosted_runner(self):
        args = argparse.Namespace(out="unused", home="unused", app="unused")
        with mock.patch.dict(os.environ, {"RUNNER_ENVIRONMENT": "self-hosted"}):
            with self.assertRaises(SystemExit):
                w.run(args, FakeHost())


if __name__ == "__main__":
    unittest.main()
