// SPDX-License-Identifier: MIT
package wire

type ConsentState string

const (
	ConsentAllowed ConsentState = "allowed"
	ConsentDenied  ConsentState = "denied"
	ConsentUnset   ConsentState = "unset"
)

type KeychainChoice string

const (
	KeychainAllow KeychainChoice = "allow"
	KeychainDeny  KeychainChoice = "deny"
	KeychainUnset KeychainChoice = "unset"
)

type ReceiptCode string

const (
	ReceiptOK              ReceiptCode = "ok"
	ReceiptCleanupPending  ReceiptCode = "cleanup_pending"
	ReceiptStaleGeneration ReceiptCode = "stale_generation"
	ReceiptStaleText       ReceiptCode = "stale_consent_text"
	ReceiptRejected        ReceiptCode = "rejected"
)

type CredentialOutcome string

const (
	OutcomeOK                  CredentialOutcome = "ok"
	OutcomeCanceled            CredentialOutcome = "canceled"
	OutcomeDenied              CredentialOutcome = "denied"
	OutcomeNotFound            CredentialOutcome = "not_found"
	OutcomeInteractionRequired CredentialOutcome = "interaction_required"
	OutcomeTimeout             CredentialOutcome = "timeout"
	OutcomeError               CredentialOutcome = "error"
)

type HealthState string

const (
	HealthReady    HealthState = "ready"
	HealthDegraded HealthState = "degraded"
	HealthStopping HealthState = "stopping"
)
const (
	CodeParseError         = -32700
	CodeInvalidRequest     = -32600
	CodeMethodNotFound     = -32601
	CodeInvalidParams      = -32602
	CodeCanceled           = -32800
	CodeProtocolMismatch   = -32010
	CodeNotInitialized     = -32011
	CodeWrongSession       = -32012
	CodeBusy               = -32013
	CodeConsentStale       = -32020
	CodeConsentRejected    = -32021
	CodeRequestMismatch    = -32022
	CodeConsentChanged     = -32023
	CodeCredentialRejected = -32030
	CodeHistoryUnavailable = -32050
	CodeCursorStale        = -32051
	CodeInternal           = -32099
)

// ErrorName is an allow-list, never derived from an implementation error.
func ErrorName(code int) string {
	switch code {
	case CodeParseError:
		return "parse_error"
	case CodeInvalidRequest:
		return "invalid_request"
	case CodeMethodNotFound:
		return "method_not_found"
	case CodeInvalidParams:
		return "invalid_params"
	case CodeCanceled:
		return "canceled"
	case CodeProtocolMismatch:
		return "protocol_mismatch"
	case CodeNotInitialized:
		return "not_initialized"
	case CodeWrongSession:
		return "wrong_session"
	case CodeBusy:
		return "busy"
	case CodeConsentStale:
		return "consent_stale"
	case CodeConsentRejected:
		return "consent_rejected"
	case CodeRequestMismatch:
		return "request_mismatch"
	case CodeConsentChanged:
		return "consent_changed"
	case CodeCredentialRejected:
		return "credential_rejected"
	case CodeHistoryUnavailable:
		return "history_unavailable"
	case CodeCursorStale:
		return "cursor_stale"
	default:
		return "internal"
	}
}

type HistoryKind string

const (
	HistoryTokens      HistoryKind = "tokens"
	HistoryQuotaCycles HistoryKind = "quota_cycles"
	HistorySessions    HistoryKind = "sessions"
)

type ScopeDisabledReason string

const ScopePolicyPending ScopeDisabledReason = "policy_pending"

type RefreshDisabledReason string

const (
	RefreshCooldown      RefreshDisabledReason = "cooldown"
	RefreshReadOnly      RefreshDisabledReason = "read_only"
	RefreshOffline       RefreshDisabledReason = "offline"
	RefreshPolicyPending RefreshDisabledReason = "policy_pending"
)
