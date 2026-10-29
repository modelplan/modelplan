<!-- SPDX-License-Identifier: MIT -->
# Kiro reader card

- Reviewed ModelPlan source: `61ef253f0667a5e10a2c438212757775e116559a`; [kiro.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/kiro.go), [quota_native.go](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/quota_native.go).
- Scope: `kiro.runtime_usage`. Scope authority, catalogue presence and account membership are separate.
- Review date: 2026-10-29. Public-source inspection only; no real data, credentials, installed runtime execution or live vendor request. This docs change enables no reader and changes no default.

- Vendor source: [Kiro V3 ACP migration](https://kiro.dev/docs/cli/v3/acp-migration/) and [ACP reference](https://kiro.dev/docs/cli/acp/) (checked on the review date; mutable documentation).
- References compared: [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/kiro.md) (Apache-2.0), [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Kiro/KiroStatusProbe.swift) (MIT). Existing port attribution: [Pulse@8410d081](https://github.com/qunqin24/Pulse/blob/8410d0817d092011b2106ed6df04eb2693117ca7/Sources/Pulse/Providers/KiroACPClient.swift).

## Data

Plan label, billing-cycle reset date and bounded credit/resource pools. Native `used`/`limit`, or explicit percentage with a limit, supply a clamped percentage. Unbounded overage and missing limits are excluded. The adapter labels the cycle monthly; a date-only reset does not establish a 30-day duration. No raw account identifier or account linkage is inferred.

- [Pulse@78eddaaf](https://github.com/qunqin24/Pulse/blob/78eddaaf9f19bc17c5a5446aee8d98724961b8f9/Docs/providers/kiro.md): owning-runtime ACP with CLI authentication; bounded resource pools and date-only reset. Its Kiro CLI 2.22.1 / ACP server 0.66.4 observation establishes reported-value compatibility in that reference, not ModelPlan runtime safety.
- [CodexBar@ee890b5f](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Kiro/KiroStatusProbe.swift): CLI usage reporting with separate usage-limits/auth machinery. Different HTTP or credential paths in the reference are not adopted by this ACP reader.

## Candidate paths

| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |
| --- | --- | --- | --- | --- | --- |
| Owning Kiro ACP | R | runtime | Kiro extension; version/capability dependent | Initializes authentication; inner behavior unknown | Chosen outer protocol; side-effect qualification incomplete |
| Borrow saved login / direct limits HTTP | L → H | O | Separate compatibility interface | Extracts credential; may add refresh logic | Rejected for this scope |
| Chat or terminal usage scraping | R / terminal | runtime | Different commands | Could create sessions or turns | Rejected; no session/prompt request |

## Incidents and pitfalls

- The pinned Pulse ACP client waits for `initialize`: its comment says authentication installs its connection while that request completes. Sending usage first races that setup. → [TestKiroUsageOverACP](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/kiro_test.go) (`TestKiroUsageOverACP`) checks ordering/arguments only.
- Kiro's current V3 guide requires advertised capability negotiation rather than inferring support from a version or fixed catalog. The reference notes usage was not advertised in its tested extension list. ModelPlan's direct call can fail on a changed version. → [TestParseKiroFailures](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/kiro_test.go) (`TestParseKiroFailures`) is a parser seam, not a live-version guarantee.

## Choice

- R/runtime, standard pre-selection **only after** a side-effect review. The compiled runtime definition currently has `defaultCheck: true`; this card does not establish the missing versioned safety proof. Display: “Read by Kiro's own runtime”.
- The CLI owns authentication; ModelPlan does not read its token database or send a prompt. This does not prove the CLI cannot refresh or write.
- Licence: `kiro.go` attributes an existing Apache-2.0 Pulse port at the full pin above. This documentation introduces no code, fixture, dependency or licence change; preserve that attribution. CodexBar is comparison-only.

### Fixed request set and runtime side-effect review

Executable selection: absolute `MODELPLAN_KIRO`, PATH, then supported install locations. Invocation is `kiro-cli acp --agent-engine v3 --auth-method cli` on private stdio.

| Call | Parameters / purpose | Refresh, writes or paid/state effects |
| --- | --- | --- |
| `initialize` | protocolVersion 1, empty clientCapabilities, fixed clientInfo | Auth connection setup is known; renewal, config/credential writes and prompts are unproved |
| `_kiro/account/getUsage` | empty params | Returns usage; vendor calls/retries, renewal and internal state writes are unknown |

Runtime version reviewed: **none installed or observed**. Reference compatibility version: Kiro CLI **2.22.1**, ACP server **0.66.4**, reported by Pulse; it is not a safety-reviewed executable/hash. Official V3 documentation leaves access-token requests to the CLI for CLI-owned authentication. No official no-refresh mechanism was established for these calls. ModelPlan sends no `authenticate`, session/new, session/prompt, model-selection, login/logout or mutation command. Absence of those outer methods does not prove no paid/background work inside the runtime.

Outer request set: two RPCs, one data query; no HTTP method/host/path/header pin inside the child is known. `askKiro` has a 40-second parent deadline, a 4-MiB scanner-line bound and kill/reap cleanup. Normal native cadence is ten minutes with a thirty-minute error wait, plus the shared provider reservation. The first terminal RPC/protocol failure ends this sequence. Inner HTTP 401/403, redirects, cumulative request count and lasting auth stops are not observable in the process fake.

## Tests

- Fixtures: [TestKiroUsageOverACP](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/kiro_test.go) (`TestKiroUsageOverACP`), [TestParseKiroFailures](https://github.com/modelplan/modelplan/blob/61ef253f0667a5e10a2c438212757775e116559a/cli/internal/quota/kiro_test.go) (`TestParseKiroFailures`); production scheduling/admission remains shared code.
- Red lines: the recorded method list excludes prompts/sessions and credential extraction by ModelPlan. It does **not** observe runtime filesystem/Keychain writes, token refresh or vendor traffic. `kiroReason` also returns unknown runtime error text unchanged; it can enter the native error/cache surface. Complete hostile-error canary coverage is missing.
- Owner-shaped case: exact executable/version/hash, all supported authentication states, initialization versus usage errors, expired login, old/new ACP capability sets, EOF/timeout, concurrent shared-home clients, revoke and reset.
- Required seam: recorded child RPC **plus** native credential/config/Keychain write and prompt events and vendor-network recording at initialization and usage. Include expired-login and error-path canaries. Current outer fake supplies none of that inner proof.

## Known gaps and unknowns

P1 runtime side-effect and error-output gaps are reported for coordinator routing. No installed runtime is certified; no general no-refresh, no-write, no-paid-call or two-vendor-request proof exists here. Owner-shaped L2, native prompts, live vendors and L3 are not-run. Unknowns remain unknown; this card is not permission to promote the path.
