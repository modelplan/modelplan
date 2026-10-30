<!-- SPDX-License-Identifier: MIT -->
# ModelPlanEngineStore (U6 interface only)

A native UI-state consumer of the merged ModelPlanEngineClient package. The store
delegates accepted-value storage to ModelPlanEngineStoreCore, applies its clear
effect on MainActor and fans out synchronous
snapshots. It does not implement transport, process supervision, session/epoch/
generation/sequence acceptance, row classification, or credential access.

EngineStoreConnection constructs the actual ProcessEngineClient with this store
as its consumer. Construction has no process effects. The existing app entry is
not switched in this stage: completion of U6 requires the normal app entry to
retain/start/stop this pair and use it for the Dock/menu/Settings surfaces after
U5 and the rest of the feature chain are ready. The old path is not deleted here.

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
- UI filtering/order/clock rendering and actual surfaces are later wiring;
  they may not reconstruct engine membership or introduce a second reducer.

Tests consume the repository's real Go-generated captures through WireDecoder.
They cover row identity fanout, acknowledgement ordering/private clear, feature
isolation, historical receipt separation and actual client construction. They
do not start a process or GUI and cannot earn normal-entry, package L2 or L3.

Run: `swift test --package-path desktop/native/ModelPlanEngineStore`.

Next: wire the normal app entry and U5 surfaces, exercise the reviewed real
app-server binary and versioned synthetic homes, then obtain the package-level
and real-input evidence. Interface acceptance never closes the owner issues.
