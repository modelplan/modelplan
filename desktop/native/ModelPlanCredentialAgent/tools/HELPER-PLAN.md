# U7 stable helper — wired-stage plan

Status: plan and packaging checker only. The executable helper, process transport,
reproducible artifact build and production constructor are not yet implemented.
A14 remains deferred until Developer ID; no self-signed replacement is planned.

## Product boundary

Move Security.framework/LocalAuthentication and the fixed-item enumeration/read
implementation to a separate executable, modelplan-credential-agent. The App-facing
library must not link or call that Keychain backend; it implements CredentialAgent
as a supervised private-pipe client. No credential tool fallback or remote network
path belongs in the helper. Retain the tested before-each-query operation checkpoint.

Reuse generated WireCredentialRequest/Result values. Define and review the narrow
versioned App/helper framing: operation id, accepted delivery context and bounded
monotonic remaining deadline; cancel/invalidation retires only its matching operation.
Parent pipe loss/EOF, restart, epoch/generation/revision changes and late output must
fail closed. One bounded OS worker stays occupied until its uninterruptible call
returns. Tokens exist only in the credential result's accessToken field over the
private pipe; never argv, environment, stderr, UI, files or diagnostics. The transport
must propagate cancellation before any next OS query, not only discard its token.

Consume EngineClient.isCurrent when its accepted API lands. Do not create a parallel
protocol reducer or substitute an always-true fence. App entry/Store edits stay within
M0's granted constructor/dependency lease; additional shared edits need their owner.

## Artifact and reproducible build

Build the helper independently of App sources. Freeze its complete source/dependency
closure, compiler/SDK and architecture, release flags, identifier and artifact version.
Use fixed optimization flags, no debug/timestamp/path payloads, compiler prefix maps,
and a deterministic link/signing policy (including Mach-O UUID/ad-hoc signature bytes).
These are proposed build controls; reproducibility is not proven until two clean
build roots produce the same final executable bytes. Dependency/toolchain changes
that affect helper bytes are helper upgrades and require a new artifact/pin.

Cache the verified helper artifact by that input closure, never by the App build id.
App packaging copies the accepted artifact; it does not rebuild or silently re-sign
it. Keep its identifier ai.modelplan.credential-agent fixed. Run the identity check
AFTER final App packaging/signing, so a nested re-sign cannot silently change the pin.

Each bundle has Contents/Helpers/modelplan-credential-agent plus
Contents/Resources/credential-agent.json. The manifest holds schemaVersion=1, sha256,
bytes, inputSHA256 and bundleIdentifier. A trusted artifact pin is supplied separately
from either bundle; neither App can approve its own replacement helper.

Run tools/check_embedded_agent.py --pin <trusted-artifact-pin> <build1.app> <build2.app>.
It rejects differing bytes, descriptor/input changes, missing/symlink members and
untrusted self-consistent replacements. Its hand-made fixtures test packaging logic
only. Real two-App embedding, helper reproducibility, process supervision and native
Keychain permission checks remain not-run.

## User-facing permission contract

App-only updates preserve the exact helper bytes and therefore its partition identity.
Only a helper upgrade changes that identity and can require one re-approval. Do not
promise persistence across helper upgrades or claim A14 without Developer ID. Synthetic
helper permission tests and the owner's eventual real login/ACL confirmation remain
separate evidence levels.
