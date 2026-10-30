<!-- SPDX-License-Identifier: MIT -->
# Cockpit web bundle — U11 interface only

A standalone local web surface for the Go `cockpit/query` display contract.
Native WKWebView construction, scheme serving, registration and final-package
proof belong to the native integration lane. This bundle is not reached from the
production app constructor yet. U12 porthole media and live 3D are absent.

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
identities fail closed. The renderer does not infer subscription groups, merge
accounts, classify rows or calculate recommendations; it renders the Go DTO.

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
  "version": 1,
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
| `load` | `appearance: {theme: "day" or "night", locale: "en" or "zh-CN", profile: "full" or "compact"}`. Once per page, after an authoritative engine context exists. Clears first; emits `ready` with the load request ID after DOM readiness. |
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

Page responses are `ready`, `rendered`, `cleared` and `action`, with the same
context/header IDs and the independent output sequence. Fixed actions are
`chooseSetup`, `openSettings` (no arguments), and `openHistory` with a `tool` from
the current displayed rows. Clear invalidates that action membership too. Native
maps these to typed UI intents, never to a command/URL interpreter. No credential,
consent mutation or plugin-install message exists in this protocol.

## Animation budget and evidence

One opacity-only compositor animation uses 60 discrete steps over 2 seconds,
therefore at most 30 visible updates per second. The bundle schedules **no rAF,
timeout or interval callbacks**, including while visible. Visibility/key/occlusion
changes pause/resume it; clear/unload cancel it. Reduced-motion rendering creates
no animation. Headless tests wrap actual browser callbacks, prove the rAF counter
with a positive control, then assert zero callbacks/timers for loaded, ready,
native-hidden, occluded, non-key, document-hidden, visible-again, cleared and
unloaded states. `document.hidden` is controlled in headless tests, not presented
as real OS window occlusion. The WebKit report attaches per-state counts.

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
populates readings, verified subscription members, summary and observation times.
Unbacked faders stay decorative and inactive; Choose setup forwards a native intent.
The empty canopy awaits U12 media. Native owner review still confirms final fidelity.

The target App + WebContent CPU is at most **6% of one core** in the U11a scenario.
Headless tests cannot certify CPU/energy, native cold/repeat-open time, GPU/RSS
attribution, memory returning after native close or repeated-window growth. The
verification skill/test-Mac lane must remeasure those on the actual package before
this draft becomes ready. No hidden prewarm, old-path deletion or U13/L3 acceptance
is claimed here.
