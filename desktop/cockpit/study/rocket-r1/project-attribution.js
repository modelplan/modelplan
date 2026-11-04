// Project totals are not attributable from model configuration shares or current source bindings.
// Exact per-account measurements are optional; an unbound scoped reading remains unknown.
const amount = v => typeof v === 'number' && Number.isFinite(v) && v >= 0;
export function projectTotals(row) {
  return {total: amount(row.tokens) ? row.tokens : null,
    accounts: row.accountTokens && typeof row.accountTokens === 'object' ? Object.fromEntries(Object.entries(row.accountTokens).filter(([, n]) => amount(n))) : null};
}
export function scopedProject(row, accountIds, scope = null) {
  const totals = row.tokenTotals || projectTotals(row), ids = scope ? [scope] : accountIds;
  if (totals.accounts) {
    const values = ids.filter(id => Object.hasOwn(totals.accounts, id)).map(id => totals.accounts[id]);
    // accountTokens is a complete attribution map only when explicitly marked complete.
    const complete = row.accountTokensComplete || ids.every(id => Object.hasOwn(totals.accounts, id));
    return {...row, tokens: complete ? values.reduce((a, b) => a + b, 0) : null, combinedTokens: totals.total, available: !complete || values.length > 0, tokenScope: complete ? 'account' : 'unknown'};
  }
  return {...row, tokens: scope ? null : totals.total, combinedTokens: totals.total, tokenScope: scope ? 'unknown' : 'combined'};
}
