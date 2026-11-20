// SPDX-License-Identifier: MIT
// pr-review-sol.yml step "Review with Sol". The only step that sees the OpenAI API key. It sends the prepared request
// (main's policy plus the PR as data) to the Responses API and writes the answer under $RUNNER_TEMP/pr-review-sol.
// No tool, file or network access is offered to the model, and nothing from the PR is executed. The answer goes to a
// file, never to the public job log; it is refused if it contains the key.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const env = process.env;
const dir = join(env.RUNNER_TEMP, "pr-review-sol");
const fail = (why) => { console.error(`pr-review-sol: no review: ${why}`); process.exit(1); };
const key = env.OPENAI_API_KEY;
if (!key) fail("OPENAI_API_KEY is not set in the pr-review environment");
// SOL_API_URL exists for the tests' local fake server; the workflow never sets it.
const API = env.SOL_API_URL || "https://api.openai.com/v1/responses";
const headers = { authorization: `Bearer ${key}`, "content-type": "application/json" };
const DEADLINE_MS = (Number(env.SOL_TIMEOUT) > 0 ? Number(env.SOL_TIMEOUT) : 1800) * 1000;

async function call(method, url, body) {
  for (let attempt = 0; ; attempt++) {
    let r;
    try { r = await fetch(url, { method, headers, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(120000) }); }
    catch (e) { if (attempt < 3) { await sleep(5000 * (attempt + 1)); continue; } fail(`network error (${e.name})`); }
    if ((r.status >= 500 || r.status === 429) && attempt < 3) { await sleep(10000 * (attempt + 1)); continue; }
    const j = await r.json().catch(() => null);
    // Only the status and the error code are printed; error bodies never echo the key, but nothing else is needed.
    if (!r.ok) fail(`${method} responses: HTTP ${r.status} ${j?.error?.code ?? j?.error?.type ?? ""}`);
    return j;
  }
}
const sleep = (ms) => new Promise((ok) => setTimeout(ok, ms));

const start = Date.now();
const input = readFileSync(join(dir, "request.md"), "utf8");
// Background mode: a medium-effort review can think for longer than an HTTP response may stay open.
let res = await call("POST", API, { model: env.MODEL, reasoning: { effort: env.EFFORT }, input, background: true, store: true, max_output_tokens: 64000 });
while (["queued", "in_progress"].includes(res?.status)) {
  if (Date.now() - start > DEADLINE_MS) {
    await call("POST", `${API}/${encodeURIComponent(res.id)}/cancel`).catch(() => {});
    fail("timed out");
  }
  await sleep(Number(env.SOL_POLL_MS) > 0 ? Number(env.SOL_POLL_MS) : 15000);
  res = await call("GET", `${API}/${encodeURIComponent(res.id)}`);
}
if (res?.status !== "completed") fail(`response ${res?.status ?? "missing"}${res?.incomplete_details?.reason ? ` (${res.incomplete_details.reason})` : ""}`);
const text = (res.output ?? []).filter((o) => o.type === "message").flatMap((o) => o.content ?? []).filter((c) => c.type === "output_text").map((c) => c.text).join("");
if (!text.trim()) fail("empty answer");
if (text.includes(key)) fail("the answer contains the API key");
const u = res.usage ?? {};
writeFileSync(join(dir, "answer.md"), text);
writeFileSync(join(dir, "usage.json"), JSON.stringify({ input: u.input_tokens ?? 0, cached: u.input_tokens_details?.cached_tokens ?? 0, output: u.output_tokens ?? 0 }));
writeFileSync(join(dir, "seconds"), String(Math.round((Date.now() - start) / 1000)));
console.log(`pr-review-sol: answer received after ${Math.round((Date.now() - start) / 1000)} s; tokens in ${u.input_tokens ?? "?"} out ${u.output_tokens ?? "?"}`);
