<!-- SPDX-License-Identifier: MIT -->
# Claude credential operation in Go

The app reads the fixed Claude item under its own identity. Go never launches a
Keychain process. A standalone Keychain-only login reports “Open the app, or use
a credentials file”. Saved credentials files remain supported. No credential is
written back to Claude or persisted in a ModelPlan store.

`CredentialBroker.Paths` wraps the production quota paths with a background
credential callback. The managed reader acquires its existing reader/provider
locks and reserves the shared remote budget before calling it. The callback
awaits `Server.ReadCredential`, which emits `credentials/request` with
`interactive:false`. The app returns the existing `CredentialResult` DTO.

An interactive operation can originate only in an explicit committed Keychain
grant. Its result goes through `CredentialBroker.AcceptCredential`, which checks
the current full epoch/generation, scope and Keychain admission again. One
credential operation occurs even when the remote budget is closed. Its success
or recoverable failure updates the credential-read fact without changing the
remote budget or renewing a retained reading's admission stamp. A successful
result is reused only if the normal managed read is due.

The constructor installs the broker for both shared-backend and refresh paths,
delegates `CredentialReceiver` to it, and binds `broker.Request` to
`server.ReadCredential` before `Serve`. The scheduler preserves the installed
callback. `PathsFor` is the original production constructor, not the broker's
own wrapper. The broker stores no token.

Operations have random IDs, an initialized session, the full consent stamp and
a bounded deadline. Wrong, canceled, expired and old-stamp results are rejected.
A background result wakes its existing reader and does not start another read.
A token is legal only in `credentials/result.accessToken`; formatting and logging
that DTO remain redacted. Transient payload bytes are cleared after use or
release, including when a closed budget prevents their use. Outcome/status
strings pass through a closed vocabulary before reaching caches, rows or
diagnostics. Deny, cancel and timeout are recoverable and never permanent latches.

The legacy injected adapter remains available to existing reader unit tests; it
has no default process executor. Synthetic Go tests do not prove the app's
Security.framework flags, signing identity or two-build Keychain behavior.
Those checks belong to the native adapter and packaged-app evidence.
