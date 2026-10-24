# Cursor native quota (opt-in)

Enable with `modelplan connect cursor`. Disable with `modelplan disconnect cursor` or `MODELPLAN_NATIVE=off`. The default remains off until connected. Existing explicit CodexBar selections stay selected; use `modelplan connect cursor --backend codexbar` for that fallback.

The native reader reads only `cursorAuth/accessToken` in Cursor's `User/globalStorage/state.vscdb`, read-only, including existing WAL state. macOS: `~/Library/Application Support/Cursor/`; Linux: absolute `$XDG_CONFIG_HOME/Cursor/` or `~/.config/Cursor/`; Windows: `%APPDATA%/Cursor/`. It never refreshes, rewrites, copies or persists credentials, scans browser stores, reads conversations, or opens a keychain. Unsupported sealed/opaque tokens and expired sign-ins produce unknown quota; sign in through Cursor or explicitly select CodexBar.

It sends an in-memory derived session to `https://cursor.com` private dashboard endpoints: `/api/usage-summary`, `/api/usage?user=...` for legacy request quotas, and `/api/dashboard/get-plan-info`. Unified plans use `/api/dashboard/get-current-period-usage` for included percentage. These are undocumented compatibility interfaces, not Cursor's documented team Admin API. Included usage and usage-based spend are separate; missing amounts, limits and reset dates stay unknown. No subscription allowance is inferred from local token counts. See the PR method comparison for evidence and limitations.

`modelplan connections --json` and desktop diagnostics disclose the path, hosts and endpoint status. Only sanitized quota and a locally keyed account hash mapped to a random reference are cached. Tokens and account identifiers are never printed or stored. Background refresh follows the native reader cadence; failed refreshes replace the usable reading with an unavailable status.

## 简体中文

默认关闭；`modelplan connect cursor` 启用原生读取，`modelplan disconnect cursor` 或 `MODELPLAN_NATIVE=off` 关闭。`--backend codexbar` 显式选择已有回退桥接，不自动切换。

只读 Cursor 的 `User/globalStorage/state.vscdb` 中的 `cursorAuth/accessToken`，包括已有 WAL。macOS 位于 `~/Library/Application Support/Cursor/`，Linux 位于绝对路径 `$XDG_CONFIG_HOME/Cursor/` 或 `~/.config/Cursor/`，Windows 位于 `%APPDATA%/Cursor/`。不刷新、改写、复制或保存凭据，不读取浏览器、钥匙串或对话。加密、不支持的非 JWT 或过期凭据会显示额度未知。

仅在内存中构造会话，访问 `cursor.com` 的未公开仪表盘接口。套餐内额度、旧版请求额度和按量付费分开显示；缺失的金额、额度和重置时间保持未知。连接状态和桌面诊断披露路径、主机与接口性质。缓存只保存清理后的额度和由本地密钥哈希映射的随机账户引用，不保存令牌或账户标识。
