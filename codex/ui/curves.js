const curveFinite = v => typeof v === 'number' && Number.isFinite(v);
const curveEsc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const curveMultiple = v => curveFinite(v) ? '×' + v.toFixed(2) : '—';
export const curveGain = v => curveFinite(v) ? (v >= 0 ? '+' : '') + v.toFixed(1) : '—';
export function focusCurveSeries(current, key) {
  return current.size === 1 && current.has(key) ? new Set(['ability', 'cost', 'time']) : new Set([key]);
}

// One shared baseline, with additive ability points and a separate log-ratio axis.
// No ability-score division, selected-effort refit, interpolation or protocol mixing.
export function effortCurveData(model, ratioForTime) {
  const baselineIndex = model.configurations.findIndex(c => c.effort === model.recommended);
  const base = model.configurations[baselineIndex];
  const rows = model.configurations.map(c => ({
    effort: c.effort, label: c.label, abilityValue: c.ability,
    ability: curveFinite(c.ability) && curveFinite(base?.ability) ? c.ability - base.ability : null,
    cost: curveFinite(c.cost) && c.cost >= 0 && base?.cost > 0 ? c.cost / base.cost : null,
    time: ratioForTime(c, base), estimated: !!(c.timeEstimated || base?.timeEstimated),
  }));
  const logs = rows.flatMap(r => [r.cost, r.time].filter(v => curveFinite(v) && v > 0).map(Math.log2));
  const low = Math.min(-.5, Math.floor(Math.min(0, ...logs) * 2) / 2);
  const high = Math.max(.5, Math.ceil(Math.max(0, ...logs) * 2) / 2);
  const gains = rows.map(r => r.ability).filter(curveFinite);
  const needed = Math.max(1, -Math.min(0, ...gains) / -low, Math.max(0, ...gains) / high);
  const power = 10 ** Math.floor(Math.log10(needed));
  const pointsPerDoubling = [1, 2, 2.5, 5, 10].map(v => v * power).find(v => v >= needed);
  return { rows, baselineIndex, low, high, pointsPerDoubling };
}

export function curveCoordinate(data, value, key) {
  if (!curveFinite(value)) return null;
  if (key !== 'ability' && value === 0) return { zero: true, fraction: 1 };
  if (key !== 'ability' && value < 0) return null;
  const coordinate = key === 'ability' ? value / data.pointsPerDoubling : Math.log2(value);
  return { zero: false, fraction: (data.high - coordinate) / (data.high - data.low) };
}

export function effortCurveSvg(data, { selected = 0, series = new Set(['ability', 'cost', 'time']), mini = false, language = 'zh' } = {}) {
  const width = mini ? 260 : 440, height = mini ? 82 : 182;
  const left = mini ? 10 : 38, right = mini ? 10 : 40, top = mini ? 7 : 18, bottom = mini ? 18 : 30;
  const plotH = height - top - bottom, plotW = width - left - right;
  const x = i => left + (data.rows.length > 1 ? i / (data.rows.length - 1) * plotW : plotW / 2);
  const y = fraction => top + fraction * plotH;
  const baseY = y(data.high / (data.high - data.low));
  const labels = language === 'zh' ? { ability: '能力', cost: '成本', time: '耗时', points: '分' } : { ability: 'Ability', cost: 'Cost', time: 'Time', points: 'pts' };
  let svg = `<svg class="curve ${mini ? 'mini-curve' : ''}" viewBox="0 0 ${width} ${height}" role="img" aria-label="${language === 'zh' ? '能力成本耗时档位曲线' : 'Effort capability, cost and time curves'}" data-baseline-y="${baseY}">`;
  for (const tick of [...new Set([data.low, 0, data.high])]) {
    const yy = y((data.high - tick) / (data.high - data.low));
    svg += `<line class="${tick === 0 ? 'baseline' : 'grid'}" x1="${left}" x2="${width - right}" y1="${yy}" y2="${yy}"/>`;
    if (!mini && series.has('ability')) svg += `<text x="${left - 7}" y="${yy + 3}" text-anchor="end">${tick * data.pointsPerDoubling >= 0 ? '+' : ''}${(tick * data.pointsPerDoubling).toFixed(0)}</text>`;
    if (!mini && (series.has('cost') || series.has('time'))) svg += `<text x="${width - right + 7}" y="${yy + 3}">${curveMultiple(2 ** tick)}</text>`;
  }
  if (!mini && series.has('ability')) svg += `<text x="${left}" y="10">Δ${labels.points}</text>`;
  if (!mini && (series.has('cost') || series.has('time'))) svg += `<text x="${width - right}" y="10" text-anchor="end">× · log₂</text>`;
  if (data.baselineIndex >= 0) svg += `<line class="recommended-guide" x1="${x(data.baselineIndex)}" x2="${x(data.baselineIndex)}" y1="${top}" y2="${height - bottom}"/>`;
  svg += `<line class="selected-guide" x1="${x(selected)}" x2="${x(selected)}" y1="${top}" y2="${height - bottom}"/>`;
  for (const key of series) {
    let previous = null;
    data.rows.forEach((row, i) => {
      const p = curveCoordinate(data, row[key], key);
      if (!p) { previous = null; return; }
      const xx = x(i), yy = p.zero ? height - bottom + 4 : y(p.fraction), estimated = key === 'time' && row.estimated;
      if (previous && !p.zero) svg += `<path class="series" data-series-path="${key}" stroke="var(--mp-${key})" ${estimated || previous.estimated ? 'stroke-dasharray="4 3"' : ''} d="M${previous.x} ${previous.y} L${xx} ${yy}"/>`;
      svg += `<circle data-series-point="${key}" data-effort-index="${i}" cx="${xx}" cy="${yy}" r="${i === selected ? mini ? 3.3 : 4 : mini ? 1.8 : 2.7}" fill="${estimated || p.zero ? 'none' : `var(--mp-${key})`}" stroke="var(--mp-${key})"><title>${curveEsc(row.label)} · ${labels[key]} ${key === 'ability' ? curveGain(row[key]) + ' ' + labels.points : curveMultiple(row[key])}${estimated ? ' ≈' : ''}</title></circle>`;
      if (!mini && series.size === 1 && !p.zero) svg += `<text class="point-label" x="${xx}" y="${yy + (key === 'ability' ? 13 : -8)}" text-anchor="${i === 0 ? 'start' : i === data.rows.length - 1 ? 'end' : 'middle'}" style="fill:var(--mp-${key})">${key === 'ability' ? curveGain(row[key]) : (estimated ? '≈' : '') + curveMultiple(row[key])}</text>`;
      if (p.zero) { svg += `<text x="${xx}" y="${yy - 5}" text-anchor="middle">0×</text>`; previous = null; }
      else previous = { x: xx, y: yy, estimated };
    });
  }
  data.rows.forEach((row, i) => {
    if (!mini || [0, data.baselineIndex, selected, data.rows.length - 1].includes(i)) svg += `<text class="${i === data.baselineIndex ? 'rec-label' : i === selected ? 'current-label' : ''}" x="${x(i)}" y="${height - 3}" text-anchor="${i === 0 ? 'start' : i === data.rows.length - 1 ? 'end' : 'middle'}">${i === data.baselineIndex ? '★' : ''}${curveEsc(row.label)}</text>`;
    svg += `<rect class="hit" x="${x(i) - plotW / Math.max(2, data.rows.length - 1) / 2}" y="${top}" width="${plotW / Math.max(2, data.rows.length - 1)}" height="${plotH}" data-chart-detent="${i}" role="button" tabindex="${mini ? '-1' : '0'}" aria-label="${curveEsc(row.label)}"><title>${curveEsc(row.label)} · ${labels.ability} ${curveGain(row.ability)} ${labels.points} · ${labels.cost} ${curveMultiple(row.cost)} · ${labels.time} ${row.estimated && curveFinite(row.time) ? '≈' : ''}${curveMultiple(row.time)}</title></rect>`;
  });
  return svg + '</svg>';
}
