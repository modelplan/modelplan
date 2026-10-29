<!-- SPDX-License-Identifier: MIT -->
# Gemini Code Assist reader card

**Status: POST request set approved as pinned, revision 1, 2026-10-29.**
Owner approval covers only the methods, authorities, paths and closed body schemas
below. This documentation does not change the compiled policy or grant user consent.
The saved-login scope remains O-class, standard and not pre-selected
(`defaultCheck: false`); a user opts in per scope. Runtime enablement and its
recording-transport verification are a separate wired change.

- Client source: [gemini.go at d9d1f01e17e96dcced1802debe230856154f20a1](https://github.com/modelplan/modelplan/blob/d9d1f01e17e96dcced1802debe230856154f20a1/cli/internal/quota/gemini.go). These reader bytes also match the U2a gate handoff; [PolicyPending at d36622f](https://github.com/modelplan/modelplan/blob/d36622f1789300b109c4bb31aacc9d33de608416/cli/internal/quota/admission_policy.go) is the historical veto entry point.
- Vendor source: Gemini CLI [server.ts](https://github.com/google-gemini/gemini-cli/blob/363a13119a57354f469732577518b9d6b319d1d6/packages/core/src/code_assist/server.ts), [types.ts](https://github.com/google-gemini/gemini-cli/blob/363a13119a57354f469732577518b9d6b319d1d6/packages/core/src/code_assist/types.ts), commit `363a13119a57354f469732577518b9d6b319d1d6` (Apache-2.0).
- References compared: [CodexBar GeminiStatusProbe](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Gemini/GeminiStatusProbe.swift), `ee890b5f392e70d6e20162d3e95cf9f1be265b60` (MIT); [Pulse GeminiUsageService](https://github.com/qunqin24/Pulse/blob/7668384cbcf357bba7dee4af85b4052a59c6e35d/Sources/Pulse/Providers/Profiled/GeminiUsageService.swift), v1.12.4, `7668384cbcf357bba7dee4af85b4052a59c6e35d` (Apache-2.0).

## Data

The required capability is **account/project quota**, plus a separately labelled
credit balance when explicitly supplied. Token history is a different capability.

| Source | Read path and authentication | Data and limits of the comparison |
| --- | --- | --- |
| Vendor Gemini CLI | H/O, `loadCodeAssist` and `retrieveUserQuota` through POST | Typed project/tier/credits and model/token buckets. `onboardUser`, generation and metrics are separate RPCs. The vendor client also has retries/auth machinery; ModelPlan does not inherit them. |
| CodexBar, pinned above | H/O, the same two POST methods | Project/tier and quota; additional refresh/project-discovery paths exist. Those paths and its model-family aggregation are excluded from this proposal. |
| Pulse, pinned above | H/O, the same two POST methods | Saved access token; project/tier, per-model fractions/resets. Its [provider note](https://github.com/qunqin24/Pulse/blob/7668384cbcf357bba7dee4af85b4052a59c6e35d/Docs/providers/gemini.md) explicitly labels evidence as second-hand fixtures. Best-effort continuation and inferred daily sorting are not adopted. |

### Response fields retained by ModelPlan

| Response field | Use and retained form |
| --- | --- |
| `loadCodeAssist.cloudaicompanionProject` | String, or compatibility object `id`/`projectId`; validated project selector. Raw value stays transient; only its keyed hash is persisted. A configured selector must match the returned selector. |
| `currentTier.id` | Only the compiled `free-tier`, `legacy-tier`, `standard-tier` mapping becomes a stable plan label. Unknown/missing tiers fail closed; no replacement project/tier is invented. |
| `currentTier.availableCredits[]`, `paidTier.availableCredits[]` | Fields `creditType`, `creditAmount`; paid-tier array takes precedence when present. Only one valid integer `GOOGLE_ONE_AI` amount in 0–1000000000000 is retained as credits, never USD, with its original metadata capture time. |
| `buckets[].modelId`, `tokenType` | Validated model label and known token/request unit. No inference of another model, pool or daily window length. |
| `buckets[].remainingFraction`, `resetTime` | Valid fraction becomes observed used percent; reset is preserved when valid. Missing duration remains unknown and expired windows are omitted. |
| `buckets[].remainingAmount` | Retained as remaining request count only when the bucket explicitly says `REQUESTS`; no invented used/limit counter or monetary conversion. |

Responses are capped at 1 MiB and quota at 128 buckets. Other response fields and raw bodies are not retained. Observation time is the
client's capture time, not an invented vendor timestamp. A local ID-token subject
may produce a keyed account binding; the ID token, subject and email are not sent
in either body or persisted as raw identity.

## Candidate paths

| Path / scope | Carrier | Auth / route | Tier | Endpoint status / side effects / red-line check |
| --- | --- | --- | --- | --- |
| `gemini.account_usage.saved_login` | H, using a local JSON login | O / `saved_login_api` | Standard, **unchecked** if approved; currently disabled | Private compatibility RPC. Exact POST set below needs owner approval. Server-side effects remain unverified. |
| `gemini.local_history` | L, local session JSON/JSONL | none / `local_log` | Standard, pre-selected subject to its own consent | Existing local token history; no remote account quota. Remains independent of this decision. |
| Gemini API-key / Vertex route | H | K, different service/product | Separate potential scope, not proposed | Not equivalent to this saved-login quota. No fallback to paid generation, token counting or API-key probing. |
| Launch Gemini CLI for quota | R | runtime | Not admitted by this card | No reviewed no-refresh RPC contract here; launching an auth-capable CLI is not proof of no token refresh/state write. |
| GET project/service quota APIs or browser scraping | H or W | Different authority/capability | Not proposed | No equivalent per-model Code Assist GET established; scraping is forbidden. No project enumeration or browser scan. |

## Exact POST request pin

Both requests use HTTPS, the compiled host below, no query parameters and no
redirect following. Header **names only** are listed; no header values or tokens
are reproduced. The access token comes from the admitted Gemini-owned
`oauth_creds.json`; expiry/auth-mode checks precede any eligible request. A login
file can contain other credentials, but no refresh-grant operation is used.

| Slot | Method | Host | Path | Application-set header names |
| --- | --- | --- | --- | --- |
| G1, cold metadata | POST | `cloudcode-pa.googleapis.com` | `/v1internal:loadCodeAssist` | `Authorization`, `Content-Type`, `Accept`, `User-Agent` |
| G2, quota | POST | `cloudcode-pa.googleapis.com` | `/v1internal:retrieveUserQuota` | `Authorization`, `Content-Type`, `Accept`, `User-Agent` |

Standard Go HTTP framing can additionally supply `Host`, `Content-Length`, and
`Accept-Encoding` when compression is enabled; HTTP/2 uses its corresponding
pseudoheaders. Proxy/TLS configuration is inherited, not a destination override.
No cookie jar, browser data or credential-carrying redirect is used.

### G1 body: closed schema

```json
{
  "type": "object",
  "required": ["mode", "metadata"],
  "additionalProperties": false,
  "properties": {
    "mode": {"const": "HEALTH_CHECK"},
    "metadata": {
      "type": "object",
      "required": ["ideType", "pluginType"],
      "additionalProperties": false,
      "properties": {
        "ideType": {"const": "GEMINI_CLI"},
        "pluginType": {"const": "GEMINI"}
      }
    },
    "cloudaicompanionProject": {
      "type": "string",
      "pattern": "^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,199}$"
    }
  }
}
```

Every field's origin: `mode`, `metadata.ideType`, and `metadata.pluginType` are
compiled constants. The optional `cloudaicompanionProject` is the validated
`GOOGLE_CLOUD_PROJECT`, else `GOOGLE_CLOUD_PROJECT_ID`; it is omitted when neither
is configured. No workspace, prompt, file content, user email, refresh token,
client secret, platform field or additional metadata is sent. The project
selector itself leaves the machine for Google; hashing it on disk does not hide
that request field from Google.

### G2 body: closed schema

```json
{
  "type": "object",
  "required": ["project"],
  "additionalProperties": false,
  "properties": {
    "project": {
      "type": "string",
      "pattern": "^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,199}$"
    }
  }
}
```

`project` is G1's validated selector, or the validated configured selector when
G1 does not yield one. On a warm read it is the same-binding transient selector, or a
matching configured selector recovered against the saved keyed hash. A changed
selector forces G1 within the same budget. An unresolved selector prevents G2;
there is no empty-body quota attempt or discovery fallback. The vendor schema's
optional `userAgent` body field is not sent.

## Why not GET; read-only evidence

The pinned vendor implementation routes both methods through `requestPost`;
`retrieveUserQuota` has no GET branch. Both monitor references also use POST for
this capability. The vendor's operation-polling GET is for a different resource,
not a quota GET. No equivalent GET is established by these reviewed sources;
this is not proof that no undocumented or future GET could exist. Changing only
the HTTP method would create a different, unapproved request.

The vendor uses `loadCodeAssist` with `HEALTH_CHECK` to refresh displayed credit
information, and exposes quota retrieval separately from onboarding, inference
and metrics submission. These are evidence of **read intent**, not a server-side
no-write/no-charge guarantee. The proposed bodies contain no generation input,
onboarding command, purchase or reset-credit instruction. ModelPlan's call graph
has no inference, project enumeration, OAuth refresh or automatic migration call.
Unknown: backend provisioning/session/audit writes, service-quota consumption,
billing treatment and current account eligibility. No live account or quota
endpoint was probed for this card.

## Read shape and budget

A cold logical read is **G1 then G2, at most two requests**; any G1 error or invalid
project/tier ends it. A warm read is **G2 only**. Metadata lasts at most 24 hours;
credential/project switches or a restart without a recoverable selector require
a cold read, not extra requests. Both calls share the managed read's 20-second
deadline. No retries or alternate hosts/methods are added.

Admission must reserve the shared vendor/provider budget before credential I/O:
at least five minutes across CLI/plugins/app and profiles. Unchanged successful
reads stretch to 10/15/30 minutes; failures back off to 10/20/40/60 minutes, with a
longer valid `Retry-After` honored. Forget/reconnect must not erase the reservation.
HTTP 401/403 aborts the current logical read before another endpoint is called.
**Limit:** the reviewed scheduler can retry a later logical read after backoff;
a durable scope stop until explicit recovery is not demonstrated. This does not
satisfy an unqualified cross-read reading of the stop-on-401/403 red line.

## Incidents and pitfalls

- [Google's consumer-account deprecation notice](https://developers.google.com/gemini-code-assist/docs/deprecations/code-assist-individuals), checked 2026-10-29: reports consumer Gemini CLI access ended on 2026-06-18. The compiled tier labels alone are not current service eligibility proof. Existing-account eligibility and [the separate Standard/Enterprise lifecycle](https://docs.cloud.google.com/gemini/docs/release-notes) require review; no automatic Antigravity migration is proposed. Fixture needed: consumer shutdown/unsupported-client never becomes a valid quota or a new grant.
- [CodexBar's pinned probe](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Gemini/GeminiStatusProbe.swift) contains token-refresh/project-discovery behavior outside this set. Fixtures: `TestGeminiUnsupportedLoginsMakeNoRequests`, `TestGeminiNoProjectEnumerationOrUnknownTierFallback`; do not port those extra paths.
- [Pulse's pinned provider](https://github.com/qunqin24/Pulse/blob/7668384cbcf357bba7dee4af85b4052a59c6e35d/Sources/Pulse/Providers/Profiled/GeminiUsageService.swift) can continue after some metadata failures. ModelPlan's proposed set stops on either auth code. Fixture gap: both HTTP codes at both slots, plus a subsequent refresh, recorded without fallback.
- Selector switch/restart must not mix account, plan or credit age. Existing fixtures: `TestGeminiProjectSwitchNeverSplicesOldScope`, `TestGeminiConfiguredProjectRecoversWarmReadWithoutPersistingID`, `TestGeminiSameExpiredGenerationRetainsOriginalCapture`.

## Red lines and tests

[Gate recording tests](https://github.com/modelplan/modelplan/blob/d36622f1789300b109c4bb31aacc9d33de608416/cli/internal/readers/admission_test.go), [production gate assertions](https://github.com/modelplan/modelplan/blob/d36622f1789300b109c4bb31aacc9d33de608416/cli/internal/readers/production_test.go), and [protocol fixtures](https://github.com/modelplan/modelplan/blob/d9d1f01e17e96dcced1802debe230856154f20a1/cli/internal/quota/gemini_test.go) are public. Tests below identify assertions, not a new certification by this docs PR. Recording method/host/path alone cannot prove filesystem, token, runtime or server-side behavior.

| Red line / forbidden event | Seam, failing example and evidence boundary |
| --- | --- |
| Never refresh/rewrite/revoke another tool's login | Record any OAuth token endpoint as forbidden; existing unsupported/expired-login fixtures make zero calls. Filesystem-write/process fakes for the complete approved path remain required. |
| Never persist/copy credentials | `assertGeminiCachePrivate` scans synthetic token/project canaries in ModelPlan caches; error-code tests reject raw text. A full cache/log/diagnostic/cockpit canary scan is not established here. |
| No inference/paid calls | `TestAdmissionRedLineUnapprovedPOSTMakesZeroRemoteCalls`: G1/G2 and GET bypass attempts yield zero recorded calls; unguarded negative control fails. Before enablement add closed-body assertions and rejection of generation/onboarding/metrics/extra-field/third-call requests. Server billing remains unknown. |
| Shared five-minute vendor budget | `TestGeminiBudgetMetadataCreditsAndCache`, `TestGeminiForgetReconnectRestartKeepsActualDispatchFloor`: recorded local-server path counts and persistent floor. Concurrent real app-server/CLI/plugin proof is an outstanding U14 case. |
| Stop on 401/403 | Current fixtures cover rejection/failure exit and no same-read fallback. Add recording cases for both codes at G1/G2 and a later scheduled read; durable cross-read stop is a known gap. |
| Detection reads presence only | `detect.TestPresenceOnlyAndUnknownSignals`; forbidden fixture is credential-content read or process launch during detection. HTTP recording cannot prove this. |
| No browser detection scan | `detect.TestPathRejectionAndSymlinkEscape` plus fake detector inventory; no browser route is proposed. Exhaustive browser-directory access recording is not claimed. |
| Store keyed hashes only | Existing cache privacy/account-project binding fixtures and identity module; raw subject/project in storage must fail a canary scan. Exclusive identity-write-path enforcement is not certified by transport tests. |
| Source and time on values | Bucket unit/reset and retained capture-age fixtures; source is `native:gemini`, route is `saved_login_api`. Nullable source/reset times must remain unknown. Final row/render time-unknown coverage belongs to U2/U14. |
| Fixed destinations, no credential redirect | `TestGeminiDoesNotForwardCredentialOnRedirect`: redirected target sees no token/request. Unapproved transport also rejects attempted GET substitution. |
| Vendor circuit breaker/readers off/revoke | Unsupported/passive/off fixtures, production catalogue restrictions, and `TestProductionPOSTGateOverridesSavedLoginConsent` / retained-capture suppression assertions. U14 shared-home completion is outstanding. |
| Keychain only via app identity/consent | This file-login scope has no Keychain or runtime fallback. A keychain/process fake should fail on any such access; transport recording does not certify its absence. |

The recorder deliberately excludes credential/header/body values. Approval-path
body tests must use synthetic requests and assert the closed schema separately.
Planned approval cases (not implemented/certified here): `G-POST-PIN` for G1/G2
method/authority/path/header-name/body-schema and cold/warm request counts;
`G-AUTH-STOP` for both auth codes at both slots and the next scheduled read;
`G-CREDENTIAL-CANARY` for the complete allowed-write/output surface. Each must
include a failing extra-field/extra-call/refresh or copied-token example.
No approved-POST transport/body-schema or live-server safety result is claimed.

## Choice

Approved capability and tier: the exact H/O saved-login request set above,
standard and unchecked (`defaultCheck: false`), subject to per-scope consent
and the shared admission/budget rules. Local history keeps its separate consent and does not
stand in for account quota. Reject token refresh, arbitrary selectors/hosts,
project enumeration, browser/CLI fallbacks and method substitution.

Licence: original card/schema analysis of the public client; no upstream code is
ported. Linked MIT/Apache-2.0 sources retain their notices and terms.

## Owner decision

Owner decision 2026-10-29: approved as pinned

Approved pin: revision 1 of this card and the client source
`d9d1f01e17e96dcced1802debe230856154f20a1` linked above. Approval covers only
the listed request set and body schemas. It does not grant user consent, change
the O-class unchecked default, waive red lines or establish L2 acceptance.
The tests and evidence gaps above describe the pinned review and historical
gate fixtures; the enabled production implementation is verified separately.
