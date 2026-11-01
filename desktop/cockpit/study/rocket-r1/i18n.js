// r7 string tables (spec 2.2). Every visible string goes through t(key, vars). Each area registers its
// own strings from strings/<area>.js, so packages that work in parallel never edit the same table.
// English count entries may use {one, other}; t() selects with Intl.PluralRules from count/n/d.
// An entry is [budgetClass, zh-CN, en]; {name} in a string is replaced from vars. Synthetic study.

export const LANGS = ['zh-CN', 'en'];
const pluralRules = Object.fromEntries(LANGS.map(locale => [locale, new Intl.PluralRules(locale)]));
export const tables = {'zh-CN': {}, en: {}};
export const classOf = {}; // key -> budget class
let lang = 'zh-CN';
const listeners = new Set();

// Length budgets per key class. zh counts a CJK character (or full-width mark) as 1 and anything else
// as 0.5; en counts characters. A {var} counts as 3 characters (en) / 1.5 (zh) in the static check;
// the runtime record measures the real rendered strings.
export const BUDGET = {
  silk: {zh: 4, en: 10, what: 'silkscreen label, key legend, toggle state (spec 2.2)'},
  lcd: {zh: 6, en: 12, what: 'short LCD tag or unit next to a value'},
  line: {zh: 20, en: 28, what: 'one single-line LCD, alert or card row (spec 2.2: ≤ 28)'},
  alert: {zh: 22, en: 44, what: 'one public-screen alert line (ellipsised on the LCD)'},
  text: {zh: 40, en: 64, what: 'wrapping card or screen text (two lines at most)'},
  ann: {zh: 32, en: 60, what: 'annotation-layer callout (hold ⌥)'},
  demo: {zh: 18, en: 34, what: 'demo panel label or button (study only)'},
  aria: {zh: Infinity, en: Infinity, what: 'accessible name or tooltip (not drawn)'},
  prose: {zh: Infinity, en: Infinity, what: 'study notes and readout (not product UI)'},
};

// register('dock', {grip: ['silk', '拖动', 'Drag']}) adds dock.grip.
export function register(area, entries) {
  for (const [k, [cls, zh, en]] of Object.entries(entries)) {
    const key = `${area}.${k}`;
    if (!BUDGET[cls]) throw new Error(`i18n: unknown class ${cls} for ${key}`);
    classOf[key] = cls; tables['zh-CN'][key] = zh; tables.en[key] = en;
  }
}

export const language = () => lang;
export function setLanguage(next) {
  if (!LANGS.includes(next) || next === lang) return;
  lang = next;
  document.documentElement.lang = next;
  for (const f of listeners) f(next);
}
export const onLanguage = f => listeners.add(f);

let record = null; // key -> longest rendered width, while checks record
const missing = new Set();
export function t(key, vars) {
  let s = tables[lang][key];
  if (s == null) { s = tables['zh-CN'][key]; if (s == null) { missing.add(key); return key; } missing.add(`${lang}:${key}`); }
  if (typeof s === 'object') {
    const count = Number(vars?.count ?? vars?.n ?? vars?.d);
    s = s[pluralRules[lang].select(count)] ?? s.other;
  }
  if (vars) s = s.replace(/\{(\w+)\}/g, (m, n) => vars[n] ?? m);
  if (record) { const w = width(s, lang), r = record[`${lang}:${key}`]; if (!r || w > r.w) record[`${lang}:${key}`] = {w, s}; }
  return s;
}

// Localised fixture text: either a plain string or {zh, en}.
export const L = v => v == null || typeof v !== 'object' ? v : lang === 'en' ? v.en ?? v.zh : v.zh ?? v.en;

/* ---------- budgets ---------- */
const CJK = /[⺀-鿿豈-﫿＀-￯　-〿]/;
export function width(s, l) {
  s = String(s).replace(/<[^>]+>/g, '');
  if (!l.startsWith('zh')) return [...s].length;
  let w = 0; for (const ch of s) w += CJK.test(ch) ? 1 : .5;
  return w;
}
const staticWidth = (s, l) => width(s.replace(/\{\w+\}/g, 'xxx'), l);
export const startRecording = () => { record = {}; };

// Returns every string over its budget: static (the tables) and, when recording, rendered values.
export function checkBudgets() {
  const over = [];
  for (const l of LANGS) for (const [key, entry] of Object.entries(tables[l])) {
    for (const s of typeof entry === 'object' ? Object.values(entry) : [entry]) {
      const b = BUDGET[classOf[key]][l.startsWith('zh') ? 'zh' : 'en'], w = staticWidth(s, l);
      if (w > b) over.push({lang:l,key,cls:classOf[key],width:w,budget:b,text:s,where:'table'});
    }
  }
  for (const [lk, {w, s}] of Object.entries(record || {})) {
    const [l, key] = [lk.slice(0, lk.indexOf(':')), lk.slice(lk.indexOf(':') + 1)];
    const b = BUDGET[classOf[key]]?.[l.startsWith('zh') ? 'zh' : 'en'] ?? Infinity;
    if (w > b) over.push({lang: l, key, cls: classOf[key], width: w, budget: b, text: s, where: 'rendered'});
  }
  return over;
}
// Keys present in one table only, or asked for but never registered.
export function checkTables() {
  const zh = Object.keys(tables['zh-CN']), en = new Set(Object.keys(tables.en));
  return {untranslated: zh.filter(k => !en.has(k) || !(typeof tables.en[k] === 'object' ? tables.en[k].other && Object.values(tables.en[k]).every(Boolean) : tables.en[k])), missing: [...missing]};
}

// Static markup carries data-i18n="key" (text) and data-i18n-aria="key" (aria-label).
export function applyI18n(root = document) {
  for (const el of root.querySelectorAll('[data-i18n]')) el.textContent = t(el.dataset.i18n);
  for (const el of root.querySelectorAll('[data-i18n-aria]')) el.setAttribute('aria-label', t(el.dataset.i18nAria));
}
