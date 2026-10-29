# The cockpit runs the prototype web code; the v1 porthole is prerendered

Status: accepted by the owner on 2026-10-29.

## Context

The cockpit was being redrawn in AppKit and Core Animation from a web prototype, with a separate native↔web bridge for the three.js porthole: still cache, capture admission, deadlines and occlusion. The cockpit fell 2–4 days behind, and the art drifted. An early test showed the live 3D porthole holding hundreds of MB. Destroying one shared WKWebView would also destroy the instruments, and WebKit does not guarantee that memory returns.

## Decision

- **Cockpit.**
  - A native window hosts one WKWebView that runs the cockpit bundle built from the prototype code: instruments, art, HUD and porthole.
  - Data comes over a narrow, typed `CockpitBridge`.
    - Allowed: display DTOs (rows, Go-computed cockpit and history data, publication summary), a `clear` message carrying a new consent generation, and a fixed set of user actions.
    - Refused: credentials, consent mutation, plugin install, arbitrary commands, files or URLs, and non-main frames.
    - Messages carry a generation, a request id and a size limit, under navigation limits and a CSP.
  - The page pauses when hidden or occluded and is released when the window closes. There is no hidden prewarmed page by default; open times and memory after close are measured first.
- **Porthole v1.**
  - No runtime 3D.
  - Stills and the ignition and entrance videos come from a reproducible offline render pipeline. The pipeline and the scene sources stay in the private repo (ADR 0049).
  - The pipeline publishes a public runtime asset pack with a manifest of input ids, versions and hashes, which public CI verifies.
  - A CI check ensures the default setup always has a confirmed still.
- **Live 3D after v1.**
  - Allowed only behind a budget measured on the lowest supported Mac, which counts app, Go, WebContent and GPU increments, CPU and energy.
  - The page falls back to stills automatically when the budget fails.
- **Animation and native 3D.**
  - Animation uses the prototype's existing stack. Rive is not introduced.
  - The RealityKit entrance comes after v1, and SceneKit is not used.

## Consequences

- Headless Chrome on Linux CI is the fast screen for cockpit visuals, with no Mac GUI slot. The final visual proof is the real WKWebView in the final package on macOS, against owner-confirmed baselines.
- The native instrument views, the field bridge, the still registration machinery and the capture pipeline are deleted in the wave that completes the web cockpit, after its WKWebView and package proof pass. Their regression scenarios stay.
- The cockpit adds one WebContent process while it is open.
