<!-- SPDX-License-Identifier: MIT -->
# D590: automatic agent usage detection

**Design approved in direction · coordinator corrections on 2026-10-27 · documentation revision before Step B.**

[Clients, readers and updates][ARCH] is authoritative (PR213, `docs/clients-and-readers`, reviewed through section 9, including the owner-approved access classes in section 4, at `5b71a37`). This note specifies FEEDFIX’s reader/catalogue contracts under it; it does not create a second client architecture.

Goal: recognise tools already used on the Mac without installing a ModelPlan status line, requesting a pasted API key, or installing another monitor. Use native readers for Claude Code, Codex, ZCode/GLM, Cursor, **Grok Build**, GitHub Copilot and Gemini CLI. **Automatic CodexBar fallback is OFF for all seven head providers.** Long-tail tools use the bundled helper only after class-appropriate consent and a passing safety audit of that exact provider/source/pin; standard routes also require local tool detection, while web-only advanced services use an explicit Add subscription action; unaudited routes are **“not yet supported.”** Catalogue `native | codexbar | off` preferences cannot bypass this admission rule. Build on existing readers and [PR209](https://github.com/modelplan/modelplan/pull/209). Based on the supplied October 23 research and primary sources below; no real credentials or authenticated usage endpoints were accessed. The owner-approved section 4 now permits audited read-only, no-quota CLI commands and separate advanced browser-session consent; those exceptions supersede the earlier blanket CLI/browser bans, while head automatic fallback remains off.

The [reader contract appendix](agent-reader-contracts.md) defines the pinned CodexBar field translations, every-provider daily upgrade gate and failure-state contract. It is part of this design, not an implementation or live-account acceptance claim.

## File boundaries and handoff

The following is the FEEDFIX/CLIJIT boundary for review. Proposed new paths are contracts for later PRs, not files created by this note. Neither lane edits the other's files opportunistically; shared changes land through the named owner.

| Owner | Files | Responsibility |
| --- | --- | --- |
| **FEEDFIX** | `cli/internal/quota/*` readers, registry, routing, provider caches/locks, additive monetary/count DTOs in `quota.go`, `identity.go`, `codexbar.go`/`codexbar_test.go` and fixtures | Native head, CodexBar fetch/invocation, `preferred` routing and typed fallback errors, one reading/ref per subscription, X Subscription identity aliases. The existing `connect.go` command/config code is the carve-out below; new reader policy belongs in FEEDFIX-owned `routing.go`, not concurrent edits to that file. |
| **FEEDFIX** | Proposed `cli/internal/keychain/*` | Fixed `/usr/bin/security` adapter for bounded presence/value operations; permission/result codes and injected-process fixtures. CLIJIT consumes the presence-only interface, never a password value. |
| **FEEDFIX** | Proposed `schema/detector-catalogue-v1.json`, `cli/internal/detectorcatalog/*`, `docs/detector-catalogue.md` | Schema/DTOs and pure validation, documented signal/path classes, attributed initial `seed.json` port covering every CodexBar provider. No machine probing, network sync or consent storage here. |
| **FEEDFIX** | `scripts/pin-codexbar.mjs`, `.github/workflows/codexbar-pin.yml`, `cli/THIRD-PARTY-NOTICES.md` reader notices | Daily CodexBar pin/contract/provider-signal review proposal; public standard runners. Published catalogue production stays with the existing publication owner, not in a new public publishing pipeline. |
| **CLIJIT** | Proposed `cli/internal/detect/*`, `cli/cmd/modelplan/*`, existing `cli/internal/quota/connect.go` until command/config extraction | Execute presence-only catalogue signals; `detect`, `connect --detected`, `disconnect`, `doctor --share`, `update`, plugin-install helper and command wiring. FEEDFIX does not edit this command/config carve-out. |
| **CLIJIT** | `cli/internal/connections/*`, consent-record package/store integration, `cli/internal/publication/*`, `cli/internal/digest/publication.go`, `schema/publication-v1.json` | Consent/revocation and shared state, consume/project the verified publication catalogue using FEEDFIX DTOs; expose reader status without duplicating reader logic. Any `reader/` consumption changes go through CLIJIT. |
| **App/client lanes** | Native Settings/first-run UI, plugin/Skill install/update surfaces | Present CLIJIT detection/consent/status; call the CLI. No quota reader or advice implementation in the App. |

**Interface:** CLIJIT hands FEEDFIX a validated catalogue revision/pin, detected tool/provider/profile IDs, consent generation/allowed source classes, effective privacy/denial state, proxy policy and invocation context. FEEDFIX exports reader capabilities plus a result containing a stable status/error code, selected reader/source, fallback reason, observation time, opaque `subscriptionRef`, confidence/freshness/billing mode/beta, chosen artifact/mapping version and next eligible attempt. No credentials or raw provider text cross into detection/doctor/UI. CLIJIT owns consent persistence and revocation orchestration; FEEDFIX exposes cancellation/cache-purge hooks and rejects stale consent generations before publication. Both use the existing shared data directory; only FEEDFIX writes provider readings/attempt gates. Shared files are versioned/additive; unknown fields do not break older CLI copies.

## Consent and shared rules

CLIJIT detection checks presence only: app IDs, approved paths, Keychain item names and CLI locations; no launches, credential values, database contents or network calls. A name-only probe that cannot run without a prompt remains unknown. “Detected” means installed/configured, **not signed in or subscribed**; successful authenticated responses confirm sign-in. First-run lists detected **standard** tools pre-checked and browser-session candidates in a separate **advanced, unchecked** group. The one-click action grants standard tools only; each browser-session provider needs its own full explanation and confirmation. API-key-only/not-read **helper paths** are not offered; eligible native heads remain listed independently. **Allow selected standard tools** records the shared standard consent; **Not now** enables nothing. A tool found later is offered separately by an App badge or one-line CLI hint; earlier choices are never re-asked. CLIJIT owns consent records and `disconnect <tool|--all>`/Forget readings revocation and deletion.

Standard consent text: **“Allow ModelPlan on this macOS user account—App, plugins and all CLI copies—to read usage for the selected tools using their existing sign-in, through native readers or the included CodexBar helper. CodexBar is downloaded automatically with a verified checksum; you do not install it. Your credential is sent to that provider to authenticate; it is never sent to ModelPlan servers or stored by ModelPlan. macOS may ask for Keychain access. You can turn this off in Settings.”** Show each detected standard tool's selected reader/access line; name CodexBar on bridge rows and state that standard helper reads disable Keychain/browser-cookie decryption. Local-only accounting sends no credential. Advanced browser consent is separate: it explains the genuine browser Safe Storage prompt, its wider saved-sign-in scope, CodexBar's session-cookie cache, provider authentication and provider-scoped Forget cleanup; see the [full access-class contract](agent-reader-contracts.md#codexbar-access-classes--complete-0810-inventory).

- After the applicable consent, read only the selected profile’s allowed fields. For **our own native readers**, on macOS FEEDFIX invokes **`/usr/bin/security`** directly with fixed argument arrays (`find-generic-password`, the selected service/account, `-w` for the authorised value read), no shell or alternative binary. The `/usr/bin/security` rule applies to our readers only; the verified CodexBar helper may use its own Keychain APIs under advanced consent. Capture native security-command stdout only in bounded private memory; never forward/log it or credential-bearing stderr. Show the genuine macOS prompt; “Always Allow” applies to Apple’s stable binary rather than each ad-hoc CLI. Deny is persisted for that tool/source by CLIJIT across every CLI copy; it is **never automatically re-prompted**, including after restart, update, rename or fallback. Only an explicit Settings Retry permits another interactive attempt. No `dump-keychain`, whole-store scans or prompt loop; background refresh never starts a new interactive grant. [Upstream security reader][SEC]
- Never refresh (even in memory), rewrite, move or delete another tool's credentials. Native/standard readers never persist a borrowed credential; only separately enabled browser-session mode may cache the selected provider's session cookie in CodexBar's own cache, as explicitly explained. No login/repair, settings changes, key/device-ID creation, inference, turns, warm-ups or reset-credit consumption. Audited read-only, no-quota provider CLI commands are allowed; a launch alone is not proof of safety. Detection never scans browser data. Expired/rejected tokens mean `open <tool> to refresh`; reread after owner-tool state changes.
- One **provider read** per **300 seconds minimum**, shared across processes, tools, accounts, manual refresh, resume, native and admitted bridge paths. A read is one bounded transaction producing one consistent reading, not one HTTP request. Persist a ModelPlan-owned attempt gate/lock; use monotonic timing and conservative restart/clock-rollback handling. Errors back off 10/20/40/60 minutes or longer `Retry-After`; authentication failures wait for tool-state changes. Nothing bypasses the five-minute floor.
- Reserve the read before I/O, failures included. Its endpoint allowance is fixed below; no automatic HTTP retries, same-cycle source waterfall or requests beyond that allowance. Local RPC handshakes do not consume HTTP allowance. Allowlist HTTPS hosts/paths, reject redirects/custom destinations, bound reads/processes/responses. App-scheduled refresh runs only while Dock/sliver or cockpit is visible and awake; preserve its one-child scheduler and read-only desktop reads. Standalone/plugin requests use the same CLI consent and provider gates without requiring the App to be open.
- Secrets never enter ModelPlan output/logs/config/cache/receipts. Native/standard secrets stay transient; the separately consented advanced CodexBar cookie cache is the sole documented exception. Persist/display identities only as installation-keyed HMACs, separated by billing authority/region/account/workspace (common authority for a verified shared pool). No raw identities or plain hashes. Cache sanitised last-good readings with original age; errors never make them fresh. Account switches invalidate bindings. Passed resets, missing/stale/unbound readings and local token totals never imply fresh quota or entitlement.

### Per-provider read budget

| Provider | Maximum calls in one admitted read | Stable metadata |
| --- | --- | --- |
| Claude Code | **2**: `/api/oauth/usage` + `/api/oauth/profile` | Profile/identity binding, up to 24 h; usually usage only. No query-variant retry or extra reset-credit request. |
| Cursor | **2**: `get-plan-info` + `GetCurrentPeriodUsage` | Plan/merged status and period, up to 24 h; usually period usage only. Replace today's three-call summary/plan/unified sequence; no additional `/api/usage-summary` or `/api/usage` waterfall. |
| Gemini CLI | **2**: `loadCodeAssist` + `retrieveUserQuota` | Code Assist project/tier, up to 24 h; usually quota only. No Cloud Resource Manager discovery. |
| Codex, ZCode/GLM, Grok Build, Copilot, Kimi and each admitted long-tail reader | **1** usage HTTP request or tool-owned quota RPC | Use local identity/metadata where available; no additional remote identity/discovery call. A route needing more remains unsupported until explicitly redesigned. |

Cache stable metadata **up to 24 hours**, keyed to the same profile, credential-generation fingerprint and account/workspace binding; invalidate it on any switch, expiry, denial, revocation or contradictory provider evidence. Persist only sanitised metadata and keyed identity hashes; raw project/account selectors remain transient or are reread from their authorised tool-owned source. If a new process cannot reconstruct a required selector, use the metadata request within the same two-call allowance. Never persist a secret or raw identity merely to achieve the one-request fast path.

One read assembles fresh usage with valid same-binding cached metadata, or obtains both in that transaction. Never fetch identity in one five-minute slot and splice it onto another slot's usage, borrow stale/ambiguous metadata, or make a third call after failure. Failed identity validation leaves fresh usage unbound and the previous verified reading aged; it does not refresh the old subscription. Record request-count, binding invalidation and partial-failure fixtures for every multi-call reader.

## Section 9 reader admission and display

| Requirement | FEEDFIX behaviour and lane handoff |
| --- | --- |
| **Automatic / Passive only** | Automatic is the default **after consent**. Passive only permits credential-free Codex app-server, native Codex/Claude session records, existing optional snapshots and explicitly supplied/configured keys; no automatic tool credential/Keychain import. Claude detection, quota and session state have **no plugin, hook or status-line dependency**. CLIJIT persists the choice; FEEDFIX enforces `MODELPLAN_READERS=passive|off` above catalogue preference. `off` starts no personal reader; presence-only detection/public data remain separate. |
| **No quota windows** | Valid balance-, count- or spend-only accounts remain visible. Report known pay-as-you-go or organisation-managed modes instead of invented full/empty tanks; unknown membership stays unbound. |
| **Several accounts** | Personal/work profiles, several `CLAUDE_CONFIG_DIR`s and Codex homes get independent canonical account/seat refs and user aliases, never “latest token wins.” CLIJIT discovers/authorises profile descriptors and stores aliases; FEEDFIX binds each result. Same actual subscription across profiles deduplicates; distinct seats do not. Round-robin accounts through **one provider-wide** lock/five-minute gate, not one gate per account. |
| **System proxy from App** | App supplies system proxy/PAC resolution and bypass policy to CLIJIT; FEEDFIX uses that transport context for native HTTP, CodexBar/tool children and helper downloads. Finder launch must work without proxy env. Preserve TLS verification and host allowlists; no silent direct retry when a required proxy fails. Never log proxy credentials; doctor receives only safe status. |
| **Beta / failure states** | Catalogue `beta:true` and effective reader/source metadata stay beta until an owner/opted-in tester verifies that route on a real account. Fixtures/CI cannot clear beta. Availability, confidence and freshness remain separate: no tool, denied, expired login, unsupported, estimated and stale each have a safe next step; see the appendix. |
| **Version / rollback** | Each entry carries **`minCli`**; CLIJIT skips incompatible entries and returns “update to read <tool>.” Keep the last verified catalogue **and** binary on failed admission; retain per-provider artifact/mapping bindings. An owner-authorised publication rollback can select prior verified content/pins—do not add an independent reader rule that blocks that rollback or resets call budgets. |

FEEDFIX supplies source URLs/contracts to the existing official-source watch for head-tool release/auth changes, plus native/CodexBar/beta support metadata. CLIJIT/App/website lanes consume the catalogue to generate support tables and localise statuses. Consent/privacy wording and notices require owner review before credential-reading release. Linux keeps file/passive sources first; Secret Service and inaccessible enterprise-admin quota are later work. Readers report measurements only: App red-level thresholds and CLI tight-pace advice remain separate consumers, not duplicate reader policy.

## Hybrid routing and coverage

FEEDFIX owns one router under the shared provider lock and attempt gate. Catalogue routing never grants consent or overrides local revocation, backend-disable settings, host/source restrictions or minimum CLI requirements. Map catalogue `codexbar` to the existing internal `codexbar-compat` backend without silently broadening legacy grants; CLIJIT owns any consent/config migration.

| Catalogue `preferred` | Effective behaviour |
| --- | --- |
| `native` | Use native. Head upstream-change errors retain the aged reading and safe error; **never automatically run CodexBar**. A long-tail tool without native code can use the helper only when its exact route has `codexbar.audited:true` and a matching verified pin. |
| `codexbar` | An explicit catalogue selection still requires the exact provider/source/pin safety audit and consent. All head bridge entries start unaudited/disabled; a remote preference alone cannot enable them. |
| `off` | Stop new provider/credential reads and pending fallback, retaining only correctly aged historical display. It is not a consent revocation; explicit disconnect deletes readings. |

An admitted bridge reports **“via CodexBar”** (and “fallback” only for an explicitly admitted non-head fallback); it replaces the selected reading, never adds another subscription. Expired/rejected login, missing consent/credential, permission denial, rate limiting and ordinary network failures do not trigger cross-reader credential hunting. Preserve `open <tool> to refresh`, backoff or the applicable unavailable reason. Once native is repaired and preferred again, retry native when due.

**Retry timing:** no automatic head fallback. Any admitted non-head source change waits for the later of the next eligible provider read and error backoff; never start a second reader inside the failed read. A catalogue switch does not clear either timestamp. One child at a time; only one successful source is selected per subscription. Provider-class boundaries never become automatic fallbacks.

**Helper pin:** the verified publication’s `codexbar` version/platform SHA-256 **replaces the compiled pin** as active authority. `cli/internal/quota/codexbar-pin.json` (currently 0.81.0) is only a bootstrap/last-good compatibility seed during migration. FEEDFIX owns bounded fetching, extraction, atomic verified-cache activation and invocation; CLIJIT supplies the admitted pin from its publication consumer. A checksum/fetch failure keeps the last verified catalogue/provider binding, helper and reading, never an unverified binary or arbitrary PATH copy. Ship its MIT notice in `cli/THIRD-PARTY-NOTICES.md` and App About → Licences. No user install; one provider/explicit source per bounded private JSON child, never `--provider all`.

Detection/translation coverage spans the complete pinned registry; **runtime eligibility does not**. Each helper entry has an **`accessClass: standard | browser-session | not-read`**. Standard reads use only the tool's own local login/records or audited read-only, no-quota CLI commands, always with **`CODEXBAR_DISABLE_KEYCHAIN_ACCESS=1`**, browser discovery/enrichment/fallback Off and no token refresh/persistent credential cache. Browser-session is advanced, off by default and never granted by one-click consent; the separately explained provider cookie cache and CodexBar's own Keychain/Safe Storage access are allowed only there. No access class permits token refresh or inference. API-key-only/manual-secret integrations and refresh paths are not-read. The `/usr/bin/security` restriction is for native readers, not CodexBar internals.

The appendix [classifies every one of the 110 pinned providers](agent-reader-contracts.md#codexbar-access-classes--complete-0810-inventory), verifies the Keychain flag's effects/limits and defines advanced consent/Forget cleanup. **Classification is separate from `audited:true`:** inspect the chosen provider's setup, success, error, retry and child-CLI paths, credential writes, endpoints and request count before enabling it. Flag `1` blocks persistent Keychain caching and Chromium cookie decryption, but does not block Safari/Gecko, raw localStorage, refresh or subprocesses; standard routes therefore need explicit browser-Off and source constraints. Unbundled CLI caching can be process-local memory. A future safe upstream release is admitted per provider only after audit/tests; a checksum/JSON flag alone is insufficient.

Existing native Kimi/other readers and local Qwen accounting remain available under the same safeguards. Translation must include encoded credits/balances, spend/cost, request counts and estimated confidence, not only percentage lanes; preserve useful no-window accounts. Untranslatable output is **“not supported yet”**. The [appendix](agent-reader-contracts.md#pinned-codexbar-json-not-ui-assumptions) specifies exact 0.81.0 source fields and additive destinations; successful translation is not a safety audit.

## Provider plan, in implementation order

**Access** supplies CLIJIT/App consent descriptions; **S/M/L** estimates reader work. FEEDFIX ships reader policy/Keychain plumbing with Claude; CLIJIT independently supplies consent, detection and command integration.

### 1. Claude Code — M, beta

**Detect/source:** `claude`, Claude Code project records or its `.credentials.json` under the authorised `CLAUDE_CONFIG_DIR` (default `~/.claude`). After consent, read `claudeAiOauth` from the selected plaintext file or the proven literal default Keychain service `Claude Code-credentials`. Directory-keyed Keychain names are not guessed: v1 keychain-only custom profiles stay undetectable/unsupported until an evidenced typed derivation ships. Claude Desktop's bundle ID alone does not detect Claude Code. **Usage:** beta compatibility endpoints `GET https://api.anthropic.com/api/oauth/usage` and `/api/oauth/profile`, bearer plus `anthropic-beta: oauth-2025-04-20`; require `user:profile`. **Source is CodexBar 0.81.0, not an official supported quota API contract**: it appends `?cedar_ember=1` to usage and uses profile for identity. Native v1 uses the base usage route, without query retry or extra reset calls. One read is at most usage + profile (2); cache sanitised profile binding up to 24 h. Scope: returned five-hour/weekly/model windows and extra spend, not Admin API. **Expiry:** reject expired/insufficient-scope credentials; shared backoff and `open Claude Code to refresh`. **Never:** plugin/status-line dependency, delegated refresh, CLI/PTY probes, inference-only grants, browser-cookie import or OAuth rotation. **Access:** “Read Claude Code's saved sign-in, with a possible macOS Keychain prompt, and authenticate to Anthropic to read account usage and verify its account identity.” [Pinned CodexBar endpoint evidence][C], [fetcher][CO]

**Passive session state — separate M PR, beta:** independently scan the selected root's `projects/**/*.jsonl`; retain the newest eligible assistant turn per session, selecting an evidenced interactive session as **`recent-thread`**, or **`current-thread`** only for a matching explicit caller selector. `message.model` is the model candidate. **Top-level `effort` and `message.usage.speed` are hypotheses pending the owner's sanitised first-party fixture**; optional versioned adapters may be enabled only after that evidence, and until then both values stay unknown even if a synthetic example contains them. No settings/default inference. Retain only model/effort/Fast and a keyed session hash plus existing observation/attribution metadata; project labels follow the existing preference. No message content, raw IDs or paths are stored. Optional hooks/status-line snapshots override nothing, including unknown fields. See [evidence limits, selection and synthetic tests](agent-reader-contracts.md#claude-code-passive-current-session-reader). Additional consent line: **“Read Claude Code's local session records for model, effort and Fast state; message contents stay unrecorded and nothing is sent.”**

### 2. Codex app / CLI / IDE — S; HTTP fallback M

**Detect/source:** `codex`, Codex app/known IDE extension installation metadata and authorised `$CODEX_HOME`/`~/.codex` metadata. Prefer item 1's tool-owned `codex app-server`: handshake, `account/read` with `refreshToken:false`, and **`account/rateLimits/read` with `excludeResetCreditDetails:true`**. Local account identity/setup RPC is distinct from the single quota RPC per admitted read. Credentials stay with Codex. Bind the returned account/workspace; app, CLI and IDE can differ. If RPC is unavailable, a later admitted read may use only that home's fresh `auth.json` access token/account selector. **Usage:** rate-limit windows and actual wire **`credits{hasCredits,unlimited,balance}`**; `usageCredits` is only ModelPlan's cache/JSON name. The reset-credit count can still be returned, but omitted details mean unknown expiry; no follow-up lookup. HTTP fallback: one `GET https://chatgpt.com/backend-api/wham/usage` with matching context. **Expiry:** open Codex to refresh; no delegated renewal. **Never:** refresh-token exchange, OpenCode auth import, account switching, reset-credit detail requests or redemption. **Access:** “Ask Codex for account usage using its sign-in; if needed, read its saved access token to authenticate to OpenAI.” [X], [RPC parameter schema][CP]

**Open item — M2 audit:** actual Codex Desktop/IDE session roots and their relationship to CLI homes remain unverified. Installed app/extension metadata does not prove a rollout path, current session or shared login. Do not claim alternate-root auto-discovery, read arbitrary candidate directories or infer membership from the existing present-but-unbound observation. Keep this gap visible until the bounded M2 source/location audit establishes the supported layouts.

### 3. ZCode / GLM — L, beta; restricted v1

**Detect/source:** ZCode app/CLI and `~/.zcode/v2`, honouring the locally approved `ZCODE_DATA_BASE_DIR`. After consent, inspect only selected family/account/plan metadata in `setting.json`/`config.json`. **No decryption of `credentials.json` in v1**, and no reproduction of its key derivation: the encrypted-envelope approach is evidenced only by third-party Token Monitor. A plaintext `options.apiKey` or other proven tool-owned plaintext source is usable **only with evidence it is the current selected account's Coding Plan key**, matching family, region and account/tenant. A generic/stale/unbound API key or keychain-only/encrypted login is **“unsupported for now”**, without a request to paste a key. **Usage:** one `GET https://api.z.ai/api/monitor/usage/quota/limit` or mainland `https://open.bigmodel.cn/api/monitor/usage/quota/limit`, selected by proven region; returned token/MCP windows only. **These endpoint/auth details are third-party-sourced from Token Monitor**, not a verified first-party ZCode contract. Team selections without a verified tenant are unsupported. Its separate `https://zcode.z.ai/api/v1/zcode-plan/billing/balance` Start Plan route is third-party research only; encrypted JWT extraction/balance reading is outside v1. **Expiry:** reject uncertain/expired credentials; open ZCode to refresh. **Never:** decrypt/derive keys, stale-account fallback, key creation, global-to-China forwarding, or infer Coding Plan entitlement from a generic key. **Access:** “Read a verified plaintext key for ZCode's current Coding Plan account and authenticate only to its matching Z.ai/BigModel quota service.” [Third-party discovery][Z], [third-party endpoints][ZU]

### 4. Cursor — M

**Detect/source:** Cursor app and `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`; after consent, query only `ItemTable`'s `cursorAuth/accessToken`, read-only with bounded WAL handling. **Usage:** at most **2 requests in one read**: `POST https://cursor.com/api/dashboard/get-plan-info` and `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage`, with an in-memory derived session. Cache same-binding plan/merged metadata up to 24 h so most reads request usage only. This replaces the current summary + plan + unified three-call flow; no extra `/api/usage-summary` or legacy `/api/usage` retry. Scope: the signed-in user's returned included pool/spend, not a team Admin API. Unsupported legacy response shapes remain unsupported rather than borrowing another slot's usage. **Expiry:** reject expired/sealed tokens; open Cursor to refresh. **Never:** browser-store decryption, conversation reads, mixed plan pools, persisted session tokens or automatic CodexBar fallback. **Access:** “Read Cursor's saved sign-in and authenticate to Cursor for your account's plan and usage.” [U], [existing native routes][CU]

### 5. Grok (Grok Build) — M; shared identity integration L

**Detect/source:** `grok` and `~/.grok/auth.json`; locally approved `GROK_HOME`/`GROK_AUTH_PATH` overrides only. Browser login is OAuth/OIDC via `auth.x.ai`; the issuer/client-scoped auth map stores `key`, `auth_mode`, `user_id`, principal/team context, creation and expiry. API-key mode also exists (`XAI_API_KEY`, legacy `GROK_CODE_XAI_API_KEY`, per-model config, or `xai::api_key` auth slot); it does **not** establish X Subscription entitlement. Respect selected per-model/auth mode; do not substitute a saved session for API-key mode. **Usage:** independently read the selected fresh first-party session and call `GET https://cli-chat-proxy.grok.com/v1/billing?format=credits`, using bearer, `X-XAI-Token-Auth: xai-grok-cli`, `x-userid` and required client metadata. This is the request behind the tool's `x.ai/billing` extension, forwarding to `GetGrokCreditsConfig`. Parse `creditUsagePercent`, `currentPeriod.{type,start,end}`, `isUnifiedBillingUser` and separate `prepaidBalance`; legacy monthly fields stay legacy. **Expiry:** enforce stored/JWT expiry conservatively; stale/unknown credentials mean `open Grok Build to refresh`. **Never:** launch its login/AuthManager, call external auth commands, refresh tokens, chmod/repair its files, change top-up controls or send an API key to this subscription route. **Access:** “Read Grok Build's existing session and authenticate to xAI for included usage and separate prepaid balance.” [Auth][GA], [request/types][GB], [dispatch][GD]

### 6. GitHub Copilot — S for CLI; L for IDE-only discovery

**Detect/source:** `copilot` or installed Copilot extension manifests. Reuse native `copilot --headless --no-auto-update --stdio`, negotiated handshake then **`account.getQuota`**, with runtime-owned authentication; no credential file is needed. **Usage/scope:** documented SDK server RPC, including premium-interaction entitlement/reset when supplied. **Expiry:** unavailable auth/capability → open Copilot to refresh; no session or login is created. IDE-only installation does not prove an installed CLI: selected extension credential-store compatibility remains unverified and must fail visibly, without asking users to install a runtime. **Never:** import an unrelated `gh` login, initiate device flow, use org billing APIs as personal quota, or invoke a turn. **Access:** “Ask your installed Copilot runtime to authenticate to GitHub and return account quota.” [G]

### 7. Gemini CLI — M, beta

**Detect/source:** `gemini` and `~/.gemini`; after consent, read only a fresh `~/.gemini/oauth_creds.json` access token/expiry under verified tool overrides. **Usage:** at most **2 requests in one read**: `POST https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist` for project/tier when needed, then `:retrieveUserQuota` for model-bucket fractions/reset. Cache same-binding stable project/tier metadata up to 24 h; normally only quota is fetched. Missing project after the allowed discovery step means unsupported, not Cloud Resource Manager enumeration. API-key/Vertex modes and unsupported tiers remain separate/unavailable. **Expiry:** `expiry_date` safety margin, then open Gemini CLI to refresh. **Never:** Google OAuth refresh, extract client secrets, enumerate projects, change login mode, launch a provider CLI via CodexBar or substitute Antigravity. **Access:** “Read Gemini CLI's saved access token and authenticate to Google Code Assist for its account/project and quota.” [Pinned CodexBar source, including excluded behaviours][E]

### 8. Kimi (existing native reader) — M

**Detect/source:** `kimi`, `~/.kimi-code`; after consent, fresh `credentials/kimi-code.json` plus existing `device_id` under that home. **Usage:** `GET https://api.kimi.com/coding/v1/usages`, with the required existing device headers; returned five-hour, weekly/monthly pools, not Moonshot API cash. Reuse the native parser. CLI credentials lack issuer provenance: China-only until verified otherwise; never send them to `api.kimi.ai`. **Expiry:** token expiry with safety margin, then open Kimi to refresh; missing device identity means unavailable. **Never:** create a device ID, renew rotating refresh tokens or import browser cookies. **Access:** “Read Kimi Code's existing sign-in/device identity and authenticate to Kimi China for Coding Plan usage.” [K]

### 9. Qwen Code (local accounting / supported bridge) — M local; L for backend quota

**Detect/source:** `qwen`, `~/.qwen/settings.json` and existing stats/project layouts. After consent, identify the selected backend; reuse bounded local aggregate/history readers. **Usage:** no verified universal Qwen Code remaining-quota endpoint. Local stats give observed tokens/model/day, not allowance. A recognised configured GLM/Kimi/etc. backend can use its own native adapter and shared provider budget only after credential/host provenance is established. QwenCloud/Alibaba subscription routes require separate contracts; browser-console cookies are excluded. **Expiry:** local capture age is shown; any supported backend token uses its provider's owner refresh guidance. **Never:** infer cloud quota from `oauth_creds.json`, equate different Qwen/Alibaba plans, or require an export command/install/key paste. **Access:** “Read Qwen Code's local usage; for a supported selected backend, use its existing credential to authenticate only to that provider.” [Q]

## Head-provider quota-shape mapping

Duration/cadence comes from the provider contract, never primary/secondary position or a public plan allowance. Display **5h / weekly / monthly / other with label**; on the existing wire these are `five_hour`, `weekly`, `monthly`, and `unknown` + `limit`/duration for other. Calendar-month resets use returned dates; daily buckets do not become five-hour windows. `spend` is a separate money meter. Keep model/MCP subwindows scoped instead of summing them into their parent. Preserve true zero, missing, unlimited and reset-passed distinctly.

ZCode/GLM exposes a distinct MCP/tool quota shape. For other heads, using MCP does not itself prove a separate allowance: show an MCP meter only if that provider returns one with a documented scope/unit; otherwise retain its actual shared/model windows without inventing an MCP cap.

| Native head | Windows / scoped lanes | Credits, spend and per-request plans |
| --- | --- | --- |
| **Claude Code** | `five_hour` → 5h; `seven_day` and returned Opus/Sonnet/model weeks → weekly with scoped label; other returned windows keep duration/label. | Returned extra-usage spend/limit → spend meter with actual currency/reset; provider-issued prepaid credits/reset inventory only if supplied and translatable. Request counts only when actually returned; never infer from tokens, prices or percentages. |
| **Codex app/CLI/IDE** | Each `rateLimitsByLimitId` primary/secondary maps by `windowDurationMins`; normal 300 → 5h, 10080 → weekly; monthly/other only if supplied. Preserve limit IDs/model reserve pools independently. | Wire `credits{hasCredits,unlimited,balance}` → credits/balance (`usageCredits` is our JSON name); monthly credit caps separate from wallet; returned reset count → cards with unknown expiry when details are excluded, never currency. No request quota invented for token-based limits. |
| **ZCode / GLM** | `TOKENS_LIMIT`/`CREDIT_LIMIT` unit+number maps 5h/weekly/monthly/other; `TIME_LIMIT` MCP/tool quotas remain labelled (monthly only under the documented monthly marker/contract). | Actual MCP/API used/limit/remaining counts → requests with the true unit; token counters are not request counters. Start Plan balance would be a separate wallet, not GLM remaining quota; its encrypted-source reader is outside v1. No sum of overlapping tool/model quotas. |
| **Cursor** | Legacy included usage is monthly; confirmed merged X Subscription included usage is weekly with its reset, never stale monthly-summary zeroes. Preserve named Auto/Other-model lanes where returned. | Legacy request plans → requests used/limit, with unlimited/unknown explicit; actual on-demand spend/caps and returned prepaid balance remain separate. Member-invisible team pools are organisation-managed, not 100% remaining. |
| **Grok Build** | `currentPeriod.type/start/end` sets weekly/monthly/other; `creditUsagePercent` is the included pool. Legacy monthly credits never become a new X Subscription window by name alone. | Returned prepaid credit/cash units → balance; legacy used/limit cap → typed budget. API-key mode is pay-as-you-go where established, never a subscription percentage. No per-request quota without counters. |
| **GitHub Copilot** | Returned quota cycle/reset supplies monthly or other; premium interactions, chat/completions stay separately labelled when exposed. | `account.getQuota` request counters → `requests`; newer credit-denominated entitlement remains credits, not rounded requests. Preserve explicit unlimited. Unavailable organisation entitlement is managed/unknown, not zero. |
| **Gemini CLI** | Returned Code Assist per-model daily buckets → **other: daily <model>** (1440 minutes where supplied); other cycles retain their actual cadence. Remaining fraction maps to percent, not an inferred request count. | Absolute request/token allowance only with its declared unit; no invented credit wallet or API-key/Vertex subscription quota. Unsupported tiers remain unsupported; observed API spend is pay-as-you-go only when supplied. |

## Catalogue schema — architecture section 5

FEEDFIX owns the schema, typed contract and first attributed catalogue port. CLIJIT owns fetching/verifying/consuming the signed publication, machine signal evaluation and update commands. The proposed **relevant `client.data`/public projection fields** are `detectors[]`, `codexbar` and `cli`; metadata below is additive. Version values and the all-zero CLI checksum in this example are illustrative, not release announcements.

```json
{
  "detectorSchemaVersion": 1,
  "detectorRevision": 1,
  "detectors": [
    {
      "providerId": "claude",
      "displayName": "Claude Code",
      "readerId": "native:claude-code",
      "preferred": "native",
      "minCli": "0.6.0",
      "beta": true,
      "detectionStatus": "signals",
      "signals": [
        {
          "id": "claude-default-file",
          "type": "path",
          "value": ".claude/.credentials.json"
        },
        {
          "id": "claude-default-keychain",
          "type": "keychainItem",
          "name": "Claude Code-credentials",
          "derivation": "literal"
        },
        {
          "id": "claude-cli",
          "type": "command",
          "name": "claude"
        }
      ],
      "provenance": [
        {
          "signalIds": [
            "claude-default-file",
            "claude-default-keychain"
          ],
          "repository": "steipete/CodexBar",
          "commit": "ee890b5f392e70d6e20162d3e95cf9f1be265b60",
          "path": "Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials.swift",
          "license": "MIT",
          "noticeId": "codexbar-mit"
        },
        {
          "signalIds": [
            "claude-cli"
          ],
          "repository": "steipete/CodexBar",
          "commit": "ee890b5f392e70d6e20162d3e95cf9f1be265b60",
          "path": "Sources/CodexBar/SettingsStore+ProviderDetection.swift",
          "license": "MIT",
          "noticeId": "codexbar-mit"
        }
      ],
      "codexbar": {
        "audited": false,
        "pin": null,
        "automaticFallback": false,
        "accessClass": "not-read"
      }
    }
  ],
  "codexbar": {
    "version": "0.81.0",
    "sha256": {
      "darwin/arm64": "441e24758d538ab16047efbdd55d5450d71c10b9fe4d7a482bbb535efc431c0d"
    },
    "providerOverrides": {}
  },
  "cli": {
    "latest": "0.6.0",
    "sha256": {
      "darwin/arm64": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
```

**Types:** positive safe-integer schema/revision; bounded literal IDs/names; semantic version strings; per-platform lowercase 64-hex SHA-256 for exact release archives. Include all supported platforms in real pins; an absent platform is unavailable, never guessed. A detector requires provider/display/reader IDs, `preferred` enum, **`minCli`**, **`beta`**, signals and provenance. `readerId` is a logical compiled-native or `codexbar:<provider>` selector, never an executable/path/flag. New CodexBar provider IDs can arrive with a tested new helper pin and detector; they are not blocked by a release-frozen five-provider allowlist. Resolve only the verified helper’s supported IDs/capabilities and that provider’s passing translation contract **and safety audit**. `codexbar.providerOverrides` optionally maps an ID to a full `{version,sha256}` pin or `null` (bridge unavailable); otherwise use the verified default. A failing provider holds its previous pin while other providers advance. `minCli` gates override-aware routing; an older copy must not ignore a hold and use the new default. Every signal has a stable `id`; provenance names its exact `signalIds` and the source file actually containing that signal. Provenance is attribution, never instructions to open paths or fetch URLs.

**Provider safety admission:** `detectors[].codexbar` requires `accessClass` (`standard | browser-session | not-read`, missing/unknown = not-read), `audited` (Boolean, absent = false), `pin` (null when unaudited, otherwise full `{version,sha256}`) and `automaticFallback` (false for every head). Native routing is independent of its helper access class: the example's Claude entry remains native-enabled while its helper is not-read. A true audit records the fixed `source` enum (`api | oauth | cli | web | auto`) and reviewed repository/commit/source paths plus safety-test IDs. `cli` requires evidence that the command is read-only, consumes no quota and does not refresh auth; `auto` requires an audited fixed graph with no cross-class fallback, browser access in standard mode or credential hunting. These are data selectors for reviewed reader policy, never arbitrary commands or arguments.

The effective class determines immutable invocation/consent policy: standard forces the Keychain-disable env and browser-Off policy; browser-session requires a separate per-provider advanced grant and privacy/denial checks; not-read never invokes the helper. A catalogue revision cannot upgrade standard consent into browser access or override a privacy setting. Class changes to browser-session require a new explicit advanced grant. CLIJIT stores that grant and cleanup status; FEEDFIX enforces it and supplies cancellation/scoped-cache-clear hooks. Match the audit against the exact provider/platform/source/default-or-override hash; mismatches/new code invalidate it. Gate class-aware admission with `minCli`; old copies cannot ignore advanced/not-read and run the provider. Translation fixtures alone cannot set `audited:true`.

**Detection provenance correction:** `SettingsStore+ProviderDetection.swift` contains CLI lookup and the **Claude Desktop** bundle signal, not Claude Code's `.credentials.json` or Keychain signals. The latter two come from `ClaudeOAuthCredentials.swift` as shown. Do **not** port `com.anthropic.claudefordesktop` as a Claude Code installation signal or evidence of its saved login. Detect Claude Desktop separately if later supported; it does not pre-check Claude Code by itself.

**Additive compatibility:** older CLI copies ignore unknown fields and unknown signal types, as PR213 requires. Unsupported readers/minimum versions yield an upgrade/unavailable status. Signals are OR-ed presence hints; unknown types are inert, and no recognised true signal means no detection. Bound to 256 KiB, 512 entries and 16 signals/entry; reject malformed known values and duplicate/conflicting IDs. `detectionStatus:"no-safe-signal"` permits an empty signal list and a stable reason for web-only/manual-key providers; never invent an installation. No script, regex, shell expansion, arbitrary command, credential query or executable predicate is accepted.

| Whitelisted type | CLIJIT evaluation boundary defined by FEEDFIX schema |
| --- | --- |
| `bundleId` | OS registration lookup for a bounded literal app ID, no launch. |
| `path` | Presence of a documented **home-relative tool path**, not arbitrary filesystem access. Allowed classes: tool-owned dotfiles/directories, `.config/<tool>/…`, and `Library/Application Support/<tool>/…`, with reviewed literal paths recorded in the catalogue documentation. Reject absolute paths, `..`, expansion/globbing, protected unrelated homes and symlink escape. A moved path within the documented set is a catalogue change; new access classes require evaluator support/consent, not remote code. |
| `keychainItem` | Bounded provider-owned service/account **name** presence only, no value or prompt; unknown if a silent check cannot establish presence. `derivation` is a closed enum: **`literal` only in v1**. No free-text formula, placeholder substitution or directory hashing rule is accepted. Claude custom profiles requiring directory-keyed item names are **undetectable by Keychain in v1**, never probed via the default/global item. Their approved plaintext-file/session signals can still work. A future directory derivation requires evidenced compiled enum support plus `minCli`; unknown rules are inert. The value reader uses `/usr/bin/security` only after consent. |
| `command` | Locate/stat one validated CLI basename in documented install directories/PATH. No shell, args, execution, or login-shell discovery. |

First-port completeness covers every CodexBar registry ID by inspecting descriptors/credential locators as well as detection code, preserving per-signal commit/path and full MIT notice. Its pinned first-run chooser detects only four providers and defaults to Codex on no match; do not port that false-positive default. The seed is reviewable bootstrap metadata; publication remains the canonical update source. [Registry][CR], [chooser][CD], [licence][CL].

**Updates and trust:** consume the architecture’s existing signed-publication contract—no competing signing envelope or parallel feed in quota readers. CLIJIT verifies authenticity, component hashes/dependencies, revision/rollback and validity before handing FEEDFIX admitted data. Invalid data cannot expand access; keep compatible last-good/bundled metadata within validity. The shared publication fetch stays ten minutes plus jitter/ETag. Detector additions, moved paths, renamed items, routing switches, tested CodexBar pins and new helper-supported tools propagate within hours **without a ModelPlan release**. New native reading code still requires a CLI release and plugin pin/App update. The daily CodexBar monitor proposes pin + registry/signal changes for review; production publication/signing stays private.

The same schema defines `cli.latest` and checksums, but **CLIJIT** owns their update hint and explicit `modelplan update`; never query GitHub for latest or self-update App/plugin-managed copies. FEEDFIX does not implement `detect`, connection/consent commands, `doctor --share`, CLI update, plugin installation or publication consumption.

## Every-provider contract test and daily pin gate

FEEDFIX extends `TestLiveCodexBarContract` from five hardcoded providers to **every candidate registry provider**, plus still-active old pins. Safe unsigned-in binary smoke checks and synthetic sign-in success/error fixtures together cover the complete set, with explicit test-mode labels; missing/unsupported shapes are not passes. Validate actual translated monetary/count/window/confidence semantics, not just an error envelope. No real credentials, host Keychain, login, inference or authenticated vendor calls in tests.

Run that provider/platform/source matrix in the **daily** monitor. A failed provider alone holds its last verified version/hash/mapping **and safety audit** via `providerOverrides`; others advance in one reviewed proposal. Every registry provider remains in the matrix, but unsafe/unaudited routes use source/fixture checks only and stay runtime-disabled; coverage is not permission to invoke them. New providers with no passing version stay “not supported yet.” Keep all referenced old binaries. Artifact/signature/checksum failure blocks the unverified artifact, not permission to run it; rollback keeps the last verified catalogue and artifact binding. See [the detailed gate contract](agent-reader-contracts.md#every-provider-daily-contract-gate).

## One X Subscription, multiple tool readings

**Product scope:** the owner's October 16 data decision is confirmed by [xAI pricing][XP] and [usage limits][XL]: one included weekly pool per paid seat for eligible first-party Grok/Cursor usage. Additional Usage/prepaid credits are separate; third-party Cursor models do not consume included allowance. Legacy Cursor and SuperGrok plans continue separately. Team seats have separate included pools; shared team wallets are not a second included quota.

**Can both readers show it?** Yes, source contracts support that: Cursor's merged-plan path uses `get-plan-info` (`isMerged`, included period/reset) plus `GetCurrentPeriodUsage` (`planUsage.totalPercentUsed`); the existing native reader already separates it from monthly legacy usage. Grok Build's billing response carries `isUnifiedBillingUser`, included percentage and period/reset. Prefer the latter's current fields over legacy monthly budget fields. The owner's cited pager `dispatch/billing.rs` routes the UI result; the actual HTTP request and response types are in shell `extensions/billing.rs`, with production host in `xai-grok-env`. The pager's unknown-billing default is an upsell-copy policy, not unified-membership evidence: require an explicit true flag. This is source evidence, not a live-account pass. Grok API-key-only mode cannot supply the subscription meter. [Cursor source][CU], [Grok request][GB], [production host][GE]

**Identity and one `subscriptionRef`:** require provider-confirmed unified status **and** the same canonical billing principal/seat/pool ID, or a verified provider link mapping Cursor's account to the Grok principal. Hash the canonical tuple with the installation key under a common `x-subscription-seat` basis (tenant + seat + included-pool kind; **not** period/reset). Atomically map both source identities to **one existing opaque ref**, preserving settings/history through aliases. Today's separate `cursor-auth`/Grok-specific assignments would create different refs: reusing their different HMAC domains does not deduplicate anything. Keep legacy bases separate. One subscription card can then name both tools. Select one whole validated reader result per ref by authoritative scope and observation time; do not combine readers to fill missing fields. Its included/prepaid meters are one reading, never summed or averaged across tools. Show conflicting readings as a discrepancy, not additional capacity. Prepaid/Additional Usage is a separate meter on that subscription, deduplicated by its own wallet scope.

**Evidence limit:** the inspected Grok billing DTO contains no subscription/seat ID, and Cursor exposes its own `sub`; Grok auth has `user_id` and principal/team fields, but the source does not prove equality or a cross-product mapping. `isMerged`, equal percentages/reset dates, same email, or both apps being installed cannot prove they are the same subscription; xAI explicitly allows unifying accounts with **different emails**. A verified common-ID/link contract is therefore a Step B prerequisite for guaranteed automatic merging. Without it, label source evidence “shared-pool link unverified,” keep it out of additive subscription totals, and do not fabricate one verified ref or silently combine different accounts. If IDs prove distinct seats/legacy plans, keep separate subscriptions. [Account-unification rules][XU]

FEEDFIX coordinates both readers under one conservative xAI/Cursor budget during link discovery, then one canonical shared-pool gate once linked; select **one native route** per five minutes. Cursor may use its two-call plan + usage transaction; Grok has one billing call. Any future remote link lookup must fit an explicitly approved read budget, not silently add a request or splice usage across slots. Automatic CodexBar fallback remains off for both heads. Merging aliases merges attempt timestamps conservatively; account/workspace switches invalidate evidence. Never unify accounts at the provider, move tokens between tools, or use public catalogue metadata to assert personal membership.

## Feedback, review and delivery

CLIJIT/App surfaces show **[Missing your tool? Tell us](https://github.com/modelplan/modelplan/issues/new?template=feature.yml&title=Tool%20detection%20request)** in onboarding, the empty state and Settings. Ask only tool name, platform and version; never attach credential paths/contents, identities, tokens or personal feed JSON automatically. Opening the form is explicit; submission is the user's action.

Direction is approved; complete these coordinator corrections before any Step B provider PR. FEEDFIX then opens one provider PR in native-head order, **`[D590] Auto-detect <provider> usage`**. CLIJIT integrates the DTO/status/cancellation interfaces through its own files. Changes to a boundary are handed off before either lane edits a shared path. FEEDFIX tests readers/routing and shape translation, persistent-denial enforcement, privacy admission, proxy propagation, beta metadata, per-account identity aliases with shared locks, dynamic per-provider pins/rollback and every-provider contract gates using synthetic homes, injected subprocesses, fake RPC and `httptest` only. CLIJIT tests detect/consent/revocation/doctor/update/plugin-install and publication consumption, including inert unknown signals and unsafe-path rejection, against the same contract fixtures. App lanes test presentation/visibility wiring. The translation/gate requirements in [agent-reader-contracts.md](agent-reader-contracts.md) are acceptance criteria for those PRs. No real credentials or vendor usage calls; this update changes documentation only.

The passive Claude session reader gets its **own** implementation PR after the coordinator corrections: **`[D590] Read Claude Code session state passively`**, separate from the Claude login quota reader. FEEDFIX owns proposed `cli/internal/quota/claudesession.go`, `claudesession_test.go` and handwritten `testdata/claude-sessions/`; source integration stays in quota-owned files. CLIJIT owns any caller/profile selector wiring. Neither implementation depends on the plugin/status line, and the passive PR tests with both entirely absent.

## Evidence and licensing

Inspected CodexBar `0827f30…` and Token Monitor `0c7dd85…` root licences are MIT; Pulse **`fc10fb7f13999d16f27f283c4bd9e83c80a2885d`** is Apache-2.0. Borrow approaches, not code/fixtures/assets. Use Pulse's existence-only discovery, with the owner's pre-checked consent replacing its unchecked chooser; exclude rotation and device-ID creation; any browser import is restricted to the separately consented advanced class. The detector port retains CodexBar copyright (Peter Steinberger, 2026) and full MIT notice in distribution; the signed catalogue references that notice. Grok Build first-party source at `2bdd1d6…` is Apache-2.0 ([licence][GL], [dependency/source-port notices][GN]). Any later substantial MIT reuse retains copyright/licence notices; Apache reuse also preserves applicable notices/attribution and marks modifications. Audit per-file/third-party terms; root licences do not grant provider API approval or branding rights.

Sources inspected 2026-10-27 (xAI product docs are live; code links pinned): [CodexBar licence][CBL], [Token Monitor licence][TML], [Pulse licence][PL] and [third-party notices][PN]; [Pulse discovery][PD]. Provider references:

[C]: https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/docs/claude.md
[X]: https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/docs/codex.md
[Z]: https://github.com/Javis603/token-monitor/blob/0c7dd855d3697ba0cd3ed47a3d52f8f187cc0e23/src/shared/providers/zai/zcodeDiscovery.js
[U]: https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/docs/cursor.md
[G]: https://github.com/github/copilot-sdk/blob/26536883459ba4cb23c735db8cb3de2c7b899d88/docs/features/usage-and-billing.md
[E]: https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/docs/gemini.md
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

[ARCH]: https://github.com/modelplan/modelplan/blob/docs/clients-and-readers/docs/clients-and-readers.md
[SEC]: https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials+SecurityCLIReader.swift

[CO]: https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift
[CP]: https://github.com/openai/codex/blob/a5ef02e56147c4c3da493655fd5e2c64db13210f/codex-rs/app-server-protocol/schema/typescript/v2/GetAccountRateLimitsParams.ts
