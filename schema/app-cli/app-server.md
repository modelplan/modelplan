# `modelplan app-server` protocol (v1 sketch, revision 3)

Status: interface frozen on 2026-10-29 with foundation v2. Bodies are not implemented. After review, dedicated Go wire DTOs are the source of truth:

- field names;
- presence: `omitempty` means the field may be absent;
- nullability: a pointer may be null;
- enum sets and size limits.

The Swift types are generated from them. The numbers in "Flow control" are implementation choices and may change in review.

Related:
- design: [`docs/architecture/foundation-v2.md`](../../docs/architecture/foundation-v2.md);
- rows: [`rows-design.md`](rows-design.md).

## Transport

- JSON-RPC 2.0, one UTF-8 JSON object per `\n`-terminated line, on anonymous pipes for the child's stdin and stdout.
- stderr carries allow-listed log lines only and is never parsed.
- The app is the only client. The process exits when stdin closes, or after `shutdown`.
- Every request has a deadline and can be cancelled with `$/cancel { id }`.
- A response carries either `result` or `error`, never both.

## Envelope

The session and the consent context travel in one place: a wrapper around every result, every server notification's params, and every error's `data`. DTOs do not repeat these fields.

| Message | Envelope |
|---|---|
| Results and notifications | `{ sessionId, storeEpoch, consentGeneration, scopes?, data }` |
| Errors | `sessionId`, and `storeEpoch` and `consentGeneration` when known, in `error.data` |
| App requests | No `sessionId`, except `initialize`: the pipe is the session |

- `consentGeneration` is the generation the content was produced or admitted under, within `storeEpoch`, the consent store's random epoch (it changes only when a damaged store is reset). The app orders consent by `(storeEpoch, consentGeneration)`.
- `scopes` lists the consent scopes the content covers. It is set on results that carry private values: rows, history and cockpit.

Initialize:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"sessionId":"s-7f3a","protocolVersion":"1.0","appVersion":"0.6.0","capabilities":["rows","consent","credentials"]}}
{"jsonrpc":"2.0","id":1,"result":{"sessionId":"s-7f3a","storeEpoch":"e-91c2","consentGeneration":41,"data":{"protocolVersion":"1.0","serverVersion":"0.6.0","capabilities":["rows","consent","credentials","refresh","plugin_install"]}}}
```

Success with private values:

```json
{"jsonrpc":"2.0","id":7,"result":{"sessionId":"s-7f3a","storeEpoch":"e-91c2","consentGeneration":41,"scopes":["claude.local_history"],"data":{"items":[{"at":"2026-10-29T13:00:00Z","model":null,"tokens":1200,"window":null,"value":null}],"nextCursor":"c1.opaque"}}}
```

Error:

```json
{"jsonrpc":"2.0","id":8,"error":{"code":-32023,"message":"consent_changed","data":{"sessionId":"s-7f3a","storeEpoch":"e-91c2","consentGeneration":42}}}
```

Notification:

```json
{"jsonrpc":"2.0","method":"rows/changed","params":{"sessionId":"s-7f3a","storeEpoch":"e-91c2","consentGeneration":42,"scopes":["claude.local_history","codex.runtime_usage"],"data":{"sequence":18,"projection":{}}}}
```

## Sessions and ordering

- **Session id.** The app generates a random `sessionId` before it starts each child, and passes it in `initialize`. The app drops any message whose envelope carries another session.
- **Sequence.** `sequence` orders `rows/changed` within one session only. `rows/subscribe` returns the current projection with its `sequence`. The app then drops any notification in the same session whose sequence is lower or equal.
- **Generation floor.** The app keeps a committed consent-generation floor across sessions, and a new session never lowers it. The app drops any projection, query result or consent fact older than the floor.

## Flow control

- **Frames.**
  - The reader scans input incrementally. A line that passes 8 MiB with no terminator is rejected at once; the reader never buffers past the limit.
  - A bad or oversized frame is a protocol error, and the receiver ends the session. The app treats a bad frame from the server as a crash and restarts it under supervision.
  - Nothing is truncated.
- **Outbound classes.** There is one writer per direction, with two queues.
  - **Control**, always sent first: consent receipts, `consent/changed`, `credentials/request`, `engine/health` and errors. It is never coalesced or dropped while the connection is up.
  - **Data**: `rows/changed` and query results. `rows/changed` coalesces to the latest snapshot.
- **Caps.** Over a cap, a new request gets `busy` at once and is never queued.

  | Cap | Limit |
  |---|---|
  | In-flight app requests | 16 |
  | In-flight history or cockpit queries | 2 |
  | Open credential operations per provider | 1 |
  | Queued data messages | 64 |

  | Queued control messages | 256, or 4 MiB |
  | Write timeout for one frame | 10 s |

  - **Data queue full.** New query requests get `busy`, and `rows/changed` keeps only its latest snapshot. A query is admitted only while a result slot is reserved for it, so a query that has started always has room for its result.
  - **Control queue full, or write timeout.** The writer is stuck: the receiver has stopped reading. The server ends the session rather than drop a control message, and the app recovers by receipt replay and `consent/get` after the restart.
  - **Scheduling in the server.** Revoke, Forget, `$/cancel` and `credentials/result` are admitted ahead of queued queries and never get `busy`, up to the control limit.
  - **Acceptance.** The app stops reading. Two queries complete, a revoke arrives and health changes. The session ends within the write timeout, and after the restart the revoke receipt replays.
- **Disconnect.**
  - A receipt may be lost when the connection drops. After a restart, the app retries the same `requestId` and the stored receipt is replayed, or it calls `consent/get`.
  - A committed transaction is never undone by EOF or cancel.

## Versioning

- `protocolVersion` is `major.minor`.
- A different major is rejected with `protocol_mismatch`. The server exits, and the app does not restart it.
- A minor version adds methods, fields or enum values, announced in `capabilities`.
- The app decodes unknown enum values as `.unknown(String)` and ignores unknown fields.
- The app and its bundled engine ship together, so there is no multi-version negotiation beyond this.

## Methods

| Method | Direction | Purpose | Needed by |
|---|---|---|---|
| `initialize` | app → server | Handshake: `sessionId`, protocol version, capabilities | first candidate |
| `shutdown` | app → server | Flush and exit | first candidate |
| `rows/subscribe` | app → server | Current projection and sequence; starts `rows/changed` | first candidate |
| `rows/changed` | server → app | Full projection after a change (coalesced) | first candidate |
| `consent/get` | app → server | Per-scope consent facts | first candidate |
| `consent/grant` | app → server | Per-scope allow, deny and forget, plus Keychain decisions; idempotent by `requestId` | first candidate |
| `consent/changed` | server → app | Consent changed outside the app, for example from the CLI | first candidate |
| `credentials/request` | server → app | Ask the app to read a credential | first candidate |
| `credentials/result` | app → server | Outcome, and the token on success | first candidate |
| `refresh/request` | app → server | Ask for refreshes within the shared budget | first candidate |
| `plugin/install` | app → server | Same contract as `plugin install --json` | first candidate |
| `diagnostics/get` | app → server | Sanitized engine health and per-scope state codes | first candidate |
| `engine/health` | server → app | `ok`, `degraded` or `recovering`, with a code | first candidate |
| `history/query` | app → server | Paged history items for one scope; fenced, see below | cockpit |
| `cockpit/query` | app → server | Cockpit display data computed by Go; fenced, see below | cockpit |
| `publication/get` | app → server | Verified publication summary | cockpit |

## Sensitive queries

`history/query` and `cockpit/query` return private values, so:

- **Admission.** The engine admits the query under the current consent of every scope it touches.
- **Re-check.** After reading, it checks `(storeEpoch, generation)` again. If either moved, the answer is `consent_changed` with no items.
- **Envelope.** The result lists the scopes it covers and the epoch and generation it was admitted under.
- **Cursors.** A cursor is opaque. It is bound to the session, the scopes, the account reference, the store epoch and the generation, and a cursor from another epoch or an older generation returns `cursor_stale`.
- **App.** The `scopes` on a result tell what the content covers. They do not tell which scopes a consent change touched.
  - When any message arrives with a higher generation or a new store epoch, the app first clears **all** private views, derived caches and cockpit page values, and sends `CockpitBridge` a `clear`. Only then does it advance the floor. This applies to errors too.
  - The app then rebuilds the views only from results admitted under the new generation.
  - Acceptance: a Claude history page is open at g=41, and the CLI revokes Claude (g=42). A Codex result at g=42 arrives before `consent/changed`. The Claude page must be cleared when that result arrives.

## Type sketch (Go wire DTOs)

```go
// package appserver/wire — wire DTOs only. JSON tags are the contract.

type Envelope[T any] struct { // every result and server notification params
	SessionID         string   `json:"sessionId"`
	StoreEpoch        string   `json:"storeEpoch"`
	ConsentGeneration uint64   `json:"consentGeneration"`
	Scopes            []string `json:"scopes,omitempty"` // set on results with private values
	Data              T        `json:"data"`
}

type InitializeParams struct { // the only app request that carries sessionId
	SessionID       string   `json:"sessionId"`       // random, app-generated
	ProtocolVersion string   `json:"protocolVersion"` // "1.0"
	AppVersion      string   `json:"appVersion"`
	Capabilities    []string `json:"capabilities"`
}

type InitializeResult struct {
	ProtocolVersion string   `json:"protocolVersion"`
	ServerVersion   string   `json:"serverVersion"`
	Capabilities    []string `json:"capabilities"`
}

type RowsSnapshot struct { // rows/subscribe result and rows/changed data
	Sequence   uint64          `json:"sequence"`
	Projection rows.Projection `json:"projection"` // rowsVersion, rows (with route codes), rowsSummary; never filtered by app preferences
}

type ConsentScope struct {
	Scope          string  `json:"scope"`        // e.g. "gemini.account_usage.saved_login"
	Tool           string  `json:"tool"`
	Route          string  `json:"route"`        // "saved_login_api" | "runtime_rpc" | "local_log" | "api_key_api" | ...
	Detected       bool    `json:"detected"`
	Retired        bool    `json:"retired"`      // still listed, so it can be revoked
	State          string  `json:"state"`        // "allowed" | "denied" | "unset"
	DefaultCheck   bool    `json:"defaultCheck"` // first-run default for undecided users
	Keychain       *string `json:"keychain"`     // null when the scope needs no Keychain
	CleanupPending bool    `json:"cleanupPending"`
	Disabled       *string `json:"disabledReason,omitempty"` // e.g. "policy_pending" for a POST read awaiting approval
}

type ConsentFacts struct {
	Scopes []ConsentScope `json:"scopes"` // the generation is in the envelope
}

type ConsentGrantParams struct {
	RequestID        string            `json:"requestId"`       // replay is keyed by (storeEpoch, requestId)
	ExpectStoreEpoch string            `json:"expectStoreEpoch"` // a different epoch is rejected with consent_stale before any commit
	ExpectGeneration uint64            `json:"expectGeneration"`
	TextVersion      int               `json:"consentTextVersion"`
	Allow            []string          `json:"allow"`              // scope ids; subject to admission
	Deny             []string          `json:"deny"`               // revoke; always accepted for known or retired scopes
	Forget           []string          `json:"forget,omitempty"`   // revoke, and erase history and identity records
	Keychain         map[string]string `json:"keychain,omitempty"` // scope -> "allow" | "deny"
}

type ConsentReceipt struct {
	RequestID           string   `json:"requestId"`
	Committed           bool     `json:"committed"`
	CommittedGeneration *uint64  `json:"committedGeneration"` // set whenever Committed, also on cleanup_pending
	CleanupPending      []string `json:"cleanupPending,omitempty"`
	Code                string   `json:"code"` // "ok" | "cleanup_pending" | "stale_generation" | "stale_consent_text" | "rejected"
}

type CredentialRequest struct { // server -> app
	OperationID       string `json:"operationId"`
	Provider          string `json:"provider"` // "claude" in v1
	Scope             string `json:"scope"`
	Interactive       bool   `json:"interactive"` // true only after an explicit Settings action
}

type CredentialResult struct { // app -> server; the only message that may carry a token
	OperationID string     `json:"operationId"`
	Outcome     string     `json:"outcome"` // "ok" | "canceled" | "denied" | "not_found" | "interaction_required" | "timeout" | "error"
	AccessToken *string    `json:"accessToken,omitempty"` // only when Outcome == "ok"
	ExpiresAt   *time.Time `json:"expiresAt,omitempty"`
}

type RefreshRequestParams struct {
	Scopes []string `json:"scopes,omitempty"` // empty = all allowed scopes
}

type RefreshScheduled struct { // result; deferral is a normal result, not an error
	Scope          string    `json:"scope"`
	At             time.Time `json:"at"`
	DisabledReason *string   `json:"disabledReason,omitempty"` // "cooldown" | "read_only" | "offline" | "policy_pending"
}

type HistoryQueryParams struct {
	Kind   string `json:"kind"`             // "tokens" | "quota_cycles" | "sessions"
	Tool   string `json:"tool"`
	Ref    string `json:"ref,omitempty"`    // subscriptionRef or accountLocator
	Cursor string `json:"cursor,omitempty"` // opaque; bound to session, scopes, ref and generation
	Limit  int    `json:"limit"`            // 1..500
}

type HistoryItem struct { // new wire DTO; not an internal storage type
	At     time.Time `json:"at"`
	Model  *string   `json:"model"` // null when the model is unknown
	Tokens *int64    `json:"tokens"`
	Window *string   `json:"window"`
	Value  *float64  `json:"value"`
}

type HistoryPage struct {
	Items      []HistoryItem `json:"items"`
	NextCursor string        `json:"nextCursor,omitempty"`
}

type Diagnostics struct {
	ProtocolVersion string      `json:"protocolVersion"`
	ServerVersion   string      `json:"serverVersion"`
	UptimeSeconds   int64       `json:"uptimeSeconds"`
	Scopes          []ScopeDiag `json:"scopes"`
	LastErrorClass  string      `json:"lastErrorClass,omitempty"`
}

type ScopeDiag struct {
	Scope     string     `json:"scope"`
	State     rows.State `json:"state"`
	Code      rows.Code  `json:"code"`
	LastRead  *time.Time `json:"lastRead"`
	NextDueAt *time.Time `json:"nextDueAt"`
}
```

## Client surface (Swift, hand-written and thin)

```swift
// One store consumes the engine and fans out to the Dock, menu bar and Settings.
@MainActor public protocol EngineStore: AnyObject {
    var state: EngineState { get }              // rows, summary, consent facts, health, generation floor
    func start() async                          // spawn, handshake with a new sessionId, supervise
    func grant(_ request: ConsentGrantRequest) async throws -> ConsentReceipt   // raises the floor from any committed generation
    func refresh(_ scopes: [String]) async throws -> [RefreshScheduled]
    func history(_ query: HistoryQuery) async throws -> HistoryPage   // dropped if older than the floor
    func diagnostics() async throws -> Diagnostics
}

// Answers credentials/request; runs SecItemCopyMatching off the main thread; drops late callbacks by operationId.
public protocol CredentialAgent: Sendable {
    func handle(_ request: CredentialRequest) async -> CredentialResult
}
```

## Errors (JSON-RPC `error.code`)

| Code | Name | Meaning |
|---|---|---|
| -32010 | `protocol_mismatch` | The major version differs. The server exits and the app does not restart it |
| -32011 | `not_initialized` | A method was called before `initialize` |
| -32012 | `wrong_session` | The `sessionId` does not match the current session |
| -32013 | `busy` | Over an in-flight or queue cap. Retry later; nothing was started |
| -32020 | `consent_stale` | `expectGeneration` is older than current. `error.data.consentGeneration` gives the current one |
| -32021 | `consent_rejected` | An `allow` for an unknown scope or a forbidden access class, or while readers are off. Deny and forget are never rejected for a known or retired scope |
| -32022 | `request_mismatch` | A known `requestId` arrived with a different payload |
| -32023 | `consent_changed` | The generation moved while a sensitive query ran. No items are returned |
| -32030 | `credential_rejected` | The result does not match an open operation, or has expired |
| -32050 | `history_unavailable` | The history store cannot be read. Rows are not affected |
| -32051 | `cursor_stale` | The cursor was issued under another session, scope set, reference or generation |
| -32099 | `internal` | Sanitized. Details only in `diagnostics/get` |

A committed `consent/grant` always returns a result with a `ConsentReceipt`, `cleanup_pending` included. It never returns an error.

## Invariants (tested)

1. **Row set.** With a valid consent and readers on, `rows` contains exactly the expected row set by stable id, never filtered by app preferences. There are no duplicates.
   - Each engine empty state (`readers_off`, `pending`, `no_consent`, empty) has its own `rowsSummary.state`.
   - "All hidden" is an app state and never appears here.
2. **Sequence.** Within a session, `sequence` strictly increases. Messages from another session are dropped.
3. **Generation floor.** The app's generation floor never decreases. Rows, query results and consent facts older than the floor are dropped.
4. **Token exposure.** A token appears only in `credentials/result.accessToken`. It never appears in any other message, log line, diagnostics field, error or the cockpit page.
5. **Credential matching.** A `credentials/result` whose operation or generation does not match an open request is rejected and never used.
6. **No background prompt.** `credentials/request` with `interactive: false` never causes a visible prompt.
7. **Budget.** No remote request happens outside the shared per-vendor budget.
8. **Query isolation.** A failing `history/query` or `cockpit/query` never changes the next `rows/changed`.
9. **Revoke and Forget are final.** After a revoke or Forget from any process, no value for that scope is cached, emitted or shown again. That includes a query result or cursor issued before the revoke.
10. **Tightening is always accepted.** Deny and forget succeed with readers off, for undetected and retired tools, and when no reader exists.
11. **No unbounded waits.** Control messages are never delayed behind data messages, and no request waits without bound: over a cap, it gets `busy`.
