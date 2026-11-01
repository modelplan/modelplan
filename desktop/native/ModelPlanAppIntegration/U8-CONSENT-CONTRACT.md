# Shared consent backend for Settings and first run

The normal entry exposes `app.scopeConsentEntry`. It is backed by the existing
EngineClient, accepted EngineStore event fanout and live ConsentGrantFactory.
Do not create a second consent service or restore grants from local reader
booleans. Requirements: SET-9-17, SET-9-20, FR-9-05.

## First-run consumer

1. Call `try entry.makeFirstRunView(language:)` before loading current facts.
   It returns a separate view over the same controller as Settings. Repeating it
   reuses the view/draft and applies the language without resetting choices.
   A pending mutation produces `PresentationError.mutationInProgress`.
2. Explicitly inspect via `await entry.controller.inspectConsent()` when the
   owning first-run flow requires current facts. Construction sends no command.
3. Newly presented first-run facts do not pre-check any unset scope. Select all
   includes available standard paths and excludes browser sessions. Existing
   accepted `allowed` state remains authoritative; absence means ask again.
4. The consumer owns the confirmation UI: `requestAllow()` produces a confirmation
   and `await confirm(id)` dispatches only the explicitly confirmed intent using
   current accepted context/version. Completion is not permission readback.
5. On dismissal call `entry.endFirstRunPresentation()`. It retires that view and
   its callbacks, retaining accepted facts for Settings. Do not call `suspend()`
   merely to close first run: suspension is the app/privacy boundary.

An EngineStore privacy invalidation synchronously clears both presentations.
Restoring after a missing saved grant never replays a mutation, assumes an
entitlement, or assumes a Keychain item survived the update. Existing Settings
local-history defaults remain separate from first-run explicit selection.

## Presentation

The scope surface replaces only the legacy `detectedReaders` / `optionalReaders`
consent rows in the normal Settings pane and search. Per-subscription visibility,
alias and read-only data-source rows remain available and searchable (SET-9-16).
The legacy consent table is not a second product permission model.
Copy diagnostics is absent from scope consent; About remains its home. The
controller's allowlisted-copy API remains compatible, with no new clipboard
writer or implicit copy operation.

`ScopeConsentBuildSigning.current` observes the running process with Security's
[`SecCodeCheckValidity`](https://developer.apple.com/documentation/security/seccodecheckvalidity(_:_:_:)).
Only the explicit unsigned result displays “needs a signed build.” A valid ad-hoc
signature counts as signed for this copy; this promises neither Developer ID,
notarization, Keychain persistence nor a reading entitlement. Unknown validation
errors do not become signed/unsigned or permission facts.

## Validation and integration order

`U8ConsentJourney` is shared by XCTest and `Tests/run-u8-consent-journey.py`.
It drives the real normal entry using synthetic external engine facts, opens
no windows, posts no input and starts no engine child. It verifies one shared
backend, explicit first-run selection, browser exclusion, live grant metadata,
no optimistic grant, signed/unsigned guidance, view retirement, privacy clear
and restore without a saved grant. Native Settings tests additionally assert
that the legacy controls are absent; the CLT runner does not claim XCTest.

This consent backend lands before the first-run composition consumer. U6 drive,
device runs and final-package/L2/L3 evidence are separate later acceptance work,
not prerequisites to merging this backend. Required CI/reviews still apply.
