// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { FILTER_MAX, NEVER_RUN, ownerPackage, plan, testClasses, toTsv } from "../mac-compile/plan.mjs";

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
  assert.equal(toTsv(rows), `desktop/native/Sub\tdesktop_native_Sub\tskip\t-\t${NEVER_RUN.join("|")}`);
});
