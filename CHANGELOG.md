# Changelog

Releases of the `modelplan` CLI and the plugins in this repository. Binaries are on [Releases](https://github.com/modelplan/modelplan/releases). The website and data change continuously; see [modelplan.ai/updates](https://modelplan.ai/updates).

## Unreleased

These ship with the next CLI release; its pin PR gives them a version heading.

## CLI v0.5.41, Codex plugin 0.15.33 and Claude Code plugin 0.7.32 (2026-10-27)

- Catalogue helper routes now distinguish audited standard, separate advanced browser-session and not-read access. Standard consent excludes browser sessions and forces both the Keychain gate and `cookieSource: off` across the complete effective helper registry, verified after normalization, including for Firefox/Safari cookies. Only the explicitly granted browser-session target gets `cookieSource: auto`; user-set Keychain disables remain in force. `connect <tool> --browser-session` explains Safe Storage/cookie caching and grants one provider explicitly. Forget atomically captures current cookie-cleanup obligations during revocation and keeps blocked cleanup pending. All connect JSON paths are previews; confirmations name destination hosts. Privacy/revocation gates now also protect Qwen status exports and generation-fenced refresh/snapshot/history writes.

- CLI `connect --detected` adds a pre-checked, single-confirmation consent chooser and read-only JSON preview, shared versioned per-tool grants, automatic/passive privacy (`MODELPLAN_READERS=passive|off`), persistent source denials, and one-time new-tool hints. `disconnect <tool|--all>` revokes first and deletes ModelPlan-owned readings while retaining other tools and request gates. Unreviewed helper routes and incompatible catalogue entries cannot admit readers.

- Add the beta China-only Kimi Code saved-login reader with the existing device identity, one usage request and no credential refresh or device creation. Login and explicit-key routes share a persisted attempt floor/backoff; other quota durations retain labels and reset-past windows leave current projections.
- Add the beta native Grok Build saved-session reader: one read-only billing request for included periods and separate prepaid USD balance, with shared-consent admission, backoff and conservative Cursor/Grok spacing. Shared-pool links remain unverified; no refresh, login launch, inference or automatic account merging.
- Add the beta native Gemini CLI OAuth-file quota reader, with explicit shared consent, at most Code Assist metadata + quota per read, separately aged Google One AI credits and model/request counters. No OAuth refresh, project enumeration, inference or CodexBar fallback; unsupported login modes make no request.
- Add the beta native Claude Code account quota reader, admitted through the shared consent interface: OAuth usage/profile and a bounded `/usr/bin/security` adapter that persists Deny and confirmation-needed states. Prepaid credits are omitted from v1; only evidenced usage windows and extra-usage spend/limit are read. No credential refresh or inference calls; command/consent wiring belongs to the CLI framework.
- Cursor's beta saved-login reader uses at most plan-info + period-usage per read, with explicit shared-consent admission, a five-minute floor, cached metadata and last-good capture retention. Eligible X Subscription pools stay labelled link-unverified and non-additive until a verified common ID exists.
- CLI `modelplan detect [--json]` checks tool presence from a verified cached catalogue or a built-in bootstrap, without credential contents, network calls, tool launches or cache writes. Unknown signals/rules are inert; incompatible `minCli` entries request an update.

- CLI publication refreshes spread load with independent uniform 0–60 second jitter before interval-triggered online checks and on the 10-minute check interval. Caller deadlines are preserved; first checks, explicit syncs and offline/cache reads have no added pre-check delay.

- Both plugins and their bundled Skill pin CLI v0.5.41 and its published archive checksums.

## CLI v0.5.40, Codex plugin 0.15.32 and Claude Code plugin 0.7.31 (2026-10-26)

- `modelplan advise`: **no spending ahead of a reset that already came.** A Codex reset can land
  before its stated time, before the announcement is seen, or minutes before the post itself,
  while the public record still says "announced". `announced_reset_with_surplus` now needs a
  reading taken after the post, and is not given when that reading shows the reset reached the
  account: the longer window began after the post (or within six hours before it), or, after the
  hint, restarted or has 10 points more left. The "Codex announced a usage reset" news is dropped
  for the same reason, and the switch-back comes as soon as an early landing shows instead of
  waiting for the stated time.
- Both plugins pin CLI v0.5.40 and its published archive checksums.

## CLI v0.5.39, Codex plugin 0.15.31 and Claude Code plugin 0.7.30 (2026-10-25)

- A weekly default-effort suggestion from the user's own local quota history. After three
  comparable finished weekly cycles, `modelplan history` and the hooks' user-facing message may
  suggest one published effort step up (often well under the limit) or down (often at the
  limit), with the published reference-cost ratio. Nothing leaves the machine; the agent never
  sees it.
- `modelplan history --effort-suggestion dismiss|off|on`, and `MODELPLAN_EFFORT_SUGGESTION=off`.
- `desktop --json` adds an optional `effortSuggestion` (contract version stays 1).
- Both plugins pin CLI v0.5.39 and its published archive checksums.

## CLI v0.5.38, Codex plugin 0.15.30 and Claude Code plugin 0.7.29 (2026-10-25)

- `modelplan publication --json` passes through the published lineage selection results:
  per-model `lineageId`, `lineageStatus` (`current`, `older`, `preview`, `retired`) and
  `defaultSelected`, plus the publication's `selectionRevision`. Missing or null values mean
  unknown. The `lineageSelection` capability is now `publication-dependent`; contract version stays 1.
- The public reader accepts these optional fields.
- Both plugins pin CLI v0.5.38 and its published archive checksums.

## CLI v0.5.37, Codex plugin 0.15.29 and Claude Code plugin 0.7.28 (2026-10-25)

- Public display names now read "ModelPlan" in the CLI output, the plugins and the Skill.
  Command, package and repository identifiers stay lowercase.
- `modelplan desktop --json --read-only` and `modelplan publication --json` add
  `contractVersion: 1` and a `capabilities` map (frozen desktop contract v1). Existing
  fields and `schemaVersion` are unchanged. Schemas are in `schema/`, synthetic goldens in
  `testdata/contract-v1/`.
- `publication --json` also carries the verified public reset announcements and
  confirmations, scoped windows, quota multipliers with their horizon, and plan metering.
- Capabilities mark credit history, reset-drop provenance and model-lineage selection as
  unavailable instead of inventing values.
- Both plugins pin CLI v0.5.37 and its published archive checksums.

## CLI v0.5.36, Codex plugin 0.15.28 and Claude Code plugin 0.7.27 (2026-10-24)

- Claude Code and Codex prompt hooks give the model one factual line when the harness's
  5-hour or weekly quota falls below 15% remaining, and one after that window resets
  with more than 50% remaining. Each low/reset line fires at most once per window per thread.
- These lines use the hook's English/Chinese setting and show only the window, remaining
  percentage and time to reset. Unknown or stale readings never trigger them; quota is read
  from the local cache without waiting on the network. Existing advice stays in the user's
  `systemMessage`, separate from the model's `additionalContext`.
- `MODELPLAN_TASK_BRIEF=off` disables the quota lines along with the task-start brief.
  Session state is stored beside the brief state with the same eight-day expiry and cleanup.
- Both plugins pin CLI v0.5.36 and its published archive checksums.

## CLI v0.5.35, Codex plugin 0.15.27 and Claude Code plugin 0.7.26 (2026-10-24)

- Cursor personal-plan quota is opt-in with `modelplan connect cursor`. It reads only
  `cursorAuth/accessToken` from the editor's `User/globalStorage/state.vscdb`, read-only,
  including existing WAL state: `~/Library/Application Support/Cursor/` on macOS,
  absolute `$XDG_CONFIG_HOME/Cursor/` or `~/.config/Cursor/` on Linux, `%APPDATA%/Cursor/` on Windows.
  It calls private dashboard JSON on `cursor.com` (`/api/usage-summary`,
  `/api/dashboard/get-plan-info`, legacy `/api/usage?user=...`) and, for unified plans,
  `api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage`. Included requests,
  monthly/weekly pools, usage-based spend and reset dates stay distinct. Tokens are never
  refreshed, rewritten, copied or stored; expired, sealed or opaque sign-ins remain unknown.
  `modelplan connect cursor --backend codexbar` explicitly selects the existing fallback.
- MiniMax plan quota is opt-in with `modelplan connect minimax --region international|china`.
  It reads only `MINIMAX_CODING_API_KEY` (or `--key-env NAME`) and calls
  `GET /v1/token_plan/remains` on `api.minimax.io` (default) or `api.minimaxi.com`.
  The same-host legacy `/v1/api/openplatform/coding_plan/remains` is tried only after
  endpoint/auth rejection; no cross-region retry occurs. The current route is documented on
  `www.minimax.io`; API subdomains, response schema and the legacy route are compatibility
  interfaces. Remaining percentages take precedence over legacy remaining counters; missing,
  inactive, unfamiliar or expired values stay unknown. No credential files, browser sessions,
  refresh, inference or API cash balance are used, and keys are never printed or stored.
- Both quota readers remain off until connected. `modelplan disconnect <provider>` or
  `MODELPLAN_NATIVE=off` stops reads. Connections and desktop diagnostics disclose the source
  path or environment variable, called hosts and endpoint documentation status; snapshot v1
  adds diagnostics without changing existing quota meanings. Identity references use local keyed hashes.
- `modelplan publication --json [--offline]` returns one public-only object with
  `schemaVersion: 1`, `publicationId`, nullable `publishedAt`, `units`, `models[]`, `lineups[]`
  and `speedTiers[]`. `lineups` is an array, unlike `lineup --json`'s developer-keyed object.
  Published order, unknown `null` values and speed qualifiers are preserved; no ranking is inferred.
  Online it anonymously refreshes verified public data; `--offline` re-verifies the cache without
  network requests or writes. It reads no account data, credentials, quotas or personal history.
- Validation uses handwritten synthetic fixtures and local test servers. Live accounts,
  endpoint acceptance and all platform/region/plan combinations were not verified; no real
  vendor credentials or quota endpoints were used during testing.
- Both plugins pin CLI v0.5.35 and its published archive checksums.

## CLI v0.5.34, Codex plugin 0.15.26 and Claude Code plugin 0.7.25 (2026-10-23)

- Quota windows become unknown (`--`) once their reset passes without a fresh reading.
  CLI readers, the Python Skill and desktop snapshots withhold the old percentage and explain why.
- Copilot premium-request quota is opt-in with `modelplan connect copilot`: the signed-in
  runtime's `account.getQuota` returns monthly used/limit/reset without a session or inference.
  Copilot owns GitHub access (normally `api.github.com`); modelplan imports no token and makes no
  direct vendor HTTP call. `MODELPLAN_COPILOT` can select the executable; the explicit
  `--backend codexbar` option keeps the existing bridge available as a fallback.
- Gemini local tokens/model/day/session history is opt-in with `modelplan usage gemini enable`.
  It reads `~/.gemini/tmp/*/chats/session-*.{json,jsonl}` and the legacy root layout; an absolute
  `MODELPLAN_GEMINI_HOME` overrides the root. `disable`, `MODELPLAN_GEMINI=off` or
  `MODELPLAN_HISTORY=off` stops it. No executable, credential file, host or remote quota is read/called.
- Kimi Code plan quota is opt-in with `modelplan connect kimi --region china|international`.
  It reads only `KIMI_CODE_API_KEY` (or `--key-env NAME`) and calls the undocumented compatibility
  `GET /coding/v1/usages` on `api.kimi.com` or `api.kimi.ai`. The key is never printed/stored;
  no OAuth, cookies, credential files, inference or Moonshot balance is used.
- Qwen local tokens/model/day/session history is opt-in with `modelplan usage qwen enable`.
  It reads `~/.qwen/projects/*/chats/*.jsonl` and legacy tmp/root chat layouts;
  `MODELPLAN_QWEN_HOME` overrides the root. `disable`, `MODELPLAN_QWEN=off` or
  `MODELPLAN_HISTORY=off` stops it. No executable, credential file or host is accessed.
  Optional `qwen-usage --export PATH` / `MODELPLAN_QWEN_USAGE_EXPORT` reads local aggregate JSON
  exports separately, without enabling or double-counting session history.
- `modelplan connections` discloses each source and host boundary. New sources are off by default;
  `modelplan disconnect <provider>` or `MODELPLAN_NATIVE=off` stops native quota reads.
  Local Gemini/Qwen history preserves unknown counters, deduplicates records and reports bounded
  coverage; desktop schema v1 adds fields without changing existing quota/speed meanings.
- Validation uses synthetic fixtures. Live accounts, endpoint acceptance and future tool schemas
  were not verified; no real account data or vendor quota endpoints were accessed during testing.
- Both plugins pin CLI v0.5.34 and its published archive checksums.

## CLI v0.5.33, Codex plugin 0.15.25 and Claude Code plugin 0.7.24 (2026-10-23)

- Personal snapshot v1 adds local-day `perfStats[].windows.today`, per-source `todayTotals[]`,
  recent `liveSessions[]` with a 60-second generation rate, and two-day `hourly[]` buckets.
- Input, cache-read and cache-write tokens are nullable in performance/daily/hourly sums. Codex
  inclusive input is normalized without double-counting its usage notice; old unknown data stays null.
- Separate local subagent logs can appear as independent live sessions. SQLite agents keep their
  no-first-token limitation; no new account call, upload or content collection is added.
- History-off stops new recording; read-only projection preserves it. The snapshot docs describe
  timing boundaries, DST, sample gates and bounded retention. Desktop parser types accept the additions.
- Complete the existing macOS CLI dependency notices for go-isatty and go-strftime (no dependency change).


- Both plugins pin CLI v0.5.33.

## CLI v0.5.32, Codex plugin 0.15.24 and Claude Code plugin 0.7.23 (2026-10-22)

- The CLI, the publication reader and the Codex plugin now skip manifest component kinds they do not know, instead of rejecting the whole publication. This lets the producer add page-sized slices (modelplans.ai #544) without breaking installed clients.
  - Unknown kinds still need a well-formed name and reference (hash, size, schema version), and are never downloaded.
  - The seven base kinds and `client` remain required. A manifest may list at most 32 kinds.
- The desktop snapshot (schema v1, additive) gains `dailyLong[]` and `dailyLongCoverage`: observed output tokens and requests per local day, source and model over the last 371 days (53 weeks), for a year-long heatmap.
  - They come from a new local ledger, `observed/daily-long.json`. It keeps the days `perf.json` lets go after 35 days, counts nothing `perf.json` did not, from the same `since`, and stays below 1 MiB.
  - It holds only days, model names and the two sums: no prompts, paths, projects, sessions or ids. `MODELPLAN_HISTORY=off` stops it.
  - `docs/personal-snapshot.md` describes both fields.
- Project labels are on by default: the desktop snapshot's project ranking names projects by their folder.
  - A stored choice is kept, so a user who turned labels off stays off.
  - `modelplan project-labels off` still deletes the stored names.
  - The names stay on this machine and are never synced or uploaded.
- Both plugins pin CLI v0.5.32.

## CLI v0.5.31, Codex plugin 0.15.23 and Claude Code plugin 0.7.22 (2026-10-22)

- ZCode and OpenCode (V2) sessions are read from their own local databases (`~/.zcode/cli/db/db.sqlite`, `opencode.db`). They are opened read-only and never changed.
  - Tokens per day, sessions, projects and both rankings in the desktop snapshot include them.
  - Their request times include the wait for the first token, so they give no generation rate.
  - Their efforts stay unreported.
  - The formats follow tokei and Tokscale.
- `modelplan connect kiro` reads Kiro credits natively through `kiro-cli`'s own ACP usage call. No prompt or session is sent, and Kiro keeps its sign-in. The route follows Pulse.
- The CLI now includes a pure-Go SQLite library, about 4 MB larger. Release archives ship `THIRD-PARTY-NOTICES.md`.
- Both plugins pin CLI v0.5.31.

## CLI v0.5.30, Codex plugin 0.15.22 and Claude Code plugin 0.7.21 (2026-10-22)

- Other plans can be read natively, without CodexBar.
  - `modelplan connect zai` reads Z.ai / GLM Coding Plan with the API key in `Z_AI_API_KEY`. Add `--region bigmodel-cn` for open.bigmodel.cn.
  - `modelplan connect opencodego` reads OpenCode Go with `OPENCODE_API_KEY`.
  - Each key is sent only to its vendor's usage endpoint and never stored.
  - The readers are ported from CodexBar (MIT).
  - Copilot, Cursor and Kiro stay on CodexBar.
- `~/.config/modelplan/connections.json` (optional) chooses `native`, `codexbar-compat` or off per provider.
  - Existing `codexbar.json` settings keep working.
  - Nothing falls back silently from one backend to the other.
  - `modelplan connections` shows the effective choice. `MODELPLAN_NATIVE=off` stops native readers.
- Subscriptions are told apart automatically, as random local references. Sources:
  - Codex's own `account/read`;
  - the account and organization ids in Claude Code's `.claude.json` (no e-mail, names or tokens);
  - CodexBar's account id;
  - a native reader's key.
  - Accounts, sessions and both rankings in the desktop snapshot carry the reference. `subscriptions[]` lists them for a scope selector.
  - The identity itself is never stored. `MODELPLAN_IDENTITY=off` turns this off.
- Both plugins pin CLI v0.5.30.

## CLI v0.5.29, Codex plugin 0.15.21 and Claude Code plugin 0.7.20 (2026-10-22)

- When a Codex plan window is used up and the account has usage credits, the hint says further use draws on them and gives the balance, for example `Codex 每周额度已用完，5天5时后重置：继续用会扣点数，剩 73,172`. A reading older than 15 minutes shows its age. Reset cards are still named.
  - `modelplan quota`, the Codex dashboard and the desktop snapshot show the balance (`accounts[].credits`).
  - It is read from the same Codex logs and account reading as the windows. The task-start brief still gives the agent no quota or credit figures.
- The desktop snapshot ranks projects (`projectRanking`) by observed output tokens over 7 and 30 days.
  - Projects are opaque references: a keyed hash of the repository, so worktrees of one repository are one project.
  - Folder names are stored only after `modelplan project-labels on`. Turning them off deletes them.
  - Ranked configurations now carry their share and the published ★ effort.
- CodexBar CLI v0.77.0 is pinned.
- Both plugins pin CLI v0.5.29.

## CLI v0.5.28, Codex plugin 0.15.20 and Claude Code plugin 0.7.19 (2026-10-21)

- The task-start brief no longer gives the agent quota figures: no remaining share, reset time or headroom verdict. You see those in the quota hints. Figures given once per thread went stale and the agent repeated them.
- While quota is tight or used up, the brief offers no step up, so the agent cannot contradict a "step down" hint.
- When you ask about quota or a hint, the agent is told to run `modelplan quota` or `modelplan advise` for current figures.
- Both plugins pin CLI v0.5.28.

## CLI v0.5.27, Codex plugin 0.15.19 and Claude Code plugin 0.7.18 (2026-10-21)

- `modelplan desktop --json --read-only` builds the personal snapshot without writing a file, starting a background process, asking Codex for an account reading or using the network. The default form and `--offline` are unchanged.
- The snapshot (schema v1, additive) gains these fields. `docs/personal-snapshot.md` describes all of them.
  - `dataRevision`: a hash of the observed inputs only.
  - `validUntil`: the next instant at which the clock alone changes a verdict.
  - `sessions[].effortStatus`: `reported` or `unreported`. The `effort` fallback to ★ stays for older clients.
  - `sessions[].workloadRate` and `tokenRate`: the recent 7-day generation rate per engine and per configuration, as ratios of sums.
  - `sessions[].activity`: `recent`, `quiet` or `unknown`, from the harness's own timestamps.
  - `perfStats[]`, `daily[]` and `dailyCoverage`: per-configuration figures and observed tokens per day over the recent 7 and 30 days.
  - `sessionRanking`: the top five sessions by observed output tokens.
  - `paceHistory`: quota percentage pace per window cycle, with gaps and drops.
  - `connections[]`: whether each agent and quota source is installed, has readable history, is authorized and has quota read. Only paths are checked; nothing is run and no credential is read.
- Two new local ledgers sit beside the existing ones. Neither changes `speed.json`, `cycles.json`, `measured[]` or `modelplan history`.
  - `observed/perf.json`: 35 days, counted from when it is created. It holds per-configuration sums and histograms, plus sessions under random references.
  - `observed/pace.json`: every counted quota reading with its gaps and drops.
  - Neither stores prompts, replies, titles, paths or ids. `MODELPLAN_HISTORY=off` stops both.
- Both plugins pin CLI v0.5.27.

## CLI v0.5.26, Codex plugin 0.15.18 and Claude Code plugin 0.7.17 (2026-10-20)

- The client digest size limit rises from 150 kB to 250 kB in the CLI (`maxObjectBytes`) and the publication reader (`CLIENT_RAW_LIMIT`), and the Codex plugin bundle is rebuilt with it. The digest reached 86% of the old limit as the multiplier packs and per-effort data grew. Integrity checks (exact byte length and SHA-256 against the manifest) are unchanged. The producer only raises its own budget after clients that accept the larger digest are released.
- Both plugins pin CLI v0.5.26.

## Public core / Codex 0.15.17 / Desktop community 0.1.1

- The already-public publication verifier has a canonical `reader/` module with hash metadata; clients display published recommendations. Scoring/recommendation source and full calibration remain private; method explanations stay public.
- The desktop builds independently with a neutral community appearance. A private official package is an explicit optional build input; historical MIT grants remain documented.
- Source/agent/CI policies separate public software, per-file data licenses, official visuals and brand identity. New original-data publications use CC BY-SA 4.0; historical and third-party exceptions remain separate.

## Desktop app preview (unreleased)

- **`desktop/`: a Tauri menu bar app**, macOS first. The menu bar shows what is left in the windows of the harness you used last and the current hint (`12% · wk70% ↓★Med ×0.73`). A popover has Now (sessions against ★, Fast, advice), Quota (windows, resets, run-out, Reserve, CodexBar) and Effort (the open curves and ladder, with your measured speed). Notifications are sent once per advice: tight or exhausted, switch back, a better model on by default; surplus before a reset off. Personal data comes from the bundled CLI (`modelplan desktop --json`), public data from the hash-checked publication; nothing personal leaves the machine. CI builds an ad-hoc signed Apple Silicon `.dmg` to try; not notarized yet. See `desktop/README.md`.
- The CLI's golden snapshot (`cli/internal/snapshot/testdata/snapshot.json`) is the contract the app is tested against.

## Codex plugin 0.15.16 and Claude Code plugin 0.7.16 (2026-10-18)

- The Skill explains the ★ effort as the best value among a model's own efforts (ability, cost and task time), not the top effort or the vendor's default: agents no longer call it an error, and point to the top effort of the same ladder when the user wants maximum quality regardless of cost.
- The Skill says ability is a frozen scale (50 = the September 2026 frontier average), so negative or above-100 values are valid data, not a bug.
- Still pinned to CLI v0.5.25.

## Codex plugin 0.15.15 and Claude Code plugin 0.7.15 (2026-10-18)

- Pinned CLI v0.5.25: a tight hint that already offers a model switch is not repeated as a separate better-model hint.

## v0.5.25 (2026-10-18)

- **`modelplan desktop`** prints the personal snapshot for the coming desktop app: sessions against ★, quota accounts, advice events with their text and a short menu-bar form, measured speed. One call; the format is in `docs/personal-snapshot.md` and is the one a mobile client will later receive through end-to-end encrypted sync.
- A tight window that already offers switching to a model is not followed by a separate better-model hint for the same switch.

## Codex plugin 0.15.14 and Claude Code plugin 0.7.14 (2026-10-18)

- Pinned CLI v0.5.24: a better model is named once when the one in use is beaten (Fable 5.1 → Opus 5.5, GPT-6 Astra → GPT-6.1 Sol), and tight hints offer it before stepping down. Claude Code's status line shows it for a week.

## v0.5.24 (2026-10-18)

- **Switch models, not just efforts.** When the publication marks the model in use as beaten (`dominatedBy`) and the model that beats it runs in the same harness, the CLI names it: its cheapest effort within the lineup's tie (1 point) of the current configuration at no more than 0.7× its cost. Today that is Fable 5.1 → Opus 5.5 (★Med: +2.5 points, ×0.52) and GPT-6 Astra → GPT-6.1 Sol (★Med: about the same, ×0.18). New event `better_model_available`, with `suggest.kind` (`stronger` | `equivalent`) and `current`. The prompt hook tells you once per model and effort and not again for 90 days (if you stay on it, you chose it); the Claude Code status line shows `→Opus 5.5 ★Med ×0.52` for a week.
- **Tight windows name the model first.** A tight window's alternative (`cheaper_model`) now uses the same tie, so Astra Med finds Sol Med (−0.2 points, ×0.18) rather than Sol High, and the hint puts it before stepping down, since it keeps the ability; the status line shows `→Sol …` instead of `↓Low`.

## Codex plugin 0.15.13 and Claude Code plugin 0.7.13 (2026-10-18)

- Pinned CLI v0.5.23: your measured speed per model, effort and Fast, on this machine only.
- Codex: the effort text lists the model's measured configurations, and the dashboard shows the chosen effort's measured turn time, tokens and tok/s against ★ (a Fast row's rate against Standard).
- Claude Code: `/modelplan:effort` explains the measured section under the ladder.

## v0.5.23 (2026-10-18)

- **Your measured speed.** Per model, effort and speed mode, over the last 28 days on this machine: output tokens per second of generation, the median time to the first token, and the median turn time and output tokens per turn. `modelplan effort <model>` shows the model's rows under its ladder, each effort against ★ in standard mode beside the published time multiple, and Fast against the same effort in Standard beside the published speed-up; `modelplan history` shows every model. `--json` adds `measured[]`.
- Read from the current Claude Code session's transcript (the status line and hooks name it) and the recent Codex rollouts: timestamps, output token counts, model, effort and speed mode only; never prompts, replies or tool output, and no paths or ids are stored (`observed/speed.json`, per day). A figure needs 5 samples. `MODELPLAN_HISTORY=off` stops it with the quota history.

## Codex plugin 0.15.12 and Claude Code plugin 0.7.12 (2026-10-17)

- Pinned CLI v0.5.22: GPT Reserve kept apart from the main Codex allowance; Codex Fast read as about ×1.5.
- Codex: the text summary and the dashboard show a `Reserve` row and name the allowance in the verdict; Fast reads "about ×1.5 faster", Ultrafast lists its plans, and the dashboard estimates task time from the speed-up, as the website does.

## v0.5.22 (2026-10-17)

- **GPT Reserve is its own allowance.** Codex meters GPT Reserve from a weekly allowance of its own (limit `base_model_inference`, `gpt-reserve`). It now shows as `weekly Reserve`, and the account's new `pool` says which allowance the latest thread drew from: headroom, hints and switch-back look only at that one, so a used-up Reserve no longer makes the main allowance tight (or the other way round). The Codex account reading keeps the two apart too; it used to fold windows of different limits into one.
- **Codex Fast about ×1.5.** The published speed-up now reads `about ×1.5 faster · generation time about ×0.67`; `up to` stays for ceilings such as Ultrafast's ×8.
- The Skill's Python reader does the same.

## Codex plugin 0.15.11 and Claude Code plugin 0.7.11 (2026-10-17)

- Pinned CLI v0.5.21: the new Claude Code status line.

## v0.5.21 (2026-10-17)

- **Status line bars.** Each window shows what is left as a bar: green from 30%, amber from 10% or when the pace is tight, red below 10%. The reset countdown, the run-out time and the hint follow.
- **Off ★ at a glance:** an effort above the recommendation is amber and one below it blue, with ★ in brackets. The cost and lineup tags show only when there is no quota to draw.
- **Narrow terminals** (`COLUMNS` under 100) get a short form: `▲ Opus 5.5 ★Med │ ▓▓▓▓░░ 65%↻40分 周70% ↑High ×1.37`.

## Codex plugin 0.15.10 and Claude Code plugin 0.7.10 (2026-10-17)

- Pinned CLI v0.5.20: the plugins' status line and hooks start the local quota history.

## v0.5.20 (2026-10-17)

- **Local quota history.** For each Claude Code and Codex window cycle, the CLI records on this machine how much was used and how many points each model, effort and Fast setting spent (`observed/cycles.json`, never uploaded). It records when the status line, a plugin hook or `advise` runs, and keeps five-hour cycles for 28 days and weekly ones for 12 weeks. `MODELPLAN_HISTORY=off` stops recording; deleting the file clears it.
- **`modelplan history`** (`--json`) shows it: weekly cycles one per line with where their points went, five-hour cycles as a summary. A later release will use it to suggest a default effort from your own finished weeks.

## Codex plugin 0.15.9 and Claude Code plugin 0.7.9 (2026-10-17)

- Pinned CLI v0.5.19: tight hints say when the window runs out at the recent rate.
- Codex: the text summary and the dashboard's quota rows show the run-out time.

## v0.5.19 (2026-10-17)

- **Recent rate of use.** Windows carry `recentPercentPerHour` and `runsOutInMinutes`, measured over the last 10–45 minutes of readings (Claude Code: the status-line snapshot now keeps the last hour of readings; Codex: every turn in its logs). The Skill's Python reader follows the same rules, tested against the same cases.
- **A burst counts as tight.** A window that runs out within three hours at the recent rate, before its reset, is tight whatever the average pace says. The hint names the time ("runs out in 2h20m, before the reset in 3h20m"), and a run-out within half an hour gets the hint shown once more.
- **Status line:** `≈2时20分用完` / `out ~2h20m` next to the window. `modelplan quota` adds it to the window line.

## Codex plugin 0.15.8 and Claude Code plugin 0.7.8 (2026-10-17)

- Pinned CLI v0.5.18: after a reset, the hint points back to the model and effort you used before it (and Codex Fast off).

## v0.5.18 (2026-10-17)

- **Switch back to what you used before.** When it first advises on a window, the CLI records the model, effort and Codex Fast in use. After that window resets it suggests going back to that configuration rather than always to ★, and says nothing if you never changed it. A used-up window still says the allowance is back.
- **The reset hint waits for your next prompt,** up to 24 hours (was 90 minutes), so coming back after a break or the next morning still gets it once. The status line shows `↺…` for 90 minutes from when it first appears.
- **Codex Fast:** after the reset, a Fast you turned on since the hint gets "turn Fast off". A tight window with Fast on says to turn it off before stepping down. A surplus no longer offers Fast when it is already on.

## Codex plugin 0.15.7 and Claude Code plugin 0.7.7 (2026-10-17)

- Pinned CLI v0.5.17: quota hints are shown to you, not the agent, and the task-start brief comes once per session.
- Claude Code: the status-line reminder shows twice at most, a week apart, and is never relayed by Claude; the reply-parsing "not now" is gone (`/modelplan:setup` still records it).
- Codex: the fetch-failure notice no longer goes to the model.

## v0.5.17 (2026-10-17)

- **Hints are for you, not the agent.** `advise --hook` shows quota hints, the plugins' setup notices and the "which plan pays for GLM" question as the hook's `systemMessage`; none of them enters the model's context, so replies no longer open or end with quota or setup talk.
- **The task-start brief comes once per thread,** about 1.2k characters (from 1.6-1.8k): options a better one beats are left out unless the thread is on one, the disclaimer is one clause, and the model is told not to bring up quota. A model the thread was not briefed on adds one line with its ladder; quota and effort changes no longer resend the brief.

## Codex plugin 0.15.6 and Claude Code plugin 0.7.6 (2026-10-16)

- Pinned CLI v0.5.16: the status line follows the declared plan for GLM through Z.ai.

## v0.5.16 (2026-10-16)

- **The status line follows the declared plan for GLM through Z.ai.** It shows that plan's windows (CodexBar's Z.ai reading) and its hint: `◷45m` when off-peak starts before the reset, `!` when tight on a per-request plan (never `↓`, which saves nothing there).
- README: other plans through CodexBar (macOS and Linux) and `modelplan declare`.

## Codex plugin 0.15.5 and Claude Code plugin 0.7.5 (2026-10-16)

- Pinned CLI v0.5.15: advice follows the plan that pays for GLM through Z.ai in Claude Code, and the hook asks once which plan that is.

## v0.5.15 (2026-10-16)

- **Advice follows the plan that pays (client-v1.3 `planMetering`, #37).** Claude Code on GLM through Z.ai runs on the user's Zhipu plan, not on Claude's. With the plan declared in `local.json` (`planId`, and `generation` where the plan meters more than one way), the session is advised by that plan's rules and its windows (the plan's own, or CodexBar's Z.ai reading):
  - per-request plans (Zhipu legacy V2) never get "step down", since every effort costs one request; a tight window says when off-peak starts instead, and a surplus says a higher effort costs no extra quota;
  - credit plans compare models by credits per API dollar at the current time-of-day rate; plans with a pool per model or unpublished rates get no cross-model cost;
  - the task-start brief lists GLM's lineup instead of Claude's and names the plan and how it counts.
  Nothing is guessed: without a declared plan, with two plans that meter the model, or with a generation missing where it matters, advice stays as before. Time rules are matched by the plan's `timeRules`, so a declared plan's peak and off-peak hints now also work for Zhipu Pro/Lite/Max on legacy V2.
- **`modelplan declare <planId> [generation]`** records the plan in `local.json` (keeping the rest of the file), checked against the publication: a plan metered two ways needs the generation. When a Claude Code session runs GLM through Z.ai with no declared plan, the hook asks the model once per model to ask the user which plan they have (only Z.ai's global plans for `api.z.ai`) and to run `declare` with the answer.
- The status line records Claude Code's `ANTHROPIC_BASE_URL` (scheme, host and path only), so GLM through Z.ai is recognised; it also shows GLM instead of an unknown model.
- Model ids with Claude Code's 1M-context suffix (`glm-5.3[1m]`, `claude-opus-4-6[1m]`) were dropped from the status-line snapshot; they are kept now.

## Codex plugin 0.15.4 and Claude Code plugin 0.7.4 (2026-10-16)

- Pinned CLI v0.5.14 and the plugin changes listed under it: setup offers CodexBar, the Codex dashboard shows those plans.

## v0.5.14 (2026-10-16)

- **The pinned CodexBar release is fetched even when one is already installed.** 0.5.13 used any `codexbar` it found and fetched only when there was none. On the owner's Mac that meant CodexBar 0.60.3, 16 releases older than the pin, whose provider code (Cursor's changes almost daily) and output were never tested. A copy the user installed is now used only until the pinned one is in place; a failed fetch is retried after 30 minutes. `MODELPLAN_CODEXBAR=<path>` still chooses a copy explicitly. `modelplan codexbar` says which copy runs.
- **Window titles that only restate the window are dropped.** CodexBar calls Z.ai's windows "5 hours" and "Weekly", which printed as "5h 5 hours". Titles that name something else ("Third Party", "MCP") stay.
- **Plugins: setup offers CodexBar, and the Codex dashboard shows those plans.** `/modelplan:setup` (Claude Code) and the Codex setup skill now list the enabled providers with what each still needs, and, when none is enabled, ask once which of these plans the user has; enabling runs only after the user agrees, with what CodexBar reads said first. The Codex dashboard and its text summary list the plans read through CodexBar under Codex's own quota (v0.5.13 said they did, but the plugin kept only the Codex account), and a provider that was not read appears as a setup line with its next step.
- **Claude Code prompts refresh CodexBar too.** In 0.5.13 only `quota`, `advise` and Codex prompts started the background CodexBar refresh, so a Claude Code user's reading went stale. Found by testing the plugin in Claude Code.

## Codex plugin 0.15.3 and Claude Code plugin 0.7.3 (2026-10-16)

- Pinned CLI v0.5.13: `~/.cache/modelplan-cli/modelplan codexbar enable cursor zai` reads other plans through CodexBar (opt-in). The setup command and the dashboard do not offer it yet.

## v0.5.13 (2026-10-16)

- **Other plans through CodexBar (opt-in): `modelplan codexbar enable cursor zai`.** Copilot, Cursor, Kiro, OpenCode Go and Z.ai / GLM keep their meters behind the vendor's own sign-in, so this client reads them through the CLI of [CodexBar](https://github.com/steipete/CodexBar) (MIT). Credentials stay with CodexBar: its config, another CLI's login, the Cursor app or browser cookies, and never a Keychain prompt in the background. This client handles none of them.
  - The first run fetches CodexBar's pinned release (`internal/quota/codexbar-pin.json`, about 14 MB on macOS and 53 MB on Linux), checked against the pinned SHA-256.
  - It runs in the background at most every 10 minutes, one provider per call, and caches only windows, reset times and the plan name.
  - `modelplan codexbar` shows what each provider returned and, when nothing was read, what CodexBar needs.
  - `quota` and the dashboards show these plans; they give no hints inside Claude Code or Codex.
  - OpenCode Go's local estimate uses fixed denominators and is not shown as quota.
  - A weekly workflow proposes newer CodexBar releases after a live check that their JSON still parses.

## Open data (2026-10-16)

- **`data/` mirrors Model Plan's reviewed data.** Plan tiers, prices, quota metering, plan model access, calendars, model identities and lineages, speed claims and effort policies, copied exactly from [modelplan.ai/open-data.json](https://modelplan.ai/open-data.json) with SHA-256 checks. The hourly `data-sync` workflow turns each change into a pull request that lists the records added, removed and changed. Data is [CC BY 4.0](data/LICENSE); `real-api-pricing/` keeps its MIT license.

## Codex plugin 0.15.2 and Claude Code plugin 0.7.2 (2026-10-16)

- Pinned CLI v0.5.12; the Codex panel changes listed under v0.5.12.

## v0.5.12 (2026-10-16)

- **Switching back to a model no longer resends the brief.** 0.5.11 compared against the last brief only, so Sol → Astra → Sol sent the Sol brief again, contrary to its own changelog (found by a Codex review). A thread now remembers every model it was briefed on, with the last effort known for each: a model it was briefed on is no reason by itself, a new effort on it still is.
- Codex plugin (next pin): in a narrow right-hand panel the curve and lineup folds stay closed (they opened in any "fullscreen" view, and the sidebar board opens fullscreen in the right panel); thread and sidebar panels ask the host for 460 px where it leaves the width to the app; the comparison says whether it shows the current (or latest local) session's model, and that model's chip is marked; the footer names the plugin version and when the panel read its data; a panel still served by an older plugin version than the one installed says so (restart Codex or open a new task).

## Codex plugin 0.15.1 and Claude Code plugin 0.7.1 (2026-10-16)

- Pinned CLI v0.5.11 (advice per model and effort, brief on substantial changes). Updating the plugin brings it; the previous copy is used while it downloads.

## v0.5.11 (2026-10-16)

- **Configuration advice per model and effort.** A tight window, a surplus before a reset or an announced reset is about the configuration in use, so the hook now remembers it per model and effort instead of per account window: a thread on another model (Astra after Sol) hears its own advice, while threads on the same configuration do not repeat it; a tight window that gets critical (10% or less left) is said once more. Account news (used up, switch back, peak hours, cards, public resets) is still said once. Only threads you send a message in hear anything. From a Codex review.
- **The task-start brief follows substantial changes:** besides a thread's first prompt and another model, another known effort (an effort first read on a later prompt does not count) and quota turning tight, used up or into a surplus. A thread switching back to a model it was briefed on keeps that brief.
- Plugins (next pin): the previous fetched CLI bridges a plugin update while the new one downloads; the Codex dashboard and text output explain every way hints can fail (unreadable hints, a CLI without `advise`, a failing run) instead of only the last.

## Codex plugin 0.15.0 and Claude Code plugin 0.7.0 (2026-10-16)

- **The plugins bring their own CLI.** Each plugin pins one `modelplan` release in `cli-pin.json` (version, release URL and the SHA-256 of each macOS and Linux archive) and fetches it with `hooks/fetch-cli.sh` (shared, identical) into `~/.cache/modelplan-cli/<version>`, using it only if the archive's checksum equals the pinned one; `~/.cache/modelplan-cli/modelplan` links the newest, a stable path for the status line. Installing or updating a plugin is all there is to do: the separate "install the CLI / upgrade the CLI / not now" flow is gone. Nothing else changes (no PATH, profile or sudo); a CLI the user installed is left alone and used only while the plugin's copy is missing. `MODELPLAN_PLUGIN_CLI=off` turns fetching off; Windows has no automatic fetch. Pinned now: v0.5.10.
- **Who fetches.** Codex: the plugin's MCP server, in the background when it starts; its hook still downloads nothing. Claude Code (no separate hook review): the hook, in the background. A failed fetch is retried after 10 minutes; Codex's dashboard has **Retry**, Claude Code's `/modelplan:setup` gives the command. Commands (`/modelplan:plan` and others) fetch on demand.
- **What you see.** The CLI's first arrival is announced once; a failed fetch says why (download, checksum mismatch, unsupported system), at most weekly; nothing is asked. The dashboard, text output, doctor and `/modelplan:setup` show the plugin's copy, a user's copy, "downloading", "failed (why)" or "off". Claude Code keeps one question, the status line, with a short "no" recorded by the hook.
- Release flow: tag the CLI, then `node scripts/pin-cli.mjs vX.Y.Z`; CI checks the pins against the published release (`--check`).

## Codex plugin 0.14.2 and Claude Code plugin 0.6.2 (2026-10-16)

- The Skill stays usable without the CLI and now says what only the CLI adds (`advise` hints with memory and the cheaper-model option, Codex's account reading, Claude Code's quota, a verified local publication), so those stay "unknown" instead of improvised. When the user asks about their own quota or resets without the CLI, it mentions the install command once; never for model or effort questions, and it never installs anything itself.

## v0.5.10 (2026-10-16)

- Plugins: Codex 0.14.1, Claude Code 0.6.1 (the Skill copies below; CLI 0.5.9 is still enough).
- **Skill's Python reader matches the CLI again.** `scripts/quota.py` (used when the CLI is not installed, also by the Codex dashboard) still had the old pace rule, so 72% of a week used with six days left was `on_track` there and `tight` in the CLI. It now applies the same early-tight rule and reads Claude Code's `sessionKey` against `CLAUDE_CODE_SESSION_ID` (`current-thread` / `recent-thread`). Both readers now run one shared table, `cli/internal/quota/testdata/pace-cases.json`, so the rules cannot drift apart unnoticed.
- Skill docs: `alternative` (`cheaper_model`) in `advise`, Claude Code attribution, the early-tight rule, the CLI found in `~/.local/bin`, a status line configured with the CLI's full path and `statusline --preview`, and that a cheaper cross-model reference cost is never a promised quota saving.
- CLI help and README: the hook's task-start brief, `quota`, `advise`, `statusline --preview`, `MODELPLAN_TASK_BRIEF`, `MODELPLAN_CODEX_ACCOUNT`, and the install command.

## v0.5.9 (2026-10-16)

- Plugins: Codex 0.14.0, Claude Code 0.6.0 (both need CLI 0.5.9).
- **Earlier warning.** A window already half used and on pace to run out is `tight` however early it is; before, the projection counted only after a fifth of the window, so 72% of a week used with six days to go showed as on track (from a Codex review). Lighter early use still waits for the fifth.
- **A cheaper model, not only a lower effort.** When a window is tight, the hint also names the cheapest configuration of another published model, usable in this harness, that scores at least as high as the current one (`alternative`, action `cheaper_model`), with its multipliers, and leaves the choice to the user ("unless this task needs the current model"). Today: GPT-6 Astra Med → GPT-6.1 Sol High, +2.4 pts at ×0.25 the reference cost.
- **The brief follows the model.** A thread that moves to another model (or whose model becomes known) gets the brief again for it; otherwise still once per thread. Without a readable model the brief tells the model to go by the model its own instructions name.
- **Cost wording.** Hints and the brief say that × is the published API cost of a reference task: within one model it roughly tracks plan usage, across models it is only a guide, never a promised quota saving. The brief names the publication date.

## Codex plugin 0.14.0 and Claude Code plugin 0.6.0 (2026-10-16)

- **The hook's outcome, not just its start.** The hook still never blocks a prompt, but it now records how each run ended: `ok`, `failed: exit N: <first error line>`, or why the CLI was not asked; and the last success. The dashboard, text output, doctor and `/modelplan:setup` show "hints computed (nothing to flag)", "hints failed (why, last success)" and "not verified yet" apart. These records are labelled as this machine's, from any chat.
- **Codex: hook definition, not plugin version.** The heartbeat records a checksum of `hooks.json`; "review due" shows only when the definition changed, not on every plugin update. Trust is reported as unknown (plugins cannot see it; `doctor.cjs` reads it from Codex in a project). Setup text names the desktop entry: the hook icon with a yellow dot next to the input, source `modelplan-codex`; `/hooks` in the CLI.
- **One CLI finder.** `hooks/find-cli.sh` (shared by both plugins) and the dashboard's `findCli` use the same order and rules: executable files only, and the first copy at least the required version wins over an older one earlier on PATH (a non-executable `modelplan` on PATH made the dashboard and the hook disagree).
- **One minimum version**, in each plugin's `cli-min.txt`, read by the hook, the dashboard and checked against the docs by a test; no more "0.4+" next to "0.5.5".
- **Install failures by kind.** `install.sh` names download, checksum and permission failures; the dashboard says what to do for each, and for an older copy found first or an unsupported system. After a successful install it says the next step (send a message to verify the hook; allow it if Codex asks).
- Hints arrive with a prompt only; the docs say so instead of implying continuous monitoring.

## v0.5.8 (2026-10-16)

- Plugins: Claude Code 0.5.1, Codex 0.13.1.
- `advise --hook`: a first sync that does not finish within 3.5 seconds goes on in the background, so the next prompt has the data. Before, a slow first download failed and was not retried for 10 minutes (seen in a logged-in Claude Code run).

## Claude Code plugin 0.5.1 and Codex plugin 0.13.1 (2026-10-16)

- **"Not now" without a command.** After the one-time setup question, the hook reads the user's next message itself: a short "no" (不用, 暂不, 算了, no, not now, skip, …) is recorded and Claude or Codex is told to acknowledge it and run nothing. Before, the model had to run `touch` in `~/.cache`, which needs approval outside the project (Claude Code blocked it even with an allow rule), so a "no" came with a permission prompt or was not recorded. Any other message consumes the question without recording anything. Claude Code's `/modelplan:setup` records "not now" with `hooks/decline.sh`.

## v0.5.7 (2026-10-16)

- `advise --hook`: with no publication on the machine yet (the CLI was just installed), the hook waits up to 3 seconds for a first sync, so the first prompt already gets the task-start brief; before, it only started a background sync and the brief came with the next prompt. A failed attempt is not retried for 10 minutes, so an offline machine is not slowed down. A stale publication is still refreshed in the background.

## v0.5.6 (2026-10-16)

- Plugins: Claude Code 0.5.0.
- **Task-start brief for Claude Code.** `advise --hook claude-code` now also hands the model the brief on the first prompt of each session (Anthropic models at ★, the default configuration, the current model's ladder, the quota headroom), as for Codex. The current model and effort come from the status line's reading only when it was this session's: the snapshot keeps a one-way `sessionKey` (a hash, never the id), and `quota` marks the Claude Code harness `current-thread` or `recent-thread` from the hook's `session_id` or `CLAUDE_CODE_SESSION_ID`. Without it the brief says "model unknown".
- The hook refreshes the published data in the background when it is older than 6 hours (before, only the status line did), and takes a plugin's setup notice (`--add-system`, `--add-context`) so one JSON object comes out.
- `statusline --preview` renders a sample without recording it; the plugin's preview used to write its sample windows into the real snapshot.

## Claude Code plugin 0.5.0 (2026-10-16)

- **One hook,** `UserPromptSubmit` → `hooks/modelplan-quota-hints.sh`; `SessionStart` is gone (the CLI refreshes data itself). It finds the CLI off PATH (`~/.local/bin`, Homebrew), records a heartbeat with the plugin version, and shows a setup notice when the CLI is missing or older than 0.5.6, or the status line has never recorded: the first notice asks Claude to offer the fix once (a "no" is recorded), later ones at most weekly without asking, none for 90 days after "not now". A current CLI with a recording status line gets hints and the brief only. Verified in Claude Code 2.1.301 (plugin hooks run without a separate review there).
- **`/modelplan:setup`** reports plugin, CLI (missing, outdated, failed, ok, and whether it is on PATH), status line (recording, set but no reading, not set), hook (last run, plugin version) and hints, each on its own line, then installs the CLI with consent, syncs and re-checks.
- `/modelplan:plan`, `/modelplan:effort`, `/modelplan:lineup` and `/modelplan:statusline` reach the CLI through the plugin, so they work when it is not on PATH; the status line is configured with the CLI's full path.
- Tests for the hooks and commands run in CI on Ubuntu and macOS.

## v0.5.5 (2026-10-16)

- Plugins: Codex 0.13.0.
- The task-start brief no longer needs a quota reading: without one (a first thread, an API-key login) it still lists the options and the default, with quota "unknown". It takes the thread's model from the hook input; when the thread's effort is not in its log, it says so and shows the ladder against ★ instead of assuming ★.

## Codex plugin 0.13.0 (2026-10-16)

- **One hook, named by its command.** `SessionStart` is gone; `UserPromptSubmit` runs `hooks/modelplan-quota-hints.sh` (status message "ModelPlan: quota hints and task-start brief"). Codex 0.157's review shows plugin hooks as "Hook 1"; `statusMessage` does not change that, so the script name, the README and the `setup` skill explain it.
- **Setup notice on the prompt, not the session start,** so it also works after an upgrade inside an open chat and after the hook is trusted mid-session (both verified in the Codex TUI). Missing or outdated CLI: the first notice asks the model to offer it once (on a no it records `cli-declined`); later notices at most weekly, without asking; none for 90 days after "not now". Asking about setup is never limited. With a current CLI only hints and the brief.
- **Setup on the dashboard, part by part:** CLI missing (Install / Not now), outdated (Upgrade), failing (with the error); hook never ran, or an update's hook has not run (Codex skips a changed hook until trusted again; the hook records its plugin version); one "setup complete" line otherwise. The text output says the same. Install and upgrade succeed only when the CLI the plugin will use reports at least 0.5.5; an older copy found first is named.
- `setup` skill rewritten: report each part from the check, never from a command having run; offer, install, re-check; record "not now"; explain hook trust and re-trust after updates. `doctor.cjs` shows when the hook last ran. App-only tool `dismiss_cli_setup` for "not now".

## v0.5.4 (2026-10-16)

- Task-start brief names a **default for ordinary tasks**: the published best value at ★, unless it scores more than 3 points below the strongest, then the strongest at ★ (today GPT-6.1 Sol ★Med, both). It lists the default model's ladder when the thread is on another model, and tells the model to suggest a step down for small tasks, High/XHigh of the default for complex ones and the default again afterwards.

## v0.5.3 (2026-10-16)

- Plugins: Codex 0.12.0.
- **Task-start brief for Codex.** On the first prompt of a Codex thread, `advise --hook codex` also hands the model a short brief: the Codex models at ★ with ability, cost relative to the cheapest and lineup verdicts (dominated ones marked skip), the current model's effort ladder against the current effort, the quota headroom and, with a surplus, Fast when it draws plan quota. The model judges the task and suggests one configuration only when the current one clearly does not fit; the brief says it never changes settings. Once per thread (by the hook's `session_id`); `MODELPLAN_TASK_BRIEF=off` disables it.

## v0.5.2 (2026-10-16)

- Plugins: Codex 0.12.0.
- **Codex account reading.** `modelplan quota`, `advise` and the Codex hook ask Codex itself for the account's windows and reset credits: `codex app-server` → `account/rateLimits/read`, in the background at most every 5 minutes (30 after a failure such as no login), with Codex's own login; `quota --refresh-account` asks now. The answer is cached in `observed/codex-account.json` without account or credit ids and merged with the session-log windows, newest observation per window, so a 5-hour window missing from recent logs is filled in. Available credits become `cards` of kind `full` with their expiry, which feed `cards_expiring` and `use_card`. The reading is marked `via: "codex-account"`. Nothing is redeemed. `MODELPLAN_CODEX_ACCOUNT=off` disables it.

## Codex plugin 0.12.0 (2026-10-16)

- The dashboard and the text output show full-reset credits (count, first expiry, redeem in Codex yourself) and name a Codex account reading as the source.

## v0.5.1 (2026-10-16)

- Plugins: Codex 0.11.0.
- `modelplan advise`: **spend ahead of an announced Codex reset.** When OpenAI has announced a reset with a time in the next 24 hours and the longer Codex window still has 20% or more that would otherwise last past it, `announced_reset_with_surplus` suggests the next effort, a stronger model or Fast, worded as applying only if the reset covers the account. The switch-back hint after it waits for a reading taken after the announced time that shows the window restarted, and is kept for up to six hours for that proof. An announcement whose time has passed is no longer shown as news.

## Codex plugin 0.11.0 (2026-10-16)

- **The hooks now load.** The manifest moved to Codex's native `.codex-plugin/plugin.json`. The old root `plugin.json` carried the Agent Plugins `$schema`, and Codex then skipped the plugin's hooks, so the `UserPromptSubmit` hint hook never ran. `codex app-server` `hooks/list` now shows both hooks; `doctor.cjs` reports whether they are loaded and trusted.
- **Getting the CLI:** an **Install CLI** button on the dashboard (macOS, Linux; app-only tool `install_modelplan_cli`, the click is the consent) runs the bundled copy of `install.sh`: latest release, checksum-checked, into `~/.local/bin`, nothing else changed. A `setup` onboarding skill checks for the CLI after install and offers it. A `SessionStart` hook shows a short notice with the install command when the CLI is missing, at most once a week.
- The server, hooks and doctor find the CLI in `~/.local/bin`, `$MODELPLAN_BIN` and Homebrew's directories as well as PATH, since Codex starts them with a short PATH.

## Codex plugin 0.10.0 (2026-10-16)

- **Panel beside the chat:** a separate `Effort & quota` thread entry (tool `open_model_panel`) opens the dashboard in the conversation's side panel; the sidebar board is its own `Model Plan` global entry. OpenAI's extension spec allows one entrypoint per tool; 0.9 declared both on `open_model_dashboard`. Each surface has its own UI resource, so the model's call still shows the inline card and a tool call never claims to open the side panel. The inline card says how to open the panel instead.
- **Width no longer follows the display mode:** hosts show every entrypoint `fullscreen`, which widened 0.9 to 640 px inside the side panel. The content is at most 420 px everywhere (borders and padding included). The inline card reports its own width to the host (`ui/notifications/size-changed`, within `containerDimensions.maxWidth`) and leaves the chat column around it unpainted. Expand appears only on the inline card.
- **Diagnosable size:** *Data & basis* shows what the host reported (surface, display mode, container dimensions) and the laid-out viewport and panel widths. `doctor.cjs` reports whether the side panel entry is registered.

## Codex plugin 0.9.0 (2026-10-16)

- **Compact inline dashboard:** opens inline (was fullscreen) at a 360–420 px target with content height and no inner scroll areas. The first screen shows the thread's model, effort and speed tier, its step against ★ and the quota. Model chips select the comparison. Curves, the full lineup and reset notices are folded; Expand opens them.
- **Speed tiers are consistent and honest:** the readout, mini curve and detail curve share one comparison state. Under Fast or Ultrafast, cost becomes an estimated plan-quota multiple vs ★ standard and task time is unknown, never shown as ×1.00 or divided by the generation speed-up. Generation speed is shown as an "up to" ceiling or as not stated, with credit multiples, eligibility, the official source and its review date.

## v0.5.0 (2026-10-16)

- Plugins: Codex 0.8.1.
- **Codex quota and the current thread are separate.** Account windows are merged across recent Codex threads, newest reading per limit id and window, each with its own `observedAt` and age; a window absent from the newest log is no longer dropped. Model and effort come from one thread: the calling one when `CODEX_THREAD_ID` (or a hook's `session_id`) names it, marked `attribution: "current-thread"`, else the newest interactive thread, marked `recent-thread`. Background threads (`subagent:*`, `internal:*`, `codex-auto-review`) never supply them. The harness also reports `observedAt`, `origin`, `serviceTier`, and the effort from `collaboration_mode` when the turn context has no top-level one. Go and Python read one shared multi-thread fixture.
- Codex plugin: the MCP server is never told which thread called it, so its reading is labelled "latest local thread, may not be this conversation" with its age; readings from older CLIs that carry `codex-auto-review` are dropped. Windows older than an hour show their age; five-hour or weekly windows not seen are listed as such.

## Codex plugin 0.8.0 (2026-10-16)

- **Runtime discovery:** Codex now starts `launch.cjs`, which runs the server on the first Node.js 22+ that passes a feature check: a pin in `~/.config/modelplan/runtime.json`, the Node Codex used, Codex desktop's own runtime when present, other PATH entries, standard locations and version managers. Re-checked at every start; PATH and global Node are never changed. With no usable runtime both tools still register and return the diagnosis. The minimum is Node.js 22 (was 24); CI runs 22 and 24.
- **Setup check:** `node doctor.cjs` starts the installed plugin through Codex's app-server without a turn and reports Codex support, install state, the runtime Codex actually used, MCP tools, the dashboard resource, public data, quota reader and hints, ending with separate *installed* / *tools callable* / *panel shown (unverified)* verdicts.
- **Install:** `--sparse .agents --sparse codex` checks out about 2 MB instead of the whole repository; README covers each step, retries, update and uninstall, and required versus optional components.
- Quota and hint results name their reader and why hints are off (`cli_missing`, `cli_without_advise`); the text output and dashboard show it.
- Fixed `tests/mcp-smoke.mjs`, which compared the effort text without the speed-tier lines.

## v0.4.1 (2026-10-15)

- `modelplan advise`: one switch-back hint per window, even when it was advised more than once (#10).

## v0.4.0 (2026-10-15)

- **Proactive advisor:** `modelplan advise [--json] [--source] [--hook claude-code|codex]` with events for a window about to reset with allowance left, tight or used-up windows, switching back to ★ after a reset, peak and off-peak starting soon, reset cards expiring and public Codex resets. Each hint is given once (#9).
- **Hooks:** UserPromptSubmit hooks for Claude Code and Codex pass new hints to the agent once.
- **Status line hints:** `↑High ×1.37`, `↓★Med ×0.73`, `↺★Med`.
- **Speed tiers:** ⚡ Fast and ⚡⚡ Ultrafast lines in `modelplan effort`; the Codex dashboard gets a Standard / Fast / Ultrafast switch; the Skill reads them. The CLI accepts any `client-v1.x` projection.
- Skill: Claude Code fast mode bills usage credits, not plan quota (#8).
- Plugins: Claude Code 0.4.0, Codex 0.7.0.

## v0.3.0 (2026-10-15)

- Quota-aware Skill, status line and Codex dashboard: Claude Code and Codex 5-hour and weekly windows read locally (#7).
- Codex effort dashboard and install instructions (#1); clients point at modelplan.ai (#2); methodology and sources published (#3); data-problem issue form (#4).
- CLI accepts the ten-component compact publication (#6).

## v0.2.1 and v0.2.0 (2026-10-12)

- First releases of the `modelplan` CLI: `lineup`, `effort`, `models`, `statusline`, `sync`, `doctor`.
