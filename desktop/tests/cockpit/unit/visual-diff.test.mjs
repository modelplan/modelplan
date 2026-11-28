// SPDX-License-Identifier: MIT
// D489: the base-vs-head pixel diff of the full-cockpit scenes and the Visual-change area map.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, mkdirSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { decodePng } from '../png-pixel.mjs';
import { MARKER_LINE, boxes, changeMask, cover, encodePng, mainJudgesReports, readMainRules, resolveAreas, run, sceneRecord } from '../visual-diff.mjs';
import * as R from '../../../../scripts/merge-gates/rules.mjs';
import { SCENES, judgeVisual, parseVisualRecord, resolveDeclared } from '../../../../scripts/merge-gates/visual.mjs';

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
    const go = (body) => run({ baseDir: join(dir, 'base'), headDir: join(dir, 'head'), outDir: join(dir, 'out'), areasPath: areas, baseSha: sha, subjectSha: sha, body, log: (l) => lines.push(l), strict: false });
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

// macrev2-1320-2: the areas measured by the normal capture (full-day-en, one box per selector match). Before the fix the
// two side boosters were joined into hull [3,490,630,381], which covered the MFD.
const MEASURED = {canopy:[[24,12,588,232]],strip:[[24,253,588,26]],band:[[24,288,588,226]],'session-lamps':[[52,523,12,18],[128,523,12,18],[204,523,12,18],[73,523,46,18]],'session-cards':[[26,541,64,101],[102,541,64,101],[178,541,64,101]],grip:[[26,659,64,111],[102,659,64,111],[178,659,64,111],[90,659,12,111],[166,659,12,111],[26,780,216,16]],mfd:[[251,523,361,257]],tape:[[24,789,588,94]],base:[[8,905,620,46]],hull:[[3,490,9,381],[624,490,9,381]]};
const one = (x, y, cov) => ({ ok: true, meta: { areas: Object.fromEntries(Object.entries(map.areas).map(([n, a]) => [n, a.aliases])) },
  scenes: new Map(SCENES.map((s) => [s, { boxes: s === 'full-day-en' ? [[x, y, 1, 1, 1, cov]] : [] }])) });

test('reviewer case: a pixel in the MFD centre is mfd only; hull alone does not cover it; a booster pixel is hull', () => {
  const areas = resolveAreas(map, [MEASURED, MEASURED]), [w] = map.size;
  const centre = cover([600 * w + 400], w, areas, map.margin);
  assert.deepEqual(centre, { mfd: 1 });
  assert.equal(judgeVisual(one(400, 600, centre), { declared: ['hull'], present: true }).state, 'failure');
  assert.equal(judgeVisual(one(400, 600, centre), { declared: ['mfd'], present: true }).state, 'success');
  const booster = cover([600 * w + 6], w, areas, map.margin);
  assert.ok(Object.keys(booster).every((k) => k.split('+').includes('hull')), JSON.stringify(booster));
  assert.equal(judgeVisual(one(6, 600, booster), { declared: ['hull'], present: true }).state, 'success');
  // no hull box, committed or measured, reaches into the MFD screen
  for (const [x, y, rw, rh] of areas.hull) assert.ok(x + rw <= 253 || x >= 610 || y + rh <= 547 || y >= 756, `hull rect ${[x, y, rw, rh]} inside the MFD screen`);
});

// macrev2-1320-1 / macrevb-1320-1: a mixed-revision queue group (this change + an undeclared MFD change) while main still runs
// the old evaluator must fail the required checks; once main carries the marker the gate decides.
test('rollout: strict until main judges reports, then fail undeclared, pass declared, pass accepted', async () => {
  const newRules = readFileSync(new URL('../../../../scripts/merge-gates/rules.mjs', import.meta.url), 'utf8');
  const oldRules = newRules.split('\n').filter((l) => l !== MARKER_LINE).join('\n');
  assert.ok(newRules.includes(MARKER_LINE) && !mainJudgesReports(oldRules) && mainJudgesReports(newRules) && !mainJudgesReports(null));
  assert.equal(await readMainRules({ token: 't', repo: 'o/r', fetchImpl: async () => ({ ok: false }) }), null, 'unreadable: strict');
  assert.equal(await readMainRules({ token: 't', repo: 'o/r', fetchImpl: async () => { throw new Error('net'); } }), null);
  assert.equal(await readMainRules({ token: 't', repo: 'o/r', fetchImpl: async () => ({ ok: true, json: async () => ({ content: Buffer.from(newRules).toString('base64') }) }) }), newRules);
  const dir = mkdtempSync(join(tmpdir(), 'visual-rollout-'));
  try {
    for (const side of ['base', 'head']) mkdirSync(join(dir, side));
    const [w, h] = map.size, blank = Buffer.alloc(w * h * 4, 255);
    for (const s of SCENES) {
      const head = Buffer.from(blank);
      if (s === 'full-night-en') for (let y = 598; y < 602; y++) for (let x = 398; x < 402; x++) head.set([200, 0, 0, 255], (y * w + x) * 4);
      writeFileSync(join(dir, 'base', `${s}.png`), encodePng(w, h, blank));
      writeFileSync(join(dir, 'head', `${s}.png`), encodePng(w, h, head));
    }
    const G = 'a'.repeat(40), BASE = 'c'.repeat(40);
    const go = (rules) => { const lines = []; const r = run({ baseDir: join(dir, 'base'), headDir: join(dir, 'head'), outDir: join(dir, 'out'), areasPath: new URL('../visual-areas.json', import.meta.url).pathname,
      baseSha: BASE, subjectSha: G, log: (l) => lines.push(l), strict: !mainJudgesReports(rules) }); return { ...r, lines }; };
    const before = go(oldRules);
    assert.equal(before.failed, true, 'old main: the job itself fails on the undeclared change');
    assert.ok(before.lines.some((l) => l.startsWith('::error title=D489 strict')));
    const after = go(newRules);
    assert.equal(after.failed, false, 'new main: the job leaves the decision to the gate');
    const annotations = after.lines.filter((l) => l.startsWith('::notice title=')).map((l) => {
      const [, title, message] = /^::notice title=([^:]+)::(.*)$/.exec(l);
      return { title, annotation_level: 'notice', message: message.replaceAll('%0A', '\n').replaceAll('%0D', '\r').replaceAll('%25', '%') };
    });
    const runRow = (path) => ({ id: 9, workflow_id: path, path, name: path, status: 'completed', conclusion: 'success', head_sha: G, head_repository: { full_name: 'modelplan/modelplan' },
      head_branch: `gh-readonly-queue/main/pr-2-${BASE}`, event: 'merge_group', pull_requests: [] });
    const queueRuns = R.QUEUE_WORKFLOWS.map(runRow), visualRun = queueRuns.find((r) => r.path === '.github/workflows/u11-cockpit.yml');
    const step = (pr, visual) => ({ pr, mergeProof: { ok: true }, prResult: { state: R.SUCCESS, why: 'ok', hostedExempt: true, visual } });
    const group = (v2) => R.evaluateGroup({ steps: [step(1, { declared: [], present: true, accepted: false }), step(2, v2)], queueRuns, groupSha: G,
      visual: { run: visualRun, job: { name: 'visual', conclusion: 'success' }, annotations } });
    const undeclared = group({ declared: [], present: false, accepted: false });
    assert.equal(undeclared.state, R.FAILURE);
    assert.match(undeclared.why, /full-night-en 398,598 4x4 \(16 px\) in mfd/);
    assert.equal(group({ declared: ['big-screen'], present: true, accepted: false }).state, R.SUCCESS, 'declared');
    assert.equal(group({ declared: [], present: false, accepted: true }).state, R.SUCCESS, 'trusted exact-head accept');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
