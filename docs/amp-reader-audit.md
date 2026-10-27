<!-- SPDX-License-Identifier: MIT -->
# Amp usage reader admission

The native reader parses the bounded output of `amp usage --no-color`. This is a
balance read, with no input, prompt, execute mode, thread or inference command.
Free/included allowance and paid USD balance are distinct pools; a missing limit
or reset remains unknown. No account or subscription membership is inferred.

Evidence checked 2026-10-27:

- [Amp pricing](https://ampcode.com/docs/pricing) names `amp usage` as a balance command.
- [Amp CLI settings](https://ampcode.com/docs/cli/settings) documents
  `AMP_SKIP_UPDATE_CHECK=1` as disabling all automatic update checks. The child
  receives it along with no-color/English settings and inherited proxy/CA policy.
- The public npm packages `@sourcegraph/amp` and `@ampcode/cli` version
  `0.0.1793104576-gc52692` were inspected without installation or execution. Their
  wrapper selects a platform-specific native executable. The Linux native
  package was streamed for static inspection, without retaining the artifact.
  Its strings confirm `userDisplayBalanceInfo` and update-disable diagnostics,
  but strings cannot establish the complete startup/credential/request graph.

**Admission is held.** No shipped binary digest is certified by this inspection.
CLIJIT must pass an audited **native executable** SHA-256 in `AmpAccess`; a path,
version, wrapper digest or user consent alone cannot admit execution. Future audit
must establish success/error paths, no credential refresh/migration/write, no
inference/thread creation, and one usage request including startup enrichment.
Do not mark a catalogue route audited from synthetic parser tests or these strings.
The missing audit is reported as `not_supported_yet`, with one next step.

The seam is fail-closed without consent, rejects pre-known expired/unsupported
login types before subprocess I/O, and honours passive/off. The cache keeps the
last good balance at its original capture time after failure, with adaptive
cadence and a shared attempt reservation. CLIJIT owns persistent denial, route
admission, revocation/cancellation, Forget cleanup and projection of rich money
results. The reader stays beta until verified on an opted-in real account.

No upstream code, account fixture, package dependency or licensed binary is
included in the repository. Tests use handwritten text and injected subprocesses.

The execution binding is now an immutable anonymous descriptor: on Linux the
selected native executable is copied into RAM, sealed against writes/growth/
shrinkage, hashed **after sealing**, then executed through its inherited fd. A
path replacement or in-place update cannot change the verified bytes. No large
artifact is retained on disk. This uses the already pinned `x/sys/unix` module;
no dependency version or lock changed. Other platforms fail closed until an
equivalent immutable execution primitive and runtime audit are admitted. Future
runtime safety qualification must cover this exact invocation context as well.
