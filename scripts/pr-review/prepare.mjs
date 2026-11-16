// SPDX-License-Identifier: MIT
// pr-review.yml step "Decide and build the brief". Runs from main's checkout with the read-only job token. It decides
// whether this PR head gets a review, fetches the head as data into a detached worktree (nothing from it is run),
// writes the patches and the brief under $RUNNER_TEMP/pr-review, and sets the step outputs review/head/tier/mode.
import { appendFileSync, existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { client } from "../merge-gates/github.mjs";
import { feed } from "../merge-gates/rules.mjs";
import { buildBrief, decide } from "./brief.mjs";

const env = process.env;
const output = (k, v) => appendFileSync(env.GITHUB_OUTPUT, `${k}=${v}\n`);
const summary = (s) => env.GITHUB_STEP_SUMMARY && appendFileSync(env.GITHUB_STEP_SUMMARY, s + "\n");
const git = (...args) => execFileSync("git", ["-c", "core.hooksPath=/dev/null", ...args], { encoding: "utf8", maxBuffer: 256 << 20 });
const tryGit = (...args) => { try { git(...args); return true; } catch { return false; } };

const n = Number(env.PR);
if (!Number.isInteger(n) || n <= 0) throw new Error("PR is not a number");
const repo = env.GITHUB_REPOSITORY;
const gh = client({ token: env.GITHUB_TOKEN, repo });
const pr = await gh.get(`/pulls/${n}`);
const files = await gh.all(`/pulls/${n}/files`);
const items = feed(await gh.all(`/issues/${n}/comments`), await gh.all(`/pulls/${n}/reviews`));
let d = decide({ pr, files, items, runHead: env.RUN_HEAD ?? "", lane: env.LANE, force: env.FORCE === "true" });

// A manual dispatch keeps the compile-first rule: ci must have passed at this exact head.
if (d.review && !env.RUN_HEAD) {
  const runs = (await gh.get(`/actions/workflows/ci.yml/runs?head_sha=${d.head}&event=pull_request&per_page=20`)).workflow_runs ?? [];
  const last = runs.sort((a, b) => (a.created_at < b.created_at ? 1 : -1))[0];
  if (!last || last.status !== "completed" || last.conclusion !== "success") d = { review: false, why: "ci has not passed at this head" };
}

if (!d.review) {
  console.log(`pr-review: skip #${n}: ${d.why}`);
  summary(`Skipped #${n}: ${d.why}`);
  output("review", "false");
  process.exit(0);
}

const dir = join(env.RUNNER_TEMP, "pr-review");
rmSync(dir, { recursive: true, force: true });
mkdirSync(dir, { recursive: true });
// Public repository: anonymous fetch, no credential in the checkout.
git("fetch", "--no-tags", "--filter=blob:none", "origin", `+refs/pull/${n}/head:refs/pr-review/head`, "+refs/heads/main:refs/remotes/origin/main");
if (git("rev-parse", "refs/pr-review/head").trim() !== d.head) {
  console.log(`pr-review: skip #${n}: head moved while preparing`);
  output("review", "false");
  process.exit(0);
}
// Delta review needs the older head and a fast-forward to the new one; after a force push it is a complete review.
if (d.since) {
  const have = tryGit("cat-file", "-e", `${d.since}^{commit}`) || tryGit("fetch", "--no-tags", "--filter=blob:none", "origin", d.since);
  if (!have || !tryGit("merge-base", "--is-ancestor", d.since, d.head)) d = { ...d, mode: "full", since: null, earlier: [] };
}
// A job killed before its clean-up step leaves the old worktree registered; drop it first.
git("worktree", "prune");
git("worktree", "add", "--quiet", "--detach", join(dir, "pr"), d.head);
const base = git("merge-base", "refs/remotes/origin/main", d.head).trim();
const paths = { diff: join(dir, "diff.patch"), files: join(dir, "files.txt"), delta: join(dir, "delta.patch") };
writeFileSync(paths.diff, git("diff", "--no-color", "--no-ext-diff", base, d.head));
writeFileSync(paths.files, git("diff", "--name-status", "--no-color", base, d.head));
if (d.since) writeFileSync(paths.delta, git("diff", "--no-color", "--no-ext-diff", d.since, d.head));
const stat = git("diff", "--stat=160", "--no-color", base, d.head);
const referenceMap = existsSync("scripts/merge-gates/reference-map.json");
writeFileSync(join(dir, "brief.md"), buildBrief({ pr, d, lane: env.LANE, paths, stat, referenceMap }));

console.log(`pr-review: review #${n} @ ${d.head} tier ${d.tier} ${d.mode}${d.since ? ` since ${d.since}` : ""} as (${env.LANE})`);
summary(`Reviewing #${n} @ \`${d.head}\` — tier ${d.tier}, ${d.mode} review, lane (${env.LANE})`);
output("review", "true");
output("head", d.head);
output("tier", String(d.tier));
output("mode", d.mode);
