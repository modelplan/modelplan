# U7 native credential adapter — interface only

Implements the generated Wire credential operation through `EngineClient.CredentialAgent`.
No app entry, EngineStore, Shell, Go, generated DTO, packaging or signing file is changed.

The reader and a thread-safe `isCurrent(EngineDeliveryContext)` fence are required inputs.
The fence must compare the authoritative session, epoch, generation and delivery revision.
EngineClient retains explicit-action/receipt matching, replay protection and final private
`credentials/result` delivery. A non-nil user action is not new consent authorization.

Only Claude's saved-login scope and the fixed generic-password service are accepted.
Requests cannot select services, accounts, files or executables. Ambiguous items fail.
Background queries prohibit authentication UI. One worker performs the blocking read;
logical timeout/cancel does not cancel the OS call, and its slot stays occupied until it
returns. Late values cannot complete twice. The final writer must still reject stale
results because a revoke can race any local fence check.

Only a bounded in-memory `claudeAiOauth.accessToken` is extracted. Refresh tokens are not
forwarded. There is no tool fallback, logging, web publication or persistence. Memory
zeroing is not claimed.

Security statuses map to `ok`, `canceled`, `denied`, `not_found`,
`interaction_required` or `error`; logical expiry maps to `timeout`. Invalid/ambiguous data
maps to `error`. Failures carry no token or expiry and are not stored as latches.

Run `swift test --package-path desktop/native/ModelPlanCredentialAgent`. All tests inject
fake readers; none invokes `SecurityItemReader.read`. They cover query flags, error mapping,
token-only output, malformed/oversized data, action admission, stale contexts, cancellation,
timeout, blocked-worker bounds and late completion.

App wiring, synthetic Keychain/UI behavior, stable signing and two-build designated
requirement/ACL qualification are not-run. Creating an identity is never a package test.
Those operations require their own reviewed runner and approvals. Owner credentials and
real ACL proof remain outside this interface stage.
