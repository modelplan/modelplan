// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanDock
import ModelPlanShell

/// One sampled display topology, supplied by the existing Dock environment input.
@MainActor struct DockDisplayTopology {
    let displays: [DockDisplayArea]
    let primaryID: String?

    var main: DockDisplayArea? { display(primaryID) ?? displays.first }

    func display(_ id: String?) -> DockDisplayArea? {
        displays.first { $0.id == id }
    }

    func containing(_ point: CGPoint) -> DockDisplayArea? {
        displays.first { $0.frame.contains(point) }
    }

    static func system() -> Self {
        let displays = NSScreen.screens.enumerated().map { index, screen in
            DockDisplayArea(id: PulseDockPanel.displayIdentifier(for: screen) ?? "session.\(index)",
                frame: screen.frame, visibleFrame: screen.visibleFrame,
                backingScale: min(2, max(1, Int(screen.backingScaleFactor))), name: screen.localizedName)
        }
        return .init(displays: displays, primaryID: displays.first?.id)
    }
}
