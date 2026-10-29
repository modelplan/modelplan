// SPDX-License-Identifier: MIT
package rows

type Kind string

const (
	KindTool     Kind = "tool"
	KindDeclared Kind = "declared"
)

type Surface string

const (
	SurfaceDock     Surface = "dock"
	SurfaceMenu     Surface = "menu"
	SurfaceSettings Surface = "settings"
)

type Consent string

const (
	ConsentAllowed     Consent = "allowed"
	ConsentImplicit    Consent = "implicit"
	ConsentDenied      Consent = "denied"
	ConsentUnset       Consent = "unset"
	ConsentNotRequired Consent = "not_required"
	ConsentRetired     Consent = "retired"
)

type State string

const (
	StateOff           State = "off"
	StateNeedsAction   State = "needs_action"
	StateNeedsConsent  State = "needs_consent"
	StatePending       State = "pending"
	StateUnsupported   State = "unsupported"
	StateNeedsKeychain State = "needs_keychain"
	StateFailed        State = "failed"
	StateEmpty         State = "empty"
	StateStale         State = "stale"
	StateFresh         State = "fresh"
)

type Action string

const (
	ActionOpenSettingsConsent  Action = "open_settings_consent"
	ActionOpenSettingsKeychain Action = "open_settings_keychain"
	ActionOpenTool             Action = "open_tool"
	ActionInstallRuntime       Action = "install_runtime"
	ActionRefresh              Action = "refresh"
	ActionUpdateCLI            Action = "update_cli"
	ActionNone                 Action = "none"
)

type DisabledReason string

const (
	DisabledReasonCooldown DisabledReason = "cooldown"
	DisabledReasonReadOnly DisabledReason = "read_only"
	DisabledReasonOffline  DisabledReason = "offline"
)

type ValueState string

const (
	ValueStateCurrent  ValueState = "current"
	ValueStateRetained ValueState = "retained"
	ValueStateNone     ValueState = "none"
)

type Role string

const (
	RoleSession Role = "session"
	RoleDaily   Role = "daily"
	RoleWeekly  Role = "weekly"
	RoleMonthly Role = "monthly"
	RoleOther   Role = "other"
)

type ResetMode string

const (
	ResetModeFixed   ResetMode = "fixed"
	ResetModeRolling ResetMode = "rolling"
	ResetModeUnknown ResetMode = "unknown"
)

type SummaryState string

const (
	SummaryStateOK         SummaryState = "ok"
	SummaryStateReadersOff SummaryState = "readers_off"
	SummaryStateNoConsent  SummaryState = "no_consent"
	SummaryStateEmpty      SummaryState = "empty"
	SummaryStatePending    SummaryState = "pending"
)

type Code string

const (
	CodeOK                            Code = "ok"
	CodeEstimated                     Code = "estimated"
	CodeStaleReading                  Code = "stale_reading"
	CodeObservationTimeUnknown        Code = "observation_time_unknown"
	CodeNotReadYet                    Code = "not_read_yet"
	CodeReaderBusy                    Code = "reader_busy"
	CodeConsentChanged                Code = "consent_changed"
	CodeNoManualReading               Code = "no_manual_reading"
	CodeNoUsageWindows                Code = "no_usage_windows"
	CodeConsentRequired               Code = "consent_required"
	CodeConsentDenied                 Code = "consent_denied"
	CodeConsentOutdated               Code = "consent_outdated"
	CodeKeychainUnset                 Code = "keychain_unset"
	CodeKeychainDenied                Code = "keychain_denied"
	CodeKeychainCanceled              Code = "keychain_canceled"
	CodeKeychainNotFound              Code = "keychain_not_found"
	CodeKeychainUnavailable           Code = "keychain_unavailable"
	CodeKeychainConfirmationNeeded    Code = "keychain_confirmation_needed"
	CodeLoginExpired                  Code = "login_expired"
	CodeRuntimeMissing                Code = "runtime_missing"
	CodeUpdateRequired                Code = "update_required"
	CodeKeyMissing                    Code = "key_missing"
	CodeToolNotFound                  Code = "tool_not_found"
	CodeCatalogueRetired              Code = "catalogue_retired"
	CodeHTTP401                       Code = "http_401"
	CodeUnsupportedLogin              Code = "unsupported_login"
	CodePrivacyBlocked                Code = "privacy_blocked"
	CodeCatalogueOff                  Code = "catalogue_off"
	CodeNotAdmitted                   Code = "not_admitted"
	CodeCodexBarNotAudited            Code = "codexbar_not_audited"
	CodeCodexBarNotRead               Code = "codexbar_not_read"
	CodeCodexBarAccessUnknown         Code = "codexbar_access_unknown"
	CodeBrowserSessionConsentRequired Code = "browser_session_consent_required"
	CodeNoReader                      Code = "no_reader"
	CodeCleanupPending                Code = "cleanup_pending"
	CodeFileMissing                   Code = "file_missing"
	CodeFileUnreadable                Code = "file_unreadable"
	CodeParseError                    Code = "parse_error"
	CodeSchemaChanged                 Code = "schema_changed"
	CodeHTTP403                       Code = "http_403"
	CodeHTTP429                       Code = "http_429"
	CodeHTTP5xx                       Code = "http_5xx"
	CodeNetwork                       Code = "network"
	CodeTimeout                       Code = "timeout"
	CodeOther                         Code = "other"
	CodeReadersOff                    Code = "readers_off"
	CodeNoConsent                     Code = "no_consent"
	CodeNoDockRows                    Code = "no_dock_rows"
)

// AttemptResult is input-only; it is not a rows wire enum.
type AttemptResult string

const (
	AttemptResultNever     AttemptResult = "never"
	AttemptResultSucceeded AttemptResult = "succeeded"
	AttemptResultFailed    AttemptResult = "failed"
)
