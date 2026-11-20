// SPDX-License-Identifier: MIT
// pr-review-sol.yml step "Post the verdict". The only step that sees the comment token. It re-reads the PR first: the
// head must still be the reviewed one and this lane must not have posted there meanwhile (duplicate delivery). The
// comment quotes the model's answer and ends with the one VERDICT line this workflow vouches for (R19 format).
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { client } from "../merge-gates/github.mjs";
import { feed, TRUSTED } from "../merge-gates/rules.mjs";
import { secretHits } from "./brief.mjs";
import { agreement, parseAnswer, postProblem, renderSolComment, SOL_SHADOW_LANE } from "./sol.mjs";

const env = process.env;
const dir = join(env.RUNNER_TEMP, "pr-review-sol");
const fail = (why) => { console.error(`pr-review-sol: not posted: ${why}`); process.exit(1); };
const say = (s) => { console.log(`pr-review-sol: ${s}`); if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, s + "\n"); };
const read = (p) => (existsSync(p) ? readFileSync(p, "utf8") : "");
const head = String(env.HEAD_SHA ?? "");
if (!/^[0-9a-f]{40}$/.test(head)) fail("no head sha");
const answer = parseAnswer(read(join(dir, "answer.md")), head);
// R18: an answer without a final VERDICT or record gives no verdict; the next trigger (or a dispatch) reviews again.
if (!answer.ok) fail(answer.why);

if (!env.GH_TOKEN) fail("PR_REVIEW_COMMENT_TOKEN is not set in the pr-review environment");
const gh = client({ token: env.GH_TOKEN, repo: env.GITHUB_REPOSITORY });
const me = await gh.get("https://api.github.com/user");
if (me?.id !== TRUSTED.id || me?.login !== TRUSTED.login) fail("the comment token does not belong to the trusted account");
const n = Number(env.PR);
// Re-check right before posting: a newer head makes this review stale; a verdict this lane already posted at the head
// (a second delivery of the same event) makes it a duplicate.
const pr = await gh.get(`/pulls/${n}`);
const items = feed(await gh.all(`/issues/${n}/comments`), await gh.all(`/pulls/${n}/reviews`));
const late = postProblem({ pr, items, head, lane: env.LANE, force: env.FORCE === "true" });
if (late) { say(`#${n}: ${late}; nothing posted`); process.exit(0); }

let usage = null;
try { usage = JSON.parse(read(join(dir, "usage.json"))); } catch {}
const meta = { model: env.MODEL, effort: env.EFFORT, seconds: read(join(dir, "seconds")).trim() || "?", usage, runUrl: env.RUN_URL };
// Shadow runs log how the lane that counts has judged this head so far (D352: compare on three PRs before cutover).
const shadow = env.LANE === SOL_SHADOW_LANE;
const agreeNow = shadow ? agreement([...items, { kind: "comment", user: TRUSTED, body: `VERDICT: ${answer.verdict} @ ${head} (${env.LANE})`, at: "~" }], head, env.LANE) : null;
const body = renderSolComment({ answer, head, lane: env.LANE, mode: env.MODE, base: env.BASE, tier: env.TIER, meta, agree: agreeNow?.text ?? "" });
if (secretHits(body)) fail("the comment looks like it contains a credential");
await gh.post(`/issues/${n}/comments`, { body });
say(`posted ${answer.verdict} @ ${head} as (${env.LANE}); ${meta.seconds} s${usage ? `, tokens in ${usage.input} (cached ${usage.cached}) out ${usage.output}` : ""}`);
if (agreeNow) say(agreeNow.text);
