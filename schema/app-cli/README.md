<!-- SPDX-License-Identifier: MIT -->
# App–CLI contract

These Draft 2020-12 schemas describe the public helper boundary. `commands.json`
is the full argv inventory from `desktop/native/Sources/ModelPlanCore/CLITransport.swift`
and the CommunityApp helper diagnostic. Connections and reader diagnostics are
included for the Settings/support boundary; the current app transport does not
invoke them. `common.json` contains shared consent definitions.

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
`notice`, `nextStep`, names and human reasons are display strings. Only
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
uses the caller's homes, credentials or provider runtimes. A synthetic cached,
content-addressed public graph avoids public-network dependencies. The generator
itself serves only synthetic Copilot metadata JSON-RPC; it has no inference or
sign-in methods. No test flags are added to the shipped CLI.

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
