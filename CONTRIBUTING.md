# Contributing to Model Plan

Thanks for helping. [简体中文](#参与贡献)

## Report a data problem

Prices, quotas, efforts, plan rules and news come from Model Plan's publication, not from this repository. If something is wrong, [open a data problem](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml) with the page or command, what you saw, what it should be, and a source (an official page is best). The **Report** links on [modelplan.ai](https://modelplan.ai) fill in the page and the item for you.

## Bugs and ideas

- **Bug:** use the bug template with the client (Skill, CLI, Claude Code plugin, Codex plugin), its version (`modelplan version`, plugin version) and steps to reproduce.
- **Idea:** describe the decision you were trying to make. Model Plan's job is to help choose a model, an effort and a plan; ideas that serve that decision fit best.

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

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE).

---

## 参与贡献

**数据问题**：价格、额度、档位、套餐规则和新闻都来自 Model Plan 的公开发布，不在本仓库里。发现错误请[报告数据问题](https://github.com/modelplan/modelplan/issues/new?template=data-problem.yml)，写明页面或命令、看到的内容、应该是什么，并附来源（官方页面最好）。modelplan.ai 上的「报错」链接会自动填好页面和条目。

**Bug 与想法**：bug 请注明客户端（Skill、命令行、Claude Code 插件、Codex 插件）、版本和复现步骤；想法请说明你当时想做什么决定：用哪个模型、开哪一档、买哪个套餐。

**Pull request**：按上表在本地跑对应检查。客户端不自己排名、只读匿名不上传、从不替用户切换模型或档位、中英文同步更新。提交即表示你同意以 [MIT 许可](LICENSE)发布你的贡献。
