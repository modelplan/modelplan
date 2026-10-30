<!-- SPDX-License-Identifier: MIT -->
# U6 Dock and menu content seam

`DockContentProvider` is the temporary native U6 protocol pending the containing host's injection seam. It exposes `dockContent: DockContentSnapshot` and `dockContentDidChange: (() -> Void)?`. The host reads the content when notified. The integration owner replaces this declaration with the shared protocol when that seam lands; this document makes no normal-entry wiring claim.

`EngineDockMenuProvider(store:)` attaches one weak sink to the existing native EngineStore. It forwards generated rows to the surfaces declared by the engine and preserves row payloads. No grouping, tool membership, consent, protocol admission, expiry reclassification, process or legacy CLI reader is introduced here. The host must retain and render the generated reason/next-step/currentness data, not treat a nonempty array as a successful reading.

States are loading, ready, empty, failed and cleared. A rows feature failure or stopped/restarting connection supplies failed presentation; independent history failures do not replace rows. Empty accepted projections retain the engine summary. Clearing synchronously withdraws all derived row/summary content and notifies before native consumption returns. A subsequent connection-starting event presents loading. These are UI states only; the client owns protocol decisions.

Validation: the actual ModelPlanEngineStore package's DockContentProviderTests use the existing Go capture and the real native consume/clear path. Normal entry, host rendering, refresh command binding, final package and physical input remain unverified. The existing legacy path is retained until the replacement is wired and its fence/package/regressions pass.
