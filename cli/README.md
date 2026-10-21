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

`modelplan history` (`--json`) shows the local quota history: for each window cycle, how much was used by its last reading and how many points each model, effort and Fast setting spent (each rise goes to the configuration of the reading that saw it). It is recorded in `observed/cycles.json` whenever the status line, a plugin hook or `advise` runs, kept 28 days for five-hour cycles and 12 weeks for weekly ones, and never uploaded. `MODELPLAN_HISTORY=off` stops recording; deleting the file clears it. It is the basis for suggesting a default effort from a user's own finished weeks in a later release.

`modelplan desktop` prints the personal snapshot for the desktop app as JSON: each harness session's configuration against ★, the quota accounts, the advice events with their text and menu-bar form, and the measured speed. The format is in [docs/personal-snapshot.md](../docs/personal-snapshot.md).

The same command, and `modelplan effort <model>` for one model, also show **your measured speed** per configuration (model, effort, speed mode) over the last 28 days: output tokens per second of generation, the median time to the first token, and the median turn time and output tokens per turn, each effort against ★ in standard mode (beside the published time multiple) and a speed mode's rate against the same effort in Standard (beside the published speed-up). The CLI reads them from the current Claude Code session's transcript (`transcript_path`, given to the status line and hooks) and the recent Codex rollouts: only timestamps, output token counts, model, effort and speed mode; never prompts, replies, tool input or output; no paths or ids are stored. A figure needs 5 samples. They are kept per day in `observed/speed.json`. Since CLI 0.5.27 the same readings also go into a second ledger, `observed/perf.json` (35 days, counted only from when it was created), behind the desktop snapshot's `perfStats[]` and `daily[]` (see [docs/personal-snapshot.md](../docs/personal-snapshot.md)). `MODELPLAN_HISTORY=off` stops both; deleting a file clears it. While recording is off the logs are not marked as read, so a later run with recording on can still pick up what was written meanwhile, within the usual read limits. `--json` adds `measured[]` (`source`, `model`, `effort`, `speed`, `days`, `requests`, `turns`, `outputTokensPerSecond`, `ttftSeconds`, `turnSeconds`, `turnOutputTokens`).

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
