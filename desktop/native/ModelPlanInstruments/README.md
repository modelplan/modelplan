# Instrument models and native cockpit controls

An independent MIT Swift library for quota rows, effort comparisons, fader readouts,
main-screen pages and record lines, plus AppKit engine-table, fader-bank and main-screen views. Pure models
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

The default policy requires at least 20 pt between native ticks and between
labelled positions. An injected provider can explicitly declare an approved dense
native tick floor (12–20 pt), the native keys with printed labels, and a separate
approved label floor. Both policies default to 20 pt; omitted label metadata means
every tick is labelled. The compact six-plus arrangement explicitly opts both
policies into its approved 12 pt floor. Invalid bounds/keys and spacing below either floor are rejected.
The policy value does not approve an official layout or choose its label positions.
Caps glide for 280 ms unless pointer-owned; changed LCD readings fade for 80 ms.
Returning ghosts fade after the glide, or fade in place for 120 ms under Reduced
Motion. Surfaces are prepared before committing state; missing resources preserve
the prior state and identical requests can retry. Unchanged updates and movement
inside one detent reuse prepared text. Controls survive refreshes; reordering keeps
keyboard focus on the same visible model. Removed/disposed controls are retired;
callbacks verify their current owner identity, and retained custom actions cannot
operate on a former model. Hover/focus/AX share the help catalogue.

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

The five-flag ledger/queue below is the retained preparation-era API. Current
runtime consumers use assembly's single shared arbiter owned by ModelPlanSettings.
These views never instantiate that legacy queue or persist a second hint ledger.

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

## Trial and main-screen navigation (B13)

`MainScreenController` wraps the existing `MainScreenNavigation` and
`EffortComparison`. Models and the exact shared selection/publication join are
injected; there is no second selector, recommendation engine or CLI action. One
sourced comparison/trial retains its original return location. Repeated source
presses return; drag/effort/Fast changes preserve the source; replacement, page,
scope/model selection, bank/favourite activation and cockpit close end the old
trial. Page keys keep underlying option state and discard temporary sourced-page
patches. Comparison page keys are dark; other sourced views retain the underlying
page lamp.

`ComparisonPresentation` keeps three fixed Current/Try/★ slots and the existing
configuration equality/backlight rules. Equal-current Try has no painted values
or separate chart profile. Table values and chart geometry share the current
reference, including valid fast cost/time. Qualifiers and explicitly unknown task
time remain available; unknown current never borrows ★. Missing metric points
break polylines. The ratio axis includes ×1 even in a large fast domain.

`MainScreenView` provides native keys, pointer and accessibility actions, shared
hover/focus explanations and atomic bitmap preparation/retry. It caches unchanged
snapshots, retires removed controls and checks current owner identity on callbacks.
`MainScreenRecipeProvider` injects drawing/resources; the default uses ordinary
system-font panels and needs no files. Inspect `minimumSize(for:)` for long names
or qualifiers. `EngineDrawingCommand.polyline` is a bounded generic primitive;
official geometry, fonts, colours, skins and source SVG receipts stay private.

Ordinary page footers retain three slots, including blank ones; comparison has
the frozen two-slot Back/Fast row with an unused Fast key blank. Injected option
choices print all states. Pointer activation chooses the printed state; keyboard
activation cycles enabled states. Page/session/alert bodies are caller-provided
text snapshots here, for their owning later batches to replace. B13 does not
implement those later page visualizations.

Assembly connects `FaderBankView.onIntent` to `receiveFaderIntent`, then handles
`MainScreenView.onIntents` as one batch: mirror `trialChanged` into the fader's
`setTrial`, route `modelSelected` through the shared selector and mirror
`sourceHighlightChanged` with `setSourceHighlight(controller.sourceModelID)`.
It also marks HUD/record/alert sources. The batch callback takes precedence over
the single-intent callback. `handleEscape()` is offered to the shell before its
close action; `closeForCockpit()` clears trial/source without depending on a page
render. Blur/occlusion calls `suspend()`, actual teardown calls `dispose()`.

## H11 consumer boundary (tasks 80/81)

`InstrumentHintInput` is an explicit injected event boundary. Fader pointer rest
starts/restarts with a typed `FaderRestAnchor` on the travel (also covering the
real cap); the shared arbiter owns its 500 ms deadline/admission. Movement, leave,
down, key/modifier input, focus loss, layout/removal and teardown cancel pending
rest. Drag never requests a displayed hint; release can start a fresh rest.
Candidate emission does not change trial/session. Views own no nine-hint priority,
open/reveal counter, seen flag, per-open budget or hint persistence.

Connect the owned views' `onHintInput` to that one M1 arbiter adapter when available.
Window/app focus cancellation is emitted by the fader; the cockpit owner routes
inputs from other owned surfaces through the same boundary. An absent adapter is
explicitly unbound; ordinary B13 still works and this library does not pretend
the shared policy is integrated. Shared hint display and help suppression remain
with that presenter. The inherited tray Help gap is not fixed here.

Task 81 native titles are separate from custom explanations and accessibility.
Only declared engine subscription-name producers receive native `toolTip`, using
the supplied full name unconditionally, even if it fits. Fader/main-screen and
other engine readings have no native tooltip; their full AX help remains. The
other four permitted name producers are owned by their later/current lanes.
`InstrumentHelpDefinitions` retains exact canonical `eng.todayBasis` and
`tape.liveBasis` copy for shared help/AX and the later Option map; no formula or
statistics period is redefined here.

## Overview bars

`OverviewPageSnapshot` consumes the existing scoped usage/expiry projections and
retains 24-hour, 7-day and 30-day series. Supply the complete stable subscription
identity catalog (and optional explicit palette inks), then pass
`snapshot.pageContent(language:)` to `MainScreenView.update`. Missing readings
remain unknown; recorded zero stays zero, and incomplete bucket totals are marked
partial. Calendar inputs retain 23/25-hour days and repeated-hour offset labels.

`OverviewChartGeometry` supplies stacked/split bars with two-point stack gaps,
proportional heights and full bucket hit regions. Bucket IDs use absolute instants;
neutral palette slots derive from stable subscription IDs, independent of scope.
The default recipe reserves a fixed notice area so plot bounds do not move when
notices change. Tab reaches bucket data and legend names; Left/Right and Home/End
traverse buckets. Shared hover/focus help and AX expose the same complete values,
including missing subscriptions. Unchanged snapshots reuse the existing bitmap.

Operational notices retain severity/expiry order. More opens the existing single
sourced Alerts route; the assembly supplies its detail body using
`MainScreenSourcedBody(.alerts, ...)`. Escape returns through the same navigation.
`OverviewInformationRow` is already-localized, injected offline information: it
appears last only when operational notices leave room. Its optional action emits
`overviewInformationSelected(id)` for the host. This target owns no update service,
network request, second update store or ALERT-lamp state. The first footer selects Bars/Grid; the grid hides the range and stack/split
slots while retaining their prior choices. Official chart drawing stays behind the recipe-provider seam.


## Calendar heatmap

Pass `coverageStart` and/or `coverageBySubscription` to `OverviewPageSnapshot`,
with `initialVisualization: .heatmap` when needed. The snapshot reuses
`UsageHeatmap` for the retained calendar, per-subscription coverage, partial
values and five intensity steps. `OverviewHeatmapData.grid` has exactly 182
slots, Monday first, with future slots absent. Dates before known coverage have
no painted cell or hit target; a missing reading inside known coverage remains
blank and accessible. Without coverage metadata, an actual reading proves only
its own day. A recorded zero gets the zero step, never the missing state.

`OverviewHeatmapGeometry` packs the 26-by-7 calendar and provides date IDs,
month/coverage bounds and cell hit regions. The neutral All palette is grayscale;
a subscription uses its injected identity ink (or the stable neutral fallback).
No official geometry, material or palette is embedded. Native cell help and AX
share full local dates, known/partial totals and every subscription value.
Left/Right moves by week, Up/Down by weekday, skipping unavailable targets;
Home/End selects the first/last available date. Tab also reaches the data and
coverage explanation. These use the existing shared hover/focus machinery, with
no extra tooltip producer, hint admission policy, polling timer or collection.

## Subscription Now

`SubscriptionNowSnapshot` consumes `SubscriptionNowInput` values built from the
existing `SubscriptionHeader`, `InstrumentQuota`, `ReservePresentation`,
`CreditPresentation`, normalized `UsageTokenDetail` and eligible `GenerationSums`.
Pass its `pageContent()` to the main screen with the matching scope and language; rebuild the localized snapshot when language changes.
All shows stable account rows; a single scope shows the header, reader/age,
reported windows, reset reserve, credits balance and selected 7/30-day detail.
Unknown existing windows use `--`; absent windows do not create quota rows.
Quota gauges reuse the existing ten-segment projection. Credits have no quota,
limit, bar or history. Reset expiries show four compact values plus overflow,
while shared help retains all supplied active allowances.

Each usage window carries its own period, attribution, evidence and generation
recording verdict. Source-wide/current-binding/unattributed statistics are not
copied into subscription totals. Known token kinds remain independent of whether
generation-rate recording is available. Generation speed uses the existing
compatible eligible sums and minimum sample gate; cache hit uses only input plus
cache-read, without adding cache-write again. No window borrows another period.

The host owns source-specific freshness and clock/deadline transactions. Supply
updated `now`/evidence even when a revision is unchanged; this target introduces
no TTL, collection, read command or timer. Forward
`subscriptionScopeSelected(id)` to the single host scope owner, then inject its
new snapshot; pressing an account never writes a session or changes scope behind
the host. Now/History occupies slot one with History unavailable until its own
implementation; slot two selects 7/30 and slot three is blank.

`MainScreenListRecipe` adds a bounded native NSScrollView/document with stable
row controls and visible-row vector drawing. All row resources are preflighted
before state commits, including offscreen rows; this target allocates no
full-document bitmap. Tab/arrows/Home/End reveal focused data, and reordering preserves the
focused ID and keeps it visible. Native scroll wheel handling stays with AppKit.
Shared hover/focus/AX explanations use the same complete row values. These new
rows receive no native `toolTip`; task81's six permitted producers are unchanged.
Unchanged snapshots retain the scroll position and bitmap, and teardown removes
the scroll observer and retires old controls. Official row drawing remains an
explicit recipe/resource input.
