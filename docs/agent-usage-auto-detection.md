<!-- SPDX-License-Identifier: MIT -->
# D590: automatic agent usage detection

**Design for owner review · aligned with PR213 on 2026-10-27 · implementation awaits approval.**

[Clients, readers and updates][ARCH] is authoritative (PR213, `docs/clients-and-readers`, reviewed head `71470685e1a7fab68dc8f5370ed78171a94dfd6d`). This note specifies FEEDFIX’s reader/catalogue contracts under it; it does not create a second client architecture.

Goal: recognise tools already used on the Mac without installing a ModelPlan status line, requesting a pasted API key, or installing another monitor. Use native readers for Claude Code, Codex, ZCode/GLM, Cursor, **Grok Build**, GitHub Copilot and Gemini CLI. For every other CodexBar-supported provider, automatically use the bundled, pinned CodexBar CLI **when its tool is detected and has consent**. Native readers are preferred; upstream-change failures can use the supported CodexBar fallback, and the catalogue can select `native | codexbar | off`. Build on existing readers and [PR209](https://github.com/modelplan/modelplan/pull/209). Based on the supplied October 23 research and primary sources below; no real credentials or authenticated usage endpoints were accessed.

## File boundaries and handoff

The following is the FEEDFIX/CLIJIT boundary for review. Proposed new paths are contracts for later PRs, not files created by this note. Neither lane edits the other's files opportunistically; shared changes land through the named owner.

| Owner | Files | Responsibility |
| --- | --- | --- |
| **FEEDFIX** | `cli/internal/quota/*` readers, registry, routing, provider caches/locks, `identity.go`, `codexbar.go` and matching tests/fixtures | Native head, CodexBar fetch/invocation, `preferred` routing and typed fallback errors, one reading/ref per subscription, X Subscription identity aliases. The existing `connect.go` command/config code is the carve-out below; new reader policy belongs in FEEDFIX-owned `routing.go`, not concurrent edits to that file. |
| **FEEDFIX** | Proposed `cli/internal/keychain/*` | Fixed `/usr/bin/security` adapter for bounded presence/value operations; permission/result codes and injected-process fixtures. CLIJIT consumes the presence-only interface, never a password value. |
| **FEEDFIX** | Proposed `schema/detector-catalogue-v1.json`, `cli/internal/detectorcatalog/*`, `docs/detector-catalogue.md` | Schema/DTOs and pure validation, documented signal/path classes, attributed initial `seed.json` port covering every CodexBar provider. No machine probing, network sync or consent storage here. |
| **FEEDFIX** | `scripts/pin-codexbar.mjs`, `.github/workflows/codexbar-pin.yml`, `cli/THIRD-PARTY-NOTICES.md` reader notices | Daily CodexBar pin/contract/provider-signal review proposal; public standard runners. Published catalogue production stays with the existing publication owner, not in a new public publishing pipeline. |
| **CLIJIT** | Proposed `cli/internal/detect/*`, `cli/cmd/modelplan/*`, existing `cli/internal/quota/connect.go` until command/config extraction | Execute presence-only catalogue signals; `detect`, `connect --detected`, `disconnect`, `doctor --share`, `update`, plugin-install helper and command wiring. FEEDFIX does not edit this command/config carve-out. |
| **CLIJIT** | `cli/internal/connections/*`, consent-record package/store integration, `cli/internal/publication/*`, `cli/internal/digest/publication.go`, `schema/publication-v1.json` | Consent/revocation and shared state, consume/project the verified publication catalogue using FEEDFIX DTOs; expose reader status without duplicating reader logic. Any `reader/` consumption changes go through CLIJIT. |
| **App/client lanes** | Native Settings/first-run UI, plugin/Skill install/update surfaces | Present CLIJIT detection/consent/status; call the CLI. No quota reader or advice implementation in the App. |

**Interface:** CLIJIT hands FEEDFIX a validated catalogue revision/pin, detected tool/provider IDs, consent generation/allowed source classes and invocation context. FEEDFIX exports reader capabilities plus a result containing a stable status/error code, selected reader/source, fallback reason, observation time, opaque `subscriptionRef` and next eligible attempt. No credentials or raw provider text cross into detection/doctor/UI. CLIJIT owns consent persistence and revocation orchestration; FEEDFIX exposes cancellation/cache-purge hooks and rejects stale consent generations before publication. Both use the existing shared data directory; only FEEDFIX writes provider readings/attempt gates. Shared files are versioned/additive; unknown fields do not break older CLI copies.

## Consent and shared rules

CLIJIT detection checks presence only: app IDs, approved paths, Keychain item names and CLI locations; no launches, credential values, database contents or network calls. A name-only probe that cannot run without a prompt remains unknown. “Detected” means installed/configured, **not signed in or subscribed**; successful authenticated responses confirm sign-in. First-run lists detected tools **pre-checked**, with the access lines below. **Allow selected tools** records one consent; **Not now** enables nothing. A tool found later is offered separately by an App badge or one-line CLI hint; earlier choices are never re-asked. CLIJIT owns consent records and `disconnect <tool|--all>`/Forget readings revocation and deletion.

Consent text: **“Allow ModelPlan to read usage for the selected tools using their existing sign-in, through native readers or the included CodexBar helper. CodexBar is downloaded automatically with a verified checksum; you do not install it. Your credential is sent to that provider to authenticate; it is never sent to ModelPlan servers or stored by ModelPlan. macOS may ask for Keychain access. You can turn this off in Settings.”** Show each detected tool's selected reader/access line; name CodexBar on bridge rows. Local-only accounting is marked as sending no credential.

- After consent, read only the selected profile’s allowed fields. On macOS FEEDFIX invokes **`/usr/bin/security`** directly with fixed argument arrays (`find-generic-password`, the selected service/account, `-w` for the authorised value read), no shell or alternative binary. Capture its stdout only in bounded private memory; never forward/log it or credential-bearing stderr. Show the genuine macOS prompt; “Always Allow” applies to Apple’s stable binary rather than each ad-hoc CLI. Denial stops access. No `dump-keychain`, whole-store scans or prompt loop; background refresh never starts a new interactive grant. [Upstream security reader][SEC]
- Never refresh (even in memory), rewrite, move, delete or copy another tool's credentials into a store. No login/repair, settings changes, key/device-ID creation, inference, turns, warm-ups, reset-credit consumption or browser-cookie harvesting. Expired/rejected tokens mean `open <tool> to refresh`; reread after owner-tool state changes.
- One usage call/provider/**300 seconds minimum**, shared across processes, tools, manual refresh, resume, native and fallback. Persist a ModelPlan-owned attempt gate/lock; use monotonic timing and conservative restart/clock-rollback handling. Errors back off 10/20/40/60 minutes or longer `Retry-After`; authentication failures wait for tool-state changes. Nothing bypasses the five-minute floor.
- Reserve before I/O, failures included. Metadata consumes the same network budget; local RPC handshakes do not. No same-cycle endpoint/fallback waterfall. Allowlist HTTPS hosts/paths, reject redirects/custom destinations, bound reads/processes/responses. App-scheduled refresh runs only while Dock/sliver or cockpit is visible and awake; preserve its one-child scheduler and read-only desktop reads. Standalone/plugin requests use the same CLI consent and provider gates without requiring the App to be open.
- Secrets stay transient in memory, never output/logs/cache/receipts. Persist/display identities only as installation-keyed HMACs, separated by billing authority/region/account/workspace (common authority for a verified shared pool). No raw identities or plain hashes. Cache sanitised last-good readings with original age; errors never make them fresh. Account switches invalidate bindings. Passed resets, missing/stale/unbound readings and local token totals never imply fresh quota or entitlement.

## Hybrid routing and coverage

FEEDFIX owns one router under the shared provider lock and attempt gate. Catalogue routing never grants consent or overrides local revocation, backend-disable settings, host/source restrictions or minimum CLI requirements. Map catalogue `codexbar` to the existing internal `codexbar-compat` backend without silently broadening legacy grants; CLIJIT owns any consent/config migration.

| Catalogue `preferred` | Effective behaviour |
| --- | --- |
| `native` | Use the native reader first. For a detected long-tail tool with no native implementation, use its supported bundled CodexBar reader. A typed `upstream-schema-change` or unexplained non-auth upstream error makes CodexBar eligible when supported. |
| `codexbar` | Bypass native and use the pinned CodexBar reader under existing consent; report the catalogue preference. This is the remote switch while a native fix ships. |
| `off` | Stop new provider/credential reads and pending fallback, retaining only correctly aged historical display. It is not a consent revocation; explicit disconnect deletes readings. |

A fallback reports **“via CodexBar (fallback)”** and its native failure reason; it replaces the selected reading, never adds another subscription. Expired/rejected login, missing consent/credential, permission denial, rate limiting and ordinary network failures do not trigger cross-reader credential hunting. Preserve `open <tool> to refresh`, backoff or the applicable unavailable reason. Once native is repaired and preferred again, retry native when due.

**Retry timing:** upstream-change fallback is automatic but not a second usage call in the same five-minute window. Reserve both readers through the same gate; schedule the retry at the later of the next eligible slot and error backoff. A catalogue switch does not clear either timestamp. One child at a time; only one successful source is selected per subscription.

**Helper pin:** the verified publication’s `codexbar` version/platform SHA-256 **replaces the compiled pin** as active authority. `cli/internal/quota/codexbar-pin.json` (currently 0.81.0) is only a bootstrap/last-good compatibility seed during migration. FEEDFIX owns bounded fetching, extraction, atomic verified-cache activation and invocation; CLIJIT supplies the admitted pin from its publication consumer. A checksum/fetch failure keeps the last-good verified helper and reading, never an unverified binary or arbitrary PATH copy. Ship its MIT notice in `cli/THIRD-PARTY-NOTICES.md` and App About → Licences. No user install; one provider/explicit source per bounded private JSON child, never `--provider all`.

Coverage is the complete pinned CodexBar registry, not today’s five-entry map. Audit every source against the safeguards: generic `--source auto` can renew tokens, cache secrets or make multiple requests. Require tested read-only/one-request behaviour, including `/usr/bin/security` for helper Keychain reads (never a direct-framework fallthrough); any necessary upstream safe mode/attributed compatibility build is a **tested CodexBar release/pin update**, not a reason to freeze the pin in ModelPlan or demand a CLI release for every helper update. Unsupported access modes stay detected with a precise reason. Native fallback obeys the same constraints. Existing native Kimi/other readers and local Qwen accounting remain available.

## Provider plan, in implementation order

**Access** supplies CLIJIT/App consent descriptions; **S/M/L** estimates reader work. FEEDFIX ships reader policy/Keychain plumbing with Claude; CLIJIT independently supplies consent, detection and command integration.

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

## Catalogue schema — architecture section 5

FEEDFIX owns the schema, typed contract and first attributed catalogue port. CLIJIT owns fetching/verifying/consuming the signed publication, machine signal evaluation and update commands. The proposed **relevant `client.data`/public projection fields** are `detectors[]`, `codexbar` and `cli`; metadata below is additive. Version values and the all-zero CLI checksum in this example are illustrative, not release announcements.

```json
{
  "detectorSchemaVersion": 1,
  "detectorRevision": 1,
  "detectors": [{
    "providerId": "claude",
    "displayName": "Claude Code",
    "readerId": "native:claude-code",
    "preferred": "native",
    "minimumCliVersion": "0.6.0",
    "detectionStatus": "signals",
    "signals": [
      {"type": "bundleId", "value": "com.anthropic.claudefordesktop"},
      {"type": "path", "value": ".claude/.credentials.json"},
      {"type": "keychainItem", "name": "Claude Code-credentials"},
      {"type": "command", "name": "claude"}
    ],
    "provenance": [{
      "repository": "steipete/CodexBar",
      "commit": "ee890b5f392e70d6e20162d3e95cf9f1be265b60",
      "path": "Sources/CodexBar/SettingsStore+ProviderDetection.swift",
      "license": "MIT",
      "noticeId": "codexbar-mit"
    }]
  }],
  "codexbar": {
    "version": "0.81.0",
    "sha256": {
      "darwin/arm64": "441e24758d538ab16047efbdd55d5450d71c10b9fe4d7a482bbb535efc431c0d"
    }
  },
  "cli": {
    "latest": "0.6.0",
    "sha256": {
      "darwin/arm64": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
```

**Types:** positive safe-integer schema/revision; bounded literal IDs/names; semantic version strings; per-platform lowercase 64-hex SHA-256 for exact release archives. Include all supported platforms in real pins; an absent platform is unavailable, never guessed. A detector requires provider/display/reader IDs, `preferred` enum, minimum CLI version, signals and provenance. `readerId` is a logical compiled-native or `codexbar:<provider>` selector, never an executable/path/flag. New CodexBar provider IDs can arrive with a tested new helper pin and detector; they are not blocked by a release-frozen five-provider allowlist. Resolve only the verified helper’s supported IDs/capabilities. Provenance is attribution, never instructions to open paths or fetch URLs.

**Additive compatibility:** older CLI copies ignore unknown fields and unknown signal types, as PR213 requires. Unsupported readers/minimum versions yield an upgrade/unavailable status. Signals are OR-ed presence hints; unknown types are inert, and no recognised true signal means no detection. Bound to 256 KiB, 512 entries and 16 signals/entry; reject malformed known values and duplicate/conflicting IDs. `detectionStatus:"no-safe-signal"` permits an empty signal list and a stable reason for web-only/manual-key providers; never invent an installation. No script, regex, shell expansion, arbitrary command, credential query or executable predicate is accepted.

| Whitelisted type | CLIJIT evaluation boundary defined by FEEDFIX schema |
| --- | --- |
| `bundleId` | OS registration lookup for a bounded literal app ID, no launch. |
| `path` | Presence of a documented **home-relative tool path**, not arbitrary filesystem access. Allowed classes: tool-owned dotfiles/directories, `.config/<tool>/…`, and `Library/Application Support/<tool>/…`, with reviewed literal paths recorded in the catalogue documentation. Reject absolute paths, `..`, expansion/globbing, protected unrelated homes and symlink escape. A moved path within the documented set is a catalogue change; new access classes require evaluator support/consent, not remote code. |
| `keychainItem` | Bounded provider-owned service/account **name** presence only, no value or prompt; unknown if a silent check cannot establish presence. Renames within the documented item class are data updates. The value reader later uses FEEDFIX’s `/usr/bin/security` adapter after consent. |
| `command` | Locate/stat one validated CLI basename in documented install directories/PATH. No shell, args, execution, or login-shell discovery. |

First-port completeness covers every CodexBar registry ID by inspecting descriptors/credential locators as well as detection code, preserving per-signal commit/path and full MIT notice. Its pinned first-run chooser detects only four providers and defaults to Codex on no match; do not port that false-positive default. The seed is reviewable bootstrap metadata; publication remains the canonical update source. [Registry][CR], [chooser][CD], [licence][CL].

**Updates and trust:** consume the architecture’s existing signed-publication contract—no competing signing envelope or parallel feed in quota readers. CLIJIT verifies authenticity, component hashes/dependencies, revision/rollback and validity before handing FEEDFIX admitted data. Invalid data cannot expand access; keep compatible last-good/bundled metadata within validity. The shared publication fetch stays ten minutes plus jitter/ETag. Detector additions, moved paths, renamed items, routing switches, tested CodexBar pins and new helper-supported tools propagate within hours **without a ModelPlan release**. New native reading code still requires a CLI release and plugin pin/App update. The daily CodexBar monitor proposes pin + registry/signal changes for review; production publication/signing stays private.

The same schema defines `cli.latest` and checksums, but **CLIJIT** owns their update hint and explicit `modelplan update`; never query GitHub for latest or self-update App/plugin-managed copies. FEEDFIX does not implement `detect`, connection/consent commands, `doctor --share`, CLI update, plugin installation or publication consumption.

## One X Subscription, multiple tool readings

**Product scope:** the owner's October 16 data decision is confirmed by [xAI pricing][XP] and [usage limits][XL]: one included weekly pool per paid seat for eligible first-party Grok/Cursor usage. Additional Usage/prepaid credits are separate; third-party Cursor models do not consume included allowance. Legacy Cursor and SuperGrok plans continue separately. Team seats have separate included pools; shared team wallets are not a second included quota.

**Can both readers show it?** Yes, source contracts support that: Cursor's merged-plan path uses `get-plan-info` (`isMerged`, included period/reset) plus `GetCurrentPeriodUsage` (`planUsage.totalPercentUsed`); the existing native reader already separates it from monthly legacy usage. Grok Build's billing response carries `isUnifiedBillingUser`, included percentage and period/reset. Prefer the latter's current fields over legacy monthly budget fields. The owner's cited pager `dispatch/billing.rs` routes the UI result; the actual HTTP request and response types are in shell `extensions/billing.rs`, with production host in `xai-grok-env`. The pager's unknown-billing default is an upsell-copy policy, not unified-membership evidence: require an explicit true flag. This is source evidence, not a live-account pass. Grok API-key-only mode cannot supply the subscription meter. [Cursor source][CU], [Grok request][GB], [production host][GE]

**Identity and one `subscriptionRef`:** require provider-confirmed unified status **and** the same canonical billing principal/seat/pool ID, or a verified provider link mapping Cursor's account to the Grok principal. Hash the canonical tuple with the installation key under a common `x-subscription-seat` basis (tenant + seat + included-pool kind; **not** period/reset). Atomically map both source identities to **one existing opaque ref**, preserving settings/history through aliases. Today's separate `cursor-auth`/Grok-specific assignments would create different refs: reusing their different HMAC domains does not deduplicate anything. Keep legacy bases separate. One subscription card can then name both tools. Select one whole validated reader result per ref by authoritative scope and observation time; do not combine readers to fill missing fields. Its included/prepaid meters are one reading, never summed or averaged across tools. Show conflicting readings as a discrepancy, not additional capacity. Prepaid/Additional Usage is a separate meter on that subscription, deduplicated by its own wallet scope.

**Evidence limit:** the inspected Grok billing DTO contains no subscription/seat ID, and Cursor exposes its own `sub`; Grok auth has `user_id` and principal/team fields, but the source does not prove equality or a cross-product mapping. `isMerged`, equal percentages/reset dates, same email, or both apps being installed cannot prove they are the same subscription; xAI explicitly allows unifying accounts with **different emails**. A verified common-ID/link contract is therefore a Step B prerequisite for guaranteed automatic merging. Without it, label source evidence “shared-pool link unverified,” keep it out of additive subscription totals, and do not fabricate one verified ref or silently combine different accounts. If IDs prove distinct seats/legacy plans, keep separate subscriptions. [Account-unification rules][XU]

FEEDFIX coordinates both readers under one conservative xAI/Cursor budget during link discovery, then one canonical shared-pool gate once linked; select **one** route under `preferred` per five minutes (fallback/alternate only in a later eligible slot). Metadata/link requests consume that same gate. Merging aliases merges attempt timestamps conservatively; account/workspace switches invalidate evidence. Never unify accounts at the provider, move tokens between tools, or use public catalogue metadata to assert personal membership.

## Feedback, review and delivery

CLIJIT/App surfaces show **[Missing your tool? Tell us](https://github.com/modelplan/modelplan/issues/new?template=feature.yml&title=Tool%20detection%20request)** in onboarding, the empty state and Settings. Ask only tool name, platform and version; never attach credential paths/contents, identities, tokens or personal feed JSON automatically. Opening the form is explicit; submission is the user's action.

Review this note before Step B; then FEEDFIX opens one provider PR in native-head order, **`[D590] Auto-detect <provider> usage`**. CLIJIT integrates the DTO/status/cancellation interfaces through its own files. Changes to a boundary are handed off before either lane edits a shared path. FEEDFIX tests readers/routing, fixed security invocation, shared locks/backoff, dynamic pin/checksum/last-good activation, registry completeness and identity aliases using synthetic homes, injected subprocesses, fake RPC and `httptest` only. CLIJIT tests detect/consent/revocation/doctor/update/plugin-install and publication consumption, including inert unknown signals and unsafe-path rejection, against the same contract fixtures. App lanes test presentation/visibility wiring. No real credentials or vendor usage calls; no CLI framework, reader implementation or workflow changes are made by this note.

## Evidence and licensing

Inspected CodexBar `0827f30…` and Token Monitor `0c7dd85…` root licences are MIT; Pulse **`fc10fb7f13999d16f27f283c4bd9e83c80a2885d`** is Apache-2.0. Borrow approaches, not code/fixtures/assets. Use Pulse's existence-only discovery, with the owner's pre-checked consent replacing its unchecked chooser; exclude rotation, device-ID creation and browser import. The detector port retains CodexBar copyright (Peter Steinberger, 2026) and full MIT notice in distribution; the signed catalogue references that notice. Grok Build first-party source at `2bdd1d6…` is Apache-2.0 ([licence][GL], [dependency/source-port notices][GN]). Any later substantial MIT reuse retains copyright/licence notices; Apache reuse also preserves applicable notices/attribution and marks modifications. Audit per-file/third-party terms; root licences do not grant provider API approval or branding rights.

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

[ARCH]: https://github.com/modelplan/modelplan/blob/docs/clients-and-readers/docs/clients-and-readers.md
[SEC]: https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials+SecurityCLIReader.swift
