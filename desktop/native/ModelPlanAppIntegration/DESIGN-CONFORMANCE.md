# Engine Dock and menu conformance

Design source: `design/dock-pulse-defaults-20261027`,
`design-handoffs/r7-spec/SPEC.md` (blob
`119f39dac7d9b9828756f734e70ca811fd2ce135`) and adjacent `GLOSSARY.md`
(blob `cdbbb74a87cf1fd0a3c2ef7f4d3baa8d4a1dc6ea`).

- SPEC §2.2: Settings selects one language for visible labels and row reasons.
- SPEC §3.6: placement changes persist through the shared Settings editor;
  context actions are Open Cockpit, Settings, Hide Dock.
- SPEC decided menu-bar icon / task 53: cap the template image at 16 pt and
  at the actual bar thickness. Do not resize the source resource.
- SPEC §6.6, lines 372–377: Website, Methodology, Privacy, Check for updates,
  Help, Settings, About, Quit. Help is directly above Settings.
- GLOSSARY Parts: Cockpit / 驾驶舱 replaces Console and Dock readings in labels.
- An unreadable community row retains dimmed ink and its localized short reason
  on the face; fresh readings and withdrawn rows discard that reason.

The Help item is disabled because the current engine Cockpit surface exposes no
Option-map operation. Wiring that interaction remains a host follow-up; opening
an ordinary Cockpit is not reported as Help delivery. Update checks remain
disabled when the existing update service/host receiver is unavailable. Public
links reuse Settings destinations; About opens the existing Settings pane.

Official appearance selection and artwork wiring are owned by M0's separate PR.
No appearance provider or licensed asset selection changes here.

Regression coverage: `EngineDesignConformanceTests` exercises the normal entry's
drag commit, durable restart and rebuild, both menu languages/order, and visible
unreadable reasons/withdrawal. `U6StatusItemFrameTests` checks the image cap.
Hosted live-frame assertions retain their approved-host guard; a skip is not a
pass. These tests do not authorize a device run.


## D9 registry amendments for Pulse placement

| Requirement | Decision | Revised binding |
|---|---|---|
| DOCK-3.1-01 | Q8, “edges next to another display and the macOS Dock are allowed” | Left, right and bottom include inner edges. |
| DOCK-3.6-05 | Q8, “edges next to another display and the macOS Dock are allowed” | Resting on the painted strip can reveal the widget at an inner edge. The wake target is inside its display. |
| DOCK-3.6-15 | Q8, “edges next to another display and the macOS Dock are allowed” | Keep the saved left, right or bottom edge on the chosen display, including adjoining edges. The bottom placement uses the visible frame above the macOS Dock under Q9. |
DOCK-3.1-07 applies with its D/52 proportions. Choose D and backing scale for
the destination display under Q10, “size per display”. Per-display appearance
evidence is pending M1 and owner review.

Transient placement, missing-display fallback and active-display following
publish observed placement. A successful release commits through one Settings
placement writer.
