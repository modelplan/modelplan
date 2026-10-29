<!-- SPDX-License-Identifier: MIT -->
# OpenCode Go reader card

- Vendor source: [Official OpenCode Go documentation](https://opencode.ai/v2/docs/console/go/) (checked 2026-10-29; product/key context, not a documented usage-endpoint stability contract).
- References compared: [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/OpenCodeGo/OpenCodeGoUsageFetcher.swift) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/opencode-go.md) (Apache-2.0).
- Reviewed ModelPlan artifact: `670fe9e7f9c2ac44ec64ac22e647b3baac73f11e`; [opencodego.go](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/opencodego.go); [fixed HTTP pins](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/readers/request_set.go). Public-source review only, 2026-10-29.
- Scope: `opencodego.account_usage.api_key`. Local history and other access classes do not grant this account route.
- Status: card/evidence inventory, not a catalogue enablement or owner-shaped acceptance. This docs change enables no source and changes no consent/default.

## Data

The usage object’s required rolling five-hour meter and supported weekly/monthly meters: supplied percentages or used/limit counters and relative/absolute reset fields. Unknown optional monthly values are omitted; no prepaid balance, spend, request allowance or total is inferred.

- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/OpenCodeGo/OpenCodeGoUsageFetcher.swift): Key-auth usage API plus optional console/browser/billing enrichment. The existing ModelPlan port selects the API usage subset, not the larger source waterfall.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/opencode-go.md): Key-auth usage and optional console-cookie workspace/history routes. ModelPlan does not import OpenCode’s auth store or browser session and does not fetch request logs.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Explicit ModelPlan key | H | K | Undocumented compatibility usage GET | One request | Chosen |
| Borrow OpenCode auth store | L → H | K / other saved auth | Different source capability | Reads another tool’s credential store | Not selected |
| Console session/billing/history | S → H | C | Undocumented console paths | Browser/session and multi-request capability | Excluded |
| Local OpenCode history | S | none | Local | Token history only | Separate capability; not account quota |

## Incidents and pitfalls

The reference links above are source-reported behavior/pitfalls, not new incidents observed with a real account by this card.
- A rolling meter is the supported five-hour slot; a bad present weekly meter must not silently become a healthy partial reading. → fixture [TestParseOpenCodeGo](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestParseOpenCodeGo`).
- Reference console/browser enrichment would change both credential class and fixed request budget. → fixture [TestAccountUsageProductionTransportRejectsOffHost](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestAccountUsageProductionTransportRejectsOffHost`).
- A refused request must not copy its body or follow an inference/console redirect. → fixture [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`).

## Choice

- Chosen path and tier: H/K, standard key. Explicit ModelPlan configuration keeps enabled behavior; an OPENCODE_API_KEY merely present in the environment is offered unchecked and does not itself enable a reader.
- Why: The one pinned key request reports the plan’s rolling windows without web scraping, browser auth or a console session.
- Licence: Existing opencodego.go attributes the earlier MIT CodexBar fetch/parse port at [8de11fff](https://github.com/steipete/CodexBar/commit/8de11fffdf1a5db45f4d26197f947e2b4a37b6a7). This card changes no code/notice/license; CodexBar MIT and Pulse Apache-2.0 comparisons do not license adopting their broader capabilities.
- Rejected paths and their red lines are listed in Candidate paths. No W/web scraping, automatic source waterfall or catalogue-driven authority expansion is admitted.

### Fixed request set

| Stage | Method / carrier | Host / peer | Path / RPC | Header names only |
| --- | --- | --- | --- | --- |
| Only request | GET | opencode.ai | /zen/go/v1/usage | Accept, Authorization, User-Agent |

All listed URLs use HTTPS. GET bodies are empty. URL queries are forbidden. Header **values are intentionally absent**. Transport-managed names such as `Host` and `Accept-Encoding` may be added below the application guard; ambient cookies, changed authorities/ports, unlisted application headers, extra stages and redirect following are refused.

### Authentication source and refresh

Only OPENCODE_API_KEY or the ModelPlan-selected environment variable, after explicit key-source consent. No OpenCode auth.json, browser cookie, device flow, workspace-header search or another provider’s key is read.

Refresh behavior: None. The key is not renewed or persisted, no browser sign-in is started and no inference/billing/history request is used to test it.

### Budget and stop rules

One GET, no region/source/endpoint fallback. Native 20-second/1-MiB bounds, 10-minute cadence and 30-minute failure wait apply with shared native lock and persisted dispatcher gates. Missing key returns unknown without I/O.

One guarded client is created for the whole logical read. HTTP 401/403 and every 3xx response terminate further calls through that transport; it is never recreated to retry a rejection. A failed/missing credential or unsupported shape never grants a new source. Expired/absent values stay unknown. The auth stop lasts for this read, so later backoff-based attempts are a known limit, not a claimed durable stop.

## Tests

Existing test references are pinned to the reviewed implementation, not new executions or live-account evidence from this docs task.

- Fixtures: [TestParseOpenCodeGo](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestParseOpenCodeGo`).
- Fixtures: [TestNativeOpenCodeGoRefresh](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestNativeOpenCodeGoRefresh`).
- Fixtures: [TestDoctorReadersLegacyCachedIntervalAndBackoff](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/readerattempt_dispatch_test.go) (`TestDoctorReadersLegacyCachedIntervalAndBackoff`).
- Owner-shaped case: Explicit connection and key variable; missing/wrong key; rolling-only, bad weekly and unknown monthly shapes; off/passive behavior under key policy; redirects; personal-data purge and shared-home concurrent callers.
- Required L2: use an isolated owner-shaped synthetic home with the real CLI/app-server, independent clients, recorded providers/processes and retained settings. Check consent, no credential bytes in any output/store, no off-list or excess calls, revoke/new-epoch late results, source provenance, budget retention and recovery. Runtime paths also require the exact executable/version and observable no-refresh/write/prompt evidence.
- Outcome here: documentation/link/request-pin audit only. Owner-shaped reader L2, native identity/UI, live vendors and final-package/L3 are **not-run** by this card-writing change.

### Red lines and evidence

| Red line | Enforcement / test evidence and its limit |
| --- | --- |
| No refresh or other-tool writes | [TestNativeOpenCodeGoRefresh](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestNativeOpenCodeGoRefresh`) checks supported local-source behavior; it is not a whole-OS write trace. |
| No credential persistence/copy | [TestNativeOpenCodeGoRefresh](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestNativeOpenCodeGoRefresh`) is a synthetic fixture, not a scan of every output writer. |
| No inference/paid or off-list calls | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) and [TestAccountUsageProductionTransportRejectsOffHost](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestAccountUsageProductionTransportRejectsOffHost`); off-list or extra calls never reach the recorder. |
| One vendor read per five minutes, shared | [TestDoctorReadersLegacyBudgetSharedWithSessionSweeps](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/readerattempt_dispatch_test.go) (`TestDoctorReadersLegacyBudgetSharedWithSessionSweeps`) provides source/cadence coverage; independent concurrent CLI/plugin/app L2 on the same home is not certified by this card. |
| Stop after authorization rejection | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) stops all later calls in the same logical read. Later scheduler reads are not a proved durable auth latch. |
| Detection reads presence only | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) covers compiled presence signals; it does not prove every real-OS I/O path. |
| No browser detection scan | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) is partial evidence. No exhaustive browser-directory trap/native audit is claimed. |
| Only keyed identity storage | [TestNativeAndCodexBarSubscriptions](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/identity_test.go) (`TestNativeAndCodexBarSubscriptions`) plus [TestNativeOpenCodeGoRefresh](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestNativeOpenCodeGoRefresh`) cover fixture bindings. A whole-writer audit is not-run. |
| Route and time on every value | [TestNativeOpenCodeGoRefresh](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestNativeOpenCodeGoRefresh`) and [TestNullableWireFieldsStayExplicit](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/rows/types_test.go) (`TestNullableWireFieldsStayExplicit`) cover fixture provenance and explicit unknown fields. Exhaustive route/time validation and native “time unknown” rendering are not certified by these fixtures. |
| Fixed destinations / no redirect | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) plus the compiled authority/stage pins. No jar or followed redirect. |
| Catalogue switch-off and revocation | [TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes`) and [TestProductionLegacyAdmission](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionLegacyAdmission`). Known violations cannot be enabled by catalogue data. |
| Keychain identity / interaction | Not used by this chosen path. No browser/Keychain fallback is granted by the account scope. |

## Known gaps and unknowns

- The official product page does not document /zen/go/v1/usage as a stable API. Current reference console migrations do not authorize a new endpoint or browser fallback.
- Native source flags and successful synthetic parsing do not establish live entitlement, vendor-side no-write effects or owner-shaped L2.
- The parser supports a bounded compatibility family of aliases; an unrecognized server shape stays unavailable rather than enabling broader probing.
- Per-read HTTP auth-stop recording does not establish a persisted cross-read scope latch. Later scheduled reads remain possible after backoff; this is a standard-completion gap.
- Public source/reference behavior is not a guarantee of server-side no-write/no-charge effects. Catalogue enablement requires the card’s red lines and L2; creating this document supplies neither permission nor a pass.
