// SPDX-License-Identifier: MIT
// pr-review-sol.yml step "Post the verdict". The only step that sees the comment token. It re-reads the PR first: the
// head must still be the reviewed one and this lane must not have posted there meanwhile (duplicate delivery). The
// comment quotes the model's answer and ends with the one VERDICT line this workflow vouches for (R19 format).
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { client } from "../merge-gates/github.mjs";
import { feed, isShadowLane, parseGlmTiers, pathTier, prPaths, tierOverride, TRUSTED } from "../merge-gates/rules.mjs";
import { secretHits } from "./brief.mjs";
import { postWhy, agreement, parseAnswer, postLane, postProblem, noVerdictNoted, oversizeNoted, glmAdvisory, prClass, waitNoted, renderNoVerdictNote, renderOversizeNote, renderScopeNote, renderSolComment, renderWaitNote, scopeNoted, SCOPE_CHANGED } from "./sol.mjs";

const env = process.env;
const dir = join(env.RUNNER_TEMP, "pr-review-sol");
const fail = (why) => { console.error(`pr-review-sol: not posted: ${why}`); process.exit(1); };
const say = (s) => { console.log(`pr-review-sol: ${s}`); if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, s + "\n"); };
const read = (p) => (existsSync(p) ? readFileSync(p, "utf8") : "");
const head = String(env.HEAD_SHA ?? "");
if (!/^[0-9a-f]{40}$/.test(head)) fail("no head sha");
const provider = read(join(dir, "provider")).trim() || "openai";
const waiting = provider === "waiting";
const oversize = provider === "oversize";   // sol-prepare.mjs: the own delta is over the request budget (D428)
// sol-call.mjs asked twice and both answers failed the verdict format: a short advisory note instead of a verdict.
const noVerdict = !waiting && existsSync(join(dir, "noverdict")) ? read(join(dir, "noverdict")).trim() || "invalid answer" : "";
const answer = waiting || oversize || noVerdict ? null : parseAnswer(read(join(dir, "answer.md")), head);
// R18: an answer without a final VERDICT or record gives no verdict; the next trigger (or a dispatch) reviews again.
if (answer && !answer.ok) fail(answer.why);
const lane = postLane(env.LANE, provider);

if (!env.GH_TOKEN) fail("PR_REVIEW_COMMENT_TOKEN is not set in the pr-review environment");
const gh = client({ token: env.GH_TOKEN, repo: env.GITHUB_REPOSITORY });
const me = await gh.get("https://api.github.com/user");
if (me?.id !== TRUSTED.id || me?.login !== TRUSTED.login) fail("the comment token does not belong to the trusted account");
const n = Number(env.PR);
// Re-check right before posting: a newer head makes this review stale; a verdict this lane already posted at the head
// (a second delivery of the same event) makes it a duplicate.
// The PR is read on both sides of the comment lookup, so a head that moves while comments page in is caught (Sol SOL-3);
// the window left is the single POST below.
const pr = await gh.get(`/pulls/${n}`);
const items = feed(await gh.all(`/issues/${n}/comments`), await gh.all(`/pulls/${n}/reviews`));
const files = await gh.all(`/pulls/${n}/files`);
const prAfter = await gh.get(`/pulls/${n}`);
const check = { items, head, lane: env.LANE, posted: waiting || oversize ? null : lane, force: env.FORCE === "true", tier: Number(env.TIER), files, glmTiers: parseGlmTiers(env.REVIEW_GLM_TIERS) };
const late = postProblem({ pr, ...check }) ?? postProblem({ pr: prAfter, ...check });
const tierNow = tierOverride(items) ?? pathTier(prPaths(files));   // fresh, as postProblem used it
if (late?.startsWith(SCOPE_CHANGED)) {
  // The prepared scope no longer fits the trusted tier: post a non-counting notice once, never a verdict.
  if (!scopeNoted(items, head)) {
    const note = renderScopeNote({ head, lane: env.LANE, preparedTier: Number(env.TIER), tier: tierNow, runUrl: env.RUN_URL });
    await gh.post(`/issues/${n}/comments`, { body: note });
    console.log(`::warning::${note.split("\n")[0]}`);
  }
  say(`#${n}: ${late}; no verdict posted`);
  process.exit(0);
}
if (late) { say(`#${n}: ${late}; nothing posted`); process.exit(0); }

if (noVerdict) {
  if (noVerdictNoted(items, head)) { say(`#${n}: a no-verdict note for ${head} already exists`); process.exit(0); }
  const note = renderNoVerdictNote({ head, lane: env.LANE, why: noVerdict, runUrl: env.RUN_URL });
  await gh.post(`/issues/${n}/comments`, { body: note });
  console.log(`::warning::${note.split("\n")[0]}`);
  say(`#${n}: posted "${note.split("\n")[0]}"`);
  process.exit(0);
}

if (oversize) {
  // One coordinator event per head, like the waiting note: the interactive lane takes it from there.
  if (oversizeNoted(items, head)) { say(`#${n}: an oversize note for ${head} already exists`); process.exit(0); }
  let o = {}; try { o = JSON.parse(read(join(dir, "oversize.json"))); } catch {}
  const note = renderOversizeNote({ head, lane: env.LANE, chars: o.chars ?? "?", budget: o.budget ?? "?", omitted: o.omitted ?? [], runUrl: env.RUN_URL });
  await gh.post(`/issues/${n}/comments`, { body: note });
  console.log(`::warning::${note.split("\n")[0]}`);
  say(`#${n}: posted "${note.split("\n")[0]}"`);
  process.exit(0);
}

if (waiting) {
  // One coordinator event per head: the note is posted once; later runs for the same head only log.
  if (waitNoted(items, head)) { say(`#${n}: a review-waiting note for ${head} already exists`); process.exit(0); }
  const who = read(join(dir, "who")).trim().split(",").filter(Boolean);
  const note = renderWaitNote({ head, lane: env.LANE, tier: tierNow, who, why: read(join(dir, "why")).trim(), runUrl: env.RUN_URL });
  await gh.post(`/issues/${n}/comments`, { body: note });
  console.log(`::warning::${note.split("\n")[0]}`);
  say(`#${n}: posted "${note.split("\n")[0]}"`);
  process.exit(0);
}

let usage = null;
try { usage = JSON.parse(read(join(dir, "usage.json"))); } catch {}
// The reason line (postWhy, sol.mjs): quota fallback, a refused model and a model mismatch are stated apart.
const why = postWhy({ quota: read(join(dir, "why")), note: read(join(dir, "note")), provider, gptRequested: env.GPT_REQUESTED === "true", tier: tierNow });
const meta = { why, model: read(join(dir, "model")).trim() || env.MODEL, effort: provider === "openai" ? env.EFFORT : "default", seconds: read(join(dir, "seconds")).trim() || "?", usage, omittedDiffs: read(join(dir, "diff-omitted")).split("\n").filter(Boolean), runUrl: env.RUN_URL };
// Shadow runs log how the lane that counts has judged this head so far (D352: compare on three PRs before cutover).
const agreeNow = isShadowLane(lane) ? agreement([...items, { kind: "comment", user: TRUSTED, body: `VERDICT: ${answer.verdict} @ ${head} (${lane})`, at: "~" }], head, lane, tierNow, parseGlmTiers(env.REVIEW_GLM_TIERS)) : null;
const body = renderSolComment({ answer, head, lane, mode: env.MODE, base: env.BASE, tier: tierNow, meta, agree: agreeNow?.text ?? "" });
if (secretHits(body)) fail("the comment looks like it contains a credential");
await gh.post(`/issues/${n}/comments`, { body });
// macrev2-1254: a GLM answer where GLM may not decide is advice; the head still waits for a Sol/GPT verdict, so raise the
// waiting event once (the same coordinator event as when every provider is out).
if (provider === "glm" && lane === "ghglm" && glmAdvisory(prClass(pr, files, tierNow), tierNow, parseGlmTiers(env.REVIEW_GLM_TIERS)) && !waitNoted(items, head)) {
  const note = renderWaitNote({ head, lane: env.LANE, tier: tierNow, who: ["openai"], why: read(join(dir, "why")).trim() || "GPT quota out; GLM answered as advice", runUrl: env.RUN_URL });
  await gh.post(`/issues/${n}/comments`, { body: note });
}
say(`posted ${answer.verdict} @ ${head} as (${lane}) from ${provider}; ${meta.seconds} s${usage ? `, tokens in ${usage.input} (cached ${usage.cached}) out ${usage.output}` : ""}`);
if (agreeNow) say(agreeNow.text);
