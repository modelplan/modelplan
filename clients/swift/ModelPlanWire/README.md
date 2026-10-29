# ModelPlanWire (U4 interface)

A standalone Swift package containing the generated app-server DTOs and a decode
harness. It has no UI, transport, consent store, merge logic or engine-state store.
M0 owns process supervision, session/generation floors and feature isolation.
The producer start edge is U3's Go wire package and generated schema. This stage
can be consumed as a local Swift package without any native app changes.

```swift
.package(path: "path/to/clients/swift/ModelPlanWire")
```

Depend on the `ModelPlanWire` product, then decode the expected method's result:

```swift
import ModelPlanWire

let message = try WireDecoder.decode(
    WireSuccess<WireRowsSnapshot>.self,
    from: lineData
)
let rows = message.result.data.projection.rows
```

Do not render a decoded message before the app's state store checks its session,
store epoch, committed generation floor, scopes and subscription sequence. A
failed history decode must leave the independent rows projection intact; a
failed envelope identity/authorization check must reject the message. A row
semantic failure is isolated to an `invalid: true` placeholder with the original
stable id, order and surfaces; its accounts, values and actions are cleared.
Valid rows survive. The package never replaces the snapshot with an empty row set. It does not prove the state/floor
or native integration, which remain M0's work.

## One source and reproducible generation

From the repository root:

```sh
cd cli
go run ./internal/swiftwire/cmd --write
go run ./internal/swiftwire/cmd --check
go test -v ./internal/swiftwire/...
```

`cli/internal/swiftwire` reads the exported production DTO declarations in
`appserver/wire/{types,enums}.go` and the reachable row types, including JSON tags,
pointers, typed enum constants, slices, maps and generics. It also consumes the
producer's generated schema bounds. It exports no row-builder inputs or storage
types. Unsupported source forms fail generation. Prefixes `Wire` and `Rows`
avoid type-name collisions (for example the two `Failure` types).

`Generated.swift` is the production DTO decoder; do not hand-edit it. The support
template in the generator provides exact integer request IDs, RFC3339 timestamps,
JSON values, frame size checks and token placement checks. No Swift dependency
or plugin bundle is added. Public hosted CI verifies producer schema drift,
generator tests, Swift/capture drift and source policy.

Typed string enums have `.unknown(String)` and preserve future display values
on encode. A known raw value `unknown` uses the distinct `.knownUnknown` case.
Where the current Go producer declares a plain string, it stays a string unless
the producer schema already supplies its enum. Later typed-enum/bounds producer
changes must regenerate the package; this client does not invent those vocabularies.

## Decode policy

| Go shape | Swift behavior |
|---|---|
| Non-pointer without `omitempty` | Required; absent or wrong type fails |
| Schema-declared required-nullable field | Key required, null allowed (error request id) |
| Pointer | Optional; absent/null becomes nil, including without `omitempty` |
| Non-pointer with `omitempty` | Optional presence; absent/null becomes nil |
| Optional display field with a wrong type | Locally nil; row membership remains intact |
| Row semantic failure with a recoverable stable id | Invalid placeholder; healthy rows survive, no accounts/values/actions on the placeholder |
| Envelope identity/authorization failure or malformed frame | Whole message fails explicitly |
| Unknown display enum/field | `.unknown(String)` / ignored field |

Encoding preserves JSON-tag behavior: nil pointer fields without `omitempty`
encode explicit null; omitted fields encode only when present. Nullable history
`model` therefore survives missing/null/wrong-display-type inputs without losing
rows. Session/epoch/operation/scope identities must be nonempty and control-free;
account/subscription references follow the producer's 16-hex representation.
Malformed or ambiguous row identities, incompatible protocol/rows versions and
invalid envelope consent contexts reject the message. Within a row, semantic
identity/authorization failures produce a placeholder; standalone consent and
credential authorization failures remain explicit. Retired rows retain the
accounts the Go producer permits; denied, unset and cleanup-pending rows may
not carry accounts. The wire row
projection carries no consent context: it appears only in the envelope. Producer schema numeric bounds are generated
(for example history `limit` 1...500). Minor versions may extend display values.
The app still owns the committed floor and the checks across sessions.

Credential success requires an access token. A non-success cannot carry a token
or expiry, even null fields. Printable credential descriptions are redacted.
`WireDecoder` rejects token fields outside a direct credential result or the
`params` of a `credentials/result` request. Use this entrypoint rather than raw
`JSONDecoder` for incoming frames. No credential is logged or persisted. Canary
fixtures are synthetic test strings, never product credentials. The U3 producer's
Go logging redaction remains its separate responsibility.

## Real Go captures and mutation proof

```sh
cd cli
UPDATE_SWIFT_CAPTURES=1 go test -count=1 -v ./internal/swiftwire/...
cd ..
MODELPLAN_CAPTURE_DIR="$PWD/schema/app-cli/captures" \
  swift test --package-path clients/swift/ModelPlanWire
```

`Captures` marshals actual Go wire DTOs with deterministic synthetic values.
The additional `retired-with-account.json` is built by the production projector,
validated by `rows.Validate` and the wire schema, and retains a retired account
alongside a healthy tool. Semantic mutations of one row must preserve the other.
The additional `production-rows.json` passes through `rows.Build`, `rows.Validate`,
`wire.Project` and the real Go success/envelope encoding. `null-error.json` is
a real Go error with a null request id; this id accepts null but remains required. `index.json` enumerates 39 DTO roots
and 48 nullable/optional fields, with all omission/null/wrong-type expectations
(47 pointer/omitempty fields plus the schema-declared required-nullable error id). The Go
test writes the captures only under the explicit update flag and otherwise
rejects drift. Adding a reachable DTO without a capture root fails generation.
The decoder dispatch harness is generated from the same root registry.

The hosted macOS `swift test` job drives those encodings and every mutation
through the generated production decoder. Credential-success token removal is
an explicit negative control, even though the token is structurally optional.
The 17 strict nullable/optional fields fail on malformed identity/authorization types;
31 display fields degrade locally. History query `ref` and `cursor` are strict
identity/query bindings: a present wrong type is an error, never a lost filter. Raw JSON params accept legal JSON extension
values. Tests also cover required fields, future enums/fields, row ids, unknown
history models, duplicate rows, exact integers above 2^53, explicit null encoding,
protocol/version/generation failures, credential redaction and token canaries.

Swift is not available on the Linux development host. A successful Go generator
check is **not** Swift compilation or decoder proof. The hosted macOS test and
its uploaded synthetic evidence are the L1 Swift result. The full app, process
supervision, real providers and macOS UI remain separate integration/L2 work.

## Invalid row diagnostics

`WireDecoder.decodeWithDiagnostics` returns the decoded `value` and an
`invalidRowCount` for that call. `WireRowsProjection.invalidRowCount` exposes the
same count on the projection. The per-call counter never becomes a global latch;
M0 can add it to diagnostics without retaining rejected data or raw errors.

A placeholder's `RowsRow.invalid` is client-only metadata, not a wire field or an
authorization grant. Its fixed bilingual label and invalid-row reason carry no
provider values. It preserves the stable id/order/surfaces so other rows and
presentation preferences survive. Its accounts, expiry values, vendor binding
and actions are empty. Encoding a placeholder back to wire JSON throws; valid
rows keep the producer's normal encoding, without an `invalid` field. An
unrecoverable identity binding or structurally malformed payload still cannot
produce a safe placeholder and rejects the malformed frame. Envelope failures
are never swallowed by the row isolation boundary.
