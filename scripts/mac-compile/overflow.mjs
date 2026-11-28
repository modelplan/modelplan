// SPDX-License-Identifier: MIT
// mac-compile-overflow.yml (owner D486, 11-28). For each mac-compile.yml run that is requested, watch its owner-pool
// `compile` job; if no owner compile Mac has picked it up OVERFLOW_MS after the job was queued, dispatch mac-compile.yml
// for the same PR head with pool=hosted (a GitHub-hosted macos-15 cold build), at most once per head. Nothing is
// cancelled: both runs go on, and mac-compile.yml's report keeps the first success at the head (success wins).
//
// Trust boundary: main's scripts only, the PR is read through the API, and mac-compile.yml's plan job re-validates the
// dispatch (open, owner's, same repository, head = sha). Pure decisions live in watchStep and overflowPlan; main() polls.
import { client } from "../merge-gates/github.mjs";
import { COMPILE_CONTEXT, isTrusted } from "../merge-gates/rules.mjs";

export const OVERFLOW_MS = 5 * 60 * 1000;
export const POLL_MS = 30 * 1000;
// The plan job takes about a minute before `compile` exists; past this the watcher gives up (the run is not stuck on
// the owner pool, or the watcher itself is late).
export const WATCH_MS = 15 * 60 * 1000;
export const OWNER_LABEL = "modelplan-compile";
// How many recent mac-compile runs the once-per-head lookup reads (about two days of runs at the 11-27 rate).
export const RUNS_SCAN = 500;
const QUEUED = new Set(["queued", "waiting", "pending", "requested"]);
const SHA = /^[0-9a-f]{40}$/;

// The head a mac-compile run is for, from the title main's run-name sets: "mac-compile <sha>" (workflow_run from the
// trigger) or "mac-compile PR #<n> @ <sha>" (dispatch with sha). Anything else (a seed run, a dispatch without sha): null.
export function titleHead(title) {
  let m = /^mac-compile PR #(\d+) @ ([0-9a-f]{40})$/.exec(String(title ?? ""));
  if (m) return { pr: Number(m[1]), sha: m[2] };
  m = /^mac-compile ([0-9a-f]{40})$/.exec(String(title ?? ""));
  return m ? { pr: null, sha: m[1] } : null;
}

// One poll of the watched run. run: REST workflow run; jobs: its jobs. Returns { action: "wait" | "stop" | "overflow", why }.
export function watchStep({ run, jobs, now = Date.now() }) {
  const r = (action, why) => ({ action, why });
  if (run.status === "completed") return r("stop", `the run finished (${run.conclusion})`);
  if (!titleHead(run.display_title)) return r("stop", "not a PR head run (seed, or a dispatch without sha)");
  const c = (jobs ?? []).find((j) => j.name === "compile");
  if (!c) return r("wait", "the compile job is not created yet");
  if (c.status === "completed") return r("stop", `the owner compile job is ${c.conclusion}`); // skipped: hosted pool or nothing to compile
  if (!(c.labels ?? []).includes(OWNER_LABEL)) return r("stop", "the compile job is not on the owner pool");
  if (!QUEUED.has(c.status)) return r("stop", `an owner compile Mac picked it up (${c.status})`);
  // The queue clock starts when the job could first be picked up: after its creation and after the plan job finished.
  const plan = (jobs ?? []).find((j) => j.name === "plan");
  if (plan && plan.status !== "completed") return r("wait", "the plan job is still running");
  const since = Math.max(Date.parse(c.created_at ?? c.started_at ?? ""), plan?.completed_at ? Date.parse(plan.completed_at) : -Infinity);
  if (!Number.isFinite(since)) return r("wait", "the compile job has no queue time yet");
  const waited = now - since;
  if (waited <= OVERFLOW_MS) return r("wait", `queued ${Math.round(waited / 1000)} s on the owner pool`);
  return r("overflow", `queued ${Math.round(waited / 60000)} min on the owner pool with no runner`);
}

// Whether to dispatch the hosted run. pr: REST pull request (current); sha: the watched head; statuses: combined statuses at
// the head; others: [{ run, jobs }] of the other mac-compile runs titled for this head. Returns { dispatch, why }.
export function overflowPlan({ pr, sha, statuses, others }) {
  const no = (why) => ({ dispatch: false, why });
  if (!pr || pr.state !== "open") return no("the PR is not open");
  if (pr.base?.ref !== "main") return no(`the PR targets ${pr.base?.ref}`);
  if (!isTrusted(pr.user) || pr.head?.repo?.full_name !== pr.base?.repo?.full_name) return no("not a trusted same-repository PR");
  if (!SHA.test(sha) || pr.head?.sha !== sha) return no("the PR moved on: the newer head has its own run");
  const st = (statuses ?? []).find((s) => s.context === COMPILE_CONTEXT);
  if (st?.state === "success") return no("mac-compile already passed at this head");
  // Once per head: any hosted job ever created for this head (queued, running or finished, not merely skipped) counts.
  const hosted = (others ?? []).some(({ jobs }) => (jobs ?? []).some((j) => j.name === "compile-hosted" && !(j.status === "completed" && j.conclusion === "skipped")));
  if (hosted) return no("a hosted compile already ran or runs for this head");
  return { dispatch: true, why: "overflow to the hosted pool" };
}

const sleep = (ms) => new Promise((ok) => setTimeout(ok, ms));

async function prFor(gh, head) {
  if (head.pr) return gh.get(`/pulls/${head.pr}`);
  // A workflow_run run names only the sha: the open PR into main whose head it is.
  const prs = (await gh.get(`/commits/${head.sha}/pulls`)) ?? [];
  const open = prs.filter((p) => p.state === "open" && p.base?.ref === "main" && p.head?.sha === head.sha);
  return open.length === 1 ? gh.get(`/pulls/${open[0].number}`) : null;
}

async function main(env) {
  const repo = env.GITHUB_REPOSITORY;
  const runId = env.RUN_ID;
  if (!/^\d+$/.test(runId ?? "")) { console.log(`::error::mac-compile-overflow: bad run id '${runId}'`); process.exit(1); }
  const gh = client({ token: env.GH_TOKEN, repo, ...(env.GITHUB_API_URL ? { api: env.GITHUB_API_URL } : {}) });
  const deadline = Date.now() + WATCH_MS;
  let step = { action: "wait", why: "start" }, run;
  while (Date.now() < deadline) {
    try {
      run = await gh.get(`/actions/runs/${runId}`);
      const jobs = (await gh.get(`/actions/runs/${runId}/jobs?per_page=100`)).jobs ?? [];
      step = watchStep({ run, jobs });
    } catch (e) { step = { action: "wait", why: `read failed: ${e.message}` }; }
    console.log(`mac-compile-overflow: run ${runId}: ${step.action} (${step.why})`);
    if (step.action !== "wait") break;
    await sleep(POLL_MS);
  }
  if (step.action !== "overflow") return;
  const head = titleHead(run.display_title);
  const pr = await prFor(gh, head);
  const statuses = (await gh.get(`/commits/${head.sha}/status`)).statuses ?? [];
  const titles = new Set([`mac-compile ${head.sha}`, `mac-compile PR #${pr?.number} @ ${head.sha}`]);
  // Earlier attempts for the head may be older than the latest page: read up to RUNS_SCAN runs (macrev2-1234-3).
  const runs = await gh.all("/actions/workflows/mac-compile.yml/runs", "workflow_runs", RUNS_SCAN);
  const others = [];
  for (const r of runs.filter((x) => String(x.id) !== String(runId) && titles.has(x.display_title)))
    others.push({ run: r, jobs: (await gh.get(`/actions/runs/${r.id}/jobs?per_page=100`)).jobs ?? [] });
  const d = overflowPlan({ pr, sha: head.sha, statuses, others });
  console.log(`mac-compile-overflow: #${pr?.number ?? "?"} @ ${head.sha.slice(0, 12)}: ${d.dispatch ? "dispatch hosted" : "none"} (${d.why})`);
  if (!d.dispatch) return;
  await gh.post("/actions/workflows/mac-compile.yml/dispatches", { ref: "main", inputs: { pr: String(pr.number), sha: head.sha, pool: "hosted" } });
  console.log(`::notice title=mac-compile overflow::PR #${pr.number} @ ${head.sha.slice(0, 8)} dispatched to the hosted pool (D486)`);
}
if (import.meta.url === `file://${process.argv[1]}`) await main(process.env);
