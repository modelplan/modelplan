# Model Plan Codex 插件

在 Codex 桌面端用紧凑看板比较 GPT 模型和推理档位；Codex CLI 返回相同口径的文字。[English](README.md)

## 安装

需要 PATH 中有 Node.js 24+，以及支持插件的 Codex。运行依赖和字体已经打包，无需 npm 安装、API Key 或 Model Plan 账号。

```sh
codex plugin marketplace add modelplan/modelplan
codex plugin add modelplan-codex@modelplan
```

安装后重启 Codex 或打开新任务，输入“打开 Model Plan 看板”，也可调用 `model-dashboard` 技能。支持应用面板的桌面客户端会显示看板；客户端提供展开能力时可点击“展开”。CLI 显示文字比较。面板位置由宿主决定，插件不能强制固定到侧栏。

更新时执行：

```sh
codex plugin marketplace upgrade modelplan
codex plugin add modelplan-codex@modelplan
```

## 看板内容

- 已发布的 OpenAI 推荐档、高能力优选、最划算和最省配置。
- 原生档位滑杆和能力／成本／耗时小曲线。点击指标单独查看，再点恢复全部；滑杆支持方向键、Home、End。
- 金色 ★ 仅代表推荐档。能力是相对推荐档增减的分数，成本／耗时是倍率。估算标 ≈；缺失或口径不兼容的耗时保持空缺。
- 公开 Codex 重置公告，保留来源、范围和时间精度，不推断你的余额、个人重置或领取资格。

使用与 [Model Plan](https://modelplan.ai/effort) 相同的核验发布数据，不在客户端重新打分、不调用模型推理、不购买套餐、不切换当前会话模型。缓存、读取失败和保留上一份快照的状态会明确显示。模型名单是已评估的 GPT 集合，不是宿主选项的完整清单。

## 开发与内部传输

`mcp.json` 配置内部 stdio 传输，提供 `open_model_dashboard` 和 `get_model_dashboard`；从安装目录启动已打包的 `server.bundle.mjs`。界面内嵌样式和字体，不依赖第三方浏览器请求。正常使用仅读取 Model Plan 公开发布端点；本地缓存只存公共数据，不收集遥测或凭证。

```sh
cd codex
npm ci --ignore-scripts
npm test
npm run build
node tests/mcp-smoke.mjs --fresh
node tests/codex-host-smoke.mjs
```

最后一项要求已在 Codex 安装同版本；只验证注册、工具和界面资源传输，不创建对话、不运行推理，也不代替原生面板位置验收。`npm start` 可启动本地界面开发预览，不是公开服务。

`lib/client-reader.mjs` 是统一发布校验器的独立副本；源码和运行包同时提供。字体 OFL 授权保留在 `ui/fonts`，运行依赖授权见 `THIRD-PARTY-NOTICES.md`。

MIT，见 [LICENSE](LICENSE)。
