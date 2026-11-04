# G1 M3 normal-entry journey status

Snapshot: public main `b98ab81217abe2ea634c369221dd9da612639af2`. This is source-based triage, not an executed journey or device acceptance. No requirement text or private fixture data is included. Product-missing entries below are source observations that still need normal-entry verification; no result is counted as passing.

| ID | Status | Current evidence / next boundary |
|---|---|---|
| CKP-ENTRY-02 | GUI-only | Real ignition hold and resulting page need the authorized window-server runner. |
| CKP-ENTRY-04 | seam-needed: EngineCockpitCoordinator.swift:selectedScope | Selection is in-memory; no day-boundary persistence/reset was found. A normal-entry controlled-clock journey is needed. |
| CKP-ENTRY-05 | seam-needed: CommunityCockpitApplicationFactory.swift:makeForChecks | Main's injected-client path bypasses the real cockpit composition; M2's separate seam must land before a valid synthetic normal-entry test. |
| CKP-ENTRY-06 | GUI-only | Actual first usable page timing requires the authorized window/device path. |
| CKP-PORT-02 | product-missing | Current field is empty; badge treatment cannot be established from an absent asset. Visual owner review remains separate. |
| CKP-PORT-03 | product-missing | Current renderer clears the HUD; actual projected-scrim geometry remains unverified. |
| CKP-PORT-04 | product-missing | Current renderer clears the HUD; chart/list content is not available to inspect. |
| CKP-PORT-05 | product-missing | Current renderer clears the HUD; compact HUD content is not available to inspect. |
| CKP-PORT-06 | product-missing | Current renderer clears the HUD; its row/point interactions are not available to exercise. |
| CKP-PORT-07 | product-missing | Current field/HUD have no delivered shared published selection to compare. |
| CKP-PORT-08 | product-missing | Current renderer clears the HUD; chart geometry is not available to inspect. |
| CKP-PORT-09 | GUI-only | Actual shutter, short-screen geometry and transition require the real window path. |
| CKP-PORT-10 | GUI-only | Actual canopy/HUD compositing and accessibility delivery require the real page/window path. |

No synthetic preview, skipped test or static source observation is a normal-entry pass. The M2 inspection branch is deliberately not included; the existing #484 work remains separate. A later change must provide and execute actual tests at the normal entry, including the required negative states, before changing any status to written or passed.
