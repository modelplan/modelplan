// SPDX-License-Identifier: MIT
// pr-review-sol.yml step "Decide and build the request". Runs from main's checkout with the read-only job token and no
// secret. It decides whether this PR head gets a Sol review (decideSol), fetches the head as data (git objects only:
// nothing from the PR is checked out, built, installed or run), writes the request under $RUNNER_TEMP/pr-review-sol
// and sets the step outputs review/head/tier/mode/base.
import { appendFileSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { client } from "../merge-gates/github.mjs";
import { feed, parseGlmTiers } from "../merge-gates/rules.mjs";
import { OVERSIZE_EVENT, buildSolPrompt, compileRunProblem, compileStatus, decideSol, diffOmitReason, omitGeneratedDiffs } from "./sol.mjs";

const env = process.env;
const output = (k, v) => appendFileSync(env.GITHUB_OUTPUT, `${k}=${v}\n`);
const summary = (s) => env.GITHUB_STEP_SUMMARY && appendFileSync(env.GITHUB_STEP_SUMMARY, s + "\n");
const git = (...args) => execFileSync("git", ["-c", "core.hooksPath=/dev/null", ...args], { encoding: "utf8", maxBuffer: 512 << 20 });
const gitBuf = (...args) => execFileSync("git", ["-c", "core.hooksPath=/dev/null", ...args], { maxBuffer: 512 << 20 });
const tryGit = (...args) => { try { git(...args); return true; } catch { return false; } };
const stop = (n, why) => { console.log(`pr-review-sol: skip #${n}: ${why}`); summary(`Skipped #${n}: ${why}`); output("review", "false"); process.exit(0); };

// Request budget in characters (about 4 per token). Patches always go in whole or the head is not reviewed here; file
// texts fill what is left, smallest first.
const MAX_PROMPT_CHARS = Number(env.SOL_MAX_PROMPT_CHARS) > 0 ? Number(env.SOL_MAX_PROMPT_CHARS) : 700000;
const MAX_FILE_CHARS = 120000;

const n = Number(env.PR);
if (!Number.isInteger(n) || n <= 0) throw new Error("PR is not a number");
const repo = env.GITHUB_REPOSITORY;
const gh = client({ token: env.GITHUB_TOKEN, repo });
const pr = await gh.get(`/pulls/${n}`);
const files = await gh.all(`/pulls/${n}/files`);
const items = feed(await gh.all(`/issues/${n}/comments`), await gh.all(`/pulls/${n}/reviews`));
const head = String(pr.head?.sha ?? "");

// Both readiness checks are read fresh for the exact head, whichever event started the run.
const checks = { ci: false, compile: false };
if (/^[0-9a-f]{40}$/.test(head)) {
  const runs = (await gh.get(`/actions/workflows/ci.yml/runs?head_sha=${head}&event=pull_request&per_page=20`)).workflow_runs ?? [];
  const last = runs.sort((a, b) => (a.created_at < b.created_at ? 1 : -1))[0];
  checks.ci = !!last && last.status === "completed" && last.conclusion === "success";
  const st = compileStatus(await gh.get(`/commits/${head}/statuses?per_page=100`), repo);
  if (st.ok) {
    const problem = compileRunProblem(await gh.get(`/actions/runs/${st.runId}`), repo, head, n);
    checks.compile = !problem;
    if (problem) console.log(`pr-review-sol: mac-compile status not trusted: ${problem}`);
  }
}
let d = decideSol({ pr, files, items, lane: env.LANE, triggerSha: env.TRIGGER_SHA ?? "", checks, force: env.FORCE === "true", glmTiers: parseGlmTiers(env.REVIEW_GLM_TIERS) });
if (!d.review) stop(n, d.why);

const dir = join(env.RUNNER_TEMP, "pr-review-sol");
rmSync(dir, { recursive: true, force: true });
mkdirSync(dir, { recursive: true });
// Public repository: anonymous fetch, no credential in the checkout.
git("fetch", "--no-tags", "--filter=blob:none", "origin", `+refs/pull/${n}/head:refs/pr-review-sol/head`, "+refs/heads/main:refs/remotes/origin/main");
if (git("rev-parse", "refs/pr-review-sol/head").trim() !== d.head) stop(n, "head moved while preparing");
const mergeBase = git("merge-base", "refs/remotes/origin/main", d.head).trim();
// Delta review needs the older head as an ancestor; after a force push it is a complete review.
let mode = "full", base = mergeBase;
if (d.since) {
  const have = tryGit("cat-file", "-e", `${d.since}^{commit}`) || tryGit("fetch", "--no-tags", "--filter=blob:none", "origin", d.since);
  if (have && tryGit("merge-base", "--is-ancestor", d.since, d.head)) { mode = "delta"; base = d.since; }
}
d = { ...d, mode, base };
// The PR's own delta (D428): the diff from the merge base, so a main merged into the branch is not in it. Files whose head
// content is already what main has (a merged or reverted main change, a regenerated file that landed meanwhile) are no part
// of it either, and binary, generated and capture files (omitGeneratedDiffs) are left out of the size budget and said so.
const differsFromMain = new Set(git("diff", "--name-only", "--no-renames", "-z", "refs/remotes/origin/main", d.head).split("\0").filter(Boolean));
const same = new Set(git("diff", "--name-only", "--no-renames", "-z", mergeBase, d.head).split("\0").filter((p) => p && !differsFromMain.has(p)));
const omittedDiffs = [];
const diff = omitGeneratedDiffs(git("diff", "--no-color", "--no-ext-diff", mergeBase, d.head), undefined, { same, report: omittedDiffs });
const delta = mode === "delta" ? omitGeneratedDiffs(git("diff", "--no-color", "--no-ext-diff", d.since, d.head), undefined, { same }) : "";
const stat = git("diff", "--stat=160", "--no-color", mergeBase, d.head);
const changed = git("diff", "--name-only", "--no-renames", "--diff-filter=AMRT", "-z", mergeBase, d.head).split("\0").filter((p) => p && !same.has(p) && !diffOmitReason(p));   // the omitted files stay out of the file texts too
const deleted = git("diff", "--name-only", "--no-renames", "--diff-filter=D", "-z", mergeBase, d.head).split("\0").filter(Boolean);

const lane = env.LANE;
// The reviewer cannot run tests: it gets every check run and commit status at the head with its result.
const ciLines = [];
try {
  for (const c of await gh.all(`/commits/${d.head}/check-runs`, "check_runs", 300)) ciLines.push(`check ${c.name}: ${c.status === "completed" ? c.conclusion : c.status}`);
  const seen = new Set();
  for (const st of await gh.get(`/commits/${d.head}/statuses?per_page=100`)) if (!seen.has(st.context)) { seen.add(st.context); ciLines.push(`status ${st.context}: ${st.state}${st.description ? ` (${st.description})` : ""}`); }
} catch (e) { ciLines.push(`CI results could not be read (${e.message.slice(0, 80)})`); }
ciLines.sort();
const fixed = buildSolPrompt({ pr, d, lane, stat, diff, delta, checks: ciLines }).length;
if (fixed > MAX_PROMPT_CHARS) {
  // Not a silent skip (D428): the post step leaves one advisory "oversize" note for the head, and the coordinator routes the head
  // to an interactive Codex lane (its review-order row, land-loop.sh glm_grace_sweep).
  writeFileSync(join(dir, "provider"), "oversize");
  writeFileSync(join(dir, "oversize.json"), JSON.stringify({ chars: fixed, budget: MAX_PROMPT_CHARS, omitted: omittedDiffs }));
  console.log(`pr-review-sol: oversize #${n}: the patches of the own delta are ${fixed} characters, over the ${MAX_PROMPT_CHARS} budget (${omittedDiffs.length} files already left out); ${OVERSIZE_EVENT}`);
  summary(`Oversize #${n} @ \`${d.head}\`: ${fixed} characters over the ${MAX_PROMPT_CHARS} budget; an advisory note routes it to an interactive lane`);
  output("review", "false"); output("oversize", "true"); output("head", d.head); output("tier", String(d.tier)); output("mode", mode); output("base", base); output("gpt", String(d.gpt));
  process.exit(0);
}
writeFileSync(join(dir, "diff-omitted"), omittedDiffs.join("\n"));
const blobs = [];
for (const path of changed) {
  const buf = gitBuf("show", `${d.head}:${path}`);
  blobs.push({ path, binary: buf.includes(0), text: buf.includes(0) ? "" : buf.toString("utf8") });
}
let room = MAX_PROMPT_CHARS - fixed;
const contents = [], omitted = deleted.map((p) => `${p} (deleted)`);
for (const b of [...blobs].sort((a, b) => a.text.length - b.text.length)) {
  const cost = b.text.length + b.path.length + 40;
  if (b.binary) omitted.push(`${b.path} (binary)`);
  else if (b.text.length > MAX_FILE_CHARS || cost > room) omitted.push(`${b.path} (${b.text.length} characters)`);
  else { contents.push(b); room -= cost; }
}
contents.sort((a, b) => (a.path < b.path ? -1 : 1));
writeFileSync(join(dir, "request.md"), buildSolPrompt({ pr, d, lane, stat, diff, delta, contents, omitted, checks: ciLines }));

console.log(`pr-review-sol: review #${n} @ ${d.head} tier ${d.tier} ${mode} from ${base} as (${lane}); ${contents.length} files inline, ${omitted.length} omitted`);
summary(`Reviewing #${n} @ \`${d.head}\` — tier ${d.tier}, ${mode} review from \`${base.slice(0, 12)}\`, lane (${lane})${d.record ? `, carrying the record at \`${d.record.sha.slice(0, 12)}\`` : ""}`);
output("review", "true");
output("head", d.head);
output("tier", String(d.tier));
output("mode", mode);
output("base", base);
output("providers", d.providers.join(","));
// Per-PR override (label review:gpt, read from the REST pull request above): GPT first whatever REVIEW_PROVIDER_MODE says.
output("gpt", String(d.gpt));
output("provider_mode", d.gpt ? "gpt-first" : "");
