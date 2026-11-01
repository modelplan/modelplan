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
| DOCK-3.3-04 | Named 5h/weekly/monthly windows drive tightest; `.other`, daily and unknown roles stay card-only by period. No window is considered model-specific without an explicit wire field. Labels, IDs and limit/pool keys are not scope evidence. |
| DOCK-3.3-05 | Settings pin uses member key and general role; weekly outer and 5h inner stay fixed. |
| DOCK-3.8-05 | Member name/duplicate tag, reported plan name, localized route/source and original observation age. No rendering-time observation. |
| DOCK-3.8-06/07 | Actual reported reset timestamp, formatted relatively at card presentation time. Missing is `--`; past reset is not future fuel. |
| DOCK-3.8-08 | Reported per-account credits balance/unit only. Reset count/earliest reserve expiry are unavailable in current RowsAccount and omitted. |
| DOCK-3.8-12/13 | Extras remain card rows; unknown quota is `--`; absent plan/reserve facts stay absent. No cross-member aggregation or inferred plan. |
| DOCK-3.4-*, DOCK-3.7-*, DOCK-3.8-11 | Deferred pending the public CLI/wire draft. `EngineRowsEventDecoder` explicitly returns `absentFromSchema`; no quota-derived reset announcement or notification. |

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

The current RowsWindow wire has no model-scope field, so every window is treated
as **not model-specific**. The previous limit/pool heuristic is superseded.
Within a role, the current tightest window is ordered first (stable ID breaks
ties), keeping rings and role pins independent of CLI array order. The exact
optional nullable `modelScope` field request is with the schema/producer owner;
no label, window name, duration or key is used to manufacture it. Actual exclusion
of model-specific windows awaits that public draft and its typed decoder.

Draft integration gates remain: M2's real session-only write path/Settings reason,
M0's official duplicate-tag presentation and the existing host card-content seam.
No new edits are made to those owners' files by this ruling update.

## Journey checks

`S4QuotaJourney` is shared by XCTest and `Tests/run-s4-journey.py`. It constructs
the production normal entry, replaces only the external engine with synthetic
rows, opens no windows, posts no input and starts no engine child.

Observed red→green tracers:

1. With no explicit scope field, the 2% weekly window participates despite its
   model-looking label/ID/limit/pool metadata. The old heuristic selected 24% and
   fails this ruling; role-only selection passes. A 1% unclassified-period window
   remains card-only by its period, not by a model-scope inference.
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
