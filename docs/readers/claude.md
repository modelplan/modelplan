<!-- SPDX-License-Identifier: MIT -->
# Claude Code reader card

- Vendor source: [Claude Code usage documentation](https://code.claude.com/docs/en/costs) (checked 2026-10-29; product context, not a documented OAuth usage/profile API).
- References compared: [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/claude-code.md) (Apache-2.0).
- Reviewed ModelPlan artifact: `670fe9e7f9c2ac44ec64ac22e647b3baac73f11e`; [claudeaccount.go](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount.go); [fixed HTTP pins](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/readers/request_set.go). Public-source review only, 2026-10-29.
- Scope: `claude.account_usage.saved_login`. Local history and other access classes do not grant this account route.
- Status: card/evidence inventory, not a catalogue enablement or owner-shaped acceptance. This docs change enables no source and changes no consent/default.

## Data

Five-hour and seven-day usage percentages, reset timestamps and supported scoped weekly windows; plan metadata; extra-usage spend/limit only where the USD-cent shape is supported. Null/absent windows remain unknown. Prepaid credits, per-request allowance and account-wide quota inferred from local tokens are excluded.

- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift): O+H OAuth GET usage with additional credential/source machinery elsewhere in CodexBar; supplies schema evidence, not authority to refresh or use browser fallback.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/claude-code.md): O+H usage/profile plus optional desktop-cookie and status-line fallbacks. Its current document prefers a limits array; that is a compatibility warning for this pin’s older top-level shape, not proof the pin handles every current response.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Saved OAuth file | L credential source → H | O | Undocumented GET profile/usage | Local read and two bounded HTTPS calls; no token refresh | Chosen, conditional on consent and acceptance |
| App credential operation | App identity → H | O | Same GETs | Separate scope/Keychain consent and non-interactive policy required | Only the app-owned path can satisfy ADR 0003 |
| Legacy Keychain subprocess | Keychain process → H | O | Same GETs | Pinned fallback can invoke /usr/bin/security | Not compliant with the no-security red line; not approved here |
| Session/status-line counts | L / J | none | Local | Separate history capability | Cannot replace account quota |
| Browser/session fallback | S → H | C | Undocumented web calls | Browser/credential access and extra calls | Excluded from this standard scope |

## Incidents and pitfalls

The reference links above are source-reported behavior/pitfalls, not new incidents observed with a real account by this card.
- The compared Pulse source reports stale/expired credentials and an optional desktop fallback; ModelPlan must not turn that into a credential-source waterfall. → fixture [TestClaudeAdmissionAndUnsupportedLoginsMakeNoRequests](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeAdmissionAndUnsupportedLoginsMakeNoRequests`).
- Changed invalid credentials must not inherit a previous account; a reset-past window must not appear current. → fixture [TestClaudeChangedInvalidBindingNeverInheritsAccount](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_review_test.go) (`TestClaudeChangedInvalidBindingNeverInheritsAccount`).
- A credential-carrying redirect must not forward to any second URL. → fixture [TestClaudeDoesNotForwardCredentialOnRedirect](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeDoesNotForwardCredentialOnRedirect`).

## Choice

- Chosen path and tier: H/O, standard, not pre-selected. Saved-login consent is unchecked initially. Passive/off cannot elevate it. File login is the selected account path; a Keychain source additionally needs the reviewed app credential operation.
- Why: The selected saved login reports the needed subscription windows without launching Claude or installing a hook. Retaining a read-only file path does not approve the legacy Keychain fallback.
- Licence: Independent Go implementation. CodexBar (MIT) and Pulse (Apache-2.0) are protocol/incident references only; this card copies no code or upstream account fixture.
- Rejected paths and their red lines are listed in Candidate paths. No W/web scraping, automatic source waterfall or catalogue-driven authority expansion is admitted.

### Fixed request set

| Stage | Method / carrier | Host / peer | Path / RPC | Header names only |
| --- | --- | --- | --- | --- |
| Cold 1 | GET | api.anthropic.com | /api/oauth/profile | Accept, Authorization, User-Agent, Anthropic-Beta |
| Cold 2 / warm 1 | GET | api.anthropic.com | /api/oauth/usage | Accept, Authorization, User-Agent, Anthropic-Beta |

All listed URLs use HTTPS. GET bodies are empty. URL queries are forbidden. Header **values are intentionally absent**. Transport-managed names such as `Host` and `Accept-Encoding` may be added below the application guard; ambient cookies, changed authorities/ports, unlisted application headers, extra stages and redirect following are refused.

### Authentication source and refresh

Only the admitted profile’s `.credentials.json` (`~/.claude` or the literal `CLAUDE_CONFIG_DIR`) and supported `claudeAiOauth` access-token/expiry/scope/plan fields. Missing default-profile credentials may enter the separately granted app callback or legacy Keychain branch; malformed credentials do not switch accounts. API-key, cloud, helper and alternate-host logins are unsupported.

Refresh behavior: None by ModelPlan. An expired/rejected login asks the user to open Claude Code. No refresh-grant endpoint, Claude process, credential repair or copied token is part of the file path. The legacy Keychain exception below must remain visible.

### Budget and stop rules

One cold profile+usage set (2 calls) or warm usage (1 call), using credential-bound metadata for at most 24 hours. The managed read has one 20-second deadline, a provider-wide five-minute floor, unchanged-success cadence 10/15/30 minutes and failure backoff 10/20/40/60 minutes plus longer Retry-After. Personal-data purge must preserve the attempt gate.

One guarded client is created for the whole logical read. HTTP 401/403 and every 3xx response terminate further calls through that transport; it is never recreated to retry a rejection. A failed/missing credential or unsupported shape never grants a new source. Expired/absent values stay unknown. The auth stop lasts for this read, so later backoff-based attempts are a known limit, not a claimed durable stop.

## Tests

Existing test references are pinned to the reviewed implementation, not new executions or live-account evidence from this docs task.

- Fixtures: [TestClaudeAccountReadBudgetCadenceAndCache](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeAccountReadBudgetCadenceAndCache`).
- Fixtures: [TestClaudeKeychainBlockedStateKeepsCapture](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeKeychainBlockedStateKeepsCapture`).
- Fixtures: [TestClaudeParserRejectsUnknownShapeAndCurrency](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeParserRejectsUnknownShapeAndCurrency`).
- Fixtures: [TestClaudeForgetReconnectRestartPreservesActualProviderFloor](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_review_test.go) (`TestClaudeForgetReconnectRestartPreservesActualProviderFloor`).
- Owner-shaped case: Default file login; custom admitted directory; expired/missing-scope and changed-token replacements; duplicate profiles; denied/unset Keychain choice; background versus explicit interaction; retained cache during revoke and reset.
- Required L2: use an isolated owner-shaped synthetic home with the real CLI/app-server, independent clients, recorded providers/processes and retained settings. Check consent, no credential bytes in any output/store, no off-list or excess calls, revoke/new-epoch late results, source provenance, budget retention and recovery. Runtime paths also require the exact executable/version and observable no-refresh/write/prompt evidence.
- Outcome here: documentation/link/request-pin audit only. Owner-shaped reader L2, native identity/UI, live vendors and final-package/L3 are **not-run** by this card-writing change.

### Red lines and evidence

| Red line | Enforcement / test evidence and its limit |
| --- | --- |
| No refresh or other-tool writes | [TestClaudeAccountReadBudgetCadenceAndCache](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeAccountReadBudgetCadenceAndCache`) for the file path; the app/legacy Keychain branch needs separate identity/prompt evidence. |
| No credential persistence/copy | [TestClaudeAccountReadBudgetCadenceAndCache](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeAccountReadBudgetCadenceAndCache`) is a synthetic fixture, not a scan of every output writer. |
| No inference/paid or off-list calls | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) and [TestAccountUsageProductionTransportRejectsOffHost](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestAccountUsageProductionTransportRejectsOffHost`); off-list or extra calls never reach the recorder. |
| One vendor read per five minutes, shared | [TestClaudeForgetReconnectRestartPreservesActualProviderFloor](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_review_test.go) (`TestClaudeForgetReconnectRestartPreservesActualProviderFloor`) provides source/cadence coverage; independent concurrent CLI/plugin/app L2 on the same home is not certified by this card. |
| Stop after authorization rejection | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) stops all later calls in the same logical read. Later scheduler reads are not a proved durable auth latch. |
| Detection reads presence only | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) covers compiled presence signals; it does not prove every real-OS I/O path. |
| No browser detection scan | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) is partial evidence. No exhaustive browser-directory trap/native audit is claimed. |
| Only keyed identity storage | [TestNativeAndCodexBarSubscriptions](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/identity_test.go) (`TestNativeAndCodexBarSubscriptions`) plus [TestClaudeAccountReadBudgetCadenceAndCache](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeAccountReadBudgetCadenceAndCache`) cover fixture bindings. A whole-writer audit is not-run. |
| Route and time on every value | [TestClaudeAccountReadBudgetCadenceAndCache](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeAccountReadBudgetCadenceAndCache`) and [TestNullableWireFieldsStayExplicit](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/rows/types_test.go) (`TestNullableWireFieldsStayExplicit`) cover fixture provenance and explicit unknown fields. Exhaustive route/time validation and native “time unknown” rendering are not certified by these fixtures. |
| Fixed destinations / no redirect | [TestProductionReaderClientsEnforceReadBoundary](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/reader_transport_test.go) (`TestProductionReaderClientsEnforceReadBoundary`) plus the compiled authority/stage pins. No jar or followed redirect. |
| Catalogue switch-off and revocation | [TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes`) and [TestProductionManagedAdmission](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionManagedAdmission`). Known violations cannot be enabled by catalogue data. |
| Keychain identity / interaction | Gap: legacy security subprocess remains in the pin when the callback is absent. [TestClaudeKeychainBlockedStateKeepsCapture](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/claudeaccount_test.go) (`TestClaudeKeychainBlockedStateKeepsCapture`) tests bounded legacy behavior, not ADR 0003 compliance. |

## Known gaps and unknowns

- The pinned collector still contains a `/usr/bin/security` fallback when no app credential callback is supplied. Its bounded process tests prove legacy behavior, not ADR 0003 compliance. That fallback is not approved by this card; an enabling route must exclude it or prove the app-owned replacement.
- The exact OAuth endpoints and legacy response shape have no vendor stability guarantee. Latest reference schema differences require fresh synthetic fixtures before parser expansion.
- File/HTTP fixtures do not prove app identity, OS prompt suppression, native time-unknown rendering, live vendor behavior or owner-shaped L2.
- Per-read HTTP auth-stop recording does not establish a persisted cross-read scope latch. Later scheduled reads remain possible after backoff; this is a standard-completion gap.
- Public source/reference behavior is not a guarantee of server-side no-write/no-charge effects. Catalogue enablement requires the card’s red lines and L2; creating this document supplies neither permission nor a pass.
