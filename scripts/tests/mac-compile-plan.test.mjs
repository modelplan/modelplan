// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { SPI_FLAG, withTestTargets, seedPlan, APP_INTEGRATION_MAX_CLASSES, FILTER_MAX, NEVER_RUN, ownerPackage, plan, testClasses, toTsv } from "../mac-compile/plan.mjs";

const files = {
  "desktop/native/Package.swift": "",
  "desktop/native/Sources/App/App.swift": "struct App {}",
  "desktop/native/Tests/AppTests/AppTests.swift": [
    "final class AppTests: XCTestCase {}",
    "@MainActor final class MainActorTests: XCTestCase {}",
    "@available(macOS 15, *) @MainActor class AttributedTests : BaseCase, XCTestCase {}",
    "final class DockBehaviourTests: XCTestCase {}",
    "class Helper: NSObject {}",
    "// class Commented: XCTestCase {}",
  ].join("\n"),
  "desktop/native/Sub/Package.swift": "",
  "desktop/native/Sub/Sources/S.swift": "",
  "desktop/native/Sub/Tests/SubTests.swift": "final class SubTests: XCTestCase {}",
  "desktop/native/NoTests/Package.swift": "",
  "desktop/native/NoTests/Sources/N.swift": "",
  "desktop/web/x.swift": "",
};
const all = Object.keys(files);
const read = (f) => files[f];

test("class declarations: attributes, modifiers and spacing as in compile-first.sh", () => {
  assert.deepEqual(testClasses(files["desktop/native/Tests/AppTests/AppTests.swift"]), ["AppTests", "MainActorTests", "AttributedTests", "DockBehaviourTests"]);
});

test("nearest package owns a file", () => {
  const pk = new Set(["desktop/native", "desktop/native/Sub"]);
  assert.equal(ownerPackage("desktop/native/Sub/Tests/SubTests.swift", pk), "desktop/native/Sub");
  assert.equal(ownerPackage("desktop/native/Sources/App/App.swift", pk), "desktop/native");
  assert.equal(ownerPackage("desktop/web/x.swift", pk), null);
});

test("touched packages get their own classes, minus the never-run list", () => {
  const rows = plan(["desktop/native/Sources/App/App.swift", "desktop/native/Sub/Package.swift", "desktop/native/NoTests/Sources/N.swift", "desktop/web/x.swift", "desktop/native/README.md"], all, read);
  assert.deepEqual(rows.map((r) => [r.dir, r.mode, r.filter]), [
    ["desktop/native", "filter", "AppTests|AttributedTests|MainActorTests"],
    ["desktop/native/NoTests", "build-tests", ""],
    ["desktop/native/Sub", "filter", "SubTests"],
  ]);
  assert.equal(rows[0].skip, NEVER_RUN.join("|"));
  assert.equal(rows[2].scratch, "desktop_native_Sub");
  for (const n of ["DockBehaviourTests", "DockClickFocusTests", "CockpitContextMenuAndReloadTests", "GeneratedDecoderTests", "GeneratedConsentPortTests"]) assert.ok(NEVER_RUN.includes(n), n);
});

test("no Swift change under desktop/native: empty plan", () => {
  assert.deepEqual(plan(["desktop/web/x.swift", "docs/a.md", "desktop/native/README.md"], all, read), []);
});

test("a long class list runs the whole package minus the never-run classes", () => {
  const many = Array.from({ length: 80 }, (_, i) => `final class LongName${i}Tests: XCTestCase {}`).join("\n");
  const rows = plan(["desktop/native/Sub/Sources/S.swift"], all, (f) => (f === "desktop/native/Sub/Tests/SubTests.swift" ? many : read(f)));
  assert.ok(many.length > FILTER_MAX);
  assert.deepEqual([rows[0].mode, rows[0].filter], ["skip", ""]);
  assert.equal(toTsv(rows), `desktop/native/Sub\tdesktop_native_Sub\tskip\t-\t${NEVER_RUN.join("|")}\t-`);
});

const AI = "desktop/native/ModelPlanAppIntegration";
const aiFiles = {
  [`${AI}/Package.swift`]: "",
  [`${AI}/Sources/X/X.swift`]: "struct X {}",
  [`${AI}/Tests/AAATests.swift`]: "final class AAATests: XCTestCase {}\nfinal class DockBehaviourTests: XCTestCase {}",
  [`${AI}/Tests/BBBTests.swift`]: "final class BBBTests: XCTestCase {}",
};
const aiRead = (f) => aiFiles[f];

test("AppIntegration broad source change builds tests only", () => {
  const rows = plan([`${AI}/Sources/X/X.swift`], Object.keys(aiFiles), aiRead);
  assert.deepEqual(rows.map((r) => [r.mode, r.filter]), [["build-tests", ""]]);
});

test("AppIntegration touched test file filters on its own classes", () => {
  const rows = plan([`${AI}/Tests/AAATests.swift`, `${AI}/Sources/X/X.swift`], Object.keys(aiFiles), aiRead);
  assert.deepEqual(rows.map((r) => [r.mode, r.filter]), [["filter", "AAATests"]]);
});

test("AppIntegration touching too many classes falls back to build-tests", () => {
  const many = Array.from({ length: APP_INTEGRATION_MAX_CLASSES + 1 }, (_, i) => `final class C${i}Tests: XCTestCase {}`).join("\n");
  const rows = plan([`${AI}/Tests/AAATests.swift`], Object.keys(aiFiles), (f) => (f.endsWith("AAATests.swift") ? many : aiRead(f)));
  assert.equal(rows[0].mode, "build-tests");
});

test("AppIntegration deleted test file is not read", () => {
  const rows = plan([`${AI}/Tests/GoneTests.swift`], Object.keys(aiFiles), aiRead);
  assert.equal(rows[0].mode, "build-tests");
});

test("seed plan: every standalone-buildable package, tests built only, one scratch each; run 44422368763's failures left out", () => {
  const f = {
    "desktop/native/Package.swift": 'targets: [.target(name: "Shell", path: "Shell/Sources/Shell"), .target(name: "Free", path: "Free/Sources/Free")]',
    "desktop/native/Sources/A.swift": "",
    "desktop/native/Shell/Package.swift": 'dependencies: [.package(name: "ModelPlanNative", path: "..")]',
    "desktop/native/Shell/Sources/Shell/S.swift": "",
    "desktop/native/Free/Package.swift": "dependencies: []",
    "desktop/native/Free/Tests/FreeTests.swift": "final class FreeTests: XCTestCase {}",
    "desktop/native/Dep/Package.swift": 'dependencies: [.package(name: "ModelPlanNative", path: "..")]',
    "desktop/native/Dep/Sources/D.swift": "",
    "desktop/native/verification/Package.swift": "",
    "desktop/native/verification/U.swift": "",
  };
  const rows = seedPlan(Object.keys(f), (p) => f[p]);
  assert.deepEqual(rows.map((r) => r.dir), ["desktop/native", "desktop/native/Dep", "desktop/native/Free"]);
  assert.ok(rows.every((r) => r.mode === "build-tests" && r.filter === ""));
  assert.equal(new Set(rows.map((r) => r.scratch)).size, rows.length);
});

test("invariant: a PR whose test targets do not compile fails mac-compile (AppIntegration tests built in both configurations)", () => {
  assert.deepEqual(withTestTargets([], []), []);
  const every = [...all, ...Object.keys(aiFiles)];
  const rows = withTestTargets(plan(["desktop/native/Sub/Sources/S.swift"], every, (f) => aiFiles[f] ?? files[f]), every);
  assert.deepEqual(rows.map((r) => [r.dir, r.scratch, r.mode, r.flags ?? ""]), [
    ["desktop/native/Sub", "desktop_native_Sub", "filter", ""],
    [AI, "desktop_native_ModelPlanAppIntegration", "build-tests", ""],
    [AI, "desktop_native_ModelPlanAppIntegration_spi", "build-tests", SPI_FLAG],
  ]);
  assert.match(toTsv(rows).split("\n")[2], new RegExp(`\\t${SPI_FLAG}$`));
});

test("a touched AppIntegration keeps its own row and gains only the SPI build; verification takes the SPI flag", () => {
  const f = { ...aiFiles, "desktop/native/verification/Package.swift": "", "desktop/native/verification/U11WiredAdapter.swift": "" };
  const rows = withTestTargets(plan([`${AI}/Tests/AAATests.swift`, "desktop/native/verification/U11WiredAdapter.swift"], Object.keys(f), (p) => f[p]), Object.keys(f));
  assert.deepEqual(rows.map((r) => [r.dir.split("/").pop(), r.mode, r.flags ?? ""]), [
    ["ModelPlanAppIntegration", "filter", ""],
    ["verification", "build-tests", SPI_FLAG],
    ["ModelPlanAppIntegration", "build-tests", SPI_FLAG],
  ]);
});
