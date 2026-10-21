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
| `accounts[]` | The quota accounts, exactly as `modelplan quota --json` gives them: windows with pace, run-out, pools (Codex `reserve`), reset cards; `codexbar:<provider>` accounts when the user enabled CodexBar |
| `sources[]` | The status of each reader (`ok`, `missing`, …, with a reason) |
| `events[]` | Advice events (below), most urgent first |
| `measured[]` | The measured speed per configuration over the last 28 days, as in `modelplan history --json`, from `observed/speed.json`. Kept as it is; a client shows it only as history before `perfStats[].since` |
| `perfStats[]` | CLI 0.5.27+. The performance ledger per configuration (below) |
| `daily[]` | CLI 0.5.27+. `{day, source, model, observedOutputTokens, observedRequests}` per local day of the last 30 (today included) and model, across efforts, speed modes and parsers. Days without rows are left out, not `0`: the ledger cannot tell no activity from no coverage. Days before the ledger started are absent |
| `paceHistory` | CLI 0.5.27+. How fast each window's percentage rose per cycle (below) |
| `dailyCoverage` | CLI 0.5.27+. `{from, recording}`: the first day `daily[]` covers (the later of the ledger's start and 30 days ago; `null` without a ledger), for a label such as "observed on this machine since <from>" |
| `recording` | Local quota history and speed measurement are on (`MODELPLAN_HISTORY` is not `off`) |
| `note` | The data boundary, in English |
| `dataRevision` | CLI 0.5.27+. A hash of what was observed: the accounts' readings (time, used share, reset, limit, window length, cards), the sessions' configuration, the readers' status, the rows of both speed ledgers, the pace ledger's cycles, the publication id and `recording`. It leaves out `generatedAt` and everything the clock derives (`resetsInMinutes`, `elapsedPercent`, `projectedPercent`, `ageMinutes`, pace, staleness, events). The same revision means the same inputs, not the same document |
| `validUntil` | CLI 0.5.27+. The next instant at which the clock alone changes a verdict: a window's reset or pace threshold, its recent rate lapsing, an account reading going stale (60 minutes) or out of use (6 hours, for cached CodexBar and Codex account readings), a card expiry or its 48-hour lead, an advice lead (a public reset, a rate boundary, a switch-back's or better model's time in the menu bar), the publication going stale, and local midnight while `measured[]` or the performance ledger has rows, a configuration's newest sample turning 24 hours and 7 days old, and a watched cycle closing at its reset. `null` when nothing is due. Read again at or after it even when `dataRevision` is unchanged; never reuse an expired event or the allowance of a passed reset. Shares that move every minute (elapsed, projected) have no boundary, so a client showing them refreshes on its own cadence too |

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

`value` is set only when `status` is `ok`.

## `perfStats[]`

CLI 0.5.27+. From `observed/perf.json`, a ledger beside `speed.json` that is never merged with it. It starts when it is created (`since`, UTC): only turns that started at or after that count, so log content read before can never be counted again; the time before it exists only in `measured[]`. It keeps 35 days, at most 3,000 rows and 2 MiB. An unreadable, oversized or other-schema file is never overwritten; its figures are `unavailable` with `reason: "ledger-unreadable"`.

One entry per configuration with a row in the last 30 days:

- `source`, `model`, `effortStatus`, `effort` (native key; `""` when unreported), `speed`, `parser` (`codex-rollout/1` | `claude-transcript/1`), `eligibility` (`gen-v1`). Rows of different parsers or eligibility rules never merge;
- `basis`: `tokenBasis: "harness-reported-output"` (believed to include hidden reasoning for both harnesses, not yet confirmed), `timing: {start, first, end, quality: "harness-log-proxy"}` and `quantile: "log1.1-centre-lower"`. Codex: the input logged, the item's `started_at_ms`, the usage record logged. Claude Code: the input logged, the thinking block's time minus its duration, the last block logged. They are the times the harness logged, a proxy for the model's own;
- `attribution: "unattributed"`: the samples belong to the harness, not to a verified subscription;
- `since`, `lastAt` (when the newest sample completed, to the minute) and `freshness`: `fresh` within 24 hours, `aging` within 7 days, else `stale`. A recent `lastAt` does not make the figures recent, and a completed request does not mean a session is working now;
- `windows.recent7d` and `windows.recent30d`: the rows of the last 7 or 30 local calendar days, today included. Not a current or last-24-hour rate. Each has:
  - `sums`: `observedRequests` and `observedOutputTokens` (every request the parser saw in a finished turn of the logs this CLI reads, counted once: Codex rollouts it scans, Claude Code transcripts seen through the status line; not the account's consumption), `eligibleRequests`, `eligibleOutputTokens`, `genMs` (requests with a known first token, at least 20 output tokens, 0.2 s to 30 min of generation and at most 3,000 tok/s), `turns`, `turnMs`, `turnOutputTokens` and `mixedConfigTurnsExcluded` (Claude Code turns whose requests ran under more than one configuration; their requests count under their own);
  - `hist`: `ttftMs`, `turnMsHist`, `turnTokensHist`, each `{scheme: "log1.1/v1", unit, counts}`. Bucket `k` ≥ 1 holds [1.1^k, 1.1^(k+1)), bucket `0` everything below 1.1. Histograms merge by adding counts, only with the same scheme and unit;
  - `metrics`: `generationTps` (Σ eligible output tokens ÷ Σ generation seconds), `ttftMs` (the merged histogram's estimate: the lowest bucket whose count reaches half, at its geometric centre; within about 5% of the lower median, never exact) and `wholeTurnTps` (Σ turn output tokens ÷ Σ turn seconds, tools included; for expanded views). Each is `{value, status, n, min, reason}` with `min` 5. `status`: `ok`, `insufficient` (fewer than `min`), `stale` (newest sample older than 7 days), `unavailable` (`no-first-token`: the source gives none, such as Claude Code without thinking; or `ledger-unreadable`), `off` (recording is off).

Rates are always ratios of sums and quantiles always come from merged histograms; nothing averages rates or medians. A generation rate is a per-request speed, not throughput: two sessions generating at 60 tok/s at the same time read 60, not 120. Speed is never used to infer plan usage or remaining quota, and it never changes published ability or recommendations.

Display rules for clients: one number per engine, `workloadRate.value`, labelled with its window and scope ("62 t/s · 7 days · all configurations"); shown only when `ok`, dimmed when `aging`, hidden when `stale`, and not drawn at all otherwise (never `0`, never the legacy `measured[]`). `tokenRate` and the `perfStats[]` entries go in hover or expanded views. Nothing in this version is any subscription's speed.

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

The snapshot holds no prompts, replies, tool output, credentials, file paths or session ids. It carries window meters, the harness's model, effort and speed mode, and the measured figures. A Claude Code session on a custom endpoint also carries that endpoint's scheme, host and path (`ANTHROPIC_BASE_URL` without query or credentials), as `modelplan quota --json` does. Anything that sends it off the machine, such as a future mobile sync, must encrypt it end to end.
