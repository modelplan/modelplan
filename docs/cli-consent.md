<!-- SPDX-License-Identifier: MIT -->
# Shared reader consent

`modelplan connect --detected` uses the same offline presence report as
[`modelplan detect`](cli-detection.md). Tools start checked. Enter keeps the
checked list; comma-separated numbers choose a subset; `none` means Not now.
One final `y` confirmation records the selection. EOF, invalid input or declining
enables nothing. The command starts no reader, download or background work.
`--json` reports proposed choices, access lines, beta flags, consent text and
text version without prompting or writing.

Consent explains the shared App/plugin/CLI grant, existing sign-in, credentials
sent only to their provider and never stored by ModelPlan, and possible macOS
Keychain prompts. Helper rows explicitly name the included, checksum-checked
CodexBar. Detection proves neither sign-in nor a subscription. Permission does
not imply a reader has shipped; unsupported readers stay unavailable until
FEEDFIX implements them.

`--privacy automatic|passive` persists the choice. Automatic permits the selected
reader after consent. Passive permits credential-free local/session or tool
runtime reads and explicitly configured keys; it blocks automatic tool credential
and Keychain import and the generic helper. `MODELPLAN_READERS=passive` further
restricts the persisted choice; `MODELPLAN_READERS=off` stops personal readers.
Presence detection and public data are unaffected. Unknown nonempty overrides
fail closed. Existing explicit legacy connections are preserved until revoked;
catalogue consent never silently broadens them.

`~/.config/modelplan/consent.json` (schema 1, mode 0600) is shared across copies.
Per-tool records contain allowed/refused, consent-text version, timestamp,
logical reader/backend and optional opaque profile descriptors. Source denials
survive disconnect, reconnect, restart and updates. Keychain Deny is never
automatically retried; only a future explicit Settings Retry may clear it. This
PR adds no Keychain value adapter. Unknown consent-text versions cannot admit a
reader. Exclusive locks and atomic replacement serialize changes; the generation
counter supplies FEEDFIX's stale-work fence (`CurrentGeneration` before publishing).

Catalogue routing cannot grant consent. `preferred: off` stops new reads;
`codexbar.audited: false` blocks the helper, including explicit legacy connections
when the publication names that provider. Newly consented helper routes require a
currently verified, audited `preferred: codexbar` entry. Native routes never
automatically fall back to CodexBar for head providers. `minCli` gates admission
after consent. FEEDFIX retains routing/reader implementation ownership; framework
changes stay in command/config admission plus the invocation version field in
`quota.Paths`. Reader implementations, provider network logic and credentials
remain untouched. Beta is catalogue metadata and fixtures cannot clear it.

`modelplan disconnect <tool>` or `--all` revokes first, disables legacy connections
and removes only that tool's ModelPlan-owned readings. It filters native/helper
snapshots, cycles/pace, tagged speed/performance history and keeps other tools and
attempt gates. Owner-tool logs and credentials are never deleted. Reader/cache
locks prevent cleanup racing writers. If busy, revocation remains saved and the
command reports cleanup failure; retry disconnect to finish deletion. FEEDFIX's
future router must use generation checks and cancellation/purge hooks for new
cache formats. Rollback never resets grants, denials or provider call budgets.

A foreground `quota` call hints once for newly detected tools, pointing to
`modelplan connect --detected`. Previously granted, refused or revoked tools are
never hinted again. JSON stays clean; detection/JSON previews do not mark hints
seen. No tool or credential data is uploaded.

`modelplan connect --detected` 默认勾选检测到的工具，选择后只确认一次；`--json`
仅预览，不写入或运行读取器。授权在 App、插件及 CLI 副本间共享并记录文本版本。
`--privacy automatic|passive` 保存隐私级别；`MODELPLAN_READERS=passive|off` 进一步限制。
Passive 禁止自动导入工具凭据/钥匙串，Off 停止个人读取器。钥匙串拒绝不会自动重试。
`disconnect <工具|--all>` 先撤销授权，再删除该工具的 ModelPlan 缓存读数；保留其他工具、
调用间隔记录和原工具文件。新工具只提示一行；目录停用、未审核的 CodexBar 路由和
不兼容 `minCli` 都不能越过本机授权。
