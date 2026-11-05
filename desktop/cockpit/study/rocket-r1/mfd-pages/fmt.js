// Pure formatting helpers for the public-screen views (r7 P4, spec 2.6). No state, no fixtures, no DOM: the views
// import these instead of core.js so they port to the desktop app as they are. Synthetic study.
import {t} from '../i18n.js';

export const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[c]));
export const LADDER = ['Low', 'Med', 'High', 'XHigh', 'Max'];
// 41m, 2h00, 5d3h (owner's d/h/m form, spec 2.2)
export const dhm = m => m == null ? '--' : m < 60 ? `${Math.round(m)}m` : m < 1440 ? `${Math.floor(m / 60)}h${String(Math.round(m % 60)).padStart(2, '0')}` : `${Math.floor(m / 1440)}d${Math.floor(m % 1440 / 60)}h`;
export const tok = n => n == null ? '--' : n < 1000 ? String(Math.round(n)) : n < 1e6 ? `${Math.round(n / 1000)}k` : `${(n / 1e6).toFixed(1)}M`;
export const grouped = n => n == null ? '--' : Math.round(n).toLocaleString('en-US');
export const unit = n => n >= 1e6 ? [(n / 1e6).toFixed(1), 'M'] : n >= 1e3 ? [String(Math.round(n / 1e3)), 'k'] : [String(Math.round(n)), ''];
export const sign = v => v > 0.05 ? '+' + v.toFixed(1) : v < -0.05 ? '−' + Math.abs(v).toFixed(1) : '±0';
export const times = v => v == null || !isFinite(v) ? '—' : '×' + (v >= 10 ? v.toFixed(0) : v.toFixed(2));
// Quota status (spec 2.1, one rule everywhere): ok above 50 %, mid above threshold through 50 %, low at/below "turn red below" (ui.redAt, 25).
export const level = (r, redAt = 25) => r == null ? 'none' : r <= redAt ? 'low' : r <= 50 ? 'mid' : 'ok';

const loc = ui => ui.lang === 'en' ? 'en' : 'zh-CN';
// Reset/expiry text is always relative to the supplied reading clock, never the host clock.
export function relativeMoment(ms,ui,full=false) {
  if(!Number.isFinite(ms)||!Number.isFinite(ui.now))return '--';
  const future=ms>ui.now,minutes=Math.max(0,Math.round(Math.abs(ms-ui.now)/60000));
  if(!minutes)return ui.lang==='en'?'now':'现在';
  let duration=dhm(minutes);
  if(full){const d=Math.floor(minutes/1440),h=Math.floor(minutes%1440/60),m=minutes%60;
    duration=ui.lang==='en'?[d?`${d} ${d===1?'day':'days'}`:'',h?`${h} ${h===1?'hour':'hours'}`:'',m?`${m} ${m===1?'minute':'minutes'}`:''].filter(Boolean).join(' ')
      :[d?`${d} 天`:'',h?`${h} 小时`:'',m?`${m} 分`:''].filter(Boolean).join(' ');}
  return ui.lang==='en'?(future?'in '+duration:duration+' ago'):duration+(future?'后':'前');
}
export const resetMoment=(w,ui,full=false)=>relativeMoment(Number.isFinite(w.resetIn)?ui.now+w.resetIn*60000:w.resetAt,ui,full);
const pad = n => String(n).padStart(2, '0');
export const hm = ms => { const d = new Date(ms); return `${pad(d.getHours())}:${pad(d.getMinutes())}`; };
const sameDay = (a, b) => new Date(a).toDateString() === new Date(b).toDateString();
// 10月22日 / Oct 22
export const md = (ms, ui) => new Intl.DateTimeFormat(loc(ui), ui.lang === 'en' ? {month: 'short', day: 'numeric'} : {month: 'long', day: 'numeric'}).format(ms);
export const mon = (ms, ui) => new Intl.DateTimeFormat(loc(ui), {month: 'short'}).format(ms);
const wd = (ms, ui) => new Intl.DateTimeFormat(loc(ui), {weekday: 'short'}).format(ms);
// An absolute time: 17:23 today, 周六 17:30 within a week, 11月3日 later.
export function when(ms, ui) {
  if (ms == null) return '';
  if (sameDay(ms, ui.now)) return hm(ms);
  return Math.abs(ms - ui.now) < 6.5 * 864e5 ? `${wd(ms, ui)} ${hm(ms)}` : md(ms, ui);
}
// A past moment for record lists: 09:12 today, 10/18 09:12 earlier.
export function stamp(ms, ui) {
  if (sameDay(ms, ui.now)) return hm(ms);
  const d = new Date(ms);
  return `${d.getMonth() + 1}/${d.getDate()} ${hm(ms)}`;
}
// Time until a moment, compact: 30h within two days, then 5天 / 5d (reset-card expiries, CodexBar style).
export function until(ms, ui) {
  const h = (ms - ui.now) / 3600e3;
  const whole=Math.max(0,Math.floor(h));
  return h <= 48 ? `${Math.max(0, Math.round(h))}h` : `${Math.floor(whole/24)}d${whole%24}h`;
}
// A 10-segment LCD bar (quota). Status colour comes from the class (spec 2.1). Lit segments are the remaining tens,
// rounded, but one stays lit while anything is left (as the engine table's bars), so only a used-up window is empty.
export const litTens = pct => pct == null || pct <= 0 ? 0 : Math.max(1, Math.min(10, Math.round(pct / 10)));
export const bar10 = (pct, lv = level(pct)) => { const n = litTens(pct); return `<span class="mb10 lv-${lv}">${Array.from({length: 10}, (_, i) => `<i class="${i < n ? 'on' : ''}"></i>`).join('')}</span>`; };
export const chip = colour => `<i class="chip" style="--v:${colour}"></i>`;
// ⚡ drawn as SVG (the faders' bolt), so Safari can never show it as a colour emoji. label: an accessible name.
export const bolt = (label = '') => `<svg class="g-bolt" viewBox="0 0 6 9" ${label ? `role="img" aria-label="${esc(label)}"` : 'aria-hidden="true"'}><path d="M3.9 0 .3 5.1h2.4L2 9l3.7-5.4H3.3z"/></svg>`;
// A clock glyph (CodexBar's reset-credit icon), drawn so no emoji font is needed.
export const clockIcon = () => '<svg class="ico-clock" viewBox="0 0 10 10" aria-hidden="true"><circle cx="5" cy="5" r="4"/><path d="M5 2.6V5l1.7 1.1"/></svg>';
// Tooltip text: lines joined by a newline, escaped for an attribute.
export const tip = lines => esc(lines.filter(Boolean).join('\n'));
// Size of a flexible area measured by the controller (the view leaves a [data-fill] slot; see mfd.js).
export const fill = (ui, name, fb) => ui.fill?.[name] || fb;
