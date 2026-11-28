// SPDX-License-Identifier: MIT
// D486 (owner 2026-11-28): hosted overflow for a mac-compile run stuck on the owner pool.
import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { OVERFLOW_MS, overflowPlan, titleHead, watchStep } from "../mac-compile/overflow.mjs";
import { isWorkflowFile, workflowProblems } from "../workflow-policy.mjs";

const H = "a".repeat(40), H2 = "b".repeat(40);
const NOW = Date.UTC(2026, 10, 28, 9, 0, 0);
const ago = (ms) => new Date(NOW - ms).toISOString();
const OWNER = ["self-hosted", "macOS", "ARM64", "modelplan-compile"];
const run = (o = {}) => ({ id: 1, status: "in_progress", display_title: `mac-compile ${H}`, ...o });
const compile = (o = {}) => ({ name: "compile", status: "queued", labels: OWNER, created_at: ago(OVERFLOW_MS + 1000), ...o });
const step = (r, jobs) => watchStep({ run: r, jobs, now: NOW }).action;

test("titleHead: both PR titles, nothing else", () => {
  assert.deepEqual(titleHead(`mac-compile ${H}`), { pr: null, sha: H });
  assert.deepEqual(titleHead(`mac-compile PR #1234 @ ${H}`), { pr: 1234, sha: H });
  for (const t of ["mac-compile PR #1234", "mac-compile", "", undefined, `mac-compile ${H.slice(1)}`, `mac-compile PR #1 @ ${H} x`]) assert.equal(titleHead(t), null, String(t));
});

test("watchStep: overflow only after more than 5 minutes queued on the owner pool", () => {
  assert.equal(step(run(), [compile()]), "overflow");
  assert.equal(step(run({ display_title: `mac-compile PR #7 @ ${H}` }), [compile()]), "overflow");
  assert.equal(step(run(), [compile({ created_at: ago(OVERFLOW_MS - 1000) })]), "wait", "under 5 minutes");
  assert.equal(step(run(), [compile({ created_at: ago(OVERFLOW_MS) })]), "wait", "exactly 5 minutes is not over");
  assert.equal(step(run(), [compile({ status: "waiting" })]), "overflow");
  assert.equal(step(run(), []), "wait", "plan still running");
  assert.equal(step(run(), [compile({ created_at: undefined })]), "wait");
  // the clock starts when the plan job finished, not when GitHub created the waiting job
  const planDone = (ms) => ({ name: "plan", status: "completed", conclusion: "success", completed_at: ago(ms) });
  assert.equal(step(run(), [planDone(OVERFLOW_MS + 2000), compile()]), "overflow");
  assert.equal(step(run(), [planDone(OVERFLOW_MS - 1000), compile()]), "wait", "created early, but plan finished under 5 minutes ago");
  assert.equal(step(run(), [{ name: "plan", status: "in_progress" }, compile()]), "wait");
});

test("watchStep: stops for a picked-up, finished, hosted, seed or non-owner run", () => {
  assert.equal(step(run(), [compile({ status: "in_progress" })]), "stop");
  assert.equal(step(run(), [compile({ status: "completed", conclusion: "success" })]), "stop");
  assert.equal(step(run(), [compile({ status: "completed", conclusion: "skipped" })]), "stop", "hosted pool or nothing to compile");
  assert.equal(step(run({ status: "completed", conclusion: "cancelled" }), [compile()]), "stop");
  assert.equal(step(run({ display_title: "mac-compile" }), [compile()]), "stop", "a seed run");
  assert.equal(step(run({ display_title: "mac-compile PR #7" }), [compile()]), "stop", "dispatch without sha");
  assert.equal(step(run(), [compile({ labels: ["macos-15"] })]), "stop");
});

const pr = (o = {}) => ({ number: 7, state: "open", user: { login: "guanbear", id: 11829005 }, head: { sha: H, repo: { full_name: "modelplan/modelplan" } }, base: { ref: "main", repo: { full_name: "modelplan/modelplan" } }, ...o });
const plan = (o = {}) => overflowPlan({ pr: pr(), sha: H, statuses: [], others: [], ...o }).dispatch;
const hostedJob = (o = {}) => ({ name: "compile-hosted", status: "queued", labels: ["macos-15"], ...o });

test("overflowPlan: once per head, for the PR's current head, never over a success", () => {
  assert.equal(plan(), true);
  assert.equal(plan({ statuses: [{ context: "mac-compile", state: "failure" }] }), true, "a failure may be retried on the other pool");
  assert.equal(plan({ statuses: [{ context: "mac-compile", state: "success" }] }), false);
  for (const j of [hostedJob(), hostedJob({ status: "in_progress" }), hostedJob({ status: "completed", conclusion: "failure" }), hostedJob({ status: "completed", conclusion: "success" })])
    assert.equal(plan({ others: [{ run: {}, jobs: [j] }] }), false, `${j.status}/${j.conclusion}`);
  assert.equal(plan({ others: [{ run: {}, jobs: [hostedJob({ status: "completed", conclusion: "skipped" }), compile()] }] }), true, "an owner run is not an overflow");
  assert.equal(plan({ pr: pr({ head: { sha: H2, repo: { full_name: "modelplan/modelplan" } } }) }), false, "the PR moved on");
  assert.equal(plan({ pr: null }), false);
  assert.equal(plan({ pr: pr({ state: "closed" }) }), false);
  assert.equal(plan({ pr: pr({ base: { ref: "release", repo: { full_name: "modelplan/modelplan" } } }) }), false);
  assert.equal(plan({ pr: pr({ user: { login: "x", id: 1 } }) }), false);
  assert.equal(plan({ pr: pr({ head: { sha: H, repo: { full_name: "fork/modelplan" } } }) }), false);
});

test("overflow workflow: follows mac-compile requests, main's scripts only, owner token only in the watch step, hosted", () => {
  const p = ".github/workflows/mac-compile-overflow.yml";
  const text = readFileSync(new URL(`../../${p}`, import.meta.url), "utf8");
  assert.ok(isWorkflowFile(p));
  assert.deepEqual(workflowProblems(text, p), []);
  assert.match(text, /^on:\n  workflow_run:\n    workflows: \[mac-compile\]\n    types: \[requested\]\npermissions:/m);
  const code = text.split("\n").filter((l) => !/^\s*#/.test(l)).join("\n");
  assert.doesNotMatch(code, /pull_request|self-hosted|macos/);
  assert.match(text, /^permissions:\n  contents: read\n  actions: read\n/m);
  assert.doesNotMatch(text, /:\s*write\b/);
  assert.match(text, /ref: main\n\s+sparse-checkout: scripts\n\s+persist-credentials: false/);
  assert.equal(text.match(/secrets\./g).length, 1);
  assert.match(text, /- run: node scripts\/mac-compile\/overflow\.mjs\n\s+env:\n\s+GH_TOKEN: \$\{\{ secrets\.PR_REVIEW_COMMENT_TOKEN \}\}/);
  assert.match(text, /if: github\.repository == 'modelplan\/modelplan' && github\.ref == 'refs\/heads\/main' && github\.event\.workflow_run\.head_branch == 'main' && github\.event\.workflow_run\.path == '\.github\/workflows\/mac-compile\.yml'/);
});
