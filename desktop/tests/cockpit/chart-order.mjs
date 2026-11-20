// SPDX-License-Identifier: MIT
// Chart-order assertions (D352 change 4). A reversed chart (the MFD order of #1096, bars drawn newest-first) is a
// recurring defect that no value check sees, because every number is still right. This helper states an order and
// fails with both orders printed. It is pure: callers measure (a node test parses SVG, a Playwright spec reads
// getBoundingClientRect) and hand over {id, pos} items.
import assert from 'node:assert/strict';

/** Items sorted by position (ties keep input order), as ids. */
export const orderOf = (items) => items.map((x, i) => ({...x, i})).sort((a, b) => a.pos - b.pos || a.i - b.i).map((x) => x.id);

/** The items must appear in `expected` order along their `pos` (y for a stacked column, x for a time axis). */
export function assertChartOrder(items, expected, what) {
  assert.ok(items.length > 0, `${what}: nothing was measured`);
  assert.deepEqual(orderOf(items), expected, `${what}: drawn order differs from the required order ${expected.join(' > ')}`);
}

/** Values must not decrease (time axes: oldest first, newest last). */
export function assertAscending(values, what) {
  assert.ok(values.length > 1, `${what}: needs at least two values`);
  for (let i = 1; i < values.length; i++) assert.ok(values[i] >= values[i - 1], `${what}: item ${i} (${values[i]}) is before item ${i - 1} (${values[i - 1]})`);
}

/** Overview bars: every .ov-bucket of overviewBars() as {x, total, tip}, in markup order. */
export function overviewBuckets(svg) {
  return [...svg.matchAll(/<g class="ov-bucket"[^>]*data-total="([^"]*)"[^>]*data-tip="([^"]*)"[^>]*><rect class="ov-hit" x="([\d.]+)"/g)]
    .map((m) => ({total: Number(m[1]), tip: m[2], x: Number(m[3])}));
}
