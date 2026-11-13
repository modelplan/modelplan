# MiniMax plan quota (opt-in)

`modelplan connect minimax` reads `MINIMAX_CODING_API_KEY` only after you opt in. Use `--key-env NAME` for a different environment variable. `--region international` is the default (`https://api.minimax.io`); `--region china` selects `https://api.minimaxi.com`. Regions have separate accounts and keys. No automatic cross-region retry occurs. Disconnect with `modelplan disconnect minimax`; `MODELPLAN_NATIVE=off` stops native reads.

The primary request is `GET /v1/token_plan/remains`. MiniMax's [official international page](https://platform.minimax.io/subscribe/token-plan) documents this route on `www.minimax.io`; the API subdomains and response schema are compatibility interfaces evidenced by CodexBar and Token Monitor. The legacy, undocumented `GET /v1/api/openplatform/coding_plan/remains` is a same-host fallback only after HTTP 404/405 or a recognized vendor-body compatibility rejection. HTTP 401 or 403 ends the read immediately, with no legacy request. No fallback after throttling, server/transport failure or malformed current data. No URL override, browser, credential file, refresh, key copy, account balance, inference or CodexBar backend is involved.

The shared `general` coding pool or known legacy text-model pools supply short-window and weekly percentages/reset dates. Remaining percentages take precedence over counters; legacy `*_usage_count` means remaining. Missing values, inactive/placeholding pools, invalid numbers and elapsed resets stay unknown. Image/video/audio lanes are excluded. API cash balance and token accounting are separate products and never become subscription quota. A PAYG key without plan entitlement has unknown quota.

`modelplan connections` and desktop diagnostics disclose the exact variable name, selected host, both routes and their documentation status. Keys and vendor error bodies are never printed or stored. Only sanitized quota and local keyed-hash identity references are cached; cache binding includes region/key selection and invalidates when either changes. With `MODELPLAN_IDENTITY=off`, the key binding cannot be verified, so cached MiniMax quota stays unknown; refresh still respects the native cadence/backoff. All tests use synthetic fixtures and local servers.

## 简体中文

默认关闭。`modelplan connect minimax` 显式启用，仅读取 `MINIMAX_CODING_API_KEY`，也可用 `--key-env NAME` 指定变量。`--region international`（默认）调用 `api.minimax.io`，`--region china` 调用 `api.minimaxi.com`，不会把 key 自动发往另一地区。`disconnect minimax` 或 `MODELPLAN_NATIVE=off` 关闭。

主接口为 `/v1/token_plan/remains`；官方国际站文档列出的是 `www.minimax.io`，API 子域名与响应结构属于兼容接口。仅在主接口返回 HTTP 404/405 或已识别的响应体兼容性拒绝码时，尝试同主机的旧版 `/v1/api/openplatform/coding_plan/remains`；HTTP 401/403 立即结束读取，不发旧版请求。限流、网络错误、服务端错误和格式异常不回退。不读取浏览器或凭据文件，不刷新、复制、保存 key，不调用余额或推理接口。

只显示共享 `general` 编程池或已知旧版文本模型池。百分比优先，旧版 `*_usage_count` 表示剩余而非已用；缺失、无效、无权益和已过重置时间的值保持未知。图片、视频、语音以及 API 现金余额不计为编程套餐额度。连接与桌面诊断披露变量、主机和接口文档状态，只缓存清理后的额度与按地区绑定的本地密钥哈希引用。`MODELPLAN_IDENTITY=off` 时无法验证 key 绑定，缓存额度保持未知，仍遵守原生刷新节奏与退避。
