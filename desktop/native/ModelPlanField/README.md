# ModelPlanField: nonvisual field bridge and cache

This MIT target implements the native/web boundary, lifecycle and still cache for the optional enlarged field. It contains no renderer, official assets, cockpit layout or visual controls. Product enlargement defaults **off** in `FieldCoordinator`; accepting the integrated minimum-runtime and resource gates is a separate assembly decision.

## Native ownership

Create `FieldConfiguration` using `FieldPublicProjection(publication:)`. That initializer accepts the public publication type, preserves published order/nullable quantities and copies only allowlisted model/effort fields. It has no personal snapshot, current-session, subscription, project, CLI-path or arbitrary JSON parameter. Publication basis/evidence blobs are excluded. There is no ranking or recommendation solver.

One `FieldCoordinator` owns one transport. Its factory can return `WKFieldTransport(resourceRoot:host:)` for the assembled app or a fake transport for nonvisual tests. Constructing/updating the coordinator does not create a WKWebView. Explicit `enlarge()` creates one instance when enabled and unblocked. Native presentation consumes `onChange` to retain the preset until ready/settled, and restore its still on close/failure. It must retain its shipped presets independently of cache success.

The owner forwards surface visibility through `setVisibility`: visible, fully occluded, ordered out, collapsed, or off Space. Fully covered rendering pauses immediately and is released after 5 seconds; uncover during that grace resumes the same instance through an acknowledged configuration. Uncover after release shows the still until explicit enlarge. Focusing another app alone changes none of these inputs.

Use `setBlocked(_:blocked:)` for independent lock, sleep, inactive user session, no-display and termination reasons. Clear each reason separately; wake does not clear a lock and recovery never remounts. `close(.screenRemoved)` handles a one-shot topology invalidation before the native owner reflows to a usable screen. Memory pressure calls `close(.memoryPressure)`, immediately releases the field and drops decoded stills. `clearCache()` releases/invalidate captures before awaiting the app-owned cache clear. The native owner retains responsibility for window/workspace notification registration, display identity and shutdown; no application-deactivation observer is installed here.

All elapsed deadlines use `ContinuousClock`, with one common-mode timer revalidated on every accepted input/restoration:

| Operation | Failure bound |
| --- | --- |
| Ready after mount | 10 s |
| Settled after each sent configuration | 5 s |
| Visible capture barrier + snapshot + image preparation | 2 s |
| Passive enlarged-field inactivity | 180 s, renewed only by meaningful current-instance interaction |
| Fully occluded grace | 5 s |
| Disposed acknowledgement | 250 ms diagnostic window; native detach never waits |

Only one configuration is in flight; the desired configuration is a single replaceable value. Projection/appearance/viewport changes invalidate the pending capture. Generation and configuration/request identities reject duplicate, late and mismatched replies. Failures release and expose the still/explicit retry; no automatic remount loop exists.

## Protocol version 1

Native uses `WKWebView.callAsyncJavaScript` with a structured `message` argument, not interpolated projection source. The only WK script handler is `field`; page-to-native envelopes are bounded JSON **strings**, from the current main frame and local origin.

Every envelope has `version: 1`, `generation` (UUID) and `type`. Native commands also have `requestId` (UUID). Generation is present in the packaged entry URL before page startup, so ready is instance-bound; the spike's unbound-ready bootstrap is not accepted.

| Direction | Type | Other fields |
| --- | --- | --- |
| Native → page | configure / setPublicProjection / setAppearance | configuration {appearance, viewport, projection}, paused |
| Native → page | capture | captureKey |
| Native → page | dispose | none |
| Page → native | ready | none |
| Page → native | settled / disposed | requestId |
| Page → native | interaction | interaction: pointer / drag / keyboard / camera |
| Page → native | captureResult | requestId, captureKey |
| Page → native | error | code: initialization / render / capture |

`captureKey` binds generation, requestId, configurationId, appearance (theme + locale), viewport (width + height + profile + scale), and projectionRevision. Wrong fields/versions/types and oversized envelopes are rejected. Page control replies are capped at 64 KiB; configurations at 1 MiB including an at-most-512-KiB projection. No personal-data snapshot, file, process, network or arbitrary-script command is exposed.

**Capture result is a settled-frame barrier, not a base64 pixel transfer.** After matching that acknowledgement the transport uses the B05a-selected native WK snapshot path while visibly presented. The same 2-second capture deadline includes both steps and image preparation. PNG bytes stay on the native side, with an 8 MiB encoded and 2048×2048 pixel ceiling. The target does not invoke Screen Recording or TCC APIs. Actual no-permission captured pixels still require assembled-app/minimum-runtime verification.

## Packaged page integration

The WK resource handler serves this target's `Web/field-bridge.mjs` as `/field-bridge.mjs` and canonical descendants of the supplied packaged renderer directory. It blocks root/symlink escape, remote navigation, downloads and popups, and applies a local-resource CSP. Scripts/fonts must be bundled. The entry is `index.html` with a module script file; inline script is blocked. Public-source links remain explicit **native** browser actions, outside this protocol.

The packaged page's module calls:

```js
import {installFieldBridge} from './field-bridge.mjs';
installFieldBridge({scene: adapter});
```

The existing private renderer supplies `adapter` with these methods, without adding a second scene/context:

- `apply(configuration, {paused, signal})`: apply the public projection/appearance/viewport and resolve only after a bounded settled frame; honor the AbortSignal and never rebuild the scene for a lineup update.
- `setPaused(boolean)`: synchronously suspend/resume render-on-demand work. No idle display loop.
- `captureBarrier()`: resolve after the current visible settled frame; do not start hidden RAF work or encode a canvas.
- `dispose()`: immediately cancel work, remove listeners and dispose/lose the owned WebGL context. Its promise may settle later without delaying native close.

The bridge provides trusted pointer/drag/key interaction reporting. A camera adapter may call `bridge.interaction('camera')` only for meaningful user activity, never a frame/heartbeat. The renderer retains its existing drag, labels, silhouette and 600 ms camera return; this module contains no drawing or animation source. The private packaged entry and website renderer remain unmodified by this preparation.

## Still retention

Before ImageIO decode, `FieldPNG.prepare` checks encoded size, PNG signature/IHDR, complete chunk boundaries/checksums, nonzero bounded dimensions and overflow-safe pixel count; corrupt images are rejected. It downsamples to a maximum dimension of 640 and re-encodes PNG without source metadata.

`FieldStillCache` uses four theme/profile slots. Each atomic single-file record binds the full capture key, SHA-256 and encoded PNG. Relaunch lookup requires the matching appearance, viewport/scale and public revision, with historical instance/request IDs retained as provenance. A main-actor decoded LRU caps retained images at 8 MiB; disk records are capped at 16 MiB with budget reservation before replacement. Image preparation and all record reads/writes run outside the main actor. Write tickets prevent out-of-order commits and a cache clear from restoring an older record. A capture accepted while visible may finish persisting after close; an unaccepted/invalidated capture cannot enter the cache. Decoded images arriving after memory pressure are not retained again.

Cache clear touches only the four app-owned records, not shipped presets or arbitrary paths. Atomic writes preserve a whole record; corruption, interrupted writes, missing directory/full disk or failed encoding must fall back to the independently shipped preset. Cached official imagery is app-local data and must never enter this public repository.

## Verification and M0 integration

```sh
df -h ~
du -sh ~/mp/build/M2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test \
  --package-path desktop/native/ModelPlanField --scratch-path ~/mp/build/M2 --jobs 2
node --test desktop/native/ModelPlanField/WebTests/field-bridge.test.mjs
node scripts/check-source-policy.mjs
```

The tests use synthetic public data, fake transports and generated neutral image fixtures. They verify protocol/lifecycle/failure cases, PNG bounds, persisted reload, memory/disk caps, symlink fencing and stale commit/clear ordering. They do not establish WebKit helper reclamation, actual screenshot pixels, physical visibility/lock/Space delivery, minimum-runtime acceptance or the integrated ten-cycle performance envelope.

M0 owns shared registration and CI. The root `desktop/native/Package.swift`, Core/Shell and B05a spike are unchanged. Register the same source directory once, with its resource:

```swift
// products
.library(name: "ModelPlanField", targets: ["ModelPlanField"]),
// targets
.target(name: "ModelPlanField", dependencies: ["ModelPlanCore"],
        path: "ModelPlanField/Sources/ModelPlanField", resources: [.copy("Web")]),
.testTarget(name: "ModelPlanFieldTests", dependencies: ["ModelPlanField"],
            path: "ModelPlanField/Tests/ModelPlanFieldTests"),
```

Add the standalone package tests and Node command to CI until shared registration lands; thereafter the native root XCTest invocation includes these tests. M0/native owner forwards surface/workspace events, supplies the app-owned cache URL and packaged private scene adapter, and keeps enlargement disabled until integrated acceptance. No private resources or setup changes are required for the neutral tests.

STATUS M2 P02 done — Nonvisual field protocol, lifecycle and bounded still cache prepared; assembly/resource/runtime acceptance remains with the owning integration lanes.
