# SPDX-License-Identifier: MIT
import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import gui_test_selection as selection
import native_test_partition as partition

TESTS = "desktop/native/ModelPlanAppIntegration/Tests/ModelPlanAppIntegrationTests"
MANIFEST = {
    "schemaVersion": 1,
    "packages": {"app-integration": {
        "packagePath": "desktop/native/ModelPlanAppIntegration",
        "testModule": "ModelPlanAppIntegrationTests",
        "testSources": TESTS,
        "preexistingSkip": [],
        "headless": ["FastTests"],
        "ownerGui": [],
        "allowedSkips": {},
    }},
}
FILES = {
    "desktop/native/ModelPlanAppIntegration/Package.swift":
        'let package = Package(dependencies: [\n  // .package(url: "https://example.com/old", from: "1.0.0"),\n  .package(path: "../Lib"),\n])\n',
    "desktop/native/Lib/Package.swift": "let package = Package(name: \"Lib\")\n",
    "desktop/native/Lib/Sources/Lib/Widget.swift": "public struct Widget {}\nprivate func widgetSecret() {}\n",
    "desktop/native/Lib/Sources/Lib/Orphan.swift": "public struct Orphan {}\n",
    "desktop/native/Lib/Sources/Lib/Hidden.swift": "private struct Hidden {}\n",
    "desktop/native/Lib/Sources/Lib/Common.swift": "public enum Common {}\n",
    "desktop/native/Lib/Sources/Lib/Resources/data.json": "{}\n",
    "desktop/native/Lib/Tests/LibTests/LibTests.swift": "final class LibTests: XCTestCase {}\n",
    "desktop/native/Lib/README.md": "notes\n",
    "desktop/native/verification/bin/drive.py": "print()\n",
    f"{TESTS}/WidgetTests.swift": "final class WidgetTests: XCTestCase { func testA() { _ = Widget(); _ = Common.self } }\n",
    f"{TESTS}/WidgetTests+More.swift": "extension WidgetTests { func testB() {} }\n",
    f"{TESTS}/FastTests.swift": "final class FastTests: XCTestCase { func testA() { _ = Widget() } }\n",
    f"{TESTS}/WindowTests.swift":
        'final class WindowTests: XCTestCase {\n  let p = "../../../../../schema/app-cli/captures"\n'
        '  let n = "CLI-NOTICES.md"\n  func testA() { makeHelper(); _ = Common.self }\n}\n',
    f"{TESTS}/Support.swift": "func makeHelper() {}\nprivate func local() {}\n",
    f"{TESTS}/Unused.swift": "func neverUsed() {}\n",
    f"{TESTS}/Fixtures/rows.json": "{}\n",
    **{f"{TESTS}/Filler{i}Tests.swift": f"final class Filler{i}Tests: XCTestCase {{ func testA() {{ _ = Common.self }} }}\n"
       for i in range(1, 7)},
    **{f"{TESTS}/Plain{i}Tests.swift": f"final class Plain{i}Tests: XCTestCase {{ func testA() {{}} }}\n" for i in range(1, 6)},
}


class SelectTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="d169-selection-")
        self.root = Path(self.tmp.name)
        for rel, text in FILES.items():
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.root / rel).write_text(text)

    def tearDown(self):
        self.tmp.cleanup()

    def pick(self, *changed):
        with contextlib.redirect_stderr(io.StringIO()):
            mode, classes = selection.select(list(changed), self.root, MANIFEST)
        return selection.render(mode, classes)

    def test_ci_package_and_test_infrastructure_select_the_full_suite(self):
        for path in [".github/workflows/desktop.yml", ".github/workflows/trusted-mac.yml",
                     "desktop/native/Lib/Package.swift", "desktop/native/Package.resolved",
                     "desktop/native/tools/ci/native-test-partition.json", "desktop/native/tools/ci/gui_test_selection.py",
                     f"{TESTS}/Fixtures/rows.json"]:
            self.assertEqual(self.pick(path), "full", path)
        # One full trigger anywhere in the change wins over a narrow selection.
        self.assertEqual(self.pick(f"{TESTS}/WidgetTests.swift", ".github/workflows/ci.yml"), "full")

    def test_changed_test_file_selects_its_own_classes_and_classes_it_extends(self):
        self.assertEqual(self.pick(f"{TESTS}/WidgetTests.swift"), "WidgetTests")
        self.assertEqual(self.pick(f"{TESTS}/WidgetTests+More.swift"), "WidgetTests")
        self.assertEqual(self.pick(f"{TESTS}/WindowTests.swift", f"{TESTS}/Plain1Tests.swift"), "Plain1Tests,WindowTests")

    def test_headless_classes_are_never_selected_for_the_gui_leg(self):
        self.assertEqual(self.pick(f"{TESTS}/FastTests.swift"), "none")
        self.assertEqual(self.pick("desktop/native/Lib/Sources/Lib/Widget.swift"), "WidgetTests")

    def test_shared_test_support_selects_its_users_or_the_full_suite(self):
        self.assertEqual(self.pick(f"{TESTS}/Support.swift"), "WindowTests")
        self.assertEqual(self.pick(f"{TESTS}/Unused.swift"), "full")

    def test_source_files_select_the_classes_naming_their_declarations(self):
        self.assertEqual(self.pick("desktop/native/Lib/Sources/Lib/Widget.swift"), "WidgetTests")
        # Reached only indirectly, or declares only private names: unsure, so the full suite.
        self.assertEqual(self.pick("desktop/native/Lib/Sources/Lib/Orphan.swift"), "full")
        self.assertEqual(self.pick("desktop/native/Lib/Sources/Lib/Hidden.swift"), "full")
        # Named by most GUI classes: a selection would save little.
        self.assertEqual(self.pick("desktop/native/Lib/Sources/Lib/Common.swift"), "full")

    def test_deleted_swift_files_and_non_swift_graph_files_select_the_full_suite(self):
        self.assertEqual(self.pick("desktop/native/Lib/Sources/Lib/Gone.swift"), "full")
        self.assertEqual(self.pick(f"{TESTS}/GoneTests.swift"), "full")
        self.assertEqual(self.pick("desktop/native/Lib/Sources/Lib/Resources/data.json"), "full")

    def test_paths_outside_the_graph_select_only_the_classes_that_spell_them(self):
        self.assertEqual(self.pick("desktop/app/main.ts", "cli/internal/x.go", "docs/a.md"), "none")
        self.assertEqual(self.pick("schema/app-cli/captures/WireRowsSnapshot.json"), "WindowTests")
        self.assertEqual(self.pick("codex/CLI-NOTICES.md"), "WindowTests")
        # Whole path components only: a look-alike directory is not named.
        self.assertEqual(self.pick("schema/app-cli/captures-old/x.json"), "none")

    def test_docs_scripts_and_other_targets_tests_inside_the_graph_select_nothing(self):
        self.assertEqual(self.pick("desktop/native/Lib/README.md"), "none")
        self.assertEqual(self.pick("desktop/native/verification/bin/drive.py"), "none")
        self.assertEqual(self.pick("desktop/native/Lib/Tests/LibTests/LibTests.swift"), "none")

    def test_empty_or_oversized_changes_select_the_full_suite(self):
        self.assertEqual(self.pick(), "full")
        self.assertEqual(self.pick(*[f"desktop/app/f{i}.ts" for i in range(selection.MAX_CHANGED + 1)]), "full")

    def test_a_remote_package_dependency_makes_the_cli_print_full(self):
        manifest = self.root / "desktop/native/Lib/Package.swift"
        manifest.write_text('let package = Package(dependencies: [.package(url: "https://example.com/x", from: "1.0.0")])\n')
        with self.assertRaises(partition.PartitionError):
            selection.package_graph(self.root)

    def test_the_real_tree_has_a_resolvable_graph_and_suite(self):
        graph = selection.package_graph(selection.ROOT)
        self.assertIn("desktop/native", graph)
        self.assertIn("desktop/native/ModelPlanAppIntegration", graph)
        suite = selection.Suite(selection.ROOT, partition.load_manifest())
        self.assertGreater(len(suite.gui), 10)
        changed = Path(self.tmp.name) / "changed.txt"
        changed.write_text(".github/workflows/desktop.yml\n")
        out = subprocess.run([sys.executable, str(Path(selection.__file__)), "select", "--changed", str(changed)],
                             capture_output=True, text=True, check=True)
        self.assertEqual(out.stdout, "full\n")


class OnlyTests(unittest.TestCase):
    PKG = {"testModule": "Mod", "testSources": "Tests", "preexistingSkip": ["GeneratedPortTests"], "headless": ["Fast"],
           "ownerGui": ["Owner"], "allowedSkips": {}}
    LISTED = ["Mod.Fast/testA", "Mod.Window/testB", "Mod.Window/testC", "Mod.Other/testD", "Mod.Owner/testE",
              "Contract.GeneratedPortTests/testF"]

    def test_parse_only_accepts_full_none_and_class_lists_only(self):
        self.assertIsNone(partition.parse_only(None))
        self.assertIsNone(partition.parse_only("full"))
        self.assertEqual(partition.parse_only("none"), [])
        self.assertEqual(partition.parse_only("Window,Fast,Window"), ["Fast", "Window"])
        for bad in ["", "Window;rm -rf /", "Window,", "a b", ".*", "Window|Other", "--skip"]:
            with self.assertRaises(partition.PartitionError, msg=bad):
                partition.parse_only(bad)

    def test_only_narrows_a_leg_to_its_own_share_of_the_selection(self):
        args, expected, summary = partition.plan(self.PKG, self.LISTED, "gui", ["Window", "Fast", "Owner"])
        self.assertEqual(expected, ["Mod.Window/testB", "Mod.Window/testC", "Mod.Owner/testE"])
        self.assertEqual(args, ["--skip", "GeneratedPortTests", "--filter", r"^Mod\.(Owner|Window)/"])
        self.assertEqual(summary["selectedClasses"], 2)
        _, hosted, _ = partition.plan(self.PKG, self.LISTED, "hosted-gui", ["Window", "Owner"])
        _, owner, _ = partition.plan(self.PKG, self.LISTED, "owner-gui", ["Window", "Owner"])
        self.assertEqual(hosted, ["Mod.Window/testB", "Mod.Window/testC"])
        self.assertEqual(owner, ["Mod.Owner/testE"])

    def test_only_never_widens_and_an_empty_share_writes_no_arguments(self):
        args, expected, _ = partition.plan(self.PKG, self.LISTED, "gui", ["Fast", "NotCompiled"])
        self.assertEqual((args, expected), ([], []))
        args, expected, _ = partition.plan(self.PKG, self.LISTED, "gui", [])
        self.assertEqual((args, expected), ([], []))
        # The full share always has arguments, so an empty argument file can only mean a narrowed leg.
        args, _, _ = partition.plan(self.PKG, self.LISTED, "gui", None)
        self.assertTrue(args)

    def test_verify_requires_exactly_the_narrowed_share(self):
        _, expected, _ = partition.plan(self.PKG, self.LISTED, "gui", ["Window"])
        ok = "\n".join(f"Test Case '-[Mod.Window {m}]' passed (0.1 seconds)." for m in ("testB", "testC"))
        self.assertEqual(partition.verify(self.PKG, expected, ok, "gui"), [])
        extra = ok + "\nTest Case '-[Mod.Other testD]' passed (0.1 seconds)."
        self.assertTrue(partition.verify(self.PKG, expected, extra, "gui"))
        self.assertTrue(partition.verify(self.PKG, expected, ok.split("\n")[0], "gui"))


if __name__ == "__main__":
    unittest.main()
