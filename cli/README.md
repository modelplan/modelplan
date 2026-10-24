# modelplan — Go thin client

This is a read-only, anonymous, single static binary with no GUI. It reads the verified public publication, keeps the shared local cache (see [`../README.md`](../README.md)) and prints the hangar views in a terminal. The Claude Code and Codex plugins call it (their hooks run `advise --hook`), and the desktop menu-bar app will be built on it later. Install: `curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh` (latest release, checksum-checked, into `~/.local/bin`).

```sh
cd cli
go test -race ./...
go build -o dist/modelplan ./cmd/modelplan

./dist/modelplan sync                 # verify and cache the current publication
./dist/modelplan lineup               # WHICH ENGINE for Anthropic and OpenAI
./dist/modelplan lineup --dev openai --json
./dist/modelplan effort opus          # ladder relative to ★ recommended
echo '{"model":{"id":"claude-opus-5-5"}}' | ./dist/modelplan statusline
./dist/modelplan statusline --harness codex --model gpt-6-astra --no-color
./dist/modelplan doctor
./dist/modelplan quota                # your own windows, read on this machine only
./dist/modelplan advise               # what is worth doing about them now
./dist/modelplan codexbar enable cursor zai   # other plans, read through CodexBar's CLI (opt-in)
echo '{"model":{"id":"claude-opus-5-5"},"rate_limits":{"five_hour":{"used_percentage":39,"resets_at":2000000000}}}' \
  | ./dist/modelplan statusline --preview   # a sample line, nothing recorded
```

`advise` events: a window used up, tight (also early: half used and on pace to run out; or a recent burst that runs it out within three hours, with the time), reset soon with allowance left, an announced Codex reset, switch back after a reset (to the configuration in use before the hint, and Codex Fast off if it was turned on since), peak and off-peak rates, expiring cards and public resets. A tight window suggests a lower effort and, when there is one, a cheaper published model that scores at least as high (`alternative`). Multiples (×) are the published API cost of a reference task: they track plan usage roughly within one model and are only a guide across models.

`modelplan history` (`--json`) shows the local quota history: for each window cycle, how much was used by its last reading and how many points each model, effort and Fast setting spent (each rise goes to the configuration of the reading that saw it). It is recorded in `observed/cycles.json` whenever the status line, a plugin hook or `advise` runs, kept 28 days for five-hour cycles and 12 weeks for weekly ones, and never uploaded. Since CLI 0.5.27 the same readings also go into `observed/pace.json`, which keeps every counted reading, its gaps and drops, for the desktop snapshot's `paceHistory` (see [docs/personal-snapshot.md](../docs/personal-snapshot.md)). `MODELPLAN_HISTORY=off` stops both; deleting a file clears it. It is the basis for suggesting a default effort from a user's own finished weeks in a later release.

`modelplan desktop` prints the personal snapshot for the desktop app as JSON: each harness session's configuration against ★, the quota accounts, the advice events with their text and menu-bar form, and the measured speed. The format is in [docs/personal-snapshot.md](../docs/personal-snapshot.md). Its project ranking names projects by their folder (not their path) unless you turn that off: `modelplan project-labels off` deletes the stored names and keeps only opaque references, and the choice is kept. The names stay on this machine.

The same command, and `modelplan effort <model>` for one model, also show **your measured speed** per configuration (model, effort, speed mode) over the last 28 days: output tokens per second of generation, the median time to the first token, and the median turn time and output tokens per turn, each effort against ★ in standard mode (beside the published time multiple) and a speed mode's rate against the same effort in Standard (beside the published speed-up). The CLI reads them from the current Claude Code session's transcript (`transcript_path`, given to the status line and hooks) and the recent Codex rollouts: only timestamps, output token counts, model, effort and speed mode; never prompts, replies, tool input or output; no paths or ids are stored. A figure needs 5 samples. They are kept per day in `observed/speed.json`. Since CLI 0.5.27 the same readings also go into a second ledger, `observed/perf.json` (35 days, counted only from when it was created), behind the desktop snapshot's `perfStats[]` and `daily[]` (see [docs/personal-snapshot.md](../docs/personal-snapshot.md)). Since CLI 0.5.32 its days are also rolled up per day, source and model into `observed/daily-long.json` (371 days, below 1 MiB; only days, model names, output tokens and requests), behind `dailyLong[]`. `MODELPLAN_HISTORY=off` stops all three; deleting a file clears it. While recording is off the logs are not marked as read, so a later run with recording on can still pick up what was written meanwhile, within the usual read limits. `--json` adds `measured[]` (`source`, `model`, `effort`, `speed`, `days`, `requests`, `turns`, `outputTokensPerSecond`, `ttftSeconds`, `turnSeconds`, `turnOutputTokens`).

### Other plans through CodexBar

`modelplan codexbar enable cursor zai` reads the usage of plans whose meters sit behind the vendor's own sign-in: `copilot`, `cursor`, `kiro`, `opencodego` and `zai`. It does this through the CLI of [CodexBar](https://github.com/steipete/CodexBar) (MIT). Claude Code and Codex are never read this way; this client reads them itself.

- **Off until enabled.** Enabling is the consent. It is stored in `~/.config/modelplan/codexbar.json`. `modelplan codexbar disable` turns it off again, and `MODELPLAN_CODEXBAR=off` overrides it.
- **No credentials pass through this client.** CodexBar finds them where the user keeps them: its own config (`config set-api-key`), another CLI's login (kiro-cli), the Cursor app, or browser cookies. In the background it never asks for Keychain access. `modelplan codexbar` shows, per provider, what was read and, when nothing was, what CodexBar needs.
- **Pinned release.** The first run downloads the CodexBar CLI release pinned in `internal/quota/codexbar-pin.json`: about 14 MB on macOS and 53 MB on Linux. It is checked against the pinned SHA-256 and kept under the cache's `codexbar/` directory. `MODELPLAN_CODEXBAR=<path>` uses another copy, and one the user installed is used when there is no pinned copy. The `codexbar-pin` workflow proposes newer releases weekly, after a live check that their JSON still parses.
- **Runs in the background.** At most every 10 minutes (30 after every provider failed), one provider per call, with a 60 s limit each and English output. The cached reading (`observed/codexbar.json`) holds windows, reset times and the plan name only. Identities, account ids and error text naming local paths or addresses are dropped.
- **Shown, not hinted.** `quota` and the dashboards show these plans. They give no prompt hints in Claude Code or Codex, which do not draw on them.
- **Estimates are not quota.** CodexBar's OpenCode Go estimate from local history uses fixed denominators, so it is reported as `estimated` and not shown as a quota.

`advise --hook claude-code|codex` is the plugins' prompt hook: it reads the hook input from stdin and shows new hints to the user once (the hook's `systemMessage`; they never reach the model). The model gets only a task-start brief with the published options on a thread's first prompt, and one line with the ladder of a model the thread was not briefed on. It never blocks the prompt; with no publication cached yet it waits up to 3.5 s for a first sync, then goes on in the background. `MODELPLAN_TASK_BRIEF=off` turns the brief off.

Example output (publication `23cd7308…`, release 0.18.9):

```text
WHICH ENGINE 选哪台 · Anthropic · 各模型都在 ★推荐档 · 成本以 Haiku 5.5 为 ×1
  Haiku 5.5 → Sonnet 5.5      能力 +8.3  成本 ×3.1
  Sonnet 5.5 → Opus 5.5       能力 +8.5  成本 ×1.9
  跳过：Fable 5.1、Opus 5（又贵又不更强）

  Opus 5.5           ★Med     能力  55.4 ████████████  成本 ×6.0   ▰▰▰▰▱  最强 最划算
  Fable 5.1          ★Med     能力  52.9 ███████████▌  成本 ×12    ▰▰▰▰▰  不如 Opus 5.5
  Sonnet 5.5         ★High    能力  46.9 ██████████▏   成本 ×3.1   ▰▰▰▱▱
  Opus 5             ★Med     能力  46.5 ██████████▏   成本 ×11    ▰▰▰▰▰  ≈ Sonnet 5.5 但更贵
  Haiku 5.5          ★XHigh   能力  38.6 ████████▍     成本 ×1.0   ▰▱▱▱▱  最省

▲ Opus 5 ★Med │ 能力 46.5 │ 成本 ×11 vs Haiku 5.5 │ ≈ Sonnet 5.5 但更贵
```

## Layout

| Package | Role |
| --- | --- |
| `cmd/modelplan` | Commands, flags, exit codes: 0 ok, 1 error, 2 usage, 3 no verified data, 75 another sync running. |
| `internal/publication` | Read protocol: pointer + ETag → manifest → component, each sha256-verified. The last good publication is kept on any failure. |
| `internal/store` | Shared cache: atomic writes, `sync.lock`, pruning. |
| `internal/digest` | **The only place that maps publication fields.** It decodes the published `client.data` fields only; missing client returns an explicit error. |
| `internal/lineup` | Published lineup DTOs; the old reference algorithm is test-only and pinned to the shared golden fixture. |
| `internal/render` | Terminal visual language: ANSI 256 amber/gold, zh/en, honours `NO_COLOR`. |
| `internal/detach` | Background sync for the status line. |

Only the standard library is used. The module requires Go ≥ 1.24.

Statusline defaults to `--harness claude-code`. For Codex, pass `--harness codex` and its exact native model ID. IDs are resolved only through the publication's reviewed, harness-specific mappings; display names and family names are not fallback identities. `未核对型号` / `id not reviewed` means this incoming ID is not reviewed for that harness, even if the model itself is in the catalogue. Sync once after a mapping update; the statusline remains cache-only.

### Qwen Code local usage exports

In Qwen Code, use `/stats export daily 2026-10-22 --format json` or `/stats export monthly 2026-10 --format json`. Then explicitly select that exported file:

```sh
modelplan qwen-usage --export /path/to/qwen-token-usage-day-2026-10-22.json
export MODELPLAN_QWEN_USAGE_EXPORT=/path/to/qwen-exports
modelplan qwen-usage --json
modelplan connections --json
modelplan desktop --read-only --offline
unset MODELPLAN_QWEN_USAGE_EXPORT
```

Off by default. `--export` authorizes one command; `MODELPLAN_QWEN_USAGE_EXPORT` selects a file or directory for `qwen-usage`, connections diagnostics and the desktop snapshot. A directory reads only `qwen-token-usage-*.json` (at most 64 exports, 1 MiB each, no recursion or symlink files). No Qwen command is run, no credentials or conversation files are opened, no host is called, and exports are never rewritten or cached. Diagnostics show the setting and selected path. No account identity is read or stored.

Each calendar day/month has model token totals and the export timestamp. The newest export of the same bucket replaces older copies; day and month buckets stay separate and must not be added together. Missing/invalid token counts remain `null` (`--` in text), including absent cache fields. Exports older than 24 hours are marked stale; their historical counts remain historical, without estimating current use. Input/cache and output/thought buckets retain Qwen's definitions and may overlap. Remaining quota is always unknown; this does not read Qwen Cloud, Alibaba Coding Plan, or Moonshot plans. The existing speed and daily ledgers are unchanged.

Source contract: Qwen's [official stats commands](https://qwenlm.github.io/qwen-code-docs/en/users/features/commands/) and first-party [`TokenUsageSummary` / JSON export](https://github.com/QwenLM/qwen-code/blob/5a0be334326566bec502a0cfcaf35c11557247d3/packages/core/src/services/tokenUsageService.ts). The report's older `~/.qwen/stats/` location is not assumed to have a stable storage schema: use the version's own JSON export. Raw `usage_record.jsonl`, session logs, CSV and unrecognized versions are unsupported. This is original Go code based on that export contract, without copying Qwen or monitor implementation code. Tests use hand-written synthetic exports; real installations/accounts were not accessed.

Qwen Code 本地用量默认关闭。在 Qwen Code 中用 `/stats export daily 2026-10-22 --format json` 或 `/stats export monthly 2026-10 --format json` 导出，再用 `modelplan qwen-usage --export 路径` 单次读取。设置 `MODELPLAN_QWEN_USAGE_EXPORT` 为文件或目录后，命令、连接诊断与桌面快照都会读取；取消该环境变量即可关闭。目录仅读取 `qwen-token-usage-*.json`，不递归，不读取符号链接文件，最多 64 个文件，每个 1 MiB。不运行 Qwen、不读取凭据或会话、不联网、不缓存或改写导出文件，也不读取或存储账号身份。诊断显示设置名称与路径。相同日/月桶仅保留最新导出；日与月不可叠加，超过 24 小时标记过期，历史数据不代表当前用量。缺失字段为 `null`/`--`，不推断剩余额度、速度或云套餐额度。旧版 `~/.qwen/stats/` 和原始日志不直接读取，请使用相应版本的 JSON 导出。

### Gemini CLI local history (opt-in)

Run `modelplan usage gemini enable`, then `modelplan usage gemini [--json]`. `modelplan usage gemini disable` stops reads; `MODELPLAN_GEMINI=off` and `MODELPLAN_HISTORY=off` also stop them. The choice and a random HMAC key are stored only in modelplan's `~/.config/modelplan/local-usage.json` (0600). No Gemini credential, settings, OAuth file or remote quota is read; no Gemini process or network request is started. `modelplan connections` discloses source paths and this boundary.

The source is `~/.gemini/tmp/*/chats/session-*.json` / `.jsonl`, plus legacy `~/.gemini/*/chats/` files; an absolute `MODELPLAN_GEMINI_HOME` overrides the root. Only Gemini message IDs, session/project IDs, timestamps, model names and token counters are selected. Prompts, replies, thoughts text and tool contents are never printed or stored. Session/message references are keyed hashes; raw IDs are never persisted. Antigravity directories and symlinks are excluded. Reads never rewrite a source file, and no token-history cache is created.

Output contains per-day/model rows and opaque session summaries for the last 35 local calendar days, including history predating modelplan setup. Each counter is nullable: missing/invalid output or other fields remain unknown, including aggregate sums containing an unknown field. Input includes cached prompt tokens; cached is a subset, output excludes thoughts, and the provider's total is preserved rather than recomputed. No subscription usage, invoice cost, generation timing or remaining quota is inferred.

JSON snapshots, JSONL full-message records and legacy `$set.messages` checkpoints are supported. Repeated IDs are counted once across resumed/copied histories; within a file, a later token-bearing record replaces its earlier version, and the newest file wins across copies. Conversation edits and rewinds do not refund observed usage. Deleted/cloud-only history is unavailable; future or invalid timestamps are excluded. Incomplete/malformed files are skipped until readable. Coverage says when results are partial: at most 20,000 directory entries, 256 files, 8 MiB per file, 32 MiB read, 50,000 unique messages per invocation. It is a bounded local view, never a complete account total.

`modelplan desktop --json` adds `localUsage[]` and Gemini connection diagnostics. Existing quota, speed and daily-ledger fields retain their meanings; local Gemini accounting is separate. `--read-only` writes nothing. [First-party session management](https://geminicli.com/docs/cli/session-management/) and [record types](https://github.com/google-gemini/gemini-cli/blob/cd1b45c2db0a5ea7b7fc3b67c1ba5879601d6005/packages/core/src/services/chatRecordingTypes.ts) establish the file/schema facts. The reader and synthetic fixtures are independently written, with no imported implementation or new dependency. Remote quota is deferred.
