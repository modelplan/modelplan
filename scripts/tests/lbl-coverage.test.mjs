// SPDX-License-Identifier: MIT
// LBL-2.2-01..21 label/copy coverage (R48). Loads the shipped string catalogs
// (Swift SettingsText pairs across desktop/native Sources, plus the cockpit
// help triples) and asserts each LBL wording rule that is checkable from the
// catalogs on Linux. Rules that need visual/device evidence are marked todo
// with the reason; catalog rules that currently fail are kept as expected
// failures (todo) and recorded in glm-review/lbl-failures-1106.md. No copy is
// changed by this file.
import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const pairs = [];
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== "Tests") walk(p); continue; }
    if (!e.name.endsWith(".swift")) continue;
    const rel = path.relative(root, p);
    const lines = fs.readFileSync(p, "utf8").split("\n");
    for (const [i, line] of lines.entries()) {
      const m = line.match(/(?:SettingsText\(|\.init\()\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/);
      if (m) pairs.push({ en: m[1], zh: m[2], at: `${rel}:${i + 1}` });
    }
  }
}
walk(path.join(root, "desktop", "native"));
// Cockpit help captions: ['selector','en','zh']
const helpPath = path.join(root, "desktop", "cockpit", "src", "prototype-help.ts");
for (const [i, line] of fs.readFileSync(helpPath, "utf8").split("\n").entries()) {
  const m = line.match(/\['[^']*',\s*'([^']*)',\s*'([^']*)'/);
  if (m) pairs.push({ en: m[1], zh: m[2], at: `desktop/cockpit/src/prototype-help.ts:${i + 1}` });
}
const zh = pairs.map((p) => p.zh);
const en = pairs.map((p) => p.en);

// Expected failures (catalog rule currently red; see glm-review/lbl-failures-1106.md).
const KNOWN = {
  "LBL-2.2-06": "budget classes (silkscreen/card) are not recorded in the catalog; needs per-surface tagging",
  "LBL-2.2-07": "zh caption is the English word 'hidden' at desktop/cockpit/src/prototype-help.ts:48",
  "LBL-2.2-12": "no catalog line frames quota as what is left (额度 · 剩余 / Quota · left)",
  "LBL-2.2-13": "glossary names 点火钮 (Ignition) and 隐藏条 (Sliver) are absent from the shipped catalogs",
  "LBL-2.2-14": "public-reset wording forms (预告/已重置 full+narrow) not present in the shipped catalogs yet",
  "LBL-2.2-15": "internal line 读数可用 still shipped at CommunityConnectionIntegration.swift:165",
  "LBL-2.2-18": "language options (English/中文) are absent from the shipped catalogs",
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
  "API", "JSON", "CLI", "3D", "Esc", "Tauri"];
const englishPhrasesAllowed = ["Claude Code", "ModelPlan", "Intel"];
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
  const dateish = /(\d{4}\s*年)|(\d{1,2}\s*月\d{1,2}\s*日)|(\d{1,2}\/\d{1,2}\/\d{2,4})|\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b/;
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
    ["推杆", "Fader"], ["注意灯", "Alert lamp"], ["点火钮", "Ignition"], ["隐藏条", "Sliver"]];
  const missing = glossary.filter(([z]) => !zh.some((s) => s.includes(z)));
  assert.deepEqual(missing, []);
});

test("LBL-2.2-14 public reset wording, full and narrow", todo("LBL-2.2-14"), () => {
  assert.ok(zh.some((s) => s.includes("预告")), "announced-reset wording (预告) missing");
  assert.ok(zh.some((s) => s.includes("已重置")), "confirmed-reset wording (已重置) missing");
});

const internalWords = ["source scope", "read here", "observation", "fixture", "envelope", "未报告单位", "读数可用", "在设置检查读取权限", "正在显示保留的旧读数在允许时刷新"];
test("LBL-2.2-15 avoid internal words in UI", todo("LBL-2.2-15"), () => {
  const bad = [];
  for (const p of pairs) for (const w of internalWords) if (p.en.includes(w) || p.zh.includes(w)) bad.push(`${w} (${p.at})`);
  assert.deepEqual(bad, []);
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
