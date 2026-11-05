# SPDX-License-Identifier: MIT
import contextlib
import io
import tempfile
from unittest.mock import patch
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


def seam_log(test_id, message, status="skipped"):
    label = test_id.replace("/", " ")
    return (f"Test Case '-[{label}]' started.\n"
            f"Synthetic.swift:12: -[{label}] : Test skipped - {message}\n"
            f"Test Case '-[{label}]' {status} (0.001 seconds).")


class VerifyTests(unittest.TestCase):
    def setUp(self):
        _, self.expected, _ = partition.plan(PKG, LISTED, "headless")

    def test_agreed_g1_messages_pass_without_a_per_test_entry(self):
        for message in ("DOCK-3.8-09 waits for G1RenderedSnapshot",
                        "DOCK-3.6-07 SEAM-NEEDED: cockpit not wired"):
            with self.subTest(message=message), contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(partition.verify(PKG, ["Mod.Fast/testA"],
                    seam_log("Mod.Fast/testA", message), "headless"), [])
                self.assertIn("G1 seam skips: 1 (" + message.split(" ", 1)[0] + ")", output.getvalue())

    def test_random_or_malformed_skip_still_needs_its_entry(self):
        for message in ("not ready", "DOCK-3.8-09: SEAM-NEEDED something",
                        "DOCK-3.8-09 waits for G1RenderedSnapshot extra"):
            with self.subTest(message=message):
                errors = partition.verify(PKG, ["Mod.Fast/testA"],
                    seam_log("Mod.Fast/testA", message), "headless")
                self.assertTrue(any("skipped without an allowed-skip entry" in e for e in errors))

    def test_g1_message_is_bound_to_the_same_skipped_case(self):
        text = seam_log("Mod.Fast/testA", "DOCK-3.8-09 waits for G1RenderedSnapshot", "passed")
        text += "\n" + seam_log("Mod.Fast/testB", "unapproved reason")
        errors = partition.verify(PKG, ["Mod.Fast/testA", "Mod.Fast/testB"], text, "headless")
        self.assertTrue(any("testB" in e and "allowed-skip" in e for e in errors))

    def test_conflicting_skip_details_do_not_get_a_blanket_exception(self):
        text = seam_log("Mod.Fast/testA", "DOCK-3.8-09 waits for G1RenderedSnapshot")
        text += "\nSynthetic.swift:13: -[Mod.Fast testA] : Test skipped - unapproved reason"
        errors = partition.verify(PKG, ["Mod.Fast/testA"], text, "headless")
        self.assertTrue(any("skipped without an allowed-skip entry" in e for e in errors))

    def test_cap_counts_cases_not_unique_requirement_ids_and_includes_boundary(self):
        ids = [f"Mod.Fast/testSeam{i}" for i in range(121)]
        text = lambda cases: "\n".join(seam_log(i, "DOCK-3.8-09 waits for G1RenderedSnapshot") for i in cases)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(partition.verify(PKG, ids[:120], text(ids[:120]), "headless"), [])
            self.assertTrue(any("cap exceeded: 121 > 120" in e for e in partition.verify(PKG, ids, text(ids), "headless")))

    def test_g1_skip_cap_trips_even_for_per_test_allowed_cases(self):
        # Coordinator budget is 120; the 121st skipped case is never silently accepted.
        ids = [f"Mod.Fast/testSeam{i}" for i in range(121)]
        pkg = {**PKG, "allowedSkips": {i.split(".", 1)[1]: {"leg": "headless", "reason": "synthetic"} for i in ids}}
        text = "\n".join(seam_log(i, f"DOCK-3.8-{n:02d} waits for G1RenderedSnapshot") for n, i in enumerate(ids))
        with contextlib.redirect_stdout(io.StringIO()) as output:
            errors = partition.verify(pkg, ids, text, "headless")
        self.assertTrue(any("G1 seam skip cap exceeded: 121 > 120" in e for e in errors))
        self.assertIn("G1 seam skips: 121 (", output.getvalue())

    def test_cli_counts_g1_as_skipped_never_as_passed(self):
        pkg = {**PKG, "allowedSkips": {}}
        with tempfile.TemporaryDirectory() as tmp:
            listed = Path(tmp) / "listed.txt"; observed = Path(tmp) / "observed.log"
            listed.write_text("Mod.Fast/testA\nMod.Window/testC\n")
            observed.write_text(seam_log("Mod.Fast/testA", "DOCK-3.8-09 waits for G1RenderedSnapshot"))
            with patch.object(partition, "load_manifest", return_value={"packages": {"p": pkg}}), contextlib.redirect_stdout(io.StringIO()) as output:
                code = partition.main(["verify", "--package", "p", "--leg", "headless", "--list", str(listed), "--log", str(observed)])
            self.assertEqual(code, 0)
            self.assertIn("G1 seam skips: 1 (DOCK-3.8-09)", output.getvalue())
            self.assertIn("0 passed, 1 skipped", output.getvalue())

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
