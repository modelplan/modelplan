# Engine Dock and menu conformance

Design source: `design/dock-pulse-defaults-20261027`,
`design-handoffs/r7-spec/SPEC.md` (blob
`119f39dac7d9b9828756f734e70ca811fd2ce135`) and adjacent `GLOSSARY.md`
(blob `cdbbb74a87cf1fd0a3c2ef7f4d3baa8d4a1dc6ea`).

- SPEC §2.2: Settings selects one language for visible labels and row reasons.
- SPEC §3.6: placement changes persist through the shared Settings editor;
  context actions are Open Cockpit, Settings, Close, and Hide Quota Widget.
  The hover card pairs Settings and Close. The paused menu retains Close and Quit.
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
