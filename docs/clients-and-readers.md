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
- One refresh lock per provider. Whichever process holds it calls the provider; the others read the cache. At most one usage call per provider every 5 minutes, with backoff on errors.
- A copy managed by a plugin or by the App never updates itself; its owner updates it (section 6).

## 3. Detection and consent

1. `modelplan detect` lists the tools found on this machine from the **detector catalogue** (section 5). It reads presence only: app bundle IDs, config/credential *paths*, Keychain item *names*, CLI presence. No credential is read and no network call is made.
2. **One consent** covers every detected tool. The App's first-run page, or `modelplan connect --detected` in a terminal or agent, lists the detected tools pre-checked. For each tool it shows where the reading comes from, which provider host receives the tool's own credential, and whether CodexBar reads it. One confirmation enables all checked tools.
3. A tool detected later is offered on its own: an App badge or a one-line CLI hint. Earlier choices are never re-asked.
4. `modelplan disconnect <tool|--all>` and the App's "Forget readings" revoke consent and delete that tool's cached readings.

## 4. Readers

**Head providers, native** (ours): Claude Code, Codex (desktop app, CLI, IDE), ZCode / GLM, Cursor (including The X Subscription's shared pool), Grok Build, GitHub Copilot, Gemini CLI.

**Long tail:** every other provider CodexBar supports is read through the **bundled CodexBar CLI**. It is fetched at a pinned version with a SHA-256 check, under its MIT licence notice, and the user never installs it. It runs only for detected tools that have no native reader, under the same consent, which names CodexBar.

**Routing**, per provider, from the catalogue: `preferred: native | codexbar | off`.

- **Native first.** If a native reader fails in a way that suggests an upstream change (an unexpected schema or an unexplained error, not an expired login), the CLI retries that provider through CodexBar when CodexBar supports it. The source is marked "via CodexBar (fallback)".
- **Remote switch.** Flipping `preferred` in the catalogue moves every user within hours, for example to CodexBar while our fix ships. `off` is the kill switch if a provider must stop being read.
- **One reading per subscription.** Identities are keyed hashes, so a subscription reached through several tools (Codex app/CLI/IDE; Grok and Cursor on The X Subscription) is shown once, from one reader, with the source in the details.

**Safeguards, all readers:**
- Never refresh, rewrite, copy or move another tool's credentials. An expired login is reported as "open <tool> to refresh".
- Never call inference or consume reset credits.
- Never print or store secret values; store only sanitised readings and keyed-hash identities.
- Tell the user, in the consent text and the privacy page, that a tool's credential is sent to that tool's own provider to authenticate.
- On macOS, read Keychain items through `/usr/bin/security`. "Always Allow" then attaches to Apple's stable binary rather than to each new ad-hoc-signed CLI build, so updates do not re-prompt.

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

- The X Subscription: whether the Cursor reader, a Grok Build reader, or both see the shared pool; how to de-duplicate (design note, FEEDFIX).
- Codex desktop app session-log location (M2 audit) for the passive path.
- Privacy page and in-app consent wording, reviewed by the owner before the first credential-reading release.
- Licence notices for CodexBar (MIT) and any Pulse-derived logic (Apache-2.0) in the CLI's `THIRD-PARTY-NOTICES.md` and the App's About → Licences.
