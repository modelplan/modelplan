# `modelplan app-server` protocol (v1 sketch, revision 2)

Status: interface sketch for review. Bodies are not implemented. After review, dedicated Go wire DTOs are the source of truth: field names, presence (`omitempty` means the field may be absent), nullability (a pointer may be null), enum sets and size limits. The Swift types are generated from them.
Design: [`docs/architecture/foundation-v2.md`](../../docs/architecture/foundation-v2.md). Rows: [`rows-design.md`](rows-design.md).

## Transport

- JSON-RPC 2.0, one UTF-8 JSON object per `\n`-terminated line, on anonymous pipes for the child's stdin and stdout.
- stderr carries allow-listed log lines only and is never parsed.
- The app is the only client. The process exits when stdin closes, or after `shutdown`.
- A frame is at most 8 MiB. Over the limit is a protocol error; nothing is truncated.
- There is one writer per direction, and the outbound queue is bounded.
- Full row snapshots coalesce to the latest. Consent receipts and credential outcomes never coalesce or drop.
- Every request has a deadline and can be cancelled with `$/cancel { id }`.
- A response carries either `result` or `error`, never both. Error details go in `error.data`.

## Sessions and ordering

- **Session id.** The app generates a random `sessionId` before starting each child and passes it in `initialize`. Every notification and response carries `sessionId`, and the app drops messages from any other session.
- **Sequence.** `sequence` orders `rows/changed` within one session only. `rows/subscribe` returns the current projection with its `sequence`. The app then drops any notification in the same session whose sequence is lower or equal.
- **Generation floor.** The app keeps a committed consent-generation floor across sessions. A new session never lowers it, and the app drops any projection or consent fact older than the floor.

## Versioning

- `protocolVersion` is `major.minor`.
- A different major is rejected with `protocol_mismatch`; the server exits and the app does not restart it.
- A minor version adds methods, fields or enum values, announced in `capabilities`.
- The app decodes unknown enum values as `.unknown(String)` and ignores unknown fields.
- The app and its bundled engine ship together, so there is no multi-version negotiation beyond this.

## Methods

| Method | Direction | Purpose |
|---|---|---|
| `initialize` | app → server | Handshake: `sessionId`, protocol version, capabilities |
| `shutdown` | app → server | Flush and exit |
| `rows/subscribe` | app → server | Current projection and sequence; starts `rows/changed` |
| `rows/changed` | server → app | Full projection after a change (coalesced) |
| `consent/get` | app → server | Per-scope consent facts, with their generation |
| `consent/grant` | app → server | Per-scope allow and deny, Keychain decisions; idempotent by `requestId` |
| `consent/changed` | server → app | Consent changed outside the app, for example from the CLI: the new generation |
| `credentials/request` | server → app | Ask the app to read a credential |
| `credentials/result` | app → server | Outcome, and the token on success |
| `refresh/request` | app → server | Ask for refreshes within the shared budget |
| `history/query` | app → server | Paged history items for one scope |
| `cockpit/query` | app → server | Cockpit display data computed by Go |
| `publication/get` | app → server | Verified publication summary |
| `plugin/install` | app → server | Same contract as `plugin install --json` |
| `diagnostics/get` | app → server | Sanitized engine health and per-scope state codes |
| `engine/health` | server → app | `ok`, `degraded` or `recovering`, with a code |

## Type sketch (Go wire DTOs)

```go
// package appserver/wire — wire DTOs only. JSON tags are the contract.

type InitializeParams struct {
	SessionID       string   `json:"sessionId"`       // random, app-generated
	ProtocolVersion string   `json:"protocolVersion"` // "1.0"
	AppVersion      string   `json:"appVersion"`
	Capabilities    []string `json:"capabilities"`
}

type InitializeResult struct {
	SessionID         string   `json:"sessionId"`
	ProtocolVersion   string   `json:"protocolVersion"`
	ServerVersion     string   `json:"serverVersion"`
	Capabilities      []string `json:"capabilities"`
	ConsentGeneration uint64   `json:"consentGeneration"`
}

type RowsSnapshot struct { // rows/subscribe result and rows/changed params
	SessionID  string          `json:"sessionId"`
	Sequence   uint64          `json:"sequence"`
	Projection rows.Projection `json:"projection"` // rowsVersion, consentGeneration, rows (with route codes), rowsSummary
}

type ConsentScope struct {
	Scope        string  `json:"scope"`        // e.g. "gemini.account_usage.saved_login"
	Tool         string  `json:"tool"`
	Route        string  `json:"route"`        // "saved_login_api" | "runtime_rpc" | "local_log" | "api_key_api" | ...
	Detected     bool    `json:"detected"`
	State        string  `json:"state"`        // "allowed" | "denied" | "unset"
	DefaultCheck bool    `json:"defaultCheck"` // first-run default for undecided users
	Keychain     *string `json:"keychain"`     // null when the scope needs no Keychain
	CleanupPending bool  `json:"cleanupPending"`
	Disabled     *string `json:"disabledReason,omitempty"` // e.g. "policy_pending" for POST reads awaiting approval
}

type ConsentFacts struct {
	SessionID  string         `json:"sessionId"`
	Generation uint64         `json:"generation"`
	Scopes     []ConsentScope `json:"scopes"`
}

type ConsentGrantParams struct {
	RequestID        string            `json:"requestId"`
	ExpectGeneration uint64            `json:"expectGeneration"`
	TextVersion      int               `json:"consentTextVersion"`
	Allow            []string          `json:"allow"`              // scope ids
	Deny             []string          `json:"deny"`
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
	SessionID         string `json:"sessionId"`
	OperationID       string `json:"operationId"`
	Provider          string `json:"provider"` // "claude" in v1
	Scope             string `json:"scope"`
	ConsentGeneration uint64 `json:"consentGeneration"`
	Interactive       bool   `json:"interactive"` // true only after an explicit Settings action
}

type CredentialResult struct { // app -> server; the only message that may carry a token
	SessionID   string     `json:"sessionId"`
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
	DisabledReason *string   `json:"disabledReason,omitempty"` // "cooldown" | "read_only" | "offline"
}

type HistoryQueryParams struct {
	Kind   string `json:"kind"`   // "tokens" | "quota_cycles" | "sessions"
	Tool   string `json:"tool"`
	Ref    string `json:"ref,omitempty"` // subscriptionRef or accountLocator
	Cursor string `json:"cursor,omitempty"`
	Limit  int    `json:"limit"` // 1..500
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
    func history(_ query: HistoryQuery) async throws -> HistoryPage
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
| -32020 | `consent_stale` | `expectGeneration` is older than current. `error.data.generation` gives the current one |
| -32021 | `consent_rejected` | Unknown scope, forbidden access class, or readers off |
| -32030 | `credential_rejected` | The result does not match an open operation, or has expired |
| -32050 | `history_unavailable` | The history store cannot be read. Rows are not affected |
| -32099 | `internal` | Sanitized. Details only in `diagnostics/get` |

A committed `consent/grant` always returns a result with a `ConsentReceipt`, `cleanup_pending` included, never an error.

## Invariants (tested)

1. With a valid consent, `rows` contains exactly the expected row set by stable id. There are no duplicates. Each empty state has its own `rowsSummary.state`.
2. Within a session, `sequence` strictly increases. Messages from another session are dropped.
3. The app's generation floor never decreases, and data older than the floor is dropped.
4. A token appears only in `credentials/result.accessToken`. It never appears in any other message, log line, diagnostics field, error or the cockpit page.
5. A `credentials/result` whose operation, session or generation does not match an open request is rejected and never used.
6. `credentials/request` with `interactive: false` never causes a visible prompt.
7. No remote request happens outside the shared per-vendor budget.
8. A failing `history/query` or `cockpit/query` never changes the next `rows/changed`.
9. After a revoke or Forget from any process, no value for that scope is cached or emitted again.
