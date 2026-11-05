<!-- SPDX-License-Identifier: MIT -->
# Z.ai / GLM Coding Plan reader card

- Vendor source: [Official GLM Coding Plan overview](https://docs.z.ai/devpack/overview) (checked 2026-10-29; product context). The monitor quota endpoint is now first-party documented in the official [zai-org/ZCode](https://github.com/zai-org/ZCode) repository @ `a9fe401e` (Apache-2.0; checked 2026-11-05): [coding-plan-quota-remaining-api.md](https://github.com/zai-org/ZCode/blob/a9fe401e/docs/coding-plan-quota-remaining-api.md) (GET `/api/monitor/usage/quota/limit`, header `authorization: <API Key>`, "do not add a `Bearer` prefix"; Coding Plan key, not an ordinary model key) and [bigmodel-coding-plan-usage-quota.md](https://github.com/zai-org/ZCode/blob/a9fe401e/docs/bigmodel-coding-plan-usage-quota.md) (hosts `api.z.ai` and `bigmodel.cn`/`open.bigmodel.cn`, "the same key works on both hosts"; provider order `builtin:zai`, `builtin:bigmodel`, then custom providers on those hosts). ZCode Desktop 3.17.2 calls this endpoint for its own "Plan usage" panel. Exact compatibility request is pinned in the public reader.
- References compared: [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Resources/Plugins/zai.js) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/zai.md) (Apache-2.0).
- Reviewed ModelPlan artifact: `670fe9e7f9c2ac44ec64ac22e647b3baac73f11e`; [zai.go](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zai.go); [fixed HTTP pins](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/readers/request_set.go). Public-source review only, 2026-10-29.
- Scope: `zai.account_usage.api_key`. Local history and other access classes do not grant this account route.
- Status: card/evidence inventory, not a catalogue enablement or owner-shaped acceptance. This docs change enables no source and changes no consent/default. The 2026-11-05 update records first-party endpoint documentation, ZCode storage file names and an open authorization-header question: facts only, no behaviour change.

## Data

Personal coding-plan TOKENS_LIMIT/CREDIT_LIMIT/TIME_LIMIT meters, native counts or percentages, supported unit/number duration and reset time, plan-shaped labels and the explicit MCP marker. The first-party ZCode docs confirm this card's window mapping (`TOKENS_LIMIT` unit 3 number 5 = 5-hour, unit 6 = weekly; `TIME_LIMIT` unit 5 number 1 = monthly MCP; `percentage` = percent used), matching `zai.go` parsing. No team/project enumeration, BigModel cash balance, model charts or local-token-to-quota inference.

- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Resources/Plugins/zai.js): Key-auth quota plugin supports additional model-usage/balance endpoints, scope selectors and endpoint overrides. ModelPlan retains one fixed personal quota GET only.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/zai.md): Compares the same regional quota family and optional model-usage history. Reference-reported invalid/expired subscription responses and CREDIT_LIMIT semantics motivate explicit schema/error handling; no inference probe or historical account data is adopted.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| ModelPlan-selected environment key | H | K | Monitor GET documented in the official ZCode docs (compatibility; no vendor stability guarantee) | One fixed personal-quota request | Chosen |
| Explicit Claude Code settings profile | L → H | K | Same fixed monitor GET | Read one selected regular config and validate Coding Plan provenance | Chosen only when explicitly admitted |
| Selected OpenCode provider/auth slot | L → H | K | Parser exists for same GET | Requires an active-provider selector | Not production-admitted at this pin |
| Team/balance/model charts/custom host | H | K | Different endpoints/parameters | Extra calls or unintended key destination | Excluded |

## Incidents and pitfalls

The reference links above are source-reported behavior/pitfalls, not new incidents observed with a real account by this card.
- A Coding Plan key is not an Open Platform cash balance; optional chart/balance routes in references are not in the chosen capability. → fixture [TestParseZai](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestParseZai`).
- The selected config source must retain captured credential/region provenance across a setting switch. → fixture [TestZaiConfigCapturedGenerationSurvivesRegionSwitch](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigCapturedGenerationSurvivesRegionSwitch`).
- An OpenCode model name or arbitrary saved auth slot does not prove active-provider selection. → fixture [TestZaiConfigOpenCodeSelectedOnly](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigOpenCodeSelectedOnly`).

## Choice

- Chosen path and tier: H/K, standard key. A key explicitly configured for ModelPlan keeps its enabled behavior; mere environment/config presence does not grant access. Selecting another tool’s API-key configuration is an explicit key-source decision, not saved-login O permission.
- Why: A single regional personal-plan read supplies the required windows while keeping the key on a compiled official authority. The selected config path is provenance-checked rather than harvested.
- Licence: Existing zai.go explicitly attributes an earlier MIT CodexBar port ([8de11fff](https://github.com/steipete/CodexBar/commit/8de11fffdf1a5db45f4d26197f947e2b4a37b6a7)); this card adds no port or license change. CodexBar MIT and Pulse Apache-2.0 are compared at the full pins above. Existing grants/notices remain in place.
- Rejected paths and their red lines are listed in Candidate paths. No W/web scraping, automatic source waterfall or catalogue-driven authority expansion is admitted.

### Fixed request set

| Stage | Method / carrier | Host / peer | Path / RPC | Header names only |
| --- | --- | --- | --- | --- |
| Global | GET | api.z.ai | /api/monitor/usage/quota/limit | Accept, Authorization, User-Agent |
| Mainland China | GET | open.bigmodel.cn | /api/monitor/usage/quota/limit | Accept, Authorization, User-Agent |

All listed URLs use HTTPS. GET bodies are empty. URL queries are forbidden. Header **values are intentionally absent**. Transport-managed names such as `Host` and `Accept-Encoding` may be added below the application guard; ambient cookies, changed authorities/ports, unlisted application headers, extra stages and redirect following are refused.

### Authentication source and refresh

Environment source: Z_AI_API_KEY or the explicitly selected variable. Config source: the one locally selected Claude Code settings.json, matching its Coding Plan base URL, reads ANTHROPIC_AUTH_TOKEN before ANTHROPIC_API_KEY. The base URL only selects a compiled region; it is never used as the quota request URL. Symlinks, arbitrary ports/userinfo/query/fragment/foreign bases are refused. OpenCode auth/provider parsing is present but absent from the production selection branch.

Refresh behavior: None. The key is never renewed, repaired, copied into a credential store or used for an inference probe. Expiry/entitlement failure is reported without searching other auth slots or regions.

### Budget and stop rules

One selected-region GET per read; 20-second timeout and 1-MiB response cap. The environment route keeps native 10-minute cadence/30-minute errors. The selected-config state has a five-minute floor, 10-minute success wait and capped exponential 10/20/40/60-minute failure wait. Production callers share provider locks/gates; an independent real-process budget matrix remains required.

One guarded client is created for the whole logical read. HTTP 401/403 and every 3xx response terminate further calls through that transport; it is never recreated to retry a rejection. A failed/missing credential or unsupported shape never grants a new source. Expired/absent values stay unknown. The auth stop lasts for this read, so later backoff-based attempts are a known limit, not a claimed durable stop.

## Tests

Existing test references are pinned to the reviewed implementation, not new executions or live-account evidence from this docs task.

- Fixtures: [TestNativeZaiRefresh](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/native_test.go) (`TestNativeZaiRefresh`).
- Fixtures: [TestZaiConfigProvenanceAndRegion](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigProvenanceAndRegion`).
- Fixtures: [TestZaiConfigConsentPassiveCadenceAndRedaction](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigConsentPassiveCadenceAndRedaction`).
- Fixtures: [TestZaiConfigSameGenerationFailureRetainsOriginalAge](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigSameGenerationFailureRetainsOriginalAge`).
- Owner-shaped case: Explicit environment versus selected Claude settings source; global/China provenance; missing key; wrong base/symlink; passive/off; region/key generation changes; no OpenCode active-provider grant; concurrent CLI/plugin/app readers on one home.
- Required L2: use an isolated owner-shaped synthetic home with the real CLI/app-server, independent clients, recorded providers/processes and retained settings. Check consent, no credential bytes in any output/store, no off-list or excess calls, revoke/new-epoch late results, source provenance, budget retention and recovery. Runtime paths also require the exact executable/version and observable no-refresh/write/prompt evidence.
- Outcome here: documentation/link/request-pin audit only. Owner-shaped reader L2, native identity/UI, live vendors and final-package/L3 are **not-run** by this card-writing change.

### Red lines and evidence

| Red line | Enforcement / test evidence and its limit |
| --- | --- |
| No refresh or other-tool writes | [TestZaiConfigConsentPassiveCadenceAndRedaction](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigConsentPassiveCadenceAndRedaction`) checks supported local-source behavior; it is not a whole-OS write trace. |
| No credential persistence/copy | [TestZaiConfigConsentPassiveCadenceAndRedaction](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigConsentPassiveCadenceAndRedaction`) is a synthetic fixture, not a scan of every output writer. Gap: label-filtered vendor Msg on rejection is not proved credential redaction. |
| No inference/paid or off-list calls | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) and [TestAccountUsageProductionTransportRejectsOffHost](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestAccountUsageProductionTransportRejectsOffHost`); off-list or extra calls never reach the recorder. |
| One vendor read per five minutes, shared | [TestDoctorReadersLegacyBudgetSharedWithSessionSweeps](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/readerattempt_dispatch_test.go) (`TestDoctorReadersLegacyBudgetSharedWithSessionSweeps`) provides source/cadence coverage; independent concurrent CLI/plugin/app L2 on the same home is not certified by this card. |
| Stop after authorization rejection | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) stops all later calls in the same logical read. Later scheduler reads are not a proved durable auth latch. |
| Detection reads presence only | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) covers compiled presence signals; it does not prove every real-OS I/O path. |
| No browser detection scan | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) is partial evidence. No exhaustive browser-directory trap/native audit is claimed. |
| Only keyed identity storage | [TestNativeAndCodexBarSubscriptions](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/identity_test.go) (`TestNativeAndCodexBarSubscriptions`) plus [TestZaiConfigConsentPassiveCadenceAndRedaction](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigConsentPassiveCadenceAndRedaction`) cover fixture bindings. A whole-writer audit is not-run. |
| Route and time on every value | [TestZaiConfigConsentPassiveCadenceAndRedaction](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/zaiconfig_test.go) (`TestZaiConfigConsentPassiveCadenceAndRedaction`) and [TestNullableWireFieldsStayExplicit](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/rows/types_test.go) (`TestNullableWireFieldsStayExplicit`) cover fixture provenance and explicit unknown fields. Exhaustive route/time validation and native “time unknown” rendering are not certified by these fixtures. |
| Fixed destinations / no redirect | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) plus the compiled authority/stage pins. No jar or followed redirect. |
| Catalogue switch-off and revocation | [TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes`) and [TestProductionLegacyAdmission](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionLegacyAdmission`). Known violations cannot be enabled by catalogue data. |
| Keychain identity / interaction | Not used by this chosen path. No browser/Keychain fallback is granted by the account scope. |

## Known gaps and unknowns

- The monitor endpoint is first-party documented in the official zai-org/ZCode docs, and ZCode Desktop 3.17.2 calls it itself; that is documentation and usage evidence, not a vendor stability or no-write/no-charge guarantee for other clients.
- **Open question (no behaviour change): authorization header form.** The official ZCode docs say to send `authorization: <API Key>` without a `Bearer` prefix, while the pinned ModelPlan transport sends `Authorization: Bearer` (as CodexBar and Pulse do; Pulse reports measuring success with `Bearer`). One live verification from a lane that already holds a key must settle which form the endpoint accepts before any transport change is considered. Until then the pinned header stays as reviewed.
- No alternative external interface exists today: `zcode` (0.17.0) has no usage/quota subcommand; the app-server `usage/stats` method returns local token/session/tool totals only; there is no OAuth/third-party-authorisation route for quota. Facts recorded 2026-11-05 from the pinned ZCode sources above.

## ZCode storage layout (research facts, file names only)

Recorded from the official ZCode repository @ `a9fe401e` and its `docs/analysis/credentials-json-code-audit.md`; no credential values are included, and no ModelPlan behaviour depends on this section.

- `~/.zcode/v2/provider_config.json` — plaintext, shared by Desktop and CLI. User-added providers carry `config.access.{type, apiKey}` (type `api-key` or `zhipu-coding-plan-api-key`), `config.api.baseUrl` and `defaultModelSelection.providerId`; fixed `account:*` providers carry no key here. Built-in templates (`zai-api`/`bigmodel-api`) default to `zhipu-coding-plan-api-key`.
- `~/.zcode/v2/credentials.json` — encrypted, `enc:v1:` AES-256-GCM envelope. The key is a SHA-256 of `ZCODE_CREDENTIAL_SECRET`, or of a fixed string built from platform, home directory and username; ZCode's own audit states this is not a Keychain-backed store. Manual "Coding Plan API key" entries are stored here encrypted; for OAuth logins the quota-reading token is minted per request and kept in memory only, so the file holds no ready quota key.
- Older layouts: Desktop 3.11–3.14 used `~/.zcode/v2/config.json` with plaintext `provider[id].options.apiKey` (read by current source only through a legacy reader); CLI-only installs keep `~/.zcode/cli/{config.json,setting.json}`. The layout has changed at least twice in about three months.
- The failure branch can include label-filtered vendor Msg text in the native error. Label validation is not a complete credential-redaction proof. Existing selected-config canary tests do not establish every rejection/error/diagnostic/cockpit output path; a hostile-response canary regression remains needed.
- OpenCode config-source parsing must not be described as an enabled production route. Enabling it needs a selected-provider contract and separate acceptance.
- Per-read HTTP auth-stop recording does not establish a persisted cross-read scope latch. Later scheduled reads remain possible after backoff; this is a standard-completion gap.
- Public source/reference behavior is not a guarantee of server-side no-write/no-charge effects. Catalogue enablement requires the card’s red lines and L2; creating this document supplies neither permission nor a pass.
