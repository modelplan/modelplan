<!-- SPDX-License-Identifier: MIT -->
# MiniMax reader card

- Vendor source: [MiniMax CLI endpoint definitions@38aba5f2](https://github.com/MiniMax-AI/cli/blob/38aba5f26173dd1065b115b221d79c9ddd87c6bb/src/client/endpoints.ts) and [vendor counter semantics@38aba5f2](https://github.com/MiniMax-AI/cli/blob/38aba5f26173dd1065b115b221d79c9ddd87c6bb/src/utils/quota.ts); the older product URL now redirects and is not endpoint stability proof.
- References compared: [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/MiniMax/MiniMaxUsageFetcher.swift) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/minimax.md) (Apache-2.0).
- Reviewed ModelPlan artifact: `670fe9e7f9c2ac44ec64ac22e647b3baac73f11e`; [minimax.go](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax.go); [fixed HTTP pins](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/readers/request_set.go). Public-source review only, 2026-10-29.
- Scope: `minimax.account_usage.api_key`. Local history and other access classes do not grant this account route.
- Status: card/evidence inventory, not a catalogue enablement or owner-shaped acceptance. This docs change enables no source and changes no consent/default.

## Data

model_remains current/weekly coding-plan meters, supported explicit remaining percentages or legacy remaining-count/total interpretation, reset timestamps and recognized model/general pools. Prefer the general shared pool over its aliases. No cash balance, inference entitlement, arbitrary vendor label or fake full tank is inferred.

- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/MiniMax/MiniMaxUsageFetcher.swift): Remains API with additional optional HTML/web/billing enrichment in the reference. Only the fixed remains paths/schema evidence are used here.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/minimax.md): Documents the same two regional remains paths and broad legacy retry even after auth failure. That retry violates this card’s HTTP 401/403 stop and is deliberately not adopted.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Selected plan key, current path | H | K | First-party route evidence; exact hosts/schema remain compatibility | One GET | Chosen |
| Same-host legacy compatibility | H | K | Undocumented GET | Second call only for the listed compatibility failures | Chosen bounded fallback, never after HTTP 401/403 |
| Other region, balance, web/HTML | H / S | K / C | Different capabilities | Credential forwarding, extra paths or browser/scraping | Excluded; W never used |

## Incidents and pitfalls

The reference links above are source-reported behavior/pitfalls, not new incidents observed with a real account by this card.
- Pulse’s broad failure fallback, including a current-path 401, is a named counterexample, not authority to continue. → fixture [TestMiniMaxFallbackBoundaries](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxFallbackBoundaries`).
- Vendor-body status_code and HTTP status are different. HTTP 200 plus recognized body 1004 may try legacy; HTTP 401/403 may not. → fixture [TestMiniMaxSchemasAndUnknowns](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxSchemasAndUnknowns`).
- Legacy usage_count can mean remaining; explicit remaining percent is authoritative and pools must not be added twice. → fixture [TestMiniMaxSchemasAndUnknowns](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxSchemasAndUnknowns`).
- Additional schema comparison: [Token Monitor@e1c393cc](https://github.com/Javis603/token-monitor/blob/e1c393cca85668aaf5e52798a291277e34999dca/src/shared/providers/minimax/limits.js) (MIT); its extra balance path is not part of this request set.

## Choice

- Chosen path and tier: H/K, standard key. A ModelPlan-configured key retains enabled behavior; mere environment presence is unchecked and cannot enable this reader. China and international are separate account/key selections.
- Why: The two-path fixed set covers the existing plan compatibility transition while ending immediately on HTTP auth rejection. There is no automatic region or account discovery.
- Licence: Original Go implementation using schema evidence from MIT CodexBar/Token Monitor and the vendor’s public source. No upstream code/fixtures or extra dependency is copied by this card. Pulse Apache-2.0 is a behavior comparison only.
- Rejected paths and their red lines are listed in Candidate paths. No W/web scraping, automatic source waterfall or catalogue-driven authority expansion is admitted.

### Fixed request set

| Stage | Method / carrier | Host / peer | Path / RPC | Header names only |
| --- | --- | --- | --- | --- |
| Current, international or China | GET | api.minimax.io or api.minimaxi.com (selected once) | /v1/token_plan/remains | Accept, Authorization, User-Agent |
| Optional same-host legacy | GET | The same selected authority | /v1/api/openplatform/coding_plan/remains | Accept, Authorization, User-Agent |

All listed URLs use HTTPS. GET bodies are empty. URL queries are forbidden. Header **values are intentionally absent**. Transport-managed names such as `Host` and `Accept-Encoding` may be added below the application guard; ambient cookies, changed authorities/ports, unlisted application headers, extra stages and redirect following are refused.

### Authentication source and refresh

Only MINIMAX_CODING_API_KEY or the explicitly selected environment-variable name. No tool credential file, OAuth/session token, browser, Keychain, device flow or copied key is used. Changing region, selected variable or key cannot reuse another successful binding.

Refresh behavior: None. Keys are never renewed, persisted or tested with inference/balance calls. A missing/rejected key leaves quota unknown and asks for the selected region’s plan key.

### Budget and stop rules

One current GET; at most one legacy GET on that same selected authority. Both share one 20-second deadline and 1-MiB response caps. Legacy is allowed only after current HTTP 404/405 or parsed vendor-body status_code 1004, never HTTP 401/403, rate-limit, transport/server failure or arbitrary malformed data. Native cadence is 10 minutes, with 30-minute failure wait and persisted dispatcher gates.

One guarded client is created for the whole logical read. HTTP 401/403 and every 3xx response terminate further calls through that transport; it is never recreated to retry a rejection. A failed/missing credential or unsupported shape never grants a new source. Expired/absent values stay unknown. The auth stop lasts for this read, so later backoff-based attempts are a known limit, not a claimed durable stop.

## Tests

Existing test references are pinned to the reviewed implementation, not new executions or live-account evidence from this docs task.

- Fixtures: [TestMiniMaxConsentRegionsBindingAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxConsentRegionsBindingAndPrivacy`).
- Fixtures: [TestMiniMaxFallbackBoundaries](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxFallbackBoundaries`).
- Fixtures: [TestMiniMaxNativeCacheResetAndErrorBackoff](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxNativeCacheResetAndErrorBackoff`).
- Fixtures: [TestMiniMaxIdentityOffDoesNotReuseQuotaOrDefeatThrottle](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxIdentityOffDoesNotReuseQuotaOrDefeatThrottle`).
- Owner-shaped case: International/China selection with separate keys; both HTTP auth codes with an available scripted legacy success; 404/405/body-1004 compatibility; rate-limit/malformed/oversized responses; old-key/region binding, identity off and concurrent shared-home callers.
- Required L2: use an isolated owner-shaped synthetic home with the real CLI/app-server, independent clients, recorded providers/processes and retained settings. Check consent, no credential bytes in any output/store, no off-list or excess calls, revoke/new-epoch late results, source provenance, budget retention and recovery. Runtime paths also require the exact executable/version and observable no-refresh/write/prompt evidence.
- Outcome here: documentation/link/request-pin audit only. Owner-shaped reader L2, native identity/UI, live vendors and final-package/L3 are **not-run** by this card-writing change.

### Red lines and evidence

| Red line | Enforcement / test evidence and its limit |
| --- | --- |
| No refresh or other-tool writes | [TestMiniMaxConsentRegionsBindingAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxConsentRegionsBindingAndPrivacy`) checks supported local-source behavior; it is not a whole-OS write trace. |
| No credential persistence/copy | [TestMiniMaxConsentRegionsBindingAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxConsentRegionsBindingAndPrivacy`) is a synthetic fixture, not a scan of every output writer. |
| No inference/paid or off-list calls | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) and [TestAccountUsageProductionTransportRejectsOffHost](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestAccountUsageProductionTransportRejectsOffHost`); off-list or extra calls never reach the recorder. |
| One vendor read per five minutes, shared | [TestDoctorReadersLegacyCachedIntervalAndBackoff](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/readerattempt_dispatch_test.go) (`TestDoctorReadersLegacyCachedIntervalAndBackoff`) provides source/cadence coverage; independent concurrent CLI/plugin/app L2 on the same home is not certified by this card. |
| Stop after authorization rejection | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) stops all later calls in the same logical read. Later scheduler reads are not a proved durable auth latch. |
| Detection reads presence only | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) covers compiled presence signals; it does not prove every real-OS I/O path. |
| No browser detection scan | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) is partial evidence. No exhaustive browser-directory trap/native audit is claimed. |
| Only keyed identity storage | [TestNativeAndCodexBarSubscriptions](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/identity_test.go) (`TestNativeAndCodexBarSubscriptions`) plus [TestMiniMaxConsentRegionsBindingAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxConsentRegionsBindingAndPrivacy`) cover fixture bindings. A whole-writer audit is not-run. |
| Route and time on every value | [TestMiniMaxConsentRegionsBindingAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/minimax_test.go) (`TestMiniMaxConsentRegionsBindingAndPrivacy`) and [TestNullableWireFieldsStayExplicit](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/rows/types_test.go) (`TestNullableWireFieldsStayExplicit`) cover fixture provenance and explicit unknown fields. Exhaustive route/time validation and native “time unknown” rendering are not certified by these fixtures. |
| Fixed destinations / no redirect | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) plus the compiled authority/stage pins. No jar or followed redirect. |
| Catalogue switch-off and revocation | [TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes`) and [TestProductionLegacyAdmission](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionLegacyAdmission`). Known violations cannot be enabled by catalogue data. |
| Keychain identity / interaction | Not used by this chosen path. No browser/Keychain fallback is granted by the account scope. |

## Known gaps and unknowns

- The compiled API subdomains/response and legacy route are compatibility interfaces, not a guarantee made by the vendor’s product page. Current first-party endpoint helpers accept broader base configuration; ModelPlan deliberately accepts only its two compiled authorities.
- No live account request was made for this card. The source/recording seam proves the fixed outbound set, not a server-side no-write/no-charge guarantee.
- The standard’s cross-read auth-stop requirement is stronger than the transport’s per-logical-read stop. A durable scope latch after HTTP 401/403 is not established here; later eligible scheduler attempts remain possible.
- Public source/reference behavior is not a guarantee of server-side no-write/no-charge effects. Catalogue enablement requires the card’s red lines and L2; creating this document supplies neither permission nor a pass.
