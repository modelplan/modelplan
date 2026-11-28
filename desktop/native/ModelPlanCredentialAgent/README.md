# U7 native credential adapter — interface only

Implements the generated Wire credential operation through `EngineClient.CredentialAgent`.
No app entry, EngineStore, Shell, Go, generated DTO, packaging or signing file is changed.

The reader and a thread-safe `isCurrent(EngineDeliveryContext)` fence are required inputs.
The fence must compare the authoritative session, epoch, generation and delivery revision.
EngineClient retains explicit-action/receipt matching, replay protection and final private
`credentials/result` delivery. A non-nil user action is not new consent authorization.

Only two fixed items are accepted, each by its provider and scope together: Claude's saved-login scope with the
`Claude Code-credentials` service, and (D380) `zai.account_usage.saved_login` with ZCode 3.19+'s store key, service
`ZCode Credential Encryption`, account hex(sha256(`~/.zcode/v2/credentials.json`)), which the agent derives from the
user's home itself. For ZCode only a 43-character base64url key is returned; nothing is written, refreshed or deleted.
Requests cannot select services, accounts, files or executables. Enumeration returns only attributes and persistent references; after uniqueness/service checks, a second single-match query reads data by that exact persistent reference. Ambiguous items fail.
Background queries prohibit authentication UI. The reader requires the agent's injected operation checkpoint before each OS call; cancellation, deadline expiry or lost context after enumeration prevents the second interactive query entirely. A pre-call terminal result has no OSStatus or data. One worker performs the blocking read;
logical timeout/cancel does not cancel the OS call, and its slot stays occupied until it
returns. Late values cannot complete twice. The final writer must still reject stale
results because a revoke can race any local fence check.

Only a bounded in-memory `claudeAiOauth.accessToken` is extracted. Refresh tokens are not
forwarded. There is no tool fallback, logging, web publication or persistence. Memory
zeroing is not claimed.

Security statuses map to `ok`, `canceled`, `denied`, `not_found`,
`interaction_required` or `error`; logical expiry maps to `timeout`. Invalid/ambiguous data
maps to `error`. Failures carry no token or expiry and are not stored as latches.

Run `swift test --package-path desktop/native/ModelPlanCredentialAgent`. Tests inject fake readers or low-level matchers; none calls `SecItemCopyMatching`. They cover query flags, error mapping,
token-only output, malformed/oversized data, action admission, stale contexts, cancellation,
timeout, blocked-worker bounds and late completion.

App wiring, synthetic Keychain/UI behavior, stable signing and two-build designated
requirement/ACL qualification are not-run. Creating an identity is never a package test.
Those operations require their own reviewed runner and approvals. Owner credentials and
real ACL proof remain outside this interface stage.
