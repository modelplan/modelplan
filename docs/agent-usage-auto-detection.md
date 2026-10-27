<!-- SPDX-License-Identifier: MIT -->
# D590: automatic agent usage detection

**Design for owner review · updated 2026-10-27 · implementation awaits approval.**

Goal: recognise tools already used on the Mac without installing a ModelPlan status line, requesting a pasted API key, or installing another monitor. Use native readers for Claude Code, Codex, ZCode/GLM, Cursor, **Grok Build**, GitHub Copilot and Gemini CLI. For every other CodexBar-supported provider, automatically use the bundled, pinned CodexBar CLI **only when its tool is detected and no native reader exists**. Existing native readers remain preferred. Build on existing readers and [PR209](https://github.com/modelplan/modelplan/pull/209). Based on the supplied October 23 research and primary sources below; no real credentials or authenticated usage endpoints were accessed.

## Consent and shared rules

Discovery checks known executable/app/extension locations and file existence only: no launches, database/credential reads or Keychain access. “Detected” means installed/configured, **not signed in or subscribed**; successful authenticated responses confirm sign-in. First-run lists detected tools **pre-checked**, with the access lines below. **Allow selected tools** records one consent; **Not now** enables nothing. The screen also explicitly offers ongoing automatic detection of new tools within the same disclosed access classes; later detections use that grant only if enabled. A new access class requires consent expansion, not silent permission escalation.

Consent text: **“Allow ModelPlan to read usage for the selected tools using their existing sign-in, through native readers or the included CodexBar helper. CodexBar is downloaded automatically with a verified checksum; you do not install it. Your credential is sent to that provider to authenticate; it is never sent to ModelPlan servers or stored by ModelPlan. macOS may ask for Keychain access. You can turn this off in Settings.”** Show each detected tool's selected reader/access line; name CodexBar on bridge rows. Local-only accounting is marked as sending no credential.

- After consent, read only the selected profile's allowlisted fields. Keychain uses the genuine macOS prompt naming the helper; denial stops access. Background work cannot trigger interactive prompts. An invalidated grant needs an explained user action, never a prompt loop or permission workaround.
- Never refresh (even in memory), rewrite, move, delete or copy another tool's credentials into a store. No login/repair, settings changes, key/device-ID creation, inference, turns, warm-ups, reset-credit consumption or browser-cookie harvesting. Expired/rejected tokens mean `open <tool> to refresh`; reread after owner-tool state changes.
- One usage call/provider/**300 seconds minimum**, shared across processes, tools, manual refresh, resume, native and fallback. Persist a ModelPlan-owned attempt gate/lock; use monotonic timing and conservative restart/clock-rollback handling. Errors back off 10/20/40/60 minutes or longer `Retry-After`; authentication failures wait for tool-state changes. Nothing bypasses the five-minute floor.
- Reserve before I/O, failures included. Metadata consumes the same network budget; local RPC handshakes do not. No same-cycle endpoint/fallback waterfall. Allowlist HTTPS hosts/paths, reject redirects/custom destinations, bound reads/processes/responses. Refresh only while Dock/sliver or cockpit is visible and awake; preserve one child and read-only desktop reads.
- Secrets stay transient in memory, never output/logs/cache/receipts. Persist/display identities only as installation-keyed HMACs, separated by billing authority/region/account/workspace (common authority for a verified shared pool). No raw identities or plain hashes. Cache sanitised last-good readings with original age; errors never make them fresh. Account switches invalidate bindings. Passed resets, missing/stale/unbound readings and local token totals never imply fresh quota or entitlement.

## Hybrid routing and coverage

The native head is ordered below. For the remaining registry, detection + consent automatically selects CodexBar without setup commands, pasted keys or a user installation. Use `cli/internal/quota/codexbar-pin.json` (currently **0.81.0**, platform SHA-256 pins), the existing bounded fetch/cache, and the exact verified cached executable; ignore arbitrary PATH copies. Ship its MIT copyright/permission notice with the helper and in app notices. One provider per child, explicit source, bounded private JSON pipe; never `--provider all`. A native failure never silently launches the bridge. Existing native Kimi/other readers and local Qwen accounting are retained; do not replace them merely to increase bridge coverage.

Coverage is the **complete pinned CodexBar provider registry**, not today's five-entry `CodexBarProviders` map. Initial integration must expand that allowlist and audit each provider/source. CodexBar's ordinary `--source auto` can renew tokens, cache secrets, spawn helpers or perform multiple calls. A launch interval alone cannot enforce our safeguards. Require a tested read-only/one-request capability for each routed source; missing capabilities require an upstream-supported safe mode or a reviewed, attributed pinned compatibility build shipped through the normal CLI/app update. Do not claim the current generic flags provide that mode. Unsupported sources stay detected with an exact unavailable reason; never compensate with credential rotation, cookies, key entry or installs. This is a release dependency for broad automatic reading, not permission to weaken the safeguards.

## Provider plan, in implementation order

**Access** supplements shared consent; **S/M/L** estimates adapter work. Shared consent/scheduling/Keychain plumbing ships first with Claude.

### 1. Claude Code — M

**Detect/source:** `claude`, `~/.claude` or the configured `CLAUDE_CONFIG_DIR`; after consent, read its `.credentials.json` (`claudeAiOauth`) or macOS Keychain service `Claude Code-credentials`, respecting profile-specific naming. **Usage:** `GET https://api.anthropic.com/api/oauth/usage`, bearer plus `anthropic-beta: oauth-2025-04-20`; existing grant needs usage/profile access (`user:profile`). Scope: returned five-hour/weekly/model windows and extra spend, separately; compatibility endpoint, not Admin API. **Expiry:** check access-token expiry/scopes; apply shared backoff and owner refresh guidance. **Never:** install a status line, run `/usage`/`/status` in a PTY, use inference-only grants, read Claude Desktop cookies or rotate OAuth. **Access:** “Read Claude Code's saved sign-in, with a possible macOS Keychain prompt, and authenticate to Anthropic to read account usage.” [C]

### 2. Codex app / CLI / IDE — S; HTTP fallback M

**Detect/source:** Codex app, `codex`, known IDE extension manifests and `$CODEX_HOME`/`~/.codex` metadata. Prefer item 1's `codex app-server`: handshake, `account/read` with `refreshToken:false`, and `account/rateLimits/read`; credentials stay with Codex. Bind reported account/workspace; app, CLI and IDE may differ. If RPC is unavailable, a later budgeted attempt may read that home's `auth.json` OAuth access token and account selector. **Usage:** RPC windows/reset-credit inventory; fallback `GET https://chatgpt.com/backend-api/wham/usage` with matching account context. **Expiry:** stale HTTP tokens require opening Codex; no delegated renewal. **Never:** refresh-token exchange, external OpenCode auth import, account switching, separate reset-credit requests or consumption. **Access:** “Ask Codex for account usage using its sign-in; if needed, read its saved access token to authenticate to OpenAI.” [X]

### 3. ZCode / GLM — L

**Detect/source:** ZCode app/CLI and `~/.zcode/v2`; honour `ZCODE_DATA_BASE_DIR`. After consent, resolve selected family/plan in `setting.json`/`config.json`, then its account entry in `credentials.json` (versioned encrypted envelope); older `options.apiKey` mirrors require evidence they belong to the current account. **Usage:** selected Coding Plan key → `GET https://api.z.ai/api/monitor/usage/quota/limit` or mainland `https://open.bigmodel.cn/api/monitor/usage/quota/limit`; returned token/MCP windows only. Team selections need verified tenant selectors or remain unavailable. ZCode Start Plan JWT → `GET https://zcode.z.ai/api/v1/zcode-plan/billing/balance`, a separate balance, never GLM remaining quota. **Expiry:** reread current selection; fail closed on unknown encryption/schema or ambiguous account; owner refresh guidance on refusal. **Never:** key creation, stale-account fallback, sending a global key to China, or treating a generic API key as Coding Plan membership. **Access:** “Read ZCode's selected account credential and authenticate only to its matching Z.ai/BigModel service for quota or balance.” [Discovery][Z], [endpoint code][ZU]

### 4. Cursor — M

**Detect/source:** Cursor app and `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`; after consent, query only `ItemTable`'s `cursorAuth/accessToken`, read-only with bounded WAL handling. **Usage:** existing native reader's `GET https://cursor.com/api/usage-summary`; unified plans may instead use `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage`, with an in-memory derived session. Select one endpoint per slot; legacy `/api/usage` and plan metadata must wait for later slots. Scope is the signed-in user's returned included pool/spend, not a team Admin API. **Expiry:** reject expired/sealed tokens; open Cursor to refresh. **Never:** decrypt browser stores, query conversations, sum incompatible plan pools or retain the session. **Access:** “Read Cursor's saved sign-in and authenticate to Cursor for your account's usage.” [U]

### 5. Grok (Grok Build) — M; shared identity integration L

**Detect/source:** `grok` and `~/.grok/auth.json`; locally approved `GROK_HOME`/`GROK_AUTH_PATH` overrides only. Browser login is OAuth/OIDC via `auth.x.ai`; the issuer/client-scoped auth map stores `key`, `auth_mode`, `user_id`, principal/team context, creation and expiry. API-key mode also exists (`XAI_API_KEY`, legacy `GROK_CODE_XAI_API_KEY`, per-model config, or `xai::api_key` auth slot); it does **not** establish X Subscription entitlement. Respect selected per-model/auth mode; do not substitute a saved session for API-key mode. **Usage:** independently read the selected fresh first-party session and call `GET https://cli-chat-proxy.grok.com/v1/billing?format=credits`, using bearer, `X-XAI-Token-Auth: xai-grok-cli`, `x-userid` and required client metadata. This is the request behind the tool's `x.ai/billing` extension, forwarding to `GetGrokCreditsConfig`. Parse `creditUsagePercent`, `currentPeriod.{type,start,end}`, `isUnifiedBillingUser` and separate `prepaidBalance`; legacy monthly fields stay legacy. **Expiry:** enforce stored/JWT expiry conservatively; stale/unknown credentials mean `open Grok Build to refresh`. **Never:** launch its login/AuthManager, call external auth commands, refresh tokens, chmod/repair its files, change top-up controls or send an API key to this subscription route. **Access:** “Read Grok Build's existing session and authenticate to xAI for included usage and separate prepaid balance.” [Auth][GA], [request/types][GB], [dispatch][GD]

### 6. GitHub Copilot — S for CLI; L for IDE-only discovery

**Detect/source:** `copilot` or installed Copilot extension manifests. Reuse native `copilot --headless --no-auto-update --stdio`, negotiated handshake then **`account.getQuota`**, with runtime-owned authentication; no credential file is needed. **Usage/scope:** documented SDK server RPC, including premium-interaction entitlement/reset when supplied. **Expiry:** unavailable auth/capability → open Copilot to refresh; no session or login is created. IDE-only installation does not prove an installed CLI: selected extension credential-store compatibility remains unverified and must fail visibly, without asking users to install a runtime. **Never:** import an unrelated `gh` login, initiate device flow, use org billing APIs as personal quota, or invoke a turn. **Access:** “Ask your installed Copilot runtime to authenticate to GitHub and return account quota.” [G]

### 7. Gemini CLI — M

**Detect/source:** `gemini` and `~/.gemini`; after consent, fresh `~/.gemini/oauth_creds.json` access token/expiry (honour verified tool overrides). **Usage:** `POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota`; model bucket remaining fractions/reset, scoped to the OAuth Code Assist account/project. If project discovery requires `:loadCodeAssist`, that uses a separate budgeted slot; no Cloud Resource Manager account enumeration. API-key/Vertex modes and unsupported tiers remain separate/unavailable rather than inferred. **Expiry:** `expiry_date` safety margin, then open Gemini CLI to refresh. **Never:** Google OAuth refresh, extract client secrets, change login mode or substitute Antigravity. **Access:** “Read Gemini CLI's saved access token and authenticate to Google Code Assist for its account/project quota.” [E]

### 8. Kimi (existing native reader) — M

**Detect/source:** `kimi`, `~/.kimi-code`; after consent, fresh `credentials/kimi-code.json` plus existing `device_id` under that home. **Usage:** `GET https://api.kimi.com/coding/v1/usages`, with the required existing device headers; returned five-hour, weekly/monthly pools, not Moonshot API cash. Reuse the native parser. CLI credentials lack issuer provenance: China-only until verified otherwise; never send them to `api.kimi.ai`. **Expiry:** token expiry with safety margin, then open Kimi to refresh; missing device identity means unavailable. **Never:** create a device ID, renew rotating refresh tokens or import browser cookies. **Access:** “Read Kimi Code's existing sign-in/device identity and authenticate to Kimi China for Coding Plan usage.” [K]

### 9. Qwen Code (local accounting / supported bridge) — M local; L for backend quota

**Detect/source:** `qwen`, `~/.qwen/settings.json` and existing stats/project layouts. After consent, identify the selected backend; reuse bounded local aggregate/history readers. **Usage:** no verified universal Qwen Code remaining-quota endpoint. Local stats give observed tokens/model/day, not allowance. A recognised configured GLM/Kimi/etc. backend can use its own native adapter and shared provider budget only after credential/host provenance is established. QwenCloud/Alibaba subscription routes require separate contracts; browser-console cookies are excluded. **Expiry:** local capture age is shown; any supported backend token uses its provider's owner refresh guidance. **Never:** infer cloud quota from `oauth_creds.json`, equate different Qwen/Alibaba plans, or require an export command/install/key paste. **Access:** “Read Qwen Code's local usage; for a supported selected backend, use its existing credential to authenticate only to that provider.” [Q]

## Signed publication: declarative detector catalogue

Propose optional `client.data.detectors`, projected as `publication.detectors`, independent of reading implementations. The first supporting CLI/app release installs the evaluator, documented path/item allowlist and complete pinned CodexBar ID/capability registry. Later signed catalogue revisions can recognise new tools through already supported signals/readers; new reading code, signal semantics, protected roots, or a new CodexBar binary still require releases. No recommendation/scoring logic is added.

Example payload (illustrative, not published data):

```json
{
  "detectors": {
    "schemaVersion": 1,
    "revision": 1,
    "minEngineVersion": 1,
    "issuedAt": "2026-10-27T00:00:00Z",
    "expiresAt": "2026-11-26T00:00:00Z",
    "sources": [{
      "id": "codexbar-0.81.0",
      "repository": "steipete/CodexBar",
      "commit": "ee890b5f392e70d6e20162d3e95cf9f1be265b60",
      "license": "MIT",
      "noticeId": "codexbar-mit"
    }],
    "providers": [{
      "providerId": "claude",
      "displayName": "Claude Code",
      "sourceId": "codexbar-0.81.0",
      "detectionStatus": "signals",
      "upstreamPaths": ["Sources/CodexBar/SettingsStore+ProviderDetection.swift"],
      "anyOf": [
        {"type": "cliPresent", "name": "claude"},
        {"type": "appBundleId", "value": "com.anthropic.claudefordesktop"},
        {"type": "pathExists", "pathId": "claude.credentials"},
        {"type": "keychainItem", "itemId": "claude.code.credentials", "phase": "afterConsent"}
      ]
    }]
  }
}
```

Closed schema (`additionalProperties:false` throughout); typed required fields as shown, with per-signal provenance in `upstreamPaths`. Provider is a `oneOf`: `detectionStatus:"signals"` requires 1–16 signals; `"no-safe-signal"` requires zero signals and `reasonCode` from `web-only`, `no-local-artifact`, `not-yet-audited`. Signal objects are a closed `oneOf` of the four types below. IDs/names are bounded literals, never expressions. Bound the section to 256 KiB, 512 providers and 16 signals/provider; unique IDs, positive safe-integer revisions and UTC dates. `providerId` must match a release-known provider, not an arbitrary child argument. `sources` is attribution only and is never fetched/executed.

| Signal type | Allowed operation and boundary |
| --- | --- |
| `appBundleId` | OS application registration lookup for a bounded literal bundle ID; no app launch. |
| `cliPresent` | Locate/stat one validated basename in documented tool install directories/PATH; no shell, arguments, execution or login-shell discovery. |
| `pathExists` | Stat a **documented path ID**, not a server-supplied absolute/relative path. E.g. `claude.credentials` resolves to the tool-scoped `.credentials.json` path; `grok.auth` to approved Grok home/auth.json. No traversal, wildcards, directory scans or symlink escape. |
| `keychainItem` | An allowlisted service/account item ID, e.g. `Claude Code-credentials`; metadata-only and **after consent**, foreground if a prompt is needed. Never probe Keychain before consent or read a value merely to detect it. |

Port signals with per-entry CodexBar source commit/path and MIT attribution. [Pinned registry][CR], [chooser][CD], [licence][CL]. Audit **every** registry provider's descriptors, credential readers and locators, not only the first-run chooser: the pinned chooser explicitly detects four providers and defaults to Codex when none match; we do not port that false-positive default. Record `detectionStatus: "no-safe-signal"` with an empty `anyOf` and a reason for web-only/manual-key providers; this is the schema's explicit alternate provider shape, never an invented installed signal. A completeness check accounts for every pinned provider ID. Keychain-only rows remain unconfirmed before consent; other hints can pre-check them. Newly added app IDs/CLI names or combinations of existing path IDs need no release; a new filesystem/item permission outside the documented allowlist needs one.

**Trust contract:** verify the bounded manifest/signature before accepting the detector payload or probing. Retain existing publication ID/component hash/size/dependency checks, but these alone are **not** publisher signatures. Propose a manifest `signature` envelope `{algorithm:"Ed25519", keyId, value}` over domain-separated RFC 8785 canonical manifest bytes excluding `signature`, including all component hashes and publication ID. Verification keys and accepted algorithm live in released clients, never in the catalogue. Signed issuance/expiry plus monotonic revision high-water protect against rollback; use a verified last-good/bundled catalogue offline within validity, otherwise stop new probes. Invalid signatures, stale revisions, unknown keys/types/path IDs or unsupported engine versions cannot expand access; isolate the incompatible entry or reject the invalid catalogue. A release establishes this signed trust path before remote detectors are enabled. Publication production/signing machinery stays private; this note proposes only its public contract.

## One X Subscription, multiple tool readings

**Product scope:** the owner's October 16 data decision is confirmed by [xAI pricing][XP] and [usage limits][XL]: one included weekly pool per paid seat for eligible first-party Grok/Cursor usage. Additional Usage/prepaid credits are separate; third-party Cursor models do not consume included allowance. Legacy Cursor and SuperGrok plans continue separately. Team seats have separate included pools; shared team wallets are not a second included quota.

**Can both readers show it?** Yes, source contracts support that: Cursor's merged-plan path uses `get-plan-info` (`isMerged`, included period/reset) plus `GetCurrentPeriodUsage` (`planUsage.totalPercentUsed`); the existing native reader already separates it from monthly legacy usage. Grok Build's billing response carries `isUnifiedBillingUser`, included percentage and period/reset. Prefer the latter's current fields over legacy monthly budget fields. The owner's cited pager `dispatch/billing.rs` routes the UI result; the actual HTTP request and response types are in shell `extensions/billing.rs`, with production host in `xai-grok-env`. The pager's unknown-billing default is an upsell-copy policy, not unified-membership evidence: require an explicit true flag. This is source evidence, not a live-account pass. Grok API-key-only mode cannot supply the subscription meter. [Cursor source][CU], [Grok request][GB], [production host][GE]

**Identity and one `subscriptionRef`:** require provider-confirmed unified status **and** the same canonical billing principal/seat/pool ID, or a verified provider link mapping Cursor's account to the Grok principal. Hash the canonical tuple with the installation key under a common `x-subscription-seat` basis (tenant + seat + included-pool kind; **not** period/reset). Atomically map both source identities to **one existing opaque ref**, preserving settings/history through aliases. Today's separate `cursor-auth`/Grok-specific assignments would create different refs: reusing their different HMAC domains does not deduplicate anything. Keep legacy bases separate. One subscription card can then name both tools; one current included window is selected by authoritative scope and observation time, never summed or averaged. Show conflicting readings as a discrepancy, not additional capacity. Prepaid/Additional Usage is a separate meter on that subscription, deduplicated by its own wallet scope.

**Evidence limit:** the inspected Grok billing DTO contains no subscription/seat ID, and Cursor exposes its own `sub`; Grok auth has `user_id` and principal/team fields, but the source does not prove equality or a cross-product mapping. `isMerged`, equal percentages/reset dates, same email, or both apps being installed cannot prove they are the same subscription; xAI explicitly allows unifying accounts with **different emails**. A verified common-ID/link contract is therefore a Step B prerequisite for guaranteed automatic merging. Without it, label source evidence “shared-pool link unverified,” keep it out of additive subscription totals, and do not fabricate one verified ref or silently combine different accounts. If IDs prove distinct seats/legacy plans, keep separate subscriptions. [Account-unification rules][XU]

Coordinate both readers under one conservative xAI/Cursor request budget during link discovery, then one canonical shared-pool gate once linked; fetch **one** preferred route per five minutes (alternate only in a later slot). Metadata/link requests consume that same gate. Merging aliases merges attempt timestamps conservatively; account/workspace switches invalidate evidence. Never unify accounts at the provider, move tokens between tools, or use public catalogue metadata to assert personal membership.

## Feedback, review and delivery

Show **[Missing your tool? Tell us](https://github.com/modelplan/modelplan/issues/new?template=feature.yml&title=Tool%20detection%20request)** in onboarding, the empty state and Settings. Ask only tool name, platform and version; never attach credential paths/contents, identities, tokens or personal feed JSON automatically. Opening the form is explicit; submission is the user's action.

Review this note before Step B. Then one provider PR in the native-head order, titled **`[D590] Auto-detect <provider> usage`**; implementation still awaits note approval. Broad CodexBar safe-mode coverage, signed-catalogue verification and the shared identity contract are explicit integration dependencies. Tests use only synthetic homes, Keychain doubles, fake RPC and `httptest`: zero credential writes/refreshes, host/call budgets including bridge internals, pinned-helper checksum/notice, registry completeness, signature/rollback/path rejection, expiry/redaction/HMAC, link aliases across reset, different seats/legacy accounts, hidden/sleep suspension and last-good age. No real credentials or vendor usage calls.

## Evidence and licensing

Inspected CodexBar `0827f30…` and Token Monitor `0c7dd85…` root licences are MIT; Pulse **`fc10fb7f13999d16f27f283c4bd9e83c80a2885d`** is Apache-2.0. Borrow approaches, not code/fixtures/assets. Use Pulse's existence-only discovery, with the owner's pre-checked consent replacing its unchecked chooser; exclude rotation, device-ID creation and browser import. The detector port retains CodexBar copyright (Peter Steinberger, 2026) and full MIT notice in distribution; the signed catalogue references that notice. Grok Build first-party source at `2bdd1d6…` is Apache-2.0, ([licence][GL], [dependency/source-port notices][GN]). Any later substantial MIT reuse retains copyright/licence notices; Apache reuse also preserves applicable notices/attribution and marks modifications. Audit per-file/third-party terms; root licences do not grant provider API approval or branding rights.

Sources inspected 2026-10-27 (xAI product docs are live; code links pinned): [CodexBar licence][CBL], [Token Monitor licence][TML], [Pulse licence][PL] and [third-party notices][PN]; [Pulse discovery][PD]. Provider references:

[C]: https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/docs/claude.md
[X]: https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/docs/codex.md
[Z]: https://github.com/Javis603/token-monitor/blob/0c7dd855d3697ba0cd3ed47a3d52f8f187cc0e23/src/shared/providers/zai/zcodeDiscovery.js
[U]: https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/docs/cursor.md
[G]: https://github.com/github/copilot-sdk/blob/26536883459ba4cb23c735db8cb3de2c7b899d88/docs/features/usage-and-billing.md
[E]: https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/docs/gemini.md
[K]: https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/docs/kimi.md
[Q]: https://github.com/QwenLM/qwen-code/blob/5cb982da6a073ce967ae17f46ee106e968054c7f/docs/users/features/commands.md
[CBL]: https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/LICENSE
[TML]: https://github.com/Javis603/token-monitor/blob/0c7dd855d3697ba0cd3ed47a3d52f8f187cc0e23/LICENSE
[PL]: https://github.com/qunqin24/Pulse/blob/fc10fb7f13999d16f27f283c4bd9e83c80a2885d/LICENSE
[PN]: https://github.com/qunqin24/Pulse/blob/fc10fb7f13999d16f27f283c4bd9e83c80a2885d/THIRD_PARTY_NOTICES.md
[PD]: https://github.com/qunqin24/Pulse/blob/fc10fb7f13999d16f27f283c4bd9e83c80a2885d/Sources/Pulse/Providers/ProviderDiscovery.swift

[ZU]: https://github.com/Javis603/token-monitor/blob/0c7dd855d3697ba0cd3ed47a3d52f8f187cc0e23/src/shared/providers/zai/limits.js

[GA]: https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-pager/docs/user-guide/02-authentication.md
[GB]: https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-shell/src/extensions/billing.rs
[GD]: https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-pager/src/app/dispatch/billing.rs
[GE]: https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-env/src/lib.rs
[GN]: https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/THIRD-PARTY-NOTICES
[XP]: https://docs.x.ai/x-subscription/pricing
[XL]: https://docs.x.ai/x-subscription/usage-limits
[XU]: https://docs.x.ai/x-subscription/unify-accounts
[CU]: https://github.com/modelplan/modelplan/blob/7beebd1d9c3768569e08c22b4bde2dc5c81fc31f/cli/internal/quota/cursor.go
[CD]: https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBar/SettingsStore+ProviderDetection.swift
[CR]: https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/docs/provider-ids.md
[CL]: https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/LICENSE
[GL]: https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/LICENSE
