#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Split the native XCTest suite between the GUI runner and an ordinary runner.

The manifest (native-test-partition.json) lists the test classes that are proven not to need a
window server ("headless"). Everything else, including every new class, stays on the GUI leg, so
the conservative default is the slow leg, never the unsafe one.

  check   static rules for the manifest against the test sources (Linux CI and both Mac legs)
  plan    from `swift test list`, write the exact swift-test arguments and expected test IDs of a leg
  verify  from the leg's XCTest log, require executed IDs == expected IDs and audit every skip

Because `plan` derives both legs from the same listed suite (headless = listed & manifest,
gui = listed - headless) and `verify` requires each leg to execute exactly its own set, a green
pair of legs proves the union is the whole suite and nothing ran twice or not at all.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

MANIFEST = Path(__file__).with_name("native-test-partition.json")
LEGS = ("gui", "headless")
CLASS_RE = re.compile(r"\bclass\s+(\w+)\s*:\s*XCTestCase\b")
CASE_RE = re.compile(r"Test Case '-\[(\w+)\.(\w+) (\w+)\]' (passed|failed|skipped)")


class PartitionError(Exception):
    pass


def load_manifest(path: Path = MANIFEST) -> dict:
    manifest = json.loads(path.read_text())
    if manifest.get("schemaVersion") != 1:
        raise PartitionError("unsupported partition manifest schemaVersion")
    return manifest


def package(manifest: dict, key: str) -> dict:
    try:
        return manifest["packages"][key]
    except KeyError:
        raise PartitionError(f"unknown package {key!r}") from None


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def call_spans(text: str, start: int) -> str:
    """Return the argument text of the call whose '(' is at text[start - 1]."""
    depth, i = 1, start
    while i < len(text) and depth:
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
        i += 1
    return text[start:i - 1]


def source_classes(root: Path, pkg: dict) -> dict[str, Path]:
    found: dict[str, Path] = {}
    for file in sorted((root / pkg["testSources"]).rglob("*.swift")):
        for name in CLASS_RE.findall(file.read_text()):
            if name in found:
                raise PartitionError(f"test class {name} is declared twice ({found[name]} and {file})")
            found[name] = file
    return found


def file_problems(text: str, manifest: dict) -> list[str]:
    code = strip_comments(text)
    problems = [f"window-server API {m.group(0)!r}" for marker in manifest["windowServerMarkers"]
                for m in [re.search(marker, code)] if m]
    for factory in manifest["panelFactories"]:
        for m in re.finditer(factory, code):
            args = call_spans(code, m.end())
            if not re.search(r"createsNativePanels\s*:\s*false\b", args):
                problems.append(f"{m.group(0)!r} without createsNativePanels: false")
    return problems


def check(root: Path, manifest: dict) -> list[str]:
    errors: list[str] = []
    for key, pkg in manifest["packages"].items():
        classes = source_classes(root, pkg)
        headless = pkg["headless"]
        if len(set(headless)) != len(headless):
            errors.append(f"{key}: duplicate headless class")
        if headless != sorted(headless):
            errors.append(f"{key}: keep the headless list sorted")
        for name in headless:
            file = classes.get(name)
            if file is None:
                errors.append(f"{key}: headless class {name} has no XCTestCase declaration")
                continue
            text = file.read_text()
            if re.search(r"^\s*#if\b", text, flags=re.M):
                errors.append(f"{key}: headless class {name} is conditionally compiled; it would vanish from the listed suite")
            errors += [f"{key}: {name} ({file.relative_to(root)}): {p}" for p in file_problems(text, manifest)]
        for test_id, rule in pkg.get("allowedSkips", {}).items():
            name = test_id.split("/")[0]
            if name not in classes:
                errors.append(f"{key}: allowed skip {test_id} names no test class")
            leg = "headless" if name in headless else "gui"
            if rule.get("leg") != leg:
                errors.append(f"{key}: allowed skip {test_id} must name its own leg {leg!r}")
            if not rule.get("reason"):
                errors.append(f"{key}: allowed skip {test_id} needs a reason")
    return errors


def listed_ids(text: str, module: str) -> list[str]:
    ids = [line.strip() for line in text.splitlines() if re.fullmatch(r"\w+\.\w+/\w+", line.strip())]
    if not any(i.startswith(module + ".") for i in ids):
        raise PartitionError(f"`swift test list` output names no {module} tests")
    return ids


def class_regex(module: str, names: list[str]) -> str:
    return "^" + re.escape(module) + r"\.(" + "|".join(map(re.escape, names)) + ")/"


def plan(pkg: dict, listed: list[str], leg: str) -> tuple[list[str], list[str], dict]:
    if leg not in LEGS:
        raise PartitionError(f"unknown leg {leg!r}")
    module, headless = pkg["testModule"], pkg["headless"]
    suite = [i for i in listed if not any(re.search(s, i) for s in pkg.get("preexistingSkip", []))]
    present = {i.split("/")[0] for i in suite}
    missing = [n for n in headless if f"{module}.{n}" not in present]
    if missing:
        raise PartitionError("headless classes absent from the listed suite: " + ", ".join(missing))
    selector = class_regex(module, headless)
    expected_headless = [i for i in suite if re.search(selector, i)]
    expected_gui = [i for i in suite if not re.search(selector, i)]
    assert sorted(expected_headless + expected_gui) == sorted(suite)
    assert not set(expected_headless) & set(expected_gui)
    if not expected_headless or not expected_gui:
        raise PartitionError("both legs must run at least one test")
    args = [a for s in pkg.get("preexistingSkip", []) for a in ("--skip", s)]
    args += ["--filter", selector] if leg == "headless" else ["--skip", selector]
    summary = {"suite": len(suite), "gui": len(expected_gui), "headless": len(expected_headless)}
    return args, (expected_headless if leg == "headless" else expected_gui), summary


def verify(pkg: dict, expected: list[str], log: str, leg: str) -> list[str]:
    executed: dict[str, str] = {}
    errors: list[str] = []
    for module, name, method, status in CASE_RE.findall(log):
        test_id = f"{module}.{name}/{method}"
        if test_id in executed:
            errors.append(f"{test_id} reported twice")
        executed[test_id] = status
    for test_id in sorted(set(expected) - set(executed)):
        errors.append(f"expected on the {leg} leg but not executed: {test_id}")
    for test_id in sorted(set(executed) - set(expected)):
        errors.append(f"executed on the {leg} leg but belongs to the other leg or is excluded: {test_id}")
    allowed = pkg.get("allowedSkips", {})
    for test_id, status in sorted(executed.items()):
        if status == "failed":
            errors.append(f"failed: {test_id}")
        if status == "skipped":
            rule = allowed.get(test_id.split(".", 1)[1])
            if not rule or rule["leg"] != leg:
                errors.append(f"skipped without an allowed-skip entry for the {leg} leg: {test_id}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    c = sub.add_parser("check")
    c.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[4])
    for name in ("plan", "verify"):
        p = sub.add_parser(name)
        p.add_argument("--package", required=True)
        p.add_argument("--leg", required=True, choices=LEGS)
        p.add_argument("--list", required=True, type=Path, help="`swift test list` output")
        if name == "plan":
            p.add_argument("--args", required=True, type=Path, help="write swift test arguments, one per line")
        else:
            p.add_argument("--log", required=True, type=Path, help="the leg's swift test output")
    ns = parser.parse_args(argv)
    try:
        manifest = load_manifest()
        if ns.command == "check":
            errors = check(ns.root, manifest)
            if errors:
                print("\n".join(errors), file=sys.stderr)
                return 1
            for key, pkg in manifest["packages"].items():
                total = len(source_classes(ns.root, pkg))
                print(f"{key}: {len(pkg['headless'])} headless classes, {total - len(pkg['headless'])} GUI-leg classes")
            return 0
        pkg = package(manifest, ns.package)
        listed = listed_ids(ns.list.read_text(), pkg["testModule"])
        args, expected, summary = plan(pkg, listed, ns.leg)
        if ns.command == "plan":
            ns.args.write_text("".join(a + "\n" for a in args))
            print(json.dumps({"leg": ns.leg, **summary}))
            return 0
        errors = verify(pkg, expected, ns.log.read_text(errors="replace"), ns.leg)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print(f"{ns.leg} leg executed exactly its {len(expected)} of {summary['suite']} tests")
        return 0
    except PartitionError as error:
        print(f"partition: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
