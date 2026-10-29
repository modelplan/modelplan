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
- **In-memory handoff.**
  - The app sends a short-lived access token to the app-server with `credentials/provide`.
  - The token never goes through argv, env, logs, diagnostics or disk, and no refresh token is ever sent.
  - The owner ruled that this in-memory handoff is not "copying credentials".
- **Grant flow.** A Keychain grant triggers one foreground Keychain read. The remote quota request still obeys the shared budget, and the #298 bypass is removed.
- **`/usr/bin/security`** is no longer used for product credentials.

## Consequences

- The prompt names ModelPlan, and the item's access list trusts only the ModelPlan signing identity.
- Rotating the certificate changes the identity, and users re-approve once. Gatekeeper still treats the build as unidentified until Developer ID notarization.
- The real-Mac (L3) check verifies that "Always Allow" survives two consecutive builds.
