<!-- SPDX-License-Identifier: MIT -->
# Verification feature map

Owner: M0/integration. Bind routes to the actual candidate before a scenario runs; an unbound entry is not a working surface.

| Surface | Reachability contract | Required evidence | Current binding |
|---|---|---|---|
| Dock widget | Candidate's native shell route | Actual input delivery, reveal/collapse/placement and rendered rows | M0 supplies candidate route |
| Menu | Candidate menu entry | Actual delivered action and expected row/state | M0 supplies candidate route |
| Cockpit | U11a test window, then candidate cockpit entry | Separate activation receipts, two-second RAF preflight, animation frames, owned PID roles and full cycle counters | U11a observation interface; GUI not-run at this head |
| Settings | Candidate settings entry | Consent/default/revoke/diagnostic flow evidence | M4 supplies route; M1 Drive binds it |

M1's synthetic journey is the next consumer. This map does not authorize product implementation, real-account testing or an unannounced GUI run.
