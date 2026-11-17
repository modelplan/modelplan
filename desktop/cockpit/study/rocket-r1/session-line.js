// SPDX-License-Identifier: MIT
// CKP-STRIP-09 / CKP-STRIP-16 / CKP-STRIP-17 (owner decision D277, 2026-11-16): what one session-strip line says.
// Order: colour chip · tool · project · model + effort · elapsed · tokens · right end. The right end is "● 58 t/s"
// while the session runs and "6m ago" when it is idle. The strip is "now": it never follows the global time range.
// Pure text, no DOM and no state, so the page (src/prototype-tape.ts) and the unit test read the same words.
import {dhm, tok, relativeMoment} from './mfd-pages/fmt.js';

// The producer's word for a model outside the verified publication (cli cockpitModelID).
export const UNKNOWN_MODEL = 'unknown';
// A harness (the producer's source) by its display name; anything else reads as reported.
const TOOL_NAMES = {codex: 'Codex', 'claude-code': 'Claude', claude: 'Claude', zcode: 'ZCode', zai: 'GLM', glm: 'GLM', opencode: 'OpenCode', opencodego: 'OpenCode', gemini: 'Gemini', grok: 'Grok', kimi: 'Kimi', qwen: 'Qwen', cursor: 'Cursor', copilot: 'Copilot'};
export const toolName = source => TOOL_NAMES[String(source).toLowerCase()] ?? String(source);
// The fader ladder's words (Low · Med · High · XHigh · Max); an effort outside it reads as reported.
const EFFORTS = {low: 'Low', med: 'Med', medium: 'Med', high: 'High', xhigh: 'XHigh', max: 'Max', ultra: 'Ultra'};
export const effortName = effort => effort ? EFFORTS[String(effort).toLowerCase()] ?? String(effort) : null;

const at = value => { const ms = value ? Date.parse(value) : NaN; return Number.isFinite(ms) ? ms : null; };
const count = n => typeof n === 'number' && Number.isFinite(n) && n >= 0;

export function sessionLine(session, now, lang, modelName = id => id) {
  const running = session.state === 'running', started = at(session.startedAt), last = at(session.lastObservedAt);
  // Elapsed runs to now while the session runs; an idle session's ends at its last reading.
  const end = running ? now : last;
  const elapsed = started !== null && end !== null && end >= started ? dhm(Math.floor((end - started) / 60000)) : '--';
  const tokens = count(session.observedOutputTokens) ? tok(session.observedOutputTokens) : '--';
  const rate = running && count(session.rate) ? session.rate : null;
  const ago = running ? null : last === null ? '--' : relativeMoment(Math.min(last, now), {now, lang});
  const unknownModel = session.model === UNKNOWN_MODEL;
  return {tool: toolName(session.source), unknownModel, model: unknownModel ? '' : modelName(session.model), effort: effortName(session.effort), elapsed, tokens, running, rate, ago};
}
