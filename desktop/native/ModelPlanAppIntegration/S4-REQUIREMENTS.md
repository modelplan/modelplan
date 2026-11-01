# S4 quota truth consumer

Source: `20261101-design-requirements/requirements.yaml`, consolidated
`design-handoffs/review/dock-settings-conformance-20261101.md`, and the
coordinator's decided account-member contract (2026-11-01).
The implementation is isolated in draft PR #401, stacked on #332. It does not
change the official appearance selection, placement writer, first run, or host
dispatcher.

## Requirement scope

| Requirement | Current implementation / evidence |
| --- | --- |
| DOCK-3.3-04 | Only unscoped 5h/session and weekly plan limits in the main pool drive the general rings and tightest. Model-scoped, named-pool, unknown and other-period windows stay card-only. |
| DOCK-3.3-05 | Settings pin uses the member key; the shortest eligible window is outer and weekly (or the longest remaining window) is inner. A single window has no inner ring. |
| DOCK-3.8-05 | Member name/duplicate tag, reported plan name, localized route/source and original observation age. No rendering-time observation. |
| DOCK-3.8-06/07 | Actual reported reset timestamp, formatted relatively at card presentation time. Missing is `--`; past reset is not future fuel. |
| DOCK-3.8-08 | Reported per-account credits balance/unit only. Reset count/earliest reserve expiry are unavailable in current RowsAccount and omitted. |
| DOCK-3.8-12/13 | Extras remain card rows; unknown quota is `--`; absent plan/reserve facts stay absent. No cross-member aggregation or inferred plan. |
| DOCK-3.4-*, DOCK-3.7-*, DOCK-3.8-11 | Partial: wire-to-member signals, card rows and shared notification-ledger sink are prepared. Host wiring, official rendering and real user/device verification await #397. |

Visual/geometry baselines and device acceptance are not established by these
source and non-windowed checks. GLM `DESIGN: pass` and VERDICT remain required.
S1/S2 and the coordinator own any later device run.

## Shared member interface

`EngineDockMenuComposition.accountMembers` projects the same admitted Store rows.
`members` exposes display key, row ID, source, verified subscription reference and
duplicate tag. The Dock content and Settings catalogue use the same member keys.
Structured `duplicateAccountTag` also reaches Dock input/readings for the official
appearance owner, without parsing a display name.
Clearing the Store synchronously withdraws identities, readings and card facts.

`migratingRowPreferences(_:)` is a pure transformation for the one shared
Settings writer to commit. Exactly one unambiguous member inherits a row key;
multiple/zero members drop that row choice. Existing member alias/pin choices win.
The App consumer does not add a competing persistence writer.

## Reversible coordinator rulings (2026-11-01)

For two or more unbound members in one row with the same source, keys are
`<rowId>#<source>#<k>`, where k counts only that collision group in CLI-emitted
order, from 1. Current wire source is `RowsAccount.route.rawValue`. All members
retain a nozzle/tag. `isStable` is false and `persistenceDisabledReason` is:
“can't be told apart until the account is verified” / “账号验证前无法区分”.

Placement, order and hide choices on these keys are **session-only**. The existing
M2 writer must route them to memory and display the reason; this integration is
not claimed complete here. The pure `persistentPreferences(_:)` guard strips the
declared temporary namespace from subscription settings/order/hide, even after
rows clear or a verified ref replaces the key. Placement writers can use
`isUnstableKey(_:)` for their own keyed state. No Store writer is added by M4.
Verification starts a new stable key from the verified ref with **no migration**
of temporary choices. Stable choices are retained.

The merged wire provides optional `modelScope`. A general window must omit it,
use the `main` pool, and have a role/limit pair of session with `main` or
`five_hour`, or weekly with `main` or `weekly`. Unknown and other named limits
or pools are not general. Labels and IDs never establish scope. Within a role,
the tightest window is ordered first (stable ID breaks ties), keeping rings and
role pins independent of CLI array order.

`memberInstability` exposes a flag per admitted Dock member. The consuming M2
placement writer and M3 scope selection must discard unstable session choices
when the member list refreshes; their actual write paths remain owned by those
lanes and are not claimed complete by this projection.

Draft integration gates remain: M2's real session-only write path/Settings reason,
M0's official duplicate-tag presentation and the existing host card-content seam.
No new edits are made to those owners' files by this ruling update.

## Journey checks

`S4QuotaJourney` is shared by XCTest and `Tests/run-s4-journey.py`. It constructs
the production normal entry, replaces only the external engine with synthetic
rows, opens no windows, posts no input and starts no engine child.

Observed red→green tracers:

1. A restricted 2% weekly window, a 1% code-review pool and an unknown limit
   cannot replace the 24% general weekly window. Tests vary ordering and cover
   restricted-only inputs, so neither ring nor tightest invents a general value.
2. Two verified members: baseline produced one tool row; projection now produces
   two nozzles/catalogue entries with independent account facts.
3. Actual Dock card content: baseline lost the reported plan; card facts pass
   independent per-member balances and absence checks.
4. Presentation time after the reported reset: cached countdown failed; retained
   timestamps now format against the actual presentation time.
5. A verified member plus two same-source unbound members and one other source:
   old collision withholding failed. All four nozzles now remain, with collision
   ordinals 1/2 rather than row positions 2/3, canonical reasons and stable flags.
   Verification replaces the key without migrating temporary choices; the pure
   guard remains non-persistent after clear. This is policy-seam evidence, not
   evidence that M2's actual UI writer has adopted it.

The journey also covers member-key pinning, one-member/multi-member preference
migration, explicit member preference precedence, unknown plan/quota/reserve/age,
and synchronous withdrawal. XCTest execution and external CI are separate facts;
the CLT runner does not claim to execute XCTest.

## Reset notice unification

The provider derives one `DockSubscriptionSignal` per admitted member from
explicit public events. Linked confirmations supersede their announcements;
wire expiry caps the shared notice lifetime and a current restarted reading
clears a confirmed notice. The App notification sink uses the Settings
`NotificationPolicy` and `NotificationLedger`, keyed by row and `id:status`,
and persists only the shared ledger. Dock/menu acknowledgements belong to the
host's in-memory `DockAttentionState`; they are not notification deduplication.
The test exercises these projections and a synthetic delivery/restart path.
The host's `DockContent.signals` integration remains pending #397, so this
preparation does not claim visible Dock, sliver or menu indicators.

## Main/language integration turn

The ordinary main merges include the upstream Kiro clock fix, #404 model scope,
and #406's capability-gated reset-event wire. An absent event field remains
unsupported; events are never inferred from personal quota.

The normal-entry language journey switches Chinese → English → Chinese and
checks Dock/menu/card copy for each setting. It was behaviorally red on raw
`money`/`other` units. Units now render as localized Credits/Balance/Reserve facts;
unknown currency or unit stays explicit, with no invented denomination. Quota
labels use 5h/Weekly/Other, with reported other-period descriptions retained.
Reading age uses user-facing reading copy rather than internal observation
wording, and duplicate account tags use 账号. Proper model/plan/user names remain
reported data rather than being guessed or translated by the App.
