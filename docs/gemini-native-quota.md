# Gemini CLI native quota (beta)

CLIJIT supplies the explicit shared saved-login grant and locally admitted profile
roots through `quota.Paths.ReaderAccess`. Existing connection settings alone do
not grant access. Consent: “Read Gemini CLI's saved access token and authenticate
to Google Code Assist for its account/project and quota.” Passive-only/off blocks
collection. Automatic CodexBar fallback remains off.

The file route reads only `~/.gemini/oauth_creds.json` and the selected auth type
in `settings.json`. `GEMINI_CLI_HOME` replaces the home prefix, so its root is
`$GEMINI_CLI_HOME/.gemini`, not the override directory itself. Multiple locally
admitted roots share one provider budget. Missing or unsupported credentials,
API-key/Vertex modes, custom Code Assist hosts/versions and the tool's selected
encrypted storage mode make no request. Secure-store-only logins are unsupported
in this file-reader version; a leftover file is not used when encrypted storage is
selected. No Keychain query, credential decryption/migration or CLI launch is tried.
Expiry uses a one-minute margin; the next step is **Open Gemini CLI to refresh**.

The compiled host is `https://cloudcode-pa.googleapis.com`. Cold reads have at
most two bearer-authenticated POST requests: `v1internal:loadCodeAssist` in
`HEALTH_CHECK` mode for the returned project/tier, then
`v1internal:retrieveUserQuota` for that project. There is no project enumeration,
onboarding, client-secret extraction, Google token refresh, inference, reset-credit
consumption, Antigravity fallback or additional endpoint attempt. No unknown
project/tier is replaced with an invented default. Redirects/cookie jars are
disabled; the App's injected proxy transport is preserved.

Stable same-credential project/tier metadata lasts at most 24 hours. Raw project
selectors stay in bounded transient process memory; persisted metadata contains
only their keyed hash. Before every reuse, the current selector is compared with the persisted scope and
transient project. A switched selector invalidates the old account and revalidates
project/tier in the first of the same two slots; a failed new scope cannot inherit
old quota, plan or wallet metadata. Transient metadata is published only after a
complete successful reading. A warm process, or a matching currently configured
`GOOGLE_CLOUD_PROJECT`/`GOOGLE_CLOUD_PROJECT_ID`, needs only the quota request.
After a process restart without a recoverable configured project, discovery takes
the second allowed slot again. This privacy constraint means such short-lived CLI
workers use two requests, rather than persisting a raw project identity to claim
one request. CLIJIT may retain a visible-session worker's transient context; it
must not persist raw selectors or bypass the five-minute floor.

Each model/token bucket stays separate. `remainingFraction` maps to observed used
percentage; the returned reset is preserved. A reset alone does not establish a
daily duration: window kind stays `unknown` (other) with a model/token label.
Explicit request `remainingAmount` maps only to `requests.remaining`; used and
limit stay unknown. Token counts without an established unit/shape are not guessed
as requests or money. No MCP quota is invented. An explicit empty bucket list is
not an unlimited plan; missing/malformed quota is unsupported. Expired windows
are omitted, including cached projections.

The first-party `availableCredits` shape maps only `GOOGLE_ONE_AI` integer
`creditAmount` into a separate credit balance (`unit=credits`,
`scope=google-one-ai`, no currency). Paid-tier credits take precedence when
present. Credit capture time is the metadata request's time and is not freshened
by a later quota-only read. Missing/unknown units never become zero or USD.
Account/project references use keyed hashes and opaque local subscription refs;
without usable local account metadata there is no fabricated verified binding.

Failures for the same binding preserve the last good reading and capture age.
Expired, malformed or unsupported changed bindings suppress the previous account
before returning, with no compatibility request. Effective account/source JSON
keeps `beta:true` for success, stale captures and unavailable states. Cross-process/profile
spacing is at least five minutes, with stable-source 10/15/30-minute cadence and
10/20/40/60-minute error backoff plus Retry-After. Forget/disconnect purges the
personal reading while preserving `observed/reader-attempts/gemini.json`, a
non-personal reservation containing only its next permitted attempt time. New
grants and process restarts cannot reset this floor. Ordinary/JSON rendering uses
ModelPlan cache only, without credentials/config/log reads or background work.

Protocol evidence: [Google Gemini CLI 363a131](https://github.com/google-gemini/gemini-cli/tree/363a13119a57354f469732577518b9d6b319d1d6/packages/core/src/code_assist)
(Apache-2.0; types, server, setup, OAuth routing and storage), its `utils/paths.ts`,
and CodexBar 0.81.0's GeminiStatusProbe (MIT). This is an independent implementation,
not vendored source or an auth-library dependency. Tests use handwritten fixtures,
synthetic homes/tokens and `httptest`, never real credentials or provider accounts.
CLIJIT owns command/consent wiring and the new `requests.remaining`/credit-scope
projection, beta label and reservation-preserving purge before enabling this
reader. The common foundation originates in PR225; the review fixes here add the
independent request reservation and effective beta projection.
