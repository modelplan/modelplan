// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanShell
import ModelPlanDock

/// ModelPlan retains exposed-edge/system-Dock policy. Pulse owns the actual
/// window-position calculation; the existing single AppKit controller owns
/// hover/reveal/collapse and the entire press/drag/release transaction.
enum PulseDockPositioning {
    static func resolve(_ request: DockPlacementRequest) throws -> DockEdgePlacement? {
        guard let eligible = try request.resolveEligibleEdge(),
              let display = request.environment.displays.first(where: { $0.id == eligible.displayID }) else { return nil }
        let edge: PulseDockPlacementGeometry.Edge
        switch eligible.edge {
        case .left: edge = .left
        case .right: edge = .right
        case .bottom: edge = .bottom
        case .top: return nil
        }
        guard let frame = PulseDockPlacementGeometry.frame(edge: edge, in: display.usableFrame,
            size: eligible.layout.expandedSize, anchor: eligible.layout.alongAnchor,
            alongFraction: eligible.alongFraction) else { throw DockEdgeError.invalidGeometry }
        let dx = frame.minX - eligible.frame.minX, dy = frame.minY - eligible.frame.minY
        return .init(displayID: eligible.displayID, edge: eligible.edge,
            alongFraction: eligible.alongFraction, frame: frame,
            sliverFrame: eligible.sliverFrame.offsetBy(dx: dx, dy: dy),
            wakeFrame: eligible.wakeFrame.offsetBy(dx: dx, dy: dy), layout: eligible.layout)
    }
}
