<!-- SPDX-License-Identifier: MIT -->
# Grok Build reader card

- Vendor source: [Grok Build billing source@2bdd1d6a](https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-shell/src/extensions/billing.rs) (Apache-2.0; source contract, not a public stable quota API).
- References compared: [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Grok/GrokStatusProbe.swift) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/grok.md) (Apache-2.0).
- Reviewed ModelPlan artifact: `670fe9e7f9c2ac44ec64ac22e647b3baac73f11e`; [grok.go](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok.go); [fixed HTTP pins](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/readers/request_set.go). Public-source review only, 2026-10-29.
- Scope: `grok.account_usage.saved_login`. Local history and other access classes do not grant this account route.
- Status: card/evidence inventory, not a catalogue enablement or owner-shaped acceptance. This docs change enables no source and changes no consent/default.

## Data

Included creditUsagePercent and explicit current-period bounds/type; legacy monthly USD-cent budget meters stay separate. Supported prepaid balance and on-demand spend/cap remain separate monetary fields. Empty versus absent Cent objects retain the evidenced proto distinction. Shared-pool eligibility does not verify a shared Cursor/Grok seat.

- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Grok/GrokStatusProbe.swift): CLI/web billing source families with optional fallback/enrichment. Only the fixed first-party billing source/field meanings are compared; browser/web fallback is excluded.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/grok.md): Borrowed OIDC billing GET plus a settings GET for plan names. ModelPlan omits that enrichment request and does not infer plan membership from a name or matching reset.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Selected first-party saved session | L → H | O | Undocumented GET, first-party source evidence | One billing call | Chosen, beta |
| AuthManager or runtime launch | R / helper | runtime / O | Broader capability | May refresh, chmod or repair credentials | Not selected |
| API key/deployment/foreign issuer | H | K / other | Not the supported subscription login | Wrong account/authority risk | Rejected before I/O |
| Browser/web fallback/settings enrichment | S → H | C / O | Different endpoints | Different auth or extra calls | Excluded |
| Local sessions | L | none | Local | Token history | Independent scope; not quota |

## Incidents and pitfalls

The reference links above are source-reported behavior/pitfalls, not new incidents observed with a real account by this card.
- The wrong auth/header surface can return legacy enterprise monthly zeroes rather than an included unified pool. Do not guess membership from a matching reset. → fixture [TestGrokLegacyCentsAndMissingUnifiedEvidence](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokLegacyCentsAndMissingUnifiedEvidence`).
- Explicit auth tables must not borrow a foreign or mismatched base; changed invalid sessions must not inherit the old account. → fixture [TestGrokOIDCTablesRequireMatchingBase](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_review_test.go) (`TestGrokOIDCTablesRequireMatchingBase`).
- A wallet-only response needs no invented quota percentage. → fixture [TestGrokSingleReadIncludedWalletAndReadOnlyCredential](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokSingleReadIncludedWalletAndReadOnlyCredential`).

## Choice

- Chosen path and tier: L→H/O, standard, not pre-selected; Automatic saved-login consent required. No browser class C permission is implied by a saved session. Local history remains independent.
- Why: The selected issuer/client-bound saved session can report included quota and a separate wallet with one fixed first-party-source GET, without running Grok’s auth manager.
- Licence: Independently implemented from Apache-2.0 Grok Build source; no first-party code or account fixture is copied. CodexBar MIT and Pulse Apache-2.0 are comparisons only. Existing go-toml dependency notices are unchanged.
- Rejected paths and their red lines are listed in Candidate paths. No W/web scraping, automatic source waterfall or catalogue-driven authority expansion is admitted.

### Fixed request set

| Stage | Method / carrier | Host / peer | Path / RPC | Header names only |
| --- | --- | --- | --- | --- |
| Only request | GET | cli-chat-proxy.grok.com | /v1/billing?format=credits | Accept, Authorization, User-Agent, X-XAI-Token-Auth, X-Userid, X-Grok-Client-Version, X-Grok-Client-Mode |

All listed URLs use HTTPS. GET bodies are empty. The only query is the literal `format=credits`. Header **values are intentionally absent**. Transport-managed names such as `Host` and `Accept-Encoding` may be added below the application guard; ambient cookies, changed authorities/ports, unlisted application headers, extra stages and redirect following are refused.

### Authentication source and refresh

Only the supported selected first-party OIDC/external entry in ~/.grok/auth.json (or locally admitted GROK_HOME/absolute GROK_AUTH_PATH), with strict issuer/client and optional principal/team matching. config.toml and explicit selectors select the same supported auth base. Earlier stored/JWT expiry wins with a one-minute margin. Unknown lifetime, foreign issuer, API-key-preferred, BYOK, helper/deployment and ambiguous selectors are unavailable before HTTP.

Refresh behavior: None. ModelPlan does not import AuthManager, launch Grok, refresh/chmod/repair credentials, use browser/Keychain data or execute auth-provider commands. Expired or unknown lifetime asks the user to open Grok Build.

### Budget and stop rules

One billing GET, native 20-second/1-MiB bounds. Managed five-minute provider floor, adaptive 10/15/30 success cadence and 10/20/40/60 failure backoff plus Retry-After. The conservative Cursor/Grok floor is an additional non-additive constraint; both attempt gates survive personal-data purge.

One guarded client is created for the whole logical read. HTTP 401/403 and every 3xx response terminate further calls through that transport; it is never recreated to retry a rejection. A failed/missing credential or unsupported shape never grants a new source. Expired/absent values stay unknown. The auth stop lasts for this read, so later backoff-based attempts are a known limit, not a claimed durable stop.

## Tests

Existing test references are pinned to the reviewed implementation, not new executions or live-account evidence from this docs task.

- Fixtures: [TestGrokUnsupportedAuthUsesNoRequests](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokUnsupportedAuthUsesNoRequests`).
- Fixtures: [TestGrokJWTExpiryAndSharedBudget](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokJWTExpiryAndSharedBudget`).
- Fixtures: [TestGrokFailuresKeepLastCaptureAndBackoff](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokFailuresKeepLastCaptureAndBackoff`).
- Fixtures: [TestGrokChangedInvalidSessionNeverInheritsAccount](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_review_test.go) (`TestGrokChangedInvalidSessionNeverInheritsAccount`).
- Owner-shaped case: Selected OIDC/external session and literal local roots; expiry/JWT precedence; foreign issuer and malformed TOML; principal/team/type mismatch; legacy cents versus included pool/wallet; shared Cursor/Grok budget; changed session, revoke and reset.
- Required L2: use an isolated owner-shaped synthetic home with the real CLI/app-server, independent clients, recorded providers/processes and retained settings. Check consent, no credential bytes in any output/store, no off-list or excess calls, revoke/new-epoch late results, source provenance, budget retention and recovery. Runtime paths also require the exact executable/version and observable no-refresh/write/prompt evidence.
- Outcome here: documentation/link/request-pin audit only. Owner-shaped reader L2, native identity/UI, live vendors and final-package/L3 are **not-run** by this card-writing change.

### Red lines and evidence

| Red line | Enforcement / test evidence and its limit |
| --- | --- |
| No refresh or other-tool writes | [TestGrokSingleReadIncludedWalletAndReadOnlyCredential](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokSingleReadIncludedWalletAndReadOnlyCredential`) checks supported local-source behavior; it is not a whole-OS write trace. |
| No credential persistence/copy | [TestGrokSingleReadIncludedWalletAndReadOnlyCredential](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokSingleReadIncludedWalletAndReadOnlyCredential`) is a synthetic fixture, not a scan of every output writer. |
| No inference/paid or off-list calls | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) and [TestAccountUsageProductionTransportRejectsOffHost](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestAccountUsageProductionTransportRejectsOffHost`); off-list or extra calls never reach the recorder. |
| One vendor read per five minutes, shared | [TestGrokJWTExpiryAndSharedBudget](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokJWTExpiryAndSharedBudget`) provides source/cadence coverage; independent concurrent CLI/plugin/app L2 on the same home is not certified by this card. |
| Stop after authorization rejection | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) stops all later calls in the same logical read. Later scheduler reads are not a proved durable auth latch. |
| Detection reads presence only | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) covers compiled presence signals; it does not prove every real-OS I/O path. |
| No browser detection scan | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) is partial evidence. No exhaustive browser-directory trap/native audit is claimed. |
| Only keyed identity storage | [TestNativeAndCodexBarSubscriptions](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/identity_test.go) (`TestNativeAndCodexBarSubscriptions`) plus [TestGrokSingleReadIncludedWalletAndReadOnlyCredential](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokSingleReadIncludedWalletAndReadOnlyCredential`) cover fixture bindings. A whole-writer audit is not-run. |
| Route and time on every value | [TestGrokSingleReadIncludedWalletAndReadOnlyCredential](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/grok_test.go) (`TestGrokSingleReadIncludedWalletAndReadOnlyCredential`) and [TestNullableWireFieldsStayExplicit](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/rows/types_test.go) (`TestNullableWireFieldsStayExplicit`) cover fixture provenance and explicit unknown fields. Exhaustive route/time validation and native “time unknown” rendering are not certified by these fixtures. |
| Fixed destinations / no redirect | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) plus the compiled authority/stage pins. No jar or followed redirect. |
| Catalogue switch-off and revocation | [TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes`) and [TestProductionManagedAdmission](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionManagedAdmission`). Known violations cannot be enabled by catalogue data. |
| Keychain identity / interaction | Not used by this chosen path. No browser/Keychain fallback is granted by the account scope. |

## Known gaps and unknowns

- Grok/Cursor shared-pool linkage remains unverified and non-additive; no seat alias is inferred from local IDs, email, reset coincidence or percentages.
- Reference projects differ on balance units and quota semantics. This pin follows the cited first-party USD-cent/proto contract, not every future/reference payload.
- The endpoint, client metadata and response are compatibility interfaces. Fixed ModelPlan metadata is not an installed Grok-version claim; live/vendor/owner-shaped and native acceptance are not newly proven.
- Per-read HTTP auth-stop recording does not establish a persisted cross-read scope latch. Later scheduled reads remain possible after backoff; this is a standard-completion gap.
- Public source/reference behavior is not a guarantee of server-side no-write/no-charge effects. Catalogue enablement requires the card’s red lines and L2; creating this document supplies neither permission nor a pass.
