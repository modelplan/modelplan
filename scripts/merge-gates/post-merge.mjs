// SPDX-License-Identifier: MIT
// D314 item 2: the post-merge report for GitHub-hosted macOS legs (hosted.mjs). Run by post-merge-hosted.yml from the
// default branch whenever a workflow that holds such a leg finishes on main, and by hand (workflow_dispatch).
//
// Every run recomputes the whole picture, so a skipped or superseded event loses nothing: for each workflow in
// HOSTED_WORKFLOWS it reads the newest finished push run on main (cancelled and skipped runs do not count) and its
// jobs. A hosted leg that failed or timed out there is a red row. The rows go into ONE open issue labelled
// `post-merge-red`: created when the first row appears, its body rewritten on every change, a comment added when a new
// red row appears (so watchers get an event), and closed once no row is left. Nothing here fails the workflow or posts
// a commit status: a red hosted leg never stops the merge line; the coordinator turns the issue into a fix-main task.
//
//   node scripts/merge-gates/post-merge.mjs [--dry-run]     needs GITHUB_TOKEN (issues: write) and GITHUB_REPOSITORY
import { client } from "./github.mjs";
import { HOSTED_MAC_LEGS, HOSTED_WORKFLOWS, isHostedMacLeg } from "./hosted.mjs";

export const LABEL = "post-merge-red";
export const TITLE = "Post-merge: hosted macOS leg red on main";
const STATE_RE = /<!-- post-merge-red-state (.*?) -->/s;
const RED = new Set(["failure", "timed_out"]);
const GREEN = new Set(["success", "neutral"]);
const COUNTED = new Set(["success", "failure", "timed_out", "neutral"]);

// The run that speaks for a workflow on main: the newest finished push run that was not cancelled or skipped.
export function pickRun(runs) {
  return [...runs].filter((r) => r.event === "push" && r.head_branch === "main" && r.status === "completed" && COUNTED.has(r.conclusion))
    .sort((a, b) => b.id - a.id)[0] ?? null;
}

// The red rows of one run: its hosted legs that failed or timed out.
export function redRows(run, jobs) {
  return jobs.filter((j) => isHostedMacLeg(run.path, j) && j.status === "completed" && RED.has(j.conclusion)).map((j) => ({
    job_id: j.id, job: j.name, conclusion: j.conclusion, workflow: run.name, path: runPath(run), run_id: run.id,
    sha: run.head_sha, url: j.html_url ?? run.html_url, test: null,
  }));
}

// The rows one workflow contributes, given the previous rows (from the open issue) and its newest counted main run.
// Invariants (macrevd P2s on #1080):
//  1. A row is cleared ONLY by a qualifying success: a job of this run that is a trusted hosted leg (isHostedMacLeg)
//     and completed success/neutral. Skipped, cancelled, running, absent, or a record without runner metadata says
//     nothing and keeps the row. A row is dropped without a success only when its leg is retired from the trusted table.
//  2. A newer record is never overwritten by an older run: a row from run N is cleared (or replaced) only by a run
//     with id >= N (the same run counts: its completed retry reports the latest attempt).
// PATHS per prev row: retired leg -> drop | run.id < row.run_id -> keep | qualifying success -> drop | red hosted leg ->
// replaced by the new red row | anything else -> keep.  New red leg (no prev row) -> add; red in a run older than its
// prev row -> prev row stays, no new row.
// Invariant (macrevd P2 on #1083): a row belongs to a workflow by its PATH when it stores one (the display name can
// change); only a legacy row without a path falls back to the display name. A row whose leg is no longer in the
// trusted table is dropped on EVERY path (reconciled or carried), before it can be kept.
// PATHS: group = same path (or legacy name) | clear = qualifying success of the same/newer run of that path |
// carry = workflow had no counted run: keep only rows still in the table | retired workflow or leg -> drop.
const runPath = (run) => String(run.path ?? "").split("@")[0];
const belongs = (r, run) => (r.path ? r.path === runPath(run) : r.workflow === run.name);
const inTable = (r) => HOSTED_MAC_LEGS.some((l) => l.name.test(String(r.job)) && (!r.path || l.workflow === r.path));
export function reconcile(prevRows, run, jobs) {
  const mine = prevRows.filter((r) => belongs(r, run));
  const newer = new Set(mine.filter((r) => r.run_id > run.id).map((r) => r.job));
  const red = redRows(run, jobs).filter((r) => !newer.has(r.job));
  const redNames = new Set(red.map((r) => r.job));
  const cleared = (r) => jobs.some((j) => j.name === r.job && isHostedMacLeg(run.path, j) && j.status === "completed" && GREEN.has(j.conclusion));
  const kept = mine.filter((r) => inTable(r) && !redNames.has(r.job) && (r.run_id > run.id || !cleared(r)));
  return [...red, ...kept];
}

// Previous rows of workflows that had no counted run on main this time: unknown, so unchanged.
export const carryOver = (prevRows, seenRuns) => prevRows.filter((r) => inTable(r) && !seenRuns.some((run) => belongs(r, run)));

// The first failing test in a job log (the same patterns as the coordinator's main-red.sh), else the failed step.
export function firstFailure(log, job) {
  const lines = String(log ?? "").split("\n").map((l) => l.replace(/^\d{4}-\d{2}-\d{2}T[0-9:.]+Z ?/, "").replace(/\x1b\[[0-9;]*m/g, ""));
  const test = [/Test Case '-\[[^\]]+\]' failed/, /--- FAIL: \S+/, /✘ +\d+ .*/, /✖ .*/, /^ *\d+\) \[[^\]]+\] › .*/, /^FAIL[: ] .*/];
  for (const re of test) for (const l of lines) { const m = re.exec(l); if (m) return clip(m[0]); }
  const err = lines.find((l) => /error:|Error:|FAILED|failed/.test(l));
  if (err) return clip(err);
  const step = (job?.steps ?? []).find((s) => RED.has(s.conclusion));
  return step ? `step ${step.name}` : "no failing test readable";
}
const clip = (s) => s.replace(/\s+/g, " ").trim().slice(0, 160);

export function parseState(body) {
  const m = STATE_RE.exec(body ?? "");
  try { return m ? JSON.parse(m[1]) : []; } catch { return []; }
}

const esc = (s) => String(s).replaceAll("|", "\\|").replaceAll("<", "&lt;").replaceAll("-->", "--&gt;");
export function renderBody(rows, repo) {
  const table = rows.map((r) => `| [\`${r.sha.slice(0, 12)}\`](https://github.com/${repo}/commit/${r.sha}) | ${esc(r.workflow)} | ${esc(r.job)} (${r.conclusion}) | ${esc(r.test ?? "")} | [run ${r.run_id}](${r.url}) |`);
  return [
    "GitHub-hosted macOS legs no longer gate merges (D314). They run on every main commit; this issue lists the ones",
    "that are red on main right now. It is rewritten by `post-merge-hosted.yml` and closed when every hosted leg is green.",
    "It does not stop the merge line: the coordinator turns it into a fix-main task.",
    "",
    "| Commit | Workflow | Job | First failing test | Run |",
    "| --- | --- | --- | --- | --- |",
    ...table,
    "",
    `<!-- post-merge-red-state ${JSON.stringify(rows).replaceAll("-->", "--\\u003e")} -->`,
  ].join("\n");
}

// What to do with the issue: {action: "none"|"create"|"update"|"close", fresh: rows not in the previous state}.
export function plan(open, rows) {
  if (!open) return { action: rows.length ? "create" : "none", fresh: rows };
  const before = new Set(parseState(open.body).map((r) => r.job_id));
  const fresh = rows.filter((r) => !before.has(r.job_id));
  if (!rows.length) return { action: "close", fresh: [] };
  return { action: "update", fresh };
}

async function main() {
  const env = process.env;
  const dryRun = process.argv.includes("--dry-run");
  const repo = env.GITHUB_REPOSITORY || "modelplan/modelplan";
  const gh = client({ token: env.GITHUB_TOKEN, repo });
  const say = (o) => console.log(JSON.stringify(o));

  const issues = (await gh.all(`/issues?state=open&labels=${LABEL}&sort=created&direction=asc`)).filter((i) => !i.pull_request);
  const open = issues[0] ?? null;
  const prev = parseState(open?.body);
  const known = new Map(prev.map((r) => [r.job_id, r.test]));
  const rows = [], seen = [];
  for (const wf of HOSTED_WORKFLOWS) {
    const file = wf.split("/").pop();
    const run = pickRun(await gh.all(`/actions/workflows/${file}/runs?branch=main&event=push&status=completed`, "workflow_runs", 50));
    if (!run) { say({ workflow: wf, run: "none on main" }); continue; }
    const jobs = await gh.all(`/actions/runs/${run.id}/jobs?filter=latest`, "jobs", 500);
    seen.push(run);
    for (const row of reconcile(prev, run, jobs)) {
      row.test = known.get(row.job_id) ?? null;
      if (!row.test) {
        let log = "";
        try { log = await (await fetch(`https://api.github.com/repos/${repo}/actions/jobs/${row.job_id}/logs`, { headers: { authorization: `Bearer ${env.GITHUB_TOKEN}`, "user-agent": "modelplan-post-merge" } })).text(); } catch { /* no log: the step name stands in */ }
        row.test = firstFailure(log, jobs.find((j) => j.id === row.job_id));
      }
      rows.push(row);
    }
    say({ workflow: wf, run: run.id, sha: run.head_sha, red: rows.filter((r) => r.run_id === run.id).map((r) => r.job) });
  }
  rows.push(...carryOver(prev, seen));
  const p = plan(open, rows);
  say({ issue: open?.number ?? null, action: p.action, red: rows.length, fresh: p.fresh.map((r) => r.job), dryRun });
  if (dryRun) return;
  const body = renderBody(rows, repo);
  const news = (rs) => `New red hosted leg(s) on main:\n${rs.map((r) => `- ${r.workflow} / ${r.job} at ${r.sha.slice(0, 12)}: ${r.test} (${r.url})`).join("\n")}`;
  if (p.action === "create") {
    try { await gh.post("/labels", { name: LABEL, color: "d93f0b", description: "A GitHub-hosted macOS leg is red on main (D314); does not stop the merge line" }); } catch { /* exists */ }
    const made = await gh.post("/issues", { title: TITLE, body, labels: [LABEL] });
    say({ created: made.number });
  } else if (p.action === "update") {
    if (open.body !== body) await gh.patch(`/issues/${open.number}`, { body });
    if (p.fresh.length) await gh.post(`/issues/${open.number}/comments`, { body: news(p.fresh) });
  } else if (p.action === "close") {
    await gh.patch(`/issues/${open.number}`, { body });
    await gh.post(`/issues/${open.number}/comments`, { body: "Every hosted macOS leg is green on main again; closing." });
    await gh.patch(`/issues/${open.number}`, { state: "closed", state_reason: "completed" });
  }
  // A race between two first reports can open a second issue; keep the oldest.
  for (const dup of issues.slice(1)) {
    await gh.post(`/issues/${dup.number}/comments`, { body: `Duplicate of #${open.number}.` });
    await gh.patch(`/issues/${dup.number}`, { state: "closed", state_reason: "not_planned" });
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  try { await main(); } catch (e) {
    // A reporting error is visible in the run, but it never touches a commit status or the merge line.
    console.error(String(e?.stack || e));
    process.exitCode = 1;
  }
}
