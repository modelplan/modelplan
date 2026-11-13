<!-- SPDX-License-Identifier: MIT -->
# Production reader admission

Every CLI account path (`quota`, `advise`, `plan`, hooks and the desktop feed)
uses `quotaPaths` → `quota.ProductionPaths`. This constructor joins the shared
versioned consent store to the saved-login readers. It inspects local presence
metadata only; it does not open login files, call a provider or start a process.
Reader grants use the consent generation and compiled local profile roots.
Published catalogue off/incompatible/helper routes cannot grant native access.

Unset or `MODELPLAN_READERS=automatic` retains the persisted privacy choice.
`passive` cannot be elevated by an automatic override. Saved-login and authenticated
runtime imports require Automatic; `off` suspends all readers. Existing explicit
environment-key routes retain their Passive contract. `MODELPLAN_NATIVE=off`
suspends native readers. A standard grant never enables browser-session access;
helper routing still requires its separately audited access class.

Native Keychain policy comes from the shared source grant. Background reads reuse
it with the existing two-second kill/reap deadline. Quiet detached refreshes,
hooks and ordinary cache/JSON reads are never interactive. An explicit foreground
`connections refresh` may use the interactive policy. Shared source Deny and the
Keychain adapter's persisted Deny/confirmation-needed state survive reconnect and
Forget; this change adds no automatic retry or credential refresh.

Before publishing, readers recheck the consent generation. Their sanitized state
and the aggregate native snapshot are committed under the consent publication
fence. Revoked reads cannot repopulate a successfully forgotten capture. Forget
also clears managed-reader, runtime/config and local-history captures while
retaining provider attempt/backoff gates, installation keys and Keychain Deny.

## U2a admission gates (U2 integration)

U2 consumes `quota.PolicyPending` for admission, projection and diagnostics.
The U2a entry-point branch alone does not install those hooks. In the integrated
build, Gemini Code Assist and Cursor plan/period account usage are disabled pending
approval of their POST request sets. Admission wins over saved-login grants and
legacy transition state: no remote calls, no scheduled account refresh, no old
remote quota projection, and diagnostics report `unavailable:policy_pending`.
Local-history paths retain their own consent. MiniMax ends its production read
after HTTP 401 or 403 without trying the legacy endpoint. Historical POST parser,
identity and budget fixtures use a test-only compiled-policy override; separate
production regressions use the unchanged gate and valid synthetic logins.

Gemini Code Assist 与 Cursor 套餐/周期 POST 账户用量路径在请求集获批前禁用，
授权及旧版过渡状态均不能绕过：不发远程请求、不调度账户刷新、不显示旧远程额度，
诊断为 `unavailable:policy_pending`。本机历史保留独立授权。
MiniMax 收到 HTTP 401/403 后立即结束，不再请求旧版端点。

## Reader audit

| Reader | Production path | Before this fix |
|---|---|---|
| Claude Code account | ProductionPaths grant → RefreshNative → collectClaudeAccount → ReadPermitted → desktop accounts/sources | Missing saved-login grant |
| Cursor account | Same managed dispatch → collectCursorAccount | Missing saved-login grant |
| Gemini account | Same managed dispatch → collectGemini | Missing saved-login grant |
| Grok Build account | Same managed dispatch → collectGrok | Missing saved-login grant |
| Kimi saved login | Same managed dispatch → collectKimiLogin | Missing saved-login grant; explicit-key route already existed |
| Copilot quota | Shared native selection → productionReaderContext → collectCopilot → aggregate native cache | Legacy explicit dispatch existed; typed generation/access context was missing |
| Antigravity quota | Same selection/context → collectAntigravity | Legacy explicit dispatch existed; typed generation/access context was missing |
| Kiro quota | Shared native selection → fetchKiro | Runtime dispatch already existed; production Automatic/Passive admission now tested |
| GLM from environment | Shared native selection → fetchZai | Explicit environment-key dispatch already existed |
| GLM from Claude settings | `connect zai --profile claude-code` → local source descriptor → collectZaiConfig → fixed validated GLM endpoint | No production source/context handoff |
| OpenCode Go | Shared native selection → fetchOpenCodeGo | Explicit environment-key dispatch already existed |
| MiniMax | Shared native selection → fetchMiniMax | Explicit environment-key dispatch already existed |
| Amp, Droid, Kimi, Copilot, Grok local history | ProductionHistoryAccess → ProductionHistory/ProductionHistories → incremental adapters → desktop localHistory | Adapters existed without production callers |
| Gemini/Qwen incremental history | Same shared constructor/refresh; their existing localUsage feed remains the displayed source | Incremental adapters had no callers; the original opt-in localUsage path already worked |
| Qwen aggregate export | qwenSnapshot/qwenUsageCmd → shared Local permission → bounded export reader | Already wired and gated; remains separate from transcript history |
| Amp money/quota | Standalone RefreshAmp requires a provider-audited exact native binary digest | No production audit/digest source exists; remains unavailable, never auto-authorized by detection or by the local-history grant |
| Claude passive session reducer | Shared projection seam, separate quota-owned reducer integration | The generic seam exists; no concrete collector is shipped by this change |

The registry inventory test requires a production admission fixture for every
native reader. The local-history inventory test does the same for every count
adapter. Tests use synthetic homes/logins, local transports and fake processes;
none certify an upstream helper or read a real account.

## Desktop and local history

`desktop --json` adds optional `localHistory` results for the additional local
count adapters. Native counters, unallocated rows, capture age and beta status
are preserved. Gemini/Qwen retain their existing `localUsage` fields, avoiding a
second displayed measurement of the same records. Contract version stays 1.
`desktop --read-only` reads sanitized incremental caches only and creates no key,
checkpoint or detached process. New history counts participate in `dataRevision`;
retry and freshness boundaries participate in `validUntil`.

Local history reuses the existing installation identity key and an opaque keyed
profile reference. Explicitly accepted shared tool grants authorize the compiled
local roots; detection alone never grants access. `MODELPLAN_HISTORY=off`, per-tool
Gemini/Qwen switches, shared denial and revocation are respected. No account quota
is inferred from token history.

## 中文

所有额度命令、钩子和桌面数据源通过同一个 `ProductionPaths` 构造器，将共享授权
转换为原生读取器的授权、代际与本机来源。默认或显式 automatic 保留已保存的隐私
选择；passive 不导入登录凭据或运行认证工具，显式环境 key 保留原有规则；off 与
`MODELPLAN_NATIVE=off` 可停止读取。浏览器会话仍需独立高级授权。

后台钥匙串读取复用已有授权并保留约两秒期限；仅显式前台刷新可交互。Deny 与
确认待办不会被自动重试、重新连接或忘记读数清除。结果写入前重新检查授权代际，
撤销中的结果不能重新写回；忘记只清除读数，保留请求间隔、退避及访问拒绝状态。

GLM 配置来源需显式 `connect zai --profile claude-code`，只接受读取器校验过的
GLM Coding Plan 端点。新增本机历史使用已有安装密钥；桌面可选 `localHistory`
保留原生计数、未知归因、捕获时间与 beta 状态。Gemini/Qwen 沿用已有展示字段，
不重复计数；只读桌面不创建密钥或游标。Amp 金额读取仍缺已审核的精确二进制摘要，
因此保持不可用，不借本机历史授权自动运行。所有验证均使用合成文件与注入请求。
