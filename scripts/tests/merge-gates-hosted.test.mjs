// SPDX-License-Identifier: MIT
// D314 item 2: GitHub-hosted macOS legs are post-merge only (scripts/merge-gates/hosted.mjs); self-hosted legs gate.
import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import * as R from "../merge-gates/rules.mjs";
import * as Hs from "../merge-gates/hosted.mjs";
import * as P from "../merge-gates/post-merge.mjs";
import { workflowProblems } from "../workflow-policy.mjs";

const root = new URL("../..", import.meta.url).pathname;
const conf = R.parseDesignConf(readFileSync(join(root, "scripts/merge-gates/design-paths.conf"), "utf8"));
const H = "a".repeat(40), BASE = "b".repeat(40);
const ME = { login: "guanbear", id: 11829005 };
const CI = ".github/workflows/ci.yml", DESKTOP = ".github/workflows/desktop.yml", U7 = ".github/workflows/u7-credential-agent.yml";

let jid = 100;
// A jobs-API record. Hosted: runner group "GitHub Actions" and a macos-* label; self-hosted: the trusted-mac labels.
const HOSTED = { labels: ["macos-latest"], runner_group_name: "GitHub Actions" };
const SELF = { labels: ["self-hosted", "macOS", "ARM64", "modelplan-mac-nongui"], runner_group_name: "modelplan-mac" };
const job = (name, conclusion = "success", where = HOSTED, status = "completed") => ({ id: jid++, name, status, conclusion: status === "completed" ? conclusion : null, ...where });
const linux = (name) => job(name, "success", { labels: ["ubuntu-latest"], runner_group_name: "GitHub Actions" });
const run = (path, conclusion, jobs, { id = 1, status = "completed", ...over } = {}) => ({
  id, workflow_id: path, path, name: path.split("/").pop(), status, conclusion: status === "completed" ? conclusion : null, jobs,
  check_suite_id: 1000 + id, head_sha: H, head_repository: { full_name: "modelplan/modelplan" }, head_branch: "feature/x",
  event: "pull_request", pull_requests: [{ number: 7 }], ...over,
});
const pr = { number: 7, state: "open", draft: false, user: ME, head: { sha: H, ref: "feature/x", repo: { full_name: "modelplan/modelplan" } },
  base: { ref: "main", repo: { full_name: "modelplan/modelplan" } } };
const verdict = { user: ME, body: `VERDICT: merge @ ${H} (macrev2)`, created_at: "2026-11-19T00:00:00Z" };
const evalPr = (runs, files = [{ filename: "desktop/native/Sources/X.swift" }]) =>
  R.evaluatePr({ pr, items: R.feed([verdict]), files, runs, statuses: [{ context: "mac-compile", state: "success" }], verifiedEdge: () => false, conf });
const greenCi = () => run(CI, "success", [linux("checks")], { id: 1 });
// desktop.yml as a PR run: app-smoke hosted, native-headless on whatever `nh` says.
const desktop = (smoke, nh = job("native-headless (macos-latest) / native-headless (macos-latest)", "success", SELF), over = {}) => {
  const jobs = [linux("queue-scope"), linux("app"), smoke, nh].filter(Boolean);
  const bad = jobs.some((j) => j.status === "completed" && !["success", "skipped"].includes(j.conclusion));
  const busy = jobs.some((j) => j.status !== "completed");
  return run(DESKTOP, bad ? "failure" : "success", jobs, { id: 2, status: busy ? "in_progress" : "completed", ...over });
};

test("hosted leg red, cancelled, timed out, pending or missing: the PR gate passes and reports it as info", () => {
  for (const [label, smoke] of [
    ["red", job("app-smoke", "failure")], ["cancelled (no runner)", job("app-smoke", "cancelled")],
    ["timed out", job("app-smoke", "timed_out")], ["pending", job("app-smoke", null, HOSTED, "queued")], ["missing", null],
  ]) {
    const r = evalPr([greenCi(), desktop(smoke)]);
    assert.equal(r.state, R.SUCCESS, label);
    assert.equal(r.hostedExempt, true, label);
    if (smoke) assert.match(r.why, /info: .*post-merge only: app-smoke/, label);
  }
  // A whole hosted-only workflow (u7) red or still waiting for a runner does not hold the PR either.
  assert.equal(evalPr([greenCi(), run(U7, "failure", [job("fake-contract", "failure")], { id: 3 })]).state, R.SUCCESS);
  assert.equal(evalPr([greenCi(), run(U7, null, [job("fake-contract", null, HOSTED, "queued")], { id: 3, status: "queued" })]).state, R.SUCCESS);
  // The hosted u11-native leg (macos-15) and the hosted macOS share of a matrix are set aside too.
  const u11 = run(".github/workflows/u11-native.yml", "failure", [job("native / u11-native (macos-15)", "failure", { labels: ["macos-15"], runner_group_name: "GitHub Actions" })], { id: 4 });
  const drive = run(".github/workflows/u14-engine-drive.yml", "failure", [linux("engine-drive (ubuntu-latest)"), job("engine-drive (macos-latest)", "failure")], { id: 5 });
  assert.equal(evalPr([greenCi(), u11, drive]).state, R.SUCCESS);
});

test("a hosted job cancelled before it got a runner (GitHub's real record) is set aside", () => {
  // Run 44387199596, claude-code-macos: cancelled while waiting; GitHub reports the group as "" with id 0.
  const unassigned = { labels: ["macos-latest"], runner_group_id: 0, runner_group_name: "", runner_id: 0, runner_name: "" };
  const ci = run(CI, "cancelled", [linux("queue-reuse"), linux("checks"), linux("cli"), job("claude-code-macos", "cancelled", unassigned)], { id: 1 });
  const r = evalPr([ci]);
  assert.equal(r.state, R.SUCCESS);
  assert.match(r.why, /post-merge only: claude-code-macos cancelled/);
  // Every "no runner" form counts as unassigned; a named non-hosted group or a self-hosted label stays required.
  for (const g of [null, undefined, ""]) assert.equal(Hs.onHostedMac({ labels: ["macos-15"], runner_group_name: g }), true, String(g));
  assert.equal(Hs.onHostedMac({ labels: ["macos-latest"], runner_group_name: "Default" }), false);
  assert.equal(Hs.onHostedMac({ labels: ["self-hosted", "macos-latest"], runner_group_name: "" }), false);
  assert.equal(evalPr([run(CI, "cancelled", [linux("checks"), job("claude-code-macos", "cancelled", { ...unassigned, labels: ["self-hosted", "macOS"] })], { id: 1 })]).state, R.FAILURE);
});

test("a self-hosted leg red or pending still decides the PR", () => {
  const nh = (c, s) => job("native-headless (macos-latest) / native-headless (macos-latest)", c, SELF, s);
  const red = evalPr([greenCi(), desktop(job("app-smoke", "failure"), nh("failure"))]);
  assert.equal(red.state, R.FAILURE);
  assert.match(red.why, /native-headless .* failure/);
  assert.equal(evalPr([greenCi(), desktop(job("app-smoke", "success"), nh(null, "in_progress"))]).state, R.PENDING);
  // A Linux job fails the run the same way.
  assert.equal(evalPr([greenCi(), desktop(job("app-smoke", "failure"), job("shell", "failure", { labels: ["ubuntu-latest"], runner_group_name: "GitHub Actions" }))]).state, R.FAILURE);
  // A table leg that the owner's variables route to a self-hosted Mac is required there (u4b transport on modelplan-mac-nongui).
  const transport = run(".github/workflows/u4b-engine-client.yml", "failure", [job("transport (macos-latest) / transport", "failure", SELF)], { id: 6 });
  assert.equal(evalPr([greenCi(), transport]).state, R.FAILURE);
  // A run without readable jobs, or a run GitHub refused at parse time, is judged whole (fail closed).
  assert.equal(evalPr([greenCi(), run(DESKTOP, "failure", undefined, { id: 2 })]).state, R.FAILURE);
  assert.equal(evalPr([greenCi(), run(DESKTOP, "startup_failure", [job("app-smoke", "failure")], { id: 2 })]).state, R.FAILURE);
});

test("a renamed or relabelled job cannot dodge the rule", () => {
  // native-headless renamed to a table name but still on a self-hosted Mac: GitHub's runner record keeps it required.
  assert.equal(evalPr([greenCi(), desktop(null, job("app-smoke", "failure", SELF))]).state, R.FAILURE, "rename only");
  // native-headless moved to a hosted label but keeping its name: not in the table, so required.
  assert.equal(evalPr([greenCi(), desktop(null, job("native-headless (macos-latest) / native-headless (macos-latest)", "failure"))]).state, R.FAILURE, "relabel only");
  // Renamed AND relabelled: only possible by editing a workflow, and a workflow change withdraws every exemption.
  const dodge = [greenCi(), desktop(job("app-smoke", "failure"), null)];
  assert.equal(evalPr(dodge, [{ filename: ".github/workflows/desktop.yml" }]).state, R.FAILURE, "rename + relabel");
  assert.equal(evalPr(dodge, [{ filename: "desktop/x.swift" }, { filename: ".github/workflows/trusted-mac.yml" }]).state, R.FAILURE, "via the reusable workflow");
  assert.equal(evalPr(dodge, [{ filename: "x", previous_filename: ".github/workflows/desktop.yml" }]).state, R.FAILURE, "a rename out of workflows");
  assert.match(evalPr(dodge, [{ filename: ".github/workflows/desktop.yml" }]).why, /workflow change: hosted legs gate/);
  // A table job name in a workflow the table does not list for it is required.
  assert.equal(evalPr([greenCi(), run(".github/workflows/u11-cockpit.yml", "failure", [job("app-smoke", "failure")], { id: 7 })]).state, R.FAILURE, "another workflow");
  // A hosted label without GitHub's hosted runner group (a self-hosted runner labelled macos-latest) is required.
  assert.equal(evalPr([greenCi(), desktop(job("app-smoke", "failure", { labels: ["macos-latest"], runner_group_name: "Default" }))]).state, R.FAILURE, "fake hosted label");
  // A file list at the API cap may hide a workflow change.
  const many = Array.from({ length: R.FILE_LIST_LIMIT }, (_, i) => ({ filename: `docs/f${i}.md` }));
  assert.equal(evalPr([greenCi(), desktop(job("app-smoke", "failure"))], many).state, R.FAILURE, "truncated file list");
});

test("an unfinished run whose only visible pending job is not a hosted leg keeps waiting", () => {
  // app-smoke done (red), native-headless not yet listed: something else may still start, so the run is pending.
  const r = evalPr([greenCi(), desktop(job("app-smoke", "failure"), null, { status: "in_progress", conclusion: null })]);
  assert.equal(r.state, R.PENDING);
});

test("merge group: hosted legs never gate; self-hosted legs and workflow changes do", () => {
  const qrun = (path, conclusion, jobs, id) => run(path, conclusion, jobs, { id, head_branch: `gh-readonly-queue/main/pr-7-${BASE}`, event: "merge_group", pull_requests: [] });
  const gui = { name: "queue-scope", steps: [{ name: R.GUI_NOT_NEEDED_STEP, conclusion: "success" }] };
  const smoke = (c, s) => job("app-smoke", c, HOSTED, s);
  const nh = (c) => job("native-headless (macos-latest) / native-headless (macos-latest)", c, SELF);
  const group = (smokeJob, nhJob, prResult) => {
    const djobs = [{ ...linux("queue-scope"), ...gui }, smokeJob, nhJob];
    const busy = djobs.some((j) => j.status !== "completed"), bad = djobs.some((j) => j.status === "completed" && !["success", "skipped"].includes(j.conclusion));
    const d = qrun(DESKTOP, bad ? "failure" : "success", djobs, 2);
    if (busy) { d.status = "in_progress"; d.conclusion = null; }
    const others = R.QUEUE_WORKFLOWS.filter((p) => p !== DESKTOP).map((p, i) => qrun(p, "success", [linux("x")], 10 + i));
    const queueRuns = [d, ...others];
    const queueCheckRuns = queueRuns.flatMap((r) => r.jobs.map((j) => ({ id: j.id, name: j.name, status: j.status, conclusion: j.conclusion, check_suite: { id: r.check_suite_id } })));
    return R.evaluateGroup({ steps: [{ pr: 7, prResult, mergeProof: { ok: true } }], queueRuns, queueCheckRuns, desktopJobs: d.jobs, now: Date.parse("2026-11-19T00:00:00Z") });
  };
  const ok = { state: R.SUCCESS, why: "ok", hostedExempt: true };
  assert.equal(group(smoke("failure"), nh("success"), ok).state, R.SUCCESS, "hosted red");
  assert.equal(group(smoke(null, "queued"), nh("success"), ok).state, R.SUCCESS, "hosted waiting for a runner");
  assert.equal(group(smoke("cancelled"), nh("success"), ok).state, R.SUCCESS, "hosted cancelled");
  assert.equal(group(smoke("success"), nh("failure"), ok).state, R.FAILURE, "self-hosted red");
  assert.equal(group(smoke("failure"), nh("success"), { ...ok, hostedExempt: false }).state, R.FAILURE, "a member changed a workflow");
  assert.equal(group(smoke("failure"), nh("success"), { state: R.SUCCESS, why: "ok" }).state, R.FAILURE, "unknown = not exempt");
  // The real PR result carries the flag through.
  const head = evalPr([greenCi(), desktop(smoke("failure"))]);
  assert.equal(group(smoke("failure"), nh("success"), head).state, R.SUCCESS);
});

// Events that start a GitHub Actions workflow (docs: "Events that trigger workflows"). Webhook-only events such as
// workflow_job are accepted by YAML but never start a run (actionlint: "unknown Webhook event").
const ACTIONS_EVENTS = new Set(["branch_protection_rule", "check_run", "check_suite", "create", "delete", "deployment",
  "deployment_status", "discussion", "discussion_comment", "fork", "gollum", "image_version", "issue_comment", "issues", "label",
  "merge_group", "milestone", "page_build", "project", "project_card", "project_column", "public", "pull_request",
  "pull_request_review", "pull_request_review_comment", "pull_request_target", "push", "registry_package", "release",
  "repository_dispatch", "schedule", "status", "watch", "workflow_call", "workflow_dispatch", "workflow_run"]);
function onEvents(text) {
  const lines = text.split("\n");
  const at = lines.findIndex((l) => /^(on|'on'|"on"):/.test(l));
  if (at < 0) return null;
  const inline = lines[at].replace(/^(on|'on'|"on"):\s*/, "").replace(/\s+#.*$/, "").trim();
  if (inline) return inline.replace(/^\[|\]$/g, "").split(",").map((x) => x.trim()).filter(Boolean);
  const out = [];
  for (const l of lines.slice(at + 1)) {
    if (/^\S/.test(l)) break;
    const m = /^ {2}([A-Za-z_]+):/.exec(l);
    if (m) out.push(m[1]);
  }
  return out;
}

test("every workflow triggers only on events GitHub Actions supports (no webhook-only workflow_job)", () => {
  const unsupported = (text) => (onEvents(text) ?? []).filter((e) => !ACTIONS_EVENTS.has(e));
  for (const f of readdirSync(join(root, ".github/workflows")).filter((f) => /\.ya?ml$/.test(f))) {
    const events = onEvents(readFileSync(join(root, ".github/workflows", f), "utf8"));
    assert.ok(events?.length, `${f}: no on: events found`);
    assert.deepEqual(unsupported(readFileSync(join(root, ".github/workflows", f), "utf8")), [], f);
  }
  // The checker itself catches the D314 head a0ad63fd form and the inline forms.
  assert.deepEqual(unsupported("name: x\non:\n  workflow_run:\n    types: [completed]\n  workflow_job:\n    types: [completed]\njobs:\n"), ["workflow_job"]);
  assert.deepEqual(unsupported("on: [push, workflow_job]\n"), ["workflow_job"]);
  assert.deepEqual(unsupported("'on':\n  push:\n"), []);
});

test("hosted legs never start on pull_request or merge_group, so no PR or group run waits for a hosted Mac", () => {
  // Any run the gate reads then completes when its required jobs do, and its workflow_run re-evaluates the gate.
  // Callers of trusted-mac.yml keep a pre-merge macOS leg only where the owner's variable routes it to a self-hosted Mac.
  const routed = {
    "u11-native": `(${Hs.PRE_MERGE_SKIP} || vars.MAC_CI_NONGUI == 'enabled')`,
    // trusted-mac.yml routes these by MAC_CI_RUNNER_V2; the caller keeps main's draft-only matrix and runs in no merge group.
    transport: `os: \${{ fromJSON(github.event_name == 'pull_request' && github.event.pull_request.draft && '["ubuntu-latest"]' || '["ubuntu-latest","macos-latest"]') }}`,
    sequences: `os: \${{ fromJSON(github.event_name == 'pull_request' && github.event.pull_request.draft && '["ubuntu-latest"]' || '["ubuntu-latest","macos-latest"]') }}`,
  };
  for (const f of ["u4b-engine-client.yml", "u6-engine-store-core.yml"])
    assert.ok(!onEvents(wfText(`.github/workflows/${f}`)).includes("merge_group"), `${f}: a routed PR leg must not join merge groups`);
  for (const leg of Hs.HOSTED_MAC_LEGS) {
    const lines = jobBlocks(wfText(leg.workflow)).get(leg.key);
    assert.ok(lines, `${leg.workflow}: job ${leg.key}`);
    const ifLine = lines.find((l) => /^    if:/.test(l)) ?? "";
    const osLine = lines.find((l) => /^        os:/.test(l)) ?? "";
    if (/^    if: \$\{\{ github\.event_name == 'workflow_dispatch' \}\}$/.test(ifLine)) continue; // dispatch only (e2e-journey)
    const want = routed[leg.key === "native" ? "u11-native" : leg.key];
    if (want) { assert.ok((ifLine + osLine).includes(want), `${leg.workflow} ${leg.key}: routed guard`); continue; }
    if (osLine) {
      assert.ok(osLine.includes(`${Hs.PRE_MERGE_SKIP} && '["ubuntu-latest","macos-latest"]' || '["ubuntu-latest"]'`), `${leg.workflow} ${leg.key}: macOS matrix leg is main-only`);
      continue;
    }
    assert.match(ifLine, /^    if: \$\{\{ .* \}\}$/, `${leg.workflow} ${leg.key}: if is an expression`);
    assert.ok(ifLine.endsWith(` && ${Hs.PRE_MERGE_SKIP} }}`), `${leg.workflow} ${leg.key}: if ends with the pre-merge skip`);
    // A top-level || would let a pre-merge event through the guard: the guard is the last &&-term of the whole expression.
    const body = ifLine.replace(/^    if: \$\{\{ /, "").replace(` && ${Hs.PRE_MERGE_SKIP} }}`, "");
    let depth = 0, topOr = false;
    for (let k = 0; k < body.length; k++) { const c = body[k]; if (c === "(") depth++; else if (c === ")") depth--; else if (!depth && body.startsWith("||", k)) topOr = true; }
    assert.equal(topOr, false, `${leg.workflow} ${leg.key}: no top-level || before the guard`);
  }
  // Every guarded workflow still passes the source policy (no caller may name the self-hosted route: check-source-policy).
  for (const p of [...Hs.HOSTED_WORKFLOWS, ".github/workflows/merge-gates.yml"]) assert.deepEqual(workflowProblems(wfText(p), p), [], p);
  // merge-gates.yml re-evaluates on workflow_run only; nothing job-level.
  const gates = wfText(".github/workflows/merge-gates.yml");
  assert.deepEqual(onEvents(gates), ["issue_comment", "workflow_run", "workflow_dispatch"]);
  assert.doesNotMatch(gates, /github\.event\.workflow_job/);
});

// ---- The table against main's workflows ----
const wfText = (p) => readFileSync(join(root, p), "utf8");
function jobBlocks(text) {
  const lines = text.split("\n"), start = lines.findIndex((l) => /^jobs:/.test(l));
  const jobs = new Map();
  let cur = null;
  for (const line of lines.slice(start + 1)) {
    if (/^[A-Za-z_"'-]+:/.test(line)) break;
    const m = /^  ([A-Za-z][\w-]*):\s*$/.exec(line);
    if (m) { cur = []; jobs.set(m[1], cur); continue; }
    if (cur) cur.push(line);
  }
  return jobs;
}
const needsOf = (lines) => {
  const l = lines.find((x) => /^    needs:/.test(x));
  if (!l) return [];
  const v = l.replace(/^    needs:\s*/, "").trim();
  return v.startsWith("[") ? v.slice(1, -1).split(",").map((s) => s.trim()) : [v];
};

test("every table leg is a macOS job of that workflow on main, and no job waits for one", () => {
  for (const leg of Hs.HOSTED_MAC_LEGS) {
    assert.ok(existsSync(join(root, leg.workflow)), leg.workflow);
    const jobs = jobBlocks(wfText(leg.workflow));
    const lines = jobs.get(leg.key);
    assert.ok(lines, `${leg.workflow}: job ${leg.key}`);
    assert.ok(lines.some((l) => /^\s*(runs-on|os):.*macos|^\s*-\s*macos|workflows\/trusted-mac\.yml/.test(l)) || lines.some((l) => /macos-latest/.test(l)), `${leg.key} runs on macOS`);
    for (const [name, other] of jobs) assert.ok(!needsOf(other).includes(leg.key), `${leg.workflow}: ${name} needs hosted leg ${leg.key}`);
  }
  // The GUI leg, native-headless and the mac-compile check are never in the table.
  for (const leg of Hs.HOSTED_MAC_LEGS) assert.ok(!/native-headless|native-owner-gui|native-hosted|^native \(|compile/.test(leg.name.source.replace(/\\/g, "")), leg.name.source);
  assert.equal(Hs.isHostedMacLeg(DESKTOP, job("native (macos-latest) / native (macos-latest)", "failure")), false, "GUI leg on a hosted fallback stays required");
  assert.equal(Hs.isHostedMacLeg(DESKTOP, job("native-hosted (macos-15) / native-hosted-gui (macos-15)", "failure")), false);
  assert.equal(Hs.isHostedMacLeg(".github/workflows/mac-compile.yml", job("compile", "failure")), false);
});

test("post-merge workflow: valid shape, follows exactly the workflows that hold hosted legs, never gates", () => {
  const path = ".github/workflows/post-merge-hosted.yml";
  const text = wfText(path);
  assert.deepEqual(workflowProblems(text, path), []);
  assert.doesNotMatch(text, /\t/, "YAML has no tabs");
  const on = text.slice(text.indexOf("\non:"), text.indexOf("\npermissions:"));
  assert.deepEqual([...on.matchAll(/^ {2}([a-z_]+):/gm)].map((m) => m[1]), ["workflow_run", "workflow_dispatch"], "runs main's copy only");
  assert.match(on, /^ {4}branches: \[main\]$/m);
  const names = [...on.matchAll(/^ {6}- (.+)$/gm)].map((m) => m[1]).sort();
  const want = Hs.HOSTED_WORKFLOWS.map((p) => /^name: (.+)$/m.exec(wfText(p))[1].trim()).sort();
  assert.deepEqual(names, want, "workflow_run names match each workflow's name:");
  const perms = text.slice(text.indexOf("\npermissions:"), text.indexOf("\nconcurrency:"));
  assert.deepEqual(perms.split("\n").filter((l) => /write/.test(l)).map((l) => l.trim()), ["issues: write"], "no statuses or checks write");
  assert.match(text, /ref: \$\{\{ github\.event\.repository\.default_branch \}\}/);
  assert.match(text, /github\.event\.workflow_run\.event == 'push' && github\.event\.workflow_run\.head_branch == 'main'/);
  assert.ok(!readFileSync(join(root, ".github/workflows/merge-gates.yml"), "utf8").includes("post-merge hosted legs"), "the gate never follows it");
  // Full YAML parse where PyYAML is available (skipped otherwise; the shape checks above always run).
  const py = spawnSync("python3", ["-c", "import sys, yaml; d = yaml.safe_load(open(sys.argv[1])); assert d['jobs']['report']['runs-on'] == 'ubuntu-latest'; assert True in d or 'on' in d", join(root, path)], { encoding: "utf8" });
  if (!/No module named/.test(py.stderr)) assert.equal(py.status, 0, py.stderr);
  // Every workflow file under .github/workflows that is new here still passes the shared policy.
  for (const f of readdirSync(join(root, ".github/workflows")).filter((f) => f.startsWith("post-merge")))
    assert.deepEqual(workflowProblems(wfText(`.github/workflows/${f}`), `.github/workflows/${f}`), [], f);
});

test("post-merge report: picks main's newest real run, lists red hosted legs with their first failing test", () => {
  const mk = (id, conclusion, over = {}) => ({ id, conclusion, status: "completed", event: "push", head_branch: "main", ...over });
  assert.equal(P.pickRun([mk(1, "failure"), mk(3, "cancelled"), mk(2, "success"), mk(4, "failure", { event: "pull_request" })]).id, 2);
  assert.equal(P.pickRun([mk(5, "skipped")]), null);
  const r = { id: 9, path: DESKTOP, name: "desktop", head_sha: H, html_url: "https://x/run/9" };
  const rows = P.redRows(r, [job("app-smoke", "failure"), job("cockpit-spi-tests", "cancelled", { labels: ["macos-15"], runner_group_name: "GitHub Actions" }),
    job("native-headless (macos-latest) / native-headless (macos-latest)", "failure", SELF), linux("shell")]);
  assert.deepEqual(rows.map((x) => x.job), ["app-smoke"], "only red hosted legs; self-hosted red is main-red.sh's");
  assert.equal(P.firstFailure("2026-11-19T01:02:03.4Z Test Case '-[ModelPlanTests.FooTests testBar]' failed (1.2 seconds).\n"), "Test Case '-[ModelPlanTests.FooTests testBar]' failed");
  assert.equal(P.firstFailure("ok\n--- FAIL: TestX (0.1s)\n"), "--- FAIL: TestX");
  assert.equal(P.firstFailure("", { steps: [{ name: "Build", conclusion: "failure" }] }), "step Build");
  rows[0].test = "Test Case x | y --> z";
  const body = P.renderBody(rows, "modelplan/modelplan");
  assert.match(body, /\| \[`aaaaaaaaaaaa`\]\(https:\/\/github\.com\/modelplan\/modelplan\/commit\/a{40}\) \| desktop \| app-smoke \(failure\) \|/);
  assert.deepEqual(P.parseState(body).map((x) => x.job_id), [rows[0].job_id], "state round-trips");
  assert.deepEqual(P.plan(null, rows).action, "create");
  assert.deepEqual(P.plan(null, []).action, "none");
  assert.deepEqual(P.plan({ body }, rows), { action: "update", fresh: [] });
  assert.equal(P.plan({ body }, [{ ...rows[0], job_id: 1 }]).fresh.length, 1, "a new red job is announced");
  assert.equal(P.plan({ body }, []).action, "close");
});

// S10 (post-merge sampling 2026-11-19): every hosted leg #1067 moved post-merge must actually run on main after a merge.
// PATHS (workflow: how its hosted leg reaches main). Every one is `push: branches: [main]` with the leg's own `if:`
// letting push through (the if-guard test above); post-merge-hosted.yml then follows the workflow by name.
//   ci, desktop, dock-host-port, e2e-journey*, macos-distribution, official-dock, repo-checks, u10-candidate, u11-native,
//   u14-engine-drive, u14-macos (was MISSING), u4-swift-wire, u4b-engine-client, u6-engine-store-core, u7-credential-agent,
//   u7-helper-producer, verification-pointer-helper.   * e2e-journey is dispatch-only by design (legacy app, frozen).
test("every hosted leg's workflow runs on pushes to main (or is dispatch-only by design)", () => {
  for (const leg of Hs.HOSTED_MAC_LEGS) {
    const ifLine = (jobBlocks(wfText(leg.workflow)).get(leg.key) ?? []).find((l) => /^    if:/.test(l)) ?? "";
    if (/^    if: \$\{\{ github\.event_name == 'workflow_dispatch' \}\}$/.test(ifLine)) continue;
    const text = wfText(leg.workflow);
    assert.ok(onEvents(text).includes("push"), `${leg.workflow}: no push trigger, so ${leg.key} never runs on main after a merge`);
    const wl = text.split("\n"), at = wl.findIndex((l) => /^on:/.test(l));
    const on = wl.slice(at, at + 1 + wl.slice(at + 1).findIndex((l) => /^\S/.test(l))).join("\n");
    assert.match(on, /^ {2}push:\n {4}branches: \[main\]/m, `${leg.workflow}: push is limited to main`);
  }
});

// S9: a skipped, cancelled or unfinished hosted leg says nothing about main, so it must not close the failure issue.
// PATHS over the issue state (rows = open issue's red legs): per workflow, newest counted main run ->
//   leg failed/timed_out -> row (new or kept) | leg success/neutral -> row dropped (green) |
//   leg skipped/cancelled/running -> previous row KEPT | leg absent from the run -> row dropped (leg gone) |
//   workflow has no counted run on main -> previous rows KEPT.  Issue: no rows & none open -> none; rows & none open ->
//   create; rows & open -> update (+comment on a new job); no rows & open -> close (only when every leg above is green/gone).
test("post-merge report: a skipped leg leaves the failure issue as it was", () => {
  const run = { id: 20, path: DESKTOP, name: "desktop", head_sha: H, html_url: "https://x/run/20" };
  const prev = [{ job_id: 7, job: "app-smoke", conclusion: "failure", workflow: "desktop", run_id: 10, sha: BASE, url: "https://x/job/7", test: "t1" },
    { job_id: 8, job: "cockpit-spi-tests", conclusion: "failure", workflow: "desktop", run_id: 10, sha: BASE, url: "https://x/job/8", test: "t2" },
    { job_id: 9, job: "contracts", conclusion: "failure", workflow: "Dock host port seam", run_id: 11, sha: BASE, url: "https://x/job/9", test: "t3" }];
  const names = (rows) => rows.map((r) => r.job).sort();
  const skipped = P.reconcile(prev, run, [job("app-smoke", "skipped"), job("cockpit-spi-tests", "skipped")]);
  assert.deepEqual(names(skipped), ["app-smoke", "cockpit-spi-tests"], "skipped: unchanged");
  assert.deepEqual(names(P.reconcile(prev, run, [job("app-smoke", "cancelled"), job("cockpit-spi-tests", "success")])), ["app-smoke"], "cancelled keeps, success clears");
  assert.deepEqual(names(P.reconcile(prev, run, [job("app-smoke", "success"), job("cockpit-spi-tests", "success")])), [], "green clears");
  assert.deepEqual(names(P.reconcile(prev, run, [job("app-smoke", "failure"), linux("shell")])), ["app-smoke", "cockpit-spi-tests"], "red stays, an absent trusted leg keeps its row");
  assert.deepEqual(names(P.carryOver(prev, [run])), ["contracts"], "a workflow with no counted run keeps its rows");
  assert.equal(P.plan({ body: P.renderBody(prev, "modelplan/modelplan") }, skipped).action, "update", "never close");
});

// macrevd P2s on #1080: absent or metadata-less records never clear a row; an older run never clears a newer failure.
test("post-merge report: only a qualifying success of the same or a newer run clears a row", () => {
  const mk = (id) => ({ id, path: DESKTOP, name: "desktop", head_sha: H, html_url: "https://x/run/" + id });
  const row = (job_, run_id, path) => ({ job_id: run_id, job: job_, conclusion: "failure", workflow: "desktop", path, run_id, sha: BASE, url: "u", test: "t" });
  const prev = [row("app-smoke", 50, DESKTOP), row("cockpit-spi-tests", 50)];
  const names = (rows) => rows.map((r) => r.job).sort();
  const both = ["app-smoke", "cockpit-spi-tests"];
  const noMeta = { ...job("app-smoke", "skipped"), labels: [], runner_group_name: null };
  assert.deepEqual(names(P.reconcile(prev, mk(60), [])), both, "absent jobs keep every row");
  assert.deepEqual(names(P.reconcile(prev, mk(60), [noMeta, job("cockpit-spi-tests", "success", SELF)])), both, "no runner metadata / self-hosted success does not clear");
  assert.deepEqual(names(P.reconcile(prev, mk(40), [job("app-smoke", "success"), job("cockpit-spi-tests", "success")])), both, "an older green run keeps newer failures");
  assert.deepEqual(names(P.reconcile(prev, mk(40), [job("app-smoke", "failure")])), both, "an older red run adds no row and keeps the newer one");
  assert.equal(P.reconcile(prev, mk(40), [job("app-smoke", "failure")]).find((r) => r.job === "app-smoke").run_id, 50);
  assert.deepEqual(names(P.reconcile(prev, mk(50), [job("app-smoke", "success"), job("cockpit-spi-tests", "success")])), [], "the same run's retry clears");
  assert.deepEqual(names(P.reconcile(prev, mk(70), [job("app-smoke", "success"), job("cockpit-spi-tests", "success")])), [], "a newer success clears");
  assert.deepEqual(names(P.reconcile([row("retired-leg", 50, DESKTOP)], mk(60), [])), [], "a leg retired from the trusted table is dropped");
});

// macrevd P2 on #1083: rows group by workflow path; retired workflows are not carried forward.
test("post-merge report: rows reconcile by workflow path and retired workflows drop", () => {
  const run = { id: 60, path: DESKTOP, name: "desktop renamed", head_sha: H, html_url: "https://x/run/60" };
  const row = (job_, path, workflow = "desktop") => ({ job_id: 5, job: job_, conclusion: "failure", workflow, path, run_id: 50, sha: BASE, url: "u", test: "t" });
  const names = (rows) => rows.map((r) => r.job).sort();
  assert.deepEqual(names(P.reconcile([row("app-smoke", DESKTOP)], run, [job("app-smoke", "success")])), [], "old display name, same path: a success clears");
  assert.deepEqual(names(P.reconcile([row("claude-code-macos", CI, "desktop renamed")], run, [job("app-smoke", "success")])), [], "another path's row is not this run's");
  assert.deepEqual(names(P.carryOver([row("app-smoke", DESKTOP)], [run])), [], "carried only when its workflow had no run");
  assert.deepEqual(names(P.carryOver([row("app-smoke", DESKTOP), row("app-smoke", ".github/workflows/gone.yml")], [])), ["app-smoke"], "a retired workflow's row is dropped from carry-over");
  assert.deepEqual(names(P.carryOver([row("retired-leg", DESKTOP)], [])), [], "a retired leg is dropped from carry-over");
  assert.deepEqual(names(P.carryOver([{ ...row("app-smoke", undefined), path: undefined }], [{ ...run, name: "desktop" }])), [], "legacy row without path groups by name");
});
