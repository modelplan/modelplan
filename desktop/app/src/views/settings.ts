import type { Lang, Snapshot } from '../snapshot.ts';
import { categories, type Category, type Prefs } from '../notify.ts';
import { sourceName, words } from '../i18n.ts';
import { esc } from './html.ts';

export interface Settings { lang: 'auto' | Lang; menuBar: string; notify: Prefs }

export function renderSettings(s: Snapshot | null, st: Settings, lang: Lang, note = ''): string {
  const t = words(lang);
  const toggles = (Object.keys(categories) as Category[]).map(c =>
    `<label class="toggle"><input type="checkbox" data-notify="${c}"${st.notify[c] ? ' checked' : ''}><span>${esc(t.notify[c])}</span></label>`).join('');
  const sources = ['auto', ...(s?.sessions.map(x => x.source) ?? [])];
  const opt = (v: string, label: string, cur: string) => `<option value="${esc(v)}"${v === cur ? ' selected' : ''}>${esc(label)}</option>`;
  return `<h2 class="mp-lcd-h">${esc(t.notify.title)}</h2><div class="toggles">${toggles}</div>
<p><button type="button" class="utility" data-action="test-notify">${esc(t.notify.test)}</button> <span class="dim small" id="notify-note">${esc(note)}</span></p>
<h2 class="mp-lcd-h">${esc(t.settings)}</h2>
<label class="field"><span>${esc(t.lang)}</span><select data-setting="lang">${opt('auto', 'Auto', st.lang)}${opt('zh', '中文', st.lang)}${opt('en', 'English', st.lang)}</select></label>
<label class="field"><span>${esc(t.menuBar)}</span><select data-setting="menuBar">${[...new Set(sources)].map(v => opt(v, v === 'auto' ? t.auto : sourceName(lang, v), st.menuBar)).join('')}</select></label>
<p class="dim small">${esc(t.local)}</p>`;
}
