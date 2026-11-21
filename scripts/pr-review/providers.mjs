// SPDX-License-Identifier: MIT
// Model providers for the Sol workflow reviewer (pr-review-sol.yml, D352). Each provider is { name, review(input) }
// and resolves to { text, usage: { input, cached, output } } or throws a ProviderError. kind "quota" means the account
// cannot pay for the call (insufficient_quota, billing hard limit, or 429 that outlasted every retry); only that kind
// moves on to the other provider. OpenAI: the Responses API called directly (the owner's API credit covers direct
// Responses calls, not the codex CLI). GLM: Zhipu GLM-5.3 through its OpenAI-compatible chat endpoint. Which goes
// first is vars.REVIEW_PROVIDER_MODE (providerOrder).
export class ProviderError extends Error {
  constructor(kind, message) { super(message); this.kind = kind; }
}
// OpenAI: insufficient_quota and the billing limits. Zhipu (string codes): 1113 balance or resource package exhausted,
// 1304 daily call limit, 1308 usage limit reached, 1310 weekly/monthly limit.
const QUOTA_CODES = new Set(["insufficient_quota", "billing_hard_limit_reached", "billing_hard_limit", "billing_not_active", "1113", "1304", "1308", "1310"]);
export const isQuotaCode = (code) => QUOTA_CODES.has(String(code ?? ""));

const sleep = (ms) => new Promise((ok) => setTimeout(ok, ms));

// One JSON request with retries for network errors, 5xx and 429. A quota code ends it at once; a 429 that survives
// every retry (about two minutes with the default waits) is a sustained 429 and counts as quota.
async function requestJson(fetchImpl, url, init, { retries = 5, waitMs = 8000, label }) {
  for (let attempt = 0; ; attempt++) {
    let r;
    try { r = await fetchImpl(url, { ...init, signal: AbortSignal.timeout(180000) }); }
    catch (e) { if (attempt < retries) { await sleep(waitMs * (attempt + 1)); continue; } throw new ProviderError("other", `${label}: network error (${e.name})`); }
    const j = await r.json().catch(() => null);
    const code = j?.error?.code ?? j?.error?.type ?? "";
    if (r.ok) return j;
    if (isQuotaCode(code)) throw new ProviderError("quota", `${label}: HTTP ${r.status} ${code}`);
    if ((r.status === 429 || r.status >= 500) && attempt < retries) { await sleep(waitMs * (attempt + 1)); continue; }
    // Only the status and the error code are reported; error bodies never echo the key, but nothing else is needed.
    throw new ProviderError(r.status === 429 ? "quota" : "other", `${label}: HTTP ${r.status} ${code}${r.status === 429 ? " (sustained)" : ""}`);
  }
}

export function openaiProvider({ key, model, effort, url = "https://api.openai.com/v1/responses", fetchImpl = fetch, pollMs = 15000, deadlineMs = 1800000, waitMs }) {
  if (!key) throw new ProviderError("config", "OPENAI_API_KEY is not set");
  const init = (method, body) => ({ method, headers: { authorization: `Bearer ${key}`, "content-type": "application/json" }, body: body ? JSON.stringify(body) : undefined });
  const opts = { label: "openai", ...(waitMs !== undefined ? { waitMs } : {}) };
  return {
    name: "openai",
    model,
    async review(input) {
      const start = Date.now();
      // Background mode: a medium-effort review can think for longer than an HTTP response may stay open.
      let res = await requestJson(fetchImpl, url, init("POST", { model, reasoning: { effort }, input, background: true, store: true, max_output_tokens: 64000 }), opts);
      while (["queued", "in_progress"].includes(res?.status)) {
        if (Date.now() - start > deadlineMs) {
          await requestJson(fetchImpl, `${url}/${encodeURIComponent(res.id)}/cancel`, init("POST"), { ...opts, retries: 0 }).catch(() => {});
          throw new ProviderError("other", "openai: timed out");
        }
        await sleep(pollMs);
        res = await requestJson(fetchImpl, `${url}/${encodeURIComponent(res.id)}`, init("GET"), opts);
      }
      if (res?.status !== "completed") {
        const code = res?.error?.code ?? "";
        throw new ProviderError(isQuotaCode(code) ? "quota" : "other", `openai: response ${res?.status ?? "missing"} ${code || res?.incomplete_details?.reason || ""}`.trim());
      }
      const text = (res.output ?? []).filter((o) => o.type === "message").flatMap((o) => o.content ?? []).filter((c) => c.type === "output_text").map((c) => c.text).join("");
      const u = res.usage ?? {};
      return { text, usage: { input: u.input_tokens ?? 0, cached: u.input_tokens_details?.cached_tokens ?? 0, output: u.output_tokens ?? 0 } };
    },
  };
}

// GLM-5.3, the full model (not a flash variant), through the OpenAI-compatible chat completions endpoint.
export const GLM_MODEL = "glm-5.3";
export function glmProvider({ key, baseUrl, model = GLM_MODEL, fetchImpl = fetch, waitMs }) {
  if (!key || !baseUrl) throw new ProviderError("config", "GLM_API_KEY or GLM_BASE_URL is not set");
  if (/flash/i.test(model)) throw new ProviderError("config", "the GLM fallback uses the full model, not flash");
  const url = `${String(baseUrl).replace(/\/+$/, "")}/chat/completions`;
  return {
    name: "glm",
    model,
    async review(input) {
      const j = await requestJson(fetchImpl, url, {
        method: "POST", headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
        body: JSON.stringify({ model, messages: [{ role: "user", content: input }], stream: false, max_tokens: 32000 }),
      }, { label: "glm", ...(waitMs !== undefined ? { waitMs } : {}) });
      const u = j?.usage ?? {};
      return { text: j?.choices?.[0]?.message?.content ?? "", usage: { input: u.prompt_tokens ?? 0, cached: u.prompt_tokens_details?.cached_tokens ?? 0, output: u.completion_tokens ?? 0 } };
    },
  };
}

// vars.REVIEW_PROVIDER_MODE: "gpt-first" (default), "glm-first", or "schedule": GPT during the Zhipu peak
// (06:00-10:00 UTC, Monday to Friday) and GLM otherwise. allowed: the providers whose verdict counts here (decideSol).
// The other provider is the quota fallback unless vars.PR_REVIEW_GLM_FALLBACK is "off".
export const PROVIDER_MODES = Object.freeze(["gpt-first", "glm-first", "schedule"]);
export function isZhipuPeak(date) {
  const day = date.getUTCDay(), h = date.getUTCHours();
  return day >= 1 && day <= 5 && h >= 6 && h < 10;
}
export function providerOrder({ mode, now = new Date(), allowed = ["openai", "glm"], fallback = true }) {
  const m = PROVIDER_MODES.includes(mode) ? mode : "gpt-first";
  const glmFirst = m === "glm-first" || (m === "schedule" && !isZhipuPeak(now));
  const order = (glmFirst ? ["glm", "openai"] : ["openai", "glm"]).filter((p) => allowed.includes(p));
  return fallback ? order : order.slice(0, 1);
}
// vars.PR_REVIEW_GLM_FALLBACK: "off" turns the fallback off entirely; anything else (unset included) leaves it on.
export const fallbackEnabled = (v) => String(v ?? "").trim().toLowerCase() !== "off";

// order: provider names; build(name): the provider (built lazily, so missing credentials of an unused provider do not
// matter). Tries them in order; only a quota error moves on. Resolves to { provider, model, text, usage, why } or, when
// every provider tried was out of quota, { provider: "waiting", who, why }.
export async function reviewInOrder({ input, order, build }) {
  const out = [];
  for (const name of order) {
    try {
      const p = build(name);
      return { provider: p.name, model: p.model, ...(out.length ? { why: out.join("; ") } : {}), ...(await p.review(input)) };
    } catch (e) {
      if (!(e instanceof ProviderError) || e.kind !== "quota") throw e;
      out.push(e.message);
    }
  }
  return { provider: "waiting", who: order, why: out.join("; ") || "no provider can review this tier" };
}
