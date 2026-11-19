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
  R.evaluatePr({ pr, items: R.feed([verdict]), files, runs, statuses: [], verifiedEdge: () => false, conf });
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
