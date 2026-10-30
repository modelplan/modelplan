<!-- SPDX-License-Identifier: MIT -->
# ModelPlanEngineStore (U6 wired source)

A native UI-state consumer of the merged ModelPlanEngineClient package. The store
delegates accepted-value storage to ModelPlanEngineStoreCore, applies its clear
effect on MainActor and fans out synchronous
snapshots. It does not implement transport, process supervision, session/epoch/
generation/sequence acceptance, row classification, or credential access.

EngineStoreConnection constructs the actual ProcessEngineClient with this store
as its consumer. Construction has no process effects. The normal community entry
now retains the pair through EngineRowsEntry and EngineDockMenuComposition,
starts/subscribes the client and drives Dock/status-menu content from accepted
rows. Explicit legacy probe/smoke routes remain separate. This is wired source,
not final-package, physical-input or owner acceptance.

## Consumer contract

- Exact response IDs are retained as correlation metadata. History query selection
  and surface-specific request routing are not wired in this interface stage.
- Private values arrive only in consume; request completion is not a second
  publication/authorization channel.
- clearPrivateViews resets retained private store values before synchronously
  clearing every attached sink/cache and applying the empty snapshot. The async
  consumer returns only after those callbacks; it never awaits another RPC.
- Sinks own any derived/private presentation and clear it in that callback.
  They must not schedule an old snapshot for publication after the callback.
- A history failure records a feature error without replacing valid rows.
  A historical grant receipt is transaction metadata, not current consent.
- Publication, plugin-install and cockpit use the generated WirePublicationResult,
  WirePluginInstallResult and WireCockpitData from the merged portable Core.
  The native wrapper adds no result schema or competing reducer.
- Configuration is explicit and passed directly to the real client. There is
  no new environment whitelist: its generated Go-owned WireChildEnvironment
  contract remains authoritative.
- The native host adapter owns presentation only; menu preference parity and
  broader Settings/cockpit integration remain follow-up work. It must never
  reconstruct engine membership or add another protocol reducer.
- Tracked menu objects and their retained item titles/attributed titles/tooltips
  are scrubbed synchronously before clear acknowledgement. Merely replacing a
  menu for the next opening is insufficient.

Tests consume the repository's real Go-generated captures through WireDecoder.
They cover row identity fanout, acknowledgement ordering/private clear, feature
isolation, historical receipt separation and actual client construction. They
do not start a process or GUI and cannot earn normal-entry, package L2 or L3.

Run: `swift test --package-path desktop/native/ModelPlanEngineStore`.

The integration tests additionally use the normal entry factory and actual
no-window Dock/status menu objects. Tracking is simulated through AppKit menu
notifications; retained old menus/items are checked inside the clear callback,
while an unrelated menu remains unchanged. Physical tracking still needs Drive.

Next: exercise a matched real app-server candidate with the versioned synthetic
profile, including clear while menus are tracked, then obtain package-level and
real-input evidence. Source checks never close owner issues.
