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

然后输入“打开 Model Plan 看板”。建议在新任务中使用；已打开的任务也可能已经加载插件。也可以调用 `model-dashboard` 技能。在对话里请求时，看板以紧凑卡片显示在对话内。想让它常驻在聊天右侧，请在对话的侧边面板中打开 **Effort & quota**：这个入口由你手动打开，工具调用打不开它，每个对话各有一份。侧栏中的 **Model Plan** 会单独打开看板。Codex CLI 显示相同口径的文字比较。

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
| Python 3 | 插件配套的 CLI 就绪前读取本机额度 | 额度显示为不可用，并说明原因 |
| 插件配套的 `modelplan` CLI（**自动下载**） | 主动提醒（`modelplan advise`）、提示钩子、Codex 账号读数；也是首选的额度读取器 | 下载好之前没有提醒；看板会说明原因 |

**插件配套的 CLI。** 插件在 `cli-pin.json` 里锁定一个 `modelplan` CLI 版本，写明它的版本号和各个 macOS、Linux 程序包的 SHA-256。Codex 启动插件时，插件的服务会在后台从 GitHub 下载这个版本，放到 `~/.cache/modelplan-cli/<版本>`，只有校验值和插件里写的完全一致才使用。所以安装或升级插件就够了，不需要另外安装或升级 CLI。不改其他任何东西：不改 PATH、配置文件，也不用 sudo；你自己装的 `modelplan`（给终端用的）保持不动，只在配套的那份还没下载好时临时使用。`MODELPLAN_PLUGIN_CLI=off` 可关闭自动下载。Windows 不自动下载，请从 [Releases](https://github.com/modelplan/modelplan/releases) 下载 `modelplan` 放到 PATH 中。

**开启主动提醒。** 主动提醒需要插件配套的 CLI，以及插件唯一的钩子（Codex 只在你允许后运行）。看板的 NOW 面板只列出没就绪的部分，每项一行：CLI 正在下载、下载失败（附原因和 **重试**），或者暂时在用你自己装的旧版本；钩子在本机还没运行过；钩子定义变了、新定义还没运行（Codex 会跳过有变化的钩子，直到你重新审核；正在进行的对话里没有提示）；或者上一次运行没能算出提醒（附退出码、错误和最近一次成功时间）。插件看不到钩子是否已授权，所以面板只说钩子最近一次在本机（任一对话）什么时候运行、结果如何，不会写“已授权”。全部正常时只显示一行：设置完整、提醒计算正常，以及当前有没有要提醒的事。也可以直接让 Codex “检查 ModelPlan 设置”（`setup` 技能）。

**关于这个钩子。** Codex 的钩子审核里它显示为 `UserPromptSubmit · Hook 1`，来源 `Plugin - modelplan-codex@modelplan`，命令 `sh "$PLUGIN_ROOT/hooks/modelplan-quota-hints.sh"`，超时 5 秒；Codex 0.157 不显示别的名称（`statusMessage` 只在运行时显示）。每次提交提示时，有新的额度提醒就显示给你（钩子的提示消息，不进 Codex 的上下文）；对话的第一条提示给 Codex 一份任务开始简报（`modelplan advise --hook codex`）。配套的 CLI 还没下载好时它什么都不说；如果下载失败，会说明原因，每周最多一次；CLI 第一次就绪时说一声。钩子本身不下载任何东西（由插件的服务下载），只写 `~/.cache/modelplan-codex`，也不改任何设置。允许方法：桌面端点输入框旁带黄点的钩子图标，确认来源是 `modelplan-codex` 后允许；CLI 里用 `/hooks`。从下一条提示开始生效，正在进行的对话也一样。提醒只随提示到达：一轮很长的任务进行中不会有新提醒，要等你的下一条消息；插件不声称持续监控。

插件已自带三个 Skill：`model-dashboard`（看板、模型与档位比较）、`model-plan`（结合任务、公开数据和本机额度给建议）和 `setup`（首次检查），不需要再单独安装同一份 Skill。想在终端里用 CLI，仍可用 `curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh` 自己安装；插件不需要它。

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

无论在哪里显示，内容宽度都不超过 420px（含边框和内边距），高度随内容变化。在对话内，卡片向宿主申请自身宽度，而不是整个聊天栏的宽度；在聊天右侧，它在窄面板内最多占满这个宽度。宿主总是以“fullscreen”显示入口，在侧边面板里这只表示占满面板，所以宽度不随显示模式变化。对话内卡片上的“展开”会请求宿主的大视图，同时展开曲线和模型榜。“数据与依据”末尾的**显示**一行列出所在位置、宿主报告的显示模式和容器尺寸，以及实际测得的宽度；反馈布局问题时请附上这一行。首屏依次显示：最近本机会话的 Codex 模型、档位和速度模式，相对 ★ 的倍率，以及你的额度；其下是比较台。档位曲线、全部模型和公开重置公告默认折叠，按需展开。


- 已发布的 OpenAI 推荐档、高能力优选、最划算和最省配置。
- 原生档位滑杆和能力／成本／耗时小曲线。点击指标单独查看，再点恢复全部；滑杆支持方向键、Home、End。
- 金色 ★ 仅代表推荐档。能力是相对推荐档增减的分数，成本／耗时是倍率。估算标 ≈；缺失或口径不兼容的耗时保持空缺。
- **你的额度**：5 小时和每周窗口的已用比例、距重置时间，以及节奏提示（重置前用不完 → 升档不浪费；偏紧 → 保持 ★）。通过 `modelplan quota` 或插件自带的 Skill 读取器（需要 Python 3，未安装 CLI 时自动回退），在本机读取 Codex 写在会话日志里的额度快照。装了 CLI（0.5.2+）时，还会在后台向 Codex 本身查询（`codex app-server` 的 `account/rateLimits/read`，最多每 5 分钟一次）账号当前的窗口和完整重置次数及到期时间；请求由 Codex 用它自己的登录发出，缓存里不保存账号或重置次数的 ID。兑换重置次数仍由你在 Codex 中自己操作。设置 `MODELPLAN_CODEX_ACCOUNT=off` 可只读日志。不上传，不读取凭证。
- **主动提醒**（需要插件自动下载的配套 CLI 和已允许的钩子；没就绪时看板会说明原因）：重置前额度有富余时提示可以升到哪一档及倍率；偏紧时（包括最近用得猛、3 小时内就会用完，会显示大约多久用完）回到 ★ 或降一档（开着 Fast 时先建议关掉 Fast）；提醒过的窗口重置后，提示换回提醒前用的模型和档位，之后开了 Fast 的也提醒关掉；最近一天的公开 Codex 重置。插件的 `UserPromptSubmit` 钩子（`hooks/hooks.json`，在 Codex 中信任后生效）把每条新提醒显示给你一次，不放进 Codex 的上下文；每个对话的第一条消息，它交给 Codex 一份简短的**任务开始简报**：Codex 可用模型在 ★ 档的能力与成本倍率（被更好选项压过的不列）、当前模型的档位阶梯和额度余量。之后只有换到没介绍过的模型时补一行，额度和档位变化不再重发。简报会给出**普通任务的默认配置**：发布数据里“最划算”的模型加 ★ 档；如果它比“最强”低 3 分以上，就用“最强”的 ★ 档。默认值跟着发布数据变（今天是 GPT-6.1 Sol ★Med）。Codex 的建议围绕它：小任务降一档，复杂任务用默认模型的 High 或 XHigh，做完回到默认。由 Codex 判断任务难度，只有当前设置明显不合适时才用一句话建议一个配置，否则不提模型和档位。设置 `MODELPLAN_TASK_BRIEF=off` 可关闭简报。只读本地文件，不会切换模型、档位或 Fast。
- **速度模式**（⚡ Fast、⚡⚡ Ultrafast）：能力不变。成本格改为“额度”，是套餐额度消耗的估算值，等于 API 参考任务成本倍率乘以该模式公布的套餐额度倍率；它只在同一模型内成立，比较基准是本模型 ★ 推荐档的标准模式。任务耗时显示为未知，因为工具、网络和测试时间不会随生成速度缩短。生成速度单独列出，标为“最多快 N 倍”的上限，没有公布时标为未公布。每个速度模式都附上积分倍率、可用套餐和官方说明链接。读数、迷你图和详情图始终处于同一模式。
- 公开 Codex 重置公告，保留来源、范围和时间精度，它们不是你自己的额度读数。

使用与 [Model Plan](https://modelplan.ai/effort) 相同的核验发布数据，不在客户端重新打分、不调用模型推理、不购买套餐、不切换当前会话模型。缓存、读取失败和保留上一份快照的状态会明确显示。模型名单是已评估的 GPT 集合，不是宿主选项的完整清单。

## 开发与内部传输

`mcp.json` 配置内部 stdio 传输，提供 `open_model_dashboard`（对话内卡片）、`get_model_dashboard`（文字和数据），以及由用户打开的入口 `open_model_panel`（对话侧边面板）和 `open_model_board`（侧栏）。每个工具只声明一个入口，每个位置一个界面资源；Codex 运行 `launch.cjs`，由它在兼容的 Node 上启动已打包的 `server.bundle.mjs`。界面内嵌样式和字体，不依赖第三方浏览器请求。正常使用仅读取 Model Plan 公开发布端点；本地缓存只存公共数据，不收集遥测或凭证。

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
