// SPDX-License-Identifier: MIT
// mac-compile-sweep.yml (owner D374, 11-21). Every ~10 minutes: for each open, ready, trusted same-repository PR into
// main that changes desktop/native,
//  - no mac-compile status at the head and no mac-compile run queued or running for it: dispatch mac-compile.yml with
//    inputs pr and sha (the plan job re-reads the PR and refuses a moved head, a draft or a stranger's PR);
//  - mac-compile success at the head while modelplan-gates still says "waiting for mac-compile": dispatch merge-gates.yml
//    for the PR (a status posted with the job token starts no workflow, so nothing else re-evaluates the gate).
// A head whose pull_request events are less than SETTLE_MS old is left alone: the trigger and its mac-compile run are
// normally still on their way. Pure decisions live in sweepPlan; main() does the reads and dispatches.
import { client } from "../merge-gates/github.mjs";
import { COMPILE_CONTEXT, CONTEXT, isTrusted, needsCompile, prPaths } from "../merge-gates/rules.mjs";

export const SETTLE_MS = 5 * 60 * 1000;
export const GATE_WAITING = "waiting for mac-compile";

// pr: REST pull request; files: REST PR files; statuses: combined statuses at the head (newest per context);
// runs: recent mac-compile.yml runs (any status); trigger: recent "mac-compile trigger" runs for the head.
// Returns { action: "compile" | "gate" | "none", why }.
export function sweepPlan({ pr, files, statuses, runs, trigger = [], now = Date.now() }) {
  const none = (why) => ({ action: "none", why });
  if (pr.state !== "open" || pr.draft) return none("not an open ready PR");
  if (pr.base?.ref !== "main") return none(`base is ${pr.base?.ref}`);
  if (!isTrusted(pr.user) || pr.head?.repo?.full_name !== pr.base?.repo?.full_name) return none("not a trusted same-repository PR");
  const head = String(pr.head?.sha ?? "");
  if (!/^[0-9a-f]{40}$/.test(head)) return none("head is not a full sha");
  if (!needsCompile(prPaths(files))) return none("no desktop/native change");
  const st = (statuses ?? []).find((s) => s.context === COMPILE_CONTEXT);
  if (st) {
    const gate = (statuses ?? []).find((s) => s.context === CONTEXT);
    if (st.state === "success" && gate?.state === "pending" && String(gate.description ?? "").includes(GATE_WAITING)) return { action: "gate", why: "mac-compile passed, the gate has not seen it" };
    return none(`mac-compile is ${st.state}`);
  }
  const titles = new Set([`mac-compile ${head}`, `mac-compile PR #${pr.number} @ ${head}`]);
  if (runs.some((r) => titles.has(r.display_title) && r.status !== "completed")) return none("a mac-compile run is queued or running for this head");
  // A recent trigger run: its mac-compile run is still being created.
  if (trigger.some((r) => r.status !== "completed" || now - Date.parse(r.created_at) < SETTLE_MS)) return none("the mac-compile trigger ran a moment ago");
  if (now - Date.parse(pr.updated_at ?? 0) < SETTLE_MS) return none("the PR changed a moment ago");
  return { action: "compile", why: "no mac-compile status or run at this head" };
}

async function main(env) {
  const repo = env.GITHUB_REPOSITORY;
  const gh = client({ token: env.GH_TOKEN, repo, ...(env.GITHUB_API_URL ? { api: env.GITHUB_API_URL } : {}) });
  const prs = await gh.all("/pulls?state=open&base=main");
  const runs = (await gh.get("/actions/workflows/mac-compile.yml/runs?per_page=100")).workflow_runs ?? [];
  let failed = 0;
  for (const p of prs) {
    if (p.draft) continue;
    try {
      const pr = await gh.get(`/pulls/${p.number}`);
      const files = await gh.all(`/pulls/${p.number}/files`);
      if (!needsCompile(prPaths(files))) continue;
      const head = pr.head.sha;
      const statuses = (await gh.get(`/commits/${head}/status`)).statuses ?? [];
      const trigger = (await gh.get(`/actions/workflows/mac-compile-trigger.yml/runs?head_sha=${head}&per_page=10`)).workflow_runs ?? [];
      const d = sweepPlan({ pr, files, statuses, runs, trigger });
      console.log(`mac-compile-sweep: #${p.number} @ ${head.slice(0, 12)}: ${d.action} (${d.why})`);
      if (d.action === "compile") await gh.post("/actions/workflows/mac-compile.yml/dispatches", { ref: "main", inputs: { pr: String(p.number), sha: head } });
      if (d.action === "gate") await gh.post("/actions/workflows/merge-gates.yml/dispatches", { ref: "main", inputs: { pr: String(p.number) } });
    } catch (e) { failed++; console.log(`::error::mac-compile-sweep: #${p.number}: ${e.message}`); }
  }
  if (failed) process.exit(1);
}
if (import.meta.url === `file://${process.argv[1]}`) await main(process.env);
