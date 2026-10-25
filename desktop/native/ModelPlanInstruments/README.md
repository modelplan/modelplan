# Instrument presentation data

An independent MIT Swift library for quota rows, effort comparisons, fader readouts,
main-screen pages and record lines. It uses Foundation only. There are no views,
assets, process launches, network reads, persistent state or model-setting writes.

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
  Today, seven-day and thirty-day summaries stay separate. Source-wide histories
  require unique current bindings and retain their attribution basis in Core.
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
Navigation state, CLI adapters, layout, accessibility and visual acceptance belong
to subsequent integration batches.

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
