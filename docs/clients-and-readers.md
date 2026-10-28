# Clients, readers and updates

Owner decisions, 2026-10-27. This is the reference for how the Mac App, the plugins, the Skill and the CLI fit together; how a tool's usage is detected and read; and how detection, CodexBar and the CLI itself are kept current. Anything not decided here stays as it is.

## 1. Roles

| Surface | Role | Who it is for | Owns | Never |
|---|---|---|---|---|
| **CLI** (`modelplan`) | The single data engine | Everyone, usually without knowing it; terminal and Linux users directly | Verified publication sync, tool detection, quota readers, history, advice, consent records | A UI of its own beyond the terminal |
| **Mac App** | A dashboard for people | Mac users who want quota at a glance outside any agent | Dock, cockpit, notifications, Settings, the first-run consent screen, one-click plugin install | Reading quota or computing advice itself: it asks its bundled CLI |
| **Plugins** (Claude Code, Codex) | Automatic in-agent help | People who use Claude Code or Codex | Prompt-time hints and the task-start brief (hooks), slash commands, Codex's panel; bundle the Skill and fetch the pinned CLI | Duplicating CLI logic; the Codex panel is feature-frozen |
| **Skill** (`model-plan`) | The playbook an agent follows | Any coding agent; also the light option for people who do not want hooks | How to answer model/effort questions and how to call the CLI | Installing anything without asking once |

**The ladder:** Skill (public data only) → Skill + CLI (your own quota, when asked) → plugin (automatic). The App sits alongside any rung. Public pages lead with three entries: App, plugins, Skill. The standalone CLI is "Advanced".

**Who installs the CLI:** plugins fetch their pinned copy; the App bundles one; the Skill asks once and then runs `scripts/install-cli.sh` (pinned version, SHA-256 checked, into `~/.local/bin`). GitHub Releases remain the distribution source for all of them.

## 2. One machine, several CLI copies

A machine may hold the plugin's copy (`~/.cache/modelplan-cli/<version>/`), the App's bundled copy, and a standalone copy. They share one data directory (cache, consent, readings, history).

- Every shared file carries a schema version. Changes are additive, and readers ignore unknown fields, so an older copy never breaks on a newer copy's files and the other way round.
- One refresh lock per provider. Whichever process holds it calls the provider; the others read the cache. At most one read per provider every 5 minutes (section 4), with backoff on errors.
- A copy managed by a plugin or by the App never updates itself; its owner updates it (section 6).

## 3. Detection and consent

1. `modelplan detect` lists the tools found on this machine from the **detector catalogue** (section 5). It reads presence only: app bundle IDs, config/credential *paths*, Keychain item *names*, CLI presence. No credential is read and no network call is made.
2. **One consent** covers every detected tool. The App's first-run page, or `modelplan connect --detected` in a terminal or agent, lists the detected tools pre-checked. For each tool it shows where the reading comes from, which provider host receives the tool's own credential, and whether CodexBar reads it. One confirmation enables all checked tools.
3. A tool detected later is offered on its own: an App badge or a one-line CLI hint. Earlier choices are never re-asked.
4. `modelplan disconnect <tool|--all>` and the App's "Forget readings" revoke consent and delete that tool's cached readings.

### App consent API

`modelplan consent --json` is a cache-only, presence-only read. It returns
`generation`, integer `consentTextVersion`, effective `mode`
(`automatic|passive|off`), `consentText: {"en": "…", "zh": "…"}`, and detected
`tools`. Each tool includes `id`, `displayName`, `accessClass`
(`standard|browser-session|not-read`), `detected`, saved `allowed`, catalogue
`backend` and `readerId`, Keychain consent `keychain` (`allowed|denied|unset`), and provider
`hosts`. Show the returned text and hosts before submitting consent. Detection
does not establish a login, and saved permission does not override privacy or a
catalogue kill switch. No credentials, network, processes or cache writes are
used by this read.

`modelplan consent grant --json` accepts one JSON object on stdin (at most 64 KiB):

```json
{"requestId":"d91cd465-a255-4bd4-bfed-47ddab82f682","expectGeneration":0,"consentTextVersion":2,"allow":["claude","codex"],"deny":[],"keychain":{"claude":"allow"}}
```

Copy both version fields from the read response; do not hardcode the example.
The command atomically applies all listed decisions and increments generation
once. Omitted tools keep their records. Success returns
`{"ok":true,"requestId":"…","generation":1,"tools":[…]}` with the same tool
shape as the read. Repeating the same UUID and request returns the saved result
without writing, even after a later decision; changed contents with that UUID
fail with `request_id_conflict`. Receipts, pending Forget obligations and
Keychain restrictions survive writes by pre-API CLI copies sharing schema 1.
Retained receipts share the consent file's
256 KiB bound; a full file rejects a new transaction without changing grants.

Failures use JSON `{"ok":false,"error":"…"}` and a nonzero exit status.
`stale_generation` and `stale_consent_text` change no permissions: reread and
show the current text before a new request. Unknown or undetected IDs fail the
whole transaction with `unknown_tool`. Only standard routes can be allowed;
browser sessions require their separate advanced action. Disabled readers fail
with `readers_off`, including `MODELPLAN_READERS=off`; passive settings remain
restrictive. Keychain entries must name a listed decision and use `allow|deny`.
Only the native Claude route uses this permission; choices for other routes fail
atomically with `keychain_not_supported`, and their readback stays `unset`.
Readback and production share the same consent policy: legacy `connect` grants
include Keychain permission and report `allowed`; passive/off or source Deny
reports `denied`. New API grants default to `unset` and cannot use Keychain
until allowed. Omitting a choice preserves existing permission. Recording a
choice never prompts. Existing source Deny and local-source opt-outs remain in
force.
On macOS, an allowed native Claude grant with Keychain unset includes `notice` and
`nextStep: "Allow Keychain for Claude Code in Settings"`. A refresh that needs
Keychain reports the same cause/action; a file-based login still works without
Keychain permission. Linux keeps the saved-login notice and omits the macOS
Keychain remedy from consent readback. Omitting `--json` prints command usage
on stderr.

Denials revoke first and perform the same scoped Forget cleanup as disconnect,
retaining request gates, identities and other tools. If cleanup cannot finish,
the durable response is `cleanup_pending` with the committed `generation` and
`pendingForget` IDs; permissions remain revoked. Cookie-cache obligations also
stay pending because this API never starts a helper that could prompt Keychain.
Use the explicit `disconnect <tool>` / advanced Forget action to retry cleanup;
replaying the request returns its original receipt. New production paths admit
the new generation, and old in-flight reads fail their `StillValid` fence.

应用使用 `consent --json` 显示返回的中英文授权原文及服务商主机，再以同一文本版本和
generation 提交 `consent grant --json`。请求以 UUID 幂等，标准授权不包含浏览器会话，
只记录钥匙串选择、不触发提示；拒绝先撤销权限，未完成的清理以 `cleanup_pending`
返回并保留义务，可通过显式断开操作重试。隐私限制、拒绝状态及停用开关始终有效。

## 4. Readers

**Head providers, native** (ours): Claude Code, Codex (desktop app, CLI, IDE), ZCode / GLM, Cursor (including The X Subscription's shared pool), Grok Build, GitHub Copilot, Gemini CLI.

**Long tail:** every other provider CodexBar supports is read through the **bundled CodexBar CLI**. It is fetched at a pinned version with a SHA-256 check, under its MIT licence notice, and the user never installs it. It runs only for detected tools that have no native reader, under the same consent, which names CodexBar, and only for providers whose CodexBar path is **audited** at the pinned version: no token refresh, no copy or cache of the tool's credentials, no launching the provider's CLI, no inference. Unaudited providers show "not yet supported". (CodexBar 0.81.0 refreshes some providers' tokens, launches provider CLIs and caches credentials in its own Keychain item, so the audit is per provider.)

**CodexBar access classes** (owner-approved 2026-10-27), recorded per provider in the catalogue:
- **Standard:** the tool's own local login or CLI, no token refresh. CodexBar runs with `CODEXBAR_DISABLE_KEYCHAIN_ACCESS=1` (no credential cache, no Chromium cookie decryption) **and** cookie source `off` for every provider, because Firefox cookies are plaintext and Safari's are readable with Full Disk Access, neither needing the Keychain. Included in the one-click consent.
- **Browser session (advanced):** providers readable only from a browser sign-in (about 50 at 0.81.0, e.g. Windsurf, Devin, Augment, Qoder, Trae CN, Perplexity, Manus, Mistral). Off by default and never in the one-click consent. The user turns each one on separately; the explanation says macOS will ask for the browser's "Safe Storage" key, which unlocks that browser's saved sign-ins, and that CodexBar keeps the session cookie in its own Keychain item. "Forget readings" also clears that cookie cache. Background refreshes never trigger a Keychain prompt; only a user action may, and a denial is not re-asked for six hours (CodexBar's own policy).
- **Not read:** providers whose CodexBar path refreshes tokens (e.g. Antigravity, Factory, StepFun, Vertex AI); head providers use our native readers instead. API-key-only platforms are not offered.

**Where users choose:** the first-run page lists the tools detected from local signals in two groups: standard (pre-checked) and browser session (advanced, unchecked, with a one-line note; checking one shows the full explanation). Settings → Subscriptions has a per-subscription reading-source switch, and "Add subscription" for web-only services with no local signal. Detection never scans browser data.

**Routing**, per provider, from the catalogue: `preferred: native | codexbar | off`.

- **Native first; CodexBar fallback only through an audited path.** Head providers follow the same audit as the long tail: fallback is allowed for a provider only when CodexBar's path for it is in the standard class (no token refresh). At 0.81.0 CodexBar's Claude, Codex, Gemini and Grok paths refresh tokens and Copilot uses CodexBar's own GitHub login, so those have no fallback; Cursor's local-app path may qualify after the audit. Without an eligible path, a native reader that fails on an upstream change shows "temporarily unavailable" until our fix ships.
- **Remote switch.** Flipping `preferred` in the catalogue moves every user within hours, for example to an audited CodexBar path while our fix ships. `off` is the kill switch if a provider must stop being read.
- **One reading per subscription.** Identities are keyed hashes, so a subscription reached through several tools (Codex app/CLI/IDE; Grok and Cursor on The X Subscription) is shown once, from one reader, with the source in the details.

**Safeguards, all readers:**
- Never refresh, rewrite, copy or move another tool's credentials. An expired login is reported as "open <tool> to refresh".
- Never call inference or consume reset credits.
- One **read** per provider every 5 minutes or more. A read is a fixed, documented set of at most two requests (for example Claude usage + profile, Cursor plan info + period usage, Gemini project + quota); stable metadata is cached for up to 24 hours, so most reads are one request.
- Never print or store secret values; store only sanitised readings and keyed-hash identities.
- Tell the user, in the consent text and the privacy page, that a tool's credential is sent to that tool's own provider to authenticate.
- On macOS, read Keychain items through `/usr/bin/security`. "Always Allow" then attaches to Apple's stable binary rather than to each new ad-hoc-signed CLI build, so updates do not re-prompt. This applies to our own readers; the pinned, stably signed CodexBar binary may use its own Keychain access.
- Launching a provider's CLI is allowed only for an audited read-only command that consumes no quota (for example `copilot --headless … account.getQuota`).

**No prerequisite installs (owner, firm):** nothing may require the plugin or the Claude Code status line. Claude Code's current model, effort and Fast state are read passively from its own local session records, the same way Codex rollouts are read. The status line and plugin hooks are optional extra sources only.

Codex needs no credential: `codex app-server` reports the account's windows (`quota --refresh-account`). The App runs that refresh on start, on resume and every 5 minutes while a Dock or cockpit is visible.

## 5. The detector catalogue (data, not code)

The catalogue is a new section of the signed public publication. The CLI already fetches the publication every 10 minutes with jitter: a pointer with an ETag, then an immutable manifest, then content-addressed components, each verified before the cache switches, all behind Cloudflare.

- **`detectors[]`:** provider id, display name, signals (whitelisted types only: `bundleId`, `path` within a documented home-relative set, `keychainItem` name, `command` presence), the reader id, `preferred`, and the minimum CLI version.
- **`codexbar`:** version plus per-platform SHA-256. This replaces the pin compiled into the CLI, so a tested CodexBar upgrade reaches users without a CLI release. A checksum mismatch keeps the last good binary.
- **`cli`:** latest version plus per-platform SHA-256 (section 6).

No executable content, arbitrary commands or arbitrary paths. Unknown signal types are ignored by older CLIs. The first catalogue ports CodexBar's provider detection signals, with attribution.

| Change | Path | Time to users |
|---|---|---|
| A tool CodexBar already supports, or a moved path or renamed Keychain item | Catalogue entry | Hours |
| A new tool supported by a newer CodexBar | Catalogue `codexbar` pin + detector | Hours, after our test |
| A new or changed native reader | CLI release, then plugin pin / App update | Days |

## 6. Keeping things current

- **CodexBar monitor:** the existing `codexbar-pin` workflow runs **daily**. It detects new releases, runs the live contract test, diffs CodexBar's provider list and detection signals, and opens one PR proposing the new pin plus catalogue changes. After review it is published in the catalogue.
- **The CLI itself:** a plugin's copy updates with the plugin (`cli-pin.json`), and the App's copy updates with the App (Sparkle, once distribution is enabled). A standalone or Skill-installed copy reads `cli` from the publication, never the GitHub API, and prints one hint: "a newer version is available; run `modelplan update`". It updates only on that explicit command, with the same checksum rule.
- **Breakage signals** (no telemetry): CodexBar release notes, the daily monitor, our contract tests, and user reports. `modelplan doctor --share` prints a sanitised source/status report users can paste into an issue.

## 7. Plugin install from the App

The App's Settings offer "Install for Claude Code" and "Install for Codex". When the `claude` / `codex` CLI is present, the button runs the documented commands (`claude plugin marketplace add modelplan/modelplan` and `… install modelplan@modelplan`; `codex plugin marketplace add …`) after one confirmation. Otherwise it copies the commands and opens the docs.

## 8. Open items

- The X Subscription: both the Cursor and Grok Build readers can see the shared pool, but no provider ID proves two readings are the same seat yet. Until a verified common ID or link exists, they stay separate and labelled "shared-pool link unverified", never summed (FEEDFIX design note).
- Claude Code session fields: confirmed on the owner's machine on 2026-10-27 with a sanitised probe (field names and short enums only): assistant records carry top-level `effort` (e.g. `high`), `message.model` and `message.usage.speed` (`standard`/`fast`). The passive reader still treats them as optional, because older records may lack them.
- ZCode: no decryption of its encrypted credential store in v1.
- Codex desktop app session-log location (M2 audit) for the passive path.
- Privacy page and in-app consent wording, reviewed by the owner before the first credential-reading release.
- Licence notices for CodexBar (MIT) and any Pulse-derived logic (Apache-2.0) in the CLI's `THIRD-PARTY-NOTICES.md` and the App's About → Licences.

## 9. Gaps closed by design (coordinator review, 2026-10-27)

**Must hold before the first credential-reading release**
1. **Consent scope:** one consent covers ModelPlan on this macOS user account: the App, the plugins and every CLI copy, because they share the data directory. The consent text says so.
2. **Privacy levels (owner-approved 2026-10-27):** Settings and `connect` offer **Automatic** (the default: detected tools, including credential-based readers) and **Passive only** (no credential reads: Codex app-server, session logs, the optional Claude Code status line, explicit keys). Cautious users and managed Macs keep working without credential reads. `MODELPLAN_READERS=passive|off` enforces the same.
3. **Keychain prompt UX:** the consent page warns that macOS will ask once per tool. A "Deny" marks that tool denied and is never re-prompted automatically; the user can retry from Settings.
4. **Plans without quota windows:** API-key / pay-as-you-go use and team or enterprise pools the user cannot see are shown as "pay-as-you-go" or "managed by your organisation", never as 0% or 100%.
5. **Several accounts per provider:** personal and work logins (several `CLAUDE_CONFIG_DIR`s, Codex profiles) are separate subscriptions with their own keyed refs and user aliases.
6. **Proxies:** an App launched from Finder has no proxy environment. The App passes the system proxy settings to the CLI; the CLI honours them for provider and publication calls.
7. **Beta label (owner-approved 2026-10-27):** a reader stays "beta" in the UI and the catalogue until it has been verified on a real account (the owner's or an opted-in tester's). Beta readers still respect every safeguard.
8. **Failure display:** no tool detected, denied, expired login, unsupported, estimated and stale are distinct states, each with one next step. A broken reader never shows a guessed number.
9. **Notices and legal:** CodexBar (MIT) and any Pulse-derived logic (Apache-2.0) are listed in `THIRD-PARTY-NOTICES.md` and the App's About → Licences. The privacy page is updated and reviewed by the owner.

**Operations**
10. **Rollback:** a bad catalogue or pin is reverted by publishing the previous publication. Clients keep the last verified catalogue and CodexBar binary if a newer one fails to verify.
11. **Version skew:** each catalogue entry carries `minCli`. An older CLI skips entries it cannot serve, and the App says "update to read <tool>" instead of failing silently.
12. **Energy:** background refresh runs only while a Dock, cockpit, plugin hook or explicit command needs it. Per-provider calls stay at five minutes or more, and CodexBar runs only for detected, consented tools.
13. **Upstream watch:** the existing official-source monitoring also watches the head tools' release notes and auth/usage docs, so breaking changes surface before users report them.
14. **Support matrix:** the website shows a "supported tools" table generated from the catalogue: native, via CodexBar, beta.

**Later**
15. Linux credential stores (Secret Service) for tools that use them; Linux keeps file-based and passive sources first.
16. A China-reachable mirror of the publication (China and the US are the main markets), if users in China report sync failures (to verify).
17. Team/enterprise admin readers, only if a provider offers a member-visible endpoint.
18. Keep terms distinct: the App's red threshold is a level (remaining ≤ threshold); the CLI's "tight" is a pace (on track to run out before the reset). Both appear consistently in the App, the hints and the docs.
