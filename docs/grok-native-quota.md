# Grok Build native quota (beta)

CLIJIT admits the detected tool through the single saved-login consent and passes
locally approved profiles in `quota.Paths.ReaderAccess`. Consent: “Read Grok Build's
existing session and authenticate to xAI for included usage and separate prepaid
balance.” Legacy connections alone do not authorize access; Passive-only/off
suspends collection. There is no automatic CodexBar fallback.

The reader selects only the production xAI issuer/client-scoped entry from
`~/.grok/auth.json`; `GROK_HOME` and absolute `GROK_AUTH_PATH` are respected. It parses
`config.toml` with pinned go-toml v2.2.4 (MIT notice shipped with the binary).
API-key-preferred, BYOK model catalogues with credentials, external helpers,
deployment keys, foreign/local issuers, unknown auth choices and forced/principal
configurations without an established selector contract return unavailable
without a request. No arbitrary scope/account search is performed. Environment
API keys do not override a fresh selected session unless the tool's auth selection
actually chooses API-key mode; they are never sent to the subscription endpoint.
Configured principal/team mismatches are rejected.

Supported saved sessions are `oidc`/first-party `external` with the exact xAI issuer.
Legacy web-login and API-key entries are not imported as subscription auth. The
earlier stored/JWT expiry wins, with a one-minute margin; unknown/expired lifetime
means **Open Grok Build to refresh**, not a fabricated 30-day lifetime. The reader
does not import the tool's AuthManager: its source shows refresh, chmod and recovery
writes even in some read paths. This implementation never refreshes, rewrites,
moves, copies, chmods or repairs credentials, executes helpers, opens Keychain or
browser data, starts Grok, or calls inference.

One admitted read makes one request:
`GET https://cli-chat-proxy.grok.com/v1/billing?format=credits`. It sends the selected
bearer, `X-XAI-Token-Auth: xai-grok-cli`, `x-userid`, and headless client metadata.
User-Agent identifies ModelPlan; the compatibility version is explicitly
`0.0.0-modelplan-native-beta`, not a claim to be an installed Grok version. The
injected proxy transport is preserved; redirects/cookie jars are disabled. HTTP
errors expose only safe state codes, never bodies or raw identities. A changed
credential store invalidates an in-flight reading.

`creditUsagePercent` plus `currentPeriod.type/start/end` defines the included pool:
weekly/monthly or an other labelled period. Unknown duration is not guessed.
Legacy `monthlyLimit`/`used` remain monthly USD-cent budget meters and never become
a unified weekly pool. Explicit `isUnifiedBillingUser:true` establishes shared-pool
eligibility; absent/false does not. No upsell default, plan name or matching reset
can establish membership.

`prepaidBalance` is a separate USD-cent balance (`currency=USD`, `unit=money`), and
on-demand used/cap remain a separate spend meter. The included weekly reset is
never copied onto a monthly/unknown spend cap. A present empty `Cent` object is
zero under the first-party proto contract; absent/null objects remain unknown.
No per-request/model/MCP allowance is invented. Valid wallet-only plans need no
fake percentage window. Expired windows are dropped while a separately captured
wallet remains accurately aged.

Eligible X Subscription results are labelled **Shared-pool link unverified** and
non-additive. Their Grok-specific subscription reference is separate from Cursor's
until a verified common seat ID/provider link exists. No alias is inferred from
email, local IDs, usage or reset coincidence. Cursor/Grok use the conservative
shared five-minute gate from PR227; merge this provider after that foundation.
That gate covers one whole native route, never a union of partial readings.

Profiles share the provider-wide five-minute floor, stable 10/15/30-minute cadence,
10/20/40/60-minute error backoff and Retry-After. Failed reads retain the last good
capture and age. JSON rendering uses sanitized ModelPlan cache only. Identities,
principals, teams, credential generations and profile paths persist only as keyed
hashes/opaque references. No raw project labels or identity strings are cached.

Source: [grok-build 2bdd1d6](https://github.com/xai-org/grok-build/tree/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8),
especially `xai-grok-login/{model,config,storage}.rs`,
`xai-grok-shell/src/extensions/billing.rs` and `xai-grok-http/src/lib.rs`
(Apache-2.0; protocol evidence, no copied code). The pager dispatch controls UI;
the shell extension defines the actual request and USD-cent response contract.
Fixtures are handwritten and tests use synthetic files/`httptest` only. CLIJIT
owns consent/commands and must consume the shared-pool and monetary DTOs before
enabling this reader. No local-history/speed files are edited.
