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
// Usage (in a checkout of the PR merge commit): node scripts/mac-compile/plan.mjs [base]
// (default HEAD^1: the merge commit's first parent is main). Prints one TSV row per package:
// dir, scratch name, mode (filter | skip | build-tests), filter pattern, skip pattern.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = "desktop/native";
// DockBehaviourTests, DockClickFocusTests and CockpitContextMenuAndReloadTests need the real window server or event
// queue (a shared compile Mac delivers other events first; GUI CI runs them). GeneratedDecoderTests and
// GeneratedConsentPortTests are frozen (#315); hosted CI skips them too.
export const NEVER_RUN = Object.freeze(["DockBehaviourTests", "DockClickFocusTests", "CockpitContextMenuAndReloadTests", "GeneratedDecoderTests", "GeneratedConsentPortTests"]);
export const FILTER_MAX = 700;
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
  for (const f of changed) {
    if (!f.startsWith(ROOT + "/") || !f.endsWith(".swift")) continue;
    const pkg = ownerPackage(f, packages);
    if (pkg) touched.add(pkg);
  }
  const skip = NEVER_RUN.join("|");
  return [...touched].sort().map((dir) => {
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
  const [base = "HEAD^1"] = argv;
  const git = (...a) => execFileSync("git", a, { encoding: "utf8", maxBuffer: 64 << 20 }).split("\0").filter(Boolean);
  const changed = git("diff", "--no-renames", "--name-only", "-z", "--diff-filter=ACMRD", base, "HEAD", "--", ROOT);
  const files = git("ls-files", "-z", "--", ROOT);
  const rows = plan(changed, files, (f) => fs.readFileSync(f, "utf8"));
  process.stdout.write(rows.length ? toTsv(rows) + "\n" : "");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) main(process.argv.slice(2));
