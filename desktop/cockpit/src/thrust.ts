// SPDX-License-Identifier: MIT
// D459/D468 (owner, 2026-11-26): the engine flames are the cockpit's own thrust. The page runs no timers; the host owns
// every timing (the launch burn is its `ignite(true)` .. `ignite(false)`), so this is a pure function of two inputs.
//   ignited                 -> full   (launch burn after a detach, put-back flight, catch-zone approach)
//   docked, not ignited     -> ember  (the cockpit at rest on the rack; the subscription glow shows only here, D460)
//   detached, not ignited   -> out    (D468 overrides D459's short flame: after the burn the flame fades out for good,
//                                      no ember and no glow, and nothing keeps animating)
export type Thrust='full'|'ember'|'out';
export function thrustState(ignited:boolean,attached:boolean):Thrust{return ignited?'full':attached?'ember':'out';}
