<!-- SPDX-License-Identifier: MIT -->
# D590: automatic agent usage detection

**Design for owner review · 2026-10-27 · implementation awaits approval.**

Goal: recognise tools already used on the Mac without installing a ModelPlan status line, requesting a pasted API key, or installing another monitor. Implement native readers in `cli/internal/quota`; retain CodexBar only as a compatible, explicitly selected fallback. Build on existing readers and [PR209](https://github.com/modelplan/modelplan/pull/209). Based on the supplied October 23 research and primary sources below; no real credentials or vendor endpoints were accessed.

## Consent and shared rules

Discovery checks known executable/app/extension locations and file existence only: no launches, database/credential reads or Keychain access. “Detected” means installed/configured, **not signed in or subscribed**; successful authenticated responses confirm sign-in. First-run lists detected tools **pre-checked**, with the access lines below. **Allow selected tools** records one consent; **Not now** enables nothing. New tools require selection later.

Consent text: **“Allow ModelPlan to read usage for the selected tools using their existing sign-in. Your credential is sent to that provider to authenticate; it is never sent to ModelPlan servers or stored by ModelPlan. macOS may ask for Keychain access. You can turn this off in Settings.”** Local-only Qwen accounting is marked separately as sending no credential.

- After consent, read only the selected profile's allowlisted fields. Keychain uses the genuine macOS prompt naming the helper; denial stops access. Background work cannot trigger interactive prompts. An invalidated grant needs an explained user action, never a prompt loop or permission workaround.
- Never refresh (even in memory), rewrite, move, delete or copy another tool's credentials into a store. No login/repair, settings changes, key/device-ID creation, inference, turns, warm-ups, reset-credit consumption or browser-cookie harvesting. Expired/rejected tokens mean `open <tool> to refresh`; reread after owner-tool state changes.
- One usage call/provider/**300 seconds minimum**, shared across processes, tools, manual refresh, resume, native and fallback. Persist a ModelPlan-owned attempt gate/lock; use monotonic timing and conservative restart/clock-rollback handling. Errors back off 10/20/40/60 minutes or longer `Retry-After`; authentication failures wait for tool-state changes. Nothing bypasses the five-minute floor.
- Reserve before I/O, failures included. Metadata consumes the same network budget; local RPC handshakes do not. No same-cycle endpoint/fallback waterfall. Allowlist HTTPS hosts/paths, reject redirects/custom destinations, bound reads/processes/responses. Refresh only while Dock/sliver or cockpit is visible and awake; preserve one child and read-only desktop reads.
- Secrets stay transient in memory, never output/logs/cache/receipts. Persist/display identities only as installation-keyed HMACs, separated by provider/region/account/workspace. No raw identities or plain hashes. Cache sanitised last-good readings with original age; errors never make them fresh. Account switches invalidate bindings. Passed resets, missing/stale/unbound readings and local token totals never imply fresh quota or entitlement.

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

### 5. GitHub Copilot — S for CLI; L for IDE-only discovery

**Detect/source:** `copilot` or installed Copilot extension manifests. Reuse native `copilot --headless --no-auto-update --stdio`, negotiated handshake then **`account.getQuota`**, with runtime-owned authentication; no credential file is needed. **Usage/scope:** documented SDK server RPC, including premium-interaction entitlement/reset when supplied. **Expiry:** unavailable auth/capability → open Copilot to refresh; no session or login is created. IDE-only installation does not prove an installed CLI: selected extension credential-store compatibility remains unverified and must fail visibly, without asking users to install a runtime. **Never:** import an unrelated `gh` login, initiate device flow, use org billing APIs as personal quota, or invoke a turn. **Access:** “Ask your installed Copilot runtime to authenticate to GitHub and return account quota.” [G]

### 6. Gemini CLI — M

**Detect/source:** `gemini` and `~/.gemini`; after consent, fresh `~/.gemini/oauth_creds.json` access token/expiry (honour verified tool overrides). **Usage:** `POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota`; model bucket remaining fractions/reset, scoped to the OAuth Code Assist account/project. If project discovery requires `:loadCodeAssist`, that uses a separate budgeted slot; no Cloud Resource Manager account enumeration. API-key/Vertex modes and unsupported tiers remain separate/unavailable rather than inferred. **Expiry:** `expiry_date` safety margin, then open Gemini CLI to refresh. **Never:** Google OAuth refresh, extract client secrets, change login mode or substitute Antigravity. **Access:** “Read Gemini CLI's saved access token and authenticate to Google Code Assist for its account/project quota.” [E]

### 7. Kimi — M

**Detect/source:** `kimi`, `~/.kimi-code`; after consent, fresh `credentials/kimi-code.json` plus existing `device_id` under that home. **Usage:** `GET https://api.kimi.com/coding/v1/usages`, with the required existing device headers; returned five-hour, weekly/monthly pools, not Moonshot API cash. Reuse the native parser. CLI credentials lack issuer provenance: China-only until verified otherwise; never send them to `api.kimi.ai`. **Expiry:** token expiry with safety margin, then open Kimi to refresh; missing device identity means unavailable. **Never:** create a device ID, renew rotating refresh tokens or import browser cookies. **Access:** “Read Kimi Code's existing sign-in/device identity and authenticate to Kimi China for Coding Plan usage.” [K]

### 8. Qwen Code — M local; L for backend quota

**Detect/source:** `qwen`, `~/.qwen/settings.json` and existing stats/project layouts. After consent, identify the selected backend; reuse bounded local aggregate/history readers. **Usage:** no verified universal Qwen Code remaining-quota endpoint. Local stats give observed tokens/model/day, not allowance. A recognised configured GLM/Kimi/etc. backend can use its own native adapter and shared provider budget only after credential/host provenance is established. QwenCloud/Alibaba subscription routes require separate contracts; browser-console cookies are excluded. **Expiry:** local capture age is shown; any supported backend token uses its provider's owner refresh guidance. **Never:** infer cloud quota from `oauth_creds.json`, equate different Qwen/Alibaba plans, or require an export command/install/key paste. **Access:** “Read Qwen Code's local usage; for a supported selected backend, use its existing credential to authenticate only to that provider.” [Q]

## Review and delivery

Review the mechanism and IDE-only Copilot/international Kimi/Qwen quota gaps before Step B. Show unavailable reasons, never invented membership. After approval: one PR/provider in this order, titled **`[D590] Auto-detect <provider> usage`**, with original code/synthetic fixtures. CodexBar fallback must satisfy identical safeguards; no automatic install. Tests: temporary synthetic homes, Keychain doubles, fake RPC and `httptest`; no real credentials/vendor calls. Assert zero credential writes, destinations, expiry, redaction/HMAC, account switches, fallback/restart cooldown, hidden/sleep suspension and last-good age.

## Evidence and licensing

Inspected CodexBar `0827f30…` and Token Monitor `0c7dd85…` root licences are MIT; Pulse **`fc10fb7f13999d16f27f283c4bd9e83c80a2885d`** is Apache-2.0. Borrow approaches, not code/fixtures/assets. Use Pulse's existence-only discovery, with the owner's pre-checked consent replacing its unchecked chooser; exclude rotation, device-ID creation and browser import. Any later substantial MIT reuse retains copyright/licence notices; Apache reuse also preserves applicable notices/attribution and marks modifications. Audit per-file/third-party terms; root licences do not grant provider API approval or branding rights.

Pinned sources, inspected 2026-10-27: [CodexBar licence][CBL], [Token Monitor licence][TML], [Pulse licence][PL] and [third-party notices][PN]; [Pulse discovery][PD]. Provider references:

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
