#!/usr/bin/env node
// SPDX-License-Identifier: MIT
// Plan for the Mac compile check (mac-compile.yml): which Swift packages a PR touches and which XCTest classes
// to run in each. Ported from the coordinator's compile-first.sh, which used to brief a Mac agent with the same
// selection:
// - a touched file is a .swift file (Package.swift included) under desktop/native that the PR adds, changes,
//   renames or deletes;
// - its package is the nearest ancestor directory with a Package.swift;
// - the classes are every `class X: ... XCTestCase` declared in that package (not in a sub-package), attributes
//   such as @MainActor allowed, minus NEVER_RUN;
// - a class list longer than FILTER_MAX runs the whole package minus NEVER_RUN; a package without XCTest classes
//   only builds its tests.
// - ModelPlanAppIntegration is the exception (it is ~540 window/GUI-style cases, over the compile Mac's time limit):
//   it never runs whole. It builds its tests and runs only the classes declared in the test files the PR itself
//   touches, and at most APP_INTEGRATION_MAX_CLASSES of them (more than that, or none, means build-tests only). The
//   full suite is the GUI and headless legs' job (desktop.yml, native-test-partition.json).
// Usage: node scripts/mac-compile/plan.mjs <base> <head> (base: the merge base of main and the PR head), in a clone
// that has both commits. Prints one TSV row per package:
// dir, scratch name, mode (filter | skip | build-tests), filter pattern, skip pattern.
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = "desktop/native";
// DockBehaviourTests, DockClickFocusTests and CockpitContextMenuAndReloadTests need the real window server or event
// queue (a shared compile Mac delivers other events first; GUI CI runs them). GeneratedDecoderTests and
// GeneratedConsentPortTests are frozen (#315); hosted CI skips them too.
export const NEVER_RUN = Object.freeze(["DockBehaviourTests", "DockClickFocusTests", "CockpitContextMenuAndReloadTests", "GeneratedDecoderTests", "GeneratedConsentPortTests"]);
export const FILTER_MAX = 700;
export const LIMITED_PACKAGE = "ModelPlanAppIntegration";
// Past this many touched classes a "targeted" run is just the broad suite again, which overran the 45 minute limit.
export const APP_INTEGRATION_MAX_CLASSES = 8;
export const CLASS_RE = /^[ \t]*(?:@[A-Za-z0-9_]+(?:\([^)]*\))?[ \t]+)*(?:(?:final|open|public|internal|private|fileprivate) )*class ([A-Za-z0-9_]+)[ \t]*:[ \t]*[A-Za-z0-9_., ]*XCTestCase/gm;

// Nearest ancestor of file (a repo-relative path) that is a package directory, or null.
export function ownerPackage(file, packages) {
  let p = path.posix.dirname(file);
  while (p !== "." && p !== "/" && p !== "") {
    if (packages.has(p)) return p;
    p = path.posix.dirname(p);
  }
  return null;
}

export function testClasses(source) {
  return [...source.matchAll(CLASS_RE)].map((m) => m[1]);
}

// changed: repo-relative paths the PR touches; files: every tracked path at the head; read(path) -> file text.
export function plan(changed, files, read) {
  const packages = new Set(files.filter((f) => f.startsWith(ROOT + "/") && /(^|\/)Package\.swift$/.test(f)).map((f) => path.posix.dirname(f)));
  const touched = new Set();
  const touchedFiles = new Map();
  for (const f of changed) {
    if (!f.startsWith(ROOT + "/") || !f.endsWith(".swift")) continue;
    const pkg = ownerPackage(f, packages);
    if (!pkg) continue;
    touched.add(pkg);
    if (!touchedFiles.has(pkg)) touchedFiles.set(pkg, []);
    touchedFiles.get(pkg).push(f);
  }
  const skip = NEVER_RUN.join("|");
  return [...touched].sort().map((dir) => {
    if (path.posix.basename(dir) === LIMITED_PACKAGE) {
      const own = new Set();
      for (const f of touchedFiles.get(dir)) {
        if (!files.includes(f)) continue; // deleted at the head
        for (const c of testClasses(read(f))) if (!NEVER_RUN.includes(c)) own.add(c);
      }
      const names = [...own].sort();
      const mode = names.length && names.length <= APP_INTEGRATION_MAX_CLASSES ? "filter" : "build-tests";
      return { dir, scratch: dir.replaceAll("/", "_"), mode, filter: mode === "filter" ? names.join("|") : "", skip };
    }
    const classes = new Set();
    for (const f of files) {
      if (!f.endsWith(".swift") || ownerPackage(f, packages) !== dir) continue;
      for (const c of testClasses(read(f))) if (!NEVER_RUN.includes(c)) classes.add(c);
    }
    const filter = [...classes].sort().join("|");
    const mode = !filter ? "build-tests" : filter.length > FILTER_MAX ? "skip" : "filter";
    return { dir, scratch: dir.replaceAll("/", "_"), mode, filter: mode === "filter" ? filter : "", skip };
  });
}

export function toTsv(rows) {
  return rows.map((r) => [r.dir, r.scratch, r.mode, r.filter || "-", r.skip].join("\t")).join("\n");
}

function main(argv) {
  const [base, head] = argv;
  if (!base || !head) throw new Error("usage: plan.mjs <base> <head>");
  const git = (...a) => execFileSync("git", a, { encoding: "utf8", maxBuffer: 64 << 20 });
  const list = (...a) => git(...a).split("\0").filter(Boolean);
  const changed = list("diff", "--no-renames", "--name-only", "-z", "--diff-filter=ACMRD", base, head, "--", ROOT);
  const files = list("ls-tree", "-r", "-z", "--name-only", head, "--", ROOT);
  // PR files are only read as text (git show), never checked out or run here.
  const rows = plan(changed, files, (f) => git("show", `${head}:${f}`));
  process.stdout.write(rows.length ? toTsv(rows) + "\n" : "");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) main(process.argv.slice(2));
