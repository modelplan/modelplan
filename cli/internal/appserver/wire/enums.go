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

type PluginTool string

const (
	PluginClaudeCode PluginTool = "claude-code"
	PluginCodex      PluginTool = "codex"
)

// PluginInstallStatus is shared by the CLI installer and the engine receipt.
type PluginInstallStatus string

const (
	PluginInstalled    PluginInstallStatus = "installed"
	PluginInstructions PluginInstallStatus = "instructions"
	PluginPlanned      PluginInstallStatus = "planned"
	PluginFailed       PluginInstallStatus = "failed"
)

type RefreshDecisionScope string

const (
	DecisionCodexRuntime RefreshDecisionScope = "codex.runtime_usage"
	DecisionCodexLocal   RefreshDecisionScope = "codex.local_history"
	DecisionClaude       RefreshDecisionScope = "claude.account_usage.saved_login"
	DecisionGemini       RefreshDecisionScope = "gemini.account_usage.saved_login"
	DecisionCursor       RefreshDecisionScope = "cursor.account_usage.saved_login"
	DecisionCopilot      RefreshDecisionScope = "copilot.runtime_usage"
	DecisionKimi         RefreshDecisionScope = "kimi.account_usage.saved_login"
	DecisionGrok         RefreshDecisionScope = "grok.account_usage.saved_login"
	DecisionKiro         RefreshDecisionScope = "kiro.runtime_usage"
	DecisionAntigravity  RefreshDecisionScope = "antigravity.runtime_usage"
	DecisionZai          RefreshDecisionScope = "zai.account_usage.api_key"
	DecisionMiniMax      RefreshDecisionScope = "minimax.account_usage.api_key"
	DecisionOpenCodeGo   RefreshDecisionScope = "opencodego.account_usage.api_key"
)

type RefreshDecisionOutcome string

const (
	DecisionNotAttempted RefreshDecisionOutcome = "not_attempted"
	DecisionDeferred     RefreshDecisionOutcome = "deferred"
	DecisionFailed       RefreshDecisionOutcome = "failed"
	DecisionSucceeded    RefreshDecisionOutcome = "succeeded"
)

type RefreshDecisionReason string

const (
	DecisionStartup     RefreshDecisionReason = "startup"
	DecisionWake        RefreshDecisionReason = "wake"
	DecisionDue         RefreshDecisionReason = "due"
	DecisionNotGranted  RefreshDecisionReason = "not_granted"
	DecisionOffline     RefreshDecisionReason = "offline"
	DecisionReadOnly    RefreshDecisionReason = "read_only"
	DecisionBudget      RefreshDecisionReason = "budget"
	DecisionInFlight    RefreshDecisionReason = "in_flight"
	DecisionUnavailable RefreshDecisionReason = "unavailable"
	DecisionCompleted   RefreshDecisionReason = "completed"
)

type MemberRefreshOutcome string

const (
	MemberRefreshStarted  MemberRefreshOutcome = "started"
	MemberRefreshDeferred MemberRefreshOutcome = "deferred"
)

type MemberRefreshReason string

const (
	MemberRefreshFloor      MemberRefreshReason = "floor"
	MemberRefreshBackoff    MemberRefreshReason = "backoff"
	MemberRefreshBudget     MemberRefreshReason = "budget"
	MemberRefreshNotGranted MemberRefreshReason = "not_granted"
	MemberRefreshOffline    MemberRefreshReason = "offline"
)

type ForecastPace string

const (
	ForecastTight     ForecastPace = "tight"
	ForecastOnTrack   ForecastPace = "on_track"
	ForecastSurplus   ForecastPace = "surplus"
	ForecastExhausted ForecastPace = "exhausted"
)

type ForecastBasis string

const (
	ForecastRecentRate   ForecastBasis = "recent-rate"
	ForecastCycleAverage ForecastBasis = "cycle-average"
	ForecastNoBasis      ForecastBasis = "none"
)

// HistoryImportPhase is the importer's state as the app shows it.
type HistoryImportPhase string

const (
	ImportIdle      HistoryImportPhase = "idle"
	ImportRunning   HistoryImportPhase = "running"
	ImportDone      HistoryImportPhase = "done"
	ImportCancelled HistoryImportPhase = "cancelled"
	ImportFailed    HistoryImportPhase = "failed"
)

// HistoryImportSourceStatus is one source's outcome in a finished import.
type HistoryImportSourceStatus string

const (
	ImportSourceImported  HistoryImportSourceStatus = "imported"
	ImportSourceNoConsent HistoryImportSourceStatus = "skipped_no_consent"
	ImportSourceNothing   HistoryImportSourceStatus = "nothing_found"
	ImportSourceOff       HistoryImportSourceStatus = "off"
)
