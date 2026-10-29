# The native shell ports Pulse's placement code and owns its state

Status: accepted by the owner on 2026-10-29.

## Context

We decided on 2026-10-23 to reuse Pulse's edge-docking, auto-hide and hover logic (qunqin24/Pulse, Apache-2.0), but none of it was reused. Our hand-written shell repeated bugs Pulse had already solved: the default edge, the sliver, drag and multi-display.

An evaluation of Pulse v1.12.4 found:

- **Strengths:** about 2,100 tests, but only for geometry; edge, drag-dock and ratio + display-UUID persistence; display following; notch handling.
- **Coupling:** hover and hide state is held in a SwiftUI view that also calls provider code, and layout reads global metrics.
- **Maintenance:** a single maintainer and frequent churn.
- **Platform risk:** it needs the macOS 26 SDK and uses one private API.

## Decision

- Do not fork Pulse.
- Port these, from a pinned commit, file by file:
  - `PanelScreen`, `ActiveDisplayFollower`, `PanelPointerWatcher` and `PointerEntryReporter`;
  - the `PanelPlacement` model, re-parameterised for our sizes;
  - the `FloatingPanel` event and ordering techniques;
  - `LoginItem`, without default-on;
  - their geometry tests and design notes.
- Keep the Apache-2.0 licence headers. If upstream ships a NOTICE file, carry its content, as the licence requires.
- Put hover, reveal, collapse and drag state in one AppKit controller that we own, tested with synthetic real input.
- Do not take providers, settings, the private appearance selector, `BotMark`, `DropletTether` or the update stack.
- Record every borrowed module in `docs/borrowed/pulse.md`.

## Consequences

- Placement defaults and persistence follow a model already tested elsewhere. The preference file adds a `schemaVersion` and migration tests.
- Upstream fixes do not flow in automatically. Each one needs a manual review.
- The real-input tests cover what Pulse leaves to manual clicking.
