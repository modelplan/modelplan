<!-- SPDX-License-Identifier: MIT -->
# DEBUG rendered inspection

The shared rev-2 interface is `app.renderedSnapshotForChecks() -> G1RenderedSnapshot`.
It adapts the existing `app.composition.renderedSnapshotForChecks()` observation tree.
The shared fields use `G1Element`, `G1Role`, `G1Interaction` and `G1Color`; `find(_:)`
searches the exported roots depth-first and `all(role:)` returns matching elements.
The detailed `root`/`element(_:)` tree remains available for evidence and unknown-field metadata.
It is available only in DEBUG builds and returns copied observations. The getter does not
reload a store, lay out or draw a view, execute JavaScript, dispatch input, or show a window.
The migration comment table in `Sources/ModelPlanAppIntegration/G1RenderedSnapshot.swift`
maps the queued one-off names to tree locations. Existing getters remain for compatibility.

Use `EngineRowsEntry.makeForG1Checks` with `G1InspectionControls` and a synthetic engine
consumer. The real app owner, cockpit page factory and store fanout remain in place.
The app adapters `advanceClock(by:)`, `movePointer(to:)` and
`injectVerifiedSessionActivity(tool:member:active:)` forward to that bound controls object.
They reject invalid/unbound input with a fixed diagnostic; no raw member or error text is logged.
Clock/pointer/activity inputs are separate from the getter. Session activity still requires
current delivery, explicit stable membership and producer verification/fresh-output facts.
The activity tool is the canonical row ID, and the member must be one matching bound
subscription reference. Updating it preserves other explicitly admitted member inputs,
without broadcasting to other accounts of the tool.
The pointer input calls the actual view hover dispatcher; it never moves the desktop cursor.
The clock drives source/interaction deadlines and can seek the existing pooled effects.
Platform window animations and WebKit animation phases remain real renderer observations.

A native Dock test must explicitly supply an isolated notification ledger. The G1 constructor
uses the normal notifier composition but rejects system notification delivery; it does not
produce successful delivery receipts or read the owner's default notification ledger.

## Evidence and coordinates

- `dock`: completed raster text, image/filter, layer, material and geometry observations.
- `card`: retained native controls plus completed custom fills and bar segments.
- `settings`: the existing native Settings surface, only after the caller presents it.
- `cockpit`: real shell state and an opt-in, bounded, completed WebKit layout/style readback.

Native controls carry `retained-native-view` evidence; custom paints carry
`completed-native-draw`; raster and web observations have their own evidence tags.
`visible` records window/layout visibility, distinct from mounted, hidden or offscreen-drawn
state. Native rectangles use points and report their parent flip basis. Screen-space area
roots are explicit. Web rectangles are actual viewport CSS-pixel client bounds; page zoom
and device pixel ratio are reported separately. Raster rectangles use the completed drawing
transform and backing scale, including transformed nozzle/readout passes.
Text clip rectangles are paired with the pre-baseline `frameTransform`; the CoreText
`glyphTransform` is recorded separately and must not be applied to that parent-space clip.
Controlled pointer input uses the currently displayed edge instrument after topology recovery,
including the same displayed view for leave events.

The native tree is a synchronous main-actor read. Web data is the last completed current
layout capture, with its own capture timestamp/generation. Readback is enabled only by the
G1 constructor, follows real accepted/rendered/input events, and waits for paint frames.
No protocol render receipt is manufactured. Display replacement, hide, clear and discard
invalidate old observations; delayed results cannot republish a prior context.

The shared facade exports only observed screen-point rectangles. Offscreen native/raster
rectangles and unmapped web CSS-pixel rectangles have `frame == nil`; the detailed tree
retains their actual local coordinate system. Unknown visibility maps conservatively to
`visible == false`; `idle` means no observed active input, not a positive hover receipt.
Menu and status-item observations are not wired yet (`nil`), and notices remain an empty
array. These values do not prove that the corresponding product surfaces or notices are absent.

Nil/unavailable means no observation, never zero or a positive acceptance receipt.
Textured/blurred backdrops and original multicolour assets have no invented uniform contrast.
Secure control values are withheld. Ledger identity is a path hash, not a path export.
Snapshot copies may contain displayed data: use synthetic profiles for portable evidence.
This API does not itself establish complete requirement, device or visual acceptance.

## Targeted checks

No-window checks:

```sh
swift test --package-path desktop/native/ModelPlanAppIntegration --filter 'G1DockJourneysD.testGenericSnapshot|G1RenderedSnapshotUnitTests'
```

Actual native Settings and WebKit checks run on the admitted GUI leg, with synthetic
profiles/client and a hash-verified synthetic document. They test the observation plumbing,
not product-DOM fidelity or private query-data acceptance. No environment skip is used:

```sh
swift test --package-path desktop/native/ModelPlanAppIntegration --filter G1RenderedSnapshotWindowTests
```
