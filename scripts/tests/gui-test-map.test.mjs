// SPDX-License-Identifier: MIT
// D481: the committed GUI test map stays valid against the tree (every class exists and runs on a GUI leg, every glob
// matches a tracked file), and the selector the gate and the PR GUI leg share behaves as documented.
import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import * as M from "../merge-gates/gui-map.mjs";
import { FILE_LIST_LIMIT } from "../merge-gates/rules.mjs";

const root = new URL("../..", import.meta.url).pathname;
const map = M.parseMap(readFileSync(join(root, M.MAP_PATH), "utf8"));
const partition = JSON.parse(readFileSync(join(root, "desktop/native/tools/ci/native-test-partition.json"), "utf8")).packages["app-integration"];
// The XCTestCase classes declared under a directory (same declaration shape as native_test_partition.py / plan.mjs).
const CLASS_RE = /^[ \t]*(?:@[A-Za-z0-9_]+(?:\([^)]*\))?[ \t]+)*(?:(?:final|open|public|internal|private|fileprivate) )*class ([A-Za-z0-9_]+)[ \t]*:[ \t]*[A-Za-z0-9_., ]*XCTestCase/gm;
function declared(dir) {
  const out = new Set();
  for (const e of readdirSync(join(root, dir), { recursive: true, withFileTypes: true })) {
    if (!e.isFile() || !e.name.endsWith(".swift")) continue;
    for (const m of readFileSync(join(e.parentPath ?? e.path, e.name), "utf8").matchAll(CLASS_RE)) out.add(m[1]);
  }
  return out;
}
function tracked() {
  try { return execFileSync("git", ["ls-files", "-z"], { cwd: root, encoding: "utf8", maxBuffer: 64 << 20 }).split("\0").filter(Boolean); }
  catch { return readdirSync(root, { recursive: true }).map(String).filter((p) => !p.startsWith(".git/") && !p.includes("node_modules/")); }
}

test("the shipped map is valid: known packages, every class declared there, app-integration classes on the GUI share", () => {
  assert.deepEqual(M.mapProblems(map), []);
  assert.equal(map.packages["app-integration"], partition.testSources, "the partition manifest's test sources");
  const headless = new Set(partition.headless);
  for (const pkg of M.PACKAGES) {
    const have = declared(map.packages[pkg]);
    assert.ok(have.size > 10, `${pkg}: test classes found`);
    for (const a of map.areas) for (const c of a.classes[pkg] ?? []) {
      assert.ok(have.has(c), `${a.area}: ${pkg} class ${c} is not declared in ${map.packages[pkg]}`);
      // A headless class never runs on the GUI leg (the partition narrows each leg to its own share): mapping it would
      // gate a PR on a run that cannot test it.
      if (pkg === M.NARROWED_PACKAGE) assert.ok(!headless.has(c), `${a.area}: ${c} is a headless class; it is not on the GUI leg`);
    }
  }
  // A class name means one class: the gate reports bare names.
  const owners = new Map();
  for (const pkg of M.PACKAGES) for (const c of declared(map.packages[pkg])) {
    if (map.areas.some((a) => (a.classes[pkg] ?? []).includes(c))) {
      assert.ok(!owners.has(c) || owners.get(c) === pkg, `${c} is declared in two packages`);
      owners.set(c, pkg);
    }
  }
});

test("every path glob of the map matches at least one tracked file", () => {
  const files = tracked();
  assert.ok(files.length > 1000);
  for (const a of map.areas) for (const g of a.paths) {
    const re = M.globRegExp(g);
    assert.ok(files.some((f) => re.test(f)), `${a.area}: ${g} matches no tracked file`);
    // A brace list names each file on purpose: every alternative must exist, or a rename silently drops coverage.
    const brace = /^(.*)\{([^}]+)\}(.*)$/.exec(g);
    if (brace) for (const alt of brace[2].split(",")) {
      const one = M.globRegExp(brace[1] + alt + brace[3]);
      assert.ok(files.some((f) => one.test(f)), `${a.area}: ${brace[1]}${alt}${brace[3]} matches no tracked file`);
    }
  }
});

test("globs: ** spans segments, * and ? stay in one, braces alternate, the rest is literal", () => {
  const ok = (g, p) => M.globRegExp(g).test(p);
  assert.ok(ok("a/**", "a/b/c.swift") && ok("a/**", "a/x") && !ok("a/**", "ab/x"));
  assert.ok(ok("a/**/c.swift", "a/c.swift") && ok("a/**/c.swift", "a/b/d/c.swift") && !ok("a/**/c.swift", "a/bc.swift"));
  assert.ok(ok("a/*.swift", "a/b.swift") && !ok("a/*.swift", "a/b/c.swift"));
  assert.ok(ok("a/{B,C}.swift", "a/C.swift") && !ok("a/{B,C}.swift", "a/D.swift") && !ok("a/{B,C}.swift", "a/B.swift.orig"));
  assert.ok(ok("a/b?.swift", "a/b1.swift") && !ok("a/b?.swift", "a/b/.swift"));
  assert.ok(!ok("a/b.swift", "a/bxswift"), "a dot is literal");
  for (const bad of ["a**/b", "a/**b", "a/{b", "a/b}", "a/{b,{c}}"]) assert.throws(() => M.globRegExp(bad), bad);
  assert.ok(M.mapProblems({ ...map, areas: [{ area: "x", paths: ["../x"], classes: { settings: ["A"] } }] }).length > 0);
  assert.ok(M.mapProblems({ ...map, areas: [{ area: "x", paths: ["a"], classes: { other: ["A"] } }] }).length > 0);
  assert.ok(M.mapProblems({ ...map, areas: [{ area: "x", paths: ["a"], classes: { settings: ["B", "A"] } }] }).length > 0, "unsorted");
  assert.ok(M.mapProblems({ ...map, areas: [...map.areas, map.areas[0]] }).length > 0, "duplicate area");
});

test("#1208 (ring geometry, D399) maps to D65ZeroQuotaTests; unmapped changes select nothing", () => {
  const pr1208 = ["changelog.d/d399-quota-rings-weekly-outside.md", "desktop/native/ModelPlanDock/Logic/DockInstrumentModel.swift",
    "desktop/native/ModelPlanDock/LogicChecks/main.swift", "desktop/native/ModelPlanDock/Native/DockInstrumentRenderer.swift"];
  const sel = M.mappedClasses(pr1208, [map]);
  assert.ok(sel.includes("app-integration:D65ZeroQuotaTests"), "the class that broke main after #1208");
  assert.match(M.guiClassesInput(sel), /(^|,)D65ZeroQuotaTests(,|$)/);
  assert.deepEqual(M.mappedClasses(["docs/mac-ci.md", "cli/main.go"], [map]), []);
  // Settings: the ModelPlanSettings classes are reported, but only app-integration classes reach gui_classes.
  const settings = M.mappedClasses(["desktop/native/ModelPlanSettings/Sources/ModelPlanSettings/SettingsWindowController.swift"], [map]);
  assert.ok(settings.includes("settings:SettingsB5GridTests") && settings.includes("app-integration:G1SettingsJourneys"));
  assert.doesNotMatch(M.guiClassesInput(settings), /SettingsB5GridTests/);
  assert.equal(M.guiClassesInput(["settings:SettingsB5GridTests"]), "none", "only whole-package classes: the leg runs, narrowed to none");
  // A rename's old path counts (the CLI adds previous_filename), a cut-off list selects every class, maps are unioned.
  const all = M.mappedClasses([], [map], { truncated: true });
  assert.equal(all.length, new Set(map.areas.flatMap((a) => Object.entries(a.classes).flatMap(([k, l]) => l.map((c) => `${k}:${c}`)))).size);
  const extra = { ...map, areas: [{ area: "new", paths: ["cli/**"], classes: { "app-integration": ["ZaiMarkSwitchTests"] } }] };
  assert.deepEqual(M.mappedClasses(["cli/x.go"], [map, extra]), ["app-integration:ZaiMarkSwitchTests"]);
  assert.deepEqual(M.bareNames(["settings:B", "app-integration:A", "app-integration:B"]), ["A", "B"]);
  assert.equal(M.FILE_LIST_LIMIT, FILE_LIST_LIMIT, "the same API cap as the gate");
});

test("CLI: reads PR file rows (renames too), unions maps, fails on an invalid map", () => {
  const dir = mkdtempSync(join(tmpdir(), "d481-map-"));
  const cli = (rows, ...maps) => {
    writeFileSync(join(dir, "files.jsonl"), rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
    const r = spawnSync(process.execPath, [join(root, "scripts/merge-gates/gui-map.mjs"), "select", "--files", join(dir, "files.jsonl"), ...maps.flatMap((m) => ["--map", m])], { encoding: "utf8" });
    return r.status === 0 ? JSON.parse(r.stdout) : { status: r.status, err: r.stderr };
  };
  const shipped = join(root, M.MAP_PATH);
  try {
    const renamed = cli([{ filename: "desktop/native/x.swift", previous_filename: "desktop/native/ModelPlanDock/Native/DockInstrumentRenderer.swift" }], shipped);
    assert.ok(renamed.all.includes("app-integration:D65ZeroQuotaTests") && !renamed.truncated);
    assert.deepEqual(cli([{ filename: "docs/a.md", previous_filename: null }], shipped), { gui: "none", all: [], truncated: false });
    const many = Array.from({ length: FILE_LIST_LIMIT }, (_, i) => ({ filename: `docs/${i}.md` }));
    const cut = cli(many, shipped);
    assert.ok(cut.truncated && cut.all.length > 50, "a cut-off list selects every mapped class");
    writeFileSync(join(dir, "bad.json"), JSON.stringify({ schemaVersion: 2 }));
    assert.equal(cli([{ filename: "a" }], shipped, join(dir, "bad.json")).status, 1);
    assert.equal(cli([{ filename: "a" }]).status, 1, "no map");
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

// macrev2-1310-2: a PR that changes only the status-item entry (EngineDockMenuApplication.swift) must be held for the
// classes that open through it, StatusItemLaunchTests among them.
test("the status-item entry path alone maps to StatusItemLaunchTests; the CLI agrees", () => {
  const entry = "desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/EngineDockMenuApplication.swift";
  assert.ok(M.mappedClasses([entry], [map]).includes("app-integration:StatusItemLaunchTests"));
  const dir = mkdtempSync(join(tmpdir(), "d481-entry-"));
  try {
    writeFileSync(join(dir, "f.jsonl"), JSON.stringify({ filename: entry }) + "\n");
    const r = spawnSync(process.execPath, [join(root, "scripts/merge-gates/gui-map.mjs"), "select", "--files", join(dir, "f.jsonl"), "--map", join(root, M.MAP_PATH)], { encoding: "utf8" });
    assert.equal(r.status, 0, r.stderr);
    assert.match(JSON.parse(r.stdout).gui, /(^|,)StatusItemLaunchTests(,|$)/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

// Every source file a non-curated area names (one file, or one brace alternative) covers at least the GUI classes the
// D169 selector rule finds for it (classes whose test files name its top-level declarations). Entry points such as the
// status item, the normal entry, the menu bar and the application factories each have their own entry-* area, so a
// change to one is held for everything that opens through it. Needs python3 (repo checks and CI images have it).
test("named source files cover what gui_test_selection.py finds for them (entry points included)", () => {
  const named = [];
  for (const a of map.areas) {
    if (a.curated) continue;
    for (const g of a.paths) {
      if (/[*?]/.test(g)) continue;
      const brace = /^(.*)\{([^}]+)\}(.*)$/.exec(g);
      for (const f of brace ? brace[2].split(",").map((x) => brace[1] + x + brace[3]) : [g]) if (f.endsWith(".swift")) named.push([a.area, f]);
    }
  }
  assert.ok(named.length > 40);
  for (const f of ["EngineDockMenuApplication", "EngineRowsEntry", "CommunityMenuBar", "CommunityApplicationFactory", "CommunityCockpitApplicationFactory", "SettingsApplication", "SettingsWindowHost"])
    assert.ok(named.some(([, p]) => p.endsWith(`/${f}.swift`)), `entry point ${f} is mapped`);
  const py = `import json, sys
sys.path.insert(0, "desktop/native/tools/ci")
import gui_test_selection as g, native_test_partition as p
suite = g.Suite(g.ROOT, p.load_manifest()); gui = set(suite.gui)
out = {}
for f in json.load(sys.stdin):
    names, ext = g.declarations((g.ROOT / f).read_text())
    out[f] = sorted(suite.referencing(names | ext) & gui)
print(json.dumps(out))`;
  const r = spawnSync("python3", ["-c", py], { cwd: root, input: JSON.stringify([...new Set(named.map(([, f]) => f))]), encoding: "utf8", maxBuffer: 16 << 20 });
  assert.equal(r.status, 0, r.stderr);
  const found = JSON.parse(r.stdout);
  for (const [area, f] of named) {
    const mapped = new Set(M.mappedClasses([f], [map]).filter((q) => q.startsWith("app-integration:")).map((q) => q.slice(16)));
    const missing = found[f].filter((c) => !mapped.has(c));
    assert.deepEqual(missing, [], `${area}: ${f} misses classes that name its declarations`);
  }
});

test("desktop.yml records the selection under the title the gate reads", () => {
  const desktop = readFileSync(join(root, ".github/workflows/desktop.yml"), "utf8");
  assert.ok(desktop.includes(`echo "::notice title=${M.RECORD_TITLE}::\${all:-none}"`));
  assert.deepEqual(M.parseRecord("none"), []);
  assert.deepEqual(M.parseRecord("app-integration:A,settings:B"), ["app-integration:A", "settings:B"]);
  for (const bad of ["", "A", "app-integration:A,", "x:A B", null]) assert.equal(M.parseRecord(bad), null, String(bad));
});
