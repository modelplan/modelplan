# Instrument models, engine table and fader banks

An independent MIT Swift library for quota rows, effort comparisons, fader readouts,
main-screen pages and record lines, plus AppKit engine-table and fader-bank views. Pure models
use Foundation; rendering uses AppKit/CoreText/Core Animation. There are no bundled
visual assets, process launches, network reads, persistent state or model-setting writes.

Inputs are immutable presentation values. The assembly adapter must supply the
verified Core join, its publication usability, fresh attributed readings and an
explicit clock/calendar/language. This package does not decode a second wire format
or compute scores, rankings or recommendations.

## Rules

- Missing quota windows produce absent cells. An existing unreadable window has
  a nil value, formatted as `--`. Only general 5h/weekly windows occupy those rows;
  monthly, daily, scoped and additional windows enter Other, tightest first.
- Calendar-window time dots require the actual duration. Passed reset readings
  become unavailable; no refill is inferred. Core must also apply its expiry ledger
  before constructing inputs, including after clock rollback.
- Comparison values and chart profiles share one current reference. Equality
  includes fast mode. Equal-current trial values are absent, with an unlit panel;
  equal configurations share a chart profile. Unknown current never borrows ★.
- Compatible metric bases are required for ratios. Fast task time is withheld
  when the publication marks it unknown; qualifiers are retained. The caller must
  match fast tiers to the model/tool and must not infer account entitlement.
- Normal fader LCD cost is current/recommendation; trial LCD cost is trial/current.
  Equality and missing costs suppress the multiple. Compact English trial costs
  and long recommendation labels follow the small-screen omission rule.
- Generation rates use eligible token/duration sums with at least five samples.
  Today, seven-day and thirty-day summaries stay separate. Even unique current
  source bindings do not prove historical account ownership. Source-wide histories
  retain their basis; subscription breakdowns require verified historical attribution.
- Usage buckets preserve nil versus zero and DST hour identity. Heatmaps cover
  26 calendar columns, Monday first, with no future or fabricated coverage cells.
  A heat cell's intensity describes its recorded portion; its tooltip still exposes
  missing subscriptions. Overview totals require complete selected inputs.
- Projects keep CLI order. Multi-subscription totals are never attributed to one
  subscription without an explicit breakdown. Project names can be removed before
  all destination and record output. Record rates are the session's own fresh 60s
  readings; a missing rate is never borrowed.

## Run the unit tests

Use an installed full Xcode for XCTest; do not switch the global developer path.
On the lane workstation check disk and the lane cache before every run:

```sh
df -h ~
du -sh ~/mp/build/M3
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ~/mp/bin/heavy \
  swift test --package-path desktop/native/ModelPlanInstruments \
  --scratch-path ~/mp/build/M3 --cache-path ~/mp/build/M3/cache --jobs 2
```

Fixtures use synthetic IDs and values, a fixed clock and explicit calendars. Test
families cover quota boundaries/unavailability/paging, reserves, current/★/trial,
fast qualifiers, weighted rates, hourly/daily coverage, DST, history and records.
They are nonvisual contract examples, not frozen visual acceptance evidence.

The parent `desktop/native/Package.swift` and native CI now register the instruments
library and XCTest target. Shared manifest/workflow changes remain assembly-owned.
The nested manifest also provides a focused, independent validation path.
CLI adapters and app assembly remain integration-owned. Pure tests do not establish
official pixel, physical input, accessibility or performance acceptance.

## Engine-table integration

`EngineTableView` consumes the existing quota/Today/reserve columns, explicit names,
language, clock, scope and page. It emits typed scope/page/add-subscription intents;
the app routes the last intent to Settings → Subscriptions. Slot keys retain stable
IDs across refreshes. Empty bodies expose the add action to pointer and accessibility
press, while only their keys enter the keyboard sequence. Unknown quota values stay
`--`, absent windows stay blank and a reported public reset never refills a quota.
This includes a table with no subscriptions. Other keeps its compact `+N` reading,
while its shared hover/focus/accessibility explanation contains every supplied
window's period, scope, remaining reading and reset, respecting evidence validity.
The quota's short AX label is separate from that complete help, so additional
windows do not consume the recipe's label budget or truncate their descriptions.
Scope keys also expose their actual current-page shortcut in the accessible label
and shared hover/focus help; these facts do not add a painted legend.

Updates prepare every throwing drawing/text surface before committing presentation,
controls or layers. A failed preparation retains the last committed state and an
identical-input retry remains eligible after the provider recovers.

The default `NeutralEngineTableRecipe` is complete without files or private checkout.
Trusted assembly may explicitly inject `EngineTableRecipeProvider` for official
resources. The generic drawing schema contains no official coordinates, silhouettes,
font names or palette. It validates bounded commands/geometry and shares a 16 MB
decoded-resource budget across nested operations; providers own bounded caches.
Text uses the first fitting supplied wording, without shrinking its requested font.
Persistent controls preserve focus and AX help; bounded reading fades end after their
supplied duration and Reduce Motion suppresses them. Unchanged snapshots do not repaint.

The host should connect `onHelpChange` to its shared, safe-placement help presenter;
the standalone neutral host has an ordinary popover fallback. Hide/blur calls
`suspend()`, teardown calls `dispose()`. There is no polling/render loop or global
input monitor. Official recipes, licensed font bytes, source goldens and visual
evidence stay private; passing this target's neutral tests is not visual approval.

## Fader-bank integration (B12)

`FaderBankView` consumes the joined, ordered `FaderChannelInput` values and emits
selection, inspection, local-trial, bank and favourite intents. The assembly owner
routes them to the shared selection/navigation/preferences layer. This batch does
not implement the comparison screen or write a model/session setting.

There are three slots per bank and one fader per unique model. Favourites precede
the remaining caller order. Every native effort key/label is retained, including
single-setting and six-plus-setting models; missing current stays `--` with a
parked cap. Ability bars require compatible published bases. Other-session marks
and indicator help use supplied attributed sessions, with the caller's privacy
choice. Vendor identities remain separate from status and trial tones.

The real cap follows reported current. Pointer drags own a continuous ghost while
the local trial follows the nearest native detent. Label presses, slider Up/Down
and accessibility increment/decrement use those same native keys. Repeating the
same label ends its trial; bank changes and explicit `endTrial()` also end it.
`selectModel` reveals its bank. A short LCD press emits inspection; a 520 ms hold
toggles a favourite, returns to bank 1 and consumes the release. An accessibility
custom action provides the same favourite operation without a timed gesture.

The provider supplies physical detent positions with at least 20 pt separation.
Caps glide for 280 ms unless pointer-owned; changed LCD readings fade for 80 ms.
Returning ghosts fade after the glide, or fade in place for 120 ms under Reduced
Motion. Surfaces are prepared before committing state; missing resources preserve
the prior state and identical requests can retry. Unchanged updates and movement
inside one detent reuse prepared text. Controls survive refreshes; reordering keeps
keyboard focus on the same visible model. Hover/focus/AX share the help catalogue.

The default `NeutralFaderBankRecipe` needs only system fonts. For long names or
native labels, construct a presentation and use `minimumSize(for:)` before sizing
the neutral view; it preserves whole supplied aliases and grows its ordinary
layout. An injected official provider owns its frozen geometry and resources.
The compact six-plus-effort official arrangement still needs a coordinator
decision; the neutral model/view support does not approve that visual case.

Refreshes without a `trial` argument preserve the local trial. Hosts explicitly
clear it with `setTrial(nil)` or `endTrial()`. Connect `onHelpChange` and `onIntent`
to shared presenters/controllers, call `suspend()` when hidden and `dispose()` at
teardown. Native pointer/VoiceOver/display/performance and official appearance
acceptance remain separate from synthetic unit and offscreen raster checks.

## Main-screen data and local navigation

`InstrumentEvidence` carries the Core verdict, source, read time and optional
deadline. The caller supplies an already-validated snapshot; `.fresh` is the
trusted-adapter default, not an independently inferred source TTL. Core must retire
expired evidence through its clock-rollback ledger before constructing inputs.

Usage inputs retain attribution and daily-turn-start/hourly-completion basis.
Stack/split expose the same stable-ID segments; unknown segments are not zeros.
Raw evidence remains separately available for honest source/age diagnostics.
Source-only totals can be displayed once in All, with their supplied period and
coverage, but never copied into two subscriptions. Duplicate source totals and
incompatible periods are unavailable. The heatmap retains up to 371 local days,
provides 182 grid slots with future slots absent, and exposes per-subscription
coverage, recorded versus complete totals and partial-cell facts.

Subscription data includes optional reported header/source/read time, exact quota
windows, full active reset entries with four compact expiries and overflow,
nullable token/cache detail, separate 7/30-day generation summaries, ten supplied
cycles and supplied peak bands. `hadDrop` stays separate from reset provenance:
it cannot prove redemption or a timestamp. Source-wide statistics have a distinct
field and are withheld from the subscription-specific statistics when unattributed.

`CreditPresentation` now contains only balance, reported drawing state, reading
evidence and the supplied history capability/reason. The preparatory P01
limit/used/remaining/30-day credit-bar API is removed. A zero balance does not
prove credits are being drawn; nil drawing state remains unknown.

`InjectedModelSelection` is an adapter seam for M2's single shared selector. It
carries ordered IDs, selected ID, publication/selection revision, scope and supplied
recent-use evidence. `EffortPagePresentation` preserves that order and raw CLI
`lineageId`/`lineageStatus`/`defaultSelected`/`current` facts. Missing values remain
unknown and false stays false. There is no model-name/score heuristic, local ranking,
second seven-day eligibility rule or new 10/6/3 cap implementation here. Missing or
mismatched selection identity withholds the scored page; missing model IDs remain
explicit. The shared policy retains recent older versions in All and subscription
scope, with an older badge; M2 owns the time/scope/retirement checks.

`MainScreenNavigation` owns a single sourced view/local trial, original return
location, shared selected ID and revision. Same-source activation/Esc/back/close
returns; a new source replaces the old view; direct page/scope/model selection ends
the old comparison. Record `+N` supplies a sourced Destinations → Timeline target.
Session ties use stable IDs, 884 is the exact five-line threshold, and each record
rate must match session/model/effort/fast identity as well as the 60s sample/freshness
rules. Missing identity never borrows another session's speed. Project rankings
retain CLI order and an explicit 7/30-day basis; project names can be removed from
all output while opaque refs remain usable for navigation.

New synthetic page/selection/navigation tests live only in this target's Tests.
Canonical CLI schemas and `testdata/contract-v1` remain read-only.

## Explicit public-default selection seam

The selection seam additionally carries caller-localized `selectionNotice` and
`modelAvailabilityNotes`, plus an explicit `publicDefaultFallback` flag (default
false). Only that catalogue mode can omit a selection revision, with a known
nonempty matching publication ID and the same scope. Known conflicting revisions
still reject. `matchesExact` retains the strict original gate and rejects fallback
mode; comparison metrics continue to require the existing publication-usability
gate. No CLI revision is invented.

Fallback pages preserve caller-provided ordered public IDs even when personal
joining or ordinary exact-selection diagnostics are unavailable. They carry tool
availability/actual-use explanations, never entitlement claims. Empty public data
has a localized `emptyStateNotice`; no missing model is manufactured. The caller
still owns selection/order and supplies public data explicitly. This seam adds no
selection algorithm or view.

## On-demand help logic

`FirstUseHintLedger` stores only the five app-owned boolean flags. Its Codable
representation retains the reference key `r7-help-hints-v1`, ignores unknown or
non-true flags, and can be reset to an empty ledger. The assembly owner persists
that value through its existing preference layer; this target performs no storage
writes. A storage refresh uses `synchronize(with:)` to cancel stale presentations.

`HelpHintQueue` has one active hint, deduplicates pending kinds and prioritizes
trial/pinned requests. Call `advance` immediately after enqueue, then schedule its
`nextDeadline` on the app's monotonic clock. The supplied presentation predicate
checks actual anchor visibility, app focus, available safe placement and help-map
suppression. A failed presentation is not marked seen. Hints expire after five
seconds or on an action; pending hints wait 200 ms after timeout or 750 ms after
an action. Reset cancels active, pending and deadline state before clearing flags.
Reduced motion changes only dismissal fade metadata, not hint lifetime.

`HelpDwell` provides a 500 ms pointer deadline, immediate keyboard-focus text and
leave cancellation using stable control IDs. The caller owns visibility and native
accessibility routing. `HelpCatalog` supplies two-line bilingual explanations and
the identical accessible description, with separate speed bases and relative-time
facts. A semantic `HelpTopic` replaces browser selector matching. `HelpMapCatalog`
provides 13 cockpit and 8 Dock entries shared by held-Option and menu help.

No help view, global key monitor, placement/routing geometry, animation or native
preference writer is included. Tall/compact map placement and actual element
coverage require the frozen presentation integration; content completeness tests
alone cannot prove visual or accessibility coverage.
