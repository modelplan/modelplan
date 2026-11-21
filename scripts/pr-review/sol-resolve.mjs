// SPDX-License-Identifier: MIT
// pr-review-sol.yml job "resolve": which PR and head this event is about, decided before the PR's review job joins its
// concurrency group, so a stale delivery never takes the queue slot of the current head (Sol SOL-4).
// - ci (workflow_run of a pull_request run): the run's PR and head.
// - mac-compile (workflow_run of main's mac-compile.yml): the head from the run title ("mac-compile <sha>", or
//   "mac-compile PR #<n> @ <sha>" for the owner's dispatch); the head's mac-compile status must link to this very run.
// Every branch reads the PR's current head as its last lookup.
//   (A status posted with the job token starts no workflow, so the run's completion is the trigger, Sol SOL-1.)
// - workflow_dispatch: the PR input, at its current head.
// Outputs pr (empty = nothing to review) and sha (the head the trigger was for; empty for a dispatch).
import { appendFileSync } from "node:fs";
import { client } from "../merge-gates/github.mjs";
import { compileRunHead, compileRunPr, compileStatus, prForSha } from "./sol.mjs";

const env = process.env;
const repo = env.GITHUB_REPOSITORY;
const out = (pr, sha, why) => {
  appendFileSync(env.GITHUB_OUTPUT, `pr=${pr}\nsha=${sha}\n`);
  console.log(`pr-review-sol: ${pr ? `PR #${pr}${sha ? ` @ ${sha}` : ""}` : "nothing to review"}${why ? ` (${why})` : ""}`);
  process.exit(0);
};
// GITHUB_API_URL is set by Actions (https://api.github.com); the tests point it at a local fake.
const gh = client({ token: env.GITHUB_TOKEN, repo, ...(env.GITHUB_API_URL ? { api: env.GITHUB_API_URL } : {}) });
const isSha = (s) => /^[0-9a-f]{40}$/.test(s ?? "");
const current = async (n, sha) => {
  const pr = await gh.get(`/pulls/${n}`);
  if (pr.state !== "open") out("", "", `PR #${n} is ${pr.state}`);
  if (sha && pr.head?.sha !== sha) out("", "", `PR #${n} moved from ${sha} to ${pr.head?.sha}`);
  return pr.head?.sha;
};

if (env.EVENT === "workflow_dispatch") {
  const n = String(env.PR_INPUT ?? "");
  if (!/^[1-9][0-9]*$/.test(n)) out("", "", `bad PR number '${n}'`);
  await current(n, "");
  out(n, "");
}
// "review-label": the label-trigger run of a pull_request (it only records that review:gpt was added); the label itself
// is read later from the REST pull request, never from this event.
if (env.WORKFLOW === "ci" || env.WORKFLOW === "review-label") {
  const n = String(env.PR_INPUT ?? ""), sha = String(env.TRIGGER_SHA ?? "");
  if (!/^[1-9][0-9]*$/.test(n) || !isSha(sha)) out("", "", "ci run without a PR or head");
  await current(n, sha);
  out(n, sha);
}
if (env.WORKFLOW === "mac-compile") {
  const run = await gh.get(`/actions/runs/${Number(env.RUN_ID)}`);
  // The run's title names the head it compiled (SOL-2); a dispatch without the sha input names none and proves nothing.
  const sha = compileRunHead(run);
  if (!isSha(sha)) out("", "", "the mac-compile run names no head");
  const n = prForSha(await gh.get(`/commits/${sha}/pulls`), sha, repo);
  if (!n) out("", "", "no single open trusted PR has this head");
  const named = compileRunPr(run);
  if (named && named !== n) out("", "", `the dispatch named PR #${named}, not #${n}`);
  // The head's latest mac-compile status must be this run's success report.
  const st = compileStatus(await gh.get(`/commits/${sha}/statuses?per_page=100`), repo);
  if (!st.ok || st.runId !== run.id) out("", "", st.ok ? "the head's mac-compile status is from another run" : st.why);
  // Last lookup (SOL-4): the head must still be current after every other read, or a stale head could take the queue
  // slot of the current one.
  await current(n, sha);
  out(n, sha);
}
out("", "", `unexpected event ${env.EVENT}/${env.WORKFLOW}`);
