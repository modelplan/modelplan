// SPDX-License: MIT
// LBL-2.2-01..21 label/copy coverage (R48; copy fixes + catalog-wide walker, 11-07). Loads the
// shipped string catalogs and asserts each LBL wording rule that is checkable from them on Linux:
//   - Swift `SettingsText("en", "zh")` pairs and two-argument `.init("en", "zh")` pairs;
//   - Settings catalogue rows `.init(.id, "en", "zh", "en-subtitle", "zh-subtitle")` (label + subtitle);
//   - the Instruments catalogs' `copy("zh", "en")` pairs (HelpCatalog / HelpMapCatalog — note the order);
//   - shipped bilingual ternaries `zh ? "…" : "…"` / `chinese ? "…" : "…"` (the zh side always, the
//     immediate string English side when it is one);
//   - the cockpit help triples `['selector', 'en', 'zh']` (line-anchored: an unanchored pattern once
//     misread attributeFilter arrays as captions — the 'hidden' false positive).
// Rules that need visual/device evidence stay todo with the reason. LBL-2.2-06 (length budgets) stays
// an expected failure: the catalog does not yet record string classes per surface.
import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const pairs = [];
const add = (en, zh, at) => pairs.push({ en, zh, at });
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== "Tests") walk(p); continue; }
    if (!e.name.endsWith(".swift")) continue;
    const rel = path.relative(root, p);
    const lines = fs.readFileSync(p, "utf8").split("\n");
    for (const [i, line] of lines.entries()) {
      const at = `${rel}:${i + 1}`;
      let m = line.match(/SettingsText\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/);
      if (m) { add(m[1], m[2], at); continue; }
      // Settings catalogue row: .init(.id, "en", "zh", "en subtitle", "zh subtitle") — label and subtitle pairs.
      m = line.match(/\.init\(\s*\.[A-Za-z]+\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/);
      if (m) { add(m[1], m[2], at); add(m[3], m[4], at); continue; }
      m = line.match(/\.init\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/);
      if (m) { add(m[1], m[2], at); continue; }
      // Instruments catalogs (HelpCatalog / HelpMapCatalog): copy("zh", "en") — reversed order.
      m = line.match(/\bcopy\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/);
      if (m) { add(m[2], m[1], at); continue; }
      // Shipped bilingual ternaries: the zh side always; the en side only when it is an immediate string
      // (concatenated right-hand sides are skipped rather than half-read). Locale identifiers
      // (zh ? "zh_CN" : "en_US_POSIX") are formatter constants, not copy.
      m = line.match(/\b(?:zh|chinese)\s*\?\s*"((?:[^"\\]|\\.)*)"\s*(?::\s*"((?:[^"\\]|\\.)*)"\s*[),]?|$)/);
      const localeTag = (s) => /^[a-z]{2,3}([-_][A-Za-z0-9]+)+$/.test(s ?? "");
      if (m && localeTag(m[1]) && (!m[2] || localeTag(m[2]))) continue;
      if (m) { add(m[2] ?? "", m[1], at); continue; }
    }
  }
}
walk(path.join(root, "desktop", "native"));
// Cockpit help captions: ['selector','en','zh'] (line-anchored, so attributeFilter arrays never match).
const helpPath = path.join(root, "desktop", "cockpit", "src", "prototype-help.ts");
for (const [i, line] of fs.readFileSync(helpPath, "utf8").split("\n").entries()) {
  const m = line.match(/^\s*\['[^']*',\s*'([^']*)',\s*'([^']*)'/);
  if (m) add(m[1], m[2], `desktop/cockpit/src/prototype-help.ts:${i + 1}`);
}
const zh = pairs.map((p) => p.zh);
const en = pairs.map((p) => p.en);
const notCatalog = (id, lane) => `${id}: not catalog-checkable — needs device/render evidence (${lane})`;

test("the walker reads a substantial bilingual catalog", () => {
  assert.ok(pairs.length >= 150, `expected a substantial catalog, found ${pairs.length}`);
});

test("LBL-2.2-01 strip controls carry symbols, no text legends", { todo: notCatalog("LBL-2.2-01", "READERS") }, () => {});
test("LBL-2.2-02 other controls carry 1-2 word silkscreen label or symbol", { todo: notCatalog("LBL-2.2-02", "READERS") }, () => {});
test("LBL-2.2-03 toggle prints both states, active lit, controls never move", { todo: notCatalog("LBL-2.2-03", "READERS") }, () => {});
test("LBL-2.2-04 actions use symbols", { todo: notCatalog("LBL-2.2-04", "READERS") }, () => {});

test("LBL-2.2-05 every visible string goes through the two complete zh-CN/en tables", () => {
  // Catalog pairs (SettingsText / .init rows / copy() / help triples) are complete on both sides;
  // bilingual ternaries contribute their zh side always and their en side only when it is one string.
  const catalog = pairs.filter((p) => p.en.length > 0 && p.zh.length > 0);
  assert.ok(catalog.length >= 150, `expected a substantial paired catalog, found ${catalog.length}`);
  for (const p of pairs) {
    if (p.en.length === 0) continue; // a ternary whose right-hand side concatenates — zh still shipped
    assert.ok(p.zh.length > 0, `english-only pair "${p.en}" at ${p.at}`);
  }
});

test("LBL-2.2-06 string length budgets", { todo: "budget classes (silkscreen/card) are not recorded in the catalog; needs per-surface tagging" }, () => {
  assert.fail("silkscreen/card string classes are not recorded; cannot assert budgets from the catalog");
});

const englishTokensAllowed = ["ALERT", "MCP", "Codex", "GLM", "ZCode", "Z.ai", "OpenCode", "Cursor", "Copilot",
  "Qwen", "Kimi", "Kiro", "Grok", "MiniMax", "Gemini", "Claude", "Antigravity", "Amp", "Droid", "token", "Token",
  "API", "JSON", "CLI", "3D", "Esc", "Tauri",
  // identifier-class names kept identical on the English side: the OS, the Escape key, the Agent
  // concept, and the CLI's own disconnect instructions.
  "macOS", "Escape", "Agent", "disconnect"];
const englishPhrasesAllowed = ["Claude Code", "ModelPlan", "Intel"];
// Swift string interpolations \(expr) carry code identifiers, not English copy; drop them with a
// balanced scan (nesting such as \(Int((age / 60).rounded())) defeats a one-level regex).
const stripInterpolations = (s) => {
  let out = "", i = 0;
  while (i < s.length) {
    if (s[i] === "\\" && s[i + 1] === "(") {
      let depth = 0, j = i + 1;
      do { if (s[j] === "(") depth++; else if (s[j] === ")") depth--; j++; } while (j < s.length && depth > 0);
      i = j;
    } else { out += s[i]; i++; }
  }
  return out;
};
test("LBL-2.2-07 no English inside the Chinese UI except ALERT, model names and units", () => {
  const bad = [];
  for (const p of pairs) {
    if (!p.zh) continue;
    let s = stripInterpolations(p.zh);
    for (const phrase of englishPhrasesAllowed) s = s.split(phrase).join(" ");
    const hits = s.match(/[A-Za-z][A-Za-z.]{1,}/g) ?? [];
    for (const h of hits) if (!englishTokensAllowed.includes(h)) bad.push(`${h} in "${p.zh}" (${p.at})`);
  }
  assert.deepEqual(bad, []);
});

test("LBL-2.2-08 product name is ModelPlan, one word", () => {
  for (const p of pairs) {
    const hit = p.en.match(/model\s?plan\w*/i) ?? p.zh.match(/model\s?plan\w*/i);
    assert.ok(!hit || hit[0] === "ModelPlan", `${p.at}: "${hit?.[0]}" is not the one-word ModelPlan`);
  }
});

test("LBL-2.2-09 relative times only; no calendar dates for resets or expiries", () => {
  // Month names count as dates only before a day number ("May 5"); bare "May run out" is prose.
  const dateish = /(\d{4}\s*年)|(\d{1,2}\s*月\d{1,2}\s*日)|(\d{1,2}\/\d{1,2}\/\d{2,4})|\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}\b/;
  for (const p of pairs) {
    assert.doesNotMatch(p.zh ?? "", dateish, `zh "${p.zh}" (${p.at})`);
    assert.doesNotMatch(p.en, dateish, `en "${p.en}" (${p.at})`);
  }
});

test("LBL-2.2-10 one name per concept across surfaces", () => {
  for (const p of pairs) {
    if (/Cockpit/i.test(p.en)) assert.match(p.zh ?? "", /驾驶舱/, `${p.at}`);
    if ((p.zh ?? "").includes("驾驶舱")) assert.match(p.en || "驾驶舱", /Cockpit/i, `${p.at}`);
    if (/Widget/i.test(p.en)) assert.match(p.en, /Quota Widget/, `${p.at}`);
  }
});

test("LBL-2.2-11 reset count wording; never 重置卡 / reset cards", () => {
  for (const p of pairs) {
    assert.doesNotMatch(p.zh ?? "", /重置卡/, `${p.at}`);
    assert.doesNotMatch(p.en, /reset cards?/i, `${p.at}`);
  }
});

test("LBL-2.2-12 quota is what is left (额度 · 剩余 / Quota · left)", () => {
  assert.ok(
    pairs.some((p) => p.zh.includes("剩余") && /left|remaining/i.test(p.en)),
    "no catalog line frames quota as what is left (剩余/left)",
  );
});

test("LBL-2.2-13 user-visible surface and part names (glossary)", () => {
  const glossary = [["额度挂件", "Quota Widget"], ["驾驶舱", "Cockpit"], ["悬窗", "Window"], ["公共屏", "Main screen"],
    ["推杆", "Fader"], ["注意灯", "Alert lamp"], ["点火钮", "Ignition"], ["隐藏条", "Sliver"]];
  const missing = glossary.filter(([z]) => !zh.some((s) => s.includes(z)));
  assert.deepEqual(missing, []);
});

test("LBL-2.2-14 public reset wording, full and narrow", () => {
  assert.ok(zh.some((s) => s.includes("预告")), "announced-reset wording (预告) missing");
  assert.ok(zh.some((s) => s.includes("已重置")), "confirmed-reset wording (已重置) missing");
});

const internalWords = ["source scope", "read here", "observation", "fixture", "envelope", "未报告单位", "读数可用", "在设置检查读取权限", "正在显示保留的旧读数在允许时刷新"];
test("LBL-2.2-15 avoid internal words in UI", () => {
  const bad = [];
  for (const p of pairs) for (const w of internalWords) if (p.en.includes(w) || (p.zh ?? "").includes(w)) bad.push(`${w} (${p.at})`);
  assert.deepEqual(bad, []);
});

test("LBL-2.2-16 ALERT stays English on the lamp face in both languages", () => {
  for (const p of pairs) {
    if (/\bALERT\b/.test(p.en)) assert.match(p.zh ?? "", /\bALERT\b/, `${p.at}: zh must keep ALERT`);
    if (/警告/.test(p.zh ?? "")) assert.doesNotMatch(p.en, /\bALERT\b/, `${p.at}: en uses ALERT but zh translates it`);
  }
});

test("LBL-2.2-17 speed and today figures name their basis in help", () => {
  assert.ok(zh.some((s) => s.includes("近 60 秒")), "last-60s basis caption missing");
  assert.ok(zh.some((s) => s.includes("今日平均")), "today-average basis caption missing");
  assert.ok(zh.some((s) => s.includes("平均")), "session-average basis caption missing");
});

test("LBL-2.2-18 language setting offers Chinese and English", () => {
  assert.ok(en.some((s) => /\bEnglish\b/.test(s)) && zh.some((s) => s.includes("中文")),
    "language options (English/中文) missing from the catalogs");
});

test("LBL-2.2-19 default UI language on first launch", { todo: notCatalog("LBL-2.2-19", "M6") }, () => {});
test("LBL-2.2-20 each surface renders in one language with glossary terms", { todo: notCatalog("LBL-2.2-20", "M6") }, () => {});

test("LBL-2.2-21 额度挂件 / Quota Widget everywhere user-visible", () => {
  for (const p of pairs) {
    if ((p.zh ?? "").includes("挂件")) assert.match(p.zh, /额度挂件/, `${p.at}: 挂件 without 额度挂件`);
    if (/Widget/i.test(p.en)) assert.match(p.en, /Quota Widget/, `${p.at}: widget name not canonical`);
  }
});
