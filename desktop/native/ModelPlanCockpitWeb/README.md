<!-- SPDX-License-Identifier: MIT -->
# U11 native cockpit bridge

The local WKWebView consumer of the web contract in public #355, pinned here to
`f25e1e821411bdd58cb09d9a388b9064505e856c`. The web source stays in
`desktop/cockpit/`; this package has no renderer, copied DTO or private art.

Production borrows its one existing `ProcessEngineClient` through
`CockpitStoreFanout`; it does not construct another client for Console. The
coordinator's standalone `makeClient` API remains for isolated hosts/tests.
`cockpit/query` is issued only after page ready, and its ordered typed response
goes directly to `CockpitWindowController.display`. The coordinator stores query
identity, never a pending private DTO.

The normal startup path is `CommunityApp.main` → `runEngineRows` →
`EngineRowsEntry.make` → `CommunityCockpitApplicationFactory.make`. Its existing
`EngineDockMenuApplication.showConsole` owns one cached surface used by both
Dock `showConsole` and the status-menu Console action. The Dock callback is
unchanged; the only leased action seam is the default factory forward in
`EngineRowsEntry`. App package declarations are append-only relative to #332.

One `ProcessEngineClient` feeds `CockpitStoreFanout`: the existing EngineStore
clears/applies its synchronous sinks first, and the cockpit then handles the same
ordered typed event before acknowledgement. No cached Store DTO is re-stamped.
The coordinator weakly borrows that shared client; closing cockpit cannot stop
Dock/Settings. Window/bundle creation waits for the explicit Console action.

Both selectors have a same-factory/same-client regression. Clear-order coverage
checks Store sinks are cleared before the WK acknowledgement barrier. Settings
and Choose setup use the existing Settings action; missing content/helper/context
has a reason plus Settings/Dock-readings next steps. History is explicitly
unavailable until its surface is delivered. The verifier alternates the two real
selectors through this same entry factory. Full sealed-candidate/owner-shaped
and fidelity acceptance remains separate.

Before candidate assembly, build the canonical selected edition, then stage its
verified bytes into U10's existing `desktop/cockpit/dist` input:

```sh
npm ci --prefix desktop/cockpit --ignore-scripts
npm run build:official --prefix desktop/cockpit
node desktop/native/ModelPlanCockpitWeb/prepare-candidate.mjs official
```

M0's existing U10 assembly copies that directory to `Resources/Cockpit`; it is not
a second editable web source. Community staging uses the community build and
`prepare-candidate.mjs community`; no reserved input is required. Missing/mixed
resources produce a human unavailable path. Signing/publishing remains with the
packaging owner. Generated-wire synchronization after the normal main merge
changes only the schema-SHA header; the Cockpit DTO/validator is byte-identical.

Before acknowledging `clearPrivateViews`, the consumer hides the page, cancels
query identity and awaits an authenticated matching `cleared` receipt, or
completely discards the view after two seconds. Unknown next floors use the last
known context with a new page revision and remain blocked; a later authoritative
context is adopted through another explicit clear. Old query tickets cannot be
retagged. Session `s-<UUID>` from ProcessEngineClient maps bijectively to that UUID
in the page contract; unsupported session formats fail closed.

Only a nonpersistent, fresh page is made on open. Native visible, occluded and key
signals are separate, event-driven and deduplicated; App hidden/deactivated and
window miniaturized states are forwarded too. No idle poll or rAF exists in this
product package. Close removes handlers/observers, cancels the clear deadline,
releases the web view and sends unload best-effort without awaiting indefinitely.

The manifest must be explicitly pinned. Community is the default; official needs
explicit admission. Regular files only, no-follow directory-relative opens,
strict relative paths, exact inventory and repeated SHA checks prevent serving
unlisted, changed or symlinked content. Caps: 4096 files, 8 MiB/file, 64 MiB total,
8192 walked entries. Remote/subframe/new-window navigation is denied; the sole
`cockpit` handler checks actual WK frame, origin and current page URL. JSON uses
argument transport, strict reply field sets, duplicate/nesting rejection, a
1 MiB cap and canonical decimal UInt64 strings. No private WebKit selector is in
this product's release build; optional verification hooks are compile gated.

The first actual preflight found no installed page API at navigation completion. The local scheme handler
initially supplied a plain URLResponse; WebKit requires an HTTP response with
CORS headers for module fetches ([WebKit contract](https://bugs.webkit.org/show_bug.cgi?id=205198)).
The response supplies JavaScript MIME, explicit noncredentialed static-file
CORS and no-store. That alone did not resolve the actual failure: the complete
module graph had been served but had not evaluated when native delivered load.
Bootstrap now awaits the exact pinned entry module before load delivery, with
no polling or idle timer. The actual repeated-window preflight and three cycles
then pass. A regression guards the response boundary, and Doctor refuses any
budget run without the installed page/query/RAF receipts. Private data is never
served by this handler. Native failure receipts contain only bounded stage
names, with no message bodies or engine values.

## Verification

```sh
swift test --package-path desktop/native/ModelPlanCockpitWeb \
  --scratch-path .tmp/u11-build --jobs 2
swift build --package-path desktop/native/verification \
  --scratch-path .tmp/u11-host-build --jobs 2 \
  -Xswiftc -DMODELPLAN_TEST_ONLY_SPI
```

Unit tests cover clear-before-consumer-ack, stale delivery, unknown floor,
retired epoch/session, exact action membership, lossless UInt64 and bundle
integrity/symlink boundaries. The real test-Mac run uses the verification skill,
synthetic HOME/TMP, the published CLI v0.5.48 in offline/read-only mode, a fresh
announced epoch, watchdog and stop hook. It uses the same native coordinator and
window, not a lookalike HTML host. Test-only RAF positive control is stopped
before idle sampling; U12 still/3D is absent from this bundle.

Target: App + WebContent mean <=6% of one core. Unit tests and headless/Linux
estimates do not prove that target, actual candidate reachability, fresh plus
owner-shaped production behavior, official pixel fidelity or L2. Keep the draft
until the separately linked native evidence and candidate assembly are reviewed.

The hosted real-client positive fixture additionally creates an empty `.codex`
inside its disposable HOME. Without explicit synthetic tool presence it depended
on the host's installed-app detection; clean hosted Macs correctly had no
`cockpit/query` scopes. No account, credential, quota or real tool profile is
created. Production scope admission remains unchanged.

## Measured synthetic CPU target

[Native run receipt](../verification/results/u11-native-20261030.json): native
`9f9d360a97f3523821375be9cfb912e30b450c5c`, unchanged official web manifest
`985b744bb0b97acd8f550fe3be1e103efeb5db4c9a50d52f677b7f0566e07c77`.
Three App+WebContent one-core means: **1.4195 / 1.0092 / 1.1146%**; mean
**1.1811% <=6%**. There are 180 settled-idle checkpoints with zero rAF/timer
counts, separate from the deliberately nonzero RAF positive controls.
Both Apps exited0, watchdog and observers stopped, and run leases/synthetic
scratch were released. App post-close RSS: 72.11 / 72.14 / 73.84 MiB; no numeric
memory pass is claimed. Child resident bytes remain separately labelled ps-rss.
This passes this fresh-profile CPU target; it does not bind the private candidate
entry or establish populated/retained-owner-profile fidelity or U13/L2.

## Shared production-entry run

The corrected single-client route has a new
[relative numerical receipt](../verification/results/u11-shared-console-20261030.json),
measured at `74f2396fe853c0737936869cf9b52ca6e5e6f422`. The real
EngineRowsEntry factory and its Dock/status-menu Console selectors delivered
three complete cycles. App+WebContent: **1.8510 / 1.5793 / 1.6744%** of one core;
mean **1.7016% <=6%**. Both Apps exited0; guardian, observers and run leases were
cleaned. M4 approved the unchanged shared action seam at d3eba026. The native
head's CI passes. No old standalone/partial-run result is substituted.

The automatic U10 staging change is owned by M0 in #367. Per coordinator decision,
that separate task does not block native-ready promotion; no candidate is cut
until #367 merges and its gate rejects a placeholder/missing manifest. The
proposed step is retained in `u10-cockpit-stage.patch`.
Inherited merged-main consent construction remains staged and is explicitly
outside U11's done criteria by coordinator scope acceptance; Settings adoption
stays with its owner. Sealed-candidate, owner-shaped, official fidelity and U13/L2
are separate gates.

## Current v1 bundle pin

Production now pins #355 `f25e1e821411bdd58cb09d9a388b9064505e856c`.
Official manifest: `b0acd07ad0e4f6e5c2fef1e5e70f1413d96c1b81bf6f689ef4b911b448fd9360`
(1069 files); community: `a06423b7730a3b158ff61e1d20d85a649301ae58717877eba48b0c2a0dc5aafe`
(28 files). Session metadata remains plain tool/project/title/time text.

Active page entry, bridge, text renderer and finite-animation CSS are unchanged
from the accepted shared-route measurement. The build now copies only current
compiler outputs. No new performance measurement is asserted or required for
this repin; the historical receipt retains its actual measured source/digest.
The coordinator accepts the prior 1.7016% result pending Tier2 review and keeps
U10 staging separate in #367. DevShared and GUI remain paused; local regressions
only were used for this update.
