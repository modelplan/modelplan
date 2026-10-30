<!-- SPDX-License-Identifier: MIT -->
# Reader admission and fixed request sets

Production account-usage readers create one `NewReadClient` per logical read.
It preserves the injected transport/proxy and timeout, removes ambient cookies,
and stops redirect following. Its `NewReadTransport` pins the request set,
serializes attempts and latches HTTP 401/403 or a redirect for the lifetime of
that read. Helpers share that transport; constructing another client to retry a
rejection would reset its budget and is forbidden.

| Scope prefix / route | HTTPS authority | Fixed requests, in order | Maximum |
| --- | --- | --- | --- |
| `minimax.account_usage.api_key` | `api.minimax.io` or `api.minimaxi.com` | GET `/v1/token_plan/remains`, optional GET `/v1/api/openplatform/coding_plan/remains` | 2, same selected region |
| `claude.account_usage.saved_login` | `api.anthropic.com` | optional GET `/api/oauth/profile`, GET `/api/oauth/usage` | 2 |
| `kimi.account_usage.api_key` | `api.kimi.com` or `api.kimi.ai` | GET `/coding/v1/usages` | 1 |
| `kimi.account_usage.saved_login` | `api.kimi.com` | GET `/coding/v1/usages` | 1 |
| `zai.account_usage.api_key` | `api.z.ai` or `open.bigmodel.cn` | GET `/api/monitor/usage/quota/limit` | 1 |
| `opencodego.account_usage.api_key` | `opencode.ai` | GET `/zen/go/v1/usage` | 1 |
| `grok.account_usage.saved_login` | `cli-chat-proxy.grok.com` | GET `/v1/billing?format=credits` | 1 |
| `gemini.account_usage.saved_login` | `cloudcode-pa.googleapis.com` | optional POST `/v1internal:loadCodeAssist`, POST `/v1internal:retrieveUserQuota` | 2 |
| `cursor.account_usage.saved_login` | `cursor.com`, then `api2.cursor.sh` | optional POST `/api/dashboard/get-plan-info`, POST `/aiserver.v1.DashboardService/GetCurrentPeriodUsage` | 2 |

The owner approved exactly the Gemini Code Assist and Cursor POST sets on
2026-10-29 as pinned in the [Gemini card](https://github.com/modelplan/modelplan/blob/9a5c61e6dfb95d5b1e67288da0a9db86a2addb08/docs/readers/gemini.md)
and [Cursor card](https://github.com/modelplan/modelplan/blob/9a5c61e6dfb95d5b1e67288da0a9db86a2addb08/docs/readers/cursor.md).
`CheckAdmission` permits only those compiled sets; this does not grant consent.
Both scopes remain O-class with `defaultCheck: false`, and users opt in per scope.
No runtime flag or catalogue field can expand a request set.
Gemini load bodies contain only the fixed health-check mode, fixed IDE/plugin
metadata and an optional validated project selector. Quota bodies contain only
a required validated project. Cursor bodies are exactly `{}`. Unknown/duplicate
fields, null project/metadata, extra headers and unreviewed bodies are rejected.
Cursor's first authority allows its app-derived cookie and Origin; its second
allows bearer authorization and Connect version. Those credential headers cannot
be forwarded between its authorities.
The independent local-history scopes remain eligible under their own consent.

All other paths, parameters, body-bearing GETs, authority overrides, extra header
names, repeated stages and excess requests fail closed. Regional requests never
switch hosts within a logical read. The MiniMax collector additionally restricts
legacy fallback to compatibility failures, never HTTP 401/403.

`quota.PolicyPending` is the veto consumed by production admission, scheduling,
cache projection and diagnostics. Consent, revocation, persistence and the shared
cross-process vendor budget remain the dispatcher's responsibility. The transport
stop lasts for one logical read; it does not prove a durable authorization latch
across later scheduled reads.

Codex and Copilot use installed-runtime RPC, with no ModelPlan vendor HTTP
client or credential. Their subprocess request sets are a separate boundary:
Codex initializes, reads rate limits and optionally reads account identity with
`refreshToken=false`; Copilot connects (or legacy ping), checks auth status, then
reads quota. HTTP transport tests do not certify the runtime's own network.

`readertest.Transport` records method, host and escaped path for every attempted
outbound request, including unexpected attempts. It opens no socket and keeps no
credentials, headers or bodies. Production-boundary tests inject it beneath the
client constructed by the actual reader. Other fixtures route the final socket
to localhost while retaining compiled production authorities above the guard.
Gemini/Cursor parser/identity fixtures retain the production admission and
transport guard. Actual-reader tests capture the production-created client,
check one guard and a shared 20-second deadline for the entire logical read,
and probe terminal auth/redirect stops at both request slots.

Run from `cli/`:

```sh
go test ./internal/readers/... ./internal/quota -count=1
go test -race ./internal/readers/... ./internal/quota -count=1
```

| Scenario | L1 evidence |
| --- | --- |
| U2a-POST | Presence alone emits zero calls. Per-scope opt-in produces only the pinned cold pair or warm usage request; revoke suppresses accounts. Fresh constructors and diagnostics preserve the shared budget. |
| U2a-AUTH | MiniMax stops on 401/403 in both regions. Gemini/Cursor stop after 401/403 or redirect at either slot; the production-created client refuses further requests. |
| U2a-LOCAL | Independent local-history admission remains eligible; the Gemini production history fixture retains seeded counts. |
| U2a-DESTINATIONS | Production off-host regressions failed before wiring. Actual clients reject excess calls, redirects and requests after auth failure. Fixtures verify expected positive requests and decoding. |
| U2a-POST-PINS | Only pinned methods/destinations/closed bodies/header names pass the guard. GET substitution, extra fields/headers/calls, off-host credentials and cross-authority Cursor headers fail before recording. |

The U14 provider-only executable keeps the real constructor/backend/guard and
records only fixed route labels and shape/credential-match booleans. Approved
scopes start unset and unchecked, then each explicit grant succeeds without
granting its peer. Each cold read produces a positive quota using its two pinned
requests. Independent CLI refresh retains all provider budget hashes, app-server
cooldown deadlines and raw call counts. Gemini and Cursor local history retain
identical positive typed values. The recorder independently rejects bad bodies;
a negative-control overlay removes the guard and changes a producer body, which
must fail the run. Linux execution is L1 engine evidence; dedicated device L2,
live vendor acceptance, native UI and L3 remain separate.
