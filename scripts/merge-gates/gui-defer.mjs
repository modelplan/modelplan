// SPDX-License-Identifier: MIT
// D488 (owner 2026-11-28): in the merge queue only the tail of the building window runs the GUI leg.
//
// The queue builds up to four groups at once; each group commit contains every group before it, and the owner has one
// GUI Mac, so the tail's GUI leg used to wait behind every earlier entry's (about 20 minutes each). desktop.yml's
// gui-defer job runs this script in a merge_group run before the GUI jobs are created:
// - this entry is the tail of the building window (no later entry is awaiting checks, mergeable or locked) -> own=true,
//   the GUI leg runs in this run as before; so does any doubt (unparsable queue branch, the queue unreadable 3 times);
// - otherwise poll every GUI_DEFER_INTERVAL_SECONDS until either a later merge_group desktop run whose commit contains
//   this group commit (compare API: ahead, behind_by 0) has a green GUI leg -> own=false, record it as a notice
//   annotation (GUI_COVER_TITLE, "run=<id> sha=<head>"); modelplan-gates re-verifies that run itself (rules.mjs
//   guiCoverState) -, or this entry becomes the tail (later entries removed) -> own=true;
// - main's evaluator cannot verify a cover yet (merge-gates.yml checks out main; its rules.mjs lacks COVER_MARKER, or
//   it is unreadable) -> own=true without waiting, and again before any cover is used, so a group never skips its GUI
//   leg while the gate that judges it would read the skip as missing (rollout, or a revert of D488 on main);
// - no cover and still not the tail after GUI_DEFER_DEADLINE_MINUTES, or the entry left the queue without a cover ->
//   exit 1. Nothing here can make a group pass: the gate checks the covering run, and a failed defer fails the group.
//
//   node scripts/merge-gates/gui-defer.mjs     (env: GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_REF, GITHUB_RUN_ID)
import { appendFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { client } from "./github.mjs";
import { DESKTOP_WORKFLOW, GUI_COVER_MARKER, GUI_COVER_TITLE, SUCCESS, coverCandidate, coverGuiState, queuePrOf } from "./rules.mjs";

// The exact line main's rules.mjs must carry before any group defers (rules.mjs GUI_COVER_MARKER).
export const COVER_MARKER = `export const GUI_COVER_MARKER = "${GUI_COVER_MARKER}";`;
export const RULES_PATH = "scripts/merge-gates/rules.mjs";
export async function mainSupportsCover(gh) {
  const blob = await gh.get(`/contents/${RULES_PATH}?ref=main`);
  const text = Buffer.from(String(blob?.content ?? ""), "base64").toString("utf8");
  return text.split("\n").includes(COVER_MARKER);
}

// Entries whose group is built or being merged; QUEUED ones (outside the build window) and UNMERGEABLE ones do not
// cover anything.
export const ACTIVE = new Set(["AWAITING_CHECKS", "MERGEABLE", "LOCKED"]);
export const QUEUE_QUERY = `query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) {
  mergeQueue(branch: "main") { entries(first: 100) { nodes { position state headCommit { oid } pullRequest { number } } } } } }`;

export async function readQueue(gh, repo) {
  const [owner, name] = repo.split("/");
  const q = (await gh.graphql(QUEUE_QUERY, { owner, name }))?.repository?.mergeQueue;
  if (!q || !Array.isArray(q.entries?.nodes)) throw new Error("no merge queue for main");
  return q.entries.nodes;
}

// Where this entry stands: found by its PR number (the queue branch names it) or its group commit.
export function queuePosition(entries, { pr, sha }) {
  const mine = entries.find((e) => e?.pullRequest?.number === pr || (sha && e?.headCommit?.oid === sha));
  if (!mine) return { found: false };
  const later = entries.filter((e) => e !== mine && ACTIVE.has(e?.state) && Number(e?.position) > Number(mine.position));
  return { found: true, position: mine.position, tail: later.length === 0, later: later.map((e) => e.pullRequest?.number) };
}

// A later merge_group desktop run whose commit contains `sha` and whose GUI leg is green. `contained` caches the
// (immutable) compare answers per commit; read errors skip a candidate for this round.
export async function findCover({ gh, repo, sha, runId, sinceMs, contained = new Map(), log = () => {} }) {
  const runs = await gh.all(`/actions/workflows/${DESKTOP_WORKFLOW.split("/").pop()}/runs?event=merge_group`, "workflow_runs", 100);
  for (const r of runs) {
    if (!coverCandidate(r, { repo, runId, groupSha: sha })) continue;
    if (!(Date.parse(r.created_at) >= sinceMs)) continue;
    if (!contained.has(r.head_sha)) {
      try {
        const c = await gh.get(`/compare/${sha}...${r.head_sha}`);
        contained.set(r.head_sha, c?.status === "ahead" && c?.behind_by === 0 && c?.ahead_by > 0);
      } catch (e) { log(`compare ${r.head_sha.slice(0, 8)}: ${String(e).slice(0, 120)}`); continue; }
    }
    if (!contained.get(r.head_sha)) continue;
    let jobs;
    try { jobs = await gh.all(`/actions/runs/${r.id}/jobs?filter=latest`, "jobs", 500); }
    catch (e) { log(`jobs of ${r.id}: ${String(e).slice(0, 120)}`); continue; }
    const leg = coverGuiState(jobs);
    if (leg.state === SUCCESS) return r;
    log(`run ${r.id} (#${queuePrOf(r.head_branch)}) contains this group: ${leg.why}`);
  }
  return null;
}

// -> { own: true } run the GUI leg here; { own: false, cover } covered; { fail: true } neither.
export async function defer({ gh, repo, sha, runId, ref, supportsCover = () => mainSupportsCover(gh), now = Date.now, sleep, deadlineMs = 70 * 60000, intervalMs = 60000, settleMs = 90000, log = () => {} }) {
  const pr = queuePrOf(ref);
  if (pr == null) return { own: true, why: `not a queue branch (${ref}): own GUI leg` };
  const notYet = { own: true, why: "main's merge gate cannot verify a GUI cover yet (no D488 marker in its rules.mjs): own GUI leg" };
  const gate = async () => { try { return (await supportsCover()) === true; } catch { return false; } };
  if (!(await gate())) return notYet;
  const start = now();
  const contained = new Map();
  let queueFails = 0, missing = 0;
  for (;;) {
    let cover = null;
    try { cover = await findCover({ gh, repo, sha, runId, sinceMs: start - 15 * 60000, contained, log }); }
    catch (e) { log(`runs list: ${String(e).slice(0, 120)}`); }
    if (cover && !(await gate())) return notYet;
    if (cover) return { own: false, cover, why: `covered by #${queuePrOf(cover.head_branch)} merge_group run ${cover.id}` };
    let pos = null;
    try { pos = queuePosition(await readQueue(gh, repo), { pr, sha }); queueFails = 0; }
    catch (e) {
      log(`merge queue: ${String(e).slice(0, 120)}`);
      if (++queueFails >= 3) return { own: true, why: "merge queue unreadable 3 times: own GUI leg" };
    }
    if (pos && !pos.found) {
      if (++missing >= 3) return { fail: true, why: `#${pr} left the merge queue without a verified covering GUI run` };
    } else if (pos) {
      missing = 0;
      if (pos.tail && now() - start >= settleMs) return { own: true, why: `#${pr} is the tail of the building window (position ${pos.position})` };
      if (!pos.tail) log(`#${pr} at position ${pos.position}; later entries: ${pos.later.map((n) => `#${n}`).join(", ")}`);
    }
    if (now() - start >= deadlineMs) return { fail: true, why: `no verified covering GUI run within ${Math.round(deadlineMs / 60000)} min and #${pr} is still not the tail` };
    await sleep(intervalMs);
  }
}

async function main() {
  const env = process.env;
  const num = (v, d) => (Number(v) > 0 ? Number(v) : d);
  const repo = env.GITHUB_REPOSITORY || "modelplan/modelplan";
  const sha = env.GITHUB_SHA;
  const out = (line) => env.GITHUB_OUTPUT && appendFileSync(env.GITHUB_OUTPUT, `${line}\n`);
  const say = (line) => { console.log(line); if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `${line}\n`); };
  const r = await defer({
    gh: client({ token: env.GITHUB_TOKEN, repo }), repo, sha, runId: Number(env.GITHUB_RUN_ID), ref: env.GITHUB_REF,
    sleep: (ms) => new Promise((ok) => setTimeout(ok, ms)),
    deadlineMs: num(env.GUI_DEFER_DEADLINE_MINUTES, 70) * 60000, intervalMs: num(env.GUI_DEFER_INTERVAL_SECONDS, 60) * 1000,
    settleMs: num(env.GUI_DEFER_SETTLE_SECONDS, 90) * 1000, log: (l) => console.log(l),
  });
  say(`D488 GUI defer: ${r.why}`);
  if (r.fail) { console.log(`::error::${r.why}`); process.exitCode = 1; return; }
  out(`own=${r.own ? "true" : "false"}`);
  // The record modelplan-gates reads back (evaluate.mjs readGuiCover). Keep the title.
  if (!r.own) console.log(`::notice title=${GUI_COVER_TITLE}::run=${r.cover.id} sha=${r.cover.head_sha}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try { await main(); } catch (e) { console.error(String(e?.stack || e)); process.exitCode = 1; }
}
