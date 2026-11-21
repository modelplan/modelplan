<!-- SPDX-License-Identifier: MIT -->
# Token Monitor ZCode sign-in port (D369)

Pinned upstream: Javis603/token-monitor, commit `9de6288ca4e9af091b42f979570f1408781f8419` (MIT, Copyright (c) 2026 Javis). Licence: `LICENSES/TokenMonitor-MIT.txt`; distribution entry `token-monitor` in `desktop/third-party/notices.json`.

Ported (JavaScript to Go, own code following the same behaviour) into `cli/internal/quota/zcode_login.go`:

- `src/shared/providers/zai/zcodeDiscovery.js`: the 3.12.3 kind-based family selection with the 3.11.x legacy fallback, the provider ids, the disabled-entry rule, the `enc:v1:` AES-256-GCM envelope and ZCode's `defaultCredentialSecret` derivation, the profile identity (`id` for a normalized profile, `user_id` for a zai document), the account key entry name, and the mirror fallback only while no identity is established.
- `src/shared/providers/zai/limits.js`: Coding Plan quota on the family's own host, Start Plan balance on `zcode.z.ai` with `X-Device-Mid` from `telemetry-state.json`, body code 401/403 as a rejected sign-in and code 500 as a state, and the balance buckets (`parseZcodeStartPlanBalances`: period by entitlement, same-name complete buckets added, daily only when uniform).

ModelPlan differences, and why:

- Opt-in scope `zai.account_usage.saved_login`, off by default (D240); Token Monitor reads the login automatically.
- Key first and exclusive: the sign-in is read only when no key route serves GLM. Token Monitor runs its key lane and ZCode lane in parallel and merges them; one source per row keeps two accounts from mixing.
- One request per read. A Coding Plan selection reads quota only, without Token Monitor's extra billing leg; a Start Plan reads billing only. No subscription list or finance report.
- A BigModel (mainland) sign-in is never sent to `zcode.z.ai` (an international host); Token Monitor sends every family's JWT there. An entry whose base URL names the other region is refused.
- The JWT's `exp` is checked before it is sent; an expired, missing or rejected credential is `login_expired` ("Sign in to ZCode again"). Token Monitor reports these as unavailable. A known account whose own key entry is missing is also `login_expired` (Token Monitor falls back to the billing leg).
- No keyed hash or account key derived from the credential is stored (Token Monitor keys its accounts and spend tracking on a hash of the token).
- Only `~/.zcode/v2` under the home directory; `ZCODE_DATA_BASE_DIR` is not honoured.
