# Cockpit integrated freshness and delivery contract

Status: proposed for integrated review. This document is a contract, not an implementation, approval, or release. The integration must carry the complete reviewed Web and native changes; existing findings remain open until trusted reviewers re-evaluate the integrated head.

## Scope and ownership

The native host owns wall-clock observation and at most one next-deadline timer per live cockpit page. The Web renderer computes the earliest authoritative expiry across both quota-window deadlines and reset-event deadlines after each accepted render and reports it to the host. The Web bundle must not create timers. A host tick causes only an expiry re-evaluation of already admitted data; it is not a new engine delivery and cannot change account identity, quota facts, session effort, or publication authority. Expiry re-rendering preserves focus, page, scope, and any in-progress gesture.

READERS owns the Web implementation and its tests on its own branch. M3 owns the integrated branch and native host changes, including bundle pins and native tests. Integrate approved Web changes by a normal merge; do not cherry-pick or rebase. Exact-head review covers the whole integrated diff, including unresolved findings from its predecessors.

## Versioned messages and trust

Extend the existing v2 cockpit bridge, without weakening its closed-shape parsing. Every message uses the existing v2 envelope: `version`, `pageId`, `requestId`, `sequence`, `sessionId`, `storeEpoch`, `generation`, and `viewRevision`, with the existing UUID, canonical unsigned-integer, context, origin, main-frame, monotonic-sequence, size, and lifecycle checks. Unknown fields and unsupported versions fail closed. The source page is the verified pinned bundle, not an arbitrary frame or network origin.

- Web to host: `type: "nextDeadline"` and exactly one additional field, `deadlineUnixMs`, either null (no scheduled expiry) or a canonical unsigned decimal string representing an absolute Unix epoch millisecond. The message is emitted after an admitted render/re-evaluation and belongs to that render's current envelope. Null cancels the current deadline.
- Host to Web: `type: "tick"` with exactly `nowUnixMs`, a canonical unsigned decimal string for the host's sampled wall-clock time, and `reason`, one of `deadline`, `show`, `wake`, `unlock`, or `clockChange`. The page re-evaluates expiry using that time and reports the next deadline, if any, under the current envelope.

Both timestamps must be finite, nonnegative integers at most `8640000000000000` (the ECMAScript date range), with no sign, leading zero except `0`, fraction, exponent, or numeric coercion. Invalid, out-of-range, wrong-source, stale-context, replayed, or otherwise malformed reports are rejected, cannot arm a timer, and cannot restore cleared data. A deadline already due is handled promptly without an unbounded zero-delay loop. The host bounds timer arithmetic and recomputes after clock changes; it never accepts a page-provided time as the current host time.

## Visibility, ordering, and cancellation

While the admitted page is visible and normally running, deliver its next due deadline within one second. Send an immediate tick when the page becomes visible, on wake, on screen unlock, and on a system clock/significant time change. A hidden page sends no deadline requests and receives no ticks; hide or close cancels any pending host timer and retires its callback. Show samples current time anew. A generation, page, session, epoch, or view-revision change cancels the old schedule; callbacks and messages from an earlier context cannot publish or revive content. Clear hides and clears private data before acknowledgement, unload/dispose retires the page, and no timer or callback may outlive its owner. Existing verified-resource, bridge, ordering, privacy and failure boundaries remain authoritative.

## Integrated acceptance

- Native synthetic tests exercise one-timer ownership, deadline delivery within one second while visible, immediate show/wake/unlock/clock-change notification, finite and malformed timestamps, replacement/cancellation, hide/close no-later-message, generation fencing and teardown without leaks.
- Built-page synthetic tests cover quota-window expiry to blank/`--` and reset-event expiry on their respective ticks, preserve focus/page/scope/in-progress gestures during expiry re-rendering, verify no Web timer, a current peer and a genuine current zero, replaced data, stale-generation rejection, clear/unload and no resurrection. They also cover visible/hidden transitions and repeated or past deadlines without a spin.
- Both community and official bundles are built from the same integrated source tree; each manifest and complete inventory is verified and its native pin matches that exact build. The native verified-resource scheme serves SVG as `image/svg+xml` with `X-Content-Type-Options: nosniff`; no unlisted, mutated, or unsafe asset is admitted. The normal `CommunityApp → EngineRowsEntry → verified page` path is tested with synthetic data and the actual pinned page.
- Synthetic no-window and built-page evidence is separate from a real packaged-window/device journey. The latter requires the coordinator's scheduled V1/M1 matrix and the owner's gallery confirmation. `cockpitEntryEnabled` remains false until both are satisfied; enabling is a separate PR.

## Gates and non-goals

The integrated exact head requires current CI, tier-2 MACREV and MACREV2, independent GLMREV, and GLM DESIGN for every cited cockpit requirement. Prior blocking findings remain open until their disposition is explained against the full integrated diff and a trusted reviewer clears them. No existing blocking finding, approval, CI, security, resource, visual-baseline, or review gate is waived. Review/evidence carry is allowed only within the same PR for an allowed merge-only update whose own diff is unchanged and whose binary bytes are identical; carry across PRs is prohibited. The integration PR does not authorize workflow pin or runner changes, account/Keychain access, GUI execution, release, or enabling the cockpit.
