// Copyright (c) 2026 qunqin24. Licensed under the Apache License, Version 2.0.
// ModelPlan adaptation: AppKit tracking view consumed by the normal host; unused SwiftUI wrapper removed.
import AppKit

/// Reports when the pointer enters the view it is attached to.
///
/// SwiftUI's own `.onHover` installs a tracking area scoped to the active
/// application. Pulse runs as an `.accessory` app behind a non-activating
/// panel that can never become key (see `FloatingPanelController`), so it is
/// essentially never the active app and `.onHover` would stay silent. This
/// uses an `.activeAlways` tracking area instead, which reports regardless of
/// which app is frontmost.
///
/// Only entering is reported, deliberately. Exit events are not trustworthy
/// here: views appearing, disappearing, or animating under a stationary
/// pointer — the details card opening, for instance — fire spurious exits,
/// and acting on one closes the card, which puts the pointer back on a ring,
/// which opens it again, an endless loop. Whether the pointer has really left
/// is answered by `PanelPointerWatcher` instead, which samples its actual
/// position rather than trusting enter/exit events.
///
/// The AppKit composition mounts this behind the active panel content and
/// sizes it to that content, without adding a click-catching view.
enum PointerEntryReporter {
    final class TrackingView: NSView {
        var onEnter: (() -> Void)?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            // `.inVisibleRect` keeps the area sized to the view on its own, so
            // it is installed once and left alone. Tearing it down and adding
            // it back on every layout pass is itself a source of phantom
            // enter/exit events.
            guard trackingAreas.isEmpty else { return }

            addTrackingArea(
                NSTrackingArea(
                    rect: .zero,
                    options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                    owner: self
                )
            )
        }

        override func mouseEntered(with event: NSEvent) {
            onEnter?()
        }
    }
}
