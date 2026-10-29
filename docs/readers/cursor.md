<!-- SPDX-License-Identifier: MIT -->
# Cursor reader card

**Status: POST request set approved as pinned, revision 1, 2026-10-29.**
Owner approval covers only the methods, authorities, paths and closed body schemas
below. This documentation does not change the compiled policy or grant user consent.
The saved-login scope remains O-class, standard and not pre-selected
(`defaultCheck: false`); a user opts in per scope. Runtime enablement and its
recording-transport verification are a separate wired change.

- Client source: [cursor.go at d9d1f01e17e96dcced1802debe230856154f20a1](https://github.com/modelplan/modelplan/blob/d9d1f01e17e96dcced1802debe230856154f20a1/cli/internal/quota/cursor.go). These reader bytes also match the U2a gate handoff; [PolicyPending at d36622f](https://github.com/modelplan/modelplan/blob/d36622f1789300b109c4bb31aacc9d33de608416/cli/internal/quota/admission_policy.go) is the historical veto entry point.
- Vendor source: [Cursor Admin API](https://cursor.com/docs/account/teams/admin-api), checked 2026-10-29. It documents team/admin-key APIs, not the private saved-login plan/period RPCs below. No public vendor implementation or no-side-effects contract for those RPCs was established.
- References compared: [CodexBar CursorStatusProbe](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Cursor/CursorStatusProbe.swift) and [app-auth adapter](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Cursor/CursorStatusProbe%2BAppAuth.swift), `ee890b5f392e70d6e20162d3e95cf9f1be265b60` (MIT); [Token Monitor probe](https://github.com/Javis603/token-monitor/blob/e1c393cca85668aaf5e52798a291277e34999dca/src/shared/providers/cursor/probe.js) and [auth source](https://github.com/Javis603/token-monitor/blob/e1c393cca85668aaf5e52798a291277e34999dca/src/shared/providers/cursor/auth.js), `e1c393cca85668aaf5e52798a291277e34999dca` (MIT).

## Data

The required capability is **the included account allowance for the vendor's
current period**, with plan cadence/reset. Token history, legacy request counts,
monthly additional spend and prepaid balance are separate capabilities.

| Source | Read path and authentication | Data and limits of the comparison |
| --- | --- | --- |
| Vendor Admin API | H/K, separate team/admin-key routes | Team usage/spend/administration; not a documented personal saved-login equivalent. Do not substitute its credentials or authority into this scope. |
| CodexBar, pinned above | H/O when app sign-in supplies the session; also has browser-origin C paths | GET usage summary, optional legacy requests and unified additional spend; POST sandbox/shared usage. Its broader waterfall and alternate credential paths are not adopted. |
| Token Monitor, pinned above | H/O for desktop token discovery; also accepts manually supplied session credentials | POST plan info and current-period usage, plus GET summary/user/request and extra dashboard calls. Its current-period parser distinguishes the included percentage from a misleading legacy monthly zero. Its credential persistence/self-sync are excluded. |

### Response fields retained by ModelPlan

| Response field | Use and retained form |
| --- | --- |
| Plan `isMerged` | Only an explicit true together with a weekly included period establishes unified membership. Missing/null/invalid/contradictory flags do not establish it. |
| `planInfo.includedUsagePeriod` | Only weekly/monthly enum values yield the compiled 10080/43200-minute cadence classification. This is the client's enum mapping, not a measured duration inferred from two timestamps. |
| `planInfo.includedUsageResetsAt`, `billingCycleEnd` | Epoch-millisecond numbers/numeric strings from 1000000000000 through 4000000000000 produce the optional reset; `billingCycleEnd` is the numeric fallback. A recognized RFC3339 `includedUsageResetsAt` is the final fallback. Missing reset stays unknown, never a made-up date. |
| `planInfo.planName` | Only a compiled known plan name becomes a stable label. A consistent merged weekly plan gets the compiled unified-plan label. Arbitrary vendor text is not retained as a label. |
| Period `enabled` | Explicit false prevents a usable reading; absent/null is not converted into a fabricated usage amount. |
| Period `planUsage.totalPercentUsed` | A valid finite 0–100 number or numeric string becomes the included used percentage, including an explicit zero. Missing/invalid values are unsupported, never zero. |

Each response is capped at 1 MiB. Raw response bodies and other plan/period fields are not retained. No money,
currency, request counter, model split, prepaid balance or organisation allowance
is derived from these fields. Capture time is the client's observation time;
reset time is separately nullable. Account/credential/profile bindings persist
as keyed hashes or opaque local references, not raw user IDs or tokens. A shared
pool remains unverified and non-additive; equal numbers do not link accounts.

## Candidate paths

| Path / scope | Carrier | Auth / route | Tier | Endpoint status / side effects / red-line check |
| --- | --- | --- | --- | --- |
| `cursor.account_usage.saved_login` | H; local S supplies the sign-in | O / `saved_login_api` | Standard, **unchecked** if approved; currently disabled | Two undocumented dashboard POSTs below. The derived cookie is app-login authentication, not a browser scan or class C. Server-side effects remain unverified. |
| `cursor.local_history` | Independent local-history scope | none / local route when implemented | Standard/pre-selected classification, separate consent | Scope identifier exists; this source base has no Cursor count adapter. Do not claim a working history query or substitute cloud quota for local history. Blocking the remote scope must not disable an implemented local path. |
| Legacy summary/request GETs | H | O or C according to credential origin | Separate capability, not selected here | Reviewed GETs exist, but do not establish equivalent unified/current-period included allowance. No method substitution or silent fallback. |
| Documented team Admin API | H | K | Separate explicit-key scope, not proposed | Different key, authority and team data. No new key collection or access is authorized by this card. |
| Browser-cookie import or scraping | H/C or W | Browser session | Advanced C requires a separate decision; W forbidden | No browser profile detection/import, scraping, or automatic bridge fallback in this proposal. |

## Exact POST request pin

Only the admitted profile's `ItemTable` key `cursorAuth/accessToken` in
`User/globalStorage/state.vscdb` is selected. The reader uses read-only/query-only
SQLite, validates the token's expiry and account subject, and derives its session
in memory. It never refreshes the login or copies it into a ModelPlan credential
store. Existing WAL/SHM behavior requires the filesystem evidence described below.

Both requests use HTTPS, the compiled authority/path, no query parameters and no
redirect following. Header **names only** are listed; no header values, cookie
contents or token examples are reproduced.

| Slot | Method | Host | Path | Application-set header names |
| --- | --- | --- | --- | --- |
| C1, cold plan metadata | POST | `cursor.com` | `/api/dashboard/get-plan-info` | `Accept`, `Content-Type`, `User-Agent`, `Cookie`, `Origin` |
| C2, period usage | POST | `api2.cursor.sh` | `/aiserver.v1.DashboardService/GetCurrentPeriodUsage` | `Accept`, `Content-Type`, `User-Agent`, `Authorization`, `Connect-Protocol-Version` |

C1 uses the session derived from the app's token and local token subject; C2 uses
the same saved access token. The cookie is not forwarded to C2, and C1 does not
send the authorization header used by C2. These are two deliberately pinned
authorities, not permission to follow a credential-carrying redirect between them.
Standard Go framing can also supply `Host`, `Content-Length`, and `Accept-Encoding`
when compression is enabled; HTTP/2 uses corresponding pseudoheaders. No cookie
jar or browser-derived headers are introduced. System proxy/TLS transport is
preserved without permitting a host override.

### C1 and C2 body: the same closed schema

Each sends an empty JSON object, `{}`. There are **no body fields**, no field
values from the user's account, and no optional additions:

```json
{
  "type": "object",
  "properties": {},
  "additionalProperties": false,
  "maxProperties": 0
}
```

Origin of the entire body: the compiled literal in `cursorJSON`, not caller
input. No user ID, email, prompt, conversation, model, budget mutation, purchase
or inference input is sent in the body. Authentication still leaves the machine
in the named headers; an empty body is not proof of zero server-side effects.

## Why not GET; read-only evidence

GET alternatives were reviewed rather than assumed absent. CodexBar uses
`GET /api/usage-summary`, legacy request usage, and
`GET /api/dashboard/v2/usage-status` for additional spend. Token Monitor's pinned
parser explains why a legacy monthly summary can show zero while a unified
weekly allowance is in use; it uses the current-period POST to obtain that
included percentage. Those GETs are not a proven equivalent of C1+C2 for the
capability above. The documented Admin API is a separate team/key interface.
No reviewed source establishes a personal GET replacement with the same fields,
units and reset semantics. This is not a claim that Cursor has no GET APIs.

The names and parsers indicate plan/status retrieval, and the bodies contain no
mutation or inference instruction. The ModelPlan call graph consists only of C1
and C2. This supports read intent, **not a vendor guarantee** about no state
change, billing, quota-meter increments, session last-use updates or analytics.
These undocumented RPCs may change. No live account or quota endpoint was probed
for this card, and a successful response would not by itself prove no charge.

## Read shape and budget

A cold logical read is **C1 then C2, at most two requests**. Any C1 error or
unsupported plan ends it; there is no legacy waterfall. A warm read is **C2 only**
while the credential/account binding, at-most-24-hour plan metadata and future
reset remain valid. A past reset or changed binding requires C1 inside the same
read budget. Both requests share the managed read's 20-second deadline.

The shared per-vendor/provider budget is reserved before credential I/O: at least
five minutes across profiles and CLI/plugins/app. Unchanged successes stretch to
10/15/30 minutes; failures back off to 10/20/40/60 minutes and honor longer valid
`Retry-After`. Cursor/Grok also use the existing conservative shared-pool floor;
this is not evidence of a verified common subscription. Forget/reconnect must
retain the non-personal reservation.

HTTP 401/403 ends the current logical read before another endpoint can be called.
**Limit:** the reviewed scheduler can retry later after backoff with unchanged
consent. A durable scope stop until explicit recovery is not demonstrated; the
unqualified cross-read stop-on-auth-failure red line remains an admission gap.

## Incidents and pitfalls

- [Token Monitor's pinned current-period parser](https://github.com/Javis603/token-monitor/blob/e1c393cca85668aaf5e52798a291277e34999dca/src/shared/providers/cursor/probe.js): a monthly summary/zero is not a unified weekly included allowance. Fixtures: `TestCursorPlanAndPeriodDoNotGuessLegacyUnits`, `TestCursorSchemasAndUnknowns`; reject silent unit/window substitution.
- [Token Monitor's pinned provider note](https://github.com/Javis603/token-monitor/blob/e1c393cca85668aaf5e52798a291277e34999dca/docs/providers/cursor.md) reports that its own read-only credential/title queries can rewrite the WAL index. That is evidence of a pitfall, not proof that ModelPlan's SQLite driver does so. `TestCursorReadOnlyAuthFormats` checks DB/WAL behavior; exhaustive SHM/write-event evidence on the actual driver remains required.
- [Token Monitor's auth source](https://github.com/Javis603/token-monitor/blob/e1c393cca85668aaf5e52798a291277e34999dca/src/shared/providers/cursor/auth.js) persists imported credentials. This is not ported or authorized. Credential canaries must fail on any ModelPlan credential copy/cache/log/error/cockpit output.
- Proto-style omitted/invalid membership flags and changed accounts must not inherit another plan or zero. Fixtures: `TestCursorOmittedPlanFlagRequiresExplicitPeriod`, `TestCursorMembershipRequiresExplicitConsistentFlag`, `TestCursorChangedUnsupportedBindingNeverInheritsQuota`.

## Red lines and tests

[Gate recording tests](https://github.com/modelplan/modelplan/blob/d36622f1789300b109c4bb31aacc9d33de608416/cli/internal/readers/admission_test.go), [production gate assertions](https://github.com/modelplan/modelplan/blob/d36622f1789300b109c4bb31aacc9d33de608416/cli/internal/readers/production_test.go), [protocol fixtures](https://github.com/modelplan/modelplan/blob/d9d1f01e17e96dcced1802debe230856154f20a1/cli/internal/quota/cursor_admission_test.go) and [SQLite fixtures](https://github.com/modelplan/modelplan/blob/d9d1f01e17e96dcced1802debe230856154f20a1/cli/internal/quota/cursor_test.go) are public. Their presence is not a new pass result from this docs PR. Transport recording cannot prove disk, browser, identity, renderer or vendor-side behavior.

| Red line / forbidden event | Seam, failing example and evidence boundary |
| --- | --- |
| Never refresh/rewrite/revoke the tool's login | `TestCursorReadOnlyAuthFormats` compares synthetic DB/WAL data; recording must reject any refresh/login endpoint. Full filesystem/SHM write-event audit remains outstanding. |
| Never persist/copy credentials | `TestCursorAdmittedReadBudgetIdentityAndCacheOnly` checks synthetic secrets in ModelPlan caches; sanitized error-code tests reject raw text. Full cache/log/diagnostic/cockpit canary scan is not established here. |
| No inference/paid calls | `TestAdmissionRedLineUnapprovedPOSTMakesZeroRemoteCalls` covers C1/C2 and GET bypass attempts; its unguarded negative control fails. Before enablement, enforce both empty-body schemas and reject other methods/hosts/paths/parameters or a third call. Server billing remains unknown. |
| Shared five-minute vendor budget | `TestCursorAdmittedReadBudgetIdentityAndCacheOnly` counts cold/warm calls; `TestXSubscriptionConservativeCrossProviderFloor` covers the extra pool floor. Cross-process real app-server/CLI/plugin proof is an outstanding U14 case. |
| Stop on 401/403 | Existing failure fixture exercises rejection exit. Recording cases for both codes at C1/C2 and a later scheduled read are still required; durable cross-read stop is a known gap. |
| Detection reads presence only | `detect.TestPresenceOnlyAndUnknownSignals`; a credential query or process during detection must fail its fake. HTTP recording cannot establish this. |
| No browser detection scan | No browser source is proposed; detector path/symlink tests are relevant. Exhaustive browser-directory access recording is not claimed. |
| Store keyed hashes only | Account/credential binding cache assertions and subscription identity tests; raw token subject or user ID in a store must fail. Exclusive identity-write-path enforcement is not certified here. |
| Source and time on values | Plan/period/expiry/retained-age fixtures; source `native:cursor`, route `saved_login_api`. Unknown reset remains nullable. Final row/render unknown-time proof belongs to U2/U14. |
| Fixed destinations, no credential redirect | `TestCursorDoesNotForwardSavedLoginOnRedirect`: redirected target receives no credential/request. C1/C2 authority and header separation must remain pinned. |
| Vendor circuit breaker/readers off/revoke | Unsupported/passive/off fixtures, production catalogue restrictions, and production POST-veto/retained-capture assertions. U14 shared-home completion is outstanding. |
| Keychain only via app identity/consent | This app-file scope has no Keychain, security-tool or runtime fallback. A fake must reject any such access; transport recording alone cannot prove its absence. |

The recorder stores method/host/path, excluding credential/header/body values.
Add synthetic request-body assertions rather than recording secrets. Planned
approval cases (not implemented/certified here): `C-POST-PIN` for both exact
requests, header-name separation, empty bodies and cold/warm counts;
`C-AUTH-STOP` for both auth codes at both slots and the next scheduled read;
`C-SQLITE-NO-WRITE` for DB/WAL/SHM write events; `C-CREDENTIAL-CANARY` for the
complete allowed-write/output surface. Include failing extra-field/extra-call,
SHM-write and copied-token examples. No
approved-POST schema/transport or live-server safety result is claimed.

## Choice

Approved capability and tier: exactly C1+C2, H/O, standard and unchecked
(`defaultCheck: false`), subject to per-scope consent and shared admission/budget
rules. A Cookie
header does not reclassify the app-owned sign-in as a browser-session grant.
Local-history consent remains separate and is never replaced by a remote reading. Reject credential persistence, browser import,
extra endpoint waterfalls, arbitrary destinations and GET substitution.

Licence: original card/schema analysis of the public client; no upstream code is
ported. Linked MIT reference code retains its own grant and notices.

## Owner decision

Owner decision 2026-10-29: approved as pinned

Approved pin: revision 1 of this card and the client source
`d9d1f01e17e96dcced1802debe230856154f20a1` linked above. Approval covers only
the listed request set and body schemas. It does not grant user consent, change
the O-class unchecked default, waive red lines or establish L2 acceptance.
The tests and evidence gaps above describe the pinned review and historical
gate fixtures; the enabled production implementation is verified separately.
