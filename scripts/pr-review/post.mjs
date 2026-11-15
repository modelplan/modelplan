// SPDX-License-Identifier: MIT
// pr-review.yml step "Post the verdict". The only step that sees the comment token. It renders the comment itself
// (first line: the VERDICT this workflow vouches for; everything the model wrote is quoted), refuses to post if the
// comment contains anything that looks like a credential or the Codex login's own values, and checks that the token
// belongs to the trusted account before posting.
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { client } from "../merge-gates/github.mjs";
import { TRUSTED } from "../merge-gates/rules.mjs";
import { checkResult, renderComment, secretHits, secretLiterals, usageFrom } from "./brief.mjs";

const env = process.env;
const dir = join(env.RUNNER_TEMP, "pr-review");
const fail = (why) => { console.error(`pr-review: not posted: ${why}`); process.exit(1); };
const read = (p) => (existsSync(p) ? readFileSync(p, "utf8") : "");

let result;
try { result = JSON.parse(read(join(dir, "result.json"))); } catch { fail("the review result is not JSON"); }
const bad = checkResult(result);
if (bad) fail(`the review result does not match the schema (${bad})`);
if (!/^[0-9a-f]{40}$/.test(env.HEAD_SHA ?? "")) fail("no head sha");

const meta = { model: env.MODEL, effort: env.EFFORT, seconds: read(join(dir, "seconds")).trim() || "?", usage: usageFrom(read(join(dir, "events.jsonl"))), runUrl: env.RUN_URL };
const { verdict, body } = renderComment({ result, head: env.HEAD_SHA, lane: env.LANE, mode: env.MODE, tier: env.TIER, meta });

let literals = [];
try { literals = secretLiterals(JSON.parse(readFileSync(join(env.CODEX_HOME, "auth.json"), "utf8"))); } catch { fail("cannot read the Codex login to screen the comment"); }
if (secretHits(body, literals)) fail("the comment looks like it contains a credential");
literals = null;

if (!env.GH_TOKEN) fail("PR_REVIEW_COMMENT_TOKEN is not set in the pr-review environment");
const gh = client({ token: env.GH_TOKEN, repo: env.GITHUB_REPOSITORY });
const me = await gh.get("https://api.github.com/user");
if (me?.id !== TRUSTED.id || me?.login !== TRUSTED.login) fail("the comment token does not belong to the trusted account");
await gh.post(`/issues/${Number(env.PR)}/comments`, { body });

const counts = ["P1", "P2", "P3"].map((s) => `${s} ${result.findings.filter((f) => f.severity === s).length}`).join(", ");
const tokens = meta.usage ? `, tokens in ${meta.usage.input} (cached ${meta.usage.cached}) out ${meta.usage.output}` : "";
console.log(`pr-review: posted ${verdict} @ ${env.HEAD_SHA} (${env.LANE}); ${counts}; ${meta.seconds} s${tokens}`);
if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `Posted **${verdict}** as (${env.LANE}): ${counts}; ${meta.seconds} s${tokens}\n`);
