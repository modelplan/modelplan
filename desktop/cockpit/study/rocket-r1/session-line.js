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
  // CKP-STRIP-16: an unknown segment is left out (null), never written as "--" and never as zero.
  const elapsed = started !== null && end !== null && end >= started ? dhm(Math.floor((end - started) / 60000)) : null;
  const tokens = count(session.observedTotalTokens) ? tok(session.observedTotalTokens) : null;
  const rate = running && count(session.rate) ? session.rate : null;
  const ago = running || last === null ? null : relativeMoment(Math.min(last, now), {now, lang});
  // G3-134: a model outside the publication whose raw name was readable shows that prettified name and a dim "not
  // listed" badge; only a name the producer could not read at all is the dim "unknown model".
  const outside = session.model === UNKNOWN_MODEL;
  const display = outside && typeof session.modelDisplay === 'string' && session.modelDisplay !== '' ? session.modelDisplay : null;
  const unlisted = display !== null, unknownModel = outside && !unlisted;
  return {tool: toolName(session.source), unknownModel, unlisted, model: unlisted ? display : unknownModel ? '' : modelName(session.model), effort: effortName(session.effort), elapsed, tokens, running, rate, ago};
}
