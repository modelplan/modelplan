// SPDX-License-Identifier: MIT
// Ability against cost from public published data only (owner D39/D-B): each model's effort curve, the gold frontier,
// ★ at the recommended effort, a white dot at the effort last seen. It plots published numbers and scores nothing.
import {esc} from './fmt.js';
import {t} from '../i18n.js';
import '../strings/review49.js';

const plotted = m => m.e.filter(row => row[1] != null && row[2] > 0);
const starRow = m => m.e.find(row => row[0] === m.rec) ?? plotted(m).at(-1) ?? null;

/** Every point with no cheaper-or-equal point at least as able: walking up the cost axis, keep each new best. */
export function frontierPoints(models) {
  const points = models.flatMap(m => plotted(m).map(row => ({m, row}))).sort((a, b) => a.row[2] - b.row[2]);
  const front = [];let best = -Infinity;
  for (const p of points) if (p.row[1] > best) { front.push(p); best = p.row[1]; }
  return front;
}
function starPath(x, y, r) {
  return Array.from({length: 10}, (_, i) => {
    const angle = -Math.PI / 2 + i * Math.PI / 5, reach = i % 2 ? r * .45 : r;
    return `${i ? 'L' : 'M'}${(x + Math.cos(angle) * reach).toFixed(1)} ${(y + Math.sin(angle) * reach).toFixed(1)}`;
  }).join('') + 'Z';
}
/** Beside its ★, one line lower or higher if that spot is taken, or not at all. */
function nameLabels(items, width, taken) {
  const boxes = [...taken], labels = [];
  for (const item of [...items].sort((a, b) => a.dim - b.dim || a.y - b.y)) {
    const w = item.text.length * 5.6 + 2, x = Math.min(item.x, width - w - 1);
    const y = [0, 10, -12, 20, -22].map(dy => item.y + dy).find(y => !boxes.some(b => x < b.x1 && b.x0 < x + w && y - 8 < b.y1 && b.y0 < y + 2));
    if (y === undefined) continue;
    boxes.push({x0: x, x1: x + w, y0: y - 8, y1: y + 2});
    labels.push(`<text class="fc-l ${item.dim ? 'dim' : ''}" x="${x.toFixed(1)}" y="${y.toFixed(1)}">${esc(item.text)}</text>`);
  }
  return labels.join('');
}
export function frontierSvg(models, {w: width, h: height, current = {}, axis = {}, aria = '', selected = null} = {}) {
  const all = models.flatMap(m => plotted(m).map(row => ({m, row})));
  if (!all.length) return '';
  const left = 26, right = 56, top = 10, bottom = 14, log = Math.log10;
  const costs = all.map(p => log(p.row[2])), abilities = all.map(p => p.row[1]);
  const minCost = Math.min(...costs), spanCost = Math.max(...costs) - minCost || 1;
  const minAbility = Math.min(...abilities) - 1, spanAbility = Math.max(...abilities) + 1 - minAbility;
  const X = cost => left + (log(cost) - minCost) / spanCost * (width - left - right);
  const Y = ability => height - bottom - (ability - minAbility) / spanAbility * (height - top - bottom);
  const at = row => `${X(row[2]).toFixed(1)},${Y(row[1]).toFixed(1)}`;
  const front = frontierPoints(models), leaders = new Set(front.map(p => p.m.id));
  const curves = models.map(m => `<polyline class="fc-m ${leaders.has(m.id) ? '' : 'dim'} ${m.id === selected ? 'focus' : ''}" points="${plotted(m).map(at).join(' ')}"/>`).join('');
  const seen = m => current[m.id] ? m.e.find(row => row[0] === current[m.id]) ?? null : null;
  const marks = models.map(m => {
    const star = starRow(m), dot = seen(m);if (!star) return '';
    return `<path class="fc-star ${leaders.has(m.id) ? '' : 'dim'}" d="${starPath(X(star[2]), Y(star[1]), 4)}"/>${dot ? `<circle class="fc-cur" cx="${X(dot[2]).toFixed(1)}" cy="${Y(dot[1]).toFixed(1)}" r="3"/>` : ''}`;
  }).join('');
  const taken = models.flatMap(m => [starRow(m), seen(m)].filter(Boolean)).map(row => ({x0: X(row[2]) - 4, x1: X(row[2]) + 4, y0: Y(row[1]) - 4, y1: Y(row[1]) + 4}));
  const names = nameLabels(models.flatMap(m => { const star = starRow(m);return star ? [{text: m.short, x: X(star[2]) + 6, y: Y(star[1]) + 4, dim: !leaders.has(m.id)}] : []; }), width, taken);
  const points = all.map(({m, row}) => {
    const roles = [current[m.id] === row[0] && t('rev49.current'), m.rec === row[0] && t('rev49.recommended')].filter(Boolean).join(' · ') || t('rev49.published');
    const label = t('rev49.point', {m: m.name, e: row[0], a: row[1], c: row[2], s: roles});
    return `<circle class="fc-inspect" cx="${X(row[2]).toFixed(1)}" cy="${Y(row[1]).toFixed(1)}" r="5" fill="transparent" stroke="none" role="img" aria-label="${esc(label)}" data-tip="${esc(label)}"/>`;
  }).join('');
  return `<svg class="fc" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="group" aria-label="${esc(aria)}"><path class="fc-ax" d="M${left} ${top}V${height - bottom}H${width - 2}"/><text class="fc-al" x="${left + 4}" y="${top + 8}">${esc(axis.ability || '')}</text><text class="fc-al" x="${width - 2}" y="${height - 3}" text-anchor="end">${esc(axis.cost || '')}</text>${curves}<polyline class="fc-front" points="${front.map(p => at(p.row)).join(' ')}"/>${marks}${names}${points}</svg>`;
}
