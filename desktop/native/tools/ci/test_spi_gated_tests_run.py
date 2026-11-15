# SPDX-License-Identifier: MIT
"""Guard: every XCTest class in a file gated on MODELPLAN_TEST_ONLY_SPI must be compiled and run by a workflow.

Without -DMODELPLAN_TEST_ONLY_SPI the gated tests are not compiled at all, so a package whose `swift test`
never passes the flag silently loses them (CockpitControllerNoWindowTests ran nowhere until this guard).
A class is covered when some workflow step runs `swift test --package-path <its package>` with the flag
and either no --filter or a --filter regex that matches the class name.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
FLAG = "MODELPLAN_TEST_ONLY_SPI"
CLASS_RE = re.compile(r"\bclass\s+(\w+)\s*:\s*XCTestCase\b")


def gated_classes():
    out = {}
    for f in (ROOT / "desktop" / "native").rglob("*.swift"):
        parts = f.relative_to(ROOT).parts
        if "Tests" not in parts or ".build" in parts or ".tmp" in parts:
            continue
        text = f.read_text(encoding="utf-8")
        if FLAG not in text:
            continue
        pkg = next(p for p in f.parents if (p / "Package.swift").exists())
        for name in CLASS_RE.findall(text):
            out[(pkg.relative_to(ROOT).as_posix(), name)] = f.relative_to(ROOT).as_posix()
    return out


def spi_test_runs():
    """(package path, [filter regexes]) of every workflow `swift test` command that passes the flag."""
    runs = []
    for wf in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        lines = [l for l in wf.read_text(encoding="utf-8").splitlines() if not l.lstrip().startswith("#")]
        text = re.sub(r"\\\n\s*", " ", "\n".join(lines))
        for cmd in text.splitlines():
            if not re.search(r"\bswift test\b", cmd) or FLAG not in cmd or re.search(r"\bswift test list\b", cmd):
                continue
            pkg = re.search(r"--package-path\s+(\S+)", cmd)
            if pkg:
                filters = [m[0] or m[1] or m[2] for m in re.findall(r"--filter\s+(?:'([^']*)'|\"([^\"]*)\"|(\S+))", cmd)]
                runs.append((pkg.group(1).strip("'\""), filters))
    return runs


class SpiGatedTestsRunTests(unittest.TestCase):
    def test_there_are_gated_tests_and_runs(self):
        self.assertTrue(gated_classes())
        self.assertTrue(spi_test_runs())

    def test_every_gated_class_is_compiled_and_run_by_a_workflow(self):
        runs = spi_test_runs()
        missing = []
        for (pkg, name), path in sorted(gated_classes().items()):
            covered = any(p == pkg and (not fl or any(re.search(f, name) for f in fl)) for p, fl in runs)
            if not covered:
                missing.append(f"{name} ({path})")
        self.assertEqual([], missing, "SPI-gated XCTest classes no workflow compiles with -D" + FLAG)


if __name__ == "__main__":
    unittest.main()
