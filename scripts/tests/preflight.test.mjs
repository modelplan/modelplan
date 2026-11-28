// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { WEBKIT_CAP, importedPaths, relatedWebkitSpecs, selectChecks, withSnapshot } from "../preflight.mjs";

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

test("skill source or packaged copy changes run the skill copy check; other changes do not", () => {
  for (const f of ["skills/model-plan/SKILL.md", "claude-code/skills/model-plan/reference.md", "codex/skills/setup/SKILL.md", "scripts/package-skill.mjs"]) {
    const c = selectChecks({ changed: [f] }).find((x) => x.name === "skill copies");
    assert.deepEqual(c.args, ["scripts/package-skill.mjs", "--check"], f);
  }
  assert.ok(!names(selectChecks({ changed: ["codex/src/a.ts", "README.md"] })).includes("skill copies"));
});

const B = "desktop/tests/cockpit/browser/";
const specs = {
  [`${B}c-hud.spec.mjs`]: "import {shortLabel} from '../../../cockpit/study/rocket-r1/short-label.js';",
  [`${B}c-forecast.spec.mjs`]: "await page.locator('.x'); // styles in cockpit.css",
  [`${B}c-other.spec.mjs`]: "import '../../../cockpit/.tmp/compiled/src/members.js';",
  [`${B}calendar-plugin.spec.mjs`]: "nothing",
};
const webkitArgs = (c) => c.filter((x) => x.name === "webkit spec").map((x) => x.args.at(-1));

test("cockpit changes run the related WebKit specs one file at a time after an official build", () => {
  const c = selectChecks({ changed: ["desktop/cockpit/study/rocket-r1/short-label.js", "desktop/cockpit/web/cockpit.css", "desktop/cockpit/src/calendar-plugin.ts"], browserSpecs: specs });
  assert.deepEqual(webkitArgs(c), ["browser/c-hud\\.spec\\.mjs$", "browser/c-forecast\\.spec\\.mjs$", "browser/calendar-plugin\\.spec\\.mjs$"]);
  assert.ok(c.findIndex((x) => x.name === "cockpit official build") < c.findIndex((x) => x.name === "webkit spec"));
  assert.ok(c.filter((x) => x.name === "webkit spec").every((x) => x.cwd === "desktop/cockpit" && x.args.length === 5));
  assert.ok(!names(selectChecks({ changed: ["README.md"], browserSpecs: specs })).includes("webkit spec"));
});

test("a changed browser spec always runs and ranks first; unrelated specs are left out", () => {
  const c = selectChecks({ changed: [`${B}c-other.spec.mjs`], browserSpecs: specs });
  assert.deepEqual(webkitArgs(c), ["browser/c-other\\.spec\\.mjs$"]);
  assert.deepEqual(relatedWebkitSpecs(["desktop/cockpit/web/cockpit.css", `${B}c-hud.spec.mjs`], specs).map((r) => [r.spec.slice(B.length), r.score]), [["c-hud.spec.mjs", 3], ["c-forecast.spec.mjs", 1]]);
});

test("more than the cap: the best are run, the rest are named as CI will run (never silent)", () => {
  const many = Object.fromEntries(Array.from({ length: 12 }, (_, i) => [`${B}s${String(i).padStart(2, "0")}.spec.mjs`, "uses cockpit.css"]));
  many[`${B}zz.spec.mjs`] = "import '../../../cockpit/web/cockpit.css';";
  const c = selectChecks({ changed: ["desktop/cockpit/web/cockpit.css"], browserSpecs: many });
  assert.equal(webkitArgs(c).length, WEBKIT_CAP);
  assert.equal(webkitArgs(c)[0], "browser/zz\\.spec\\.mjs$"); // direct import ranks first
  const note = c.find((x) => x.name === "webkit" && x.kind === "note");
  assert.match(note.note, /^CI will run 5 more related spec\(s\)/);
});

test("without Playwright WebKit the specs are a recorded SKIP, not a silent pass", () => {
  const c = selectChecks({ changed: ["desktop/cockpit/web/cockpit.css"], browserSpecs: specs, webkitAvailable: false });
  const n = c.find((x) => x.name === "webkit");
  assert.equal(n.skipped, true);
  assert.match(n.note, /not installed/);
  assert.ok(!names(c).includes("webkit spec") && !names(c).includes("cockpit official build"));
  assert.equal(selectChecks({ changed: ["desktop/cockpit/web/zzz-none.css"], browserSpecs: specs, webkitAvailable: false }).find((x) => x.name === "webkit").skipped, undefined);
});

test("Swift, GUI map or merge-gate changes run the GUI map test and every script test that reads the map", () => {
  const scriptTests = {
    "scripts/tests/gui-test-map.test.mjs": "x",
    "scripts/tests/merge-gates.test.mjs": "reads gui-test-map.json",
    "scripts/tests/other.test.mjs": "nothing",
  };
  const want = ["--test", "scripts/tests/gui-test-map.test.mjs", "scripts/tests/merge-gates.test.mjs"];
  for (const f of ["desktop/native/Sources/A/b.swift", "desktop/native/tools/ci/gui-test-map.json"]) {
    assert.deepEqual(selectChecks({ changed: [f], scriptTests }).find((x) => x.name === "GUI map tests").args, want, f);
  }
  assert.ok(!names(selectChecks({ changed: ["desktop/native/README.md", "desktop/native/tools/ci/other.json"], scriptTests })).includes("GUI map tests"));
  // scripts/merge-gates/** already selects merge-gates.test.mjs by name; it is not run twice.
  const g = selectChecks({ changed: ["scripts/merge-gates/rules.mjs"], scriptTests: { ...scriptTests, "scripts/tests/merge-gates.test.mjs": "reads gui-test-map.json and rules.mjs" } });
  assert.deepEqual(g.find((x) => x.name === "script tests for changed files").args, ["--test", "scripts/tests/merge-gates.test.mjs"]);
  assert.deepEqual(g.find((x) => x.name === "GUI map tests").args, ["--test", "scripts/tests/gui-test-map.test.mjs"]);
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
