<!-- SPDX-License-Identifier: MIT -->
# ModelPlanEngineStoreCore

Portable accepted-event storage for U6, extracted from the native EngineStore at
`d894cf6` (#332). The Snapshot and FeatureFailure fields retain the donor's types
and meaning. The package depends on ModelPlanEngineClient and generated
ModelPlanWire through local package dependencies; it copies no DTOs or protocol
whitelists.

```swift
var core = EngineStoreCore()
let effect = core.apply(event)
let snapshot = core.snapshot
```

`apply` is synchronous and deterministic. It stores only events already admitted
by EngineClient. It has no I/O, tasks, transport, supervision, credential handling
or preference persistence. A clear resets every retained private field, including
context, grant metadata, errors and health, before returning
`.clearPrivateViews(invalidation)`. The connection state is preserved, as in the
donor. All other events return `.none`.

Only a context event changes the retained delivery context. A grant response
updates transaction metadata and the exact response request ID, never current
consent or context. A feature failure replaces only that feature's error; an
independent row snapshot remains intact. A successful feature result removes
only its own error. Rows and invalid-row counts are stored as delivered, without
reclassifying membership or interpreting protocol stamps.

## Native consumer boundary

The native owner retains the MainActor wrapper, weak sinks, actual client
construction and normal App/UI wiring. Its delivery turn must apply Core,
synchronously clear every private UI/cache sink when the effect requests it,
publish the current snapshot and only then return from `consume`. Calling Core
alone never acknowledges the delivery barrier. Session/epoch/generation/sequence
admission and that barrier stay solely in EngineClient.

The native facade can re-export this module or alias `EngineStoreSnapshot` and
`EngineStoreFeatureFailure` to these types while replacing its draft value
application with Core. This package does not edit or provide a second native
wrapper. Presentation policy, history surface routing and future typed Client
result contracts remain with their owning features.

## Verification

```sh
swift test --package-path clients/swift/ModelPlanEngineStoreCore \
  --scratch-path .tmp/store-core-build --jobs 2
```

Tests use the checked-in real Go captures through `WireDecoder`. Event-sequence
tables cover all donor fields, every clear reason, clearing before the returned
effect is handled, feature failure/recovery isolation, exact string/signed/unsigned
request IDs, historical receipts, and clear followed by a new context and rows.
The donor's native sink/acknowledgement and real-client-construction tests remain
native responsibilities; pure Core tests do not establish those boundaries.

The dedicated workflow tests Linux Swift and macOS on standard hosted runners,
with macOS starting when a draft is ready. Synthetic logs are uploaded before
owned scratch is removed. Stage: **interface only**; normal App entry, real child
execution through this consumer, native fanout and owner-shaped L2 are not-run.
