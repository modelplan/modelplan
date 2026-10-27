# Cursor native quota (beta)

The saved-login reader needs explicit shared consent through
`quota.Paths.ReaderAccess`. Existing connection settings alone do not grant access.
CLIJIT owns detection, consent records and worker/command wiring. Consent line:
“Read Cursor's saved sign-in and authenticate to Cursor for your account's plan
and usage.” `MODELPLAN_READERS=passive|off` and `MODELPLAN_NATIVE=off` suspend
collection. Automatic CodexBar fallback is off.

Only `cursorAuth/accessToken` in the admitted Cursor profile's
`User/globalStorage/state.vscdb` is queried, read-only with existing WAL. Default
paths: macOS `~/Library/Application Support/Cursor/`; Linux absolute
`$XDG_CONFIG_HOME/Cursor/` or `~/.config/Cursor/`; Windows `%APPDATA%/Cursor/`.
Unsupported/sealed or expired logins make no request; the next step is **Open
Cursor to refresh**. No credential refresh, rewrite, copy/cache, browser or
Keychain access, conversation reads, CLI launch or inference calls.

Cold reads have at most **two requests**: `POST https://cursor.com/api/dashboard/get-plan-info`
with an in-memory derived WorkOS session, then
`POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage`
with the same access token as bearer and Connect protocol version 1. Same-binding
plan/merged/period metadata is cached for at most 24 hours; warm reads request
period usage only. An expired cached reset forces revalidation. The former
`/api/usage-summary` and `/api/usage` waterfall is removed. These undocumented
personal dashboard contracts are not the team Admin API. Proxy transport from the
injected client is preserved; redirects/cookie jars are disabled and the selected
local store is checked for changes during the transaction.

Explicit included periods map to weekly/monthly with the returned reset and
`planUsage.totalPercentUsed`. Missing percentages stay unknown, never zero. No
Auto/Other-model split, money unit, request count, prepaid balance or organisation
allowance is guessed when these two contracts do not establish it. An actual
provider zero stays zero. Unsupported spend/per-request shapes require verified
contracts within the same budget, not extra fallback calls.

Eligible merged weekly plans get `sharedPool={kind:"x-subscription",status:"unverified",additive:false}`
and **Shared-pool link unverified**. Keep Cursor and Grok subscription references
separate until a verified common billing/seat ID or provider link exists. Equal
percentages, resets, emails or installed apps are not link evidence. Unverified
pools must not be added as separate capacity. During link discovery, a conservative
shared Cursor/Grok gate permits one native route per five minutes, without remote
link lookup requests. There is no provider-side account unification or token move.

The provider-wide floor spans profiles/processes. Unchanged readings stretch to
10/15/30 minutes; errors back off to 10/20/40/60 minutes and honor longer Retry-After.
Failures retain the last good capture and its age; reset-past windows are dropped.
Changed credentials cannot inherit an unverified old binding. Ordinary/JSON
rendering loads ModelPlan's sanitized cache only: no tool-store stat, SQLite, HTTP
or detached worker. Profile paths and identities persist only as keyed hashes or
opaque references.

Protocol evidence: [existing compatibility reader](https://github.com/modelplan/modelplan/blob/7beebd1d9c3768569e08c22b4bde2dc5c81fc31f/cli/internal/quota/cursor.go),
CodexBar 0.81.0 ee890b5 (MIT), Token Monitor e1c393c (MIT). Fixtures are handwritten,
not captured accounts or copied code. Shared admission/cache machinery is reused
from PR225; this independently based provider PR can merge after that foundation.
CLIJIT must consume the additive shared-pool DTO before enabling the new reader.

## 简体中文

此 beta 读取器由统一同意记录明确授权；旧连接设置不授权读取登录信息。只读 Cursor
本地登录，不刷新、改写或保存凭据，不读浏览器、钥匙串或对话，不启动 CLI，不调用推理。
失效或不支持的登录不发请求，下一步为“打开 Cursor 刷新登录”。

每次最多访问套餐信息和当前周期用量两个接口；同一登录的套餐元数据最多缓存 24 小时，
通常只需一次用量请求。不再串行尝试旧版 summary/usage 接口。缺失的比例、金额、币种和
请求数保持未知，不猜测。读取间隔至少五分钟，错误退避并保留上次成功读取及其采集时间，
过期窗口不再显示。JSON 只投影 ModelPlan 缓存，不访问 Cursor 文件或网络。

确认合并周额度时标记“共享额度关联未验证”；公共 ID 或提供方关联证据出现前不与 Grok
合并，也不当作可相加的第二份额度。Cursor 与 Grok 暂共用保守的五分钟门限。
测试仅使用合成 SQLite 文件和本地 HTTP 服务，不读取真实凭据或访问真实提供方账号。
