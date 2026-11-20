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
import { HOSTED_WORKFLOWS } from "./hosted.mjs";
import { createHash } from "node:crypto";
import { CARRY_CONTEXT, CONTEXT, FAILURE, carryStatus, dataSyncRunId, parseFallbackUntil, cancelledRunSuperseded, description, evaluateGroup, evaluatePr, queueRunScope, feed, isTrain, parseDesignConf, supersededPrs, TIER_TABLE, tiersFrom, trainMembers } from "./rules.mjs";

const env = process.env;
const argv = process.argv.slice(2);
const flag = (name) => { const i = argv.indexOf(name); return i < 0 ? null : argv[i + 1] ?? ""; };
const dryRun = argv.includes("--dry-run");
const repo = env.GITHUB_REPOSITORY || "modelplan/modelplan";
const cwd = flag("--repo-dir") ?? process.cwd();
// GITHUB_API_URL is set by Actions (https://api.github.com); tests point it at a local fake.
const gh = client({ token: env.GITHUB_TOKEN, repo, ...(env.GITHUB_API_URL ? { api: env.GITHUB_API_URL } : {}) });
const conf = parseDesignConf(readFileSync(new URL("./design-paths.conf", import.meta.url), "utf8"));
const tiers = tiersFrom(() => readFileSync(new URL(`../../${TIER_TABLE}`, import.meta.url), "utf8"));
const MAIN = "refs/remotes/origin/main";
const runUrl = env.GITHUB_RUN_ID ? `${env.GITHUB_SERVER_URL || "https://github.com"}/${repo}/actions/runs/${env.GITHUB_RUN_ID}` : undefined;

function log(obj) {
  const line = JSON.stringify(obj);
  console.log(line);
  if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, "`" + line.replaceAll("`", "'") + "`\n\n");
}

if (!tiers.size) log({ warning: `${TIER_TABLE} unreadable: every scenario needs evidence` });

async function post(sha, result, { carry = false } = {}) {
  log({ sha, ...result, dryRun });
  if (dryRun) return;
  // A PR head gets the machine-readable carry status FIRST (round 3): a revoked carry is withdrawn before the gate state that
  // depended on it can change, and readers never take it from the human description.
  if (carry) await gh.post(`/statuses/${sha}`, { ...carryStatus(result), context: CARRY_CONTEXT, target_url: runUrl });
  await gh.post(`/statuses/${sha}`, { state: result.state, context: CONTEXT, description: description(result.why), target_url: runUrl });
}

// Round 3 (Sol): every input a PR evaluation reads that can change at the same head (trusted and untrusted comments with
// their edit times, reviews, the head's commit statuses other than our own, the PR body/title/draft/base and the head),
// as one hash. A writer publishes, then re-reads it: if it changed since the evaluation read it, the result may be stale
// and the PR is evaluated again (at most 4 rounds). Whichever writer finishes last therefore posted from inputs that were
// still current after its own post, so a stale result never stays on the head, whatever concurrency group it ran in.
async function inputsKey(number) {
  const [pr, comments, reviews] = await Promise.all([gh.get(`/pulls/${number}`), gh.all(`/issues/${number}/comments`), gh.all(`/pulls/${number}/reviews`)]);
  const statuses = (await gh.get(`/commits/${pr.head.sha}/status`)).statuses ?? [];
  const key = JSON.stringify([pr.head.sha, pr.state, pr.draft, pr.base?.ref, pr.title, pr.body,
    comments.map((c) => [c.id, c.updated_at, c.user?.id, c.body]), reviews.map((r) => [r.id, r.submitted_at, r.state, r.user?.id, r.body]),
    statuses.filter((x) => x.context !== CONTEXT && x.context !== CARRY_CONTEXT).map((x) => [x.context, x.state, x.updated_at]).sort()]);
  return createHash("sha256").update(key).digest("hex");
}

const carryCache = new Map();
function verifiedEdge(oldSha, newSha) {
  const k = `${oldSha}>${newSha}`;
  if (!carryCache.has(k)) {
    let r;
    try { r = G.verifyCarry(cwd, oldSha, newSha, MAIN); } catch (e) { r = { ok: false, why: `git error: ${String(e?.message || e).split("\n")[0]}` }; }
    log({ carry: k, ok: r.ok, why: r.why, ...(r.sides ? { prSide: r.sides.pr.length, mainSide: r.sides.main.length } : {}) });
    carryCache.set(k, r);
  }
  return carryCache.get(k);
}

// D243 G6 auto-carry proof (git.verifyMainMerges). The checkout has full history of main (fetch-depth 0, blobless);
// main is refetched once before the first proof; PR commits are fetched by sha and blobs on demand, so no
// shallow-history limit applies.
const mainMergeCache = new Map();
let mainFresh = false;
function proveMainMerges(oldSha, newSha) {
  const k = `${oldSha}>${newSha}`;
  if (!mainMergeCache.has(k)) {
    let r;
    try {
      // Refresh main once, so a main commit merged after the job's checkout is still found on main.
      if (!mainFresh) { G.git(cwd, ["fetch", "-q", "--no-tags", "--filter=blob:none", "origin", `+refs/heads/main:${MAIN}`]); mainFresh = true; }
      r = G.verifyMainMerges(cwd, oldSha, newSha, MAIN);
    } catch (e) {
      r = { ok: false, why: `git error: ${String(e?.message || e).split("\n")[0]}`, between: [] };
    }
    log({ autoCarry: k, ok: r.ok, why: r.why });
    mainMergeCache.set(k, r);
  }
  return mainMergeCache.get(k);
}

// Plan B carry-forward proof (git.verifyCarryForward), cached like the auto-carry proof; main is refreshed once first.
const forwardCache = new Map();
function proveCarryForward(approved, head, mainSha) {
  const k = `${approved}>${head}>${mainSha}`;
  if (!forwardCache.has(k)) {
    let r;
    try {
      if (!mainFresh) { G.git(cwd, ["fetch", "-q", "--no-tags", "--filter=blob:none", "origin", `+refs/heads/main:${MAIN}`]); mainFresh = true; }
      r = G.verifyCarryForward(cwd, approved, head, mainSha, MAIN);
    } catch (e) {
      r = { ok: false, why: `git error: ${String(e?.message || e).split("\n")[0]}` };
    }
    log({ carryForward: k, ok: r.ok, why: r.why, ...(r.sides ? { prSide: r.sides.pr.length, mainSide: r.sides.main.length } : {}) });
    forwardCache.set(k, r);
  }
  return forwardCache.get(k);
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

// A data-sync PR's evidence, read only for a bot PR on a data/sync-* branch: the workflow run its branch names and
// the head commit. An unreadable run or commit (404) is "not proven", never a pass.
async function readDataSync(pr) {
  const runId = dataSyncRunId(pr);
  if (!runId) return null;
  const orNull = (e) => { if (/HTTP 404/.test(String(e))) return null; throw e; };
  const [run, commit] = await Promise.all([gh.get(`/actions/runs/${runId}`).catch(orNull), gh.get(`/commits/${pr.head.sha}`).catch(orNull)]);
  return { run, commit };
}

// D314: the jobs of runs that may hold a GitHub-hosted macOS leg (hosted.mjs), attached as run.jobs so the rules can set
// those legs aside. Only runs that are not already green are read. An unreadable list leaves run.jobs unset, and the
// rules then judge the whole run as before (fail closed).
async function readJobs(runs) {
  await Promise.all(runs.filter((r) => HOSTED_WORKFLOWS.includes(String(r.path).split("@")[0])).map(async (r) => {
    try { r.jobs = await gh.all(`/actions/runs/${r.id}/jobs?filter=latest`, "jobs", 500); }
    catch (e) { log({ run: r.id, jobs: `unreadable: ${String(e).slice(0, 120)}` }); }
  }));
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
  await readJobs(runs.filter((r) => !(r.status === "completed" && ["success", "skipped", "neutral"].includes(r.conclusion))));
  // GLM-out fallback window (repository variable GLM_FALLBACK_UNTIL, the GLM reset time); unset = closed.
  const now = Date.now();
  const glmFallbackUntil = parseFallbackUntil(env.GLM_FALLBACK_UNTIL || "", now);
  const result = evaluatePr({ pr, items: feed(comments, reviews), files, runs, statuses: combined.statuses ?? [], verifiedEdge, proveMainMerges, proveCarryForward, conf, members, tiers, sync: await readDataSync(pr), glmFallbackUntil, now });
  return { pr, result };
}

async function evaluatePrAndPost(number) {
  for (let round = 1; round <= 4; round++) {
    const before = await inputsKey(number);
    const { pr, result } = await prResult(number);
    if (pr.state !== "open") return log({ pr: number, skipped: `PR is ${pr.state}` });
    // Never publish a verdict for a head that moved while we were reading: the newer event re-evaluates it.
    const now = await gh.get(`/pulls/${number}`);
    if (now.head.sha !== result.head) return log({ pr: number, skipped: "head moved during evaluation" });
    await post(result.head, { pr: number, ...result }, { carry: true });
    if (dryRun || (await inputsKey(number)) === before) return;
    log({ pr: number, reevaluate: `inputs changed during evaluation round ${round}` });
  }
  // Still changing after 4 rounds: the latest change's own event re-evaluates it (its job runs after this one or reads later).
  log({ pr: number, warning: "inputs kept changing; the next event re-evaluates" });
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
  const [queueRuns, combined, queueCheckRuns] = await Promise.all([
    gh.all(`/actions/runs?head_sha=${groupSha}`, "workflow_runs", 500),
    gh.get(`/commits/${groupSha}/status`),
    gh.all(`/commits/${groupSha}/check-runs`, "check_runs", 1000),
  ]);
  const desktop = queueRuns.filter(queueRunScope(repo)).filter((r) => r.path === ".github/workflows/desktop.yml").sort((x, y) => y.id - x.id)[0];
  const desktopJobs = desktop ? await gh.all(`/actions/runs/${desktop.id}/jobs`, "jobs", 500) : null;
  if (desktop) desktop.jobs = desktopJobs;
  await readJobs(queueRuns.filter(queueRunScope(repo)).filter((r) => r !== desktop));
  const result = evaluateGroup({ steps, queueRuns, queueStatuses: combined.statuses ?? [], queueCheckRuns, desktopJobs, repo });
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
  return fromRun(ev.workflow_run);
}

// One workflow run (the workflow_run payload): its merge group or its PRs.
async function fromRun(wr) {
  // Plan B (Sol round 1): the gate requires mac-compile success at a Swift PR's head, and the compile status is posted
  // with the workflow token (which starts no workflow), so the finished mac-compile run re-evaluates its PR. The run
  // title names the PR (mac-compile.yml run-name); the evaluation re-reads everything, so the title only picks the PR.
  if (String(wr.path ?? "").split("@")[0] === ".github/workflows/mac-compile.yml") {
    const m = /^mac-compile PR #([0-9]+)$/.exec(wr.display_title ?? "");
    if (!m || wr.head_branch !== "main") return log({ skipped: "mac-compile run without a PR" });
    return evaluatePrAndPost(Number(m[1]));
  }
  if (wr.event === "merge_group") {
    if (!String(wr.head_branch).startsWith("gh-readonly-queue/main/")) return log({ skipped: `queue branch ${wr.head_branch}` });
    return evaluateGroupAndPost(wr.head_sha);
  }
  if (wr.event !== "pull_request" && wr.event !== "pull_request_review") return log({ skipped: `run event ${wr.event}` });
  let numbers = (wr.pull_requests ?? []).map((p) => p.number);
  if (!numbers.length) numbers = (await gh.get(`/commits/${wr.head_sha}/pulls`)).filter((p) => p.state === "open").map((p) => p.number);
  for (const n of numbers) {
    // A cancelled run whose head is no longer the PR head was replaced by a newer push: that head's runs decide.
    if (wr.conclusion === "cancelled" && cancelledRunSuperseded(wr, (await gh.get(`/pulls/${n}`)).head.sha)) {
      log({ pr: n, skipped: "cancelled run of a superseded head" });
      continue;
    }
    await evaluatePrAndPost(n);
  }
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
