// SPDX-License-Identifier: MIT
// Computes and publishes the `modelplan-gates` commit status (see rules.mjs) for a PR head or a
// merge-group commit. Runs from the default branch only (workflow_run, issue_comment, workflow_dispatch),
// so a PR never runs its own version of the rules that judge it.
//
//   node scripts/merge-gates/evaluate.mjs                       from a GitHub Actions event
//   node scripts/merge-gates/evaluate.mjs --pr 123 [--dry-run]   one PR head
//   node scripts/merge-gates/evaluate.mjs --group <sha> [--dry-run]
// Needs GITHUB_TOKEN (statuses: write to post) and GITHUB_REPOSITORY; the working directory is a clone
// of the repository (blobless is enough; objects are fetched on demand).
import { readFileSync, appendFileSync } from "node:fs";
import { client } from "./github.mjs";
import * as G from "./git.mjs";
import { CONTEXT, FAILURE, description, evaluateGroup, evaluatePr, feed, isTrain, parseDesignConf, supersededPrs, trainMembers } from "./rules.mjs";

const env = process.env;
const argv = process.argv.slice(2);
const flag = (name) => { const i = argv.indexOf(name); return i < 0 ? null : argv[i + 1] ?? ""; };
const dryRun = argv.includes("--dry-run");
const repo = env.GITHUB_REPOSITORY || "modelplan/modelplan";
const cwd = flag("--repo-dir") ?? process.cwd();
const gh = client({ token: env.GITHUB_TOKEN, repo });
const conf = parseDesignConf(readFileSync(new URL("./design-paths.conf", import.meta.url), "utf8"));
const MAIN = "refs/remotes/origin/main";
const runUrl = env.GITHUB_RUN_ID ? `${env.GITHUB_SERVER_URL || "https://github.com"}/${repo}/actions/runs/${env.GITHUB_RUN_ID}` : undefined;

function log(obj) {
  const line = JSON.stringify(obj);
  console.log(line);
  if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, "`" + line.replaceAll("`", "'") + "`\n\n");
}

async function post(sha, result) {
  log({ sha, ...result, dryRun });
  if (dryRun) return;
  await gh.post(`/statuses/${sha}`, { state: result.state, context: CONTEXT, description: description(result.why), target_url: runUrl });
}

const carryCache = new Map();
function verifiedEdge(oldSha, newSha) {
  const k = `${oldSha}>${newSha}`;
  if (!carryCache.has(k)) {
    const r = G.verifyCarry(cwd, oldSha, newSha, MAIN);
    log({ carry: k, ...r });
    carryCache.set(k, r.ok);
  }
  return carryCache.get(k);
}

// A train's members, read only for a train: the extra calls would otherwise run on every evaluation. A number in
// Supersedes that is not a PR is skipped; any other read error stops the evaluation, so the gate never passes on
// a partial member list.
async function readTrainMembers(pr) {
  if (!isTrain(pr)) return [];
  const notFound = (e) => { if (/HTTP 404/.test(String(e))) return null; throw e; };
  const [based, open, superseded] = await Promise.all([
    gh.all(`/pulls?state=all&base=${encodeURIComponent(pr.head.ref)}`),
    gh.all("/pulls?state=open&base=main"),
    Promise.all(supersededPrs(pr.body).map((n) => gh.get(`/pulls/${n}`).catch(notFound))),
  ]);
  G.git(cwd, ["fetch", "-q", "--no-tags", "--filter=blob:none", "origin", `+refs/heads/main:${MAIN}`]);
  return trainMembers(pr, { based, open, superseded: superseded.filter(Boolean), commits: G.commitsOnlyIn(cwd, pr.head.sha, MAIN) });
}

async function prResult(number) {
  const pr = await gh.get(`/pulls/${number}`);
  const head = pr.head.sha;
  const [comments, reviews, files, runs, combined, members] = await Promise.all([
    gh.all(`/issues/${number}/comments`),
    gh.all(`/pulls/${number}/reviews`),
    gh.all(`/pulls/${number}/files`),
    gh.all(`/actions/runs?head_sha=${head}`, "workflow_runs", 500),
    gh.get(`/commits/${head}/status`),
    readTrainMembers(pr),
  ]);
  const result = evaluatePr({ pr, items: feed(comments, reviews), files, runs, statuses: combined.statuses ?? [], verifiedEdge, conf, members });
  return { pr, result };
}

async function evaluatePrAndPost(number) {
  const { pr, result } = await prResult(number);
  if (pr.state !== "open") return log({ pr: number, skipped: `PR is ${pr.state}` });
  // Never publish a verdict for a head that moved while we were reading: the newer event re-evaluates it.
  const now = await gh.get(`/pulls/${number}`);
  if (now.head.sha !== result.head) return log({ pr: number, skipped: "head moved during evaluation" });
  await post(result.head, { pr: number, ...result });
}

async function evaluateGroupAndPost(groupSha) {
  G.git(cwd, ["fetch", "-q", "--no-tags", "--filter=blob:none", "origin", `+refs/heads/main:${MAIN}`]);
  if (!G.ensure(cwd, groupSha)) return post(groupSha, { state: FAILURE, why: "group commit not found" });
  if (G.isAncestor(cwd, groupSha, MAIN)) return log({ group: groupSha, skipped: "already on main" });
  const steps = [];
  let c = groupSha;
  for (let i = 0; i < 10 && !G.isAncestor(cwd, c, MAIN); i++) {
    const p = G.parents(cwd, c);
    if (p.length !== 2) return post(groupSha, { state: FAILURE, why: `${c.slice(0, 8)} is not a merge-queue merge` });
    let mergeProof = G.verifyCleanMerge(cwd, c);
    // The queue's merge commits are made and signed by GitHub; anything else is not the queue's merge.
    const meta = await gh.get(`/commits/${c}`);
    if (mergeProof.ok && !meta.commit?.verification?.verified) mergeProof = { ok: false, why: "group commit is not GitHub-signed" };
    const pulls = (await gh.get(`/commits/${p[1]}/pulls`)).filter((x) => x.state === "open" && x.base.ref === "main" && x.head.sha === p[1]);
    if (pulls.length !== 1) return post(groupSha, { state: FAILURE, why: `no single open PR has head ${p[1].slice(0, 8)}` });
    const { result } = await prResult(pulls[0].number);
    if (result.head !== p[1]) return post(groupSha, { state: FAILURE, why: `#${pulls[0].number} head moved` });
    steps.unshift({ pr: pulls[0].number, prResult: result, mergeProof });
    c = p[0];
  }
  if (!G.isAncestor(cwd, c, MAIN)) return post(groupSha, { state: FAILURE, why: "group does not start on main within 10 PRs" });
  const [queueRuns, combined] = await Promise.all([
    gh.all(`/actions/runs?head_sha=${groupSha}`, "workflow_runs", 500),
    gh.get(`/commits/${groupSha}/status`),
  ]);
  const result = evaluateGroup({ steps, queueRuns, queueStatuses: combined.statuses ?? [] });
  await post(groupSha, { group: steps.map((s) => s.pr), ...result });
}

async function fromEvent() {
  const name = env.GITHUB_EVENT_NAME;
  const ev = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, "utf8"));
  if (name === "issue_comment") return ev.issue?.pull_request ? evaluatePrAndPost(ev.issue.number) : null;
  if (name === "workflow_dispatch") {
    if (ev.inputs?.group_sha) return evaluateGroupAndPost(ev.inputs.group_sha);
    if (ev.inputs?.pr) return evaluatePrAndPost(Number(ev.inputs.pr));
    return null;
  }
  if (name !== "workflow_run") return log({ skipped: `event ${name}` });
  const wr = ev.workflow_run;
  if (wr.event === "merge_group") {
    if (!String(wr.head_branch).startsWith("gh-readonly-queue/main/")) return log({ skipped: `queue branch ${wr.head_branch}` });
    return evaluateGroupAndPost(wr.head_sha);
  }
  if (wr.event !== "pull_request" && wr.event !== "pull_request_review") return log({ skipped: `run event ${wr.event}` });
  let numbers = (wr.pull_requests ?? []).map((p) => p.number);
  if (!numbers.length) numbers = (await gh.get(`/commits/${wr.head_sha}/pulls`)).filter((p) => p.state === "open").map((p) => p.number);
  for (const n of numbers) await evaluatePrAndPost(n);
}

const pr = flag("--pr"), group = flag("--group");
try {
  if (pr) await evaluatePrAndPost(Number(pr));
  else if (group) await evaluateGroupAndPost(group);
  else await fromEvent();
} catch (e) {
  // An evaluator error never turns into a pass; the status stays as it was and the run fails visibly.
  console.error(String(e?.stack || e));
  process.exitCode = 1;
}
