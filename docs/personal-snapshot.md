# Personal snapshot (schema v1)

`modelplan desktop --json` (CLI 0.5.25+) prints the **personal snapshot**: one document holding the user's own state that a desktop client renders. A mobile client will later receive the same document through sync. It is built on the user's machine from what the harnesses already write locally. Public recommendations are not in it: clients read the verified publication themselves (`/v1/client`, through the shared client reader).

Each run also does what the plugin hooks do:

- refreshes the Codex account reading, CodexBar and a stale publication in the background;
- records the local quota history and Codex speed measurement;
- arms switch-back.

It marks no advice as told. A client keeps its own notified keys.

`modelplan desktop --json --read-only` (CLI 0.5.27+) builds the same document without any of that. It reads the harness logs and Model Plan's own caches as they are, and it writes no file, starts no background process, asks Codex for no account reading and uses no network. It is read-only, not cache-only: it still parses the Codex rollouts. The advice comes from the stored readings and the current clock; nothing is armed or remembered. What keeps the data fresh is the default form, the status line and its hook, and `modelplan sync`. A client calls the default form on a slow cadence and the read-only form for frequent reads.

`--offline` keeps its meaning (no network and no background refresh); it still records history and speed and saves the advice state, so it is not read-only.

`cli/internal/snapshot/testdata/snapshot.json` is a complete example, kept in step with the CLI by its tests (`go test ./internal/snapshot -update` rewrites it). The desktop app's tests read it, so a change that breaks a client fails there.

## Top level

| Field | Meaning |
|---|---|
| `schemaVersion` | `1`. Later versions only add fields; a breaking change gets a new kind or version |
| `kind` | `"modelplan.personal-snapshot"` |
| `generatedAt` | When it was built (UTC) |
| `cliVersion` | The CLI that built it |
| `publication` | `{publicationId, publishedAt, checkedAt, verifiedAt, stale, lastError}` of the verified publication the figures come from; `null` before the first sync. `stale`: not checked for 48 hours |
| `sessions[]` | Each harness's current configuration (below) |
| `accounts[]` | The quota accounts, exactly as `modelplan quota --json` gives them: windows with pace, run-out, pools (Codex `reserve`), reset cards, Codex usage credits (`credits`, CLI 0.5.29+); `codexbar:<provider>` accounts when the user enabled CodexBar, `native:<provider>` (CLI 0.5.30+, `via: "native"`) when a native reader serves the provider (`modelplan connect`) |
| `sources[]` | The status of each reader (`ok`, `missing`, …, with a reason) |
| `connections[]` | CLI 0.5.27+. Per agent and quota source, how far it is connected (below) |
| `events[]` | Advice events (below), most urgent first |
| `measured[]` | The measured speed per configuration over the last 28 days, as in `modelplan history --json`, from `observed/speed.json`. Kept as it is; a client shows it only as history before `perfStats[].since` |
| `perfStats[]` | CLI 0.5.27+. The performance ledger per configuration (below) |
| `daily[]` | CLI 0.5.27+. `{day, source, model, observedOutputTokens, observedRequests}` per local day of the last 30 (today included) and model, across efforts, speed modes and parsers. Days without rows are left out, not `0`: the ledger cannot tell no activity from no coverage. Days before the ledger started are absent |
| `dailyLong[]` | CLI 0.5.32+. The same rows for the last 371 local days (53 weeks, today included), from `observed/daily-long.json`, for a year-long heatmap (below) |
| `sessionRanking` | CLI 0.5.27+. The sessions with the most observed output tokens (below) |
| `projectRanking` | CLI 0.5.29+. The same sessions summed per project (below) |
| `subscriptions` | CLI 0.5.30+. `[{subscriptionRef, sources, basis, observedAt}]`: each subscription the accounts were bound to, with the account sources read from it, for a scope selector (below) |
| `projectLabels` | CLI 0.5.29+. Whether project labels are on. Since CLI 0.5.32 they are on unless the user turned them off (`modelplan project-labels off`), and a stored choice is kept; before, they were off until `modelplan project-labels on` |
| `paceHistory` | CLI 0.5.27+. How fast each window's percentage rose per cycle (below) |
| `dailyCoverage` | CLI 0.5.27+. `{from, recording}`: the first day `daily[]` covers (the later of the ledger's start and 30 days ago; `null` without a ledger), for a label such as "observed on this machine since <from>" |
| `dailyLongCoverage` | CLI 0.5.32+. `{from, recording}`: the first day `dailyLong[]` covers, with the same meaning (below) |
| `recording` | Local quota history and speed measurement are on (`MODELPLAN_HISTORY` is not `off`) |
| `note` | The data boundary, in English |
| `dataRevision` | CLI 0.5.27+. A hash of what was observed: the accounts' readings (time, used share, reset, limit, window length, cards, the usage-credit balance and its reading time), the sessions' configuration, the readers' status, the rows of both speed ledgers and of the long-term daily ledger, the pace ledger's cycles, the publication id and `recording`. It leaves out `generatedAt` and everything the clock derives (`resetsInMinutes`, `elapsedPercent`, `projectedPercent`, `ageMinutes`, pace, staleness, events). The same revision means the same inputs, not the same document |
| `validUntil` | CLI 0.5.27+. The next instant at which the clock alone changes a verdict: a window's reset or pace threshold, its recent rate lapsing, an account reading going stale (60 minutes) or out of use (6 hours, for cached CodexBar and Codex account readings), a card expiry or its 48-hour lead, an advice lead (a public reset, a rate boundary, a switch-back's or better model's time in the menu bar), the publication going stale, and local midnight while `measured[]`, the performance ledger or the long-term daily ledger has rows, a configuration's newest sample turning 24 hours and 7 days old, and a watched cycle closing at its reset. `null` when nothing is due. Read again at or after it even when `dataRevision` is unchanged; never reuse an expired event or the allowance of a passed reset. Shares that move every minute (elapsed, projected) have no boundary, so a client showing them refreshes on its own cadence too |

A cached reading that ages out of use (a CodexBar or Codex account reading after 6 hours) changes the accounts, so it changes `dataRevision` too.

## `sessions[]`

One entry per harness that reported a model (`claude-code`, `codex`):

- `source`, `observedAt`, `attribution` (`current-thread` | `recent-thread`), `origin`, `stale`;
- `model`: `{harnessId, id, name, developerId}`. `id`, `name` and `developerId` are the publication's and are empty when the model is not listed there;
- `effort` and `recommended`: `{key, label, star}` for the effort in use (the harness default counts as ★) and the ★ effort. Both are `null` when the model is not listed. The ★ fallback in `effort` is kept for older clients only;
- `effortStatus` (CLI 0.5.27+): `reported` when the harness reported an effort, `unreported` when it did not (then `effort` is only the ★ fallback). A client draws an effort marker as the user's own only when it is `reported`;
- `vsRecommended`: `{abilityDelta, costRatio}` of the effort in use against ★, or `null` at ★;
- `speed`: `""` for standard, else the mode (`fast`, …);
- `headroom`, `deciding`, `pool`: the quota verdict of the session's account for the allowance it draws from;
- `workloadRate` (CLI 0.5.27+): the one speed reading per engine. `{source, window: "recent7d", scope: "all-configurations", configCount, value, status, n, min, lastAt, freshness}`: the generation rate of all the harness's configurations in the recent 7 days, as the ratio of their summed eligible output tokens and generation time. It describes what this user's mix produced, unreported efforts included; it is not a plan's speed and moves when the mix changes;
- `tokenRate` (CLI 0.5.27+): the same for the session's own configuration, `{configKey, window: "recent7d", value, status, n, min, lastAt, freshness}`. With `effortStatus: "unreported"` it is `unavailable` with `reason: "effort-unreported"`, since an unknown configuration is no proof of the same one. No other configuration stands in.

- `subscription` (CLI 0.5.30+): the account's binding, as in `accounts[].subscription`; `null` when unknown.
- `projectRef` (CLI 0.5.29+): the project of the harness's most recently active session in the performance ledger, as in `projectRanking`; `null` when unknown. With `attribution: "recent-thread"` that is the session this entry describes.
- `activity` (CLI 0.5.27+): `{status, lastSignalAt, basis, withinMinutes}`. `recent` when the harness's own timestamps show a turn started (Codex's turn context, `basis: "turn-started"`) or a request completed (`completed-request`, from the performance ledger) within `withinMinutes` (10); `quiet` when not since; `unknown` without such a timestamp. Claude Code's status line also renders while idle, so its time is not used. It never says a session is working now: a long turn shows only once a request in it completes.

`value` is set only when `status` is `ok`.

## `perfStats[]`

CLI 0.5.27+. From `observed/perf.json`, a ledger beside `speed.json` that is never merged with it. It starts when it is created (`since`, UTC): only turns that started at or after that count, so log content read before can never be counted again; the time before it exists only in `measured[]`. It keeps 35 days, at most 3,000 rows and 2 MiB. An unreadable, oversized or other-schema file is never overwritten; its figures are `unavailable` with `reason: "ledger-unreadable"`.

One entry per configuration with a row in the last 30 days:

- `source`, `model`, `effortStatus`, `effort` (native key; `""` when unreported), `speed`, `parser` (`codex-rollout/1` | `claude-transcript/1` | `zcode-db/1` | `opencode-db/1`), `eligibility` (`gen-v1`). Rows of different parsers or eligibility rules never merge;
- `basis`: `tokenBasis: "harness-reported-output"` (believed to include hidden reasoning for both harnesses, not yet confirmed), `timing: {start, first, end, quality: "harness-log-proxy"}` and `quantile: "log1.1-centre-lower"`. Codex: the input logged, the item's `started_at_ms`, the usage record logged. Claude Code: the input logged, the thinking block's time minus its duration, the last block logged. They are the times the harness logged, a proxy for the model's own;
- `attribution: "unattributed"`: the samples belong to the harness, not to a verified subscription;
- `since`, `lastAt` (when the newest sample completed, to the minute) and `freshness`: `fresh` within 24 hours, `aging` within 7 days, else `stale`. A recent `lastAt` does not make the figures recent, and a completed request does not mean a session is working now;
- `windows.recent7d` and `windows.recent30d`: the rows of the last 7 or 30 local calendar days, today included. Not a current or last-24-hour rate. Each has:
  - `sums`: `observedRequests` and `observedOutputTokens` (every request the parser saw in a finished turn of the logs this CLI reads, counted once: Codex rollouts it scans, Claude Code transcripts seen through the status line; not the account's consumption), `eligibleRequests`, `eligibleOutputTokens`, `genMs` (requests with a known first token, at least 20 output tokens, 0.2 s to 30 min of generation and at most 3,000 tok/s), `turns`, `turnMs`, `turnOutputTokens` and `mixedConfigTurnsExcluded` (Claude Code turns whose requests ran under more than one configuration; their requests count under their own);
  - `hist`: `ttftMs`, `turnMsHist`, `turnTokensHist`, each `{scheme: "log1.1/v1", unit, counts}`. Bucket `k` ≥ 1 holds [1.1^k, 1.1^(k+1)), bucket `0` everything below 1.1. Histograms merge by adding counts, only with the same scheme and unit;
  - `metrics`: `generationTps` (Σ eligible output tokens ÷ Σ generation seconds), `ttftMs` (the merged histogram's estimate: the lowest bucket whose count reaches half, at its geometric centre; within about 5% of the lower median, never exact) and `wholeTurnTps` (Σ turn output tokens ÷ Σ turn seconds, tools included; for expanded views). Each is `{value, status, n, min, reason}` with `min` 5. `status`: `ok`, `insufficient` (fewer than `min`), `stale` (newest sample older than 7 days), `unavailable` (`no-first-token`: the source gives none, such as Claude Code without thinking; or `ledger-unreadable`), `off` (recording is off).

Rates are always ratios of sums and quantiles always come from merged histograms; nothing averages rates or medians. A generation rate is a per-request speed, not throughput: two sessions generating at 60 tok/s at the same time read 60, not 120. Speed is never used to infer plan usage or remaining quota, and it never changes published ability or recommendations.

Display rules for clients: one number per engine, `workloadRate.value`, labelled with its window and scope ("62 t/s · 7 days · all configurations"); shown only when `ok`, dimmed when `aging`, hidden when `stale`, and not drawn at all otherwise (never `0`, never the legacy `measured[]`). `tokenRate` and the `perfStats[]` entries go in hover or expanded views. Nothing in this version is any subscription's speed.

## `dailyLong[]`

CLI 0.5.32+. The rows of `daily[]` (`{day, source, model, observedOutputTokens, observedRequests}`, per local day, source and model, across efforts, speed modes and parsers) for the last 371 local days, today included: 53 weeks, for a year-long heatmap. They come from `observed/daily-long.json`. Each time the CLI writes `perf.json`, it rolls that ledger's days up into this file, which keeps them after `perf.json` lets them go at 35 days.

- It counts nothing `perf.json` did not: the same logs and databases, read the same way, from the same `since`. Per day, source and model it keeps the larger of its stored figure and the current one, so reading a log again never counts a request twice. Where its days overlap `daily[]`, the figures are the same.
- It holds only days, sources, model names and the two sums. It has no prompts, replies, titles, paths, projects, sessions, subscriptions or ids.
- It stays below 1 MiB, about 0.3 MB for a year of a few models a day. If a year does not fit, the oldest days go first, each day whole, and coverage starts after them.
- `MODELPLAN_HISTORY=off` stops it together with `perf.json`; deleting the file clears it. An unreadable file is never overwritten.

`dailyLongCoverage` is `{from, recording}`, read as `dailyCoverage`. `from` is the first day `dailyLong[]` covers, the latest of:

- 371 days ago;
- the ledger's `since`: `perf.json`'s `since`, or, when `perf.json` was older than 35 days when the file was made, the start of the oldest day it still held whole;
- the day after a size trim.

Before the file's first write, or when it cannot be read, `dailyLong[]` is what `perf.json` holds: its days from its `since`, at most 35 days back. `from` is `null` when `perf.json` cannot be read (nothing is recorded then) or neither ledger has started. Days without rows are left out, not `0`, as in `daily[]`.

## `connections[]`

CLI 0.5.27+. One entry per known source, in a fixed order: `codex`, `claude-code`, `opencode`, `zcode` (CLI 0.5.31+), then one entry per optional quota provider: `codexbar:<provider>`, or `native:<provider>` (CLI 0.5.30+) when connections.json gives it to a native reader. A native entry's authorization is `yes` with `via: "env:<NAME>"` when the key variable is set where the CLI runs, else `no` with `reason: "key-env-unset"`; a provider turned off in connections.json is `off`. The CLI only checks whether known paths exist and reuses what its readers already report: it runs no client, reads no credential or secret value, and changes nothing.

- `id`, `kind` (`agent` | `quota`) and `support`: `full` (sessions and quota), `quota-only` (CodexBar providers such as Kiro: quota, no session reader) or `detected-only` (OpenCode: found, nothing read yet).
- Four levels, each `{status, reason, via, at, binding}` with `status` `yes`, `no`, `off` (turned off by the user's switch), `unknown` or `not-applicable`, and `reason` a stable code:
  - `installed`: the client or its CLI is at a known path (on `PATH` or the usual install places, a macOS app, or its data folder). A desktop app started from Finder has a short `PATH`, so the usual places are checked too;
  - `history`: its local logs were read (`at`: the newest reading). OpenCode: `no-session-reader`;
  - `authorization`: a reader that needs the user's opt-in is enabled: Codex's own account reader (`via: "agent-owned-reader"`, `off` with `MODELPLAN_CODEX_ACCOUNT=off`), a CodexBar provider the user enabled (`via: "codexbar"`, `off` with `MODELPLAN_CODEXBAR=off`, else `not-enabled`). Claude Code needs none (`via: "status-line"`);
  - `quota`: windows were read (`at`: when). `binding` is `unknown`: a reading proves a meter, not whose subscription it is.

### Agents read from their databases

CLI 0.5.31+. Besides the Codex and Claude Code logs, the ledger reads two agents' own SQLite databases, opened read-only and never created or changed:

- **ZCode**: `~/.zcode/cli/db/db.sqlite` (`MODELPLAN_ZCODE_DB` to override), table `model_usage`, one row per model call; the working directory from its `session` table.
- **OpenCode V2**: `opencode.db` under `$XDG_DATA_HOME/opencode` (default `~/.local/share/opencode`, `MODELPLAN_OPENCODE_DB` to override), assistant rows of `session_message`; output and reasoning tokens both count as output, as Codex and Claude Code report them. A forked session's copies of earlier messages are not counted again. The V1 `message` table and JSON storage are not read.

Each finished request counts once, from rows written after the ledger's `since`; the rest follows in batches of 5,000 rows, at most every 30 seconds and only when the database changed. Their times run from the request's start to its end, the wait for the first token included, so they are never eligible generation samples: tokens, days, sessions, projects and rankings count, generation rates stay `insufficient` for these sources. Efforts are `unreported` (neither records one the CLI can rely on yet). Neither prompts, replies, titles nor ids reach the ledger. The formats follow [tokei](https://github.com/cclank/tokei) and [Tokscale](https://github.com/junhoyeo/tokscale) (both MIT); no code is copied.

## `sessionRanking`

CLI 0.5.27+. `{measure: "observed-output-tokens", recent7d, recent30d}`; each window is `{sessions, totalObservedOutputTokens, top}`, with `top` the five sessions with the most observed output tokens in its local days:

- `ref`: a random reference made on this machine. Sessions carry no title, path or session id;
- `source`, `firstAt` (the first counted turn's start) and `lastAt` (the newest sample's completion), to the minute;
- `observedOutputTokens`, `observedRequests` and `share`: the session's part of the window's observed output tokens. That is a share of what this CLI saw in the logs it reads, not of any plan or allowance;
- `projectRef` (CLI 0.5.29+): the session's project, as in `projectRanking`; `null` when its log records no working directory;
- `subscriptionRef` (CLI 0.5.30+): the subscription the harness was signed in to when the session's first turn with a known one was read; `null` when unknown;
- `configs[]`: `{model, effortStatus, effort, speed, observedOutputTokens, share, recommendedEffort}`, the largest first, at most three. `share` (CLI 0.5.29+) is the configuration's part of the session's output in the window; `recommendedEffort` (CLI 0.5.29+) is the published ★ effort of the model as a native key, absent when the publication has none.

The sessions are kept in the performance ledger with the same `since`, 35 days and size limits; a session whose last day is older leaves it. Codex's own threads (subagents, reviews) are not read, so they are neither ranked nor counted, and never counted twice; Claude Code's sidechain requests are not counted either. Titles are not kept at all.

## Subscriptions

CLI 0.5.30+. A subscription is known by a random reference made on this machine the first time a reader sees its account; the account itself is never stored, and the keyed hash that maps it to the reference stays in `observed/subscriptions.json`. `accounts[].subscription` is `{subscriptionRef, status: "verified", basis, observedAt}`, with `basis`:

- `codex-account`: Codex's own `account/read`, asked with the account reading (the signed-in ChatGPT account; none for an API-key login);
- `claude-config`: the account and organization ids in Claude Code's `.claude.json` (`$CLAUDE_CONFIG_DIR` when set), read by the status line when that file changes; the e-mail and names in it are not read, and it holds no tokens;
- `codexbar`: the account id CodexBar reports for a provider;
- `api-key`: a native reader's API key (each key is one subscription).

An account without one (Codex read only from its logs, a declared plan) has none, and the session ledger keeps sessions read before as unknown. Two harnesses signed in to the same account share a reference only when the same basis saw it. `MODELPLAN_IDENTITY=off` stops all of it. A read-only snapshot shows only references made before.

## `projectRanking`

CLI 0.5.29+. `{measure: "observed-output-tokens", recent7d, recent30d}`; each window is `{projects, totalObservedOutputTokens, unattributedOutputTokens, top}`. `totalObservedOutputTokens` counts every session in the window; `unattributedOutputTokens` is the part from sessions whose log records no working directory. `top` holds the ten projects with the most observed output tokens:

- `ref`: an opaque reference, a keyed hash of the project root with a random key kept beside the ledger (`observed/project-key`). It says nothing about the path and differs between machines. The root is the repository's git common directory when the session's working directory is inside a checkout or worktree that still exists when it is read, so all worktrees of one repository are one project; otherwise it is the working directory itself, also when that was removed before it was read. `.git` files are read; git is never run;
- `label`: the project folder's name (not its path), only while `projectLabels` is on, which is the default since CLI 0.5.32; `null` otherwise, and the desktop names projects by rank ("Project A / B / C"). A choice the user stored is kept: a user who turned labels off stays off. Turning labels off (`modelplan project-labels off`) deletes the stored names; the references stay. Names are kept only on this machine and are never synced or uploaded;
- `sessions`, `lastAt`, `observedOutputTokens`, `observedRequests` and `share` (the project's part of `totalObservedOutputTokens`);
- `subscriptionRefs` (CLI 0.5.30+): the subscriptions its sessions ran under, as far as known;
- `configs[]`: as in `sessionRanking`, across the project's sessions.

Sources: the Codex rollout's working directory (session meta and turn context) and the Claude Code transcript's. The first one a session records names its project. At most 500 projects are kept; the ones last active longest ago lose their reference first, and a reference goes with its last session. Neither the reference nor the label is meant for anything that leaves the machine; a future portable or synced form leaves both out.

## `paceHistory`

CLI 0.5.27+. Quota percentage pace, a different quantity from token speed; neither is derived from the other, and points are never turned into tokens or back. From `observed/pace.json`, kept from the same readings as the quota history (`observed/cycles.json`, behind `modelplan history`). `cycles.json` is not changed and never mixed in. The pace ledger keeps 35 days of five-hour cycles and 84 days of longer ones. It has its own `since`: readings taken before it are not counted. An unreadable file is never overwritten.

`{since, status, reason, gapLimitMinutes, groups}`. `status` is `ok`, `off` (recording is off) or `unavailable` (`reason: "ledger-unreadable"`). `gapLimitMinutes` gives, per window kind, the silence after which a rise is not credited to any configuration: five-hour 60, weekly 360, monthly 1440.

`groups[]`: one per (`source`, `plan`, `limit`, `kind`, `windowMinutes`), Claude Code and Codex only. Weekly, monthly, five-hour and Codex Reserve windows are separate groups and are never added together. Two accounts on the same plan are not told apart, so every group is `attribution: "unattributed"` and is not for advice by account.

- `closedCycles`, `validCycles`: cycles whose reset passed; of those, the ones without a drop and with an observed span;
- `observedIntervalRatePerHour`: Σ points ÷ Σ observed span hours over the valid cycles. It includes idle time inside the spans, so it is an average over watched intervals, not a burn rate while working. Set only when `status` is `ok`, which needs `min` (2) valid cycles: a threshold for showing a number, not proof it is reliable enough to advise from;
- `cycles[]`, newest first, at most 10: `resetsAt`, `closed` (the reset passed; `lastUsed` is then the last reading, not a final one), `firstObservedAt`/`firstUsed`, `lastObservedAt`/`lastUsed`, `readings` (at most one unchanged reading per two minutes counts), `spanMinutes`, `coverage` (span ÷ window length, only when the source gives the length: Codex reports it, Claude Code's `five_hour` and `seven_day` fields name it; else `null`; the span is not sampling coverage), `gapCount` and `maxGapMinutes` (gaps longer than the limit), `drops` and `hadDrop` (the meter fell under the same reset, for a reset card or a correction; later rises count from the new value), `points` (every rise observed), `gapPoints` (the part seen only after a gap, configuration unknown), and `spent[]` (`{model, effort, fast, points}` for the rest) with `spentBasis: "reading-time-heuristic"`: a rise is credited to the configuration of the reading that saw it. A recording-off period shorter than the gap limit cannot be detected and is credited the same way.

A window with no readings has no cycle (no zero). Cycles show percentages only; tokens per cycle are not available, since the performance ledger is per local day. Nothing here changes model, effort or Fast.

## `events[]`

The events of `modelplan advise --json` (types, `suggest`, `alternative`, `current`, … as in the Skill reference), plus:

- `key`: the once-only key. Configuration advice (tight, surplus) is keyed per model and effort, a better model per model, effort and target. Notify once per key.
- `text`: `{zh, en}`, the full sentence.
- `short`: `{zh, en}` for a menu bar, such as `↑High ×1.37`, `↓★Med ×0.73`, `→Opus 5.5 ★Med ×0.52` or `↺★Med`. Absent when the event has none.
- `inMenuBar`: whether the Claude Code status line would show it now. A switch-back shows for a while after it appeared, a better model for a week.

## Privacy

The snapshot holds no prompts, replies, tool output, credentials, file paths, session ids or account identities: subscriptions appear only as random local references. With project labels on (the default since CLI 0.5.32), `projectRanking` names each project by its folder's name, not its path; `modelplan project-labels off` removes the names. It carries window meters, the harness's model, effort and speed mode, and the measured figures. A Claude Code session on a custom endpoint also carries that endpoint's scheme, host and path (`ANTHROPIC_BASE_URL` without query or credentials), as `modelplan quota --json` does. Anything that sends it off the machine, such as a future mobile sync, must encrypt it end to end.

## CLI 0.5.33: today's speed, token kinds, live sessions and hours

These are additive schema-v1 fields. Older snapshots and ledger rows remain readable. Upgrade all local CLI/plugin writers before relying on these fields: an older writer can discard fields it does not know when rewriting the schema-v1 ledger. All new
observations come from local timestamps and token usage, never message text, account endpoints or
uploads. `MODELPLAN_HISTORY=off` stops their recording too. `--read-only` only projects the saved
ledger and does not discover or record new sessions.

### Today and token kinds

`perfStats[].windows.today` has the same `sums`, `hist` and `metrics` shape and sample gates as
`recent7d`, restricted to the current local calendar day. It follows the existing performance
ledger's **turn-start day** attribution; a turn spanning midnight remains assigned to its start day.
`todayTotals[]` supplies `{source, sums}` across configurations for that day. Generation speed is
`sum(eligibleOutputTokens) / (sum(genMs) / 1000)`, never an average of configuration speeds. Preserve
`eligibleRequests` and the normal five-sample display gate; zero eligible time does not mean 0 t/s.

`subscriptions[].sources` can join a source to an already known subscription. These source-wide
sums are **not historically subscription-attributed**: if more than one subscription maps to a
source, do not duplicate its sum into each subscription or claim the historic account is known.
No account reading is requested to fill that gap.

The following nullable fields are in performance ledger rows, window sums, `daily[]`, `dailyLong[]`
and `hourly[]`:

| Field | Meaning |
|---|---|
| `inputTokens` | Input excluding cache reads, as reported/normalized below |
| `cacheReadTokens` | Cache-read input tokens |
| `cacheWriteTokens` | Cache-write input tokens when reported |

A missing field in an old row becomes `null`, not zero. An aggregate is known only if **every
counted request** supplied that field; newer partial samples never masquerade as a complete old
sum. Explicit recorded zero is kept. The desktop's cache-hit ratio is
`cacheReadTokens / (inputTokens + cacheReadTokens)` only when both operands are known and the
denominator is positive. Cache writes are diagnostic and not added again to this formula.

- Claude Code: `usage.input_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`;
  repeated blocks of one request use their largest reported counters, not their sum.
- Codex: `last_token_usage` is preferred; `total_token_usage` is differenced only after a prior
  total exists, and a reset is not a negative request. Its `input_tokens` includes
  `cached_input_tokens`, which is subtracted for `inputTokens`; if that cached count is absent,
  uncached input remains unknown. Newer `cache_write_input_tokens` is optional. A preceding
  `token_usage_record` and its `token_count` notice are one request; the notice can fill missing
  kinds without double-counting. These fields follow the [official protocol](https://github.com/openai/codex/blob/main/codex-rs/protocol/src/protocol.rs)
  and are exercised only with synthetic parser fixtures, never a user's logs.
- OpenCode V2: `tokens.input`, `tokens.cache.read`, `tokens.cache.write`; output still includes
  `tokens.reasoning` as before. Missing JSON values are unknown.
- ZCode: `input_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens` when those
  columns exist. Missing columns/NULL values are unknown. The databases stay read-only.

### `liveSessions[]`

The entries with a local log/database signal in the last **five minutes**, independent of the
legacy one-per-harness `sessions[]`. A signal exactly five minutes old is expired. Fields:

```json
{
  "ref": "7b540e218d963fac", "source": "claude-code", "model": "fixture-model",
  "effort": "high", "effortStatus": "reported", "speed": "",
  "projectRef": null, "subscriptionRef": null,
  "startedAt": "2026-10-23T09:00:00Z", "lastAt": "2026-10-23T09:00:40Z",
  "status": "running",
  "rate": {"source":"claude-code","window":"60s","scope":"session","value":null,
           "status":"insufficient","n":2,"min":5,"reason":"too-few-samples","lastAt":"2026-10-23T09:00:40Z"}
}
```

This example is synthetic. `ref` is a random local reference, not a harness session ID.
`startedAt` is the earliest observed start (or existing ledger's first start); it need not be the
harness's creation instant. `lastAt` is an actual log signal, never the poll's time. `running` means
an unfinished logged turn/request; `idle` means its latest observed work completed. No operating
system process or server request liveness is inferred. A long silent operation can leave the
five-minute observed set without proving it stopped. Unknown effort is `""` / `unreported`, never ★.

The `rate` uses eligible completed requests of the **current configuration**, whose completions
are in `(now-60s, now]`, including requests in a still-open turn. Five samples are required. With
fewer it is `insufficient` / `too-few-samples`; observations with no eligible generation are
`unavailable` / `no-eligible-generation`. No other session or configuration supplies a fallback.
`validUntil` includes sample expiry and the five-minute session expiry, even if dataRevision stays
unchanged. Merely reading live data never adds historical token counts.

Normal `desktop --json` discovers the newest 64 regular JSONL files modified within five minutes
under Claude's configured `projects/` and Codex's `sessions/`, without following symlinks. Discovery
visits at most 20,000 entries per root and parsing reads at most a 256-KiB tail per file. This is a
bounded observation set, not a claim to inventory all running processes. A tail missing its model
context cannot produce a fabricated configuration. Pending SQLite reads follow the existing batch
and 30-second bounds. Live state is kept in perf.json for five minutes, with at most 64 entries and
256 recent request samples per entry, with a 512-KiB live-state cap inside its existing 2-MiB bound; oldest entries leave first.

| Harness | Concurrent/subagent behavior and limits |
|---|---|
| Claude Code | Separate transcripts are separate entries; `subagents/*.jsonl` may carry `isSidechain`. Inline sidechain lines in the parent remain excluded, so they are not folded into its rate. Without an observed prompt/model context the entry may be unavailable. Generation still needs the thinking-start proxy. |
| Codex | Separate rollout files, including subagent/review origins, are independent live entries. The historical ledger's existing background-thread exclusions are unchanged. Missing first-token timestamps mean no generation rate. |
| OpenCode V2 | Sessions with their own new/pending database requests are separate entries. Copied fork history does not become new activity. Only request start/end is available, so generation rate remains unavailable. |
| ZCode | Each database session is separate. A pending request is running; completed is idle. Without first-token evidence there is no generation rate. |

### `hourly[]`

`{hour, source, model, observedOutputTokens, observedRequests, inputTokens, cacheReadTokens,
cacheWriteTokens}` for **today and yesterday** in local time. `hour` is an ISO hour with its UTC
offset, e.g. `2026-11-01T01:00:00-04:00` and `2026-11-01T01:00:00-05:00` are two distinct hours.
Only finished requests count, by their **completion hour**; nothing is split or estimated across
hours. This differs from daily/performance turn-start attribution for work spanning midnight.
Unfinished turns appear in live data before the existing historical parser commits them.

At most 48 buckets per source/model, 2,048 buckets overall and 512 KiB are kept, never beyond those two
local days. A 25-hour DST day plus another day can exceed 48: oldest buckets are omitted, not
merged or represented as zero. A missing hour means no observation, not verified inactivity.
The same limits apply during read-only projection even before another ledger write.

### 中文摘要

新增字段保持 schema v1：`perfStats[].windows.today` 和 `todayTotals[]` 给出今日合格输出量、
生成毫秒数及请求数；先相加再相除，不平均各配置的速度。它们沿用原账本的回合开始日期。
`liveSessions[]` 表示最近 5 分钟有本地信号的会话，速度只看最近 60 秒、至少 5 个合格样本；
独立子会话不并入父会话。`hourly[]` 按请求完成小时记账，只保留今天、昨天，每来源与模型最多
48 桶，夏令时重复小时由时区偏移区分。跨午夜的小时统计与原来的按回合开始日期统计可能不同。
输入、缓存读取、缓存写入缺失时为 `null`，不是零；缓存命中率仅在字段已知时按
`cacheRead / (input + cacheRead)` 计算。所有新增记录只在本机，关闭历史开关会停止记录；
只读模式不写文件、不发现新会话，也不请求账号端点。

`localUsage[]` is an additive, optional local accounting view. Gemini is off until `modelplan usage gemini enable`. Its rows group native token counters by local day and model; sessions expose only keyed references and timestamps. Counters are nullable, `coverage` identifies bounded/skipped history, and `scope` distinguishes this from account quota. No credential or network access is involved. These values do not enter existing quota accounts, speed estimates or the performance ledger's daily totals. Source paths, an empty `hosts` list and privacy text are also present in Gemini connection diagnostics. Snapshot revisions exclude each report's evaluation clock; enabled local usage adds a local-midnight refresh boundary.
