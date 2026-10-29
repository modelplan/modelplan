<!-- SPDX-License-Identifier: MIT -->
# ModelPlanEngineClient — interface only

This standalone Swift package proposes the app-side engine transport contract on
U4's local `ModelPlanWire` product. It contains value types, data constructors and
protocol requirements only. It does not spawn a process, parse frames, schedule
requests, enforce a floor, implement a credential agent or provide a working
client. No throwing/fatalError fake implementation is supplied.

M0 consumes the contract through EngineStore in U6. EngineStore owns UI state;
this package will own sessions, ordering, consent gating and supervision. M0
supplies Security.framework in U7 behind `CredentialAgent`.

## Proposed use

```swift
.package(path: "path/to/clients/swift/ModelPlanEngineClient")
```

Import `ModelPlanEngineClient` and `ModelPlanWire`. The public requirements are in
`Sources/ModelPlanEngineClient/Interface.swift`; metadata and configuration are
in `Values.swift`. A future `ProcessEngineClient: EngineClient` actor will accept
configuration, an initial committed floor, an optional credential agent and the
consumer. That actor and its constructor are deliberately absent at this stage.

The `EngineClientEventConsumer` is the single ordered data-delivery path. M0's
consumer clears private rows/history/derived caches/cockpit state on
`clearPrivateViews` before acknowledging it. Only afterward may the client emit
new context/data. RPC methods return `EngineRequestCompletion` after the consumer
acknowledges their typed `EngineResponse`, so an independently resumed Task cannot
publish an older private result after a clear. The consumer must apply events in
that delivery turn and must not build another asynchronous publication path.

Epochs use equality, never string ordering; generations order only within an
identical epoch. `EngineConsentFloor` has no Comparable conformance. Sequence is
session-local. Restarts preserve the floor but cancel old requests/cursors and
retire credential operations. A lost sent grant reports mutationOutcomeUnknown;
a lost plugin install reports interrupted(outcomeUnknown). No uncertain mutation
or cancellation is success, and there is no implicit mutation replay.

After signature confirmation, implementation will add UTF-8 JSON-RPC LF framing
with the 8 MiB cap (including LF), exact ids, bounded deadlines and $/cancel;
concurrent pipe drainage; fresh handshake sessions; 1/2/4/.../30-second restart
backoff; a five-crashes-in-ten-minutes stop; and bounded stop/close/reap behavior.
Credential tokens will travel only in credentials/result, outside events/logs.
Plugin/publication result bindings temporarily use generated WireJSONValue rather
than a second hand-written DTO schema. Capabilities gate unsupported methods.

## Stages and verification

1. Interface review: M0 confirms these signatures before any runtime work.
2. Wired implementation: test the package against the actual modelplan app-server
   on Linux and macOS, including framing boundaries, crash/backoff/EOF, wrong
   sessions, sequence races, external revoke/reset, clear acknowledgment ordering,
   mutation uncertainty and every pending request's cancellation on restart.

Fault injection uses labeled pipe/process/clock seams plus separate direct real-
binary cases. No production fixture switches, native app changes, live credentials
or broad inherited environment are introduced. Native signing/prompts/UI/final-
package L2/L3 remain distinct from these transport tests.

The interface currently consumes the reviewed U3b/U4 producer edge. When merging
later producer updates, regenerate owned Swift/captures from Go at their source;
do not hand-merge generated files. This package does not edit ModelPlanWire.

No runtime or real-binary test passes are claimed by this interface-only stage.
