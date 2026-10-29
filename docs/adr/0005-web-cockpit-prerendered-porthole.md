# The cockpit runs the prototype web code; the v1 porthole is prerendered

Status: accepted by the owner on 2026-10-29.

## Context

The cockpit was being redrawn in AppKit and Core Animation from a web prototype, with a separate native↔web bridge for the three.js porthole: still cache, capture admission, deadlines and occlusion. The cockpit fell 2–4 days behind, and the art drifted. An early test showed the live 3D porthole holding hundreds of MB. Destroying one shared WKWebView would also destroy the instruments, and WebKit does not guarantee that memory returns.

## Decision

- **Cockpit.**
  - A native window hosts one WKWebView that runs the cockpit bundle built from the prototype code: instruments, art, HUD and porthole.
  - Data comes over one message channel carrying the app-server payloads.
  - The page pauses when hidden or occluded and is released when the window closes. A prewarmed hidden page keeps open time at 0.3 s or less.
- **Porthole v1.**
  - No runtime 3D.
  - Stills and the ignition and entrance videos come from a reproducible offline render pipeline in the repo.
  - A CI check ensures the default setup always has a confirmed still.
- **Live 3D after v1.**
  - Allowed only behind a budget measured on the lowest supported Mac, which counts app, Go, WebContent and GPU increments, CPU and energy.
  - The page falls back to stills automatically when the budget fails.
- **Animation and native 3D.**
  - Animation uses the prototype's existing stack. Rive is not introduced.
  - The RealityKit entrance comes after v1, and SceneKit is not used.

## Consequences

- Cockpit visual tests run in headless Chrome on Linux CI, with no Mac GUI slot.
- The native instrument views, the field bridge, the still registration machinery and the capture pipeline are deleted once the web cockpit lands.
- The cockpit adds one WebContent process while it is open.
