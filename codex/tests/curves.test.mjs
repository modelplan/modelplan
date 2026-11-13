import test from 'node:test';
import assert from 'node:assert/strict';
import { effortCurveData, curveCoordinate, effortCurveSvg, focusCurveSeries, speedComparison } from '../ui/curves.js';
import { timeRatio } from '../ui/comparison.js';
const basis = { source: 'aa-agent', cohort: 'same-task', boundary: 'wall', referenceSeconds: 100 };
const model = () => ({ recommended: 'medium', configurations: [
  { effort: 'low', label: 'Low', ability: 40, cost: .5, time: 1, timeBasis: basis },
  { effort: 'medium', label: 'Med', ability: 50, cost: 1, time: 2, timeBasis: basis },
  { effort: 'high', label: 'High', ability: 55, cost: 2, time: 3, timeBasis: basis },
  { effort: 'max', label: 'Max', ability: 54, cost: 4, time: 4, timeBasis: basis },
] });

test('zero-point ability gain and 1x ratios share a baseline; ratio doubling is logarithmic', () => {
  const d = effortCurveData(model(), timeRatio);
  assert.deepEqual(d.rows.map(r => r.ability), [-10, 0, 5, 4]);
  assert.equal(curveCoordinate(d, 0, 'ability').fraction, curveCoordinate(d, 1, 'cost').fraction);
  assert.equal(curveCoordinate(d, 2, 'cost').fraction, (curveCoordinate(d, 1, 'cost').fraction + curveCoordinate(d, 4, 'cost').fraction) / 2);
  assert.equal(d.rows[3].abilityValue, 54); // Real decline, not a smoothed maximum.
});
test('selected effort changes highlights but cannot refit curve coordinates or baseline', () => {
  const d = effortCurveData(model(), timeRatio);
  const paths = svg => [...svg.matchAll(/<path[^>]+d="([^"]+)"/g)].map(m => m[1]);
  const a = effortCurveSvg(d, { selected: 0 }), b = effortCurveSvg(d, { selected: 3 });
  assert.deepEqual(paths(a), paths(b));
  assert.notEqual(a, b);
});
test('missing values and incompatible time protocols leave gaps; estimates remain dashed', () => {
  const m = model(); m.configurations[2].cost = null;
  m.configurations[2].timeBasis = { ...basis, cohort: 'different' };
  m.configurations[3].timeEstimated = true;
  const d = effortCurveData(m, timeRatio), svg = effortCurveSvg(d);
  assert.equal(d.rows[2].time, null);
  assert.equal(d.rows[2].cost, null);
  assert.equal((svg.match(/data-series-path="cost"/g) || []).length, 1);
  assert.equal((svg.match(/data-series-path="time"/g) || []).length, 1);
  const contiguous = effortCurveSvg(effortCurveData({ ...m, configurations: [m.configurations[1], m.configurations[3]] }, timeRatio));
  assert.match(contiguous, /data-series-path="time"[^>]+stroke-dasharray/);
});
test('true zero ratios use an explicit zero marker, never log(0), epsilon or an invented point', () => {
  const m = model(); m.configurations[0].cost = 0;
  const d = effortCurveData(m, timeRatio), svg = effortCurveSvg(d);
  assert.equal(d.rows[0].cost, 0);
  assert.equal(curveCoordinate(d, 0, 'cost').zero, true);
  assert.match(svg, />0×<\/text>/);
  assert.doesNotMatch(svg, /NaN|Infinity/);
  assert.equal((svg.match(/data-series-path="cost"/g) || []).length, 2);
});
test('one click isolates a metric, a repeat restores all; only solo plots label every point', () => {
  const all = new Set(['ability', 'cost', 'time']), solo = focusCurveSeries(all, 'cost');
  assert.deepEqual([...solo], ['cost']); assert.equal(all.size, 3);
  assert.deepEqual([...focusCurveSeries(solo, 'cost')], ['ability', 'cost', 'time']);
  const d = effortCurveData(model(), timeRatio);
  assert.equal((effortCurveSvg(d, { series: solo }).match(/class="point-label"/g) || []).length, 4);
  assert.doesNotMatch(effortCurveSvg(d), /class="point-label"/);
});
const tier = (name, quota, credits, speed) => ({ tier: name, billing: [{ account: 'subscription', billsTo: 'plan-quota', ratio: quota }, { account: 'credits', billsTo: 'credits', ratio: credits }], model: { speed } });
test('a speed tier changes cost and time in one state shared by readout and both curves; ability never moves', () => {
  const m = model(), standard = speedComparison(m, timeRatio), fast = speedComparison(m, timeRatio, tier('fast', 2.5, 2, { ratio: null, qualifier: 'unstated' }));
  assert.deepEqual(standard.rows, effortCurveData(m, timeRatio).rows);
  assert.equal(standard.mode, 'standard');
  assert.deepEqual(fast.rows.map(r => r.ability), standard.rows.map(r => r.ability));
  assert.deepEqual(fast.rows.map(r => r.cost), standard.rows.map(r => r.cost * 2.5), 'plan-quota estimate vs ★ standard');
  assert.deepEqual(fast.rows.map(r => r.time), standard.rows.map(r => r.time), 'an unstated speed-up leaves time as in standard mode');
  assert.equal(fast.baselineIndex, standard.baselineIndex);
  assert.equal(fast.generation, null, 'unstated speed stays unknown, not ×1');
  assert.deepEqual([fast.quotaRatio, fast.creditRatio], [2.5, 2]);
  const mini = effortCurveSvg(fast, { mini: true }), detail = effortCurveSvg(fast);
  for (const svg of [mini, detail]) {
    assert.match(svg, /data-series-path="time"/);
    assert.match(svg, /data-series-path="cost"[^>]+stroke-dasharray/, 'estimated quota is dashed');
  }
  assert.notDeepEqual(effortCurveSvg(standard, { mini: true }), mini, 'the mini curve follows the speed mode');
  const ultra = speedComparison(m, timeRatio, tier('ultrafast', 8, 6, { ratio: 8, qualifier: 'up-to' }));
  assert.deepEqual(ultra.generation, { ratio: 8, qualifier: 'up-to' });
  assert.equal(ultra.rows[ultra.baselineIndex].cost, 8);
  const about = speedComparison(m, timeRatio, tier('fast', 2.5, 2, { ratio: 1.5, qualifier: 'approximate' }));
  assert.deepEqual(about.rows.map(r => r.time), standard.rows.map(r => r.time === null ? null : r.time / 1.5), 'time divides by the speed-up');
  assert.ok(about.rows.every(r => r.time === null || r.estimated), 'and is an estimate');
  assert.deepEqual(about.generation, { ratio: 1.5, qualifier: 'approximate' });
  assert.ok(speedComparison(m, timeRatio, { tier: 'fast', billing: [{ billsTo: 'credits', ratio: 2 }], model: {} }).rows.every(r => r.cost === null), 'no plan-quota multiple, no quota estimate');
});
