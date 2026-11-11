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
identities fail closed. The renderer uses verified subscription references from the Go DTO; otherwise it uses session-only row-and-route keys. Colliding fallback keys receive ordered `#1`, `#2`, … suffixes and are retired on replacement rather than treated as durable identities. The renderer does not calculate recommendations.

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
| `load` | Version 2; exact `appearance: {theme, locale, reduceMotion, reduceTransparency}` and `shell: {profile, attached, forcedClosed, tier, scope}`. Optional top-level `redBelow` is 10, 15, 20, 25, 30 or 40; absent or invalid values use 25 with a fixed warning. Once per page; clears first and applies both before `ready`. |
| `appearance` | Flat `theme`, `locale`, `reduceMotion`, `reduceTransparency` and optional top-level `redBelow`, applied without clearing data. Both day and night are supported by the web renderer. |
| `shell` | `profile` is `open` or `closed`, `attached` and `forcedClosed` are booleans, `tier` is `tall` or `compact`, and `scope` is `all` or a member key. Native chooses tier; forced closure disables user shutter actions. |
| `tick` | `nowUnixMs` is a bounded canonical decimal timestamp; `reason` is `deadline`, `show`, `wake`, `unlock` or `clockChange`. Only a visible page with a current display accepts it. |
| `display` | `data: WireCockpitData`. Context must match exactly; no context is adopted from data. Render is synchronous; the current displayed data supports deadline refresh and is removed on clear or unload. |
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

Page responses include `ready`, `rendered`, `cleared`, `nextDeadline` and `action`, with the same context/header IDs and the independent output sequence. `ready` carries `appearanceVersion: 2` and the capabilities `appearanceUpdates`, `shellState` and `shellActions`. While visible with displayed data, display, appearance and tick can report a nullable `deadlineUnixMs` correlated to the triggering request. Fixed actions include `chooseSetup`, `openSettings`, `close`, `detach`, `putBack`, `shutterToggle`, `scopeSelect`, `openHistory`, `openField` and `openWebsite`. `openField` may carry `key`, the clicked rocket's published display name (1-64 characters); native resolves it against the published models and focuses nothing for an unknown name. `openWebsite` carries a `page` (`plans`, `effort` or `methodology`) and a short `value`; native builds the public address from them, so no URL crosses the bridge. `scopeSelect` carries `key` equal to `all` or an admitted current member; `openHistory` carries a `tool` from the current displayed rows. Clear invalidates that action membership too. Native
maps these to typed UI intents, never to a command/URL interpreter. No credential,
consent mutation or plugin-install message exists in this protocol.

## Plugin columns (v1.1 framework, D121/D124/D126/D127)

Plugins are bundled modules in `src/plugin-registry.ts` (id, bilingual title, trusted 16 px icon, settings specs,
`render`, `start`/`stop`, `update`). `src/plugin-layout.ts` is the pure page rule: columns = max(3, subscriptions +
plugins), at most six per page, subscriptions first; unpinned plugins only fill free slots of the last page; up to two
pinned plugins stay on page 1. `src/plugin-host.ts` keeps one panel per plugin across repaints, turns empty slots into
plugin columns and runs the empty-slot "+" menu (detected unconnected tools, then plugins).

Lifecycle: a plugin runs only while the page is visible and not occluded (key or not) and its column is on the shown
page. The page has no timers; the host samples. Messages, all with the common header:

- host → page `{"type":"plugins","plugins":{"version":1,"entries":[{"id","enabled","pinned"}],"settings":{id:{key:int}}}}`:
  the saved choices (Settings, `CockpitPluginPreferences.swift`). Sending it also tells the page the host accepts the
  two actions below; without it the page posts neither and keeps page edits to itself.
- host → page `{"type":"pluginData","id":…,"data":…}`: a reading for a running plugin; refused otherwise.
- page → host action `pluginsEdit` with `plugins` (same shape): an edit made with a key's × or the "+" menu.
- page → host action `pluginsRunning` with `ids`: the plugins now running, sent on every change; sample exactly these.

Defaults: a default-on plugin (D121) is on only once the host has sent `plugins`; a page whose host never did draws the
v1 table.

Framework additions for the calendar (v1.1, all generic):

- Data shape: a plugin with `update` must declare `data: {maxBytes, parse}`. The framework refuses data larger than
  `maxBytes` as JSON (at most 64 KiB) before `parse`, the plugin's strict structural check (exact keys, bounded lists),
  runs; `update` receives what `parse` returns. This replaces the placeholder's single-key check.
- Host-side shaping: a plugin may declare `derive(display, now)`. While it runs, the page shapes its data from the
  `display` data it already has (no network, no new host message) on each render and deadline tick, through the same
  shape check. A host that pushes a valid `pluginData` for that plugin takes over: shaping stops for it.
- Tick: a running plugin may name its next repaint (`nextDeadline`, e.g. the next whole minute). The page reports the
  earliest of its own deadlines and the plugins' in `nextDeadline`; the host's `tick` reaches the plugin's `tick`.
  No page timers, and a stopped plugin asks for nothing.
- Expand on MFD (CKP-PLG-07): a plugin with `expand` opens a temporary overlay inside `.mfd-screen` only (the faders,
  the MFD page keys and the option keys stay usable) when its column or key is clicked (not its own buttons) or the
  focused column gets Enter/Space. The framework owns the frame (‹ Back to <page>, title, a status slot, ×). It closes on
  a second click on the plugin, ×, ‹ Back, Esc, an MFD page key (which then shows that page) or the alert lamp, and when
  the plugin stops or the cockpit loses key. `expand.key` sees keys first while it is open. No host action is involved.
- Settings kinds: the calendar has no settings, so `seconds` is still the only kind.

Calendar (`src/calendar-plugin.ts`, `src/calendar-data.ts`, `src/calendar-time.ts`; CKP-PLG-06/07): default on, no
settings. Its data (`version`, `subs` ≤16, `peaks` ≤64, `resets` ≤64, `spans` ≤16, epoch-ms times, ≤16 KiB) is shaped
from `display`: published peak windows (`details.peaks`, cockpitPeaksV1), the user's own 5 h (`session`) and weekly
window resets, reset cards (verified subscriptions only) and announced/confirmed reset events, for the user's own rows
only. All times are local; day boundaries are local midnights (DST days have 23/25 hours).

## Animation budget and evidence

The lamp is static at idle. A change in displayed readings, reasons, summary or
subscriptions triggers two finite 240 ms CSS opacity pulses (six steps per pulse,
25 updates/s), then stops. Identical deliveries and observation-time-only updates
do not restart it. The pulse decision compares the current DOM within render; the current displayed DTO is retained for deadline refresh and removed on clear or unload. A hidden, occluded or non-key page cancels the pulse;
returning visible never replays it, and offscreen changes are not queued.
Clear/unload cancel it and reduced motion creates no animation. Unused prototype
animation declarations/keyframes are removed; the only infinite CSS animation is
the running-session cursor (CKP-STRIP-10), gated on an active, open, visible page and
static under Reduce Motion; the bundle schedules **no rAF, timeout or interval callbacks**.

Headless tests scan computed animation-iteration-count on every element and its
pseudo-elements, plus runtime effect iterations, with negative controls for both
elements and pseudo-elements. The rAF positive control precedes zero-count checks
for loaded, pulsing, visible-idle, hidden, occluded, non-key, document-hidden,
visible-again, cleared and unloaded states. `document.hidden` is controlled in
headless tests, not presented as real OS window occlusion. The WebKit report
attaches per-state counts; visual comparisons also enforce finite iteration counts.

Visual comparisons cover full 636×890 and compact 636×640, both themes and both
languages, using synthetic Go captures. Ubuntu 24.04 arm64/WebKit 2203 is the
pinned baseline profile. Reference images stay under the reserved visual license;
regeneration requires review. They are implementation references, **not**
owner-confirmed pixel fidelity or native WKWebView baselines.

The owner-released G/P6 prototype at
`1d3f82429f1b853314ee120d4bd0007f84fc051d` supplies the plate/port/engine/deck/tape
hierarchy, layout calculation and CSS. [Provenance and exclusions](../../docs/borrowed/cockpit-web.md)
record the MIT release and source hashes. Resource imports, vendor logos, mock
bootstrap, canvas/3D and timer loops are removed. Tool names are text. The Go DTO
populates quota and available details, while absent publication, session and history data remain unavailable. The faders read the publication the engine fetches by itself; until it arrives, or while it cannot be fetched, their channels stay empty and the bank row says the data is unavailable. No prototype fixture is loaded in production. Scope selection is session-only and does not sync to the Dock.
The empty canopy awaits U12 media. Native owner review still confirms final fidelity.

The target App + WebContent CPU is at most **6% of one core** in the U11a scenario.
Headless tests cannot certify CPU/energy, native cold/repeat-open time, GPU/RSS
attribution, memory returning after native close or repeated-window growth. The
verification skill/test-Mac lane must remeasure those on the actual package before
this draft becomes ready. No hidden prewarm, old-path deletion or U13/L3 acceptance
is claimed here.
