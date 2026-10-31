// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { ALLOWED_ROUTES, TRUSTED_MAC_ROUTE, isWorkflowFile, workflowProblems } from "../workflow-policy.mjs";

test("trusted Mac route is confined to the reviewed reusable workflow path", () => {
  const text = `jobs:\n  check:\n    ${TRUSTED_MAC_ROUTE}\n`;
  assert.deepEqual(workflowProblems(text, ".github/workflows/trusted-mac.yml"), []);
  assert.ok(workflowProblems(text, ".github/workflows/attacker.yml").length > 0);
  assert.ok(workflowProblems(text.replace("github.actor_id == '11829005'", "true"), ".github/workflows/trusted-mac.yml").length > 0);
  assert.ok(workflowProblems(text.replace("github.event.pull_request.head.repo.full_name == github.repository", "true"), ".github/workflows/trusted-mac.yml").length > 0);
  assert.ok(workflowProblems(text.replace("inputs.os == 'macos-latest'", "true"), ".github/workflows/trusted-mac.yml").length > 0);
});

const GUARD = "vars.MAC_CI_RUNNER == 'self-hosted' && github.event_name != 'pull_request_target' && (github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository)";
const ROUTED = "jobs:\n" + [...ALLOWED_ROUTES].map((r, i) => `  j${i}:\n    ${r}\n`).join("");

test("accepts hosted runners and ordinary pull_request triggers", () => {
  assert.deepEqual(workflowProblems("on: pull_request\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
  assert.deepEqual(workflowProblems("on:\n  push:\n  pull_request:\njobs:\n  a:\n    runs-on: ubuntu-latest\n"), []);
  assert.ok(workflowProblems(`runs-on: \${{ (${GUARD}) && fromJSON('["self-hosted","macOS","ARM64","modelplan-mac"]') || 'macos-latest' }}`).length > 0);
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

test("rejects escaped spellings that a YAML parser decodes to the forbidden names", () => {
  for (const t of [
    'on:\n  "pull_request_tar\\u0067et":',
    'on:\n  "pull_request\\x5ftarget":',
    'on:\n  "pull_request_\\\n    target":',
    'jobs:\n  a:\n    runs-on: "self\\u002dhosted"',
    'jobs:\n  a:\n    runs-on: "modelplans\\u002dci"',
  ]) assert.ok(workflowProblems(t).length > 0, t);
});

test("ordinary shell and regex backslashes stay legal", () => {
  const run = 'jobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n      - run: |\n          go build -ldflags "-s -w" \\\n            ./cmd\n          python3 -c \'import re; re.findall(r"\\d+", "v1")\'\n';
  assert.deepEqual(workflowProblems(run), []);
});

test("both workflow extensions are checked", () => {
  assert.ok(isWorkflowFile(".github/workflows/ci.yml"));
  assert.ok(isWorkflowFile(".github/workflows/ci.yaml"));
  assert.ok(!isWorkflowFile(".github/workflows/nested/ci.yml"));
  assert.ok(!isWorkflowFile(".github/workflows/README.md"));
});
