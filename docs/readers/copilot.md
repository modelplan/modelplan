<!-- SPDX-License-Identifier: MIT -->
# GitHub Copilot runtime reader card

- Vendor source: [GitHub Copilot SDK client@53867584](https://github.com/github/copilot-sdk/blob/538675843887643ce471c874a3a9870ebda3f6f4/nodejs/src/client.ts) and [SDK protocol version@53867584](https://github.com/github/copilot-sdk/blob/538675843887643ce471c874a3a9870ebda3f6f4/go/sdk_protocol_version.go) (protocol 3; not an installed-runtime version review).
- References compared: [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Copilot/CopilotUsageFetcher.swift) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/copilot.md) (Apache-2.0).
- Reviewed ModelPlan artifact: `61ef253f0667a5e10a2c438212757775e116559a`; [copilot.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot.go); [fixed HTTP pins](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/readers/request_set.go). Public-source review only, 2026-10-29.
- Scope: `copilot.runtime_usage`. Local history and other access classes do not grant this account route.
- Status: card/evidence inventory, not a catalogue enablement or owner-shaped acceptance. This docs change enables no source and changes no consent/default.

## Data

Quota snapshots for premium interactions, chat and completions: reported used/entitlement request counts, remaining percentage, explicit unlimited entitlement and reset date. A reset date does not establish a monthly duration. Unknown/missing counters and entitlement stay unknown; no plan membership or token history is inferred.

- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Copilot/CopilotUsageFetcher.swift): Uses a GitHub OAuth token over H to /copilot_internal/user; this is a different auth capability from the selected owning-runtime path.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/copilot.md): Also uses the undocumented internal GitHub endpoint and keeps its own token. Its missing-entitlement and overage warnings motivate parser caution; its HTTP shape does not prove parity with protocol-3 quota RPC.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Owning runtime RPC | R | runtime | Published SDK RPC contract, protocol 3 | Runtime may access network/login/Keychain internally | Selected outer RPC surface; side effects still unknown |
| GitHub saved-token HTTP | L → H | O / separately managed token | Undocumented internal endpoint | Extracts/keeps token | Not selected |
| Automatic bridge fallback | Helper-dependent | Separate access class | Different backend | May add auth/browser/process capabilities | Not selected; explicit separate review needed |
| Local events | L | none | Local | Token history only | Separate copilot.local_history scope |

## Incidents and pitfalls

The reference links above are source-reported behavior/pitfalls, not new incidents observed with a real account by this card.
- Unauthenticated or unsupported auth must stop before quota, with no helper/token fallback. → fixture [TestCopilotAuthBeforeQuota](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotAuthBeforeQuota`).
- Method-not-found may use the single listed ping handshake; arbitrary errors must not open a waterfall. → fixture [TestCopilotProtocolFailuresAndLegacy](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_test.go) (`TestCopilotProtocolFailuresAndLegacy`).
- Missing runtime must not turn into quota zero or execute an incompatible script. → fixture [TestCopilotMissingRuntimeAndResetCounts](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_test.go) (`TestCopilotMissingRuntimeAndResetCounts`).

## Choice

- Chosen path and tier: R/runtime; standard, pre-selected only after the required runtime side-effect review. That review is not established by an SDK protocol number. Label the path “Read by Copilot’s own runtime”; a missing runtime needs a recovery action, not an automatic helper switch.
- Why: The owning process can provide account quota while keeping authentication out of ModelPlan. The selected scope never imports GitHub CLI/SDK tokens.
- Licence: Independent adapter based on the MIT GitHub SDK contract; no SDK implementation is copied. CodexBar MIT and Pulse Apache-2.0 are comparison-only sources.
- Rejected paths and their red lines are listed in Candidate paths. No W/web scraping, automatic source waterfall or catalogue-driven authority expansion is admitted.

### Fixed request set

| Stage | Method / carrier | Host / peer | Path / RPC | Header names only |
| --- | --- | --- | --- | --- |
| Handshake | Content-Length-framed stdio RPC | Owning copilot process | connect | Content-Length (framing only) |
| Compatibility handshake | Same RPC | Same process | ping, only after connect returns method-not-found | Content-Length (framing only) |
| Data 1 | Same RPC | Same process | auth.getStatus | Content-Length (framing only) |
| Data 2 | Same RPC | Same process | account.getQuota | Content-Length (framing only) |

Every listed RPC has exactly empty params. `connect` may fall back to `ping` only for method-not-found; an authentication/server error is terminal. The returned protocol must be 3, auth must be an authenticated user, and only then is quota requested.

HTTP method/host/path/header values inside the owning process are not invented here. These are outer protocol pins, not a NewReadTransport wrapper or proof of a two-HTTP-request budget.

### Authentication source and refresh

The supported installed runtime runs with `--headless --no-auto-update --stdio`; the absolute MODELPLAN_COPILOT override or supported discovery chooses the executable. ModelPlan strips caller GitHub/Copilot credential environment variables before launch and requires authenticated user auth from auth.getStatus. It does not read/import a saved token or create a session. Vendor HTTP method/host/path/headers inside the runtime are unknown.

Refresh behavior: Runtime-owned and unproved. The outer method set has no login/logout/refresh, prompt or session method; no per-request no-refresh switch equivalent to Codex’s flag is established here. Preventing auto-update is not proof that authentication cannot renew or write state.

### Runtime side-effect review (2026-10-29)

Subject: [current main adapter](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot.go) and [generation/budget wrapper](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state.go). Runtime version reviewed: **none installed, executed or safety-audited**. The pinned MIT SDK contract at `538675843887643ce471c874a3a9870ebda3f6f4` specifies protocol **3**; that is not an installed Copilot executable version/hash.

| Boundary | Evidence and conclusion |
| --- | --- |
| Exact outer calls | `connect` (only method-not-found permits `ping`), then `auth.getStatus`, then `account.getQuota`; every params object is empty |
| Login renewal | No per-request no-refresh mechanism is established for these calls. Runtime-owned login renewal during startup, handshake, auth or quota retrieval is **unknown** |
| Credential/config/Keychain writes | Caller GitHub/Copilot token variables and NODE_DEBUG are stripped; no token file is imported. Runtime-owned writes/migration and OS prompts are **unknown**; `--no-auto-update` is not an authentication safeguard |
| Inference, paid calls, state changes | No session creation, prompt, login/logout or mutation command is sent. Process/connection and ModelPlan cache/gate bookkeeping occur; persistent runtime/backend changes, inner request count and paid/background work remain **unknown** |
| Observable evidence | Framed synthetic RPC fakes check protocol/auth-before-quota and the outer method list. They are not vendor-HTTP, filesystem or Keychain observations |
| Required test seam | Exact executable/version/hash; record startup/connect/auth/quota with valid/expired/missing login, error/EOF and cancellation. Observe vendor requests, credential/config writes and prompts, and scan every writer for credential canaries |

**P1 gap:** no versioned no-refresh/write/paid-call qualification is supplied. The compiled R definition has `defaultCheck: true`; the standard makes runtime pre-selection conditional on the missing side-effect review. The nonempty-generation auth hold is outer evidence only and cannot classify hidden HTTP 401/403. This docs PR changes no admission/default and certifies no runtime.

### Budget and stop rules

Normally connect + auth status + quota (3 RPC requests); ping adds one handshake request only for -32601. There are at most two data RPCs, not at most two vendor HTTP requests. The native 20-second deadline, bounded framing/output and kill/reap cleanup apply. Persisted five-minute attempt floor, 10-minute success wait and capped 10/20/40/60-minute failures apply to the source state.

The first terminal RPC/auth/protocol/transport failure stops the listed sequence (except the listed connect-to-ping method-not-found compatibility). No request to renew a token, start inference or consume credits is allowed. Inner runtime retries, HTTP auth codes, redirect behavior and subsequent network calls remain outside this recorder’s proof.

## Tests

Existing test references are pinned to the reviewed implementation, not new executions or live-account evidence from this docs task.

- Fixtures: [TestCopilotRuntimeOptInAndCache](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_test.go) (`TestCopilotRuntimeOptInAndCache`).
- Fixtures: [TestCopilotPartialQuota](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_test.go) (`TestCopilotPartialQuota`).
- Fixtures: [TestCopilotAdmissionBeforeIO](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotAdmissionBeforeIO`).
- Fixtures: [TestCopilotEnvironmentAndAuthHold](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotEnvironmentAndAuthHold`).
- Fixtures: [TestCopilotCaptureGenerationIsNotAttemptGeneration](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotCaptureGenerationIsNotAttemptGeneration`).
- Owner-shaped case: Exact installed runtime version/hash, protocol-3 handshake and legacy ping; GUI runtime availability; authenticated user versus service/API-key auth; scoped login generation; unknown/zero/unlimited entitlement; timeout/EOF; concurrent shared-home callers, revoke and reset.
- Required L2: use an isolated owner-shaped synthetic home with the real CLI/app-server, independent clients, recorded providers/processes and retained settings. Check consent, no credential bytes in any output/store, no off-list or excess calls, revoke/new-epoch late results, source provenance, budget retention and recovery. Runtime paths also require the exact executable/version and observable no-refresh/write/prompt evidence.
- Outcome here: documentation/link/request-pin audit only. Owner-shaped reader L2, native identity/UI, live vendors and final-package/L3 are **not-run** by this card-writing change.

### Red lines and evidence

| Red line | Enforcement / test evidence and its limit |
| --- | --- |
| No refresh or other-tool writes | Outer call list only: [TestCopilotProtocolFailuresAndLegacy](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_test.go) (`TestCopilotProtocolFailuresAndLegacy`). Inner refresh/writes are unknown; no installed-runtime side-effect pass. |
| No credential persistence/copy | [TestCopilotEnvironmentAndAuthHold](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotEnvironmentAndAuthHold`) is a synthetic fixture, not a scan of every output writer. |
| No inference/paid or off-list calls | Outer method list: [TestCopilotProtocolFailuresAndLegacy](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_test.go) (`TestCopilotProtocolFailuresAndLegacy`). Runtime-owned HTTP/paid behavior not certified. |
| One vendor read per five minutes, shared | [TestCopilotAttemptGateAndLastGood](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotAttemptGateAndLastGood`) provides source/cadence coverage; independent concurrent CLI/plugin/app L2 on the same home is not certified by this card. |
| Stop after authorization rejection | [TestCopilotAuthBeforeQuota](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotAuthBeforeQuota`) and [TestCopilotEnvironmentAndAuthHold](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotEnvironmentAndAuthHold`); outer auth hold is conditional, not inner HTTP proof. |
| Detection reads presence only | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) covers compiled presence signals; it does not prove every real-OS I/O path. |
| No browser detection scan | [TestPresenceOnlyAndUnknownSignals](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/detect/detect_test.go) (`TestPresenceOnlyAndUnknownSignals`) is partial evidence. No exhaustive browser-directory trap/native audit is claimed. |
| Only keyed identity storage | [TestNativeAndCodexBarSubscriptions](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/identity_test.go) (`TestNativeAndCodexBarSubscriptions`) plus [TestCopilotEnvironmentAndAuthHold](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotEnvironmentAndAuthHold`) cover fixture bindings. A whole-writer audit is not-run. |
| Route and time on every value | [TestCopilotEnvironmentAndAuthHold](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/copilot_state_test.go) (`TestCopilotEnvironmentAndAuthHold`) and [TestNullableWireFieldsStayExplicit](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/rows/types_test.go) (`TestNullableWireFieldsStayExplicit`) cover fixture provenance and explicit unknown fields. Exhaustive route/time validation and native “time unknown” rendering are not certified by these fixtures. |
| Fixed destinations / no redirect | Unknown inside the runtime. The process fake is not a vendor-HTTP recording proxy. |
| Catalogue switch-off and revocation | [TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/production_test.go) (`TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes`) and [TestProductionLegacyAdmission](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/production_test.go) (`TestProductionLegacyAdmission`). Known violations cannot be enabled by catalogue data. |
| Keychain identity / interaction | ModelPlan imports no Keychain credential in this scope; runtime-owned OS prompts/writes remain unknown. Native identity/UI evidence is not-run. |

## Known gaps and unknowns

- Runtime version reviewed: none. SDK commit and protocol 3 do not identify a reviewed executable or certify startup/auth side effects, no writes/prompts, no token renewal, no paid calls or inner HTTP request limits.
- A nonempty verified login generation can hold expired_login until the generation changes. Legacy unbound reads retry after persisted backoff. Neither synthetic branch certifies a durable response to an HTTP 401/403 hidden inside the runtime.
- Reference HTTP quota fields and plan semantics may differ from account.getQuota. Current synthetic RPC fixtures are compatibility proof only; owner-shaped runtime L2 and native Keychain/prompt evidence are not-run.
- Public source/reference behavior is not a guarantee of server-side no-write/no-charge effects. Catalogue enablement requires the card’s red lines and L2; creating this document supplies neither permission nor a pass.
