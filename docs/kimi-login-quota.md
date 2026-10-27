# Kimi Code saved-login quota (beta, China only)

CLIJIT supplies the single saved-login grant and locally admitted roots through
`quota.Paths.ReaderAccess`. Consent: “Read Kimi Code's existing sign-in/device
identity and authenticate to Kimi China for Coding Plan usage.” Passive-only/off
blocks borrowed-login collection. Detection alone and existing connection settings
do not grant it. The legacy explicitly configured environment-key reader remains
available separately; a new grant selects the saved-login route rather than
silently falling back to that key or another region.

The login reader uses `~/.kimi-code/credentials/kimi-code.json` (or the literal
absolute `KIMI_CODE_HOME` root) and an **existing** `device_id` in that root. It never
creates/repairs a device ID. `access_token`/`expires_at` use the pinned credential
contract; expiry is epoch seconds with a one-minute margin. An earlier JWT expiry
also rejects the token. Expired/unknown lifetime means **Open Kimi Code to refresh**.
It never reads/uses the refresh token, imports browser cookies, refreshes login,
rewrites/moves/copies credentials or launches Kimi.

The credential file does not establish an issuing region. V1 therefore supports
China only and refuses international, API-key/web-token modes and all endpoint/
OAuth-host overrides **before a request**. It never sends this login to
`api.kimi.ai`, a configured arbitrary host or a Moonshot cash/billing endpoint.

One read makes one `GET https://api.kimi.com/coding/v1/usages` with bearer, the
known `X-Msh-Platform: kimi_code_cli` and the existing device ID. Client metadata
identifies ModelPlan; no hostname is read or stored and no installed Kimi version
is fabricated. The proxy transport is preserved. Redirects/cookie jars and extra
browser/subscription enrichment calls are disabled. A changed credential file
invalidates an in-flight reading.

The existing native parser maps explicit `limit_5h` to five-hour, `limit_7d` to
weekly, and `limit_month_total` to monthly. Returned duration/unit windows keep
their actual minutes; other durations retain an explicit label rather than being
discarded or called five-hour. Ratio/count responses stay in one reading. Source
counts without a proved request unit are not labelled request counts. No model,
MCP allowance, cash balance or unlimited plan is inferred. Missing/malformed quota
is unsupported, never zero. Current projections drop reset-past windows; the raw
sanitized capture remains available for history with its original age.

The new login and legacy explicit-key routes share one persisted provider attempt
gate across profiles, regions and processes. Neither source/account switches nor
disconnect/reconnect bypass it. The login route has a five-minute floor, stable
10/15/30-minute cadence and 10/20/40/60-minute error backoff plus Retry-After. The
existing key route keeps its 10-minute cadence/30-minute error wait under the same
minimum gate. The shared managed reservation in
`observed/reader-attempts/kimi.json` and Kimi's cross-source reservation both
survive Forget/reconnect/new grants/restart; preserve their union during
integration and personal-data purge. Same-generation failures retain the last good capture and its original age.
Credential generation is compared before expiry/JWT/device validation; changed
expired or unsupported logins (including a new token with no device ID) cannot
inherit the previous account. A missing device is never repaired. A new shared grant owns
the routing decision even if it is blocked; it does not trigger a legacy-key
fallback. `MODELPLAN_READERS=off` also stops legacy native collection.

The saved-login cache projection performs no credential/config/device read or HTTP request.
Only keyed credential/profile/account references and sanitized windows persist.
A valid local subject can establish a scoped China account reference after a
successful request; device identity alone never establishes a subscription.
Missing account identity stays unbound. No raw token, device ID or account is
printed, cached or emitted by diagnostics.

Evidence: [CodexBar 0.81.0 KimiSettingsReader](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Kimi/KimiSettingsReader.swift)
and UsageFetcher/Models (MIT), compared with the existing native parser's pinned
CodexBar/Token Monitor evidence. Undocumented compatibility routes remain beta;
this is independently implemented and does not copy code or upstream account
fixtures. Tests use synthetic files, JWTs/device IDs and `httptest` only. The
second lane's Kimi history files and all speed files remain untouched. CLIJIT
owns consent/commands and enables the new source only after the shared handoff.

Effective source/account JSON emits `beta:true` for successful, stale and unavailable
projections. CLIJIT must retain the route-aware projection and both provider gates.
