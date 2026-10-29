// SPDX-License-Identifier: MIT
package rows

// Outcome is one entry in the closed normative reason table.
type Outcome struct {
	State  State
	Code   Code
	Action Action
	Text   Text
}

var outcomes = map[Code]Outcome{
	CodeOK:                            {State: StateFresh, Code: CodeOK, Action: ActionNone, Text: Text{EN: "Reading available", ZH: "读数可用"}},
	CodeEstimated:                     {State: StateFresh, Code: CodeEstimated, Action: ActionNone, Text: Text{EN: "Estimated reading", ZH: "估算读数"}},
	CodeStaleReading:                  {State: StateStale, Code: CodeStaleReading, Action: ActionRefresh, Text: Text{EN: "A retained reading is shown", ZH: "正在显示保留的旧读数"}},
	CodeObservationTimeUnknown:        {State: StateStale, Code: CodeObservationTimeUnknown, Action: ActionRefresh, Text: Text{EN: "The observation time is unknown", ZH: "观测时间未知"}},
	CodeNotReadYet:                    {State: StatePending, Code: CodeNotReadYet, Action: ActionNone, Text: Text{EN: "Waiting for the first reading", ZH: "等待首次读取"}},
	CodeReaderBusy:                    {State: StatePending, Code: CodeReaderBusy, Action: ActionNone, Text: Text{EN: "A reading is already in progress", ZH: "读取正在进行"}},
	CodeConsentChanged:                {State: StatePending, Code: CodeConsentChanged, Action: ActionNone, Text: Text{EN: "Consent changed during the read", ZH: "读取期间授权已更改"}},
	CodeNoManualReading:               {State: StatePending, Code: CodeNoManualReading, Action: ActionNone, Text: Text{EN: "No manual reading has been entered", ZH: "尚未填写手动读数"}},
	CodeNoUsageWindows:                {State: StateEmpty, Code: CodeNoUsageWindows, Action: ActionNone, Text: Text{EN: "No usage windows were reported", ZH: "未报告用量窗口"}},
	CodeConsentRequired:               {State: StateNeedsConsent, Code: CodeConsentRequired, Action: ActionOpenSettingsConsent, Text: Text{EN: "Reader consent is needed", ZH: "需要读取授权"}},
	CodeConsentDenied:                 {State: StateNeedsConsent, Code: CodeConsentDenied, Action: ActionOpenSettingsConsent, Text: Text{EN: "Reader consent is denied", ZH: "读取授权已拒绝"}},
	CodeConsentOutdated:               {State: StateNeedsConsent, Code: CodeConsentOutdated, Action: ActionOpenSettingsConsent, Text: Text{EN: "Reader consent needs to be renewed", ZH: "读取授权需要更新"}},
	CodeLoginExpired:                  {State: StateNeedsAction, Code: CodeLoginExpired, Action: ActionOpenTool, Text: Text{EN: "The saved sign-in has expired", ZH: "已保存的登录已过期"}},
	CodeRuntimeMissing:                {State: StateNeedsAction, Code: CodeRuntimeMissing, Action: ActionInstallRuntime, Text: Text{EN: "The tool runtime is missing", ZH: "缺少工具运行时"}},
	CodeUpdateRequired:                {State: StateNeedsAction, Code: CodeUpdateRequired, Action: ActionUpdateCLI, Text: Text{EN: "Update the CLI to use this reader", ZH: "请更新 CLI 以使用此读取器"}},
	CodeKeyMissing:                    {State: StateNeedsAction, Code: CodeKeyMissing, Action: ActionOpenSettingsConsent, Text: Text{EN: "A configured key is required", ZH: "需要配置密钥"}},
	CodeToolNotFound:                  {State: StateNeedsAction, Code: CodeToolNotFound, Action: ActionOpenSettingsConsent, Text: Text{EN: "The allowed tool is not detected", ZH: "未检测到已授权的工具"}},
	CodeCatalogueRetired:              {State: StateNeedsAction, Code: CodeCatalogueRetired, Action: ActionOpenSettingsConsent, Text: Text{EN: "The allowed tool was retired from the catalogue", ZH: "已授权工具已从目录移除"}},
	CodeHTTP401:                       {State: StateNeedsAction, Code: CodeHTTP401, Action: ActionOpenSettingsConsent, Text: Text{EN: "The provider rejected the saved sign-in", ZH: "服务商拒绝了已保存的登录"}},
	CodeUnsupportedLogin:              {State: StateNeedsAction, Code: CodeUnsupportedLogin, Action: ActionOpenSettingsConsent, Text: Text{EN: "This saved sign-in is not supported", ZH: "不支持此已保存的登录"}},
	CodePrivacyBlocked:                {State: StateOff, Code: CodePrivacyBlocked, Action: ActionOpenSettingsConsent, Text: Text{EN: "Privacy settings block this reader", ZH: "隐私设置阻止此读取器"}},
	CodeCatalogueOff:                  {State: StateOff, Code: CodeCatalogueOff, Action: ActionOpenSettingsConsent, Text: Text{EN: "This reader route is disabled", ZH: "此读取路由已停用"}},
	CodeNotAdmitted:                   {State: StateOff, Code: CodeNotAdmitted, Action: ActionOpenSettingsConsent, Text: Text{EN: "This reader is not admitted", ZH: "此读取器未获准运行"}},
	CodeCodexBarNotAudited:            {State: StateOff, Code: CodeCodexBarNotAudited, Action: ActionOpenSettingsConsent, Text: Text{EN: "This helper route has not been audited", ZH: "此辅助路由尚未审核"}},
	CodeCodexBarNotRead:               {State: StateOff, Code: CodeCodexBarNotRead, Action: ActionOpenSettingsConsent, Text: Text{EN: "This helper route does not read usage", ZH: "此辅助路由不读取用量"}},
	CodeCodexBarAccessUnknown:         {State: StateOff, Code: CodeCodexBarAccessUnknown, Action: ActionOpenSettingsConsent, Text: Text{EN: "The helper access class is unknown", ZH: "辅助访问类别未知"}},
	CodeBrowserSessionConsentRequired: {State: StateOff, Code: CodeBrowserSessionConsentRequired, Action: ActionOpenSettingsConsent, Text: Text{EN: "Separate browser-session consent is required", ZH: "需要单独的浏览器会话授权"}},
	CodeNoReader:                      {State: StateUnsupported, Code: CodeNoReader, Action: ActionNone, Text: Text{EN: "No usage reader is available for this tool", ZH: "此工具暂无用量读取器"}},
	CodeCleanupPending:                {State: StateOff, Code: CodeCleanupPending, Action: ActionOpenSettingsConsent, Text: Text{EN: "Consent was revoked; cleanup is pending", ZH: "授权已撤销，等待清理"}},
	CodeOther:                         {State: StateFailed, Code: CodeOther, Action: ActionRefresh, Text: Text{EN: "The reading could not be completed", ZH: "无法完成读取"}},
	CodeKeychainUnset:                 {State: StateNeedsKeychain, Code: CodeKeychainUnset, Action: ActionOpenSettingsKeychain, Text: Text{EN: "Allow Keychain access for this read", ZH: "请允许本次读取访问钥匙串"}},
	CodeKeychainDenied:                {State: StateNeedsKeychain, Code: CodeKeychainDenied, Action: ActionOpenSettingsKeychain, Text: Text{EN: "Keychain access was denied", ZH: "钥匙串访问已拒绝"}},
	CodeKeychainCanceled:              {State: StateNeedsKeychain, Code: CodeKeychainCanceled, Action: ActionOpenSettingsKeychain, Text: Text{EN: "Keychain access was canceled", ZH: "钥匙串访问已取消"}},
	CodeKeychainNotFound:              {State: StateNeedsKeychain, Code: CodeKeychainNotFound, Action: ActionOpenSettingsKeychain, Text: Text{EN: "The Keychain item was not found", ZH: "未找到钥匙串项目"}},
	CodeKeychainUnavailable:           {State: StateNeedsKeychain, Code: CodeKeychainUnavailable, Action: ActionOpenSettingsKeychain, Text: Text{EN: "Keychain access is unavailable", ZH: "钥匙串访问不可用"}},
	CodeKeychainConfirmationNeeded:    {State: StateNeedsKeychain, Code: CodeKeychainConfirmationNeeded, Action: ActionOpenSettingsKeychain, Text: Text{EN: "Keychain confirmation is needed", ZH: "需要确认钥匙串访问"}},
	CodeFileMissing:                   {State: StateFailed, Code: CodeFileMissing, Action: ActionRefresh, Text: Text{EN: "The saved reading input is missing", ZH: "缺少已保存的读取输入"}},
	CodeFileUnreadable:                {State: StateFailed, Code: CodeFileUnreadable, Action: ActionRefresh, Text: Text{EN: "The saved reading input is unreadable", ZH: "无法读取已保存的输入"}},
	CodeParseError:                    {State: StateFailed, Code: CodeParseError, Action: ActionRefresh, Text: Text{EN: "The reader could not parse the response", ZH: "读取器无法解析响应"}},
	CodeSchemaChanged:                 {State: StateFailed, Code: CodeSchemaChanged, Action: ActionRefresh, Text: Text{EN: "The reader input format has changed", ZH: "读取输入格式已更改"}},
	CodeHTTP403:                       {State: StateFailed, Code: CodeHTTP403, Action: ActionRefresh, Text: Text{EN: "The provider denied the request", ZH: "服务商拒绝了请求"}},
	CodeHTTP429:                       {State: StateFailed, Code: CodeHTTP429, Action: ActionRefresh, Text: Text{EN: "The provider is limiting requests", ZH: "服务商正在限制请求"}},
	CodeHTTP5xx:                       {State: StateFailed, Code: CodeHTTP5xx, Action: ActionRefresh, Text: Text{EN: "The provider is temporarily unavailable", ZH: "服务商暂时不可用"}},
	CodeNetwork:                       {State: StateFailed, Code: CodeNetwork, Action: ActionRefresh, Text: Text{EN: "The reader could not reach the provider", ZH: "读取器无法连接服务商"}},
	CodeTimeout:                       {State: StateFailed, Code: CodeTimeout, Action: ActionRefresh, Text: Text{EN: "The reader timed out", ZH: "读取器超时"}},
}

// Describe returns only compiled messages. Unknown codes never carry caller text.
func Describe(code Code) Outcome {
	if out, ok := outcomes[code]; ok {
		return out
	}
	return outcomes[CodeOther]
}

// SignalChannel separates identical strings with different meanings. In
// particular credential-store consent_required is not reader consent.
type SignalChannel string

const (
	SignalStatus    SignalChannel = "status"
	SignalError     SignalChannel = "errorCode"
	SignalBlocked   SignalChannel = "blocked"
	SignalDetection SignalChannel = "detection"
	SignalKeychain  SignalChannel = "keychain"
)

type signalKey struct {
	Channel SignalChannel
	Value   string
}

var signalCodes = map[signalKey]Code{
	// These generic statuses defer to errorCode/reason; without one lookup is
	// the separately tested unknown fallback, never intentional generic success.
	{SignalStatus, "error"}:       "",
	{SignalStatus, "unavailable"}: "",

	{SignalError, "runtime_missing"}:                    CodeRuntimeMissing,
	{SignalError, "http_401"}:                           CodeHTTP401,
	{SignalError, "unsupported_login"}:                  CodeUnsupportedLogin,
	{SignalError, "other"}:                              CodeOther,
	{SignalError, "file_missing"}:                       CodeFileMissing,
	{SignalError, "file_unreadable"}:                    CodeFileUnreadable,
	{SignalError, "parse_error"}:                        CodeParseError,
	{SignalError, "schema_changed"}:                     CodeSchemaChanged,
	{SignalError, "http_403"}:                           CodeHTTP403,
	{SignalError, "http_429"}:                           CodeHTTP429,
	{SignalError, "http_5xx"}:                           CodeHTTP5xx,
	{SignalError, "network"}:                            CodeNetwork,
	{SignalError, "timeout"}:                            CodeTimeout,
	{SignalBlocked, "native-off"}:                       CodePrivacyBlocked,
	{SignalBlocked, "codexbar-off"}:                     CodePrivacyBlocked,
	{SignalBlocked, "off"}:                              CodePrivacyBlocked,
	{SignalBlocked, "privacy_blocked"}:                  CodePrivacyBlocked,
	{SignalBlocked, "reader-privacy"}:                   CodePrivacyBlocked,
	{SignalBlocked, "catalogue-off"}:                    CodeCatalogueOff,
	{SignalBlocked, "no-native-reader"}:                 CodeNoReader,
	{SignalBlocked, "no-key"}:                           CodeKeyMissing,
	{SignalBlocked, "reader-consent-or-privacy"}:        CodeNotAdmitted,
	{SignalBlocked, "codexbar-not-audited"}:             CodeCodexBarNotAudited,
	{SignalBlocked, "codexbar-not-read"}:                CodeCodexBarNotRead,
	{SignalBlocked, "codexbar-access-unknown"}:          CodeCodexBarAccessUnknown,
	{SignalBlocked, "browser-session-consent-required"}: CodeBrowserSessionConsentRequired,
	{SignalBlocked, "update-required"}:                  CodeUpdateRequired,
	{SignalBlocked, "not_admitted"}:                     CodeNotAdmitted,
	{SignalBlocked, "unsafe_path"}:                      CodeNotAdmitted,
	{SignalBlocked, "not-configured"}:                   CodeNotAdmitted,
	{SignalDetection, "detected"}:                       CodeOK,
	{SignalDetection, "present"}:                        CodeOK,
	{SignalDetection, "not-detected"}:                   CodeToolNotFound,
	{SignalDetection, "not_detected"}:                   CodeToolNotFound,
	{SignalDetection, "absent"}:                         CodeToolNotFound,
	{SignalDetection, "unknown"}:                        CodeToolNotFound,
	{SignalDetection, "no-safe-signal"}:                 CodeToolNotFound,
	{SignalDetection, "update-required"}:                CodeUpdateRequired,
	{SignalDetection, "codexbar-not-audited"}:           CodeCodexBarNotAudited,
	{SignalDetection, "codexbar-not-read"}:              CodeCodexBarNotRead,
	{SignalDetection, "codexbar-access-unknown"}:        CodeCodexBarAccessUnknown,
	{SignalKeychain, "ok"}:                              CodeOK,
	{SignalKeychain, "consent-required"}:                CodeKeychainUnset,
	{SignalKeychain, "consent_required"}:                CodeKeychainUnset,
	{SignalKeychain, "keychain_choice_needed"}:          CodeKeychainUnset,
	{SignalKeychain, "unset"}:                           CodeKeychainUnset,
	{SignalKeychain, "keychain_unset"}:                  CodeKeychainUnset,
	{SignalKeychain, "denied"}:                          CodeKeychainDenied,
	{SignalKeychain, "keychain_denied"}:                 CodeKeychainDenied,
	{SignalKeychain, "canceled"}:                        CodeKeychainCanceled,
	{SignalKeychain, "not-found"}:                       CodeKeychainNotFound,
	{SignalKeychain, "unavailable"}:                     CodeKeychainUnavailable,
	{SignalKeychain, "keychain-confirmation-needed"}:    CodeKeychainConfirmationNeeded,
	{SignalKeychain, "confirmation-needed"}:             CodeKeychainConfirmationNeeded,
	{SignalKeychain, "busy"}:                            CodeReaderBusy,
	{SignalStatus, "ok"}:                                CodeOK,
	{SignalStatus, "estimated"}:                         CodeEstimated,
	{SignalStatus, "stale"}:                             CodeStaleReading,
	{SignalStatus, "missing"}:                           CodeNotReadYet,
	{SignalStatus, "empty"}:                             CodeNoUsageWindows,
	{SignalStatus, "not_read"}:                          CodeNotReadYet,
	{SignalStatus, "not-read"}:                          CodeNotReadYet,
	{SignalStatus, "not_read_yet"}:                      CodeNotReadYet,
	{SignalStatus, "not read yet"}:                      CodeNotReadYet,
	{SignalStatus, "not-detected"}:                      CodeToolNotFound,
	{SignalStatus, "not_detected"}:                      CodeToolNotFound,
	{SignalStatus, "not-found"}:                         CodeToolNotFound,
	{SignalStatus, "busy"}:                              CodeReaderBusy,
	{SignalStatus, "reader_busy"}:                       CodeReaderBusy,
	{SignalStatus, "cooldown"}:                          CodeReaderBusy,
	{SignalStatus, "expired"}:                           CodeLoginExpired,
	{SignalStatus, "expired_login"}:                     CodeLoginExpired,
	{SignalStatus, "login_expired"}:                     CodeLoginExpired,
	{SignalStatus, "rate-limited"}:                      CodeHTTP429,
	{SignalStatus, "rate_limited"}:                      CodeHTTP429,
	{SignalStatus, "unsupported_schema"}:                CodeSchemaChanged,
	{SignalStatus, "not-supported"}:                     CodeSchemaChanged,
	{SignalStatus, "not_supported_yet"}:                 CodeSchemaChanged,
	{SignalStatus, "upstream_changed"}:                  CodeSchemaChanged,
	{SignalStatus, "invalid"}:                           CodeParseError,
	{SignalStatus, "unreadable"}:                        CodeFileUnreadable,
	{SignalStatus, "unsafe_path"}:                       CodeNotAdmitted,
	{SignalStatus, "too_large"}:                         CodeSchemaChanged,
	{SignalStatus, "network_error"}:                     CodeNetwork,
	{SignalStatus, "runtime_missing"}:                   CodeRuntimeMissing,
	{SignalStatus, "consent-changed"}:                   CodeConsentChanged,
	{SignalStatus, "off"}:                               CodePrivacyBlocked,
	{SignalStatus, "privacy_blocked"}:                   CodePrivacyBlocked,
	{SignalStatus, "consent_required"}:                  CodeNotAdmitted,
	{SignalStatus, "denied"}:                            CodeHTTP403,
}

// MapSignal performs exact, contextual lookup. No provider substring is parsed.
// The bool distinguishes an intentional compiled generic result from fallback.
func MapSignal(channel SignalChannel, value string) (Outcome, bool) {
	code, ok := signalCodes[signalKey{channel, value}]
	if !ok || code == "" {
		return Describe(CodeOther), false
	}
	return Describe(code), true
}

// IntentionalOther is restricted to reader_errors.go's compiled generic code.
// Canceled and untyped errors use this value; arbitrary status text does not.
func IntentionalOther(channel SignalChannel, value string) bool {
	return channel == SignalError && value == "other"
}
