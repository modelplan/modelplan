<!-- SPDX-License-Identifier: MIT -->
# Confirmed plugin installation

CommunityApp creates its Settings backend and calls
`CommunityApplicationFactory.connectSettings`. That factory binds one
`CommunityPluginInstaller` before the existing editor/controller caches
capabilities. A verified app bundle enables Claude Code and Codex; absent or
inconsistent helper identity leaves both actions disabled with the existing
component-help route. The installer has a dedicated `BundledCLI`, so the normal
usage poll cannot occupy its process slot.

An install button creates a confirmation; only Confirm invokes the fixed
`plugin install <claude-code|codex> --json` command. It may let the host CLI use
network, credentials and host configuration. This neither requests usage consent
nor changes reader mode, timers, subscription identity or either release pin.
The helper remains the app's pinned native helper; this action does not upgrade it.

The decoder accepts only the public schema's fixed tool, commands, docs,
completed-step count and matching exit status. `installed` means both host
commands reported success, without independent installation verification.
`instructions` means the host CLI was missing; after the confirmed request it
copies static installation commands and requests the fixed setup guide URL.
Failed delivery is shown with Copy/Open controls. Those controls also help with
planned/failed results and never repeat installation. A partial failure preserves
its completed count; no rollback or automatic retry occurs. Hidden/cancelled work
cannot trigger delayed guidance. Raw host stderr, paths and errors are not rendered.

Synthetic proof uses the actual Settings factory/controller/view with a fake
wire and guidance adapter, plus the shared generated CLI captures for both tools
and all five outcomes. It checks confirmation, one dispatch, truthful partial and
fallback outcomes, guidance delivery, cancellation and unverified construction.
It does not prove a packaged native helper or a real host installation. The next
proof requires a reviewed candidate containing this source and direct owner
approval specifically for host installation and clipboard/browser effects.

## 中文

CommunityApp 经共享工厂为同一个 Settings controller 接入安装服务；只有组件身份
核验通过才启用 Claude Code/Codex 按钮。点按钮只创建确认，确认后才运行固定安装命令；
宿主 CLI 可能访问网络、凭据和配置。此操作不授权用量读取、不改变轮询或版本 pin。

仅两步宿主命令均报告成功才显示安装器报告完成，不声称独立验证插件可用。找不到宿主
CLI 时显示尚未安装，复制静态命令并请求打开固定指南；复制或打开失败会如实提示，并可
单独重试。复制/指南按钮不重复安装；部分失败保留已完成步数，不自动回滚或重试。
生命周期退役或任务取消后的延迟结果不会触发指南副作用，也不显示原始宿主错误。

当前证据来自真实 Settings 工厂/控件和共享 CLI 样例的合成测试；并未执行真实宿主安装。
下一次实际验证需候选包含本改动，且本人单独批准安装及剪贴板/浏览器副作用。
