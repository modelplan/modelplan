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

The product entry must retain this object and map `onIntent` to typed existing
Settings/Choose setup/history routes. No page message can execute commands,
open a URL, mutate consent or request credentials. An unavailable context does
not create a hidden web view: the caller's `onUnavailable` supplies its status.
This public slice supplies the production constructor seam and a synthetic
executable using it; applying it to the private candidate entry is still an
explicit assembly step, not proven by these package tests.

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

The first actual preflight found no installed page API. The local scheme handler
initially supplied a plain URLResponse; WebKit requires an HTTP response with
CORS headers for module fetches ([WebKit contract](https://bugs.webkit.org/show_bug.cgi?id=205198)).
The response now supplies JavaScript MIME, explicit noncredentialed static-file
CORS and no-store. A regression guards that response boundary; private data is
never served by this handler. Native failure receipts contain only bounded stage
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
