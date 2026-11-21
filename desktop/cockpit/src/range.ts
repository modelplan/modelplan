// SPDX-License-Identifier: MIT
/** CKP-SHELL-50 / MENU-52 (WP-09): the app's one time range. The host owns it, keeps it across restarts and sends it
 *  in the shell before the first render; the page shows it and asks to change it (big-screen key, T). Quota, resets,
 *  alerts and sessions are "now" and never follow it. */
export type CockpitRange='today'|'7d'|'30d';
/** A fresh profile (and an older host that sends no range) is at 7d, as the native default. */
export const INITIAL_RANGE:CockpitRange='7d';
export const COCKPIT_RANGES:readonly CockpitRange[]=Object.freeze(['today','7d','30d']);
export const isCockpitRange=(value:unknown):value is CockpitRange=>value==='today'||value==='7d'||value==='30d';
/** T: Today → 7d → 30d → Today. */
export const nextCockpitRange=(range:CockpitRange):CockpitRange=>range==='today'?'7d':range==='7d'?'30d':'today';
