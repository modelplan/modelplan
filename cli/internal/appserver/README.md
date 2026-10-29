<!-- SPDX-License-Identifier: MIT -->
# App-server

`modelplan app-server` serves newline-delimited JSON-RPC on the child's anonymous
stdin/stdout pipes. It starts before ordinary command/store initialization. The
transport owns the pipes, handshake, session envelopes, request deadlines,
cancellation, row subscription sequencing and bounded outbound queues.

The production constructor currently uses `UnavailableBackend`: it performs no
home, credential or network I/O, reports `consent_unavailable` health, exposes
readers-off rows and advertises only rows and diagnostics. Consent and credential
production wiring awaits the shared U2 schema-2 implementation. A grant is not
reported as committed by this placeholder. This stage does not complete U3.

## Wire contract

`wire` is the source of truth for JSON names, optional fields, nullability,
enums and flow-control limits. It implements the frozen [protocol](https://github.com/modelplan/modelplan/blob/3306b85d474b3c696aafa078626ff8f147b72c39/schema/app-cli/app-server.md).
`wireschema` generates `schema/app-cli/app-server.json` from those production
DTOs and typed enum constants:

```sh
cd cli
go run ./internal/appserver/wire/cmd/schema
go run ./internal/appserver/wire/cmd/schema --check
go test ./internal/appserver/...
go test -race ./internal/appserver
```

Required pointer fields encode explicit null; `omitempty` fields may be absent.
`HistoryItem.model` is nullable. Consent context appears only in the envelope;
`wire.Project` strips the standalone projection's duplicate generation without
changing the standalone command contract. `credentials/result.accessToken` is
the sole token field, legal only for a successful credential outcome.

## Shared backend and handlers

`Backend.Get` returns an immutable, generation-fenced view. `Grant` takes the
expected epoch/generation and returns a durable receipt, including a committed
receipt when cancellation or cleanup follows the commit. `Publish` checks the
stamp atomically with a bounded enqueue callback; pipe writes never hold the
store lock. Data is checked again against the shared stamp before writing.
`Changes` triggers a current-state reread; events coalesce without losing a
change that arrives during an earlier reread.

The backend owns consent, migration, receipts, reader admission, publication
fences, budgets and shared-store synchronization. The transport does not create
a second store. `CredentialReceiver` repeats admission/fence/budget checks before
in-memory use. Operations are bound to their session, generation and expiry,
consumed once, and limited to one per provider. Background requests are
non-interactive; foreground requests arise only from an explicit Keychain grant.

`Handler` is the seam for the refresh/plugin and cockpit/history units. Results
carry their admission stamp; private queries also carry scopes. Results are
reserved before admission, and stale results produce `consent_changed` without
items. A query failure does not mutate rows.

## Bounds and supervision

There is one writer. Control messages precede queued data and are not coalesced.
One of the 64 data slots is reserved for the latest coalesced row snapshot; the
remaining slots hold reserved/query results. A blocked writer closes the session
at the production ten-second timeout. The reader bounds both frame length and
backing-array capacity, and rejects an excess byte without waiting for a newline.
Inherited Unix pipes are wrapped as pollable nonblocking duplicates so close
interrupts an outstanding read/write.

`RestartDelay` and `ChildEnvironment` express the supervision contract. The
native launcher must additionally use a new session for each child, close
unrelated FDs, drain both output streams, close/reap the child, preserve its
committed generation floor and stop after a protocol mismatch or five crashes
in ten minutes. These helpers do not prove native process supervision.

## Evidence scope

The tests build the real CLI and exercise handshake, readers-off rows,
diagnostics, shutdown, EOF, protocol mismatch and an oversized unterminated
frame over OS pipes, using a temporary synthetic home with no runtime tools.

A synthetic backend exercises row membership/sequence, late queries and
credentials, caps, cancellation/deadlines, committed receipts, control priority,
coalescing and the stopped-reader scenario at the production ten-second timeout.
Its replay assertion proves the transport seam, not shared-store durability.
Schema tests validate actual Go encodings through concrete wire decoding and
reject incompatible mutations.

U2 integration, real shared-store revoke/Forget races, real-binary invariants
1–11 as a complete set, the final backpressure acceptance with U2, generated
Swift decoding, native supervision and native L2 remain pending. Existing
standalone app/CLI captures continue to have their own contract gate.
