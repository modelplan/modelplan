<!-- SPDX-License-Identifier: MIT -->
# U6 Dock and menu content seam

The shared `DockContentProvider.makeContent(DockContentContext)` seam lives in ModelPlanAppIntegration. The portable-facing native store package exposes only `EngineDockMenuProvider.dockContent` and `dockContentDidChange`; `EngineDockContentProvider` adapts it to the host without a reverse package dependency. The original temporary protocol is removed.

The normal executable calls EngineRowsEntry.make → EngineDockMenuApplication → EngineDockMenuComposition. That composition attaches the accepted-row provider, installs the host adapter, retains one EngineClient, and drives Dock and status-menu updates from the same events. Refresh uses EngineClient.refresh. Legacy probe/smoke routes are explicitly separate; normal Dock/menu readings do not use the legacy CLI transport.

`EngineDockMenuProvider(store:)` attaches one weak sink to the existing native EngineStore. It forwards generated rows to the surfaces declared by the engine and preserves row payloads. No grouping, tool membership, consent, protocol admission, expiry reclassification, process or legacy CLI reader is introduced here. The host must retain and render the generated reason/next-step/currentness data, not treat a nonempty array as a successful reading.

States are loading, ready, empty, failed and cleared. A rows feature failure or stopped/restarting connection supplies failed presentation; independent history failures do not replace rows. Empty accepted projections retain the engine summary. Clearing synchronously withdraws all derived row/summary content and notifies before native consumption returns. A subsequent connection-starting event presents loading. These are UI states only; the client owns protocol decisions.

Validation: the actual ModelPlanEngineStore package's DockContentProviderTests use the existing Go capture and the real native consume/clear path. Normal-entry factory/actual no-window host/menu and synchronous clearing have two additional synthetic integration checks. Final package, physical input/Drive and owner-shaped acceptance remain unverified; Settings/cockpit integration is a separate completion input. The existing legacy path is retained until the replacement is wired and its fence/package/regressions pass.
