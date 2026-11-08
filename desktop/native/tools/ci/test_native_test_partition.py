# SPDX-License-Identifier: MIT
import tempfile
import unittest
from pathlib import Path

import native_test_partition as partition

ROOT = Path(__file__).resolve().parents[4]
MANIFEST = partition.load_manifest()
PKG = {
    "testModule": "Mod",
    "testSources": "Tests",
    "preexistingSkip": ["GeneratedPortTests"],
    "headless": ["Fast"],
    "allowedSkips": {"Fast/testEnvGated": {"leg": "headless", "reason": "synthetic"},
                     "Window/testHostedOnly": {"leg": "gui", "reason": "synthetic"}},
}
LISTED = ["Mod.Fast/testA", "Mod.Fast/testEnvGated", "Mod.FastLater/testB", "Mod.Window/testC",
          "Mod.Window/testHostedOnly", "Contract.GeneratedPortTests/testD"]


def log(cases):
    return "\n".join(f"Test Case '-[{c.replace('/', ' ')}]' {s} (0.001 seconds)." for c, s in cases)


class PlanTests(unittest.TestCase):
    def test_legs_partition_the_listed_suite_exactly(self):
        _, gui, summary = partition.plan(PKG, LISTED, "gui")
        _, headless, _ = partition.plan(PKG, LISTED, "headless")
        self.assertEqual(headless, ["Mod.Fast/testA", "Mod.Fast/testEnvGated"])
        # Prefix look-alikes and new classes stay on the GUI leg; pre-existing exclusions run nowhere.
        self.assertEqual(gui, ["Mod.FastLater/testB", "Mod.Window/testC", "Mod.Window/testHostedOnly"])
        self.assertEqual(summary, {"suite": 5, "gui": 3, "headless": 2})

    def test_both_legs_use_one_selector_as_filter_and_skip(self):
        gui_args, _, _ = partition.plan(PKG, LISTED, "gui")
        headless_args, _, _ = partition.plan(PKG, LISTED, "headless")
        self.assertEqual(gui_args, ["--skip", "GeneratedPortTests", "--skip", r"^Mod\.(Fast)/"])
        self.assertEqual(headless_args, ["--skip", "GeneratedPortTests", "--filter", r"^Mod\.(Fast)/"])

    def test_stale_headless_class_fails(self):
        with self.assertRaisesRegex(partition.PartitionError, "Gone"):
            partition.plan({**PKG, "headless": ["Fast", "Gone"]}, LISTED, "headless")

    def test_list_parser_ignores_build_noise(self):
        text = "Building for debugging...\n[3/4] Compiling\nMod.Fast/testA\nBuild complete!\n"
        self.assertEqual(partition.listed_ids(text, "Mod"), ["Mod.Fast/testA"])
        with self.assertRaises(partition.PartitionError):
            partition.listed_ids("Build complete!\n", "Mod")


class VerifyTests(unittest.TestCase):
    def setUp(self):
        _, self.expected, _ = partition.plan(PKG, LISTED, "headless")

    def test_exact_execution_passes(self):
        text = log([("Mod.Fast/testA", "passed"), ("Mod.Fast/testEnvGated", "skipped")])
        self.assertEqual(partition.verify(PKG, self.expected, text, "headless"), [])

    def test_missing_extra_failed_and_unlisted_skips_fail(self):
        text = log([("Mod.Fast/testA", "skipped"), ("Mod.Window/testC", "passed")])
        errors = partition.verify(PKG, self.expected, text, "headless")
        self.assertTrue(any("not executed: Mod.Fast/testEnvGated" in e for e in errors))
        self.assertTrue(any("belongs to the other leg" in e and "Window/testC" in e for e in errors))
        self.assertTrue(any("skipped without an allowed-skip entry" in e and "Fast/testA" in e for e in errors))
        self.assertTrue(any("failed: Mod.Fast/testA" in e for e in
                            partition.verify(PKG, self.expected, log([("Mod.Fast/testA", "failed"), ("Mod.Fast/testEnvGated", "passed")]), "headless")))

    def test_repository_admits_only_the_cli_missing_headless_skip(self):
        pkg = MANIFEST["packages"]["app-integration"]
        case = "ModelPlanAppIntegrationTests.CommunityCockpitEntryTests/testNormalEntryRejectsOutdatedCLI"
        self.assertEqual(partition.verify(pkg, [case], log([(case, "skipped")]), "headless"), [])
        self.assertTrue(any("skipped without an allowed-skip entry" in e for e in
                            partition.verify(pkg, [case], log([(case, "skipped")]), "gui")))

    def test_a_skip_allowed_on_the_other_leg_is_not_allowed_here(self):
        pkg = {**PKG, "headless": ["Fast", "Window"]}
        _, expected, _ = partition.plan(pkg, LISTED, "headless")
        text = log([(i, "skipped" if i.endswith("HostedOnly") else "passed") for i in expected])
        self.assertTrue(any("HostedOnly" in e for e in partition.verify(pkg, expected, text, "headless")))


class CheckTests(unittest.TestCase):
    def run_check(self, source):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "Tests").mkdir()
            (Path(tmp) / "Tests" / "Fast.swift").write_text(source)
            manifest = {**MANIFEST, "packages": {"p": {**PKG, "allowedSkips": {}}}}
            return partition.check(Path(tmp), manifest)

    def test_window_server_api_in_a_headless_class_fails(self):
        self.assertEqual(self.run_check("final class Fast: XCTestCase { func testA() {} }"), [])
        for api in ("_ = NSApplication.shared", "let w = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)",
                    "panel.orderFrontRegardless()", "NSStatusBar.system.thickness", "NSScreen.main"):
            self.assertTrue(self.run_check(f"final class Fast: XCTestCase {{ func testA() {{ {api} }} }}"), api)

    def test_comments_do_not_count(self):
        self.assertEqual(self.run_check("// No orderFront or NSWindow( here.\nfinal class Fast: XCTestCase {}"), [])

    def test_factories_must_opt_out_of_native_panels(self):
        ok = "final class Fast: XCTestCase { func t() { EngineRowsEntry.make(configuration: .init(a: f(1)),\n settingsStore: s, createsNativePanels: false) } }"
        bad = "final class Fast: XCTestCase { func t() { EngineRowsEntry.make(configuration: .init(a: f(1)), settingsStore: s) } }"
        self.assertEqual(self.run_check(ok), [])
        self.assertTrue(any("createsNativePanels" in e for e in self.run_check(bad)))

    def test_conditionally_compiled_headless_class_fails(self):
        self.assertTrue(any("conditionally" in e for e in self.run_check("#if DRIVE\nfinal class Fast: XCTestCase {}\n#endif")))

    def test_repository_manifest_passes(self):
        self.assertEqual(partition.check(ROOT, MANIFEST), [])


if __name__ == "__main__":
    unittest.main()


OWNER = {**PKG, "ownerGui": ["Window"],
         "allowedSkips": {**PKG["allowedSkips"], "FastLater/testOwnerOnly": {"leg": "gui", "reason": "synthetic"}}}


class OwnerGuiTests(unittest.TestCase):
    """D62: the GUI share splits into a hosted part and the classes that need the owner's GUI Mac."""

    def test_hosted_and_owner_legs_split_the_gui_share_exactly(self):
        _, gui, _ = partition.plan(OWNER, LISTED, "gui")
        _, hosted, summary = partition.plan(OWNER, LISTED, "hosted-gui")
        _, owner, _ = partition.plan(OWNER, LISTED, "owner-gui")
        self.assertEqual(owner, ["Mod.Window/testC", "Mod.Window/testHostedOnly"])
        self.assertEqual(hosted, ["Mod.FastLater/testB"])
        self.assertEqual(sorted(hosted + owner), gui)
        self.assertEqual(summary["owner-gui"], 2)

    def test_owner_and_hosted_legs_use_one_selector(self):
        hosted, _, _ = partition.plan(OWNER, LISTED, "hosted-gui")
        owner, _, _ = partition.plan(OWNER, LISTED, "owner-gui")
        self.assertEqual(hosted, ["--skip", "GeneratedPortTests", "--skip", r"^Mod\.(Fast)/", "--skip", r"^Mod\.(Window)/"])
        self.assertEqual(owner, ["--skip", "GeneratedPortTests", "--filter", r"^Mod\.(Window)/"])

    def test_no_owner_list_means_no_owner_leg(self):
        with self.assertRaises(partition.PartitionError):
            partition.plan(PKG, LISTED, "owner-gui")
        _, hosted, _ = partition.plan(PKG, LISTED, "hosted-gui")
        _, gui, _ = partition.plan(PKG, LISTED, "gui")
        self.assertEqual(hosted, gui)

    def test_gui_skips_count_on_both_halves_of_the_gui_share(self):
        _, owner, _ = partition.plan(OWNER, LISTED, "owner-gui")
        self.assertEqual([], partition.verify(OWNER, owner, log([("Mod.Window/testC", "passed"), ("Mod.Window/testHostedOnly", "skipped")]), "owner-gui"))
        _, hosted, _ = partition.plan(OWNER, LISTED, "hosted-gui")
        self.assertEqual([], partition.verify(OWNER, hosted, log([("Mod.FastLater/testB", "passed")]), "hosted-gui"))

    def test_owner_list_rules(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / "Tests").mkdir()
            (root / "Tests/A.swift").write_text("class Fast: XCTestCase {}\nclass Window: XCTestCase {}\nclass Other: XCTestCase {}\n")
            manifest = {**MANIFEST, "packages": {"m": {**OWNER, "allowedSkips": {}, "ownerGui": ["Window", "Fast"]}}}
            errors = partition.check(root, manifest)
            self.assertTrue(any("ownerGui" in e and "sorted" in e for e in errors), errors)
            self.assertTrue(any("both headless and ownerGui" in e for e in errors), errors)
            manifest["packages"]["m"]["ownerGui"] = ["Missing"]
            self.assertTrue(any("ownerGui class Missing" in e for e in partition.check(root, manifest)))
