// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { importedPaths, selectChecks } from "../preflight.mjs";

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
  assert.deepEqual(c[2].args, ["--test", A]);
  assert.deepEqual(c[3].args, ["--test", "desktop/tests/cockpit/unit/calendar.test.mjs", "desktop/tests/cockpit/unit/credits-format.test.mjs"]);
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
