# Reader integration standard

Status: accepted by the owner on 2026-10-29, as part of foundation v2. Use this standard before you add a reader or repair one.
It covers four things: how we classify a reader path, the lines we never cross, how we learn from other quota monitors, and what each integration must produce.
Related documents:

- [`foundation-v2.md`](../architecture/foundation-v2.md)
- [`clients-and-readers.md`](../clients-and-readers.md), the current rules and access classes
- the per-tool reader documents in `docs/*-quota.md`

## 1. Classify the read path, not the tool

One tool can have several read paths. Claude, for example, has local session logs and an account quota read through its saved OAuth login. Classify each path on three axes.

**Carrier**: where the data comes from.

| Code | Carrier | Example |
|---|---|---|
| L | Local JSON, JSONL, log or cache file | Codex session logs, Claude session JSONL |
| S | Local SQLite | Cursor local state |
| J | Status line or hook output | Claude status line (not installed by default) |
| R | Structured RPC of the owning tool | `codex app-server` account read |
| D | Output of the tool's own CLI | Kiro CLI text |

**Authentication**: what proves the user to the vendor. A local read with no network use has none.

| Code | Authentication | Example |
|---|---|---|
| O | The tool's own saved OAuth login, sent to the vendor's usage endpoint | Claude Code OAuth, Gemini CLI login, Grok Build session |
| K | An API key the user has already set | Z.ai, OpenCode Go, MiniMax, Kimi key route |
| C | A browser cookie or session | Web-only services, CodexBar browser-session class |

**Endpoint status**: A means a documented vendor API. Otherwise the endpoint is undocumented, and the integration card records the endpoint and its stability.

**Never used**: W, scraping web pages.

**Tier**: comes from the classification.

| Tier | Paths | First-run consent |
|---|---|---|
| standard, pre-selected | L, S, R, D with no credential sent | Checked |
| standard, not pre-selected | O, and K when the key is already set | Unchecked, with a "select all" control |
| advanced, off by default | C | Not on the first-run screen. Settings only, per subscription |
| not-read | Any path that breaks a red line and has no compliant alternative | Shown with the reason |

O may become pre-selected only by owner decision, after two beta cycles with no credential incident and a re-review.

## 2. Red lines

Each red line is enforced by a test, a type or a lint. Writing it in text is not enough.

| Red line | Enforced by |
|---|---|
| Never refresh, rewrite or revoke another tool's tokens or config | The reader interface has no refresh function. A test asserts that the files under the tool's directory are byte-identical after a read |
| Never persist or copy credentials | Tokens exist only in memory. A test plants canary tokens and scans the cache, logs and diagnostics for them |
| No inference or paid calls | Endpoints come from an allow-list fixed in code. A test fails on any other host |
| At most one remote read per vendor every 5 minutes, with backoff, shared by the CLI, plugins and app | One shared budget file per vendor. A test runs concurrent CLI and app-server reads |
| Detection reads presence only and never scans browser data | The detector types accept paths, bundle ids and Keychain item names only |
| Store keyed hashes only | The identity package is the only writer of identity fields |
| Show the source and time on every value | The row schema requires both fields |
| Fixed destinations; no cross-domain redirect that carries a credential | The HTTP client disables redirects for credentialed requests |
| Stop on 401 or 403 and never retry with other parameters | A classifier table test |
| Per-vendor circuit breaker and remote switch-off | A catalogue flag, with a test |
| Keychain is read only through the app's signing identity, with consent | See ADR 0003. `/usr/bin/security` is never called |

## 3. Reference projects

Look at the official vendor source first. Then compare at least two of these projects that cover the tool, at a pinned commit.

| Project | Licence | Language | Notes for us |
|---|---|---|---|
| [CodexBar](https://github.com/steipete/CodexBar) | MIT | Swift | Widest provider coverage and the most users. In 0.81.0, some providers refresh tokens, launch CLIs or cache credentials, so never copy those paths |
| [Pulse](https://github.com/qunqin24/Pulse) | Apache-2.0 | Swift | 70+ tools, including Keychain and browser-auth handling. Some quota paths are only profiled from fixtures |
| [Token Monitor](https://github.com/Javis603/token-monitor) | MIT | Electron and Node | Cross-platform. Includes a headless agent |
| [ccusage](https://github.com/ccusage/ccusage) | MIT (LICENSE file) | Rust and TypeScript | The reference for parsing Claude and Codex local JSONL |
| [Tokscale](https://github.com/junhoyeo/tokscale) | MIT | — | **Known incident #1001**: it refreshed tokens and logged users out of the original tool. Study it as the anti-pattern |
| [Tokei](https://github.com/cclank/tokei) | README says MIT; no LICENSE file | — | Ideas only. Do not copy code |
| [ClaudeBar](https://github.com/tddworks/ClaudeBar) | Apache-2.0 | Swift | Menu-bar quota |
| [openusage](https://github.com/robinebers/openusage) | MIT | Swift | Multi-subscription handling |
| [Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor) | MIT | Python | Claude windows and burn-rate prediction |

The 10-23 coverage research found that 9 of 12 principal projects send borrowed credentials to account endpoints. That shows the practice is common. It does not show the practice is safe.

## 4. Decision procedure

To add or repair a reader:

1. **Write the integration card** `docs/readers/<tool>.md` from the template in section 5. Fill every field from the vendor source and the reference projects at pinned commits.
2. **List the candidate paths** with their classification (section 1).
3. **Drop every path that breaks a red line** (section 2).
4. **Choose among the remaining paths**, in this order:
   1. the path that sends no credential;
   2. a documented endpoint over an undocumented one;
   3. the path with the fewest reported incidents in the reference projects' issue trackers;
   4. the path that reports quota windows the vendor defines.
5. **If no path survives**, take only the ideas: field meanings, parsing quirks and incident lessons. Then decide one of two outcomes:
   - implement a compliant path the references did not use;
   - mark the tool `not-read`, show the reason, and record it in the card.
6. **Turn every reported pitfall into a synthetic fixture** before writing the reader, and make sure the fixture fails first.
7. **Copy code only under a clear licence.** MIT and Apache-2.0 may be ported with attribution; Apache also needs its NOTICE. Record the port in `docs/borrowed/<source>.md`. Anything without a licence file is ideas only.
8. **Ship at L2.** The reader passes the owner-shaped fixture (ADR 0006) before it is enabled in the catalogue.

Research and card drafting use public material only. That work may go to a lower-cost model, such as GLM Flash or Codex at medium effort. The coordinator reviews the card's choice. A reader lane implements it.

## 5. Integration card template

```markdown
# <Tool> reader card

- Vendor source: <official docs or code, pinned link>
- References compared: <project@commit>, <project@commit>, ...

## Data
- What the vendor reports: <windows, units, resets, plan, credits>
- How each reference reads it: <path, carrier, auth, endpoint, fields> (one line per reference)

## Candidate paths
| Path | Carrier | Auth | Endpoint status | Side effects | Red-line check |

## Incidents and pitfalls
- <issue link>: <what broke> → fixture <name>

## Choice
- Chosen path and tier: <...>
- Why: <...>
- Rejected paths and the red line each one breaks: <...>
- Licence: <ported code and attribution, or ideas only>

## Tests
- Fixtures: <names>
- Owner-shaped case: <which shape fields matter>
```

## 6. Current paths and first batch

This is the code's state on main `f830589`. Each card must verify it before the reader is changed.

| Tool | Current path | Target after the card |
|---|---|---|
| Claude Code | O: saved OAuth from `.credentials.json`, else Keychain via `/usr/bin/security`. L: session JSONL | O: Keychain through the app's identity (ADR 0003). L unchanged. Not pre-selected |
| Codex | L: session logs. R: `codex app-server` account read | Unchanged. Pre-selected |
| Cursor | Saved local sign-in (S/O) | Card decides. Failed on the owner's Mac |
| Gemini CLI | O: saved login. L: local usage | Card decides. Failed on the owner's Mac |
| Grok Build | O: saved session | Card decides. Failed on the owner's Mac |
| Kimi Code | O: login route. K: key route | Card decides. Failed on the owner's Mac |
| Kiro | D: `kiro-cli` text (risk of a paid prompt) | Card decides. `runtime_missing` on the owner's Mac |
| GitHub Copilot | Native, needs the Copilot runtime; CodexBar optional | Card decides. `runtime_missing` on the owner's Mac |
| Z.ai / ZCode | K: ZCode's stored key or an env key | Keep. Card confirms the endpoint |
| OpenCode Go | K: env key | Keep |
| MiniMax | K: env key | Keep |
| Antigravity | Native state reader | Card decides |
| Amp, Droid | No quota reader (`no_reader`) | Card decides whether a compliant path exists |
| Qwen Code | L: a user-selected export | Keep |

**First batch:** Claude, Gemini, Grok, Kimi, Kiro and Cursor. All of them failed on the owner's Mac. Copilot follows.
