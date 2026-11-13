<!-- SPDX-License-Identifier: MIT -->
# Antigravity reader card

- Reviewed ModelPlan source: `61ef253f0667a5e10a2c438212757775e116559a`; [antigravity.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity.go), [antigravity_state.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_state.go).
- Scope: `antigravity.runtime_usage`. Scope authority, catalogue presence and account membership are separate.
- Review date: 2026-10-29. Public-source inspection only; no real data, credentials, installed runtime execution or live vendor request. This docs change enables no reader and changes no default.

- Vendor source: [Google Antigravity authentication](https://antigravity.google/docs/install) (checked on the review date; product context, not a documented no-refresh GetUserStatus contract).
- References compared: [antigravity-panel@dc1c63dd](https://github.com/n2ns/antigravity-panel/blob/dc1c63dd16c4621f115310fdea37b4c86fecc0cd/src/model/services/quota.service.ts) (Apache-2.0), [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Antigravity/AntigravityStatusProbe+LocalEndpoints.swift) (MIT), [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/antigravity.md) (Apache-2.0).

## Data

`userStatus.cascadeModelConfigData.clientModelConfigs`: each model/pool's explicit remaining fraction and reset time. Convert a bounded fraction to used percentage; skip duplicate/invalid/past-reset entries. Duration/kind stays unknown. No Claude/Codex plan, membership, identity or shared account is inferred from model names.

- Panel, pinned above: local language-server quota/status family, including a different quota-summary RPC; its extra endpoint is not added to ModelPlan's single GetUserStatus read.
- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Antigravity/AntigravityStatusProbe+LocalEndpoints.swift): alternate local endpoint/source selection. Its broader fallback/auth sources do not authorize a ModelPlan waterfall.
- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/antigravity.md): local quota summary and optional CLI fallback; documents why older `agy` print-mode slash commands could become paid prompts and why CLI logging matters. That CLI path is not launched here.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Already-running verified language server | R, loopback HTTP | runtime; transient local CSRF nonce | Undocumented local RPC | Runtime's inner network/auth/storage effects unknown | Selected, with listener binding; review incomplete |
| Extra quota-summary / alternate port probing | R | runtime | Different RPCs or ambiguous peer | Extra calls or nonce to wrong process | Rejected |
| Launch `agy`, OAuth HTTP, browser or Keychain fallback | R / H / S | runtime / O / C | Different capabilities | Startup refresh, prompt, logs or credential extraction risk | Excluded |

## Incidents and pitfalls

- A PID/port descriptor can become stale between discovery and connect. → [TestAntigravityListenerBindingBeforeHTTP](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_test.go) (`TestAntigravityListenerBindingBeforeHTTP`) checks revalidation before nonce transmission.
- Reference CLI behavior is version dependent: Pulse reports print-mode `/usage` could become a prompt before its supported version, and logging can alter the CLI log pointer. This justifies excluding that fallback; it is not evidence about ModelPlan's loopback RPC. → [TestAntigravityNoRedirectRetryOrOAuth](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_test.go) (`TestAntigravityNoRedirectRetryOrOAuth`).

## Choice

- R/runtime; standard pre-selection requires completed side-effect review. The compiled definition has `defaultCheck: true`, but no reviewed language-server version/hash or inner side-effect evidence is supplied here. Display: “Read by Antigravity's own runtime”.
- Use the already-running same-user process, exact app marker, declared port and nonce; no app launch, browser scan, port probing, OAuth file read or fallback.
- Licence: the existing Go implementation identifies independent contract use from the pinned Panel source. All three upstream licences remain attached to their own sources; this card copies no implementation or account fixture.

### Fixed request set and runtime side-effect review

| Method | Peer | Path | Header names only | Body schema |
| --- | --- | --- | --- | --- |
| POST | `127.0.0.1`, exact verified process port | `/exa.language_server_pb.LanguageServerService/GetUserStatus` | Content-Type, Connect-Protocol-Version, X-Codeium-Csrf-Token | Fixed metadata: ideName, extensionName, ideVersion, locale; no user input |

HTTP is the default loopback scheme; a supplied verified TLS descriptor selects HTTPS. The body fields are compiled constants. The CSRF nonce is local connection metadata, used transiently; the owning app retains its vendor login. ModelPlan removes proxies for this verified local connection, disables redirects, binds the exact address and rechecks ownership after connecting before sending headers. One RPC per read, 20-second request timeout and 1-MiB response bound; no retry/fallback. Discovery uses bounded same-user process/listener metadata commands after admission, not a vendor call.

Runtime version reviewed: **none installed or observed**. The Panel/source pins identify comparison code, not a tested Google executable. No official no-refresh flag was established for GetUserStatus. ModelPlan issues no login, session creation, generation or state-change method; whether this RPC can trigger vendor authentication renewal, config/credential writes, audit/state updates or paid calls inside the language server remains unknown. A loopback recording cannot prove zero vendor network activity.

The wrapper preserves a five-minute attempt floor, ten-minute success cadence and 10/20/40/60-minute failure backoff. HTTP 401/403 ends this call; a verified nonempty login generation can hold the expired-login state until recovery. Legacy unbound dispatch may retry after backoff, so no unconditional durable auth-stop claim is made.

## Tests

- Fixtures: [TestAntigravityLocalRPCAndCache](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_test.go) (`TestAntigravityLocalRPCAndCache`), [TestAntigravityAdmissionAndDiscovery](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_test.go) (`TestAntigravityAdmissionAndDiscovery`), [TestAntigravityNoRedirectRetryOrOAuth](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_test.go) (`TestAntigravityNoRedirectRetryOrOAuth`), [TestAntigravityListenerBindingBeforeHTTP](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_test.go) (`TestAntigravityListenerBindingBeforeHTTP`), [TestAntigravityNativeFailureGenerationAndLegacyRecovery](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_test.go) (`TestAntigravityNativeFailureGenerationAndLegacyRecovery`), [TestAntigravityVerifiedLoopbackBypassesSuppliedProxy](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/antigravity_test.go) (`TestAntigravityVerifiedLoopbackBypassesSuppliedProxy`).
- Red lines covered by synthetic seams: no nonce to a changed listener/off-loopback peer; no redirect/retry/OAuth fallback; privacy/generation gates and cache binding. No inner vendor-network or credential/config/Keychain-write observation is established.
- Owner-shaped case: exact app executable/version/hash, running versus absent/ambiguous/replaced listener, HTTP/TLS descriptor, proxy present, expired login with/without a verified generation, revoke/reset and concurrent clients.
- Required seam: connect the verified real runtime to independent vendor traffic and filesystem/Keychain/prompt recorders, including auth-expiry and error paths. Outer local-server tests cannot replace it.

## Known gaps and unknowns

The runtime side-effect gap is P1 for coordinator routing. Local identity checks prove the peer, not what it does internally. No runtime safety qualification, live quota, native app prompt proof, device L2 or L3 is claimed by this card. Do not infer plan duration or shared subscription from returned model pools.
