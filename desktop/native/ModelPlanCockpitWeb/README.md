<!-- SPDX-License-Identifier: MIT -->
# U11 native cockpit bridge

The local WKWebView consumer of the web contract in public #355, pinned here to
`44e2ffa4758df79883cb5f0bf2daf6980a4203c4`. The web source stays in
`desktop/cockpit/`; this package has no renderer, copied DTO or private art.

`EngineCockpitCoordinator.makeClient` constructs the existing
`ProcessEngineClient` with a weak ordered consumer proxy. The App retains the
coordinator, passes its existing EngineStore consumer as `downstream`, and calls
`open()` from the cockpit action. `cockpit/query` is issued only after page ready;
its typed ordered response goes directly to `CockpitWindowController.display`.
The coordinator is the sole cockpit query requester for this client. It stores
query identity, never a pending private DTO. Existing clients can instead route
all events through `consume` and call `bind(client:)` once.

```swift
let bundle = try VerifiedCockpitBundle(root: bundleRoot,
    manifestSHA256: pinnedManifestSHA, allowOfficial: explicitlyOfficial)
let cockpit = EngineCockpitCoordinator(bundle: bundle,
    appearance: .init(theme: .night, locale: .en, profile: .full),
    downstream: existingStore)
let client = cockpit.makeClient(configuration: configuration)
// After normal client startup/context delivery, in the App's cockpit action:
cockpit.open()
```

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
