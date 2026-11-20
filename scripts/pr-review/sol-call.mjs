// SPDX-License-Identifier: MIT
// pr-review-sol.yml step "Review". The only step that sees the model credentials (OPENAI_API_KEY, GLM_API_KEY,
// GLM_BASE_URL). It sends the prepared request (main's policy plus the PR as data) to the providers in the order
// vars.REVIEW_PROVIDER_MODE picks among those whose verdict counts here (PROVIDERS, from the prepare step); a quota
// error moves on to the next one, and when all are out of quota it records a wait (providers.mjs). No tool, file or
// network access is offered to the model and nothing from the PR is executed. The answer goes to a file, never to the
// public job log, and is refused if it contains a credential.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fallbackEnabled, glmProvider, openaiProvider, providerOrder, reviewInOrder } from "./providers.mjs";

const env = process.env;
const dir = join(env.RUNNER_TEMP, "pr-review-sol");
const fail = (why) => { console.error(`pr-review-sol: no review: ${why}`); process.exit(1); };
const num = (v, d) => (Number(v) > 0 ? Number(v) : d);
const start = Date.now();
const input = readFileSync(join(dir, "request.md"), "utf8");
// SOL_API_URL / SOL_POLL_MS / SOL_RETRY_MS / SOL_NOW exist for the tests; the workflow never sets them.
const waitMs = env.SOL_RETRY_MS !== undefined ? Number(env.SOL_RETRY_MS) : undefined;
const allowed = String(env.PROVIDERS ?? "openai").split(",").filter(Boolean);
const order = providerOrder({ mode: env.PROVIDER_MODE, now: env.SOL_NOW ? new Date(env.SOL_NOW) : new Date(), allowed, fallback: fallbackEnabled(env.GLM_FALLBACK) });
const build = (name) => name === "glm"
  ? glmProvider({ key: env.GLM_API_KEY, baseUrl: env.GLM_BASE_URL, waitMs })
  : openaiProvider({ key: env.OPENAI_API_KEY, model: env.MODEL, effort: env.EFFORT, url: env.SOL_API_URL || undefined, pollMs: num(env.SOL_POLL_MS, 15000), deadlineMs: num(env.SOL_TIMEOUT, 1800) * 1000, waitMs });
let r;
try { r = await reviewInOrder({ input, order, build }); } catch (e) { fail(e.message); }
writeFileSync(join(dir, "provider"), r.provider);
writeFileSync(join(dir, "seconds"), String(Math.round((Date.now() - start) / 1000)));
writeFileSync(join(dir, "why"), r.why ?? "");
if (r.provider === "waiting") {
  writeFileSync(join(dir, "who"), r.who.join(","));
  console.log(`pr-review-sol: every provider is out of quota (${r.why}); the head waits`);
  process.exit(0);
}
if (!r.text.trim()) fail(`empty answer from ${r.provider}`);
for (const k of [env.OPENAI_API_KEY, env.GLM_API_KEY]) if (k && r.text.includes(k)) fail("the answer contains an API key");
writeFileSync(join(dir, "answer.md"), r.text);
writeFileSync(join(dir, "model"), r.model ?? "");
writeFileSync(join(dir, "usage.json"), JSON.stringify(r.usage));
if (r.why) console.log(`pr-review-sol: quota out (${r.why}); answered by ${r.provider}`);
console.log(`pr-review-sol: answer from ${r.provider} (order ${order.join(" > ")}) after ${Math.round((Date.now() - start) / 1000)} s; tokens in ${r.usage.input} out ${r.usage.output}`);
