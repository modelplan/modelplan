// SPDX-License-Identifier: MIT
// D489: the base-vs-head pixel diff of the full-cockpit scenes and the Visual-change area map.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { decodePng } from '../png-pixel.mjs';
import { boxes, changeMask, cover, encodePng, resolveAreas, run, sceneRecord } from '../visual-diff.mjs';
import { SCENES, parseVisualRecord, resolveDeclared } from '../../../../scripts/merge-gates/visual.mjs';

const map = JSON.parse(readFileSync(new URL('../visual-areas.json', import.meta.url), 'utf8'));
const W = 64, H = 48;
const image = (paint = () => null) => {
  const data = Buffer.alloc(W * H * 4);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) data.set(paint(x, y) ?? [40, 60, 80, 255], (y * W + x) * 4);
  return { width: W, height: H, data };
};

test('area map: unique names and aliases, rects inside the scene, selectors listed', () => {
  const [w, h] = map.size, seen = new Set();
  assert.deepEqual(map.size, [636, 951], 'the visual-scenes.spec.mjs viewport');
  for (const [name, area] of Object.entries(map.areas)) {
    for (const n of [name, ...(area.aliases ?? [])]) { assert.match(n, /^[a-z][a-z0-9-]{0,31}$/); assert.ok(!seen.has(n), `${n} named twice`); seen.add(n); }
    assert.ok(area.rects.length > 0, name);
    for (const [x, y, rw, rh] of area.rects) assert.ok(x >= 0 && y >= 0 && rw > 0 && rh > 0 && x + rw <= w && y + rh <= h, `${name} rect inside ${w}x${h}`);
    assert.ok(Array.isArray(area.selectors), name);
  }
  for (const n of ['grip', 'levers', 'canopy', 'window', 'session-lamps', 'session-cards', 'band', 'mfd', 'big-screen', 'tape', 'hull', 'strip'])
    assert.ok(seen.has(n), `area or alias ${n}`);
  const areas = Object.fromEntries(Object.entries(map.areas).map(([n, a]) => [n, a.aliases]));
  assert.deepEqual(resolveDeclared(['levers', 'big-screen', 'grip', 'wing'], areas), { known: ['grip', 'mfd'], unknown: ['wing'] });
});

test('area map: the panels cover the whole scene, so a change always falls in some area', () => {
  const [w, h] = map.size, areas = resolveAreas(map), all = [];
  for (let i = 0; i < w * h; i++) all.push(i);
  const c = cover(all, w, areas, 0);
  assert.equal(c[''] ?? 0, 0, `${c[''] ?? 0} scene pixels are in no area`);
});

test('changeMask: Playwright pixelmatch at threshold 0.2; identical images change nothing', () => {
  assert.equal(changeMask(image(), image()).count, 0);
  const faint = changeMask(image(), image(() => [41, 60, 80, 255]));
  assert.equal(faint.count, 0, 'below the 0.2 threshold, like toHaveScreenshot');
  const m = changeMask(image(), image((x, y) => (x >= 10 && x < 14 && y >= 20 && y < 23 ? [255, 255, 255, 255] : null)));
  assert.ok(m.count >= 12 - 4 && m.count <= 12, `${m.count} changed pixels (anti-aliased edge pixels may be ignored)`);
});

test('changeMask: a size change counts every pixel only one render has', () => {
  const small = { width: W, height: H - 8, data: image().data.subarray(0, W * (H - 8) * 4) };
  assert.equal(changeMask(small, image()).count, W * 8);
});

test('boxes: nearby pixels join, far ones split, bounds are tight, largest first', () => {
  const mask = new Uint8Array(W * H);
  const on = (x, y) => { mask[y * W + x] = 1; };
  for (let x = 2; x < 6; x++) on(x, 2);   // 4 px
  on(8, 3);                               // 2 px from the first run: same box
  for (let y = 30; y < 40; y++) on(50, y); // far away: own box, 10 px
  const found = boxes({ width: W, height: H, mask }, 6);
  assert.deepEqual(found.map(({ x, y, w, h, pixels }) => [x, y, w, h, pixels.length]), [[50, 30, 1, 10, 10], [2, 2, 7, 2, 5]]);
});

test('cover: pixels keyed by the sorted set of areas holding them, with margin', () => {
  const areas = { grip: [[0, 0, 10, 10]], band: [[8, 0, 10, 10]] };
  const px = (x, y) => y * W + x;
  assert.deepEqual(cover([px(1, 1), px(9, 1), px(30, 30), px(11, 11)], W, areas, 0), { grip: 1, 'band+grip': 1, '': 2 });
  assert.deepEqual(cover([px(11, 11)], W, areas, 2), { 'band+grip': 1 }, 'the margin widens every rect');
});

test('sceneRecord: folding small boxes keeps the exact cover sums under the annotation limit', () => {
  const found = Array.from({ length: 400 }, (_, i) => ({ x: i, y: i, w: 1, h: 1, n: 2, cover: i % 2 ? { grip: 2 } : { '': 1, band: 1 } }));
  const r = sceneRecord('full-day-en', [636, 951], found);
  assert.ok(JSON.stringify(r).length <= 4000);
  assert.ok(r.boxes.length < 400);
  assert.equal(r.pixels, 800);
  const sum = {};
  for (const b of r.boxes) for (const [k, n] of Object.entries(b[5])) sum[k] = (sum[k] ?? 0) + n;
  assert.deepEqual(sum, { '': 200, band: 200, grip: 400 });
});

test('encodePng round-trips through the test decoder', () => {
  const img = image((x, y) => [x * 3, y * 5, 7, 200]);
  const back = decodePng(encodePng(W, H, img.data));
  assert.deepEqual([back.width, back.height, back.channels], [W, H, 4]);
  assert.ok(back.data.equals(img.data));
});

test('run: records every scene, draws diff images, previews the gate against the body', () => {
  const dir = mkdtempSync(join(tmpdir(), 'visual-diff-'));
  try {
    const areas = join(dir, 'areas.json');
    writeFileSync(areas, JSON.stringify({ size: [W, H], margin: 1, areas: { grip: { aliases: ['levers'], selectors: ['.fd-travel'], rects: [[0, 0, 32, 48]] }, band: { selectors: [], rects: [[32, 0, 32, 48]] } } }));
    for (const side of ['base', 'head']) mkdirSync(join(dir, side));
    for (const s of SCENES) {
      const base = image(), head = image((x, y) => (s === 'full-day-en' && x >= 4 && x < 10 && y >= 4 && y < 10 ? [250, 250, 250, 255] : null));
      writeFileSync(join(dir, 'base', `${s}.png`), encodePng(W, H, base.data));
      writeFileSync(join(dir, 'head', `${s}.png`), encodePng(W, H, head.data));
    }
    // the head measured the grip selector somewhere the committed rect does not reach: the live box joins the area
    writeFileSync(join(dir, 'head', 'full-day-en.areas.json'), JSON.stringify({ grip: [[40, 40, 4, 4]] }));
    const lines = [], sha = 'd'.repeat(40);
    const go = (body) => run({ baseDir: join(dir, 'base'), headDir: join(dir, 'head'), outDir: join(dir, 'out'), areasPath: areas, baseSha: sha, subjectSha: sha, body, log: (l) => lines.push(l) });
    const plain = go(null);
    assert.equal(plain.verdict.state, 'failure');
    assert.match(plain.verdict.why, /full-day-en \d+,\d+ \d+x\d+ \(\d+ px\) in grip/);
    assert.ok(existsSync(join(dir, 'out', 'full-day-en.diff.png')) && !existsSync(join(dir, 'out', 'full-night-en.diff.png')));
    assert.deepEqual(plain.report.scenes['full-day-en'].areas.grip, [[0, 0, 32, 48], [40, 40, 4, 4]]);
    const notices = lines.filter((l) => l.startsWith('::notice title=')).map((l) => {
      const [, title, message] = /^::notice title=([^:]+)::(.*)$/.exec(l);
      return { title, annotation_level: 'notice', message: message.replaceAll('%0A', '\n').replaceAll('%0D', '\r').replaceAll('%25', '%') };
    });
    assert.equal(notices.length, 5);
    assert.ok(parseVisualRecord(notices).ok, 'the gate reads back what the job printed');
    assert.ok(lines.some((l) => l.startsWith('::warning title=D489')));
    assert.equal(go('Visual-change: levers').verdict.state, 'success');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
