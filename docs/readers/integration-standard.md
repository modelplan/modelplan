# Reader integration standard

Status: revision 3, frozen on 2026-10-29. The owner accepted the direction, the K default and the POST gate on 2026-10-29. Part of foundation v2. Use this standard before you add a reader or repair one.

**Transition.** Cards are written reader by reader, but admission gates apply now and override the transition: the POST gate, known red-line violations, readers off and every revoke. Only a reader that already meets the red lines keeps running until its card is written. Foundation v2 unit U2a delivers the gates for the first batch.
It covers four things: how we classify a reader path, the lines we never cross, how we learn from other quota monitors, and what each integration must produce.
Related documents:

- [`foundation-v2.md`](../architecture/foundation-v2.md)
- [`clients-and-readers.md`](../clients-and-readers.md), the current rules and access classes
- the per-tool reader documents in `docs/*-quota.md`

## 1. Classify the read path, not the tool

One tool can have several read paths, and each path is a separate consent **scope**. Claude, for example, has `claude.local_history` and `claude.account_usage.saved_login`. Before you compare paths, decide which **data capability** you need: token history, account quota, or credits/balance. A token history never stands in for an account quota.

Classify each path on four axes:

**Carrier**: where the data comes from.

| Code | Carrier | Example |
|---|---|---|
| L | Local JSON, JSONL, log or cache file | Codex session logs, Claude session JSONL, `.grok/sessions` |
| S | Local SQLite | Cursor app sign-in store, OpenCode history |
| J | Status line or hook output | Claude status line (optional, never installed by default) |
| R | Structured RPC of the owning tool's runtime | `codex app-server` (`account/rateLimits/read`), `kiro-cli acp` (`_kiro/account/getUsage`), Copilot runtime, Antigravity loopback `GetUserStatus` |
| H | Remote HTTPS/JSON endpoint called by ModelPlan | Claude and Gemini usage APIs, Z.ai quota |

**Authentication**: what proves the user to the vendor. Classify by where the credential comes from, not by whether the request carries a Cookie header.

| Code | Authentication | Example |
|---|---|---|
| none | No credential leaves ModelPlan | L, S and J reads |
| runtime | The owning tool's runtime authenticates; ModelPlan never extracts a credential | Codex, Kiro, Copilot, Antigravity R paths |
| O | The tool's own saved login (OAuth file, Keychain item or app sign-in store), sent by ModelPlan over H | Claude, Gemini, Grok, Kimi login route, Cursor |
| K | An API key | Z.ai, OpenCode Go, MiniMax, Kimi key route |
| C | A browser cookie or session | Web-only services; CodexBar browser-session class |

**Method**: GET, or POST. A POST is allowed only through the gate below.

**Endpoint status**: documented (A), or undocumented, in which case the card records the endpoint and its stability.

**Web scraping (W) is never used.**

**Tiers and first-run defaults:**

| Tier | Paths | First run | Status |
|---|---|---|---|
| standard, pre-selected | auth `none` (L, S, J), and auth `runtime` (R, after the side-effect review) | Checked | [owner] |
| standard, not pre-selected | auth O | Unchecked, with "select all" | [owner] |
| standard, key | auth K | Configured for ModelPlan: enabled. Only found in the environment: unchecked | [owner] |
| advanced, off by default | auth C | Not on first run; Settings per subscription | Unchanged |
| not-read | Any path that breaks a red line with no compliant alternative | Shown with the reason | Unchanged |

- **Runtime reads are not automatically safe.** An R path is not "local" or "zero network": the owning runtime calls its vendor. The UI says "Read by <tool>'s own runtime", not "local reading".
  - **The rule.** A query from ModelPlan must not cause the runtime to refresh a token, write state or make a paid call on our behalf.
  - **What recording proves.** Recording the outer RPC proves what we sent, not what the runtime did inside.
  - **What the card records instead:**
    - the runtime version reviewed;
    - the vendor's no-refresh mechanism, if one exists (for example `refreshToken:false`);
    - the observable evidence;
    - what is still unknown.

    An unknown stays marked unknown. "Runtime reviewed" is not a proof.
- **K default [owner, 2026-10-29].** A key the user explicitly configured for ModelPlan (through `modelplan connect` or Settings) keeps its current enabled behaviour. A key merely present in the environment is offered unchecked and is used only after consent.
- **Promotion.** O becomes pre-selected only by owner decision, after two beta cycles with no credential incident and a re-review, per vendor and per path version. Promotion changes the initial choice for undecided users only. It never overrides a denial, a revoke or Passive mode.
- **POST gate [owner, 2026-10-29].** A POST read is allowed only for a vendor the owner approves. Its method, host, path and request-body schema are pinned in code and covered by the recording-transport test. The integration card presents the exact request for the owner's approval. Until a vendor is approved, its POST account-usage scope is disabled: today that means Gemini Code Assist and Cursor plan and period usage. Their local-history scopes are unaffected. Do not convert a POST to a GET and do not self-exempt a "read-only" POST.

## 2. Red lines

Each red line is defined by an **observable forbidden event**, a **place where it is enforced**, a **test seam** and a **failing example**. A type constraint or a green unit test alone does not prove a red line.

| Red line | Forbidden event | Enforced at | Test seam and failing example |
|---|---|---|---|
| Never refresh, rewrite or revoke another tool's tokens or config | Any write to the tool's credential stores, config or Keychain item; any refresh-grant request from ModelPlan; a runtime launched with flags that refresh, or a runtime call the card does not list as no-refresh | Reader capability set (no refresh function); filesystem, keychain and process fakes | Fake FS, keychain and process: a reader that writes `.credentials.json` or calls the token endpoint fails. Runtime R paths: recorded runtime calls checked against the reviewed method list for that runtime version |
| Never persist or copy credentials | A token byte sequence outside `credentials/result` or in-memory request use, in anything ModelPlan writes | Store writers and log and diagnostics serializers | Canary tokens planted in fixtures. A scan of every ModelPlan cache file, log line, diagnostics output, error and cockpit message fails on a hit. The one bounded exception is the advanced browser-session class (C): CodexBar keeps a session cookie in its own Keychain item, never in a ModelPlan store. It exists only while C is granted for that subscription, and Forget clears it. A separate test checks the clearing |
| No inference or paid calls | A request whose method, host, path or parameters are not on the reader's allow-list, or a request beyond the card's fixed request set for one read | HTTP client with a per-reader allow-list of (method, host, path, parameter schema) | Recording transport: a call to an official host's inference path fails, as does any request outside the card's set (for example a third call in a two-request read) |
| Budget: at most one remote read per vendor every 5 minutes, with backoff, shared by the CLI, plugins and app. A read is the card's fixed set of at most two requests (`clients-and-readers.md` §4, unchanged), so Cursor's plan + period and Gemini's project + quota are one read | Two admitted reads for one vendor inside the window, from any process | Shared budget file and provider lock | Concurrent CLI, plugin and app-server runs on one home: the recording transport counts the calls |
| Stop on 401 or 403 | Any further request after a 401 or 403 for that scope, with or without changed parameters | Reader classifier plus the HTTP client | Recording transport: MiniMax's legacy-endpoint retry after 401 or 403 fails this test and must be removed |
| Detection reads presence only | Opening a file's contents, reading a Keychain value, or launching a process during detection | Detector given fake FS, keychain and process with presence-only methods | A detector that calls `read` or `exec` fails |
| No browser data scanned for detection | Any access under browser profile directories during detection | Same fakes | Fails on any access |
| Store keyed hashes only | An identity field written by anything other than the identity package | Store writers | Write-path test |
| Source and time on every value | A displayed value without a `route` code, or a time invented when the source has none | Row schema (`route` required; time nullable) and the renderer | A fixture with a null time must show "time unknown" |
| Fixed destinations; no credential-carrying redirect | Following a redirect on a credentialed request | HTTP client with redirects disabled on credentialed requests | A fake server that redirects: the request must stop |
| Per-vendor circuit breaker and remote switch-off | A read after the vendor is switched off | Catalogue flag checked at admission | Test with the flag set |
| Keychain only through the app's identity and consent | Any call to `/usr/bin/security`; a Keychain read for a scope without its scope consent and Keychain consent; any prompt during a non-interactive operation. A consented background read with UI disabled is allowed | ADR 0003 credential operation | A process fake fails on `security`. A fake Security.framework adapter checks the scope, the consent and the interaction flag of each call: a non-interactive call that allows UI fails |

## 3. Reference projects

Look at the official vendor source first. Then compare at least two of these projects that cover the tool, at a pinned commit.

| Project | Licence | Language | Notes for us |
|---|---|---|---|
| [CodexBar](https://github.com/steipete/CodexBar) | MIT | Swift | Widest provider coverage. In 0.81.0, some providers refresh tokens, launch CLIs or cache credentials, so never copy those paths |
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
4. **Choose among the remaining paths that deliver the needed capability**, in this order:
   1. the path that sends no credential, or lets the owning runtime authenticate;
   2. a documented endpoint over an undocumented one;
   3. the path with the fewest incidents in the reference projects' issue trackers, judged by version and exposure, not by raw count;
   4. the path that reports the windows the vendor defines.
5. **If no path survives**, take only the ideas: field meanings, parsing quirks and incident lessons. Then decide one of two outcomes:
   - implement a compliant path the references did not use;
   - mark the tool `not-read`, show the reason, and record it in the card.
6. **Turn every reported pitfall into a synthetic fixture** before writing the reader, and make sure the fixture fails first.
7. **Copy code only under a clear licence.**
   - MIT and Apache-2.0 code may be ported with attribution.
   - For Apache-2.0, keep the licence headers. If upstream ships a NOTICE file, carry its content.
   - Record the port in `docs/borrowed/<source>.md`.
   - Anything without a licence file is ideas only.
8. **Ship at L2.** Before the reader is enabled in the catalogue, it passes the scenarios its card declares on the owner-shaped home (ADR 0006).

Research and card drafting use public material only. That work goes to a lower-cost model: GLM Flash, or Codex Terra or Luna. Codex Sol is kept for implementation and review that need it. The coordinator reviews the card's choice. A reader lane implements it.

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

This is the state of the code on main `f830589`, checked in the Codex review of revision 1. Each card verifies it again before the reader is changed. "Failed on the owner's Mac" is a symptom, not proof of a reader bug: `runtime_missing` is an environment gap, and it needs a recovery step before any rewrite.

| Tool | Current paths | Target after the card |
|---|---|---|
| Claude Code | O+H: saved OAuth from `.credentials.json` or a custom profile, else, for the default profile only, the Keychain via `/usr/bin/security` (`quota/claudeaccount.go:104–132`). L: session JSONL. J: optional status line (never installed by default) | O: file or custom-profile path kept. The Keychain moves to the app's identity (ADR 0003). L unchanged. O not pre-selected |
| Codex | L: session logs. R: `codex app-server` `account/rateLimits/read`, plus `account/read {refreshToken:false}` for identity (`codexaccount.go:265–289`) | Unchanged. R labelled "read by Codex's runtime" |
| Cursor | O+H: the app sign-in from its SQLite store and a derived session, then a remote **POST** to an undocumented plan and period usage endpoint (`cursor.go:89–154, 454–491`). Not class C | Behind the POST gate; disabled until the owner decides. The card decides the long-term path |
| Gemini CLI | O+H: saved login file, then a Code Assist **POST** (`gemini.go:424–443`). L: local usage and history adapter | Remote scope behind the POST gate. L kept. Two separate scopes |
| Grok Build | O+H: saved session, fixed **GET** billing endpoint. L: `.grok/sessions` history (`localusage/history_adapters.go`) | Card decides. Two scopes |
| Kimi Code | O+H: login route. K: key route. L: `.kimi/sessions/*/*/wire.jsonl` token history | Card decides. Three scopes |
| Kiro | R: `kiro-cli acp`, `initialize`, then only `_kiro/account/getUsage`; no prompt is sent (`quota/kiro.go:18–23, 63, 116–126`) | Runtime side-effect review; show the `runtime_missing` recovery step |
| GitHub Copilot | R: the Copilot runtime RPC (`copilot.go`). L: `.copilot/session-state/*/events.jsonl`. CodexBar bridge only by explicit choice, never as an automatic fallback | Runtime review; `runtime_missing` recovery step |
| Z.ai | K: `Z_AI_API_KEY`, or the explicitly selected Claude Code settings source (`production.go:103–116`). An OpenCode provider/auth source exists in `zaiconfig.go:101–168` but is not admitted (`connect_provider.go:169`). ZCode's local usage (S) is a separate scope | Keep. The card confirms the endpoint and the OpenCode source decision |
| OpenCode Go | K: `OPENCODE_API_KEY`, then a fixed usage GET. OpenCode's local S history is a separate scope | Keep |
| MiniMax | K: `MINIMAX_CODING_API_KEY`. Retries a legacy endpoint after 401 or 403 (`minimax.go:44–57`) | Remove the retry (red line). Disabled until fixed |
| Antigravity | R: verifies the running loopback server, then `GetUserStatus` with transient CSRF metadata (`antigravity.go:108–151`) | Runtime review |
| Amp | L: history. `RefreshAmp` money read exists, but it is not admitted, because no reviewed binary digest exists yet (`docs/production-reader-admission.md:47–50`) | Card decides on admission |
| Droid | L: history. No quota reader | Card decides whether a compliant quota path exists |
| Qwen Code | L: native records with incremental history (`localusage/qwen.go`). Optional aggregate export; the two are de-duplicated (`production.go:135–146`) | Keep both, with the de-duplication rule |

**First batch** (each failed on the owner's Mac): Claude, Gemini, Grok, Kimi, Kiro and Cursor. Copilot and MiniMax follow. The admission gates (see Transition, at the top) apply to all of them now: Gemini Code Assist and Cursor make zero remote calls until their POST cards are approved, and MiniMax stays disabled until its retry after 401 or 403 is removed.

## 7. Keep the research; update it, don't repeat it

Research happens once per tool and is then kept. Two artifacts carry it:

- **Reference index**, `docs/readers/reference-index.md`.
  - A script lists, for each reference project at a pinned commit, the tools it supports, the files that hold each tool's reader, and each path's classification.
  - It starts from the 10-23 coverage research.
  - For a new tool, look the tool up in the index, then read only the two or three projects that cover it, and only their files for that tool.
- **Integration card**, `docs/readers/<tool>.md`. A card is permanent. It records the references compared and their pinned commits, the chosen path, the rejected paths and why, the pitfalls and their fixtures.

Update a card only when one of these happens:

1. Our reader breaks, or fails on a real Mac.
2. The vendor changes the endpoint or the authentication.
3. A reference project changes that tool's files since the card's pinned commit.
4. A new incident about that tool appears in a reference project's issue tracker.

**Watch.** A lower-cost model runs the watch weekly and before each release. It works through these steps:

1. For each reference project, diff that tool's files from the pinned commit to the current head.
2. Scan new issues that mention the tool.
3. Write a short change report.
4. If a card is affected, propose the card update, with what changed and why.

The coordinator reviews each card update. A reader lane changes the code. Because cards and the index persist, a new tool costs one card, and a changed reference costs one card update.
