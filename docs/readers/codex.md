<!-- SPDX-License-Identifier: MIT -->
# Codex runtime reader card

- Vendor source: [Official OpenAI app-server account/rate-limit contract](https://learn.chatgpt.com/docs/app-server#auth-endpoints) (checked 2026-10-29; published protocol, not a reviewed installed runtime version).
- References compared: [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/docs/codex.md) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/codex.md) (Apache-2.0).
- Reviewed ModelPlan artifact: `670fe9e7f9c2ac44ec64ac22e647b3baac73f11e`; [codexaccount.go](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount.go); [fixed HTTP pins](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/readers/request_set.go). Public-source review only, 2026-10-29.
- Scope: `codex.runtime_usage`. Local history and other access classes do not grant this account route.
- Status: card/evidence inventory, not a catalogue enablement or owner-shaped acceptance. This docs change enables no source and changes no consent/default.

## Data

Runtime-reported quota-window percentages, durations and reset times; plan; usage-credit balance; earned reset-credit count and available expiries. Missing details stay unknown. No credit IDs, raw account identity, prompts or request-level token history enter the account snapshot; local session history is a separate scope.

- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/docs/codex.md): Compares CLI account/rateLimits/read with OAuth/PAT HTTP usage and optional web enrichment. ModelPlan chooses only the owning-runtime request set.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/codex.md): Uses a saved-token HTTP primary and an app-server fallback/reset-credit query. Its pipe EOF/reconnect incident is a supervision lesson, not evidence that runtime-owned authentication has no side effects.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Owning runtime account RPC | R | runtime | Documented account methods | Runtime may use network or renew its own login; inner behavior unproved | Selected bounded outer method set; side-effect review incomplete |
| Borrowed saved-token HTTP | L → H | O | Undocumented compatibility endpoint | Extracts another tool’s credential | Not selected; increases credential capability |
| Web/dashboard enrichment | S → H | C | Undocumented | Browser/session access and extra calls | Excluded |
| Local session log | L | none | Local | Token history only | Separate scope; not account quota |

## Incidents and pitfalls

The reference links above are source-reported behavior/pitfalls, not new incidents observed with a real account by this card.
- Pulse documents an EOF readability-handler spin (its issue #25); ModelPlan must close/reap the child and terminate bounded reads. → fixture [TestFailedRefreshWaitsLongerAndOffMeansOff](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestFailedRefreshWaitsLongerAndOffMeansOff`).
- Reset-credit availability must not invoke the consuming operation. → fixture [TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes`).
- Shortened runtime error text is not secret redaction; the error-store branch needs its own canary regression. → fixture [TestFailedRefreshWaitsLongerAndOffMeansOff](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestFailedRefreshWaitsLongerAndOffMeansOff`).
- [Pulse EOF incident #25](https://github.com/qunqin24/Pulse/issues/25) is a reference process-lifecycle incident, not a reproduced ModelPlan incident.

## Choice

- Chosen path and tier: R/runtime. Standard, pre-selected is the integration-standard target only after runtime side-effect review. This card supplies no such completed review and changes no catalogue default. The UI must say “Read by Codex’s own runtime”.
- Why: The documented runtime can return account-wide windows without ModelPlan extracting a credential. This is not a local/zero-network path.
- Licence: Existing independently written Go RPC adapter; CodexBar MIT and Pulse Apache-2.0 are comparison references only. No copied upstream implementation or account fixture is introduced.
- Rejected paths and their red lines are listed in Candidate paths. No W/web scraping, automatic source waterfall or catalogue-driven authority expansion is admitted.

### Fixed request set

| Stage | Method / carrier | Host / peer | Path / RPC | Header names only |
| --- | --- | --- | --- | --- |
| Handshake | stdio JSON-RPC | Owning codex process | initialize; initialized | No HTTP headers |
| Data 1 | stdio JSON-RPC | Owning codex process | account/rateLimits/read | No HTTP headers |
| Optional data 2 | stdio JSON-RPC | Owning codex process | account/read | No HTTP headers |

`initialize` sends fixed clientInfo and experimental capability metadata; `initialized` is a notification. Both data methods use empty params except optional `account/read`, whose sole parameter is `refreshToken:false`.

HTTP method/host/path/header values inside the owning process are not invented here. These are outer protocol pins, not a NewReadTransport wrapper or proof of a two-HTTP-request budget.

### Authentication source and refresh

The installed executable selected by `MODELPLAN_CODEX`, PATH or supported bundled locations runs `codex app-server` on private stdin/stdout pipes. The runtime owns its login; ModelPlan does not read `auth.json` or import a token for this scope. HTTP method, vendor host/path and HTTP header allow-list inside that process are unknown, not ModelPlan-pinned.

Refresh behavior: Runtime-owned and not certified. The optional identity request explicitly uses `refreshToken:false`; no refresh/login/logout/turn/thread/reset-credit-consume method is sent. The official contract says this flag avoids a forced refresh for that account read; it is not a blanket no-refresh guarantee for startup, rate-limit retrieval or every authentication mode.

### Budget and stop rules

Exactly initialize/initialized, then one rate-limit read and at most one identity read (identity is omitted when identity is off). These are at most two data RPCs, not a two-HTTP-call proof. The outer operation has a 15-second deadline and kill/reap cleanup. AccountDue offers a five-minute success cadence and 30-minute failure wait; its all-caller/durable-budget limit is recorded below.

The first terminal RPC/auth/protocol/transport failure stops the listed sequence. No request to renew a token, start inference or consume credits is allowed. Inner runtime retries, HTTP auth codes, redirect behavior and subsequent network calls remain outside this recorder’s proof.

## Tests

Existing test references are pinned to the reviewed implementation, not new executions or live-account evidence from this docs task.

- Fixtures: [TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes`).
- Fixtures: [TestFailedRefreshWaitsLongerAndOffMeansOff](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestFailedRefreshWaitsLongerAndOffMeansOff`).
- Fixtures: [TestCreditsWithoutDetailsAreCounted](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestCreditsWithoutDetailsAreCounted`).
- Fixtures: [TestUsageCreditsFromAccountAndLogs](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestUsageCreditsFromAccountAndLogs`).
- Owner-shaped case: A selected installed Codex executable and exact runtime version; signed-in ChatGPT versus unsupported/no account; runtime missing from GUI PATH; stdin/stdout EOF and timeout; identity off; count-only versus detailed reset credits; external revoke and epoch reset on a shared home.
- Required L2: use an isolated owner-shaped synthetic home with the real CLI/app-server, independent clients, recorded providers/processes and retained settings. Check consent, no credential bytes in any output/store, no off-list or excess calls, revoke/new-epoch late results, source provenance, budget retention and recovery. Runtime paths also require the exact executable/version and observable no-refresh/write/prompt evidence.
- Outcome here: documentation/link/request-pin audit only. Owner-shaped reader L2, native identity/UI, live vendors and final-package/L3 are **not-run** by this card-writing change.

### Red lines and evidence

| Red line | Enforcement / test evidence and its limit |
| --- | --- |
| No refresh or other-tool writes | Outer call list only: [TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes`). Inner refresh/writes are unknown; no installed-runtime side-effect pass. |
| No credential persistence/copy | [TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes`) is a synthetic fixture, not a scan of every output writer. Gap: shortened arbitrary runtime errors can still be persisted; no full error-path canary pass. |
| No inference/paid or off-list calls | Outer method list: [TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes`). Runtime-owned HTTP/paid behavior not certified. |
| One vendor read per five minutes, shared | [TestFailedRefreshWaitsLongerAndOffMeansOff](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestFailedRefreshWaitsLongerAndOffMeansOff`) provides source/cadence coverage; independent concurrent CLI/plugin/app L2 on the same home is not certified by this card. Direct refresh and snapshot purge remain explicit gaps. |
| Stop after authorization rejection | RPC errors end the pending read; [TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes`). Hidden HTTP 401/403 cannot be classified or durably stopped by ModelPlan’s HTTP guard. |
| Detection reads presence only | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) covers compiled presence signals; it does not prove every real-OS I/O path. |
| No browser detection scan | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) is partial evidence. No exhaustive browser-directory trap/native audit is claimed. |
| Only keyed identity storage | [TestNativeAndCodexBarSubscriptions](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/identity_test.go) (`TestNativeAndCodexBarSubscriptions`) plus [TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes`) cover fixture bindings. A whole-writer audit is not-run. |
| Route and time on every value | [TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/codexaccount_test.go) (`TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes`) and [TestNullableWireFieldsStayExplicit](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/rows/types_test.go) (`TestNullableWireFieldsStayExplicit`) cover fixture provenance and explicit unknown fields. Exhaustive route/time validation and native “time unknown” rendering are not certified by these fixtures. |
| Fixed destinations / no redirect | Unknown inside the runtime. The process fake is not a vendor-HTTP recording proxy. |
| Catalogue switch-off and revocation | [TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes`) and [TestProductionLegacyAdmission](https://github.com/modelplan/modelplan/blob/670fe9e7f9c2ac44ec64ac22e647b3baac73f11e/cli/internal/quota/production_test.go) (`TestProductionLegacyAdmission`). Known violations cannot be enabled by catalogue data. |
| Keychain identity / interaction | ModelPlan imports no Keychain credential in this scope; runtime-owned OS prompts/writes remain unknown. Native identity/UI evidence is not-run. |

## Known gaps and unknowns

- Runtime version reviewed: none. The checked artifact is ModelPlan’s adapter and synthetic protocol fixtures, not an installed Codex binary/hash. Startup writes, token renewal, Keychain prompts, paid calls, inner HTTP destinations/redirects/counts and no-refresh across all paths remain unknown.
- The pinned error path persists `short(err.Error())` to the account snapshot, and `askCodex` can return the runtime’s arbitrary error.message. Truncation is not a canary-safe redaction boundary; current happy-path identity tests do not establish the no-credential-output red line for this branch.
- The direct RefreshCodexAccount function does not itself call AccountDue, and attempt timing lives in its snapshot. A five-minute floor across every caller and after Forget/reconnect is not proven by its cadence/lock fixtures.
- The current HTTP/runtime equivalence and side-effect acceptance remain a contract gap; writing this card is not an approval to promote the runtime path.
- Public source/reference behavior is not a guarantee of server-side no-write/no-charge effects. Catalogue enablement requires the card’s red lines and L2; creating this document supplies neither permission nor a pass.
