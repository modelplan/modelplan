// SPDX-License-Identifier: MIT
// LBL-2.2-01..21 label/copy coverage (R48). Scope: desktop/native and
// desktop/cockpit/src only; CLI and plugin text is not read. Loads the string catalogs
// (Swift SettingsText pairs across desktop/native Sources, plus the cockpit
// help triples) and asserts each LBL wording rule that is checkable from the
// catalogs on Linux. Rules that need visual/device evidence are marked todo
// with the reason.
import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const pairs = [];
const cjk = /[一-鿿]/;
const quoted = '"((?:[^"\\\\\\n]|\\\\.)*)"';
// Every form the shipped code uses to pair the two languages, across line breaks.
const swiftForms = [
  [new RegExp(`(?:SettingsText\\(|\\.init\\(|label\\()\\s*${quoted}\\s*,\\s*${quoted}\\s*[,)]`, "g"), 1, 2],
  [new RegExp(`\\bcopy\\(\\s*${quoted}\\s*,\\s*${quoted}\\s*\\)`, "g"), 2, 1],
  // Catalogue rows: .init(.key, title en, title zh, subtitle en, subtitle zh)
  [new RegExp(`\\.init\\(\\.\\w+\\s*,\\s*${quoted}\\s*,\\s*${quoted}`, "g"), 1, 2],
  // The titles may be expressions, as in the login row.
  [new RegExp(`\\.init\\(\\.\\w+\\s*,\\s*[^,\\n]+,\\s*[^,\\n]+,\\s*${quoted}\\s*,\\s*${quoted}`, "g"), 1, 2],
  [new RegExp(`\\b(?:english|isEnglish)\\s*\\?\\s*${quoted}\\s*:\\s*${quoted}`, "g"), 1, 2],
  [new RegExp(`\\b(?:zh|chinese|isChinese)\\s*\\?\\s*${quoted}\\s*:\\s*${quoted}`, "g"), 2, 1],
  [new RegExp(`==\\s*\\.chinese\\s*\\?\\s*${quoted}\\s*:\\s*${quoted}`, "g"), 2, 1],
  [new RegExp(`==\\s*\\.english\\s*\\?\\s*${quoted}\\s*:\\s*${quoted}`, "g"), 1, 2],
];
const single = "'((?:[^'\\\\\\n]|\\\\.)*)'";
const webForms = [
  [new RegExp(`\\['[^']*',\\s*${single},\\s*${single}`, "g"), 1, 2],
  [new RegExp(`===?\\s*'en'\\s*\\?\\s*${single}\\s*:\\s*${single}`, "g"), 1, 2],
  [new RegExp(`\\b(?:en|english)\\s*\\?\\s*${single}\\s*:\\s*${single}`, "g"), 1, 2],
];
function collect(rel, text, forms, into = pairs) {
  for (const [pattern, enAt, zhAt] of forms) {
    for (const m of text.matchAll(pattern)) {
      // Most forms also match non-text calls, so a pair needs Chinese on a side. SettingsText is always text.
      if (!cjk.test(m[zhAt]) && !cjk.test(m[enAt]) && !m[0].startsWith("SettingsText(")) continue;
      const line = text.slice(0, m.index).split("\n").length;
      into.push({ en: m[enAt], zh: m[zhAt], at: `${rel}:${line}` });
    }
  }
}
function walk(dir, extension, forms) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== "Tests" && e.name !== "node_modules" && e.name !== ".tmp") walk(p, extension, forms); continue; }
    if (!e.name.endsWith(extension)) continue;
    collect(path.relative(root, p), fs.readFileSync(p, "utf8"), forms);
  }
}
walk(path.join(root, "desktop", "native"), ".swift", swiftForms);
walk(path.join(root, "desktop", "cockpit", "src"), ".ts", webForms);
// Interpolated code is not text the reader sees.
const plain = (text) => {
  let out = "", depth = 0;
  for (let i = 0; i < text.length; i++) {
    if (!depth && text[i] === "\\" && text[i + 1] === "(") { depth = 1; i++; continue; }
    if (!depth && text[i] === "$" && text[i + 1] === "{") { depth = 1; i++; continue; }
    if (depth) { if ("({".includes(text[i])) depth++; if (")}".includes(text[i])) depth--; continue; }
    out += text[i];
  }
  return out.replace(/\\[nt"']/g, " ");
};
for (const p of pairs) { p.en = plain(p.en); p.zh = plain(p.zh); }
const zh = pairs.map((p) => p.zh);
const en = pairs.map((p) => p.en);

// Budgets need each string's surface, which the code does not record.
const KNOWN = {
  "LBL-2.2-06": "budget classes (silkscreen/card) are not recorded in the catalog; needs per-surface tagging",
};
const todo = (id) => (KNOWN[id] ? { todo: KNOWN[id] } : {});
const notCatalog = (id, lane) => `${id}: not catalog-checkable — needs device/render evidence (${lane})`;

test("LBL-2.2-01 strip controls carry symbols, no text legends", { todo: notCatalog("LBL-2.2-01", "READERS") }, () => {});
test("LBL-2.2-02 other controls carry 1-2 word silkscreen label or symbol", { todo: notCatalog("LBL-2.2-02", "READERS") }, () => {});
test("LBL-2.2-03 toggle prints both states, active lit, controls never move", { todo: notCatalog("LBL-2.2-03", "READERS") }, () => {});
test("LBL-2.2-04 actions use symbols", { todo: notCatalog("LBL-2.2-04", "READERS") }, () => {});

test("LBL-2.2-05 every visible string goes through the two complete zh-CN/en tables", todo("LBL-2.2-05"), () => {
  assert.ok(pairs.length >= 150, `expected a substantial catalog, found ${pairs.length}`);
  for (const p of pairs) {
    assert.ok(p.en.length > 0, `empty english side at ${p.at}`);
    assert.ok(p.zh.length > 0, `empty chinese side at ${p.at}`);
  }
});

test("LBL-2.2-06 string length budgets", todo("LBL-2.2-06"), () => {
  // silkscreen CJK 2-4 chars, Latin <=10; card lines <=28 — classes not tagged in the catalog.
  assert.fail("silkscreen/card string classes are not recorded; cannot assert budgets from the catalog");
});

const englishTokensAllowed = ["ALERT", "MCP", "Codex", "GLM", "ZCode", "Z.ai", "OpenCode", "Cursor", "Copilot",
  "Qwen", "Kimi", "Kiro", "Grok", "MiniMax", "Gemini", "Claude", "Antigravity", "Amp", "Droid", "token", "Token",
  "API", "JSON", "CLI", "3D", "Esc", "Escape", "macOS", "Mac", "MIT"];
const englishPhrasesAllowed = ["Claude Code", "ModelPlan", "Model Plan", "Intel"];
test("LBL-2.2-07 no English inside the Chinese UI except ALERT, model names and units", todo("LBL-2.2-07"), () => {
  const bad = [];
  for (const p of pairs) {
    let s = p.zh;
    for (const phrase of englishPhrasesAllowed) s = s.split(phrase).join(" ");
    const hits = s.match(/[A-Za-z][A-Za-z.]{1,}/g) ?? [];
    for (const h of hits) if (!englishTokensAllowed.includes(h)) bad.push(`${h} in "${p.zh}" (${p.at})`);
  }
  assert.deepEqual(bad, []);
});

test("LBL-2.2-08 product name is ModelPlan, one word", todo("LBL-2.2-08"), () => {
  for (const p of pairs) {
    const hit = p.en.match(/model\s?plan\w*/i) ?? p.zh.match(/model\s?plan\w*/i);
    assert.ok(!hit || hit[0] === "ModelPlan", `${p.at}: "${hit?.[0]}" is not the one-word ModelPlan`);
  }
});

test("LBL-2.2-09 relative times only; no calendar dates for resets or expiries", todo("LBL-2.2-09"), () => {
  const dateish = /(\d{4}\s*年)|(\d{1,2}\s*月\d{1,2}\s*日)|(\d{1,2}\/\d{1,2}\/\d{2,4})|\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d/;
  for (const p of pairs) {
    assert.doesNotMatch(p.zh, dateish, `zh "${p.zh}" (${p.at})`);
    assert.doesNotMatch(p.en, dateish, `en "${p.en}" (${p.at})`);
  }
});

test("LBL-2.2-10 one name per concept across surfaces", todo("LBL-2.2-10"), () => {
  for (const p of pairs) {
    if (/Cockpit/i.test(p.en)) assert.match(p.zh, /驾驶舱/, `${p.at}`);
    if (p.zh.includes("驾驶舱")) assert.match(p.en, /Cockpit/i, `${p.at}`);
    if (/Widget/i.test(p.en)) assert.match(p.en, /Quota Widget/, `${p.at}`);
  }
});

test("LBL-2.2-11 reset count wording; never 重置卡 / reset cards", todo("LBL-2.2-11"), () => {
  for (const p of pairs) {
    assert.doesNotMatch(p.zh, /重置卡/, `${p.at}`);
    assert.doesNotMatch(p.en, /reset cards?/i, `${p.at}`);
  }
});

test("LBL-2.2-12 quota is what is left (额度 · 剩余 / Quota · left)", todo("LBL-2.2-12"), () => {
  assert.ok(
    pairs.some((p) => p.zh.includes("剩余") && /left|remaining/i.test(p.en)),
    "no catalog line frames quota as what is left (剩余/left)",
  );
});

test("LBL-2.2-13 user-visible surface and part names (glossary)", todo("LBL-2.2-13"), () => {
  const glossary = [["额度挂件", "Quota Widget"], ["驾驶舱", "Cockpit"], ["悬窗", "Window"], ["公共屏", "Main screen"],
    ["推杆", "Fader"], ["注意灯", "Alert lamp"], ["点火钮", "Ignition"], ["细条", "Sliver"]];
  const missing = glossary.filter(([z]) => !zh.some((s) => s.includes(z)));
  assert.deepEqual(missing, []);
});

test("LBL-2.2-14 public reset wording, full and narrow", todo("LBL-2.2-14"), () => {
  assert.ok(zh.some((s) => s.includes("预告")), "announced-reset wording (预告) missing");
  assert.ok(zh.some((s) => s.includes("已重置")), "confirmed-reset wording (已重置) missing");
});

const internalWords = ["source scope", "read here", "observation", "fixture", "envelope", "未报告单位", "读数可用", "在设置检查读取权限", "正在显示保留的旧读数在允许时刷新"];
const internalHits = (list) => list.flatMap((p) => internalWords.filter((w) => p.en.toLowerCase().includes(w) || p.zh.includes(w)).map((w) => `${w} (${p.at})`));
test("LBL-2.2-15 avoid internal words in UI", todo("LBL-2.2-15"), () => {
  assert.deepEqual(internalHits(pairs), []);
});

// The scanner itself: each of these once passed unseen.
test("the scanner sees a missing language, an expression title and any case", () => {
  const seen = [];
  collect("control", `SettingsText("Synthetic missing Chinese", "")
SettingsText("", "缺少英文")
.init(.login,LoginSetting.title.english,LoginSetting.title.chinese,"A fixture line","合成行")
SettingsText("Observation details", "合成读取说明")`, swiftForms, seen);
  assert.equal(seen.filter((p) => !p.en || !p.zh).length, 2);
  assert.ok(seen.some((p) => p.en === "A fixture line"));
  assert.deepEqual(internalHits(seen).map((hit) => hit.split(" ")[0]), ["observation", "fixture"]);
});

test("LBL-2.2-16 ALERT stays English on the lamp face in both languages", todo("LBL-2.2-16"), () => {
  for (const p of pairs) {
    if (/\bALERT\b/.test(p.en)) assert.match(p.zh, /\bALERT\b/, `${p.at}: zh must keep ALERT`);
    if (/警告/.test(p.zh)) assert.doesNotMatch(p.en, /\bALERT\b/, `${p.at}: en uses ALERT but zh translates it`);
  }
});

test("LBL-2.2-17 speed and today figures name their basis in help", todo("LBL-2.2-17"), () => {
  assert.ok(zh.some((s) => s.includes("近 60 秒")), "last-60s basis caption missing");
  assert.ok(zh.some((s) => s.includes("今日平均")), "today-average basis caption missing");
  assert.ok(zh.some((s) => s.includes("平均")), "session-average basis caption missing");
});

test("LBL-2.2-18 language setting offers Chinese and English", todo("LBL-2.2-18"), () => {
  assert.ok(en.some((s) => /\bEnglish\b/.test(s)) && zh.some((s) => s.includes("中文")),
    "language options (English/中文) missing from the catalogs");
});

test("LBL-2.2-19 default UI language on first launch", { todo: notCatalog("LBL-2.2-19", "M6") }, () => {});
test("LBL-2.2-20 each surface renders in one language with glossary terms", { todo: notCatalog("LBL-2.2-20", "M6") }, () => {});

test("LBL-2.2-21 额度挂件 / Quota Widget everywhere user-visible", todo("LBL-2.2-21"), () => {
  for (const p of pairs) {
    if (p.zh.includes("挂件")) assert.match(p.zh, /额度挂件/, `${p.at}: 挂件 without 额度挂件`);
    if (/Widget/i.test(p.en)) assert.match(p.en, /Quota Widget/, `${p.at}: widget name not canonical`);
  }
});
