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
  assert.deepEqual(rows.map((r) => r.dir), ["desktop/native", "desktop/native/Dep", "desktop/native/Free", "desktop/native/verification"]);
  assert.equal(rows[3].flags, SPI_FLAG); // the host is no longer left out: it builds with the SPI flag, as a PR row does
  assert.ok(rows.every((r) => r.mode === "build-tests" && r.filter === ""));
  assert.equal(new Set(rows.map((r) => r.scratch)).size, rows.length);
});

// A miniature of desktop/native: the root embeds Selection's sources as its own targets, Settings and AppIntegration
// depend on the root, verification depends on Settings and AppIntegration, Wire lives outside desktop/native.
const N = "desktop/native";
const g = {
  [`${N}/Package.swift`]: '.target(name: "ModelPlanSelection", path: "ModelPlanSelection/Sources/ModelPlanSelection"), .testTarget(name: "RootTests", path: "RootTests")',
  [`${N}/ModelPlanSelection/Package.swift`]: "",
  [`${N}/ModelPlanSelection/Sources/ModelPlanSelection/S.swift`]: "",
  [`${N}/RootTests/RootTests.swift`]: "final class RootTests: XCTestCase {}",
  [`${N}/ModelPlanSettings/Package.swift`]: '.package(name: "ModelPlanNative", path: ".."), .package(path: "../../../clients/swift/ModelPlanWire")',
  [`${N}/ModelPlanSettings/Sources/A.swift`]: "",
  [`${N}/ModelPlanAppIntegration/Package.swift`]: '.package(name: "ModelPlanNative", path: ".."),\n.package(name: "ModelPlanSettings", path: "../ModelPlanSettings")',
  [`${N}/ModelPlanAppIntegration/Sources/X.swift`]: "",
  [`${N}/verification/Package.swift`]: '.package(path: "../ModelPlanAppIntegration"), .package(path: "../ModelPlanSettings")',
  [`${N}/verification/U11WiredAdapter.swift`]: "",
  [`${N}/ModelPlanCredentialAgent/Package.swift`]: "",
  [`${N}/ModelPlanCredentialAgent/Sources/C.swift`]: "",
  "clients/swift/ModelPlanWire/Package.swift": "",
  "clients/swift/ModelPlanWire/Sources/W.swift": "",
};
const gAll = Object.keys(g);
const gRead = (f) => g[f];
const dirs = (changed) => withTestTargets(plan(changed, gAll, gRead), gAll, changed, gRead).map((r) => `${r.dir.replace(`${N}/`, "").replace(N, "root")}${r.flags ? "+SPI" : ""}`);

test("invariant: a PR whose test targets do not compile fails mac-compile (every dependent is built)", () => {
  assert.deepEqual(withTestTargets([], [], [], () => ""), []);
  // Selection-only change: the root (which embeds it) and everything on the root, tests built.
  const sel = dirs([`${N}/ModelPlanSelection/Sources/ModelPlanSelection/S.swift`]);
  for (const want of ["root", "ModelPlanSettings", "ModelPlanAppIntegration", "ModelPlanAppIntegration+SPI", "verification+SPI"]) assert.ok(sel.includes(want), `${want} in ${sel}`);
  assert.ok(!sel.includes("ModelPlanCredentialAgent"));
});

test("a Settings-only change builds the wired verification host with the SPI flag, never standalone", () => {
  const rows = withTestTargets(plan([`${N}/ModelPlanSettings/Sources/A.swift`], gAll, gRead), gAll, [`${N}/ModelPlanSettings/Sources/A.swift`], gRead);
  const v = rows.filter((r) => r.dir === `${N}/verification`);
  assert.deepEqual(v.map((r) => r.flags), [SPI_FLAG]);
  assert.ok(rows.some((r) => r.dir === `${N}/ModelPlanAppIntegration` && r.flags === SPI_FLAG));
  assert.ok(!rows.some((r) => r.dir === N), "root does not depend on Settings");
});

test("a change outside desktop/native reaches its dependents inside it; an unrelated package builds only itself", () => {
  assert.deepEqual(dirs(["clients/swift/ModelPlanWire/Sources/W.swift"]).sort(), ["ModelPlanAppIntegration", "ModelPlanAppIntegration+SPI", "ModelPlanSettings", "verification+SPI"].sort());
  assert.deepEqual(dirs([`${N}/ModelPlanCredentialAgent/Sources/C.swift`]), ["ModelPlanCredentialAgent"]);
});

test("the seed builds every standalone package plus the SPI rows", () => {
  const rows = seedPlan(gAll, gRead);
  assert.ok(rows.every((r) => r.mode === "build-tests"));
  assert.deepEqual(rows.filter((r) => r.dir === `${N}/verification`).map((r) => [r.scratch, r.flags]), [["desktop_native_verification_spi", SPI_FLAG]]);
  assert.ok(rows.some((r) => r.flags === SPI_FLAG && r.scratch.endsWith("_spi")));
});

test("invariant: every row a PR can schedule has its products built by the seed in the same configuration", () => {
  const key = (r) => [r.dir, r.scratch, r.flags ?? ""].join("|");
  const seeded = new Set(seedPlan(gAll, gRead).map(key));
  const swift = gAll.filter((f) => f.endsWith(".swift"));
  for (const f of swift) {
    for (const r of withTestTargets(plan([f], gAll, gRead), gAll, [f], gRead)) assert.ok(seeded.has(key(r)), `${f}: ${key(r)} is not seeded`);
  }
});
