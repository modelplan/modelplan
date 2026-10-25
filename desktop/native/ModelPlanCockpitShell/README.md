# Cockpit shell state preparation

Generic MIT model code for the native cockpit shell. This is a nonvisual preparation change: it adds no windows, controls, assets, HUD, field renderer or app wiring. The full shell and strip appearance batches remain subject to their design and native input gates.

`CockpitLayout` selects the 890/640/collapsed tiers using an already resolved native usable frame. It reserves a fixed 6 pt gap below its top boundary and a separate exhaust region, tries the collapsed profile before uniformly shrinking it, includes silhouette overhang in containment, and exposes inverse screen/root coordinate conversions. Root coordinates start at the **visible** body top, with Y down; global AppKit points have Y up. Physical backing density does not affect this point-space calculation. The caller resolves display identity, safe areas, menu/Dock exclusions and the unobscured anchor region once, without subtracting those exclusions again here. No usable area, invalid input, or a width-only failure while open returns `nil`. Width-only failure does not invent a new closure policy; a closed cockpit's final uniform transform fits both height and width.

`CockpitMetrics` requires the caller to supply content/silhouette widths and the closed heights for both full and compact profiles. These are intentionally not built-in official geometry. Test values are injected examples, not approval of a design reference. The visible body and exhaust must be represented completely by these dimensions. A future presentation provider must translate transparent asset/window padding to this visible-body coordinate system; anchoring an arbitrary window frame is insufficient. All painted geometry, controls, accessibility frames and drag coordinates must use the same fit transform.

`CockpitWindowState` stores the user's window-switch preference separately from forced closure. The switch is disabled while forced closed, and attempts to change it leave the preference intact. Restoring a larger usable area reuses the saved preference.

`CautionLampModel` reuses `ModelPlanPrimitives.CautionState`, adapting its elapsed seconds to `ContinuousClock.Instant` and `Duration`. Supply only existing amber/red conditions with stable semantic episode IDs; informational notices and formatted text do not belong in this input. Updates, press, presentation and Reduce Motion changes are synchronous value-state operations. Nothing schedules a repeating timer or creates an animation. The host should retain one model for the app lifecycle, serialize its mutations (normally on the main actor), and:

- Update conditions without recreating the model on cockpit open, refresh or locale change.
- Read `presentation(now:)` before restoring a frame and on wake, menu/tracking exit and deadline delivery. A stale deadline callback can only validate the current state.
- Schedule one common-mode deadline validation and use the absolute deadline to bound any opacity animation. `blinkStartedAt` and the 1 s period preserve phase across hide/show. Cancel the animation when the mode stops blinking and retain steady model opacity. No animation source is part of this target.
- Route `.openAlerts` through the existing sourced navigation/return path. A press while off returns no action; returning from an already-open alerts view is the navigation owner's responsibility.

Expiry yields `steadyUnacknowledged`; it does not acknowledge. New semantic episodes and worsening severity get a fresh bounded interval. Clear removes latches; Reduce Motion immediately presents a steady light. Colors, lens artwork and localized accessibility strings belong to the presentation layer.

## Semantic caution input (P03)

`update(notices:now:)` accepts `CautionNotice` values. `CautionEpisodeID` binds subscription, optional window, event kind and episode identity, excluding localized text, countdowns and readings. Length framing prevents delimiter collisions; canonical Unicode reconstruction preserves the same identity. Empty or oversized identity components are rejected. Information/blue notices never become primitive caution conditions.

This overload only maps into the existing `CautionLampModel.update` / `ModelPlanPrimitives.CautionState`; it does not add a controller or another transition implementation. Tests cover the specified 0/3/6/16/20/24-second sequence, information exclusion, same-severity new episodes, both severity levels with Reduce Motion/acknowledgement, reconstruction, and elapsed recovery after sleep. The existing condition-based API remains valid.

## Local verification

M0 has registered this target in the native root package. Use that root entry point: the historical lane-local manifest depends on the parent and now collides with its same-named target. No manifest change is needed for P03. No private checkout or external package is required. Run from the public worktree, after checking disk space:

```sh
df -h ~
du -sh ~/mp/build/M2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test \
  --package-path desktop/native --filter ModelPlanCockpitShellTests \
  --scratch-path ~/mp/build/M2 --jobs 2
node scripts/check-source-policy.mjs
git diff --check
```

Tests exercise tier thresholds, visible-top anchoring, complete fit/reserve containment, negative/above display origins, scaled input conversion, switch restoration, and caution acknowledgement/new/worse/clear/timeout/Reduce Motion/delayed validation. They do not prove physical input, pixels, macOS 14 runtime behavior, animation CPU or app memory acceptance.

## Assembly boundary

The shared `desktop/native/Package.swift`, `ModelPlanCore`, `ModelPlanShell` and `ModelPlanPrimitives` are unchanged. The existing M0-owned root registration already points to these sources/tests:

```swift
// products
.library(name: "ModelPlanCockpitShell", targets: ["ModelPlanCockpitShell"]),
// targets
.target(name: "ModelPlanCockpitShell", dependencies: ["ModelPlanPrimitives"],
        path: "ModelPlanCockpitShell/Sources/ModelPlanCockpitShell"),
.testTarget(name: "ModelPlanCockpitShellTests", dependencies: ["ModelPlanCockpitShell"],
            path: "ModelPlanCockpitShell/Tests/ModelPlanCockpitShellTests"),
```

M0 also supplies the frozen closed-profile dimensions and native usable-frame/anchor contract when wiring the presentation. This preparation does not resolve pending appearance geometry or claim full shell/strip acceptance. No shared-state-machine change is currently requested.

The separate `ModelPlanSelection` package is the P03 shared ordered-ID seam. Its README lists the new registration/adapter request; this shell target remains on its existing registration.
