// SPDX-License-Identifier: MIT
// D489: pixel diff of the four full-cockpit scenes, base render vs head render (both made by visual-scenes.spec.mjs on
// one runner). Same comparison as the retired toHaveScreenshot baselines: Playwright's pixelmatch, threshold 0.2,
// anti-aliased pixels ignored, zero changed pixels allowed. Changed pixels are grouped into boxes; each box records which
// Visual-change areas (visual-areas.json) hold its pixels. modelplan-gates decides from the annotations this prints
// (scripts/merge-gates/visual.mjs); the job itself fails only when a capture is missing or unreadable.
//
//   node visual-diff.mjs --base <dir> --head <dir> --out <dir> --base-sha <sha> --subject-sha <sha> [--head-sha <sha>]
//                        [--areas <visual-areas.json>] [--body-file <PR body>]
//   node visual-diff.mjs --print-areas <capture dir>     union of the measured selector boxes over the four scenes
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, appendFileSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { deflateSync } from 'node:zlib';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { decodePng } from './png-pixel.mjs';
import { META_TITLE, RECORD_MAX, SCENE_TITLE, SCENES, judgeVisual, parseVisualChange, parseVisualRecord } from '../../../scripts/merge-gates/visual.mjs';

const require = createRequire(import.meta.url);
let pixelmatch = null;
function matcher() {
  pixelmatch ??= require('../../cockpit/node_modules/playwright-core/lib/third_party/pixelmatch.js');
  return pixelmatch.default ?? pixelmatch;
}
export const THRESHOLD = 0.2;   // toHaveScreenshot's default, which the retired baselines used
export const GAP = 6;           // changed pixels closer than this (cells of GAP px) join one box

function rgba({ width, height, channels, data }) {
  if (channels === 4) return data;
  const out = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) { data.copy(out, i * 4, i * 3, i * 3 + 3); out[i * 4 + 3] = 255; }
  return out;
}
function pad(img, w, h) {
  if (img.width === w && img.height === h) return img.data;
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < img.height; y++) img.data.copy(out, y * w * 4, y * img.width * 4, (y + 1) * img.width * 4);
  return out;
}

// Changed-pixel mask of two decoded images ({width,height,data RGBA}). Different sizes are compared on the larger
// canvas, so every pixel only one image has counts as changed.
export function changeMask(base, head) {
  const width = Math.max(base.width, head.width), height = Math.max(base.height, head.height);
  const a = pad(base, width, height), b = pad(head, width, height), out = Buffer.alloc(width * height * 4);
  matcher()(a, b, out, width, height, { threshold: THRESHOLD, diffMask: true });
  const mask = new Uint8Array(width * height);
  let count = 0;
  for (let i = 0; i < width * height; i++) if (out[i * 4 + 3]) { mask[i] = 1; count++; }
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++)
    if ((x >= base.width || y >= base.height) !== (x >= head.width || y >= head.height) && !mask[y * width + x]) { mask[y * width + x] = 1; count++; }
  return { width, height, mask, count };
}

// Boxes of changed pixels: cells of `gap` px holding a changed pixel, joined 8-connected; each box is the tight bound
// of its pixels. Returns [{x,y,w,h,pixels:[index...]}], largest first.
export function boxes({ width, height, mask }, gap = GAP) {
  const cw = Math.ceil(width / gap), ch = Math.ceil(height / gap), cells = new Int32Array(cw * ch).fill(-1);
  for (let i = 0; i < mask.length; i++) if (mask[i]) cells[Math.floor(Math.floor(i / width) / gap) * cw + Math.floor((i % width) / gap)] = 0;
  const label = new Int32Array(cw * ch).fill(-1);
  let n = 0;
  for (let c = 0; c < cells.length; c++) {
    if (cells[c] !== 0 || label[c] >= 0) continue;
    const stack = [c]; label[c] = n;
    while (stack.length) {
      const k = stack.pop(), cx = k % cw, cy = (k - cx) / cw;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = cx + dx, ny = cy + dy, j = ny * cw + nx;
        if (nx >= 0 && ny >= 0 && nx < cw && ny < ch && cells[j] === 0 && label[j] < 0) { label[j] = n; stack.push(j); }
      }
    }
    n++;
  }
  const found = Array.from({ length: n }, () => ({ x0: Infinity, y0: Infinity, x1: -1, y1: -1, pixels: [] }));
  for (let i = 0; i < mask.length; i++) {
    if (!mask[i]) continue;
    const x = i % width, y = (i - x) / width, b = found[label[Math.floor(y / gap) * cw + Math.floor(x / gap)]];
    b.x0 = Math.min(b.x0, x); b.y0 = Math.min(b.y0, y); b.x1 = Math.max(b.x1, x); b.y1 = Math.max(b.y1, y); b.pixels.push(i);
  }
  return found.map((b) => ({ x: b.x0, y: b.y0, w: b.x1 - b.x0 + 1, h: b.y1 - b.y0 + 1, pixels: b.pixels })).sort((p, q) => q.pixels.length - p.pixels.length);
}

// Area name -> rects: the map's rects plus the measured selector boxes of every render given (base and head).
export function resolveAreas(map, measured = []) {
  const out = {};
  for (const [name, area] of Object.entries(map.areas)) {
    out[name] = [...(area.rects ?? [])];
    for (const m of measured) for (const r of m?.[name] ?? []) out[name].push(r);
  }
  return out;
}

// Changed-pixel counts of one box keyed by the "+"-joined, sorted set of areas (rects widened by margin) holding the pixel.
export function cover(pixels, width, areas, margin = 0) {
  const names = Object.keys(areas).sort(), out = {};
  for (const i of pixels) {
    const x = i % width, y = (i - x) / width;
    const key = names.filter((n) => areas[n].some(([rx, ry, rw, rh]) => x >= rx - margin && x < rx + rw + margin && y >= ry - margin && y < ry + rh + margin)).join('+');
    out[key] = (out[key] ?? 0) + 1;
  }
  return out;
}

// One scene's record, kept under RECORD_MAX characters: when too long, the smallest boxes fold into one bounding box
// whose cover is the exact sum, so the decision is unchanged and only the report gets coarser.
export function sceneRecord(scene, size, found) {
  let list = found.map((b) => [b.x, b.y, b.w, b.h, b.n, b.cover]);
  const pixels = list.reduce((s, b) => s + b[4], 0);
  const text = () => JSON.stringify({ v: 1, scene, size, pixels, boxes: list });
  while (text().length > RECORD_MAX && list.length > 1) {
    const keep = Math.max(1, Math.floor(list.length / 2)), rest = list.slice(keep - 1);
    const x0 = Math.min(...rest.map((b) => b[0])), y0 = Math.min(...rest.map((b) => b[1]));
    const x1 = Math.max(...rest.map((b) => b[0] + b[2])), y1 = Math.max(...rest.map((b) => b[1] + b[3]));
    const sum = {};
    for (const b of rest) for (const [k, n] of Object.entries(b[5])) sum[k] = (sum[k] ?? 0) + n;
    list = [...list.slice(0, keep - 1), [x0, y0, x1 - x0, y1 - y0, rest.reduce((s, b) => s + b[4], 0), sum]];
  }
  if (text().length > RECORD_MAX) throw new Error(`${scene}: record over ${RECORD_MAX} characters`);
  return { v: 1, scene, size, pixels, boxes: list };
}

// ---- PNG output (8-bit RGBA, filter 0) ----
const CRC = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc32 = (buf) => { let c = 0xffffffff; for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
function chunk(type, body) {
  const head = Buffer.alloc(8); head.writeUInt32BE(body.length, 0); head.write(type, 4, 'latin1');
  const tail = Buffer.alloc(4); tail.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), body])), 0);
  return Buffer.concat([head, body, tail]);
}
export function encodePng(width, height, data) {
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) data.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

// The head image faded to grey, changed pixels red, each box outlined in magenta (2 px outside its bounds).
export function diffImage(head, { width, height, mask }, found) {
  const src = pad(head, width, height), out = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    const g = Math.round(0.299 * src[i * 4] + 0.587 * src[i * 4 + 1] + 0.114 * src[i * 4 + 2]), v = mask[i] ? null : Math.round(160 + g * 0.35);
    out.set(v === null ? [255, 0, 0, 255] : [v, v, v, 255], i * 4);
  }
  const dot = (x, y) => { if (x >= 0 && y >= 0 && x < width && y < height) out.set([255, 0, 255, 255], (y * width + x) * 4); };
  for (const b of found) {
    const x0 = b.x - 2, y0 = b.y - 2, x1 = b.x + b.w + 1, y1 = b.y + b.h + 1;
    for (let x = x0; x <= x1; x++) { dot(x, y0); dot(x, y1); }
    for (let y = y0; y <= y1; y++) { dot(x0, y); dot(x1, y); }
  }
  return encodePng(width, height, out);
}

const esc = (s) => String(s).replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');
const readJson = (path) => (existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : null);

// D489 rollout (macrev2-1320-1): until main's merge gate judges these reports, i.e. while main's rules.mjs lacks
// MARKER_LINE, the job itself keeps the retired baselines' rule and fails on any changed pixel (strict). Otherwise a
// merge group with this change and an undeclared visual change would pass: the old gate ignores the report.
export const MARKER_LINE = 'export const VISUAL_DIFF_MARKER = "D489-v1";';
export const RULES_PATH = 'scripts/merge-gates/rules.mjs';
export const mainJudgesReports = (rulesText) => typeof rulesText === 'string' && rulesText.split('\n').some((l) => l.replace(/\r$/, '') === MARKER_LINE);
// main's rules.mjs through the contents API; null when unreadable (which means strict).
export async function readMainRules({ token, repo, fetchImpl = fetch } = {}) {
  if (!token || !repo) return null;
  try {
    const r = await fetchImpl(`https://api.github.com/repos/${repo}/contents/${RULES_PATH}?ref=main`, { headers: { accept: 'application/vnd.github+json', authorization: `Bearer ${token}`, 'user-agent': 'modelplan-visual-diff' } });
    if (!r.ok) return null;
    return Buffer.from(String((await r.json())?.content ?? ''), 'base64').toString('utf8');
  } catch { return null; }
}

export function run({ baseDir, headDir, outDir, areasPath, baseSha, subjectSha, headSha, body = null, log = console.log, summary = null, strict = true }) {
  const map = JSON.parse(readFileSync(areasPath, 'utf8'));
  mkdirSync(outDir, { recursive: true });
  const meta = { v: 1, base: baseSha, subject: subjectSha, head: headSha ?? subjectSha, areas: Object.fromEntries(Object.entries(map.areas).map(([n, a]) => [n, a.aliases ?? []])) };
  const notes = [{ title: META_TITLE, annotation_level: 'notice', message: JSON.stringify(meta) }], report = { ...meta, scenes: {} };
  for (const scene of SCENES) {
    const read = (dir) => { const path = join(dir, `${scene}.png`); if (!existsSync(path)) throw new Error(`missing capture ${path}`); const img = decodePng(readFileSync(path)); return { ...img, data: rgba(img) }; };
    const base = read(baseDir), head = read(headDir), m = changeMask(base, head);
    const areas = resolveAreas(map, [readJson(join(baseDir, `${scene}.areas.json`)), readJson(join(headDir, `${scene}.areas.json`))]);
    const found = boxes(m).map((b) => ({ ...b, n: b.pixels.length, cover: cover(b.pixels, m.width, areas, map.margin ?? 0) }));
    const record = sceneRecord(scene, [m.width, m.height], found);
    notes.push({ title: SCENE_TITLE, annotation_level: 'notice', message: JSON.stringify(record) });
    report.scenes[scene] = { ...record, areas };
    copyFileSync(join(baseDir, `${scene}.png`), join(outDir, `${scene}.base.png`));
    copyFileSync(join(headDir, `${scene}.png`), join(outDir, `${scene}.head.png`));
    if (m.count) writeFileSync(join(outDir, `${scene}.diff.png`), diffImage(head, m, found));
  }
  for (const n of notes) log(`::notice title=${n.title}::${esc(n.message)}`);
  // Preview of the gate's decision against the body this run saw; modelplan-gates re-reads the live body and comments.
  const declared = parseVisualChange(body ?? '');
  const verdict = judgeVisual(parseVisualRecord(notes), { declared: declared.areas, present: declared.present });
  report.preview = { declared, verdict };
  const lines = ['## Full-cockpit visual diff (D489)', '', `base \`${baseSha}\` vs subject \`${subjectSha}\`${headSha && headSha !== subjectSha ? ` (PR head \`${headSha}\`)` : ''}`, '',
    '| scene | changed px | boxes (x,y w×h px → areas) |', '|---|---|---|',
    ...SCENES.map((s) => { const r = report.scenes[s]; return `| ${s} | ${r.pixels} | ${r.boxes.map((b) => `${b[0]},${b[1]} ${b[2]}×${b[3]} ${b[4]} → ${Object.entries(b[5]).map(([k, n]) => `${k || 'no area'}:${n}`).join(' ')}`).join('<br>') || '—'} |`; }),
    '', `Declared now: ${declared.present ? (declared.areas.join(', ') || 'none') : 'no Visual-change line'}`, '',
    `**Gate preview: ${verdict.state === 'success' ? 'PASS' : 'FAIL'}** — ${verdict.why}`, '',
    'modelplan-gates decides from the live PR body (`Visual-change: <area>[, <area>]`) and a trusted `VISUAL-ACCEPT @ <head sha>` comment. Diff images: the run artifact.', ''];
  const changed = SCENES.reduce((n, s) => n + report.scenes[s].pixels, 0), failed = strict && changed > 0;
  report.strict = strict;
  if (strict) lines.push(`**Strict mode** (main's merge gate does not judge D489 reports yet): ${failed ? `FAIL, ${changed} changed px; any change fails until D489 is on main` : 'no change, pass'}.`, '');
  writeFileSync(join(outDir, 'report.json'), JSON.stringify(report, null, 1));
  if (summary) appendFileSync(summary, lines.join('\n'));
  if (failed) log(`::error title=D489 strict visual check::${esc(`${changed} changed px; main's merge gate cannot judge Visual-change yet, so any change fails: ${verdict.why}`)}`);
  else if (verdict.state !== 'success') log(`::warning title=D489 visual change outside declared areas::${esc(verdict.why)}`);
  return { report, verdict, notes, failed };
}

// Every distinct measured box per area over the four scenes (one per selector match), to update the map's rects.
export function printAreas(dir) {
  const out = {};
  for (const scene of SCENES) for (const [name, rects] of Object.entries(readJson(join(dir, `${scene}.areas.json`)) ?? {})) {
    const seen = (out[name] ??= []);
    for (const r of rects) if (!seen.some((q) => q.join() === r.join())) seen.push(r);
  }
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const argv = process.argv.slice(2), flag = (name) => { const i = argv.indexOf(name); return i < 0 ? null : argv[i + 1]; };
  if (flag('--print-areas')) console.log(JSON.stringify(printAreas(flag('--print-areas'))));
  else {
    const bodyFile = flag('--body-file'), rulesFile = flag('--main-rules-file');
    const rules = rulesFile ? (existsSync(rulesFile) ? readFileSync(rulesFile, 'utf8') : null) : await readMainRules({ token: process.env.GITHUB_TOKEN, repo: process.env.GITHUB_REPOSITORY });
    const strict = !mainJudgesReports(rules);
    console.log(strict ? `strict: main's ${RULES_PATH} ${rules === null ? 'unreadable' : 'lacks the D489 marker'}; any changed pixel fails` : 'main judges D489 reports: the gate decides');
    const { failed } = run({ baseDir: flag('--base'), headDir: flag('--head'), outDir: flag('--out'), areasPath: flag('--areas') ?? fileURLToPath(new URL('./visual-areas.json', import.meta.url)),
      baseSha: flag('--base-sha'), subjectSha: flag('--subject-sha'), headSha: flag('--head-sha') || null,
      body: bodyFile && existsSync(bodyFile) ? readFileSync(bodyFile, 'utf8') : null, summary: process.env.GITHUB_STEP_SUMMARY || null, strict });
    if (failed) process.exitCode = 1;
  }
}
