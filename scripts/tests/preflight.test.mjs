// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { importedPaths, selectChecks, withSnapshot } from "../preflight.mjs";

const names = (c) => c.map((x) => x.name);
const A = "desktop/tests/cockpit/unit/host-strings.test.mjs";

test("always runs source policy and changelog; Swift is only a note", () => {
  const c = selectChecks({ changed: ["README.md"] });
  assert.deepEqual(names(c), ["source policy", "changelog fragments", "swift"]);
  assert.equal(c.at(-1).kind, "note");
});

test("importedPaths resolves static, dynamic and URL references", () => {
  const p = "desktop/tests/cockpit/unit/x.test.mjs";
  const text = `import a from '../../../cockpit/src/a.ts';\nawait import("./b.mjs");\nnew URL('../../../cockpit/study/c.js',import.meta.url)\nimport t from 'node:test'`;
  assert.deepEqual(importedPaths(p, text), ["desktop/cockpit/src/a.ts", "desktop/tests/cockpit/unit/b.mjs", "desktop/cockpit/study/c.js"]);
});

test("cockpit changes add the language audit and tests that import or share a name with the changed file", () => {
  const cockpitTests = {
    [A]: [],
    "desktop/tests/cockpit/unit/calendar.test.mjs": ["desktop/cockpit/src/calendar.ts"],
    "desktop/tests/cockpit/unit/other.test.mjs": ["desktop/cockpit/src/other.ts"],
    "desktop/tests/cockpit/unit/credits-format.test.mjs": [],
  };
  const c = selectChecks({ changed: ["desktop/cockpit/src/calendar.ts", "desktop/cockpit/src/credits-format.ts"], cockpitTests });
  const audit = c.findIndex((x) => x.name === "cockpit language audit");
  assert.deepEqual(c[audit].args, ["--test", A]);
  assert.deepEqual(c[audit + 1].args, ["--test", "desktop/tests/cockpit/unit/calendar.test.mjs", "desktop/tests/cockpit/unit/credits-format.test.mjs"]);
  assert.ok(!names(selectChecks({ changed: ["README.md"], cockpitTests })).includes("cockpit language audit"));
});

test("a changed cockpit unit test runs itself", () => {
  const t = "desktop/tests/cockpit/unit/d1.test.mjs";
  const c = selectChecks({ changed: [t], cockpitTests: { [t]: [] } });
  assert.ok(c.some((x) => x.args?.includes(t)));
});

test("scripts and workflows run the script tests that mention the changed file name", () => {
  const scriptTests = { "scripts/tests/a.test.mjs": "reads workflow-policy.mjs", "scripts/tests/b.test.mjs": "nothing" };
  const c = selectChecks({ changed: ["scripts/workflow-policy.mjs"], scriptTests });
  assert.deepEqual(c.find((x) => x.name.startsWith("script tests")).args, ["--test", "scripts/tests/a.test.mjs"]);
});

test("Go changes: note without go, vet and test per changed package with go", () => {
  const changed = ["cli/internal/quota/a.go", "cli/internal/quota/b.go", "cli/cmd/modelplan/main.go"];
  assert.equal(selectChecks({ changed }).find((x) => x.name === "go").kind, "note");
  const c = selectChecks({ changed, goAvailable: true });
  assert.deepEqual(c.find((x) => x.name.startsWith("go vet")).args, ["vet", "./cmd/modelplan", "./internal/quota"]);
  assert.equal(c.find((x) => x.name.startsWith("go test")).cwd, "cli");
});

const U = "desktop/tests/cockpit/unit/";
const real = {
  [`${U}window-freshness.test.mjs`]: importedPaths(`${U}window-freshness.test.mjs`, "import {currentWindow} from '../../../cockpit/.tmp/compiled/src/prototype-data-adapter.js';"),
  [`${U}lcd-tap-no-trial.test.mjs`]: importedPaths(`${U}lcd-tap-no-trial.test.mjs`, "import '../../../cockpit/study/rocket-r1/strings/mfd.js';\nimport node from 'node:test';"),
  [`${U}unrelated.test.mjs`]: importedPaths(`${U}unrelated.test.mjs`, "import '../../../cockpit/.tmp/compiled/src/members.js';"),
};
const unitArgs = (c) => c.find((x) => x.name === "cockpit unit tests for changed files")?.args.slice(1);

test("compiled imports map back to TypeScript and side-effect imports count", () => {
  const a = selectChecks({ changed: ["desktop/cockpit/src/prototype-data-adapter.ts"], cockpitTests: real });
  assert.deepEqual(unitArgs(a), [`${U}window-freshness.test.mjs`]);
  const b = selectChecks({ changed: ["desktop/cockpit/study/rocket-r1/strings/mfd.js"], cockpitTests: real });
  assert.deepEqual(unitArgs(b), [`${U}lcd-tap-no-trial.test.mjs`]);
});

test("selected cockpit tests are preceded by a clean rebuild from this commit's TypeScript", () => {
  const c = selectChecks({ changed: ["desktop/cockpit/src/x.ts"], cockpitTests: real });
  const i = c.findIndex((x) => x.name === "cockpit compile");
  assert.ok(i >= 0 && i < c.findIndex((x) => x.name === "cockpit language audit"));
  assert.equal(c[i].clean, "desktop/cockpit/.tmp/compiled");
  assert.equal(c[i].cwd, "desktop/cockpit");
  assert.ok(!names(c).includes("cockpit dependencies"));
  assert.equal(selectChecks({ changed: ["desktop/cockpit/src/x.ts"], cockpitDepsInstalled: false })[2].name, "cockpit dependencies");
});

test("a deleted Go package is skipped; surviving importers of it are checked", () => {
  const changed = ["cli/internal/old/a.go", "cli/internal/user/u.go", "cli/internal/other/o.go"];
  const goExistingDirs = new Set(["internal/user", "internal/other", "internal/dep"]);
  const goImporters = { "internal/user": ["internal/old"], "internal/dep": ["internal/old"], "internal/other": [] };
  const c = selectChecks({ changed, goAvailable: true, goExistingDirs, goImporters });
  assert.deepEqual(c.find((x) => x.name.startsWith("go vet")).args, ["vet", "./internal/dep", "./internal/other", "./internal/user"]);
  const only = selectChecks({ changed: ["cli/internal/old/a.go"], goAvailable: true, goExistingDirs: new Set(), goImporters: {} });
  assert.equal(only.find((x) => x.name === "go").kind, "note");
});

function tmpRepo() {
  const dir = mkdtempSync(join(tmpdir(), "preflight-snap-"));
  const g = (...a) => execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@example.invalid", ...a], { cwd: dir, encoding: "utf8" }).trim();
  g("init", "-q", "-b", "main");
  const commit = (v) => { writeFileSync(join(dir, "v.txt"), v); g("add", "."); g("commit", "-qm", v); return g("rev-parse", "HEAD"); };
  return { dir, g, commit };
}

test("checks read an immutable snapshot of the tested commit even if the checkout moves away and back", () => {
  const { dir, g, commit } = tmpRepo();
  try {
    const a = commit("A"), b = commit("B");
    let snapDir;
    const seen = withSnapshot(dir, a, (snap) => {
      snapDir = snap;
      g("checkout", "-q", b); // the user switches to another clean commit mid-run
      const during = readFileSync(join(snap, "v.txt"), "utf8");
      g("checkout", "-q", a); // ...and back (ABA): the old end-of-run check would pass here
      g("checkout", "-q", b);
      return [during, readFileSync(join(snap, "v.txt"), "utf8"), g("-C", snap, "rev-parse", "HEAD")];
    });
    assert.deepEqual(seen, ["A", "A", a]);
    assert.equal(existsSync(snapDir), false);
    assert.ok(!g("worktree", "list").includes("/preflight/snap-"));
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test("the snapshot is removed when a check throws", () => {
  const { dir, g, commit } = tmpRepo();
  try {
    const a = commit("A");
    let snapDir;
    assert.throws(() => withSnapshot(dir, a, (snap) => { snapDir = snap; throw new Error("boom"); }), /boom/);
    assert.equal(existsSync(snapDir), false);
    assert.ok(!g("worktree", "list").includes("/preflight/snap-"));
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
