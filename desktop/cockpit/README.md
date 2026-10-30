<!-- SPDX-License-Identifier: MIT -->
# Cockpit web bundle (U11 interface only)

This standalone web surface will consume the typed `cockpit/query` display DTO
(`WireCockpitData`) through a narrow `CockpitBridge`. The native WKWebView window
and production bridge registration are a separate integration step.

Implementation scope:

- A bounded, versioned message contract with request IDs and consent context;
  reject unknown/malformed messages, other origins and non-main frames.
- Load, ready, hidden/occluded/non-key, clear and unload lifecycle; clear private
  DOM and retained values before admitting a new consent context.
- Decorative motion capped at 30 fps, with no requestAnimationFrame loop while
  hidden, occluded, non-key or unloaded, and no idle timers.
- Existing public A5, c01 and OFL assets only; no U12 porthole media or live 3D.
- Bridge/clear regressions, actual headless WebKit callback counts and visual
  regression baselines. Baselines are implementation evidence, not owner visual
  approval or WKWebView performance acceptance.

The test-Mac App + WebContent CPU target is at most 6% of one core in the U11a
scenario. Headless tests cannot certify that target, GPU attribution or memory
return after closing a native window. Those measurements remain required before
this draft can be made ready.
