// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import { ALLOWED_ROUTES, TRUSTED_MAC_ROUTE, draftGuardProblems, isWorkflowFile, macConcurrencyProblems, workflowProblems } from "../workflow-policy.mjs";

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

test("v1 install guide matches the supported package and update policy", async () => {
  const { readFile } = await import("node:fs/promises");
  const guide = await readFile(new URL("../../docs/install-beta.md", import.meta.url), "utf8");
  const obsolete = /\buniversal\b|\bmacOS\s*14\b|\bSparkle\b|\bappcast\b/i;
  for (const stale of ["universal", "macOS 14", "Sparkle", "appcast"]) {
    assert.match(stale, obsolete);
  }
  assert.doesNotMatch(guide, obsolete);
  assert.match(guide, /Apple silicon only/i);
  assert.match(guide, /macOS 15 or later/i);
  assert.match(guide, /no automatic updates/i);
  assert.match(guide, /no update feed/i);
});

test("macOS workflows on pull_request/push cancel superseded PR heads but never main or release runs", () => {
  const group = "concurrency:\n  group: dist-${{ github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number) || github.run_id }}\n";
  // compliant: PR heads share the pr-N group and cancel the superseded run
  assert.deepEqual(macConcurrencyProblems(`on:\n  pull_request:\n  push:\n${group}  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    runs-on: macos-latest\n`), []);
  // matrix os and trusted-mac callers count as macOS starters
  assert.deepEqual(macConcurrencyProblems(`on: pull_request\n${group}  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    runs-on: \${{ matrix.os }}\n    strategy:\n      matrix:\n        os: [ubuntu-latest, macos-latest]\n`), []);
  assert.deepEqual(macConcurrencyProblems(`on: pull_request\n${group}  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    uses: modelplan/modelplan/.github/workflows/trusted-mac.yml@8a22050adc0cbcc85e4159e54cbd50647245b6c0\n`), []);
  // violations: no group at all, the queueing literal false, the cancelling literal true (either group
  // shape — a ref group cancels main runs; a sha group collides with a same-commit dispatch), and a
  // group without the unique run-id fallback
  for (const bad of ["on:\n  pull_request:\n  push:\njobs:\n  a:\n    runs-on: macos-latest\n",
                     `on:\n  pull_request:\n  push:\n${group}  cancel-in-progress: false\njobs:\n  a:\n    runs-on: macos-latest\n`,
                     `on:\n  pull_request:\n  push:\n${group}  cancel-in-progress: true\njobs:\n  a:\n    runs-on: macos-latest\n`,
                     "on:\n  pull_request:\n  push:\nconcurrency:\n  group: dist-${{ github.event.pull_request.number || github.sha }}\n  cancel-in-progress: true\njobs:\n  a:\n    runs-on: macos-latest\n",
                     "on:\n  pull_request:\n  push:\nconcurrency:\n  group: dist-${{ github.event.pull_request.number || github.ref }}\n  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    runs-on: macos-latest\n"]) {
    assert.ok(macConcurrencyProblems(bad).length > 0, bad);
  }
});

test("non-macOS and non-PR/push workflows are outside the concurrency rule", () => {
  assert.deepEqual(macConcurrencyProblems("on:\n  pull_request:\n  push:\njobs:\n  a:\n    runs-on: ubuntu-latest\n"), []);
  assert.deepEqual(macConcurrencyProblems("on:\n  workflow_dispatch:\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
});

test("every macOS-running workflow in this repository carries the concurrency group", () => {
  const dir = new URL("../../.github/workflows/", import.meta.url);
  for (const f of fs.readdirSync(dir)) {
    if (!/\.(ya?ml)$/.test(f)) continue;
    const text = fs.readFileSync(new URL(f, dir), "utf8");
    assert.deepEqual(macConcurrencyProblems(text), [], f);
  }
});

test("macOS jobs on pull_request are draft-guarded (or dispatch-only) and the workflow keeps workflow_dispatch", () => {
  const on = "on:\n  pull_request:\n  push:\n  workflow_dispatch:\n";
  const guarded = (job) => `on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n${job}`;
  // compliant: the standard guard
  assert.deepEqual(draftGuardProblems(guarded("  a:\n    if: github.event_name != 'pull_request' || !github.event.pull_request.draft\n    runs-on: macos-latest\n")), []);
  // compliant: dispatch-only job, and a matrix that collapses to ubuntu on drafts
  assert.deepEqual(draftGuardProblems(guarded("  a:\n    if: github.event_name == 'workflow_dispatch'\n    runs-on: macos-latest\n")), []);
  assert.deepEqual(draftGuardProblems(guarded("  a:\n    strategy:\n      matrix:\n        os: ${{ fromJSON(github.event_name == 'pull_request' && github.event.pull_request.draft && '[\"ubuntu-latest\"]' || '[\"ubuntu-latest\",\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n")), []);
  // violations: an unguarded macOS job, and a missing workflow_dispatch trigger
  assert.ok(draftGuardProblems(guarded("  a:\n    runs-on: macos-latest\n")).some((p) => p.includes("macOS job a")), "unguarded job");
  assert.ok(draftGuardProblems("on:\n  pull_request:\n  push:\njobs:\n  a:\n    if: github.event_name != 'pull_request' || !github.event.pull_request.draft\n    runs-on: macos-latest\n").some((p) => p.includes("workflow_dispatch missing")), "missing dispatch trigger");
  // ubuntu-only and workflow_call-only workflows are outside the rule
  assert.deepEqual(draftGuardProblems("on:\n  pull_request:\njobs:\n  a:\n    runs-on: ubuntu-latest\n"), []);
  assert.deepEqual(draftGuardProblems("on:\n  workflow_call:\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
});

test("every macOS workflow in this repository draft-guards its jobs and keeps a dispatch trigger", () => {
  const dir = new URL("../../.github/workflows/", import.meta.url);
  for (const f of fs.readdirSync(dir)) {
    if (!/\.(ya?ml)$/.test(f)) continue;
    const text = fs.readFileSync(new URL(f, dir), "utf8");
    assert.deepEqual(draftGuardProblems(text), [], f);
  }
});

test("macrev2-579-3 regressions: quoted on-keys, dynamic fromJSON matrices and reversed draft guards", () => {
  // a quoted "on" key must not escape the concurrency or draft checks
  const quoted = `"on":\n  pull_request:\n  push:\njobs:\n  a:\n    runs-on: macos-latest\n`;
  assert.ok(macConcurrencyProblems(quoted).length > 0, "quoted on key escaped the concurrency check");
  assert.ok(draftGuardProblems(quoted).length > 0, "quoted on key escaped the draft check");
  // a dynamic fromJSON matrix is a macOS starter even without a literal macos runs-on
  const dyn = `on:\n  pull_request:\n  push:\nconcurrency:\n  group: g-\${{ github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number) || github.run_id }}\n  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\njobs:\n  a:\n    strategy:\n      matrix:\n        os: \${{ fromJSON(github.event_name == 'pull_request' && github.event.pull_request.draft && '[\"ubuntu-latest\"]' || '[\"ubuntu-latest\",\"macos-latest\"]') }}\n    runs-on: \${{ matrix.os }}\n`;
  assert.deepEqual(macConcurrencyProblems(dyn), []);
  // reversed polarity: runs only on drafts, and the OR form is always true on pull_request events
  const rev1 = `on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    if: github.event.pull_request.draft\n    runs-on: macos-latest\n`;
  const rev2 = `on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    if: github.event_name == 'pull_request' || !github.event.pull_request.draft\n    runs-on: macos-latest\n`;
  for (const bad of [rev1, rev2]) {
    assert.ok(draftGuardProblems(bad).some((p) => p.includes("macOS job a")), bad);
  }
});

test("macrevb-579-3 regressions: every matrix/runs-on expression form is recognised as macOS", () => {
  const group = "concurrency:\n  group: g-\${{ github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number) || github.run_id }}\n  cancel-in-progress: \${{ github.event_name == 'pull_request' }}\n";
  const compliant = (jobs) => macConcurrencyProblems(`on:\n  pull_request:\n  push:\n${group}jobs:\n${jobs}`);
  // form 3: block-sequence matrix entries (desktop.yml's native caller)
  assert.deepEqual(compliant("  a:\n    strategy:\n      fail-fast: false\n      matrix:\n        os:\n        - macos-latest\n    uses: modelplan/modelplan/.github/workflows/trusted-mac.yml@8a22050adc0cbcc85e4159e54cbd50647245b6c0\n    with:\n      task: native\n      os: ${{ matrix.os }}\n"), []);
  // form 4a: a dynamic os expression with leading conditions BEFORE fromJSON (ci.yml's collapse) is
  // recognised — with the correct group it is compliant, and without any group it is flagged
  const ciCollapse = "  a:\n    strategy:\n      matrix:\n        os: ${{ (github.event_name == 'merge_group' || (github.event_name == 'pull_request' && github.event.pull_request.draft)) && fromJSON('[\"ubuntu-latest\"]') || fromJSON('[\"ubuntu-latest\",\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n";
  assert.deepEqual(compliant(ciCollapse), []);
  assert.ok(macConcurrencyProblems(`on:\n  pull_request:\n  push:\njobs:\n${ciCollapse}`).length > 0, "ci.yml's collapse form escaped the concurrency policy");
  // form 4b: a matrix forwarded from a job output, and the lowercase fromJson spelling
  assert.deepEqual(compliant("  a:\n    strategy:\n      matrix: ${{ needs.wf.outputs.matrix }}\n    runs-on: ${{ matrix.os }}\n"), []);
  assert.deepEqual(compliant("  a:\n    strategy:\n      matrix:\n        os: ${{ fromJson(needs.wf.outputs.matrix) }}\n    runs-on: ${{ matrix.os }}\n"), []);
  // fail-closed backstop: a macOS mention anywhere (even only in a comment) requires the group
  assert.ok(macConcurrencyProblems("on:\n  pull_request:\n  push:\njobs:\n  a:\n    runs-on: ubuntu-latest # macOS runners are scarce\n").length > 0, "a macOS mention escaped the policy");
  // workflow_call-only and workflow_dispatch-only files stay outside the rule even when they mention macOS
  assert.deepEqual(macConcurrencyProblems("on:\n  workflow_call:\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
  assert.deepEqual(macConcurrencyProblems("on:\n  workflow_dispatch:\njobs:\n  a:\n    runs-on: macos-latest\n"), []);
  // a collapse whose both branches contain macOS is NOT a draft guard (macrevb-579-3's draft
  // control flips the Linux branch to Mac); only an ubuntu-only draft branch counts, and a
  // collapse without any draft clause (e.g. merge_group-only ubuntu) still runs macOS on drafts
  // and is flagged
  const allMac = "on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    strategy:\n      matrix:\n        os: ${{ github.event.pull_request.draft && fromJSON('[\"macos-latest\"]') || fromJSON('[\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n";
  assert.ok(draftGuardProblems(allMac).length > 0, "an all-Mac collapse escaped the draft guard");
  assert.deepEqual(draftGuardProblems("on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    strategy:\n      matrix:\n        os: ${{ github.event.pull_request.draft && fromJSON('[\"ubuntu-latest\"]') || fromJSON('[\"ubuntu-latest\",\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n"), []);
  assert.ok(draftGuardProblems("on:\n  pull_request:\n  push:\n  workflow_dispatch:\njobs:\n  a:\n    strategy:\n      matrix:\n        os: ${{ (github.event_name == 'merge_group') && fromJSON('[\"ubuntu-latest\"]') || fromJSON('[\"macos-latest\"]') }}\n    runs-on: ${{ matrix.os }}\n").length > 0, "a merge_group-only ubuntu branch still runs macOS on drafts");
});
