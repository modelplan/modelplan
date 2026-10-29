<!-- SPDX-License-Identifier: MIT -->
# App–CLI contract

These Draft 2020-12 schemas describe the public helper boundary. `commands.json`
is the full argv inventory from `desktop/native/Sources/ModelPlanCore/CLITransport.swift`
and the CommunityApp helper diagnostic. Connections and reader diagnostics are
included for the Settings/support boundary; the current app transport does not
invoke them. Plugin installation is reserved for the Settings integration being
added by the app owner; its existing production CLI command is covered here
before that integration lands. `common.json` contains shared definitions.

| Command | Schema | Collection / side effects |
| --- | --- | --- |
| `desktop --json` | [desktop.json](desktop.json) | Returns cached/local observations; online polls can schedule due readers and update derived history. |
| `desktop --json --read-only` | [desktop.json](desktop.json) | Cache/presence only; starts no refresh and writes nothing. `--offline` also starts no refresh. |
| `consent --json` | [consent.json](consent.json) | Cache/presence only; neither grants nor refreshes. |
| `consent grant --json` | [stdin](consent-grant-request.json), [stdout](consent-grant-response.json) | Atomic generation/text-version checks and replay receipts; denial revokes before scoped cleanup. No provider contact. |
| `detect --json` | [detect.json](detect.json) | Presence only, without credential values, reader execution or writes. |
| `publication --json` | [publication.json](publication.json) | Synchronously checks public data (30-second bound), then returns verified cache. |
| `publication --json --offline` | [publication.json](publication.json) | Verified cache only, no sync. |
| `quota --refresh-account --quiet` | [refresh-account.json](refresh-account.json) | Explicit synchronous Codex runtime refresh, consent gated. The app ignores stdout. |
| `plugin install claude-code --json` / `plugin install codex --json` | [plugin-install.json](plugin-install.json) | Explicit foreground host marketplace commands; host output goes to stderr. |
| Same plugin commands with `--offline` | [plugin-install.json](plugin-install.json) | Plan only; no host lookup, execution or network. |
| `--help` | [help.json](help.json) | Human text, no collection. |
| `connections --json` | [connections.json](connections.json) | Cached status/presence only. |
| `connections` | [connections-text.json](connections-text.json) | Human presentation of the same status, not JSON. |
| `doctor readers --json` | [doctor-readers.json](doctor-readers.json) | Cached diagnostics only. An explicit `--refresh` is foreground collection. |

Each command schema's `x-behavior` records network, credentials, writes, exit
codes and display/machine distinctions. These annotations are documentation;
JSON Schema validates shapes, while real-command tests enforce state and side
effects. Nonzero exits are never silently treated as successful data. JSON
schemas for text-only commands describe a JSON string containing their stdout;
the manifest records the actual transport encoding and exit code separately.
An empty stdout on failure is likewise represented as a JSON string, not an
invented JSON error object.

## Plugin installation

The actual command path is `cmd/modelplan.run` → `pluginCmd` in
`cli/cmd/modelplan/plugin_install.go` → `plugininstall.Install` in
`cli/internal/plugininstall/install.go`. The result always has
`schemaVersion`, `tool`, `status`, `commands`, `completed` and `docs`; the
[schema](plugin-install.json) defines every field, fixed argv/docs and progress
constraints, without changing command behavior.

| `status` | Exit | `completed` | Existing meaning |
| --- | --- | --- | --- |
| `installed` | 0 | 2 | Both host commands returned success; no independent verification. |
| `instructions` | 0 | 0 | Host executable missing; return the same commands and docs for manual use. |
| `planned` | 0 | 0 | `--offline`; no host lookup or execution, even when a host is present. |
| `failed` | 1 | 0 or 1 | First or second host command failed; no later step and no rollback. |

A host-present manual-step error is **failed**, not instructions. There is no
separate manual-required status. A host that exits successfully despite printing
manual guidance still yields installed. M4 should decode the result and inspect
the exit status; host text on stderr is not a structured app status. Usage errors
exit 2, with no JSON stdout. Real online installs may use host-managed network,
credentials and configuration; only an explicit install invocation runs them.

The existing generator builds the real CLI from this checkout and invokes both
supported commands in ten separate synthetic homes, using the same manifest
provenance, raw schema validation and uncached drift gate as other app commands.
Only the fake host tools run; they record fixed argv, emit synthetic progress and
return success/failure, with no network or real plugin/config installation.
The tests assert exact command prefixes, stdout/stderr separation, completed
counts, stopping on failure, no host invocation for planning/missing-host cases,
and no ModelPlan cache or configuration writes. Plugin outcomes use `state: fresh`
because each starts in a fresh home; filenames distinguish installer outcomes
from the separate consent/quota lifecycle.

For each of `claude-code` and `codex`, these actual-binary captures are committed:

| Filename suffix after `fresh-plugin-install-<tool>-` | Synthetic condition |
| --- | --- |
| `installed.json` | Both fake host commands succeed. |
| `instructions.json` | Requested host absent from the isolated PATH. |
| `planned.json` | Fake host present; `--offline` must not invoke it. |
| `failed-first.json` | First fake host command errors; second is not invoked. |
| `failed-manual-step.json` | First succeeds, second requests a manual step and errors. |

`plugin_install_test.go` compares the schema's serialized fields/types/required
set against the real Go `plugininstall.Result` and its status enum against every
production status assignment. It also requires a capture for every tool/status.
No parallel handwritten positive result set is introduced. M4's new typed
Settings service/decoder tests should load these files via the existing
`GeneratedAppCLIFixtures` loader and use the corresponding manifest exit code.

插件安装契约覆盖两个宿主的真实 CLI 输出；缺少宿主返回 `instructions`，
宿主命令失败返回 `failed`，`--offline` 返回 `planned` 且不执行宿主。
样例仅在合成 HOME 中运行假宿主，不安装真实插件、不访问网络。

## Retired consent records

The same-checkout binary generator also captures `retired` (real grant, catalogue
retirement, rejected re-grant, revoke receipt, then readback) and `retired-legacy`
(a synthetic persisted grant with no reader/backend metadata, rejected re-grant,
revoke receipt, then readback). Every raw command response is schema-validated
before normalization; read-only views must leave the synthetic home unchanged.

A retired record's `readerId` is logical display/revocation metadata. If its
stored route is missing or invalid, the CLI emits `native:<toolId>` without
persisting that fallback or claiming reader availability. New grants still
require current detection. The backend enum includes `codexbar-compat` as a
compatibility alias; the CLI normalizes persisted alias values to `codexbar`.

退役授权的样例覆盖真实 CLI 的授权、目录移除、拒绝重新授权、撤销回执与读回，
也覆盖缺少旧读取器元数据的记录。显示用的回退标识不写回授权，也不允许新授权。

## Scheduling and consent

A normal desktop poll returns its current snapshot before detached work finishes.
After consent, a native reader with no attempt is due immediately. The next poll
starts one cross-process-locked native worker, and a later poll sees its result.
Native provider requests retain the five-minute minimum attempt floor, provider-specific
intervals, budgets, backoff and generation fences; polling faster does not make
requests faster. Unreadable readers are reported with empty readings and a reason,
not fabricated values. The separate scheduled Codex account path waits five
minutes after success and thirty after failure. The explicit app account-refresh
command bypasses that due check; the app spaces calls by 300 seconds and the CLI
locks overlapping refreshes. Background Keychain reads are non-interactive and bounded
to about two seconds. Read-only/offline paths start nothing.

`allowed` in a consent readback is saved standard permission, not proof of a login
or current admission. Catalogue/privacy restrictions still apply. The grant
receipt is not current permission: reread consent after mutation. A nonzero
`cleanup_pending` receipt with a matching request and committed generation means
denial is committed but deletion needs a retry. A replay can retain an older
receipt shape without additive `hostDetails`.

Use IDs, enums, booleans, timestamps and observations as machine values. `hosts`,
`notice`, `nextStep`, names and human reasons are display strings. Native reader
failures expose optional `sources[].errorCode` (also `connections[].reading.errorCode`
in the connections command), with the bounded vocabulary in
`common.json#/$defs/readerErrorCode`. Native failure reasons and desktop
`connections[].quota.reason` use these same machine codes; doctor readers
includes the code in `unavailable:reader_error:<code>`. Raw errors are never part
of that contract. The unreadable synthetic runtime yields `parse_error`. Only
`hostDetails[].host` supplies bare DNS metadata, never a URL or a permission to
contact that host. The existing display labels remain unchanged.

## Generate and verify

From the repository root (Go 1.24 on PATH):

```sh
make app-cli-fixtures
make app-cli-contract-check
cd cli && go vet ./... && go test ./...
```

`cli/internal/appcontract` builds the actual CLI from this checkout and executes
all inventory commands in separate synthetic homes. It validates raw stdout
before normalization and compares every generated file byte-for-byte. It never
uses the caller's homes, credentials or provider runtimes. Inert CLI presence
markers cover the connection reporter's PATH and absolute-install probes, so
developer and hosted-runner tool installations cannot affect captures. A synthetic cached,
content-addressed public graph avoids public-network dependencies. The generator
itself serves synthetic Copilot metadata JSON-RPC and fixed installer replies;
it has no inference, real installation or sign-in methods. No test flags are added to the shipped CLI.

States: **fresh**, **consented**, **refreshed**, **unreadable**, **revoked**, and
**cleanup-pending**. Refreshed data is produced by the real desktop's detached
worker, rather than a prefilled native cache. Stale-generation and unknown-tool
errors are captured from actual grant requests; a missing public cache captures
publication exit 3 with empty stdout. Read-only commands are checked
for filesystem changes. Claude is detected but ungranted so these captures
never touch an OS Keychain. Codex is granted through the API, but its runtime
is disabled in this suite; existing scheduling tests cover that separate worker.

Only nondeterministic presentation is normalized: synthetic home paths become
`$HOME`; the report clock moves to `2030-01-02T03:04:05Z`, with relative timestamp
and day offsets retained at minute precision; elapsed ages become zero; fixed
future reset countdowns move with the clock. Authored publication/reset instants
are retained. Derived `dataRevision` is recomputed after normalization. The CLI
build version is fixed to `1.0.0` to keep release labels out of captures. No
permissions, hosts, states, quota values, errors or arbitrary fields are removed.
The first asynchronous desktop response is validated but not committed as a
fixture because collection may finish on either side of that response.

`fixtures/manifest.json` records each command, state, schema, encoding, real exit
code and stderr, and pairs mutation stdout with its stdin file. Do not edit
fixture JSON by hand. Review regenerated diffs with schema and consumer changes.
The standard hosted CLI CI job also runs `make app-cli-contract-check` explicitly,
so Go test caching cannot skip regeneration when only production command code
changes. The normal Go suite includes conformance as well.
The existing hosted macOS Swift jobs run these two new fixture-consuming targets:

```sh
swift test --package-path desktop/native --filter GeneratedDecoderTests
swift test --package-path desktop/native/ModelPlanAppIntegration --filter GeneratedConsentPortTests
```

## App test migration / M4 handoff

Current positive cases now load this directory directly in:

- `desktop/native/AppCLIContractTests/GeneratedDecoderTests.swift`: production desktop, consent, detection and publication decoders, every state and transport argv.
- `desktop/native/ModelPlanAppIntegration/AppCLIContractTests/GeneratedConsentPortTests.swift`: real consent port, Settings projection, matched success/error/cleanup receipts.
- `desktop/native/CommunityHostTests/ConsentPreviewTests.swift`: current readback and fail-closed mutations.
- `desktop/native/CommunityHostTests/ConsentGatedDesktopTransportTests.swift`: current generated canonical admission, with explicit negative mutations.
- `desktop/native/ModelPlanAppIntegration/Tests/ModelPlanAppIntegrationTests/CLIConsentPortTests.swift`: matched receipt plus deliberate malformed mutations.
- `desktop/native/ModelPlanAppIntegration/Tests/ModelPlanAppIntegrationTests/ConsentHostDisplayTests.swift`: generated base for deliberate legacy/structured host forms.

The semantic/fault mock also now uses generated bases in
`desktop/native/ModelPlanAppIntegration/Tests/ModelPlanAppIntegrationTests/ConsentCoreQ2Tests.swift`:
`consented-consent.json` / `revoked-consent.json` supply the base for Claude
semantic/fault mutations and `cleanup-pending-revoke.json` supplies the matched
committed cleanup receipt. Its intentional fault and request-ID matching remain.
M4 can extend these exact files when adding app behavior; do not introduce a
second current positive wire fixture set.
Typed Settings-domain fixtures are not wire captures. Frozen v1 and pinned
v0.5.43/v0.5.45 release captures intentionally remain historical compatibility
checks; they are not the source of current output expectations.

Every contract change updates its schema, generated fixtures, CLI conformance
and Swift decoder tests in the same PR. Additive compatibility stays allowed;
fixture drift still requires an explicit reviewed update.
