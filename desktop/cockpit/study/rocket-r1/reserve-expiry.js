// SPDX-License-Identifier: MIT
// D474 §5.1 / C7: one rule for "a reserve item expires soon" on every surface. A banked reset (or other reserve item)
// whose expiry is in the future and at most 48 hours away is soon: the reserve line's amber clause, the alert list's
// counted reserve row, and (native, ReserveExpiry.swift in #1289) the widget card and the menu. Both helpers are held to
// tests/shared/reserve-expiry.json. Pure: the clock is an argument. A missing or unreadable expiry is never soon.
export const RESERVE_SOON_H = 48;
const LIMIT_MS = RESERVE_SOON_H * 3600e3;
const ms = v => typeof v === 'number' ? v : typeof v === 'string' ? Date.parse(v) : NaN;
export function reserveSoon(expiresAt, now) {
  const at = ms(expiresAt);
  if (!Number.isFinite(at) || !Number.isFinite(now)) return false;
  return at > now && at - now <= LIMIT_MS;
}
