# Install ModelPlan / 安装 ModelPlan

Choose **Mac App**, **plugins**, or **Skill**. The CLI is the shared data engine; installing it separately is an advanced option. See [product roles](product-surfaces.md).

三个入口是 **Mac App、插件、Skill**；CLI 是共享数据引擎，单独安装属于高级用法。参见[产品分工](product-surfaces.md)。

## Mac App: a dashboard for people / 给人看的仪表盘

The App displays models, efforts, personal quota and reset times. It includes the CLI, so there is no separate CLI setup. For the current macOS preview, follow [Try a build](../desktop/README.md#try-a-build); preview build and signing status are documented there.

App 自带 CLI，集中显示模型、档位、个人额度和重置时间。当前 macOS 预览版按 [Try a build](../desktop/README.md#try-a-build) 安装，构建与签名状态见该页。

Settings is the designated plugin-install entry point. The current preview still needs its installer integration; use the host commands below meanwhile. This checkout has no shared `modelplan plugin install claude-code|codex` command.

Settings 是插件安装入口的产品定位；当前预览版仍需接好安装集成，暂用下面的宿主命令。此代码尚无统一的 `modelplan plugin install claude-code|codex` 命令。

## Plugins: automatic in-agent help / Agent 内的自动帮助

Both plugins bundle the Skill and a pinned, SHA-256 checked CLI. There is no separate CLI installation. Automatic hints default to on; off silences the entire prompt hook while explicit commands and the existing panel remain available.

插件自带 Skill 和锁定版本、核对 SHA-256 的 CLI，无需另装。自动提示默认开启；关闭后提示钩子完全静默，显式命令和已有面板仍可使用。

**Claude Code:**

```text
/plugin marketplace add modelplan/modelplan
/plugin install modelplan@modelplan
/modelplan:setup
```

Use `/modelplan:setup automatic-hints off` or `on`. The status line is an **optional display**. Its local snapshot is currently the only source of Claude Code quota; automatic detection is coming. Without a snapshot, Claude quota stays unknown and public model advice still works. [Plugin guide](../claude-code/README.md)

用上述 setup 命令的 `automatic-hints off` 或 `on` 关闭/开启提示。状态栏是**可选显示**。当前版本的 Claude Code 额度只来自它记录的本地快照，自动检测尚待推出。没有快照时 Claude 额度保持未知，公开模型建议仍可使用。[插件指南](../claude-code/README.md)

**Codex:**

```sh
codex plugin marketplace add modelplan/modelplan --sparse .agents --sparse codex
codex plugin add modelplan-codex@modelplan
```

Ask Codex to check ModelPlan setup or turn automatic hints off/on. The plugin finds a compatible Node.js 22+ runtime; it does not install Node. The existing panel is feature-frozen; new visuals go to the App and website. [Plugin guide](../codex/README.md) · [中文](../codex/README.zh-CN.md)

让 Codex 检查 ModelPlan 设置，或关闭/开启自动提示。插件会查找兼容的 Node.js 22+，不会安装 Node。已有面板功能冻结，新视觉功能放在 App 和网站。

## Skill: any coding agent / 任何 coding agent

```sh
npx skills add modelplan/modelplan
```

Or copy [the Skill directory](../skills/model-plan/) into your agent's skills directory. A shell and anonymous HTTPS are enough for public model and effort answers. For your own quota, if no CLI is available, it asks once before installing the pinned CLI into `~/.local/bin`. It installs only after yes; after no it never asks again. Unavailable readings stay unknown. The Python quota helper is deprecated during the CLI auto-detection transition.

也可以把 [Skill 目录](../skills/model-plan/) 复制到 Agent 的 skills 目录。公开模型和档位问答只需 shell 与匿名 HTTPS。问到自己的额度且没有 CLI 时，只询问一次是否安装锁定版 CLI 到 `~/.local/bin`；只在同意后安装，拒绝后不再问。无法读取的数据保持未知。Python 额度读取器在 CLI 自动检测过渡期保留，但已弃用。

The ladder is **Skill → Skill + CLI → plugin**; the App sits alongside it. / 使用阶梯是 **Skill → Skill + CLI → 插件**，App 与之并行。

## Advanced: standalone CLI / 高级：单独安装 CLI

For terminal workflows and integrations only. The App and plugins already ship the engine; the Skill has its own consent-based pinned installer.

仅供终端工作流和集成使用。App 和插件已自带引擎；Skill 有单独的、征得同意后运行的锁定版安装器。

```sh
curl -fsSL https://raw.githubusercontent.com/modelplan/modelplan/main/install.sh | sh
```

This standalone installer downloads the latest release, verifies SHA-256, installs into `~/.local/bin`, and prints a PATH suggestion if needed without editing profiles. [CLI guide](../cli/README.md)

独立安装器下载最新发布版、核对 SHA-256，安装到 `~/.local/bin`；需要时只打印 PATH 建议，不改 shell 配置。[CLI 指南](../cli/README.md)
