# Shared model selection values

Foundation-only native DTOs and one pure selector, with no dependency on Core, AppKit, WebKit or another lane. Inputs must already be validated and joined to canonical public model IDs by the assembly adapter. This module reads no files, starts no processes and has no model/effort write path.

`ModelSelection.select(SelectionInput)` returns one `SharedModelSelection`. Its `orderedIDs` is the full eligible order; `fieldIDs`, `chartIDs` and `rowIDs` are the first **10 / 6 / 3** of that same order. M3 and field consumers inject this result rather than implementing another filter/order. `ModelSelectionState` stores only local highlight: selecting ranks 4–10 cannot promote them into the rows or change the chart/field prefix. Replacing scope recomputes its shared result; an unavailable highlight clears, and surviving highlights do not affect order.

## Inputs and abstention

- `SelectionScope`: All or one exact subscription ID. An unknown ID never falls back to All.
- `SelectionPublication`: publication identity, nullable selection revision, models in published order and already-tagged published picks. There are no names, versions, ability/cost scores, capability statuses or ranking inputs.
- `SelectionModel`: verbatim nullable `lineageID`, `lineageStatus`, `defaultSelected`, developer ID and explicit published tail/exclusion verdicts. `exclusion`/`placement` are native adapter inputs, not new CLI fields. Supply them only from explicit published legacy/retired/dominated/pricier-twin verdicts; never calculate them locally. Missing placement is not a fabricated dominance decision.
- `SelectionSubscription`: explicit available/unavailable/unknown status and canonical offered IDs. Nil offerings means unknown; a known empty set grants no models. Neither CLI capability support nor an account binding proves availability.
- `SelectionUsage`: exact attributed per-model events, with subscription ID, canonical model ID and event time. Evaluation `now` and `SessionRank.lastAt` must never substitute for an unknown model event time.
- `SelectionWindowUsage(modelID, subscriptionID)`: native membership evidence that an upstream-validated **fresh snapshot** has positive usage for that configuration in its `recent7d` summary. It has no event Date and does not claim one. Canonical attribution is resolved before constructing it.
- `SelectionInput.windowUsage` defaults to `[]`, preserving existing call sites and exact-event behavior.
- `now`: explicit evaluation reference for validating exact events, not a manufactured model activity timestamp.

Current stable candidates require known published lineage ID and `lineageStatus == current`. Missing/null flags stay unknown; unsupported statuses do not become current. All defaults additionally require `defaultSelected == true`. A known false is a global-default exclusion, **not retirement**: it does not bar an available current representative in a single subscription. A nil global-default bit remains nil even when the single-scope rule admits the current model.

**Both All and single-subscription scopes retain published stable `older` models actually used in that scope within seven elapsed days, with `isOlder == true`.** This is the explicit recent-use exception to default selection, including a published false default bit. Exact-event evidence uses the inclusive interval `[now − 7×24 h, now]`; future/nonfinite timestamps cannot prove an exact event. Validated window membership independently proves recent use without inventing an event time; freshness/positive-summary validation remains upstream. Unavailable subscriptions, out-of-scope attribution or a model not offered by that subscription cannot prove the exception. Preview, explicit retired and explicit legacy releases remain excluded even with usage or picks. No alternate older-policy switch exists.

Identical duplicate records deduplicate. Conflicting model/subscription IDs and multiple qualifying current representatives for a lineage abstain with typed reasons; this module does not choose by name, version or score. A recent older exception may coexist with its current representative. Unknown developer IDs are not invented: those remaining models retain publication order after the known-developer round-robin.

`issues` distinguishes unknown metadata/availability, known global-default exclusion, retirement, preview, expiry, conflicts and missing data. All flags remain available in each selected model. A `notGlobalDefault` diagnostic records the known false fact even when other metadata is missing; it may coexist with admission under a single scope or the recent older exception. Consumers use the selected IDs as authoritative and do not refilter them from diagnostic facts. An absent publication yields no invented fallback selection.

## Window attribution boundary (P04)

M0 resolves an explicit `subRef` first; otherwise it accepts only a unique subscription for the source. Ambiguity withholds only that window-use exception, not other already-validated available/default candidates. This selector receives only canonical model/subscription IDs and reuses the existing scope/offered checks; it does not resolve sources, collect more data or broaden CLI/schema inputs.

Do not construct window tuples from stale/unknown summaries, zero/unknown usage, source-wide aggregates or guessed membership. Omission is the abstention path. The caller must refresh/withdraw window assertions when snapshot freshness changes; the model deliberately cannot derive an event timestamp or expiration from an ID-only tuple. Native scope/usage/provenance stay outside the public-only web projection.

## Explicit public-default directory fallback (P04)

`ModelSelection.publicDefaults(publication:scope:)` is the central **labelled public directory** entry point for the assembly's "cannot determine personal selection" state. It does not accept subscriptions, offerings, usage, window evidence or a clock, and does not imply personal entitlement or recent use. Every returned entry has `.publishedDefaultFallback` origin.

The fallback preserves publication order and fields, admitting only nonempty canonical IDs with explicit `lineageStatus == current` and `defaultSelected == true`. Identical duplicate IDs deduplicate; conflicting IDs abstain rather than choosing an eligible variant. Explicit legacy/retired verdicts and preview/older/non-default/unknown-status entries cannot enter. Picks, scores, developer round-robin and lineage winner inference do not reorder this directory; 10/6/3 remain prefixes of it.

Known current/default flags can admit a public directory entry with a missing lineage ID. That missing fact is diagnosed and stays missing; neither lineage ID nor selection revision is fabricated. This exception is limited to this explicit fallback and does **not** relax ordinary `select` lineage/availability checks. A scope label echoes native context; it is not proof that its subscription offers those public models.

The method requires a real `SelectionPublication`. If no actual public data exists, the assembly must show the explicit unloaded empty state; it must not construct placeholder models or fake revisions to call this fallback. A genuinely loaded empty directory stays empty.

## Stable order

1. At most three distinct eligible used models in total: exact recent events first, most recent first (equal times use publication order); then window-only members fill remaining slots in publication order. Exact events retain `.recentUsage(actualDate)`; untimed membership uses `.recentWindow`, never a synthetic Date. Window tuple order and duplicates do not establish chronology.
2. Published `strongest`, `best_value`, `cheapest` picks, in that kind order and publication order within each kind.
3. Remaining non-tail candidates, round-robin in published developer order, preserving order within each developer.
4. Published dominated/pricier twins in publication order.

The stages are applied in order and deduplicate IDs. An actually-used tail model may occupy the first usage stage; otherwise a tail verdict keeps it out of pick/mainstay stages. Tags are consumed, not recomputed, and the ordering is not a cross-vendor quality rank.

## M0 / M3 seam

M0 maps the existing CLI `PublicPublication` and native availability/attributed-use data into these inputs. This package deliberately does not modify Core, the CLI, schemas, canonical fixtures, the root manifest or CI. M3 should consume `SharedModelSelection` (including each model's older/provenance flags), and must replace its older local scope filter instead of adding a second selection algorithm. Field/chart/row consumers receive the same immutable result.

M0 has registered the existing source/tests in the root package; those entries remain assembly-owned:

```swift
// products
.library(name: "ModelPlanSelection", targets: ["ModelPlanSelection"]),
// targets
.target(name: "ModelPlanSelection", path: "ModelPlanSelection/Sources/ModelPlanSelection"),
.testTarget(name: "ModelPlanSelectionTests", dependencies: ["ModelPlanSelection"],
            path: "ModelPlanSelection/Tests/ModelPlanSelectionTests"),
```

Run the independent package explicitly (the registered root target also runs it in native CI):

```sh
df -h ~
du -sh ~/mp/build/M2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test \
  --package-path desktop/native/ModelPlanSelection --scratch-path ~/mp/build/M2 --jobs 2
```

Tests read the existing canonical lineage fixtures without editing/copying them; additional synthetic cases live under this package's Tests. There is no HUD, rendering, bitmap, field context, visual freeze or product enlargement in this package.
