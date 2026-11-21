// SPDX-License-Identifier: MIT
import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { SETTLE_MS, sweepPlan } from "../mac-compile/sweep.mjs";
import { isWorkflowFile, workflowProblems } from "../workflow-policy.mjs";

const H = "a".repeat(40);
const NOW = Date.UTC(2026, 10, 21, 15, 0, 0);
const old = new Date(NOW - 3 * SETTLE_MS).toISOString();
const pr = (o = {}) => ({ number: 1129, state: "open", draft: false, user: { login: "guanbear", id: 11829005 }, head: { sha: H, repo: { full_name: "modelplan/modelplan" } }, base: { ref: "main", repo: { full_name: "modelplan/modelplan" } }, updated_at: old, ...o });
const native = [{ filename: "desktop/native/A/B.swift" }];
const plan = (o = {}) => sweepPlan({ pr: pr(), files: native, statuses: [], runs: [], trigger: [], now: NOW, ...o }).action;

test("sweep: a ready native PR with no mac-compile status or run gets one dispatched", () => {
  assert.equal(plan(), "compile");
  assert.equal(plan({ trigger: [{ status: "completed", created_at: old }] }), "compile", "an old trigger run does not hide a missing compile");
});

test("sweep: leaves alone what is not missing or not its business", () => {
  assert.equal(plan({ pr: pr({ draft: true }) }), "none");
  assert.equal(plan({ pr: pr({ base: { ref: "other", repo: { full_name: "modelplan/modelplan" } } }) }), "none");
  assert.equal(plan({ pr: pr({ user: { login: "stranger", id: 1 } }) }), "none");
  assert.equal(plan({ files: [{ filename: "cli/main.go" }] }), "none", "no desktop/native change");
  assert.equal(plan({ files: [{ filename: "cli/x.swift", previous_filename: "desktop/native/x.swift" }] }), "compile", "a rename out of desktop/native still needs it");
  assert.equal(plan({ statuses: [{ context: "mac-compile", state: "failure" }] }), "none", "a failed compile is a result, not a missing one");
  assert.equal(plan({ statuses: [{ context: "mac-compile", state: "success" }] }), "none");
  assert.equal(plan({ runs: [{ display_title: `mac-compile PR #1129 @ ${H}`, status: "in_progress" }] }), "none", "a run is already queued");
  assert.equal(plan({ runs: [{ display_title: `mac-compile ${H}`, status: "queued" }] }), "none");
  assert.equal(plan({ runs: [{ display_title: `mac-compile ${H}`, status: "completed" }] }), "compile", "a finished run without a status (cancelled) is retried");
  assert.equal(plan({ trigger: [{ status: "completed", created_at: new Date(NOW - 60000).toISOString() }] }), "none", "the trigger just ran");
  assert.equal(plan({ pr: pr({ updated_at: new Date(NOW - 60000).toISOString() }) }), "none", "the PR just changed");
});

test("sweep: a passed compile that the gate has not seen re-runs the gate", () => {
  const ok = { context: "mac-compile", state: "success" };
  const waiting = { context: "modelplan-gates", state: "pending", description: "waiting for mac-compile at this head; info: x" };
  assert.equal(plan({ statuses: [ok, waiting] }), "gate");
  assert.equal(plan({ statuses: [ok, { ...waiting, description: "running: ci" }] }), "none");
  assert.equal(plan({ statuses: [ok, { ...waiting, state: "success" }] }), "none");
});

test("sweep workflow: schedule, main's scripts only, owner token only in the sweep step, no persisted credentials", () => {
  const p = ".github/workflows/mac-compile-sweep.yml";
  const text = readFileSync(new URL(`../../${p}`, import.meta.url), "utf8");
  assert.ok(isWorkflowFile(p));
  assert.deepEqual(workflowProblems(text, p), []);
  assert.match(text, /cron: "\*\/10 \* \* \* \*"/);
  assert.doesNotMatch(text, /pull_request/);
  assert.match(text, /^permissions:\n  contents: read$/m);
  assert.match(text, /ref: main\n\s+sparse-checkout: scripts\n\s+persist-credentials: false/);
  assert.equal(text.match(/secrets\./g).length, 1);
  assert.match(text, /- run: node scripts\/mac-compile\/sweep\.mjs\n\s+env:\n\s+GH_TOKEN: \$\{\{ secrets\.PR_REVIEW_COMMENT_TOKEN \}\}/);
  assert.doesNotMatch(text, /self-hosted/);
});

test("the mac-compile trigger also runs when a PR is retargeted to main (the missed #1129 trigger)", () => {
  const text = readFileSync(new URL("../../.github/workflows/mac-compile-trigger.yml", import.meta.url), "utf8");
  assert.match(text, /types: \[opened, synchronize, reopened, ready_for_review, edited\]/);
  assert.match(text, /if: \$\{\{ !github\.event\.pull_request\.draft && \(github\.event\.action != 'edited' \|\| github\.event\.changes\.base\) \}\}/);
});
