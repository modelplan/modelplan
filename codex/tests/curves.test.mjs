import test from 'node:test';
import assert from 'node:assert/strict';
import { effortCurveData, curveCoordinate, effortCurveSvg, focusCurveSeries } from '../ui/curves.js';
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
