# S4 quota truth consumer

Source: `20261101-design-requirements/requirements.yaml`, consolidated
`design-handoffs/review/dock-settings-conformance-20261101.md`, and the account
member contract recorded in private ticket #695, comment 6551743299.
The implementation is isolated in draft PR #401, stacked on #332. It does not
change the official appearance selection, placement writer, first run, or host
dispatcher.

## Requirement scope

| Requirement | Current implementation / evidence |
| --- | --- |
| DOCK-3.3-04 | General 5h/weekly/monthly windows drive tightest; `.other`, daily and unknown roles stay card-only. Unknown/explicit supplemental limit/pool keys (`other`, `code_review`, `reserve`) also stay card-only even with a general role. Lowest extra does not win. |
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
Clearing the Store synchronously withdraws identities, readings and card facts.

`migratingRowPreferences(_:)` is a pure transformation for M2's one shared
Settings writer to commit. Exactly one unambiguous member inherits a row key;
multiple/zero members drop that row choice. Existing member alias/pin choices win.
The App consumer does not add a competing persistence writer.

**Unresolved contract details:** current RowsAccount has `route`, but no `source`
locator. The provisional fallback is `<rowId>#<route.rawValue>`; colliding keys
are withheld rather than assigned positional/hash identities or duplicated
totals. The exact stable source/collision rule is requested on #697. Similarly,
the wire has no explicit model-scope flag: a model-specific window that retains
a general role and reports general limit/pool keys cannot be distinguished safely.
Unknown or explicitly supplemental keys are conservatively card-only. No classification by label,
duration, provider text or guessed model name is attempted. These are draft
limitations, not completed acceptance cases.

## Journey checks

`S4QuotaJourney` is shared by XCTest and `Tests/run-s4-journey.py`. It constructs
the production normal entry, replaces only the external engine with synthetic
rows, opens no windows, posts no input and starts no engine child.

Observed red→green tracers:

1. General tightest expected 24%, with a 1% extra, shuffled role order and
   disagreeing durations: baseline selected the extra; role implementation passes.
2. Two verified members: baseline produced one tool row; projection now produces
   two nozzles/catalogue entries with independent account facts.
3. Actual Dock card content: baseline lost the reported plan; card facts pass
   independent per-member balances and absence checks.
4. Presentation time after the reported reset: cached countdown failed; retained
   timestamps now format against the actual presentation time.

The journey also covers member-key pinning, one-member/multi-member preference
migration, explicit member preference precedence, unknown plan/quota/reserve/age,
and synchronous withdrawal. XCTest execution and external CI are separate facts;
the CLT runner does not claim to execute XCTest.
