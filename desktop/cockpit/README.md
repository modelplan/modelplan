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

Page responses include `ready`, `rendered`, `cleared`, `nextDeadline` and `action`, with the same context/header IDs and the independent output sequence. `ready` carries `appearanceVersion: 2` and the capabilities `appearanceUpdates`, `shellState` and `shellActions`. While visible with displayed data, display, appearance and tick can report a nullable `deadlineUnixMs` correlated to the triggering request. While the session strip lists a session, the next whole minute is a deadline, so its elapsed time and "6m ago" move with the host's tick (owner decision D277, CKP-STRIP-16). Fixed actions include `chooseSetup`, `openSettings`, `close`, `detach`, `putBack`, `shutterToggle`, `scopeSelect`, `openHistory`, `openField`, `openWebsite` and `refreshMember`. `openField` may carry `key`, the clicked rocket's published display name (1-64 characters); native resolves it against the published models and focuses nothing for an unknown name. `openWebsite` carries a `page` (`plans`, `effort` or `methodology`) and a short `value`; native builds the public address from them, so no URL crosses the bridge. `refreshMember` (owner D277) carries `key` equal to `all` or an admitted current member and asks native for the widget's per-member re-read. `scopeSelect` carries `key` equal to `all` or an admitted current member; `openHistory` carries a `tool` from the current displayed rows. Clear invalidates that action membership too. Native
maps these to typed UI intents, never to a command/URL interpreter. No credential,
consent mutation or plugin-install message exists in this protocol.

## Plugin columns (D121/D124, D293; CKP-PLG-50…54)

Plugins are bundled modules in `src/plugin-registry.ts`: id, string-table keys for the title (long and short) and the
one-sentence Settings summary, a trusted white line-art icon at the vendor-mark size, the dashed underline colour and
bar ink (only `#87939e`, `#e9edf0` or `#b9c7d6`), settings specs, and three pure functions: `accept` folds a host reading
into the plugin's state (kept across repaints), `column` describes up to three cells in the subscription columns'
Other-cell grammar (small tag · large number · side value · continuous bar with a thin trend line) plus a bottom line,
and `screen` gives the lines of its big screen. Custom draw (D323): when cells cannot express a plugin (a day strip, a
week grid), its `column` or `screen` result may also carry `draw(ctx)`. The host then gives it one clipped area (the
column's cell rows, or the screen body under the framework's title bar) and calls `draw` with that `area`, its size, the
cockpit `tokens`, a per-plugin `memo` shared by column and screen, `opening` and `redraw()`. The key, underline, pin,
"+" menu, bottom line, title bar and lifecycle stay the framework's; a draw that throws falls back to the cells or lines,
a size change draws again, and focus on a `data-focus` element survives every redraw. Plugin strings live in `study/rocket-r1/strings/plugins.js`, each drawn
one with a `<key>Short` form. `src/plugin-layout.ts` is the pure page rule: columns = max(3, subscriptions + plugins),
at most six per page, subscriptions first; unpinned plugins only fill free slots of the last page; up to two pinned
plugins stay on page 1. `src/plugin-host.ts` turns empty slots into plugin keys and columns drawn like subscription keys
and columns (no inner frame, no ×), opens a plugin's big screen inside the big-screen well when its key is clicked
(faders and page keys stay uncovered; a page key closes it), offers Remove on the key's right-click menu, and runs the
empty-slot "+" menu (detected unconnected tools, then plugins). Settings keeps the durable choices in the "Plugins"
section of Settings › Subscriptions.

Lifecycle: a plugin runs only while the page is visible and not occluded (key or not) and its column is on the shown
page. The page has no timers; the host samples. Messages, all with the common header:

- host → page `{"type":"plugins","plugins":{"version":1,"entries":[{"id","enabled","pinned"}],"settings":{id:{key:int}}}}`:
  the saved choices (Settings, `CockpitPluginPreferences.swift`). Sending it also tells the page the host accepts the
  two actions below; without it the page posts neither and keeps page edits to itself.
- host → page `{"type":"pluginData","id":…,"data":…}`: a reading for a running plugin; refused otherwise.
- host → page `{"type":"pluginScreen","id":…}`: open that enabled plugin's big screen (a native action such as the
  widget card's); an open one stays open. Refused before `plugins` or for a plugin that is off.
- page → host action `pluginsEdit` with `plugins` (same shape): an edit made with a key's right-click Remove or the "+" menu.
- page → host action `pluginsRunning` with `ids`: the plugins now running, sent on every change; sample exactly these.

Native host (macrevc-844-1): `CockpitPluginWire.canonical` applies `parsePluginState`'s rules in both directions;
`plugins` is the one nested reply value (at most 4 levels, 64 unique keys per object, 32 items per array, 64 KiB).
The window sends `plugins` on ready, after every clear and on change (never the same state twice to one page);
`pluginsRunning` is accepted without focus, `pluginsEdit` only from the active page. The running set drops to `[]`
when the page goes or is cleared. `CockpitPluginBridge` (ModelPlanAppIntegration) keeps the durable copy in
`cockpit-plugins.json` and drives `CockpitPluginSampler`, which reads registered plugins at their interval.

Defaults: a default-on plugin (D121) is on only once the host has sent `plugins`; a page whose host never did draws the
v1 table.

Framework additions for the calendar (v1.1, all generic):

- Host-side shaping: a plugin may declare `derive(display, now)`. While it runs, the page shapes its reading from the
  `display` data it already has (no network, no new host message) on each render and deadline tick, through the
  plugin's own `accept`. A host that pushes a valid `pluginData` for that plugin takes over: shaping stops for it.
- Tick: a running plugin may name its next redraw (`nextDeadline(state, now)`, e.g. the next whole minute). The page
  reports the earliest of its own deadlines and the plugins' in `nextDeadline`; the host's `tick` redraws the plugin.
  `context.now` is the host's clock. No page timers, and a stopped plugin asks for nothing.
- Settings kinds: the calendar has no settings, so `seconds` is still the only kind.

Calendar (`src/calendar-plugin.ts`, `src/calendar-data.ts`, `src/calendar-time.ts`; CKP-PLG-06/07; D323): default on, no
settings. The day strip (column) and the 7-day week grid (its big screen, opened from the key) are custom draws; the
bottom line shows the time now, and a failed draw falls back to next reset / next peak / reset cards cells and plain
lines. Its accept refuses data over 16 KiB as JSON, then runs the strict parser. Its data (`version`, optional `peakRules` `yes`/`no`/`unknown` (missing is unknown), `subs` ≤16, `peaks` ≤64, `resets` ≤64, `spans` ≤16, epoch-ms times, ≤16 KiB) is shaped
from `display`: published peak windows (`details.peaks`, cockpitPeaksV1), the user's own 5 h (`session`) and weekly
window resets, reset cards (verified subscriptions only) and announced/confirmed reset events, for the user's own rows
only. A reset-card list the producer marks partial or truncated has no exact count and no expiry beyond the one it states; "No rules" is shown only when the peak feed is present and the user has no declared plan. The privacy barrier (clear) drops the plugin readings and the host takeover. All times are local; day boundaries are local midnights (DST days have 23/25 hours).

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

## Maker livery colours (D131, D250)

**D250 (owner 2026-11-13, guanbear/modelplans.ai#716) supersedes D211 "Set 1" for UI accents:** the old pastel palette, completed ("Old+").
It applies to engine tabs, fader strips, record-strip chips and chart series. Rockets keep the website livery (`rocket`). The shared table is the
private site's `src/shell/brandLivery.ts`; `src/livery-shared.json` is its vendored copy and is unchanged by D250.

| Maker | Colour | Alt (collision shade) |
| --- | --- | --- |
| OpenAI / Codex | `#6aa8ff` | `#1352a1` |
| Anthropic / Claude | `#ff9a6a` | `#a0440a` |
| Zhipu / Z.ai / GLM | `#8f7dff` | `#4422a0` |
| Copilot | `#c08cff` | `#6c35a1` |
| Kimi | `#ff8fcf` | `#a03878` |
| OpenCode | `#b5d65a` | `#647c04` |
| Cursor | `#eef2f6` | `#6f7782` (mid grey, reads on light backgrounds; `altFrom: 'app'`) |
| xAI | `#8594a4` | `#374452` |
| Google | `#4eccd3` | `#0b7176` |
| MiniMax | `#f16f7e` | `#900d30` |
| Meta | `#a6dcff` | `#5084a4` |
| Alibaba | `#4ab89a` | `#025e4b` |
| DeepSeek | `#00aad6` | `#0e5166` |
| Xiaomi | `#e89700` | `#794e08` |

Alts are the same hue, lightness lowered by 0.28 in OKLab (`deriveAlt`), so they separate from the main colours. Antigravity `#68d7a1`, Kiro `#f8d376`
and Amp `#83b259` are owner-approved too but have no table row: the cockpit has no vendor key, logo or engine row for them, so adding a row would be dead
until that wiring exists.

Same-screen collisions (CIEDE2000 under 15) now include GLM next to Copilot (9.7) and GLM next to xAI (12.6); the later one takes its alt.
Day theme: marks are drawn at 40% of the colour toward black, at least 3.4:1 on the day metal for every colour. Cursor's near-white would only reach 3.25, so on day Cursor starts from its grey alt `#6f7782` (CSS rule in `prototype-theme.css`).
Night uses the colours as is.

**UI accents only; rockets keep website livery.** The palette above is applied by `APP_UI` and `TOOLS` in `sync-livery.mjs` over the shared table:
`livery-shared.json` stays a verbatim copy of the website's `brandLivery.ts`, so `node sync-livery.mjs --check --source <file>` still demands
identity with it, and the website colour stays in the generated table as `rocket` (Cursor keeps its former `#f79dcb`). Anything that paints a rocket
(launch-field scene developer colours, porthole stills) uses `rocketColour()`, never `brandColour()`.

`app/livery.css` declares the `--mp-<maker>` developer variables for external or private visual packages appended after the frozen
`official-visuals/theme.css` (`build.mjs`); nothing in this repo reads them, so the public build's pixels do not depend on that file.
Contrast floors: night marks are at least 3:1 on the night metal (the lowest are Meta 3.22, Zhipu 3.25, DeepSeek 3.90, MiniMax 4.08); the
enforced bar is the 3:1 in `livery.test.mjs`. Day marks (40% toward black) are at least 3.4:1.
