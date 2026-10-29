# Keychain reads use the app's own stable identity; tokens reach Go in memory only

Status: accepted by the owner on 2026-10-29.

## Context

Claude's login on the owner's Mac exists only in the Keychain. The CLI read it through `/usr/bin/security` with a 2-second background timeout.

- The first prompt timed out, and the timeout was saved as a permanent latch.
- Once a user chooses "Always Allow", the item's access list trusts `/usr/bin/security`, so any local process that runs that tool can read the item.
- `/usr/bin/security` was chosen because ad-hoc test builds change identity on every build, which re-prompts.
- #298 added a foreground read at grant time, but that read bypasses the vendor budget.

## Decision

- **Stable identity.** Test builds are signed with a local self-signed code-signing certificate:
  - the certificate type is Code Signing, and it lives in the build Mac's login keychain;
  - the private key never enters a repository, and the owner keeps a `.p12` backup;
  - the certificate is not set as system-trusted.
- **App read.** The app reads only the fixed item with Security.framework, off the main thread, with a bounded wait. Cancel and deny are normal interactive states and never become a permanent latch.
- **Credential operation.**
  - The server sends `credentials/request` with an operation id, the scope, the consent generation and an `interactive` flag. `interactive` is true only after an explicit Settings action.
  - The app answers with `credentials/result`: an outcome (`ok`, `canceled`, `denied`, `not_found`, `interaction_required`, `timeout`, `error`), plus the token when the outcome is `ok`.
  - Go rejects a result for an operation it no longer has open.
  - Background operations never prompt.
  - The token appears only in that one field. It never goes through argv, env, logs, diagnostics, errors, the web page or disk, and no refresh token is ever sent.
  - The owner ruled that this in-memory handoff is not "copying credentials".
- **Grant flow.** A Keychain grant triggers one foreground Keychain read. The remote quota request still obeys the shared budget, and the #298 bypass is removed.
- **`/usr/bin/security`** is no longer used for product credentials.

## Consequences

- ModelPlan asks for access under its own identity, so the prompt names ModelPlan.
- Existing access-list entries are not changed. A trust entry the user once gave `/usr/bin/security` stays until the owner removes it by hand.
- A standalone CLI run cannot read a Keychain-only login. It says so with a recovery step, and never falls back to `/usr/bin/security`.
- Rotating the certificate changes the identity, and users re-approve once. Gatekeeper still treats the build as unidentified until Developer ID notarization.
- The test Mac proves the two-build behaviour first, with a synthetic Keychain item and two signed builds of one identity. That is the implementation-ready gate.
- The real-Mac (L3) check then verifies that "Always Allow" survives two consecutive reviewed candidates. It stays pending until the second one.
