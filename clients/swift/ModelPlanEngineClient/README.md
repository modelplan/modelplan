<!-- SPDX-License-Identifier: MIT -->
# ModelPlanEngineClient

Standalone Swift transport for the local `modelplan app-server`, using the
producer-generated `ModelPlanWire` package. `ProcessEngineClient.start()` launches
the ordinary executable and performs the real handshake. UI state belongs to the
consumer; this package owns sessions, ordering, consent gating and supervision.
`CredentialAgent` is a protocol only. The native app supplies its OS adapter.

## Use

Add `.package(path: "path/to/clients/swift/ModelPlanEngineClient")` and import
`ModelPlanEngineClient` and `ModelPlanWire`.

```swift
let client = ProcessEngineClient(
    configuration: EngineClientConfiguration(
        executableURL: engineURL,
        applicationVersion: appVersion,
        allowedEnvironment: ["HOME": home, "TMPDIR": temporary, "PATH": path]),
    initialFloor: lastCommittedFloor,
    credentialAgent: credentialAgent,
    consumer: consumer)
let context = try await client.start()
// Responses arrive through consumer.consume; this only acknowledges delivery.
_ = try await client.consent()
await client.stop()
```

The executable receives `app-server`, optionally `--offline` and `--read-only`.
The environment is explicit, with required HOME/TMPDIR. `validateConfiguration`
uses `WireChildEnvironment.allowedKeys`, generated from Go supervision's
`ChildEnvironmentKeys` into ModelPlanWire and
`schema/app-cli/child-environment.json`; there is no handwritten Swift key list.
No host environment is inherited. Do not put credential
agent tokens there. Sources/ModelPlanEngineClient/Interface.swift lists the public
protocols/events/errors; Values.swift contains immutable metadata/configuration.

## Delivery contract

`EngineClientEventConsumer.consume` is the sole serial private-value path.
Returning acknowledges application during that delivery turn. On
`clearPrivateViews`, clear private rows, history, derived caches and cockpit state
before returning. The client waits for this acknowledgement before admitting a
new context/value and rechecks queued delivery revisions immediately before
calling the consumer. RPCs return `EngineRequestCompletion` only after their
response event is acknowledged. That completion is neither a grant receipt nor
current authorization; never use a separately resumed Task to publish values.

The consumer **must not await another client RPC inside consume**. Its response
would need the same consumer. Start follow-up requests outside that turn. Pipe
drainage and internal controls continue while consume is suspended. A callback
stalled for 30 seconds closes the child, retires requests and schedules a sticky
clear. No concurrent callback starts if non-cooperative consumer work remains.
Retry is refused until that work returns and the clear is acknowledged.

Epochs use equality only. Generations order within an identical epoch. Session
IDs fence every frame; one sequence high-water mark fences snapshots/updates.
An unfamiliar epoch clears immediately, then a fresh correlated internal
`consent/get` confirms the active epoch while delivery is gated. Replay receipts
cannot confirm it. Failed confirmation leaves views cleared; sentinel/unavailable
contexts cannot replace a committed floor. Retired epoch bookkeeping is bounded
and triggers a controlled reconnect when full.

`EngineClient.isCurrent(_:)` is synchronous and safe from any thread, including
an OS credential callback. It compares the entire package-issued context:
session, equality-only store epoch, generation and revision. It reads a locked
value owned by the transport, rather than a possibly delayed UI snapshot. A
cached initial floor is not current. A context becomes current only after the
authoritative handshake/floor and the matching private-clear acknowledgement;
revoke, uncertain/superseded epoch, disconnect, stop and protocol failure withdraw
it before waiter completion or clear delivery. A new handshake cannot revive an
old session, and a late clear acknowledgement cannot revive a stopped client.

Use this as a point-in-time veto before credential work and again before using
its callback. A true result does not grant consent, validate an action/deadline,
reserve future validity or cancel an OS call. The credential agent still checks
the operation's scope and action; the client independently rejects stale results.
The native constructor/OS adapter supplies the callback wiring.

A historical same-epoch receipt is transaction metadata with its actual
`committedGeneration` and original epoch. It never lowers the floor, restores
facts or authorizes prompting. `supersededByLaterConsent` is recalculated before
dispatch. Different-epoch receipts require reconciliation. On restart/cancel,
each pending request gets one terminal disposition: sent grants without a
validated receipt report `mutationOutcomeUnknown`; validated commits interrupted
before acknowledgement report `receiptDeliveryInterrupted` with the known stamp.
Neither is successful delivery. Full receipts require event consumption or an
explicit idempotent replay. No mutation or old cursor is automatically replayed.

## Transport and credentials

UTF-8 JSON-RPC frames use LF with an 8,388,608-byte cap including LF. Partial EOF,
invalid UTF-8, invalid envelopes and framing overflow terminate that session.
Integer/string IDs retain exact identity. Default deadlines are 30 seconds;
cancellation sends bounded `$/cancel` notifications. Ordinary requests, query
reservations, data/control queues, writes and consumer callbacks are bounded.
Rows may coalesce after header observation; required control overflow closes the
session. A malformed feature result fails that feature without clearing healthy
rows. Raw frames/stderr/tokens are never included in events, errors or logs.

Initialize errors and deadlines complete every pending start with a terminal
failure and retire the child through supervision, even if the peer stays alive.
Failed initialization counts toward backoff; later starts use a fresh handshake.
Each launch has a new handshake session ID. Restarts preserve the consent floor,
retire credentials and use 1/2/4/8-second delays; the fifth crash within ten minutes
stops until explicit retry. Protocol-major mismatch stops without retrying the
same incompatible configuration. Stop closes stdin, then bounds termination and
reaping; failed cleanup blocks another spawn. Broken writes do not change the
host process's SIGPIPE handler. The ordinary engine also exits on stdin EOF.

Interactive credential work requires a one-use `EngineUserAction` bound to the
exact grant payload/request ID, scope, session and expected epoch, then its actual
validated committed receipt generation. No generation is guessed. A request
arriving before the receipt waits without prompting. Ambiguous concurrent
actions fail closed. Background operations have no user action and must never
prompt. Revoke/reset/disconnect/expiry logically cancel work; the bounded provider
worker remains occupied until a non-cancelable OS call returns. Late, mismatched,
expired or oversized token results are discarded or converted to typed failure.
Tokens travel only through the private `credentials/result` writer.

`publication()` and `pluginInstall` deliver generated `WirePublicationResult`
and `WirePluginInstallResult` values through the sole response event path.
Publication metadata/containers are typed; the producer deliberately retains
extensible published verdict objects as JSON leaves, preserving nulls, unknown
fields and exact integer values rather than creating a second Swift publication
schema. The result root is never an arbitrary `WireJSONValue` response.

`cockpit(timeout:)` sends the fixed empty-params `cockpit/query`, delivering
`WireCockpitData` with its validated envelope/scopes. Cockpit and history share
two query slots, bounded data reservations, cancellation and the same acknowledged
clear/revision/authoritative-epoch barriers. Late revoked/reset results cannot
reopen private views. All three feature methods require their negotiated capability.

Plugin result `tool` must match the request. Generated validation rejects unknown
installation statuses and inconsistent completed-step counts. A failed/instructions/
planned receipt is delivered as that status, not an assertion that installation
succeeded; completion only acknowledges event delivery. Returned command vectors
are informational and must never be executed as arbitrary shell source. The
installer only runs its own fixed commands. A sent install interrupted by
restart/cancellation/deadline reports an unknown outcome and is never replayed.

## Verification

Build the ordinary engine and the separately labeled test-only pipe proxy:

```sh
mkdir -p .tmp
(cd cli && go build -o ../.tmp/modelplan ./cmd/modelplan)
go build -o .tmp/frame-proxy clients/swift/ModelPlanEngineClient/Tools/FrameProxy/main.go
MODELPLAN_ENGINE_TEST_BINARY="$PWD/.tmp/modelplan" \
MODELPLAN_ENGINE_TEST_PROXY="$PWD/.tmp/frame-proxy" TMPDIR="$PWD/.tmp" \
swift test --package-path clients/swift/ModelPlanEngineClient \
  --scratch-path .tmp/swift-build --jobs 2
node scripts/check-source-policy.mjs
```

The hosted workflow runs this package against the real CLI on Linux and macOS
(only Linux for drafts). Tests use isolated synthetic homes and no real OS
credentials. Direct cases cover handshake/EOF, external revoke/reset, actual
SIGKILL/backoff/crash stop, clear acknowledgement, restart dispositions and stop
during backoff. Framing tests cover the exact LF-inclusive limit. Labeled pipe
faults around the ordinary binary cover wrong sessions/sequences, overflow,
malformed feature bodies, higher-context errors, late canceled replies, failed
epoch confirmation, historical receipts and both credential/receipt orderings.
The proxy records method names and a token-presence boolean only; it replaces
synthetic success tokens with `not_found` before forwarding to Go, so these tests
do not exercise a live provider. Native signing/prompts/UI/package L2/L3 and
positive provider quota checks remain separate evidence.

ModelPlanWire and its captures are producer-owned. Regenerate their outputs
from Go after contract changes; never hand-merge generated files.
