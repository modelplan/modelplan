// SPDX-License-Identifier: MIT
package wire

import (
	"encoding/json"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

const ProtocolVersion = "1.0"
const JSONRPC = "2.0"

// Limits bound admission and memory independently of provider implementations.
const (
	MaxFrameBytes             = 8 << 20
	MaxRequests               = 16
	MaxQueries                = 2
	MaxCredentialsPerProvider = 1
	MaxDataMessages           = 64
	MaxControlMessages        = 256
	MaxControlBytes           = 4 << 20
	WriteTimeout              = 10 * time.Second
	RequestTimeout            = 30 * time.Second
)

// ID preserves a caller's integer or string without a float64 round trip.
type ID = json.RawMessage

type Request struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      ID              `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type Envelope[T any] struct {
	SessionID         string   `json:"sessionId"`
	StoreEpoch        string   `json:"storeEpoch"`
	ConsentGeneration uint64   `json:"consentGeneration"`
	Scopes            []string `json:"scopes,omitempty"`
	Data              T        `json:"data"`
}

type Success[T any] struct {
	JSONRPC string      `json:"jsonrpc"`
	ID      ID          `json:"id"`
	Result  Envelope[T] `json:"result"`
}

type Notification[T any] struct {
	JSONRPC string      `json:"jsonrpc"`
	Method  string      `json:"method"`
	Params  Envelope[T] `json:"params"`
}

type ErrorContext struct {
	SessionID         string  `json:"sessionId"`
	StoreEpoch        *string `json:"storeEpoch,omitempty"`
	ConsentGeneration *uint64 `json:"consentGeneration,omitempty"`
}

type RPCError struct {
	Code    int          `json:"code"`
	Message string       `json:"message"`
	Data    ErrorContext `json:"data"`
}

type Failure struct {
	JSONRPC string   `json:"jsonrpc"`
	ID      ID       `json:"id"`
	Error   RPCError `json:"error"`
}

type InitializeParams struct {
	SessionID       string   `json:"sessionId"`
	ProtocolVersion string   `json:"protocolVersion"`
	AppVersion      string   `json:"appVersion"`
	Capabilities    []string `json:"capabilities"`
}

type InitializeResult struct {
	ProtocolVersion string   `json:"protocolVersion"`
	ServerVersion   string   `json:"serverVersion"`
	Capabilities    []string `json:"capabilities"`
}

type Empty struct{}

type CancelParams struct {
	ID ID `json:"id"`
}

type RowsSnapshot struct {
	Sequence   uint64         `json:"sequence"`
	Projection RowsProjection `json:"projection"`
}

// RowsProjection excludes consent context, which belongs only in Envelope.
// The standalone desktop projection retains its independent legacy contract.
type RowsProjection struct {
	RowsVersion int              `json:"rowsVersion"`
	Rows        []rows.Row       `json:"rows"`
	RowsSummary rows.RowsSummary `json:"rowsSummary"`
}

func Project(value rows.Projection) RowsProjection {
	return RowsProjection{RowsVersion: value.RowsVersion, Rows: value.Rows, RowsSummary: value.RowsSummary}
}

type ConsentScope struct {
	Scope          string               `json:"scope"`
	Tool           string               `json:"tool"`
	Route          rows.Route           `json:"route"`
	Detected       bool                 `json:"detected"`
	Retired        bool                 `json:"retired"`
	State          ConsentState         `json:"state"`
	DefaultCheck   bool                 `json:"defaultCheck"`
	Keychain       *KeychainChoice      `json:"keychain"`
	CleanupPending bool                 `json:"cleanupPending"`
	Disabled       *ScopeDisabledReason `json:"disabledReason,omitempty"`
}

type ConsentFacts struct {
	Scopes []ConsentScope `json:"scopes"`
}

type ConsentGrantParams struct {
	RequestID        string                    `json:"requestId"`
	ExpectStoreEpoch string                    `json:"expectStoreEpoch"`
	ExpectGeneration uint64                    `json:"expectGeneration"`
	TextVersion      int                       `json:"consentTextVersion"`
	Allow            []string                  `json:"allow"`
	Deny             []string                  `json:"deny"`
	Forget           []string                  `json:"forget,omitempty"`
	Keychain         map[string]KeychainChoice `json:"keychain,omitempty"`
}

// ConsentReceipt's response envelope carries the transaction's committed
// (storeEpoch,consentGeneration). CommittedGeneration equals that envelope's
// generation, including cleanup_pending and replay, even if the store advances.
type ConsentReceipt struct {
	RequestID           string      `json:"requestId"`
	Committed           bool        `json:"committed"`
	CommittedGeneration *uint64     `json:"committedGeneration"`
	CleanupPending      []string    `json:"cleanupPending,omitempty"`
	Code                ReceiptCode `json:"code"`
}

type CredentialRequest struct {
	OperationID string `json:"operationId"`
	Provider    string `json:"provider"`
	Scope       string `json:"scope"`
	Interactive bool   `json:"interactive"`
}

// CredentialResult is the sole token-bearing DTO. Never format it in an error,
// log, diagnostic or persisted receipt. A token is legal only for OutcomeOK.
type CredentialResult struct {
	OperationID string            `json:"operationId"`
	Outcome     CredentialOutcome `json:"outcome"`
	AccessToken *string           `json:"accessToken,omitempty"`
	ExpiresAt   *time.Time        `json:"expiresAt,omitempty"`
}

type RefreshRequestParams struct {
	Scopes []string `json:"scopes,omitempty"`
}

type RefreshScheduled struct {
	Scope          string                 `json:"scope"`
	At             time.Time              `json:"at"`
	DisabledReason *RefreshDisabledReason `json:"disabledReason,omitempty"`
}

type HistoryQueryParams struct {
	Kind   HistoryKind `json:"kind"`
	Tool   string      `json:"tool"`
	Ref    string      `json:"ref,omitempty" schema:"pattern=^[a-f0-9]{16}$,maxLength=16"`
	Cursor string      `json:"cursor,omitempty"`
	Limit  int         `json:"limit" schema:"minimum=1,maximum=500"`
}

type HistoryItem struct {
	At     time.Time `json:"at"`
	Model  *string   `json:"model"`
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

// Health contains codes only; provider error strings and credentials are excluded.
type Health struct {
	State HealthState `json:"state"`
	Code  string      `json:"code"`
}
