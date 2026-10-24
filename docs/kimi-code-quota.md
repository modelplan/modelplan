# Kimi Code plan-key quota

Enable explicitly with `modelplan connect kimi --region china` or `--region international`. The key comes only from `KIMI_CODE_API_KEY`, or a variable named by `--key-env NAME`; setting a key alone does not enable the reader. `modelplan disconnect kimi` or `MODELPLAN_NATIVE=off` stops it.

| Region | Passive read | Credential |
| --- | --- | --- |
| `china` (default) | `GET https://api.kimi.com/coding/v1/usages` | China-issued Kimi Code plan key |
| `international` | `GET https://api.kimi.ai/coding/v1/usages` | International-issued Kimi Code plan key |

This is an **undocumented compatibility endpoint** identified in popular public monitors, not a vendor-documented API stability promise. Connections and desktop diagnostics disclose the selected environment variable, host and this status. Hosts are compiled in, redirects are refused, and the key is never printed, written or cached. No credential file, CLI OAuth token, browser session, inference route or Moonshot API balance is used. Kimi Code subscription quota is separate from Moonshot Open Platform cash balance. Credentials are never refreshed or rewritten; no model is switched.

When no key is set, the explanation remains explicit: no key was read or request sent, quota is unknown, and the plan-key endpoint is undocumented. Supply a region-appropriate plan key in the selected environment variable, rather than granting access to another tool's sign-in. A missing key never reuses a previous account's meter.

The reader follows the native z.ai lifecycle: at most every 10 minutes in the background, 30-minute retry after failure, bounded GET/response/timeout, and a sanitized native cache. Kimi readings older than 60 minutes and passed resets become unknown (`--`). Old count-based `usage` / `limits[].detail` and named `usages.limit_5h`, `limit_7d`, `limit_month_total` ratios are supported. Absent/invalid counters never default to zero. Ratios retain precision; conflicting counts for the same reset period retain the higher usage. Monthly Code-only usage is not added to the overlapping monthly total pool. No remaining balance, quota or reset is guessed from local activity.

Account bindings use the existing local keyed-hash identity map, scoped to Kimi and region; only opaque references reach snapshots. Changing the selected region, environment variable or key invalidates the previous successful binding. No key, user profile, error response body or raw account identity is stored. `MODELPLAN_IDENTITY=off` withholds account bindings as for the other native adapters.

Schema/route evidence read (MIT licences in both actual root LICENSE files): [CodexBar docs](https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/docs/kimi.md), [KimiModels.swift](https://github.com/steipete/CodexBar/blob/0827f30bfcecf08ade05ea878b147184ec6515dc/Sources/CodexBarCore/Providers/Kimi/KimiModels.swift), its usage fetcher and ratio tests; [token-monitor Kimi limits](https://github.com/Javis603/token-monitor/blob/0c7dd855d3697ba0cd3ed47a3d52f8f187cc0e23/src/shared/providers/kimi/limits.js). The Go implementation and fixtures are independently written; no monitor code or non-trivial implementation structure was copied. The [official overview](https://www.kimi.com/code/docs/) supplies regional inference-base/product context, not a quota API guarantee. Live endpoint acceptance is unverified: tests use handwritten synthetic shapes and local HTTP servers only.

## 中文

用 `modelplan connect kimi --region china`（默认国内）或 `--region international` 显式启用。仅从 `KIMI_CODE_API_KEY` 或 `--key-env NAME` 指定的环境变量读取对应地区套餐 key；仅设置 key 不会启用。`disconnect kimi` 或 `MODELPLAN_NATIVE=off` 停止读取。

国内只调用 `GET https://api.kimi.com/coding/v1/usages`，国际只调用 `GET https://api.kimi.ai/coding/v1/usages`。这是公开监控工具使用的未公开文档兼容端点，不保证稳定。诊断披露变量名、主机和未公开文档状态，拒绝重定向。key 不打印、不落盘、不缓存；不读取凭据文件、OAuth、浏览器或 Moonshot 余额，不刷新、改写其他工具凭据，不调用推理、不自动切换模型。未设置 key 时保留说明：没有读取 key 或发送请求，额度未知。

沿用原生 z.ai 读取节流、失败退避、大小与时间限制及脱敏缓存。支持旧版计数及新版 5 小时、7 天、月总量比例；缺失、无效、超过 60 分钟或过重置时间的读数均保持未知 `--`，不把月 Code 子池叠加到月总池。身份仅存储按地区区分的本地带密钥哈希和不透明引用，改变 key 或地区使旧的成功绑定失效。代码与合成样本独立编写，参考 CodexBar 和 token-monitor 的 MIT 来源，未访问真实账号或厂商端点。
