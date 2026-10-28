# modelplan — Go thin client

`modelplan connect --detected` offers detected tools in a pre-checked list with one
confirmation. `--json` previews without changes. `--privacy automatic|passive`
persists reader privacy; `MODELPLAN_READERS=passive|off` restricts it.
`modelplan disconnect <tool|--all>` revokes permission and deletes cached readings.
[Shared consent](../docs/cli-consent.md).

Audited standard CodexBar access is included in the checked group with Keychain
disabled and `cookieSource: off` in the generated helper config. Browser-session
tools stay in a separate unchecked advanced group;
`connect <tool> --browser-session` explains Safe Storage and the helper's cookie
cache before its own confirmation; only that provider gets `cookieSource: auto`.
Forget also clears that provider's cookie cache. Not-read/token-refresh and
API-key-only helper platforms are not offered.
Every `connect --json` is a preview; connecting starts no reader or refresh.
The config covers the complete effective helper registry and is checked after
normalization; all providers except the granted advanced target keep cookies Off.
A user-set Keychain disable remains in force and leaves cookie cleanup pending.

标准 CodexBar 路径须经审核并关闭钥匙串及 cookie 导入（`cookieSource: off`）；浏览器会话单列为高级未勾选组，
用 `connect <工具> --browser-session` 查看 Safe Storage 和 cookie 缓存说明后单独确认，只有该提供商使用 `cookieSource: auto`。
忘记读数也会按提供商清除 cookie 缓存；所有 `connect --json` 只预览，连接不启动读取器。
配置包含完整有效注册表并核对规范化结果；只有本次高级授权目标可用 Auto，其余均为 Off。
用户的钥匙串禁用设置不会被覆盖；清理受阻时保留待清理标记。

`modelplan connect --detected` 预勾选已检测工具，只确认一次；`--json` 仅预览。
`--privacy automatic|passive` 保存隐私级别，`MODELPLAN_READERS=passive|off` 进一步限制。
`disconnect <工具|--all>` 撤销授权并删除缓存读数。[共享授权](../docs/cli-consent.md)。

`modelplan detect [--json]` checks tool presence from the verified cached catalogue
(built-in fallback before publication support), without credentials, network calls
or tool launches. Detected does not mean signed in. [Detection contract](../docs/cli-detection.md).

`modelplan detect [--json]` 使用已核验的本地目录（尚未发布时使用内置回退）检测工具是否存在；
不读取凭据、不联网、不启动工具。检测到不代表已登录。[检测约定](../docs/cli-detection.md)。

This is a read-only, anonymous, single static binary with no GUI. It reads the verified public publication, keeps the shared local cache (see [`../README.md`](../README.md)) and prints the hangar views in a terminal. The Claude Code and Codex plugins call it (their hooks run `advise --hook`), and the desktop menu-bar app will be built on it later. Install: `curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh` (latest release, checksum-checked, into `~/.local/bin`).

```sh
cd cli
go test -race ./...
go build -o dist/modelplan ./cmd/modelplan

./dist/modelplan sync                 # verify and cache the current publication
./dist/modelplan lineup               # WHICH ENGINE for Anthropic and OpenAI
./dist/modelplan lineup --dev openai --json
./dist/modelplan publication --json --offline  # public recommendations only
./dist/modelplan effort opus          # ladder relative to ★ recommended
echo '{"model":{"id":"claude-opus-5-5"}}' | ./dist/modelplan statusline
./dist/modelplan statusline --harness codex --model gpt-6-astra --no-color
./dist/modelplan doctor
./dist/modelplan quota                # your own windows, read on this machine only
./dist/modelplan advise               # what is worth doing about them now
./dist/modelplan connect --detected         # standard detected tools; explicit consent
echo '{"model":{"id":"claude-opus-5-5"},"rate_limits":{"five_hour":{"used_percentage":39,"resets_at":2000000000}}}' \
  | ./dist/modelplan statusline --preview   # a sample line, nothing recorded
```

### Shareable diagnostics

`modelplan doctor readers [--json]` prints a sanitised verification row for every compiled native quota reader, local-history adapter (`:history`) and Claude session projection (`:session`). It checks presence metadata, production admission and ModelPlan's cache only; it never opens tool credentials or sessions, makes requests, prompts or creates files. `consent` is `granted`, `none` or `denied`; `admitted` is the current production permission, which privacy settings can restrict independently. `windows` counts unexpired quota windows (zero for history/session readers); `last` is the UTC age of the latest cached observation in whole seconds, or `unknown`. Beta flags remain unchanged. Output omits identifiers, paths, hashes, provider text and quota values, and ends with a safe-sharing message.

Use `modelplan doctor readers --refresh [--json]` on your own account to perform one foreground read per admitted provider, within existing request budgets, backoff and a five-minute minimum. This is explicit interactive refresh even with `--json`, so an admitted Keychain reader may prompt. Nothing is uploaded; paste the output back to the coordinator for verification. `--offline` cannot be combined with `--refresh`.

`modelplan doctor readers [--json]` 为每个编译内置的原生额度读取器、本机历史适配器（`:history`）和 Claude 会话投影（`:session`）输出一行脱敏核验结果。仅检查存在性元数据、生产授权与 ModelPlan 缓存，不打开工具凭据或会话，不请求、不提示、不创建文件。`consent` 为 `granted`、`none` 或 `denied`；`admitted` 表示当前生产权限，隐私设置可独立限制它。`windows` 为未过期额度窗口数（历史与会话为零）；`last` 为最新缓存观测距当前的 UTC 整秒数，未知时为 `unknown`。保留原有 beta 标记，不输出个人标识、路径、哈希、提供方文本或额度值，末尾提示可安全分享。

在自己的账号上运行 `modelplan doctor readers --refresh [--json]`，按生产授权为每个已准入提供方执行一次前台读取，遵守现有请求预算、退避和至少五分钟间隔。即使使用 `--json`，这也是显式交互刷新，已授权的钥匙串读取器可能弹窗。不上传任何内容；可将输出粘贴给协调者核验。`--offline` 不能与 `--refresh` 同用。

`modelplan doctor --share [--json]` prints a versioned, sanitised source/status report for an issue. It reads only bounded ModelPlan cache metadata, never starts readers or network requests, and creates no files. It excludes paths, hosts, raw errors, account/session/subscription identifiers, credential values and quota numbers. The report includes the sanitised `MODELPLAN_READERS` mode and keeps distinct cached failure/plan states, including denied, expired login, unsupported, estimated, stale, pay-as-you-go and organisation-managed; multiple accounts can contribute distinct states without exposing their aliases or refs. `cached` describes a local cache envelope, not a fresh provider reading or a live authentication check. Ordinary `doctor` output remains local and can contain paths; use `--share` for material you intend to paste.

`modelplan doctor --share [--json]` 输出可贴到 issue 的版本化、脱敏来源/状态报告。只读取有限大小的 ModelPlan 缓存元数据，不启动读取器、不联网、不创建文件；不输出路径、主机、原始错误、账号/会话/订阅标识、凭据或额度数字。报告包含脱敏后的 `MODELPLAN_READERS` 模式，区分拒绝授权、登录过期、不支持、估算、过期读数、按量计费和组织管理等缓存状态；多个账号的不同状态保留，但不输出别名或引用。`cached` 仅表示本机有缓存封装，不证明实时读数或登录状态。普通 `doctor` 仍可能包含本机路径，要分享时请使用 `--share`。

### Public publication JSON

`modelplan publication --json [--offline]` returns one versioned public-only object:

```json
{
  "schemaVersion": 1,
  "publicationId": "<verified manifest publicationId>",
  "publishedAt": "<manifest timestamp, or null when unknown>",
  "units": {
    "ability": "websiteAbility",
    "cost": "usdPerReferenceTask",
    "time": "taskTimeCrossModel"
  },
  "models": [],
  "lineups": [],
  "speedTiers": []
}
```

The arrays contain the verified client digest's published entries in publication order, without filtering or ranking. `models[]` retains `id`, `name`, `developerId`, `recommended`, `harnessIds` and `efforts[]` (`effort`, `label`, `ability`, `cost`, `time` and published basis metadata). `lineups[]` retains each developer's published `frontier`, members and steps; it is an array, unlike `lineup --json`'s developer-keyed object. `speedTiers[]` retains `harness`, `models[].modelId`, `models[].speed.{ratio,qualifier}`, `billing[]`, eligibility, caveats and sources. Ratios keep their `up-to`, `approximate` or `unstated` qualifier: they describe token generation, never measured speed or task time. Eligibility does not establish a local entitlement. Unknown numeric values and model IDs stay `null`; missing speed tiers yield `[]`. No scores, ratios or rankings are inferred.

The command reads no credentials, account data, quotas, sessions, local configuration or speed/history ledgers, and starts no account readers or background processes. Online it uses the same anonymous publication refresh as `models` and `lineup` (at most once per 10 minutes), retaining a verified last-good cache with a warning on stderr if refresh fails. `--offline` only re-verifies cached publication files: it makes no network requests and creates or changes no files. Missing or invalid cached data produces no JSON, a clear stderr error and exit code 3; `--json` is required (usage errors exit 2).

A native host can pair this object with `modelplan desktop --json --read-only`. Require `schemaVersion: 1`, compatible `units` and an exact match between this `publicationId` and `snapshot.publication.publicationId` before joining their models. Keep views blank on an unavailable or mismatched publication; refresh the personal snapshot after the publication changes. A valid publication can be older when offline or after a failed refresh; its ID and timestamp describe that publication, not the current clock.

`modelplan publication --json [--offline]` 仅返回经过校验的公开推荐：`schemaVersion: 1`、清单中的 `publicationId` / `publishedAt`、`units`、按发布顺序保留的 `models[]`、`lineups[]` 和 `speedTiers[]`。不读取凭据、账号、额度、会话、本地配置或速度/历史账本，不启动账号读取器或后台进程。在线沿用匿名刷新和已校验旧缓存；刷新失败在 stderr 提示。`--offline` 仅重新校验缓存，不联网、不创建或改写文件；无有效缓存时不输出 JSON，stderr 说明原因并退出 3。必须带 `--json`，用法错误退出 2。

未知数值和型号 ID 保留 `null`，缺失速度档位为 `[]`；保留 `up-to` / `approximate` / `unstated` 限定，不将生成速度当作任务时间或实测保证，也不把适用套餐当作本地权益。客户端不补分数、不推算排名。与个人快照拼接前，必须检查版本、单位，以及 `publicationId` 与 `snapshot.publication.publicationId` 完全一致；缺失或不匹配时保持空白，公开发布更新后应重新获取个人快照。

`advise` events: a window used up, tight (also early: half used and on pace to run out; or a recent burst that runs it out within three hours, with the time), reset soon with allowance left, an announced Codex reset, switch back after a reset (to the configuration in use before the hint, and Codex Fast off if it was turned on since), peak and off-peak rates, expiring cards and public resets. A tight window suggests a lower effort and, when there is one, a cheaper published model that scores at least as high (`alternative`). Multiples (×) are the published API cost of a reference task: they track plan usage roughly within one model and are only a guide across models.

`modelplan history` (`--json`) shows the local quota history: for each window cycle, how much was used by its last reading and how many points each model, effort and Fast setting spent (each rise goes to the configuration of the reading that saw it). It is recorded in `observed/cycles.json` whenever the status line, a plugin hook or `advise` runs, kept 28 days for five-hour cycles and 12 weeks for weekly ones, and never uploaded. Since CLI 0.5.27 the same readings also go into `observed/pace.json`, which keeps every counted reading, its gaps and drops, for the desktop snapshot's `paceHistory` (see [docs/personal-snapshot.md](../docs/personal-snapshot.md)). `MODELPLAN_HISTORY=off` stops both; deleting a file clears it. After three comparable finished weeks, text history, the Claude Code status line and the hooks' user message share at most one local default-effort suggestion per seven days, with an adjacent published effort and reference-cost ratio; JSON history stays a raw measurement feed. See [local effort suggestions](../docs/effort-suggestion.md) for thresholds, caveats and dismiss/off/on controls.

三个可比较的周周期结束后，历史文本、Claude Code 状态栏和钩子的用户提示共享每七天最多一次的本机默认档位建议，显示相邻公开档位及参考成本比；历史 JSON 保持原始记录格式。阈值、归因限制和 dismiss/off/on 控制见[本机档位建议](../docs/effort-suggestion.md)。

`modelplan desktop` prints the personal snapshot for the desktop app as JSON: each harness session's configuration against ★, the quota accounts, the advice events with their text and menu-bar form, and the measured speed. The format is in [docs/personal-snapshot.md](../docs/personal-snapshot.md). Its project ranking names projects by their folder (not their path) unless you turn that off: `modelplan project-labels off` deletes the stored names and keeps only opaque references, and the choice is kept. The names stay on this machine.

The same command, and `modelplan effort <model>` for one model, also show **your measured speed** per configuration (model, effort, speed mode) over the last 28 days: output tokens per second of generation, the median time to the first token, and the median turn time and output tokens per turn, each effort against ★ in standard mode (beside the published time multiple) and a speed mode's rate against the same effort in Standard (beside the published speed-up). The CLI reads them from the current Claude Code session's transcript (`transcript_path`, given to the status line and hooks) and the recent Codex rollouts: only timestamps, output token counts, model, effort and speed mode; never prompts, replies, tool input or output; no paths or ids are stored. A figure needs 5 samples. They are kept per day in `observed/speed.json`. Since CLI 0.5.27 the same readings also go into a second ledger, `observed/perf.json` (35 days, counted only from when it was created), behind the desktop snapshot's `perfStats[]` and `daily[]` (see [docs/personal-snapshot.md](../docs/personal-snapshot.md)). Since CLI 0.5.32 its days are also rolled up per day, source and model into `observed/daily-long.json` (371 days, below 1 MiB; only days, model names, output tokens and requests), behind `dailyLong[]`. `MODELPLAN_HISTORY=off` stops all three; deleting a file clears it. While recording is off the logs are not marked as read, so a later run with recording on can still pick up what was written meanwhile, within the usual read limits. `--json` adds `measured[]` (`source`, `model`, `effort`, `speed`, `days`, `requests`, `turns`, `outputTokensPerSecond`, `ttftSeconds`, `turnSeconds`, `turnOutputTokens`).

### Kimi Code plan-key quota

`modelplan connect kimi --region china` (default) or `--region international` opts into the undocumented compatibility `GET /coding/v1/usages` endpoint on `api.kimi.com` or `api.kimi.ai`. Only `KIMI_CODE_API_KEY` (or `--key-env NAME`) is read; no credential files, OAuth, cookies, inference or Moonshot balance. Connections disclose the variable/host and undocumented status; a missing key keeps quota unknown and sends nothing. The key is never printed or stored. Disconnect or `MODELPLAN_NATIVE=off` stops reads. Native cache/backoff and keyed-hash regional bindings apply. [Contract, privacy, limits and MIT source references](../docs/kimi-code-quota.md).

`modelplan connect kimi --region china` 或 `--region international` 显式启用未公开文档的兼容额度端点，分别仅调用 `api.kimi.com` / `api.kimi.ai`。只读取 `KIMI_CODE_API_KEY` 或 `--key-env NAME` 指定的环境变量，诊断披露变量名、主机与文档状态；未设置 key 不发送请求，额度保持未知。不读取凭据/OAuth/浏览器，不调用推理或 Moonshot 余额，key 不打印、不落盘。沿用原生缓存、退避和按地区区分的带密钥哈希身份。[详情](../docs/kimi-code-quota.md)。

### Other plans through CodexBar

`modelplan connect --detected` offers audited standard helper routes alongside native readers. Browser-session routes require `modelplan connect <tool> --browser-session` and their separate explanation/confirmation. Head providers use native readers with no automatic helper fallback. An unaudited, unknown-access or not-read route remains unsupported.

- **Consent and access class.** Helper use requires the current catalogue audit/class and the shared grant. Standard runs force `CODEXBAR_DISABLE_KEYCHAIN_ACCESS=1`; browser access is off until its explicit per-provider grant. Legacy `codexbar enable` settings alone cannot bypass these gates. `MODELPLAN_CODEXBAR=off` stops usage reads.
- **Credential handling.** ModelPlan reads only the helper's sanitised JSON. Standard helpers use their audited local login/read-only CLI route without refresh. Advanced browser routes may ask for Safe Storage and cache a session cookie in CodexBar's own Keychain item; Forget runs provider-scoped cookie cleanup. No browser discovery runs during detection or connect.
- **Pinned release.** The first run downloads the CodexBar CLI release pinned in `internal/quota/codexbar-pin.json`: about 14 MB on macOS and 53 MB on Linux. It is checked against the pinned SHA-256 and kept under the cache's `codexbar/` directory. `MODELPLAN_CODEXBAR=<path>` uses another copy, and one the user installed is used when there is no pinned copy. The `codexbar-pin` workflow proposes newer releases weekly, after a live check that their JSON still parses.
- **Runs in the background.** At most every 10 minutes (30 after every provider failed), one provider per call, with a 60 s limit each and English output. The cached reading (`observed/codexbar.json`) holds windows, reset times and the plan name only. Identities, account ids and error text naming local paths or addresses are dropped.
- **Shown, not hinted.** `quota` and the dashboards show these plans. They give no prompt hints in Claude Code or Codex, which do not draw on them.
- **Estimates are not quota.** CodexBar's OpenCode Go estimate from local history uses fixed denominators, so it is reported as `estimated` and not shown as a quota.

`advise --hook claude-code|codex` is the plugins' prompt hook: it reads the hook input from stdin and shows new hints to the user once (the hook's `systemMessage`; they never reach the model). The model gets a task-start brief with the published options on a thread's first prompt, and one line with the ladder of a model the thread was not briefed on. It also gets one factual line when the harness's own 5-hour or weekly remaining quota falls below 15%, and one when that window has reset and a fresh reading shows more than 50% remaining after being below 15% in this thread. Each low/reset line is sent at most once per window per thread, in `--lang` / `MODELPLAN_LANG` (English or Chinese), with the remaining percentage and time to reset: `Weekly quota: 12% left, resets in 3d4h.` No advice accompanies these lines. Unknown or stale readings never trigger them, and they only read local cached quota; they never wait on the network. Their per-thread state lives beside the brief state in `observed/advice.json`, with the same eight-day expiry and cleanup. The hook never fails the prompt; with no publication cached yet its existing brief sync waits up to 3.5 s, then goes on in the background. `MODELPLAN_TASK_BRIEF=off` turns off both the brief and these quota lines.

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

### Copilot monthly premium requests (opt-in)

`modelplan connect copilot` selects the native reader; `modelplan disconnect copilot` turns it off. The installed `copilot` executable is resolved on PATH, or by the absolute path in `MODELPLAN_COPILOT`. It runs `--headless --no-auto-update --stdio`, negotiates protocol 3 and calls server-scoped `account.getQuota` with empty parameters. It reuses Copilot-managed authentication, starts no session or inference, reads no credential file itself, and collects no identity. Credentials are never printed or stored by modelplan. Copilot itself owns its GitHub requests (normally `api.github.com`, with enterprise host selection owned by the runtime); modelplan makes no direct vendor HTTP request. `modelplan connections` / desktop connection diagnostics include this boundary.

Only `premium_interactions` becomes a monthly window. JSON adds `windows[].requests` with nullable `used` / `limit`, `unlimited` and an optional reason; text shows the counts. No entitlement is guessed from a plan name, missing fields, zero limits or unlimited entitlements. Counts expire at the supplied reset. Sanitized quota follows the existing 10-minute native cache, 30-minute error retry and 6-hour cache ceiling. `MODELPLAN_NATIVE=off` stops it. If the runtime is absent, signed out or incompatible, the reason points to the explicit compatibility fallback: `modelplan connect copilot --backend codexbar`. No bridge is silently enabled and modelplan never harvests GitHub tokens.

Wire/schema reference: [official Copilot SDK usage and billing](https://github.com/github/copilot-sdk/blob/538675843887643ce471c874a3a9870ebda3f6f4/docs/features/usage-and-billing.md). The wrapper and fixtures are independently written; no external implementation or new dependency is included. Live account acceptance and enterprise host behavior are unverified.


## Explicit standalone CLI updates

`modelplan update [--json]` updates only standalone or Skill-installed copies. Plugin cache copies (including symlinks) and App bundles are refused before any network/cache work; update those through their owner. No other command updates the executable.

The command refreshes/verifies the publication (with a last-verified-cache fallback on network failure), reads `client.data.cli.latest` and `cli.sha256["os/arch"]` from FEEDFIX's catalogue design, and downloads that exact release archive from GitHub Releases. It never asks GitHub for “latest”, accepts a download URL from metadata or guesses a missing platform checksum. Until the publication carries a supported pin, it reports unavailable and leaves the binary alone. Older/equal pins do not downgrade a newer CLI.

The archive must match its SHA-256 before bounded tar/ZIP extraction. Invalid checksums, unsafe archive entries, truncation, cancellation and failed staging keep the current executable. A successful replacement keeps the previous binary at `<executable>.previous`. A per-executable lock prevents overlapping updates; the updater never deletes the verified catalogue or reader/helper caches. Publication/download HTTP honors the App-supplied proxy environment. `--offline` refuses without network or executable changes.

`modelplan update [--json]` 只更新独立或 Skill 安装的副本；插件缓存（包括符号链接）和 App 包内的副本在联网/访问缓存前拒绝，请通过其管理方更新。其他命令绝不更新可执行文件。仅从已校验发布中的 `cli.latest` 和按 `os/arch` 索引的 SHA-256 选择准确版本，不查 GitHub 的 latest API、不接受元数据 URL、不猜缺失校验值；发布尚无该字段时明确报告不可用。校验、归档、取消或暂存失败保留现有文件，成功后在 `.previous` 保留上一个副本，不删除已校验目录/读取器缓存。HTTP 继承 App 传入的代理；离线模式不更新。

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

### Qwen Code local history (opt-in)

Run `modelplan usage qwen enable`, then `modelplan usage qwen [--json]`. Once enabled, existing local session history is read automatically. `modelplan usage qwen disable`, `MODELPLAN_QWEN=off` or `MODELPLAN_HISTORY=off` stops it. An absolute `MODELPLAN_QWEN_HOME` selects a different history root. No export step or cloud plan login is needed.

This reuses the [Gemini reader in PR #121](https://github.com/modelplan/modelplan/pull/121): one consent/HMAC store (`~/.config/modelplan/local-usage.json`), bounded discovery, safe file reads, message deduplication, unknown-preserving sums, local-day/model history, opaque session references and partial-coverage reporting. Gemini and Qwen opt-ins are independent. No Qwen executable, credentials/settings/OAuth files or network host are accessed. Prompts, replies, thoughts text, tool payloads and raw identifiers never enter output or storage. Only modelplan's own consent/HMAC file is written; source files and local history are never rewritten or cached.

Current Qwen writes `~/.qwen/projects/<project>/chats/<sessionId>.jsonl` records with `uuid`, `type: assistant`, `usageMetadata` and model/timestamp metadata. The reader also accepts Gemini-style Qwen snapshots/JSONL under `~/.qwen/tmp/*/chats/` and legacy `~/.qwen/*/chats/`. Reads stay within direct `chats` files (`*.jsonl`, legacy `session-*.json`), without arbitrary recursive scanning. Symlinks are refused. Limits match Gemini: 35 local days, 20,000 directory entries, 256 files, 8 MiB/file, 32 MiB read and 50,000 unique messages. Deleted/cloud-only/subdirectory histories cannot be reconstructed; incomplete/unsupported files produce partial coverage.

Native prompt/cached and candidate/thought counters retain their meanings and may overlap: do not add them. Missing/invalid counters and sums containing them stay `null` / `--`, including absent cache/thought fields. Copied/forked UUIDs count once; session totals, user/tool records, edits and rewinds do not invent extra usage or refunds. No remaining quota, subscription debit, API-price cost or generation speed is inferred. Connections disclose exact patterns, privacy and an empty host list. Desktop schema v1 adds Qwen to #121's `localUsage[]`; quota, speed and daily-ledger fields retain their meanings.

First-party source reviewed (Apache-2.0): [ChatRecord and recordAssistantTurn](https://github.com/QwenLM/qwen-code/blob/5a0be334326566bec502a0cfcaf35c11557247d3/packages/core/src/services/chatRecordingService.ts), [Storage.getProjectDir](https://github.com/QwenLM/qwen-code/blob/5a0be334326566bec502a0cfcaf35c11557247d3/packages/core/src/config/storage.ts). The implementation and fixtures are original Go/handwritten JSON; no Qwen code was copied. The record service's older tmp-path comment is superseded by its actual `getProjectDir()` call; the reader supports both layouts. Live installations and future schemas remain unverified.

Qwen Code 默认关闭。`modelplan usage qwen enable` 后自动读取本机已有聊天记录，`modelplan usage qwen --json` 查看；`disable`、`MODELPLAN_QWEN=off` 或 `MODELPLAN_HISTORY=off` 停止读取。可用绝对路径 `MODELPLAN_QWEN_HOME` 指定记录根目录，不需要手动导出或云账号。与 Gemini 共用 #121 的同意设置、带密钥哈希身份、安全扫描、去重、可空求和和时间/模型汇总，但独立启用。读取 `.qwen/projects/*/chats/*.jsonl` 及旧版 tmp/根目录布局，保留原生 token 定义，不叠加重叠计数。缺失为 `null`/`--`；只统计有界本机历史，不推断额度、费用或速度。凭据/设置/OAuth 不读取，不运行 Qwen 或联网；提问、回复、思考正文、工具内容与原始标识不输出或存储，不改写源文件。桌面仅新增 `localUsage` 的 Qwen 条目，不改变原有额度或速度字段。

#### Optional JSON exports

The existing `modelplan qwen-usage --export PATH` and `MODELPLAN_QWEN_USAGE_EXPORT` remain an independent optional view for Qwen's own aggregated JSON exports (`/stats export daily|monthly --format json`). A directory reads only `qwen-token-usage-*.json`, at most 64 files of 1 MiB each. It never enables session reads, calls a host, rewrites exports or merges them into session accounting. Re-exporting replaces the same calendar bucket; overlapping day/month exports stay separate. `qwenUsage` remains an optional snapshot field for this view only. Unset the variable to stop it. [Export contract](https://github.com/QwenLM/qwen-code/blob/5a0be334326566bec502a0cfcaf35c11557247d3/packages/core/src/services/tokenUsageService.ts).

原有 `qwen-usage --export PATH` 和 `MODELPLAN_QWEN_USAGE_EXPORT` 仅作为可选聚合导出视图保留，不是自动读取所必需，不会启用会话读取或把导出与会话重复相加。取消环境变量即可停止；可选快照字段 `qwenUsage` 仍只表示导出。

### Gemini CLI local history (opt-in)

Run `modelplan usage gemini enable`, then `modelplan usage gemini [--json]`. `modelplan usage gemini disable` stops reads; `MODELPLAN_GEMINI=off` and `MODELPLAN_HISTORY=off` also stop them. The choice and a random HMAC key are stored only in modelplan's `~/.config/modelplan/local-usage.json` (0600). No Gemini credential, settings, OAuth file or remote quota is read; no Gemini process or network request is started. `modelplan connections` discloses source paths and this boundary.

The source is `~/.gemini/tmp/*/chats/session-*.json` / `.jsonl`, plus legacy `~/.gemini/*/chats/` files; an absolute `MODELPLAN_GEMINI_HOME` overrides the root. Only Gemini message IDs, session/project IDs, timestamps, model names and token counters are selected. Prompts, replies, thoughts text and tool contents are never printed or stored. Session/message references are keyed hashes; raw IDs are never persisted. Antigravity directories and symlinks are excluded. Reads never rewrite a source file, and no token-history cache is created.

Output contains per-day/model rows and opaque session summaries for the last 35 local calendar days, including history predating modelplan setup. Each counter is nullable: missing/invalid output or other fields remain unknown, including aggregate sums containing an unknown field. Input includes cached prompt tokens; cached is a subset, output excludes thoughts, and the provider's total is preserved rather than recomputed. No subscription usage, invoice cost, generation timing or remaining quota is inferred.

JSON snapshots, JSONL full-message records and legacy `$set.messages` checkpoints are supported. Repeated IDs are counted once across resumed/copied histories; within a file, a later token-bearing record replaces its earlier version, and the newest file wins across copies. Conversation edits and rewinds do not refund observed usage. Deleted/cloud-only history is unavailable; future or invalid timestamps are excluded. Incomplete/malformed files are skipped until readable. Coverage says when results are partial: at most 20,000 directory entries, 256 files, 8 MiB per file, 32 MiB read, 50,000 unique messages per invocation. It is a bounded local view, never a complete account total.

`modelplan desktop --json` adds `localUsage[]` and Gemini connection diagnostics. Existing quota, speed and daily-ledger fields retain their meanings; local Gemini accounting is separate. `--read-only` writes nothing. [First-party session management](https://geminicli.com/docs/cli/session-management/) and [record types](https://github.com/google-gemini/gemini-cli/blob/cd1b45c2db0a5ea7b7fc3b67c1ba5879601d6005/packages/core/src/services/chatRecordingTypes.ts) establish the file/schema facts. The reader and synthetic fixtures are independently written, with no imported implementation or new dependency. Remote quota is deferred.

## Cursor native quota (opt-in) / Cursor 原生额度（可选）

`modelplan connect cursor` uses the editor SQLite sign-in read-only and private Cursor dashboard JSON. No refresh, copy, credential persistence, browser/keychain access or automatic backend fallback. Unsupported or expired credentials keep quota unknown. `modelplan connect cursor --backend codexbar` selects the existing bridge explicitly. [Paths, endpoints, privacy and limits](../docs/cursor-native-quota.md).

`modelplan connect cursor` 只读编辑器 SQLite 登录状态，访问未公开仪表盘接口，不刷新、复制或保存凭据，不读取浏览器和钥匙串。不支持或过期时额度未知；`--backend codexbar` 显式选择已有桥接。[路径、接口与限制](../docs/cursor-native-quota.md)。

## MiniMax plan quota (opt-in) / MiniMax 套餐额度（可选）

`modelplan connect minimax` reads only `MINIMAX_CODING_API_KEY` (or `--key-env NAME`). `--region international` (default) uses `api.minimax.io`; `--region china` uses `api.minimaxi.com`. Current Token Plan JSON is primary, with legacy JSON fallback on the same host for endpoint/auth rejection. No cross-region probing, browser/config/token-file reads, refresh, credential storage, balance or inference. Missing entitlement and unsupported values stay unknown. Connections/desktop disclose the selected variable, host and documentation status. [Method, privacy and limitations](../docs/minimax-quota.md).

`modelplan connect minimax` 仅读取 `MINIMAX_CODING_API_KEY` 或 `--key-env NAME` 指定变量。`--region international`（默认）/ `china` 分别调用国际/国内 API 主机，不跨地区尝试。优先读取 Token Plan JSON，仅在端点或授权拒绝时回退同主机旧接口。不读取浏览器或凭据文件，不刷新或保存 key，不调用余额、推理接口。缺失权益或无效值保持未知；诊断披露变量、主机及文档状态。[详情](../docs/minimax-quota.md)。

## Plugin installation for App Settings

`modelplan plugin install claude-code|codex [--json]` runs the documented marketplace-add and plugin-install commands through the host CLI when `claude` or `codex` is on PATH. It uses fixed argument arrays without a shell, inherits the App-provided environment (including proxy settings), and stops if a step fails. The App obtains its one confirmation before invoking this explicit installation command. No quota readers, consent records or publication cache are touched.

When the host CLI is unavailable, it prints the commands and documentation link instead. `--offline` always prints a plan without executing anything; `--json` returns a versioned result (`installed`, `instructions`, `planned` or `failed`), routing host output to stderr so stdout remains valid JSON.

`modelplan plugin install claude-code|codex [--json]` 在 PATH 中存在 `claude` 或 `codex` 时，通过宿主 CLI 运行文档中的市场添加和插件安装命令。使用固定参数数组、不经过 shell，继承 App 传入的环境和代理；某一步失败就停止。App 在调用这个显式命令之前取得一次确认。不触碰额度读取器、授权记录或发布缓存。没有宿主 CLI 时打印命令和文档链接；`--offline` 只打印计划，`--json` 返回版本化结果，宿主输出转到 stderr，保持 stdout 为有效 JSON。
