#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Pick the GUI-leg XCTest classes a change is related to (owner D169).

A pull request's GUI leg runs only the app-integration GUI classes related to the files the branch
changed; the merge queue and the nightly main run always run the whole GUI share (trusted-mac.yml
forces it for every event except a branch dispatch). This is a speed-up for the PR round, not the
merge gate: anything this selector misses is still caught before the change reaches main.

The selection is conservative. Any path it cannot place is a reason to run the full GUI share:

  full   CI/workflow files, any Package.swift/Package.resolved, the partition and this selector,
         the test target's fixtures, a deleted Swift file, a non-Swift file inside the Swift package
         graph (resources, data), a Swift file whose declarations no GUI class names, or a
         selection that would cover most of the GUI share anyway, an empty change
  classes  the GUI classes declared in (or extended by) a changed test file, the GUI classes whose
         test files name a top-level declaration of a changed Swift file, and the GUI classes whose
         test files spell a repository path or file name that a changed path matches
  none   only paths outside the Swift package graph that no GUI test file names, Markdown inside
         it, tests of other targets and the verification/tooling scripts (they run in their own
         steps, whole, on every leg)

Usage: gui_test_selection.py select --changed <file with one path per line> [--root <repo>]
prints one line: "full", "none" or a comma-separated class list, and the reasons on stderr.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import native_test_partition as partition

ROOT = Path(__file__).resolve().parents[4]
PACKAGE_KEY = "app-integration"
# The package whose test target the GUI leg runs; its Package.swift path dependencies span the graph.
GRAPH_ROOT = "desktop/native/ModelPlanAppIntegration"
FULL_PATTERNS = (
    re.compile(r"^\.github/"),
    re.compile(r"(^|/)Package\.(swift|resolved)$"),
    re.compile(r"^desktop/native/tools/ci/"),
    re.compile(r"^desktop/native/ModelPlanAppIntegration/Tests/ModelPlanAppIntegrationTests/Fixtures/"),
)
# Python/Node/shell tooling inside desktop/native runs in its own steps, not inside the XCTest classes.
SCRIPT = re.compile(r"^desktop/native/(verification|tools)/.*\.(py|mjs|sh)$")
# Above this share of the GUI classes a selection saves little: run the whole share instead.
FULL_SHARE = 0.6
MAX_CHANGED = 300
TOP_LEVEL_DECL = re.compile(
    r"^(?:@\w+(?:\([^)\n]*\))?\s+)*"
    r"((?:(?:public|internal|package|open|final|private|fileprivate|nonisolated|indirect|static)\s+)*)"
    r"(class|struct|enum|protocol|actor|extension|typealias|func|let|var)\s+([A-Za-z_]\w*)",
    re.M)
STRING_LITERAL = re.compile(r'"([^"\\\n]*)"')


def package_graph(root: Path, start: str = GRAPH_ROOT) -> list[str]:
    """Repository-relative directories of the Swift packages the GUI leg builds (path dependencies only)."""
    seen: list[Path] = []
    todo = [(root / start).resolve()]
    while todo:
        directory = todo.pop()
        if directory in seen:
            continue
        seen.append(directory)
        manifest = directory / "Package.swift"
        if not manifest.is_file():
            raise partition.PartitionError(f"no Package.swift in {directory}")
        # Only whole-line and block comments: a URL's "//" must not hide a remote dependency.
        text = re.sub(r"^\s*//[^\n]*", "", re.sub(r"/\*.*?\*/", "", manifest.read_text(), flags=re.S), flags=re.M)
        for call in re.finditer(r"\.package\(([^)]*)\)", text):
            path = re.search(r'path:\s*"([^"]+)"', call.group(1))
            if path:
                todo.append((directory / path.group(1)).resolve())
            elif "url:" in call.group(1):
                raise partition.PartitionError(f"{manifest}: remote package dependency; extend the selector")
    return sorted(str(d.relative_to(root.resolve())) for d in seen)


def in_graph(path: str, graph: list[str]) -> bool:
    return any(path == d or path.startswith(d + "/") for d in graph)


def declarations(text: str) -> tuple[set[str], set[str]]:
    """Visible top-level names a file declares, and the types it extends."""
    names, extended = set(), set()
    for modifiers, kind, name in TOP_LEVEL_DECL.findall(partition.strip_comments(text)):
        if kind == "extension":
            extended.add(name)
        elif not re.search(r"\b(private|fileprivate)\b", modifiers):
            names.add(name)
    return names, extended


def path_literals(text: str) -> set[str]:
    """Repository paths and file names a test file spells, normalised (leading ./ and ../ dropped)."""
    found = set()
    for literal in STRING_LITERAL.findall(text):
        literal = re.sub(r"^(?:\.\.?/)+", "", literal).strip("/")
        if not re.fullmatch(r"[A-Za-z0-9_.+-]+(?:/[A-Za-z0-9_.+-]+)*", literal):
            continue
        if "/" in literal or re.fullmatch(r"[A-Za-z0-9_+-]{3,}\.[A-Za-z0-9]{2,5}", literal):
            found.add(literal)
    return found


def literal_matches(literal: str, path: str) -> bool:
    """A file name matches a path's last component; a path matches whole components anywhere in the path."""
    if "/" not in literal:
        return path.rsplit("/", 1)[-1] == literal
    return ("/" + literal + "/") in ("/" + path + "/")


class Suite:
    """The app-integration test sources: classes per file, GUI share, names and paths each file spells."""

    def __init__(self, root: Path, manifest: dict):
        pkg = partition.package(manifest, PACKAGE_KEY)
        self.test_dir = pkg["testSources"]
        classes = partition.source_classes(root, pkg)
        self.gui = sorted(name for name in classes if name not in pkg["headless"])
        self.files: dict[str, dict] = {}
        for file in sorted((root / self.test_dir).rglob("*.swift")):
            text = file.read_text()
            rel = str(file.relative_to(root))
            names, extended = declarations(text)
            self.files[rel] = {
                "classes": [n for n in partition.CLASS_RE.findall(text)],
                "extended": extended,
                "names": names,
                "words": set(re.findall(r"\b[A-Za-z_]\w*\b", partition.strip_comments(text))),
                "literals": path_literals(text),
            }

    def owners(self, rel: str) -> set[str]:
        """Test classes whose tests live in this file (declared or extended here)."""
        info = self.files[rel]
        return set(info["classes"]) | (info["extended"] & self.every_class())

    def every_class(self) -> set[str]:
        return {c for f in self.files.values() for c in f["classes"]}

    def referencing(self, names: set[str], exclude: str = "") -> set[str]:
        return {c for rel, f in self.files.items() if rel != exclude and f["words"] & names for c in self.owners(rel)}

    def spelling(self, path: str) -> set[str]:
        return {c for rel, f in self.files.items() if any(literal_matches(l, path) for l in f["literals"])
                for c in self.owners(rel)}


def is_other_test_dir(path: str) -> bool:
    return any(part == "Tests" or part.endswith("Tests") for part in path.split("/")[:-1])


def select(changed: list[str], root: Path = ROOT, manifest: dict | None = None) -> tuple[str, list[str]]:
    """Return ("full" | "none" | "classes", sorted GUI classes) and print a reason per path to stderr."""
    manifest = manifest or partition.load_manifest()
    suite = Suite(root, manifest)
    graph = package_graph(root)
    gui = set(suite.gui)
    selected: set[str] = set()
    reasons: list[str] = []

    def full(why: str) -> tuple[str, list[str]]:
        print(f"gui-selection: full suite: {why}", file=sys.stderr)
        return "full", []

    paths = sorted({p.strip() for p in changed if p.strip()})
    if not paths:
        return full("no changed path to select from")
    if len(paths) > MAX_CHANGED:
        return full(f"{len(paths)} changed paths")
    for path in paths:
        if any(p.search(path) for p in FULL_PATTERNS):
            return full(f"{path} is CI, package or test infrastructure")
        hits = suite.spelling(path)
        exists = (root / path).is_file()
        if not in_graph(path, graph):
            reasons.append(f"{path}: outside the Swift package graph; named by {len(hits)} GUI-leg classes")
        elif path.endswith(".md"):
            reasons.append(f"{path}: documentation; named by {len(hits)} classes")
        elif SCRIPT.search(path):
            reasons.append(f"{path}: verification/tooling script (run by its own steps); named by {len(hits)} classes")
        elif not path.endswith(".swift"):
            return full(f"{path} is a non-Swift file in the Swift package graph")
        elif not exists:
            return full(f"{path} was deleted or renamed")
        elif path.startswith(suite.test_dir + "/"):
            own = suite.owners(path)
            info, tests = suite.files[path], suite.every_class()
            # Support it declares, and production types it extends for other files (fixtures, helpers).
            users = suite.referencing((info["names"] | info["extended"]) - tests, exclude=path)
            if not own and not users:
                return full(f"{path} is shared test support that no class names")
            hits |= own | users
            reasons.append(f"{path}: test file of {len(own)} classes, support used by {len(users - own)} more")
        elif is_other_test_dir(path):
            reasons.append(f"{path}: tests of another target, not part of the app-integration GUI leg")
        else:
            names, extended = declarations((root / path).read_text())
            users = suite.referencing(names | extended)
            if not users:
                return full(f"{path} declares nothing a GUI-leg test names (it may be reached indirectly)")
            hits |= users
            reasons.append(f"{path}: {len(users)} classes name its declarations")
        selected |= hits
    for line in reasons:
        print(f"gui-selection: {line}", file=sys.stderr)
    selected &= gui
    if not selected:
        print("gui-selection: no GUI-leg class is related to this change", file=sys.stderr)
        return "none", []
    if len(selected) >= FULL_SHARE * len(gui):
        return full(f"{len(selected)} of {len(gui)} GUI classes are related")
    print(f"gui-selection: {len(selected)} of {len(gui)} GUI classes", file=sys.stderr)
    return "classes", sorted(selected)


def render(mode: str, classes: list[str]) -> str:
    return ",".join(classes) if mode == "classes" else mode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    s = sub.add_parser("select")
    s.add_argument("--changed", required=True, type=Path, help="changed paths, one per line")
    s.add_argument("--root", type=Path, default=ROOT)
    ns = parser.parse_args(argv)
    try:
        mode, classes = select(ns.changed.read_text().splitlines(), ns.root.resolve())
    except partition.PartitionError as error:
        print(f"gui-selection: full suite: {error}", file=sys.stderr)
        mode, classes = "full", []
    print(render(mode, classes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
