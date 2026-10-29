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
| `gemini.account_usage.saved_login` (**policy_pending**) | `cloudcode-pa.googleapis.com` | optional POST `/v1internal:loadCodeAssist`, POST `/v1internal:retrieveUserQuota` | 2 |
| `cursor.account_usage.saved_login` (**policy_pending**) | `cursor.com`, then `api2.cursor.sh` | optional POST `/api/dashboard/get-plan-info`, POST `/aiserver.v1.DashboardService/GetCurrentPeriodUsage` | 2 |

The POST pins are dormant. `CheckAdmission` rejects both scopes independently of
saved-login consent, before transport I/O; no runtime flag approves them.
Gemini load bodies contain only the fixed health-check mode, fixed IDE/plugin
metadata and an optional validated project selector. Quota bodies contain only
a required validated project. Cursor bodies are exactly `{}`. Unknown/duplicate
fields, null project/metadata, extra headers and unreviewed bodies are rejected.
Cursor's first authority allows its app-derived cookie and Origin; its second
allows bearer authorization and Connect version. Those credential headers cannot
be forwarded between its authorities. An owner policy decision is still required.
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
Historical Gemini/Cursor parser/identity fixtures explicitly bypass both policy
and transport admission in test code only. Strict production POST regressions
retain the unchanged policy and use valid synthetic logins and `ProductionPaths`.
Dormant POST schema tests validate the pins without approving either scope.

Run from `cli/`:

```sh
go test ./internal/readers/... ./internal/quota -count=1
go test -race ./internal/readers/... ./internal/quota -count=1
```

| Scenario | L1 evidence |
| --- | --- |
| U2a-POST | Production refresh/diagnostics emit zero calls, never schedule remote reads, suppress retained captures and report policy_pending. Valid synthetic logins prevent a missing-credential false pass. |
| U2a-AUTH | MiniMax production dispatch stops on 401/403 in both regions; every active HTTP reader's actual constructed client rejects subsequent requests. |
| U2a-LOCAL | Independent local-history admission remains eligible; the Gemini production history fixture retains seeded counts. |
| U2a-DESTINATIONS | Production off-host regressions failed before wiring. Actual clients reject excess calls, redirects and requests after auth failure. Fixtures verify expected positive requests and decoding. |
| U2a-POST-PINS | Closed body schemas, exact destinations and method, header whitelist, and Cursor credential separation are checked while admission stays pending. |

U14 completion still requires the real app-server constructor and an independent
CLI on one synthetic shared home: grant POST account scopes and local history,
require policy_pending/zero vendor calls, return MiniMax 401 and 403 separately,
and query retained local history. Cursor has a scope but no local count adapter
on this base, so that history capability is unsupported. Bind outcomes to the
source and packaged subject SHAs. These local tests do not claim that L2 result,
live vendor acceptance, native UI or L3 evidence.
