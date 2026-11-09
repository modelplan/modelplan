// SPDX-License-Identifier: MIT
package wire

import (
	"encoding/json"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

const ProtocolVersion = "1.0"
const JSONRPC = "2.0"
const MaxRefreshScopes = 128
const PluginInstallTimeout = 2 * time.Minute

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
	ID      ID              `json:"id,omitempty" null:"forbidden"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty" null:"distinct"`
}

type Envelope[T any] struct {
	SessionID         string   `json:"sessionId"`
	StoreEpoch        string   `json:"storeEpoch"`
	ConsentGeneration uint64   `json:"consentGeneration"`
	Scopes            []string `json:"scopes,omitempty" null:"coalesced"`
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
	StoreEpoch        *string `json:"storeEpoch,omitempty" null:"coalesced"`
	ConsentGeneration *uint64 `json:"consentGeneration,omitempty" null:"coalesced"`
}

type RPCError struct {
	Code    int          `json:"code"`
	Message string       `json:"message"`
	Data    ErrorContext `json:"data"`
}

type Failure struct {
	JSONRPC string   `json:"jsonrpc"`
	ID      ID       `json:"id" null:"coalesced"`
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
	ResetEvents *[]rows.ResetEvent `json:"resetEvents,omitempty" null:"forbidden"`
	// Forecasts is present only for a client that negotiated cockpitForecastV1, so the App can
	// notify while the cockpit is closed.
	Forecasts   *[]CockpitForecast `json:"forecasts,omitempty" schema:"maxItems=128" null:"forbidden"`
	RowsVersion int                `json:"rowsVersion"`
	Rows        []rows.Row         `json:"rows"`
	RowsSummary rows.RowsSummary   `json:"rowsSummary"`
}

func ProjectWithEvents(value rows.Projection, events *[]rows.ResetEvent, enabled bool, sourceEnabled ...bool) RowsProjection {
	expose := len(sourceEnabled) > 0 && sourceEnabled[0]
	members := len(sourceEnabled) > 1 && sourceEnabled[1]
	today := len(sourceEnabled) > 3 && sourceEnabled[3]
	result := project(value, expose, members, today)
	if len(sourceEnabled) > 4 && sourceEnabled[4] {
		forecasts := ProjectForecasts(value, func(string) bool { return true }, time.Now())
		result.Forecasts = &forecasts
	}
	if enabled {
		if events != nil {
			projected := ProjectResetEventLinks(*events, len(sourceEnabled) > 2 && sourceEnabled[2])
			result.ResetEvents = &projected
		}
	}
	return result
}

// ProjectResetEventLinks removes the additive link field for older clients
// without mutating the shared snapshot.
func ProjectResetEventLinks(events []rows.ResetEvent, enabled bool) []rows.ResetEvent {
	if enabled {
		return events
	}
	out := append([]rows.ResetEvent{}, events...)
	for i := range out {
		out[i].Source.Links = nil
	}
	return out
}

func Project(value rows.Projection) RowsProjection { return project(value, false, false, false) }

func project(value rows.Projection, expose, members, today bool) RowsProjection {
	result := RowsProjection{RowsVersion: value.RowsVersion, Rows: append([]rows.Row{}, value.Rows...), RowsSummary: value.RowsSummary}
	if expose && members && today {
		return result
	}
	for i := range result.Rows {
		if !members {
			result.Rows[i].RefreshNotBefore = nil
		}
		result.Rows[i].Accounts = append([]rows.Account{}, result.Rows[i].Accounts...)
		for j := range result.Rows[i].Accounts {
			account := &result.Rows[i].Accounts[j]
			if !today {
				account.Today = nil
			}
			if !members {
				account.RefreshNotBefore = nil
			}
			if !expose {
				account.Windows = append([]rows.Window{}, account.Windows...)
				for k := range account.Windows {
					account.Windows[k].Source = nil
				}
			}
		}
	}
	return result
}

type ConsentScope struct {
	Scope          string               `json:"scope"`
	Tool           string               `json:"tool"`
	Route          rows.Route           `json:"route"`
	Detected       bool                 `json:"detected"`
	Retired        bool                 `json:"retired"`
	State          ConsentState         `json:"state"`
	DefaultCheck   bool                 `json:"defaultCheck"`
	Keychain       *KeychainChoice      `json:"keychain" null:"coalesced"`
	CleanupPending bool                 `json:"cleanupPending"`
	Disabled       *ScopeDisabledReason `json:"disabledReason,omitempty" null:"coalesced"`
}

type ConsentFacts struct {
	TextVersion int            `json:"consentTextVersion"`
	Scopes      []ConsentScope `json:"scopes"`
}

type ConsentGrantParams struct {
	RequestID        string                    `json:"requestId"`
	ExpectStoreEpoch string                    `json:"expectStoreEpoch"`
	ExpectGeneration uint64                    `json:"expectGeneration"`
	TextVersion      int                       `json:"consentTextVersion"`
	Allow            []string                  `json:"allow"`
	Deny             []string                  `json:"deny"`
	Forget           []string                  `json:"forget,omitempty" null:"coalesced"`
	Keychain         map[string]KeychainChoice `json:"keychain,omitempty" null:"coalesced"`
}

// ConsentReceipt's response envelope carries the transaction's committed
// (storeEpoch,consentGeneration). CommittedGeneration equals that envelope's
// generation, including cleanup_pending and replay, even if the store advances.
type ConsentReceipt struct {
	RequestID           string      `json:"requestId"`
	Committed           bool        `json:"committed"`
	CommittedGeneration *uint64     `json:"committedGeneration" null:"coalesced"`
	CleanupPending      []string    `json:"cleanupPending,omitempty" null:"coalesced"`
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
	AccessToken *string           `json:"accessToken,omitempty" null:"forbidden"`
	ExpiresAt   *time.Time        `json:"expiresAt,omitempty" null:"coalesced"`
}

type RefreshMember struct {
	RowID           string     `json:"rowId"`
	Route           rows.Route `json:"route"`
	SubscriptionRef string     `json:"subscriptionRef,omitempty" schema:"pattern=^[a-f0-9]{16}$,maxLength=16" null:"forbidden"`
	AccountLocator  string     `json:"accountLocator,omitempty" schema:"pattern=^[a-f0-9]{16}$,maxLength=16" null:"forbidden"`
}

type MemberRefreshResult struct {
	Outcome   MemberRefreshOutcome `json:"outcome"`
	NotBefore *time.Time           `json:"notBefore,omitempty" null:"forbidden"`
	Reason    *MemberRefreshReason `json:"reason,omitempty" null:"forbidden"`
}

type RefreshRequestParams struct {
	Member *RefreshMember `json:"member,omitempty" null:"forbidden"`
	Scopes []string       `json:"scopes,omitempty" schema:"maxItems=128,uniqueItems=true" null:"coalesced"`
}

type RefreshScheduled struct {
	Scope          string                 `json:"scope"`
	At             time.Time              `json:"at"`
	DisabledReason *RefreshDisabledReason `json:"disabledReason,omitempty" null:"coalesced"`
}

type HistoryQueryParams struct {
	Kind   HistoryKind `json:"kind"`
	Tool   string      `json:"tool"`
	Ref    string      `json:"ref,omitempty" schema:"pattern=^[a-f0-9]{16}$,maxLength=16" null:"forbidden"`
	Cursor string      `json:"cursor,omitempty" null:"forbidden"`
	Limit  int         `json:"limit" schema:"minimum=1,maximum=500"`
}

type HistoryItem struct {
	At     time.Time `json:"at"`
	Model  *string   `json:"model" null:"coalesced"`
	Tokens *int64    `json:"tokens" null:"coalesced"`
	Window *string   `json:"window" null:"coalesced"`
	Value  *float64  `json:"value" null:"coalesced"`
}

type HistoryPage struct {
	Items      []HistoryItem `json:"items"`
	NextCursor string        `json:"nextCursor,omitempty" null:"coalesced"`
}

type RefreshDecision struct {
	AgoSeconds int64                  `json:"agoSeconds" schema:"minimum=0"`
	Scope      RefreshDecisionScope   `json:"scope"`
	Outcome    RefreshDecisionOutcome `json:"outcome"`
	Reason     RefreshDecisionReason  `json:"reason"`
}

type Diagnostics struct {
	RefreshDecisions *[]RefreshDecision `json:"refreshDecisions,omitempty" schema:"maxItems=20" null:"forbidden"`
	ProtocolVersion  string             `json:"protocolVersion"`
	ServerVersion    string             `json:"serverVersion"`
	UptimeSeconds    int64              `json:"uptimeSeconds"`
	Scopes           []ScopeDiag        `json:"scopes"`
	LastErrorClass   string             `json:"lastErrorClass,omitempty" null:"coalesced"`
}

type ScopeDiag struct {
	Scope     string     `json:"scope"`
	State     rows.State `json:"state"`
	Code      rows.Code  `json:"code"`
	LastRead  *time.Time `json:"lastRead" null:"coalesced"`
	NextDueAt *time.Time `json:"nextDueAt" null:"coalesced"`
}

// Health contains codes only; provider error strings and credentials are excluded.
type Health struct {
	State HealthState `json:"state"`
	Code  string      `json:"code"`
}

// PluginInstallParams selects one fixed host integration. Offline plans the
// same commands without process lookup or execution.
type PluginInstallParams struct {
	Tool    PluginTool `json:"tool"`
	Offline bool       `json:"offline,omitempty" null:"coalesced"`
}

// ReaderKeyParams is the input of readerkey/set, readerkey/test and readerkey/remove (D90). Key is
// the only secret on the wire besides credentials/result: empty means "the stored key" for test and
// is ignored by remove; set needs it. Region is "none" for providers without a choice. The key is
// never echoed: see ReaderKeyParams.String and LogValue.
type ReaderKeyParams struct {
	Provider ReaderKeyProvider `json:"provider"`
	Region   ReaderKeyRegion   `json:"region"`
	Key      string            `json:"key" schema:"maxLength=4096"`
}

// ReaderKeyResult is the output of the three readerkey/* methods. It never carries the key.
type ReaderKeyResult struct {
	SchemaVersion int               `json:"schemaVersion" schema:"minimum=1,maximum=1"`
	Provider      ReaderKeyProvider `json:"provider"`
	Region        ReaderKeyRegion   `json:"region"`
	Present       bool              `json:"present"`
	Outcome       ReaderKeyOutcome  `json:"outcome"`
}
