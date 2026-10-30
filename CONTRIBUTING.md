# Contributing to ModelPlan

Thanks for helping. [简体中文](#参与贡献)

## Report a data problem

Prices, quotas, efforts, plan rules and news come from ModelPlan's publication. Its reviewed data is mirrored in [`data/`](data/) (one pull request per change, so the history shows what changed and when), but it is edited upstream: a pull request that edits `data/` cannot be merged, and the next sync would overwrite it. If something is wrong, [open a data problem](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml) with the page or command, what you saw, what it should be, and a source (an official page is best). The **Report** links on [modelplan.ai](https://modelplan.ai) fill in the page and the item for you.

## Bugs and ideas

- **Bug:** use the bug template with the client (Skill, CLI, Claude Code plugin, Codex plugin), its version (`modelplan version`, plugin version) and steps to reproduce.
- **Idea:** describe the decision you were trying to make. ModelPlan's job is to help choose a model, an effort and a plan; ideas that serve that decision fit best.

## Pull requests

The clients live here:

| Directory | Stack | Check locally |
| --- | --- | --- |
| `cli/` | Go 1.24 | `cd cli && go vet ./... && go test ./...` |
| `codex/` | Node.js 22+ (CI runs 22 and 24) | `cd codex && npm ci --ignore-scripts && npm test && npm run build` (commit the rebuilt `server.bundle.mjs`) |
| `skills/model-plan/` | Markdown, Python 3.12 evals | `python -m unittest discover -s skills/model-plan/evals -p 'test_*.py'`; then `node scripts/package-skill.mjs` copies the Skill into both plugins (`--check` in CI) |
| `claude-code/` | plugin manifest, commands, hooks | edit the Skill in `skills/model-plan/`, not the plugin copy |

Ground rules:

- Clients never rank on their own. Numbers, verdicts and multipliers come from the publication; a client only selects and displays them.
- Read-only and anonymous: no accounts, no telemetry, no uploads. Quota stays on the user's machine.
- Never switch the user's model or effort; advise only.
- Keep English and Chinese text in step (READMEs, Skill answers, CLI strings).
- Small, focused PRs with a clear description. CI must be green.

### Reader and release regression checks

CI runs the reader reason conformance tables without the test cache. They inject
synthetic runtime/vendor errors and check returned entries, retained files,
connection diagnostics, logs and JSON. New native readers need an error fixture;
fixed reason codes must survive failure and retained-read paths.

From `cli/`, run `go test -count=1 ./internal/quota ./internal/connections ./cmd/modelplan -run 'Test(ReaderReason|NativeConnectionReasons|.*ErrorOutput|RuntimeErrorsStayOutOfCLIJSONAndLogs)'`
and `go run ./internal/releaseguard/cmd --root ..`.
The release scan covers Swift, Go, Objective-C and cgo under `desktop/native` and
`clients/swift`. Private selectors/KVC require `MODELPLAN_TEST_ONLY_SPI` to exclude
the code from release; `DEBUG`, test directory names and `flag || platform` are
not exceptions. This literal-source guard does not resolve computed selectors.

### Releasing

The plugins bring their own CLI: each pins one release in `cli-pin.json` (version and per-platform SHA-256) and fetches it with `hooks/fetch-cli.sh`. So a CLI change ships in two steps:

1. Merge the CLI change and push the tag `vX.Y.Z` on the merge commit; the release workflow builds the archives and `checksums.txt`.
2. Run `node scripts/pin-cli.mjs vX.Y.Z` (writes both plugins' `cli-pin.json`), bump both plugin versions, open a PR. CI runs `node scripts/pin-cli.mjs --check` against the published release.

The CLI itself pins the CodexBar CLI release that `modelplan codexbar` fetches, in `cli/internal/quota/codexbar-pin.json`. The weekly `codexbar-pin` workflow runs `node scripts/pin-codexbar.mjs --latest` and the live contract test, then opens a PR. Close and reopen that PR to run CI; a new pin ships with the next CLI release.

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE). The official visuals in `desktop/official-visuals/` are the exception: they are under their own [license](desktop/official-visuals/LICENSE.md), and outside changes to them need a separate written agreement.

---

## 参与贡献

**数据问题**：价格、额度、档位、套餐规则和新闻都来自 ModelPlan 的公开发布。审核过的数据镜像在 [`data/`](data/)（每次变化一个 PR，历史里能看到改了什么、何时改的），但编辑在上游进行：直接修改 `data/` 的 PR 无法合并，下次同步也会覆盖。发现错误请[报告数据问题](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml)，写明页面或命令、看到的内容、应该是什么，并附来源（官方页面最好）。modelplan.ai 上的「报错」链接会自动填好页面和条目。

**Bug 与想法**：bug 请注明客户端（Skill、命令行、Claude Code 插件、Codex 插件）、版本和复现步骤；想法请说明你当时想做什么决定：用哪个模型、开哪一档、买哪个套餐。

**发版**：插件自带 CLI，各自在 `cli-pin.json` 里锁定一个版本和各平台的 SHA-256。所以 CLI 的改动分两步发：先合并并在合并提交上打 `vX.Y.Z` 标签，等发版流程生成程序包和 `checksums.txt`；再运行 `node scripts/pin-cli.mjs vX.Y.Z` 写入两个插件的 `cli-pin.json`，升两个插件的版本号并开 PR，CI 会用 `node scripts/pin-cli.mjs --check` 对照已发布的版本核验。CLI 自己锁定 `modelplan codexbar` 下载的 CodexBar CLI 版本，写在 `cli/internal/quota/codexbar-pin.json`。每周的 `codexbar-pin` 流程会运行 `node scripts/pin-codexbar.mjs --latest` 和实时格式检查，再开 PR；关闭并重新打开这个 PR 才会跑 CI，新锁定的版本随下一次 CLI 发版生效。

**Pull request**：按上表在本地跑对应检查。客户端不自己排名、只读匿名不上传、从不替用户切换模型或档位、中英文同步更新。提交即表示你同意以 [MIT 许可](LICENSE)发布你的贡献。`desktop/official-visuals/` 里的官方视觉例外：它有自己的[许可](desktop/official-visuals/LICENSE.md)，外部修改需要另签书面协议。
