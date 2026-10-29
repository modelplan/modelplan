<!-- SPDX-License-Identifier: MIT -->
# Kimi Code reader card

- Vendor source: [Kimi CLI usage@9ab1286b](https://github.com/MoonshotAI/kimi-cli/blob/9ab1286b8fe4e6bcd116949a27ce5e0ac3389c82/src/kimi_cli/ui/shell/usage.py) and [Kimi CLI auth@9ab1286b](https://github.com/MoonshotAI/kimi-cli/blob/9ab1286b8fe4e6bcd116949a27ce5e0ac3389c82/src/kimi_cli/auth/oauth.py); source evidence, not a frozen endpoint guarantee.
- References compared: [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Kimi/KimiUsageFetcher.swift) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/kimi-code.md) (Apache-2.0).
- Reviewed ModelPlan artifact: `670fe9e7f9c2ac44ec64ac22e647b3baac73f11e`; [kimi.go](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi.go); [fixed HTTP pins](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/readers/request_set.go). Public-source review only, 2026-10-29.
- Scope: `kimi.account_usage.api_key` and `kimi.account_usage.saved_login` (separate grants). Local history and other access classes do not grant this account route.
- Status: card/evidence inventory, not a catalogue enablement or owner-shaped acceptance. This docs change enables no source and changes no consent/default.

## Data

Supported legacy usage/limit counters and explicit five-hour, seven-day, monthly and other duration/ratio windows. Preserve provided reset times, native counts and duration labels; do not invent request units, a model, MCP quota, cash balance or unlimited entitlement.

- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Kimi/KimiUsageFetcher.swift): Supports key, saved-login/device and optional web paths. Usage/schema and credential layout are compared; custom-host/web/session/refresh behaviors are not adopted.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/kimi-code.md): Uses a user-configured key for the China usages GET and its usage/limits fields. Its duration and concurrency notes do not justify guessing a window length or presenting parallelism as quota.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Selected plan key | H | K | Compatibility GET; vendor source exists, stability unguaranteed | One regional call | Chosen key scope |
| Saved China login | L → H | O | Same usage GET | Reads supported credential and existing device ID | Chosen independent login scope, beta |
| Saved international/foreign login | L → H | O | Issuing region not established | Could forward the wrong credential | Rejected before request |
| Browser/web token | S → H | C | Undocumented | Different credential class | Excluded |
| Moonshot balance/local token history | H / L | K / none | Different capability | Not subscription quota | Not an alternative for these scopes |

## Incidents and pitfalls

The reference links above are source-reported behavior/pitfalls, not new incidents observed with a real account by this card.
- A login file does not establish international issuing region; guessed host switching could expose a credential. → fixture [TestKimiLoginUnsupportedModesMakeNoRequests](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_login_test.go) (`TestKimiLoginUnsupportedModesMakeNoRequests`).
- Changed expired/unsupported credentials or a missing device ID must not inherit old quota. → fixture [TestKimiChangedInvalidBindingNeverInheritsQuota](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_review_test.go) (`TestKimiChangedInvalidBindingNeverInheritsQuota`).
- Other durations and overlapping monthly counters must not be mislabelled or added twice. → fixture [TestKimiOtherDurationRetainsLabel](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_login_test.go) (`TestKimiOtherDurationRetainsLabel`).

## Choice

- Chosen path and tier: Key route: H/K, standard key; explicitly configured ModelPlan keys keep enabled behavior, an environment-only key is offered unchecked. Login route: L→H/O, standard, not pre-selected; Automatic consent only. A blocked new login grant does not fall back to the legacy key route.
- Why: The fixed usage endpoint returns coding-plan windows. Separate scopes preserve the distinction between an explicitly supplied plan key and another tool’s saved login/device identity.
- Licence: Independent Go adapter. CodexBar MIT and Pulse Apache-2.0 are schema/behavior comparisons, with no code or upstream account fixture copied by this card.
- Rejected paths and their red lines are listed in Candidate paths. No W/web scraping, automatic source waterfall or catalogue-driven authority expansion is admitted.

### Fixed request set

| Stage | Method / carrier | Host / peer | Path / RPC | Header names only |
| --- | --- | --- | --- | --- |
| Key, China | GET | api.kimi.com | /coding/v1/usages | Accept, Authorization, User-Agent |
| Key, international | GET | api.kimi.ai | /coding/v1/usages | Accept, Authorization, User-Agent |
| Saved login, China only | GET | api.kimi.com | /coding/v1/usages | Accept, Authorization, User-Agent, X-Msh-Platform, X-Msh-Version, X-Msh-Device-Id, X-Msh-Device-Name, X-Msh-Device-Model, X-Msh-Os-Version |

All listed URLs use HTTPS. GET bodies are empty. URL queries are forbidden. Header **values are intentionally absent**. Transport-managed names such as `Host` and `Accept-Encoding` may be added below the application guard; ambient cookies, changed authorities/ports, unlisted application headers, extra stages and redirect following are refused.

### Authentication source and refresh

Key scope reads only KIMI_CODE_API_KEY or the selected environment-variable name. Saved-login scope reads the admitted KIMI_CODE_HOME (default ~/.kimi-code) credential file credentials/kimi-code.json and an already-existing device_id. Only supported access-token/expiry/subject information is used; the refresh token is not used. Saved login is China-only and rejects endpoint/OAuth-host overrides, unsupported login modes and missing device identity.

Refresh behavior: None by ModelPlan. It never launches Kimi, creates a device ID, imports a web token, renews a login or rewrites config/credentials. The user opens Kimi Code to renew an expired login. The vendor’s own token manager has refresh/write logic and is deliberately not imported.

### Budget and stop rules

Exactly one selected-region GET, no cross-region/source retry, with the native 20-second/1-MiB bounds. Key route uses 10-minute success/30-minute error cadence; login route uses a five-minute floor, adaptive 10/15/30 success cadence and 10/20/40/60 failures plus Retry-After. Both share provider/source gates; Forget/reconnect must preserve their union.

One guarded client is created for the whole logical read. HTTP 401/403 and every 3xx response terminate further calls through that transport; it is never recreated to retry a rejection. A failed/missing credential or unsupported shape never grants a new source. Expired/absent values stay unknown. The auth stop lasts for this read, so later backoff-based attempts are a known limit, not a claimed durable stop.

## Tests

Existing test references are pinned to the reviewed implementation, not new executions or live-account evidence from this docs task.

- Fixtures: [TestKimiResponseGenerations](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_test.go) (`TestKimiResponseGenerations`).
- Fixtures: [TestKimiOptInRegionsCacheAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_test.go) (`TestKimiOptInRegionsCacheAndPrivacy`).
- Fixtures: [TestKimiLoginChinaBudgetCacheAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_login_test.go) (`TestKimiLoginChinaBudgetCacheAndPrivacy`).
- Fixtures: [TestKimiLoginRefusesCredentialRedirect](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_login_test.go) (`TestKimiLoginRefusesCredentialRedirect`).
- Fixtures: [TestKimiForgetReconnectRestartRetainsUnionOfGates](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_review_test.go) (`TestKimiForgetReconnectRestartRetainsUnionOfGates`).
- Owner-shaped case: Separate local history/key/login grants; selected key environment and region; existing versus missing device ID; expired/JWT-shorter expiry; custom admitted root; login/key switches and old capture provenance; concurrent processes sharing the same gates.
- Required L2: use an isolated owner-shaped synthetic home with the real CLI/app-server, independent clients, recorded providers/processes and retained settings. Check consent, no credential bytes in any output/store, no off-list or excess calls, revoke/new-epoch late results, source provenance, budget retention and recovery. Runtime paths also require the exact executable/version and observable no-refresh/write/prompt evidence.
- Outcome here: documentation/link/request-pin audit only. Owner-shaped reader L2, native identity/UI, live vendors and final-package/L3 are **not-run** by this card-writing change.

### Red lines and evidence

| Red line | Enforcement / test evidence and its limit |
| --- | --- |
| No refresh or other-tool writes | [TestKimiLoginChinaBudgetCacheAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_login_test.go) (`TestKimiLoginChinaBudgetCacheAndPrivacy`) checks supported local-source behavior; it is not a whole-OS write trace. |
| No credential persistence/copy | [TestKimiLoginChinaBudgetCacheAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_login_test.go) (`TestKimiLoginChinaBudgetCacheAndPrivacy`) is a synthetic fixture, not a scan of every output writer. |
| No inference/paid or off-list calls | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) and [TestAccountUsageProductionTransportRejectsOffHost](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestAccountUsageProductionTransportRejectsOffHost`); off-list or extra calls never reach the recorder. |
| One vendor read per five minutes, shared | [TestKimiForgetReconnectRestartRetainsUnionOfGates](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_review_test.go) (`TestKimiForgetReconnectRestartRetainsUnionOfGates`) provides source/cadence coverage; independent concurrent CLI/plugin/app L2 on the same home is not certified by this card. |
| Stop after authorization rejection | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) stops all later calls in the same logical read. Later scheduler reads are not a proved durable auth latch. |
| Detection reads presence only | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) covers compiled presence signals; it does not prove every real-OS I/O path. |
| No browser detection scan | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) is partial evidence. No exhaustive browser-directory trap/native audit is claimed. |
| Only keyed identity storage | [TestNativeAndCodexBarSubscriptions](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/identity_test.go) (`TestNativeAndCodexBarSubscriptions`) plus [TestKimiLoginChinaBudgetCacheAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_login_test.go) (`TestKimiLoginChinaBudgetCacheAndPrivacy`) cover fixture bindings. A whole-writer audit is not-run. |
| Route and time on every value | [TestKimiLoginChinaBudgetCacheAndPrivacy](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/kimi_login_test.go) (`TestKimiLoginChinaBudgetCacheAndPrivacy`) and [TestNullableWireFieldsStayExplicit](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/rows/types_test.go) (`TestNullableWireFieldsStayExplicit`) cover fixture provenance and explicit unknown fields. Exhaustive route/time validation and native “time unknown” rendering are not certified by these fixtures. |
| Fixed destinations / no redirect | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) plus the compiled authority/stage pins. No jar or followed redirect. |
| Catalogue switch-off and revocation | [TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes`) and [TestProductionManagedAdmission](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionManagedAdmission`). Known violations cannot be enabled by catalogue data. |
| Keychain identity / interaction | Not used by this chosen path. No browser/Keychain fallback is granted by the account scope. |

## Known gaps and unknowns

- Saved international login remains unsupported; the key and China saved-login contracts must not be merged by convenience.
- The compared sources have different region/window assumptions and optional web paths. A source calling an endpoint documented is not a vendor stability or no-write guarantee; this card treats the exact route as compatibility.
- The native X-Msh client metadata is fixed ModelPlan metadata, not proof of an installed Kimi runtime version. Source/OS/device behavior and full owner-shaped L2 are not newly verified by these docs.
- Per-read HTTP auth-stop recording does not establish a persisted cross-read scope latch. Later scheduled reads remain possible after backoff; this is a standard-completion gap.
- Public source/reference behavior is not a guarantee of server-side no-write/no-charge effects. Catalogue enablement requires the card’s red lines and L2; creating this document supplies neither permission nor a pass.
