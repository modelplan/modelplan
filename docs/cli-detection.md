<!-- SPDX-License-Identifier: MIT -->
# Presence-only CLI detection

`modelplan detect` (`--json` for integrations) checks installed/configured tool
signals. Detection does not establish sign-in, a subscription or remaining quota.
It reads no credential contents, launches no tool, makes no network request,
starts no background process and writes no cache. It works before the first sync.

The command consumes `detectorSchemaVersion`, `detectorRevision` and `detectors`
from the existing verified, cached `client.data` publication. Until these exist,
it uses a small built-in bootstrap for the clients' existing tools. FEEDFIX owns
the complete attributed seed, schema DTOs and readers. Publication sync rejects
malformed known catalogue fields before switching, keeping the last verified
publication. An owner-authorised rollback may select an earlier revision.

Entries carry `providerId`, `displayName`, `readerId`, `preferred`
(`native|codexbar|off`), `codexbar: {audited: bool, accessClass: standard|browser-session|not-read}`, `minCli`, `beta`,
`detectionStatus` and `signals`. Incompatible entries report `update-required`
before probing. Fixture tests never clear beta. Routing is descriptive here:
detection enables no reader and never introduces automatic CodexBar fallback.

The approved wire field is `codexbar.accessClass`; the unrecognised `access`
key cannot grant a route. An unaudited helper route, a missing/unknown access
class, or `not-read` is explicitly unsupported, with effective `preferred: off`
in the report. This does not prevent detection or admission of another provider. `standard` is eligible
for one-click consent only with an audit. `browser-session` needs separate,
per-provider advanced consent and never belongs to the one-click grant.
Detection never inspects browser directories, cookie stores or browser profiles.
The reader audit may permit a read-only provider CLI launch that consumes no
quota; detection still never launches that CLI. The `/usr/bin/security` rule
belongs to ModelPlan's own readers, not the signed CodexBar helper.

Signals are OR-ed. Initial evaluator forms and boundaries:

- `{"type":"path","value":".claude"}`: stat only beneath the current home;
  reject absolute paths, traversal, expansion and symlink escapes. Approved roots:
  `.claude`, `.codex`, `.zcode`, `.cursor`, `.copilot`, `.gemini`, `.kimi-code`,
  `.qwen`, `.kiro`, `.config/opencode`, and
  `Library/Application Support/{Cursor,Claude,Codex,ZCode}`. Claude/Codex root
  overrides inside the home are honoured; outside/inaccessible roots stay unknown.
  A root another tool shares is not a signal by itself: Gemini CLI is detected by
  `gemini`, `.gemini/oauth_creds.json` or `.gemini/tmp`, because Google
  Antigravity also creates `~/.gemini` (G3-104); Antigravity itself is detected by
  `antigravity` or `.gemini/antigravity`. Kiro is detected by `kiro-cli` only, the
  CLI its reader uses (the Kiro IDE alone also creates `~/.kiro`). OpenCode Go is detected from the
  OpenCode app (`opencode`, `.config/opencode`); that says nothing about an
  OpenCode Go subscription (G3-105). The subscription is found only by the existence
  of an `opencode-go` entry in OpenCode's own key store (an active `opencode-go` row
  in `opencode.db`'s `credential` table, opened read-only (not immutable, so committed WAL state counts) with a query
  that selects no value column, or an `opencode-go` top-level key in `auth.json`,
  scanned for key names only with the buffer zeroed afterwards) or a set
  `OPENCODE_API_KEY`. The key value is never read into a variable, stored, logged
  or sent (owner decision D230). Without it the `opencodego.account_usage.api_key`
  path is reported as not detected and Settings says "OpenCode installed · no
  OpenCode Go subscription found".
- `{"type":"command","name":"claude"}`: locate/stat a literal executable
  basename in absolute PATH/install directories, without running it or a shell.
- `{"type":"bundleId","value":"com.example.Tool"}`: silent OS-registration
  adapter boundary; unknown when no safe adapter is available.
- `{"type":"keychainItem","name":"Claude Code-credentials"}` or
  `{"type":"keychainItem","rule":"claude-config-dir"}`: typed fixed name or
  derivation rule, never a value query. The initial rule enum has only
  `claude-config-dir`. Without FEEDFIX's silent presence adapter this is unknown;
  this implementation never invokes Keychain or requests a grant.

Unknown signal types and rules (including unfamiliar future payloads) are ignored
without errors. Unknown-only entries never become detected. Malformed known
signals reject admission. No scripts, regexes, executable predicates or shell
expansions are evaluated. Limits: 256 KiB, 512 entries, 16 signals per entry.
Reports contain logical IDs and statuses, never matched paths or identities.

`modelplan detect` 仅检测工具是否存在，不代表登录、订阅或剩余额度。
不读取凭据内容（唯一例外：OpenCode Go 只检查 OpenCode 密钥库里是否存在 `opencode-go` 条目，不读取密钥值，D230）、不启动工具、不联网、不写缓存。使用已核验的本地公开目录；
尚未发布目录时使用内置回退。未知信号和规则被忽略；不能静默检查的信号保持未知，
版本不足的条目提示更新。
CodexBar 使用目录中的 `codexbar.accessClass`；缺失或为假的 `audited`、缺失或未知的
访问类别以及 `not-read` 均显示不支持，路由为 `off`，不影响其他提供商。
