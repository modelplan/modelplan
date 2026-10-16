# Model Plan Codex 插件

在 Codex 桌面端用紧凑看板比较 GPT 模型和推理档位；Codex CLI 返回相同口径的文字。[English](README.md)

## 安装

需要支持 `codex plugin` 命令的 Codex。运行依赖和字体已经打包，无需 npm 安装、API Key 或 Model Plan 账号。

```sh
codex plugin marketplace add modelplan/modelplan --sparse .agents --sparse codex
codex plugin add modelplan-codex@modelplan
```

1. **添加插件源。** Codex 会克隆本仓库。两个 `--sparse` 路径只检出 marketplace 文件和本插件，约 2 MB，不下载文档和媒体文件。下载过程、进度输出和重试由 Codex 自己控制，网络慢时可能长时间没有输出。失败时重新执行同一条命令即可；成功后再次执行只会提示已添加。若中断留下了不完整的源，先执行 `codex plugin marketplace remove modelplan` 再重新添加。
2. **安装插件。** Codex 把插件复制到它的插件缓存；重复执行会重新安装同一版本。
3. **检查安装**（可选）：在 Codex 里说“检查 Model Plan 插件安装”，或自己运行检查。已安装的版本号可用 `codex plugin list` 查看：

   ```sh
   node ~/.codex/plugins/cache/modelplan/modelplan-codex/<版本>/doctor.cjs --lang zh
   ```

然后输入“打开 Model Plan 看板”。建议在新任务中使用；已打开的任务也可能已经加载插件。也可以调用 `model-dashboard` 技能。支持应用面板的桌面客户端会在对话内显示看板；客户端提供展开能力时可点击“展开”。Codex CLI 显示相同口径的文字比较。面板位置由宿主决定，插件不能把自己固定到侧栏。

### 安装检查

`doctor.cjs` 让 Codex 自己的 app-server 像普通任务一样启动已安装的插件，开一个不发送消息的临时线程（不推理、不计费、不写会话日志），并调用一次只读数据工具。它会报告：

- Codex 是否支持插件命令，插件是否已安装并启用；
- Codex 实际用来运行插件的 Node.js 路径、版本，以及它是怎么找到的；
- MCP 服务是否启动、两个工具是否注册，面板资源能否读取；
- 公开数据是最新发布还是上一份快照；
- 本机额度能否读取、由哪个读取器读取，主动提醒是否启用，未启用时缺什么。

最后分三项给出结论：**安装成功**、**工具可调用**、**面板实际展示**。第三项始终为“未验证”：只有在 Codex 桌面端打开看板才能确认面板确实显示。加 `--json` 输出机器可读结果。

### Node.js

插件服务需要 Node.js 22 或更新版本。Codex 用它 PATH 中的 `node` 启动 `launch.cjs`，这个 Node 只需要能运行启动器（14+）。启动器按以下顺序选用第一个通过版本和功能检查的运行时：

1. `~/.config/modelplan/runtime.json` 中的指定：`{"node": "/path/to/node"}`。Codex 不会把你 shell 里的环境变量传给插件服务，所以指定运行时要用这个文件，而不是环境变量。指定的路径失效时会报告并跳过；
2. Codex 启动启动器所用的 `node`；
3. Codex 桌面端自带的运行时（`~/.cache/codex-runtimes/` 下，仅当该客户端安装过）。它是可选候选，目录结构属于 Codex，插件不假设它一定存在；
4. PATH 中的其他 `node`；
5. 常见位置：macOS 的 Homebrew 和 `/usr/local/bin`，Linux 的 `/usr/local/bin`、`/usr/bin`，Windows 的 Program Files 和 nvm-windows；
6. nvm、fnm、mise、asdf、Volta 安装的版本。

每次启动都会重新选择，不缓存结果，所以升级或删除运行时后，下一个任务会自动重新发现。启动器不会修改 PATH 或全局 Node。全部候选都不可用时，两个工具仍会注册，调用时返回已检查的运行时列表和处理方法。

限制：如果 Codex 的 PATH 中完全没有 `node`，Codex 无法启动启动器，会显示它自己的 MCP 启动错误；请安装 Node.js 22+ 或让 Codex 能找到 `node`。Windows 上覆盖了 Program Files 和 nvm-windows，Codex 桌面端运行时在 Windows 上的位置尚未验证。

### 必需与可选

| 组件 | 用途 | 缺少时 |
| --- | --- | --- |
| 支持 `codex plugin` 命令的 Codex | 全部功能 | 无法安装插件 |
| Node.js 22+（自动查找，见上） | 看板和两个工具 | 工具返回安装诊断 |
| Python 3 | 未安装 `modelplan` CLI 时读取本机额度 | 额度显示为不可用，并说明原因 |
| `modelplan` CLI 0.4+（**可选**） | 主动提醒（`modelplan advise`）和提示钩子；也是首选的额度读取器 | 没有提醒；看板会说明提醒未启用及原因 |

插件已自带两个 Skill：`model-dashboard`（看板、模型与档位比较）和 `model-plan`（结合任务、公开数据和本机额度给建议），不需要再单独安装同一份 Skill。CLI 可用 `curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh` 安装，或从 [Releases](https://github.com/modelplan/modelplan/releases) 下载。

### 更新与卸载

```sh
codex plugin marketplace upgrade modelplan
codex plugin add modelplan-codex@modelplan
```

```sh
codex plugin remove modelplan-codex@modelplan
codex plugin marketplace remove modelplan
```

`plugin remove` 会删除插件缓存。公开数据缓存（`~/Library/Caches/modelplan`、`~/.cache/modelplan` 或 `%LOCALAPPDATA%\modelplan`）与 CLI 共用，两者都不用时可以手动删除。

## 看板内容

- 已发布的 OpenAI 推荐档、高能力优选、最划算和最省配置。
- 原生档位滑杆和能力／成本／耗时小曲线。点击指标单独查看，再点恢复全部；滑杆支持方向键、Home、End。
- 金色 ★ 仅代表推荐档。能力是相对推荐档增减的分数，成本／耗时是倍率。估算标 ≈；缺失或口径不兼容的耗时保持空缺。
- **你的额度**：5 小时和每周窗口的已用比例、距重置时间，以及节奏提示（重置前用不完 → 升档不浪费；偏紧 → 保持 ★）。通过 `modelplan quota` 或插件自带的 Skill 读取器（需要 Python 3，未安装 CLI 时自动回退），在本机读取 Codex 写在会话日志里的额度快照。不上传，不读取凭证。
- **主动提醒**（可选，需要 `modelplan` CLI 0.4+；没有时看板会说明提醒未启用）：重置前额度有富余时提示可以升到哪一档及倍率；偏紧时回到 ★ 或降一档；提醒过的窗口重置后提示切回 ★；最近一天的公开 Codex 重置。插件的 `UserPromptSubmit` 钩子（`hooks/hooks.json`，在 Codex 中信任后生效）把每条新提醒告诉 Codex 一次。只读本地文件，不会切换模型、档位或 Fast。
- 公开 Codex 重置公告，保留来源、范围和时间精度，它们不是你自己的额度读数。

使用与 [Model Plan](https://modelplan.ai/effort) 相同的核验发布数据，不在客户端重新打分、不调用模型推理、不购买套餐、不切换当前会话模型。缓存、读取失败和保留上一份快照的状态会明确显示。模型名单是已评估的 GPT 集合，不是宿主选项的完整清单。

## 开发与内部传输

`mcp.json` 配置内部 stdio 传输，提供 `open_model_dashboard` 和 `get_model_dashboard`；Codex 运行 `launch.cjs`，由它在兼容的 Node 上启动已打包的 `server.bundle.mjs`。界面内嵌样式和字体，不依赖第三方浏览器请求。正常使用仅读取 Model Plan 公开发布端点；本地缓存只存公共数据，不收集遥测或凭证。

```sh
cd codex
npm ci --ignore-scripts
npm test
npm run build
node tests/mcp-smoke.mjs --fresh
node tests/codex-host-smoke.mjs
node doctor.cjs --lang zh
```

最后一项要求已在 Codex 安装同版本；只验证注册、工具和界面资源传输，不创建对话、不运行推理，也不代替原生面板位置验收。`npm start` 可启动本地界面开发预览，不是公开服务。

`lib/client-reader.mjs` 是统一发布校验器的独立副本；源码和运行包同时提供。字体 OFL 授权保留在 `ui/fonts`，运行依赖授权见 `THIRD-PARTY-NOTICES.md`。

MIT，见 [LICENSE](LICENSE)。
