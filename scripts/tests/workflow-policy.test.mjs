// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { ALLOWED_ROUTES, workflowProblems } from "../workflow-policy.mjs";

const GUARD = "vars.MAC_CI_RUNNER == 'self-hosted' && github.event_name != 'pull_request_target' && (github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository)";
const ROUTED = "jobs:\n" + [...ALLOWED_ROUTES].map((r, i) => `  j${i}:\n    ${r}\n`).join("");

test("accepts hosted runners, pull_request, and the guarded Mac route", () => {
  assert.deepEqual(workflowProblems("on: pull_request\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
  assert.deepEqual(workflowProblems("on:\n  push:\n  pull_request:\n" + ROUTED), []);
});

test("rejects pull_request_target in every YAML form", () => {
  for (const on of ["on: pull_request_target", "on:\n  pull_request_target:", "on: { pull_request_target: {} }",
    "on: [push, pull_request_target]", "on:\n  - pull_request_target"]) {
    assert.ok(workflowProblems(on + "\njobs:\n  a:\n    runs-on: ubuntu-latest\n").includes("non-canonical self-hosted route or pull_request_target"), on);
  }
});

test("rejects unguarded self-hosted selection even with guard strings in a comment", () => {
  const sneaky = `jobs:\n  a:\n    runs-on: [self-hosted, macOS, ARM64, modelplan-mac] # ${GUARD} github.event.pull_request.head.repo.full_name == github.repository\n`;
  assert.ok(workflowProblems(sneaky).includes("non-canonical self-hosted route or pull_request_target"));
});

test("rejects private labels, literal or dynamically constructed", () => {
  assert.ok(workflowProblems("jobs:\n  a:\n    runs-on: modelplans-publish\n").includes("private runner label"));
  assert.ok(workflowProblems("jobs:\n  a:\n    runs-on: ${{ format('{0}{1}', 'modelplans-', 'publish') }}\n").includes("dynamically constructed runner label"));
  assert.ok(workflowProblems("jobs:\n  a:\n    runs-on: ${{ join(fromJSON('[\"modelplans\",\"ci\"]'), '-') }}\n").includes("dynamically constructed runner label"));
});

test("rejects guard look-alikes: branch filters, OR-bypass, quoted keys", () => {
  const bad = [
    `on: { pull_request_target: { types: [opened], branches: [main, "github.event_name != 'pull_request_target'"] } }`,
    `on:\n  "pull_request_target":`,
    `jobs:\n  a:\n    runs-on: \${{ (${GUARD} || true) && fromJSON('["self-hosted","macOS","ARM64","modelplan-mac"]') || 'macos-latest' }}`,
  ];
  for (const t of bad) assert.ok(workflowProblems(t).includes("non-canonical self-hosted route or pull_request_target"), t);
});
