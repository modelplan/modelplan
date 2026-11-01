<!-- SPDX-License-Identifier: MIT -->
# Cockpit web bundle — U11 interface only

A standalone local web surface for the Go `cockpit/query` display contract.
Native WKWebView construction, scheme serving, registration and final-package
proof belong to the native integration lane. This bundle is not reached from the
production app constructor yet. No porthole imagery is displayed and no live 3D
code is included. Published U12 PNGs may be carried with the verified public
runtime pack; this view does not bind or render them.

## Build and test

```sh
npm ci --prefix desktop/cockpit --ignore-scripts
npm run check --prefix desktop/cockpit
npm test --prefix desktop/cockpit
npm run build --prefix desktop/cockpit
npm run build:official --prefix desktop/cockpit
# Use a restored Playwright 1.55.0 WebKit 2203, or install that pinned browser.
PLAYWRIGHT_BROWSERS_PATH=/path/to/ms-playwright npm run test:webkit --prefix desktop/cockpit
```

Builds are in `desktop/cockpit/.tmp/{community,official}/`, with a SHA-256 file
inventory, edition, MIT notice and (for official) reserved-visual/OFL notices.
The default community build never reads reserved artwork. The explicit official
build uses the already-public c01 canopy and local OFL fonts. The public A5
pack remains available in the official runtime directory. It loads no remote content. No third-party UI/animation
runtime is added. Playwright and TypeScript are development dependencies only.

`generate-wire.mjs` derives `generated/wire.ts`, including `WireCockpitData`,
from the Go-generated `schema/app-cli/app-server.json`. `npm run generate` updates
it; `npm run check` rejects drift. The reachable schema is also the production
runtime validator. Unknown fields, unsupported generator keywords, invalid enum
values, malformed timestamps, duplicate keys, unsafe numbers and invalid
identities fail closed. The renderer uses verified subscription references from the Go DTO and otherwise uses session-only row and route keys. When unverified members share a row and route, keys gain `#1`, `#2`, and so on in CLI-emitted order; these are not durable identities, reset to All on each data refresh, and do not migrate to a later verified reference. It lays out quota windows without calculating recommendations.

## Native consumer contract

Load `modelplan-cockpit://bundle/index.html?pageId=<fresh UUID>`. A loopback HTTP
origin is permitted only for local/headless development. The page refuses other
schemes/hosts and subframe installation. There is no browser `message` listener.
The native WKScriptMessageHandler must independently enforce the main-frame and
local-origin checks, exact page/request/context matching, byte cap and action
allow-list. The web library's source metadata check is not proof of WK frameInfo.
Native navigation/new-window delegates must refuse remote navigation and files
outside the verified local bundle. CSP additionally forbids connections, frames,
objects, workers, base changes and form submission.

```ts
import { CockpitBridge, type BridgeSource, type HostMessage } from './src/bridge.js';
import type { WireCockpitData } from './generated/wire.js';
// Library seams, with a synchronous renderer and a bounded JSON-string transport:
new CockpitBridge(pageId, localOrigin, postToHost, view, newRequestId);
bridge.receive(rawJSON, { origin: localOrigin, isMainFrame: true }); // boolean
bridge.clear(rawClearJSON, source); // boolean; same validated path
bridge.ready();
bridge.documentHidden(document.hidden);
bridge.unload(); // terminal; a new window needs a new instance/pageId
```

The installed page API is `window.modelPlanCockpit.receive(rawJSON)`,
`.clear(rawClearJSON)` and `.state()`. Both receive methods return acceptance.
They do not accept arbitrary JavaScript, commands, URLs or files.

Every host message has exactly these common fields:

```json
{
  "version": 2,
  "pageId": "00000000-0000-4000-8000-000000000001",
  "requestId": "00000000-0000-4000-8000-000000000002",
  "sessionId": "00000000-0000-4000-8000-000000000003",
  "storeEpoch": "opaque-engine-epoch",
  "generation": "41",
  "viewRevision": "3",
  "sequence": "1",
  "type": "clear"
}
```

`generation`, `viewRevision` and `sequence` are canonical decimal UInt64 strings,
so the native adapter must stringify these integers explicitly rather than lose
precision through a JavaScript Number. Epochs are equality-only. Host sequence
strictly increases for the page lifetime. The independent page-to-host sequence
also increases. Request and session IDs are UUID strings. Maximum encoded UTF-8
message size is 1 MiB; parsing is bounded to 48 levels/50,000 value nodes, arrays
of at most 1,024 items, objects of at most 64 fields and strings of at most 65,536
UTF-16 units. These bridge limits do not change the Go transport's 8 MiB cap.

| Type | Additional fields and effect |
| --- | --- |
| `load` | Version 2 only; `appearance: {theme, locale, reduceMotion, reduceTransparency}` and `shell: {profile, attached, forcedClosed, tier, scope}` are required with no extra fields. Once per page, after an authoritative engine context exists. Clears first and applies both states before emitting `ready`. |
| `appearance` | Exact fields `theme`, `locale`, `reduceMotion`, `reduceTransparency`; applies live without clearing displayed data. Theme remains night in v1. |
| `shell` | Exact fields `profile` (`open` or `closed`), `attached`, `forcedClosed`, `tier` (`tall` or `compact`) and `scope` (`all` or a member display key). The native-selected tier maps to the 890 or 640 web layout; the forced-closed cap displays a localized reason. The user shutter emits `shutterToggle`; native shell state is authoritative. |
| `display` | `data: WireCockpitData`. Context must match exactly; no context is adopted from data. Render is synchronous, with no retained DTO/pending-render cache. |
| `visibility` | `visible`, `occluded`, `key`: booleans. Defaults are inactive. Active requires DOM readiness, visible, unoccluded, key and `!document.hidden`. |
| `clear` | No additional fields. New `viewRevision` must be greater. Clears private DOM, derived history-action IDs and animations before adopting context/emitting `cleared` with this request ID. A new epoch may restart generation; the same epoch cannot decrease it. Retired epochs/sessions cannot return. |
| `unload` | No additional fields. Clears/disposes and releases page listeners. Terminal. Native close must not wait indefinitely for page acknowledgement. |

On an EngineClient invalidation, native clears the page before any new private
delivery and awaits its matching `cleared` receipt (or discards the WKWebView on
failure/deadline). An uncertain next floor is not a made-up epoch: clear using the
last known context plus the new view revision, withhold data, and adopt an
authoritative floor only through a later explicit clear. Never retag an old query
reply with the new context. Replays and old view revisions are rejected even when
the consent floor itself did not change. An engine restart can adopt its new
session only through that explicit clear, or by unloading and making a fresh page.

The `ready` receipt additionally has `appearanceVersion: 2` and `capabilities: ["appearanceUpdates", "shellState", "shellActions"]`. Page responses are `ready`, `rendered`, `cleared` and `action`, with the same
context/header IDs and the independent output sequence. Fixed actions are
`chooseSetup`, `openSettings`, `close`, `detach`, `putBack`, `shutterToggle` (no arguments), `scopeSelect` with `key` equal to `all` or a currently displayed subscription-member identity, and `openHistory` with a `tool` from
the current displayed rows. Clear invalidates that action membership too. Native
maps these to typed UI intents, never to a command/URL interpreter. No credential,
consent mutation or plugin-install message exists in this protocol.

## Animation budget and evidence

The lamp is static at idle. A change in displayed readings, reasons, summary or
subscriptions triggers two finite 240 ms CSS opacity pulses (six steps per pulse,
25 updates/s), then stops. Identical deliveries and observation-time-only updates
do not restart it. Comparison uses the current DOM within render; no private DTO
or signature is retained. A hidden, occluded or non-key page cancels the pulse;
returning visible never replays it, and offscreen changes are not queued.
Clear/unload cancel it and reduced motion creates no animation. Unused prototype
animation declarations/keyframes are removed; the bundle has no infinite CSS
animation declarations and schedules **no rAF, timeout or interval callbacks**.

Headless tests scan computed animation-iteration-count on every element and its
pseudo-elements, plus runtime effect iterations, with negative controls for both
elements and pseudo-elements. The rAF positive control precedes zero-count checks
for loaded, pulsing, visible-idle, hidden, occluded, non-key, document-hidden,
visible-again, cleared and unloaded states. `document.hidden` is controlled in
headless tests, not presented as real OS window occlusion. The WebKit report
attaches per-state counts; visual comparisons also enforce finite iteration counts.

Existing visual comparisons cover full 636×890 and compact 636×640 and both languages, using synthetic Go captures. The S6 v1 cockpit renders night only; existing day baselines and prior engine-table images require owner review before replacement. Ubuntu 24.04 arm64/WebKit 2203 is the
pinned baseline profile. Reference images stay under the reserved visual license;
regeneration requires review. They are implementation references, **not**
owner-confirmed pixel fidelity or native WKWebView baselines.

The owner-released G/P6 prototype at
`1d3f82429f1b853314ee120d4bd0007f84fc051d` supplies the plate/port/engine/deck/tape
hierarchy, layout calculation and CSS. [Provenance and exclusions](../../docs/borrowed/cockpit-web.md)
record the MIT release and source hashes. Resource imports, vendor logos, mock
bootstrap, canvas/3D and timer loops are removed. Tool names are text. The Go DTO populates subscription-member quota readings and the summary. Unbacked faders and setup controls are hidden. Scope selection emits a bounded `scopeSelect` action with `key`; the native host validates it against the current display, retains it for the cockpit session and returns it as `shell.scope`. The Dock does not follow cockpit scope in v1. Version-2 appearance and shell messages require a compatible native host; M3 owns its integration and repin.
The empty canopy awaits U12 media. Native owner review still confirms final fidelity.

The target App + WebContent CPU is at most **6% of one core** in the U11a scenario.
Headless tests cannot certify CPU/energy, native cold/repeat-open time, GPU/RSS
attribution, memory returning after native close or repeated-window growth. The
verification skill/test-Mac lane must remeasure those on the actual package before
this draft becomes ready. No hidden prewarm, old-path deletion or U13/L3 acceptance
is claimed here.

Vendor identity marks are locally bundled PNGs with their sources and third-party rights notice in `vendor-marks/SOURCES.md`; unknown vendor keys render text only.

The v1 strip uses the existing official vector mark in the official edition and a
neutral community mark in the community edition. Settings, detach/put back and
close are icon keys with localized accessible names. The ALERT lamp stays off:
the current cockpit wire does not supply alert state or acknowledgement. Session records and Option help remain post-v1. The v1 shutter emits the existing `shutterToggle` action; native shell state remains authoritative. The inactive ALERT lamp does not imply alert data.

The named rows require the main pool and no `modelScope`. General limit keys
are `main`, `five_hour`, and `weekly`: 5h accepts `main` or `five_hour`, while
Weekly accepts `main` or `weekly`, with the matching role and duration. Special
limits, named pools, model-scoped windows and unknown limits stay in Other. The
wire schema enumerates roles but defines `limitKey` as a string; the producer
allow-list is in `cli/internal/rows/catalogue.go`. The schema rejects an empty
`models` array; missing `modelScope` denotes no model restriction.

## Post-v1 day theme

Restore the four full/compact English/Chinese day visual comparisons when the day
theme returns to normal entry. Keep their existing baselines for owner review;
the v1 WebKit gate explicitly skips them under the owner decision of 2026-11-01.
