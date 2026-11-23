// SPDX-License-Identifier: MIT
// Ability against cost from public published data only (owner D39/D-B): each model's effort curve, the gold frontier,
// ★ at the recommended effort, a white dot at the effort last seen. It plots published numbers and scores nothing.
import {esc} from './fmt.js';
import {t} from '../i18n.js';
import '../strings/review49.js';

const plotted = m => m.e.filter(row => row[1] != null && row[2] > 0);
const starRow = m => m.e.find(row => row[0] === m.rec) ?? plotted(m).at(-1) ?? null;

/** Every point with no cheaper-or-equal point at least as able: walking up the cost axis, keep each new best. At one
 * cost the most able point comes first, so an equally priced but less able one never leads (audit F 3). */
export function frontierPoints(models) {
  const points = models.flatMap(m => plotted(m).map(row => ({m, row}))).sort((a, b) => a.row[2] - b.row[2] || b.row[1] - a.row[1]);
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
/** Beside its ★, one line lower or higher or on its left if that spot is taken; when none is free the name goes in the
 * first free row down the right-hand edge — or the next column left of it — with a thin leader line back to its ★.
 * A spot counts as free only inside the chart, an overlong published name is fitted to the chart's width (the full
 * name stays in the hover title; the point's tooltip keeps it too), and every name is drawn (G3-168). */
// Estimated drawn width: 5.6 px per narrow glyph; full-width, CJK and emoji glyphs take about two (measured in WebKit:
// a 47-glyph full-width name is ~450 px). Exported so the tests use the renderer's own estimate.
export const labelWidth = text => [...text].reduce((sum, ch) => sum + (/[\u1100-\u115f\u2e80-\ua4cf\uac00-\ud7a3\uf900-\ufaff\ufe30-\ufe6f\uff00-\uff60\uffe0-\uffe6]|\p{Extended_Pictographic}/u.test(ch) ? 10 : 5.6), 2);
function nameLabels(items, width, height, taken) {
  const boxes = [...taken], labels = [];
  const free = (x, y, w) => x >= 1 && x + w <= width - 1 && y - 8 >= 0 && y + 2 <= height
    && !boxes.some(b => x < b.x1 && b.x0 < x + w && y - 8 < b.y1 && b.y0 < y + 2);
  for (const item of [...items].sort((a, b) => a.dim - b.dim || a.y - b.y)) {
    let text = item.text, w = labelWidth(text);
    while (w > width - 2 && text.length > 2) { text = [...text].slice(0, -2).join('') + '…'; w = labelWidth(text); }
    const right = Math.min(item.x, width - w - 1), left = Math.max(1, item.x - 12 - w);
    let spot = null;
    for (const [x, dy] of [[right, 0], [right, 10], [right, -12], [right, 20], [right, -22], [left, 0], [left, 10], [left, -12]]) {
      if (free(x, item.y + dy, w)) { spot = {x, y: item.y + dy}; break; }
    }
    let leader = '';
    if (!spot) {
      for (const x of [width - w - 1, width - 2 * w - 7]) {
        for (let y = 10; y < height - 4; y += 10) if (free(x, y, w)) { spot = {x, y}; break; }
        if (spot) break;
      }
      // Search the remaining chart before using the unavoidable crowded fallback.
      if (!spot) {
        for (let x = width - w - 1; x >= 1 && !spot; x -= 5) {
          for (let y = 8; y <= height - 2; y += 2) if (free(x, y, w)) { spot = {x, y}; break; }
        }
      }
      spot ??= {x: Math.max(1, width - w - 1), y: Math.max(8, Math.min(height - 2, item.y))};
      leader = `<line class="fc-lead" x1="${(item.x - 6).toFixed(1)}" y1="${(item.y - 4).toFixed(1)}" x2="${(spot.x - 1).toFixed(1)}" y2="${(spot.y - 3).toFixed(1)}"/>`;
    }
    boxes.push({x0: spot.x, x1: spot.x + w, y0: spot.y - 8, y1: spot.y + 2});
    const title = text !== item.text ? `<title>${esc(item.text)}</title>` : '';
    labels.push(`${leader}<text class="fc-l ${item.dim ? 'dim' : ''}" x="${spot.x.toFixed(1)}" y="${spot.y.toFixed(1)}">${title}${esc(text)}</text>`);
  }
  return labels.join('');
}
export function frontierSvg(models, {w: width, h: height, current = {}, axis = {}, aria = '', selected = null, named = null} = {}) {
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
  // A session reports the wire key ("high"), a row names its label ("High"): the model's labels map one to the other
  // (audit F 4); a study model without them already reports labels.
  const isCurrent = (m, row) => !!current[m.id] && row[0] === (m.labels?.[current[m.id]] ?? current[m.id]);
  const seen = m => m.e.find(row => isCurrent(m, row)) ?? null;
  const marks = models.map(m => {
    const star = starRow(m), dot = seen(m);if (!star) return '';
    return `<path class="fc-star ${leaders.has(m.id) ? '' : 'dim'}" d="${starPath(X(star[2]), Y(star[1]), 4)}"/>${dot ? `<circle class="fc-cur" cx="${X(dot[2]).toFixed(1)}" cy="${Y(dot[1]).toFixed(1)}" r="3"/>` : ''}`;
  }).join('');
  const taken = models.flatMap(m => [starRow(m), seen(m)].filter(Boolean)).map(row => ({x0: X(row[2]) - 4, x1: X(row[2]) + 4, y0: Y(row[1]) - 4, y1: Y(row[1]) + 4}));
  const names = nameLabels(models.flatMap(m => { const star = starRow(m);return star && (!named || named.has(m.id)) ? [{text: m.short, x: X(star[2]) + 6, y: Y(star[1]) + 4, dim: !leaders.has(m.id)}] : []; }), width, height, taken);
  const points = all.map(({m, row}) => {
    const roles = [isCurrent(m, row) && t('rev49.current'), m.rec === row[0] && t('rev49.recommended')].filter(Boolean).join(' · ') || t('rev49.published');
    const label = t('rev49.point', {m: m.name, e: row[0], a: row[1], c: row[2], s: roles});
    return `<circle class="fc-inspect" cx="${X(row[2]).toFixed(1)}" cy="${Y(row[1]).toFixed(1)}" r="5" fill="transparent" stroke="none" role="img" aria-label="${esc(label)}" data-tip="${esc(label)}"/>`;
  }).join('');
  return `<svg class="fc" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="group" aria-label="${esc(aria)}"><path class="fc-ax" d="M${left} ${top}V${height - bottom}H${width - 2}"/><text class="fc-al" x="${left + 4}" y="${top + 8}">${esc(axis.ability || '')}</text><text class="fc-al" x="${width - 2}" y="${height - 3}" text-anchor="end">${esc(axis.cost || '')}</text>${curves}<polyline class="fc-front" points="${front.map(p => at(p.row)).join(' ')}"/>${marks}${names}${points}</svg>`;
}
