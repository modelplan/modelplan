// Whole-label aliases shared by the fader LCD, published model projection and record strip.
// First choice preserves the model version where needed; later choices are explicit narrow-LCD aliases.
// Unknown names retain their full text where it fits, otherwise use a defined generic tag (full name in aria/title).
const MODELS = {
  'GPT-6 Luna': ['Luna'],
  'GPT-6 Sol': ['Sol 6', 'Sol6'],
  'GPT-6.1 Sol': ['Sol 6.1', 'Sol6.1'],
  'GPT-6 Astra': ['Astra'],
  'GPT Astra': ['Astra'],
  'Claude Opus 5.5': ['Opus 5.5', 'Opus5.5', 'Opus'],
  'Claude Sonnet 5': ['Sonnet 5', 'Sonnet5', 'Sonnet'],
  'Claude Sonnet 5.5': ['Sonnet 5.5', 'Sonnet5.5', 'Sonnet'],
  'Claude Fable 5.1': ['Fable 5.1', 'Fable5.1', 'Fable'],
  'Claude Haiku 4.5': ['Haiku 4.5', 'Haiku4.5', 'Haiku'],
  'Claude Haiku 5.5': ['Haiku 5.5', 'Haiku5.5', 'Haiku'],
  'GLM-5.3': ['GLM-5.3', 'GLM'],
  'GLM-5.3-Flash': ['GLM Flash', 'GLM-F'],
  'GPT-5.6 Terra': ['Terra 5.6', 'Terra5.6', 'Terra'],
  'GPT-5.6 Sol': ['Sol 5.6', 'Sol5.6'],
  'GPT-5.6 Luna': ['Luna 5.6', 'Luna5.6', 'Luna'],
  'GPT-5.5': ['GPT-5.5', 'GPT'],
  'GPT-6.1 Terra': ['Terra 6.1', 'Terra6.1', 'Terra'],
  'GPT-6 Terra': ['Terra 6', 'Terra6', 'Terra'],
  'GPT-6.1 Luna': ['Luna 6.1', 'Luna6.1', 'Luna'],
  'GPT-6.1 Astra': ['Astra 6.1', 'Astra6.1', 'Astra'],
};
// Public port (owner build 13): a published name the table does not know yet still gets a short name, so a new release
// is not cut off on the 56 px LCD. The vendor prefix goes and the version stays: "GPT-6.2 Terra" -> "Terra 6.2",
// "Claude Opus 6" -> "Opus 6". Anything else keeps its full text.
function generic(name) {
  const gpt = /^GPT-(\d+(?:\.\d+)?)\s+([A-Za-z]+)$/.exec(name), claude = /^Claude\s+([A-Za-z]+)\s+(\d+(?:\.\d+)?)$/.exec(name);
  const m = gpt ? [gpt[2], gpt[1]] : claude ? [claude[1], claude[2]] : null;
  return m ? [`${m[0]} ${m[1]}`, `${m[0]}${m[1]}`, m[0]] : null;
}
const TOOLS = {'Claude Code': ['CLAUDE'], Codex: ['CODEX'], OpenCode: ['OPENCODE']};
export function shortLabel(name, kind = 'model', fits = label => kind !== 'tool' || label.length <= 8) {
  const table = kind === 'tool' ? TOOLS : MODELS;
  const fallback = kind === 'tool' ? 'TOOL' : 'Model';
  const unknown = kind === 'tool' ? String(name || fallback).split(/\s+/)[0].toUpperCase() : String(name || fallback);
  return [...(table[name] || (kind === 'model' && generic(String(name || ''))) || [unknown]), fallback].find(fits) || fallback;
}
