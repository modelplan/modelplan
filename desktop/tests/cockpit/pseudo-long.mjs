// SPDX-License-Identifier: MIT
// Test-only pseudo-long locale (SET-9-40 groundwork, SET-9-38 layout check): every English string is padded by about 40 %,
// the width a longer language typically needs. It is never offered to users: the product tables stay en and zh-CN, and the
// browser spec swaps these strings in by rewriting the served i18n.js module, so nothing here is bundled.

// Pure and self-contained (it is serialised into the page). Keeps {vars} and <tags> intact; the padding repeats the
// string's own letters, so its width is realistic, and it is appended without a space so it can never add a wrap point.
export function pseudoLong(text) {
  if (text && typeof text === 'object') return Object.fromEntries(Object.entries(text).map(([k, v]) => [k, pseudoLong(v)]));
  if (typeof text !== 'string') return text;
  const letters = text.replace(/\{\w+\}|<[^>]+>/g, '').replace(/[^\p{L}\p{N}]/gu, '');
  if (!letters) return text;
  const extra = Math.ceil(text.replace(/\{\w+\}|<[^>]+>/g, 'xxx').length * 0.4);
  let pad = '';
  while (pad.length < extra) pad += letters;
  return text + pad.slice(0, extra);
}

// Serves i18n.js with every English registration padded. Install before the page loads.
export async function usePseudoLong(page) {
  await page.addInitScript(`window.__pseudoLong=${pseudoLong.toString()};`);
  await page.route('**/study/rocket-r1/i18n.js', async route => {
    const response = await route.fetch();
    const source = await response.text();
    const patched = source.replace('tables.en[key] = en;', 'tables.en[key] = window.__pseudoLong ? window.__pseudoLong(en) : en;');
    if (patched === source) throw new Error('pseudo-long: the register() line in i18n.js changed');
    await route.fulfill({response, body: patched});
  });
}
