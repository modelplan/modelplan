<!-- SPDX-License-Identifier: MIT -->
# Shared reader consent

`modelplan connect --detected` uses the same offline presence report as
[`modelplan detect`](cli-detection.md). Standard tools start checked. Enter keeps the
checked list; comma-separated numbers choose a subset; `none` means Not now.
One final `y` confirmation records the selection. EOF, invalid input or declining
enables nothing. The command starts no reader, download or background work.
`--json` reports proposed choices, access lines, beta flags, consent text and
text version without prompting or writing.

The catalogue's `codexbar: {audited, access}` distinguishes `standard`,
`browser-session` and `not-read`. Audited standard access uses the tool's own
login or an audited read-only CLI command that consumes no quota. It always runs
with `CODEXBAR_DISABLE_KEYCHAIN_ACCESS=1`, overriding a conflicting inherited
value. Missing/unknown classes, unaudited routes, token-refresh paths and
`not-read` routes cannot run. API-key-only helper platforms are not offered.

Browser-session tools appear in a separate **unchecked advanced group** and are
never selected or enabled by the standard confirmation, even through a numeric
selection. Use `modelplan connect <tool> --browser-session` for one provider.
That command explains the macOS browser **Safe Storage** prompt (the key unlocks
that browser's saved sign-ins) and CodexBar's session-cookie cache in its own
Keychain item, then asks once. Its JSON form is only a preview. Passive/off
privacy cannot enable it. Detection never scans browser profiles or stores.
The `/usr/bin/security` rule applies to our own readers; the signed CodexBar
helper may use its own Keychain access under this separate grant.

Every confirmation and preview names destination hosts and the selected native
region/key-variable name, never the key value. Existing native region choices
are shown and retained by the detected-tool chooser. Native host capabilities
come from the compiled reader; helper host metadata follows the pinned upstream
provider documentation. Unknown destinations remain unavailable until FEEDFIX
supplies their capability metadata; no destination is guessed. Host labels are
display metadata, never instructions to send a credential to a remote URL.
Legacy `connect <provider>` uses the same preview/confirmation contract and
starts no refresh or detached work. `connect --json` never saves a grant.

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
fail closed. Existing explicit native connections remain available until revoked;
legacy helper settings still require an audited current access class and cannot
acquire browser permission. Catalogue consent never silently broadens them.

`~/.config/modelplan/consent.json` (schema 1, mode 0600) is shared across copies.
Per-tool records contain allowed/refused, consent-text version, timestamp,
logical reader/backend and optional opaque profile descriptors. Source denials
survive disconnect, reconnect, restart and updates. Keychain Deny is never
automatically retried; only a future explicit Settings Retry may clear it. This
PR adds no Keychain value adapter. Unknown consent-text versions cannot admit a
reader. Consent text version 2 excludes browser access from the standard grant.
Schema-1 records add explicit browser-grant and pending-cookie-cleanup flags;
the latter persists after revocation until cleanup succeeds. Kernel locks release
on process termination; atomic replacement serializes state changes. Reader
admission precedes provider selection and collection, and generation validation
and cache publication are serialized with consent changes. A paused refresh
cannot publish after revocation; a paused statusline input is admitted only after
input parsing. Local performance and quota-history writes use the same fences.

Catalogue routing cannot grant consent. `preferred: off` stops new reads;
`codexbar.audited: false` blocks the helper, including explicit legacy connections
when the publication names that provider. Newly consented helper routes require a
currently verified, audited `preferred: codexbar` entry. Native routes never
automatically fall back to CodexBar for head providers. `minCli` gates admission
after consent. FEEDFIX retains routing/reader implementation ownership. Shared
refresh functions add framework admission/publication guards and the helper's
access-class environment; provider HTTP/auth implementations remain untouched.
`quota.Paths` supplies the invocation version and permitted reports carry a
non-JSON generation for downstream cache writers. Beta is catalogue metadata and
fixtures cannot clear it.

`modelplan disconnect <tool>` or `--all` revokes first, disables legacy connections
and removes only that tool's ModelPlan-owned readings. It filters native/helper
snapshots, cycles/pace, tagged speed/performance history and keeps other tools and
attempt gates. ZCode/OpenCode's stored `zcode`/`opencode` source aliases map to
their `zai`/`opencodego` consent IDs. Owner-tool logs and credentials are never deleted. Reader/cache
locks prevent cleanup racing writers. If busy, revocation remains saved and the
command reports cleanup failure; retry disconnect to finish deletion. FEEDFIX's
future router must use generation checks and cancellation/purge hooks for new
cache formats. Rollback never resets grants, denials or provider call budgets.

For a browser-session grant, Forget also executes the pinned helper's fixed
`cache clear --cookies --provider <id> --format json` operation. It never clears
all providers, performs usage reads or downloads a helper during cleanup. A
missing helper or failed cookie deletion reports incomplete cleanup and retains
the marker for an explicit retry; other providers' cookies stay untouched.
The operation and provider scope are defined by upstream
[CLICacheCommand.swift](https://github.com/steipete/CodexBar/blob/ee890b5f392e70d6e20162d3e95cf9f1be265b60/Sources/CodexBarCLI/CLICacheCommand.swift).
Qwen export status paths also honour off/revocation before opening an export.

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

标准 CodexBar 路径需经审核，并强制关闭钥匙串访问；只允许工具自身登录或不消耗额度的
只读 CLI 命令，不刷新 token。浏览器会话放在单独的高级未勾选组，标准确认绝不启用；
用 `connect <工具> --browser-session` 单独查看 Safe Storage 和 CodexBar cookie 缓存说明并确认。
忘记读数会按提供商清除该 cookie 缓存，失败则保留待清理标记以供显式重试。
JSON 只预览，连接不触发读取或后台工作；确认前列出接收凭据的主机和所选地区。
