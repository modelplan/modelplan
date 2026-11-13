<!-- SPDX-License-Identifier: MIT -->
# Verification feature map

Owner: M2/skill integration. Bind routes to the actual candidate before a scenario runs; an unbound entry is not a working surface.

| Surface | Reachability contract | Required evidence | Current binding |
|---|---|---|---|
| Dock widget | Candidate's native shell route | Actual input delivery, reveal/collapse/placement and rendered rows | M2 binds candidate route from the delivered shell subject |
| Menu | Candidate menu entry | Actual delivered action and expected row/state | M2 binds candidate route from the delivered shell subject |
| Cockpit | U11a test window, then candidate cockpit entry | Separate activation receipts, two-second RAF preflight, animation frames, owned PID roles and full cycle counters | U11a role-counter evidence is separate; U11WiredHost uses EngineCockpitCoordinator → ProcessEngineClient.cockpit → ordered response → CockpitWindowController. Private candidate action remains unbound until assembly. |
| Settings | Candidate settings entry | Consent/default/revoke/diagnostic flow evidence | M4 supplies route; the skill Drive binds it |

M1's synthetic journey is the next consumer. This map does not authorize product implementation, real-account testing or an unannounced GUI run.

Current source inventory: [`CommunityApp.swift`](../ModelPlanAppIntegration/Sources/ModelPlanCommunityApp/CommunityApp.swift) composes `ProductionDockFactory.community()`, `CommunityApplicationFactory.makeSurfaces` and `makeDelegate` with Settings integration. This inventory is not a claim that the next candidate or U11 cockpit is wired or verified. The root `ModelPlanCommunity` executable is explicitly legacy/probe-compatible. Candidate routes remain unbound until an exact subject is delivered.
