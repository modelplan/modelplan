# `modelplan app-server` protocol (v1 sketch)

Status: interface sketch for review. The bodies are not implemented yet. After review, the Go types become the source of truth, and the Swift types are generated from them.
Design: [`docs/architecture/foundation-v2.md`](../../docs/architecture/foundation-v2.md). Rows: [`rows-design.md`](rows-design.md).

## Transport

- JSON-RPC 2.0, one JSON object per line (UTF-8, `\n`-delimited), on the child's stdin and stdout.
- stderr carries sanitized log lines and is never parsed.
- The app is the only client. The process exits when stdin closes or after `shutdown`.
- A message is at most 8 MiB. A larger message is a protocol error; the server never truncates.
- Requests carry an `id`; notifications do not. The server may send notifications at any time after `initialize`.

## Versioning

- `protocolVersion` is `major.minor`.
- A different major is rejected with error `-32010 protocol_mismatch` and the server exits.
- A newer minor only adds methods, fields or enum values. The app decodes unknown enum values as `.unknown(String)` and ignores unknown fields.

## Methods

| Method | Direction | Purpose |
|---|---|---|
| `initialize` | app → server | Handshake; returns server version, capabilities, consent generation |
| `shutdown` | app → server | Flush and exit |
| `rows/subscribe` | app → server | Start `rows/changed` notifications; returns the current `Projection` |
| `rows/changed` | server → app (notification) | Full `Projection` after any change |
| `consent/get` | app → server | Consent facts for Settings (detected, allowed, keychain, access class, hosts, cleanup) |
| `consent/grant` | app → server | Grant/deny/keychain; same request and receipt shape as today's `consent grant --json` |
| `credentials/provide` | app → server | Short-lived access token read by the app from the Keychain |
| `credentials/status` | server → app (notification) | Which providers need the app to (re)read a credential |
| `refresh/request` | app → server | Ask for a refresh; obeys the shared budget |
| `history/query` | app → server | Paged history for one scope |
| `cockpit/query` | app → server | Cockpit inputs (publication scope, selection) |
| `publication/get` | app → server | Verified publication summary |
| `plugin/install` | app → server | Same contract as `plugin install --json` |
| `diagnostics/get` | app → server | Sanitized engine health and per-tool state codes |
| `engine/health` | server → app (notification) | Degraded, recovering or ok, with a reason code |

## Type sketch (Go)

```go
// package appserver — request/response shapes only; bodies not implemented.

type InitializeParams struct {
	ProtocolVersion string   `json:"protocolVersion"` // "1.0"
	AppVersion      string   `json:"appVersion"`
	Capabilities    []string `json:"capabilities"`    // e.g. "credentials.keychain", "cockpit.web"
}

type InitializeResult struct {
	ProtocolVersion   string   `json:"protocolVersion"`
	ServerVersion     string   `json:"serverVersion"` // CLI version, e.g. "0.6.0"
	Capabilities      []string `json:"capabilities"`
	ConsentGeneration uint64   `json:"consentGeneration"`
}

// rows/subscribe result and rows/changed params.
type RowsChanged struct {
	Projection rows.Projection `json:"projection"` // rowsVersion, consentGeneration, rows, rowsSummary
	Sequence   uint64          `json:"sequence"`   // strictly increasing per process
}

type CredentialsProvideParams struct {
	Provider    string    `json:"provider"`    // "claude" only in v1
	AccessToken string    `json:"accessToken"` // never logged; never persisted
	ExpiresAt   time.Time `json:"expiresAt"`
}

type CredentialsStatus struct {
	Provider string `json:"provider"`
	Need     string `json:"need"` // "none" | "read" | "reread_after_expiry" | "user_denied"
}

type RefreshRequestParams struct {
	Tools []string `json:"tools,omitempty"` // empty = all allowed tools
}

type RefreshRequestResult struct {
	Scheduled []ScheduledRefresh `json:"scheduled"`
}

type ScheduledRefresh struct {
	Tool       string     `json:"tool"`
	At         time.Time  `json:"at"`                       // now, or the next due time
	Disabled   *string    `json:"disabledReason,omitempty"` // "cooldown" | "read_only" | "offline"
}

type HistoryQueryParams struct {
	Scope  string `json:"scope"`            // subscriptionRef or tool id
	Cursor string `json:"cursor,omitempty"`
	Limit  int    `json:"limit"`            // <= 500
}

type HistoryPage struct {
	Items      []history.Entry `json:"items"`
	NextCursor string          `json:"nextCursor,omitempty"`
}

type Diagnostics struct {
	ProtocolVersion string          `json:"protocolVersion"`
	ServerVersion   string          `json:"serverVersion"`
	Uptime          int64           `json:"uptimeSeconds"`
	Tools           []ToolDiag      `json:"tools"`
	LastErrorClass  string          `json:"lastErrorClass,omitempty"`
}

type ToolDiag struct {
	Tool      string     `json:"tool"`
	State     rows.State `json:"state"`
	Code      rows.Code  `json:"code"`
	LastRead  *time.Time `json:"lastRead"`
	NextDueAt *time.Time `json:"nextDueAt"`
}

type EngineHealth struct {
	Status string `json:"status"` // "ok" | "degraded" | "recovering"
	Code   string `json:"code,omitempty"`
}
```

## Type sketch (Swift, generated)

```swift
// Generated by cli/internal/appcontract — do not edit.
public struct RowsChanged: Decodable, Sendable { public let projection: Projection; public let sequence: UInt64 }
public enum RowState: Decodable, Sendable { case fresh, stale, pending, failed, empty, needsConsent, needsKeychain, needsAction, unsupported, off, unknown(String) }

// Client surface the app codes against (hand-written, thin).
public protocol EngineClient: Sendable {
    func start() async throws -> InitializeResult           // spawns, handshakes, restarts with backoff
    var rows: AsyncStream<RowsChanged> { get }              // one stream; decode errors become engine/health, never an empty projection
    func consent() async throws -> ConsentFacts
    func grant(_ request: ConsentGrantRequest) async throws -> ConsentReceipt
    func provideCredential(_ token: ShortLivedToken) async throws  // token is wiped after send
    func refresh(_ tools: [String]) async throws -> [ScheduledRefresh]
    func history(_ query: HistoryQuery) async throws -> HistoryPage
    func diagnostics() async throws -> Diagnostics
}
```

## Errors

| Code | Name | Meaning |
|---|---|---|
| -32010 | `protocol_mismatch` | Major version differs; server exits |
| -32011 | `not_initialized` | Method before `initialize` |
| -32020 | `consent_stale` | Grant against an old generation; re-read and retry |
| -32021 | `consent_rejected` | Grant refused (unknown tool, forbidden access class, readers off) |
| -32030 | `credential_rejected` | Token missing, expired or for an unsupported provider |
| -32040 | `budget_deferred` | Refresh scheduled later; result carries `at` |
| -32050 | `history_unavailable` | History store unreadable; rows unaffected |
| -32099 | `internal` | Sanitized; details only in `diagnostics/get` |

## Invariants (tested)

1. `rows/changed` is never sent with fewer rows than allowed tools while consent is not `off`.
2. `sequence` strictly increases. The app ignores a lower or equal value.
3. A projection whose `consentGeneration` is older than the app's committed floor is dropped by the app.
4. No message, log line or diagnostics field contains a token, path outside ModelPlan's directories, email, account name or provider error text.
5. `credentials/provide` never triggers a remote request outside the shared budget.
6. A failing `history/query` or `cockpit/query` never changes the next `rows/changed`.
