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
- The v1 menu places Help directly above Settings and keeps Website, Methodology,
  Privacy, About and Quit. D16, S-03 and I-08 omit Check for updates even when
  the helper advertises an update capability.
- GLOSSARY Parts: Cockpit / 驾驶舱 replaces Console and Dock readings in labels.
- An unreadable community row retains dimmed ink and its localized short reason
  on the face; fresh readings and withdrawn rows discard that reason.

Help requests the Dock help map. Public links reuse Settings destinations.
About opens the existing Settings pane. The status menu, widget entry and
Command-comma use the shared Settings window host.

Official appearance selection and artwork wiring are owned by M0's separate PR.
No appearance provider or licensed asset selection changes here.

Regression coverage: `EngineDesignConformanceTests` exercises the normal entry's
drag commit, durable restart and rebuild, both menu languages/order, and visible
unreadable reasons/withdrawal. `U6StatusItemFrameTests` checks the image cap.
Hosted live-frame assertions retain their approved-host guard; a skip is not a
pass. These tests do not authorize a device run.
