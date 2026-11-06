// Copyright (c) 2026 qunqin24. Licensed under the Apache License, Version 2.0.
// ModelPlan adaptation: carry the panel and port the pulled-off edge hold from
// FloatingPanelController. Use the destination visible frame, omit liquid
// drawing and animation, and leave saving to the single release transaction.
import Foundation
import CoreGraphics

struct PulsePanelDrag {
    private let press: CGPoint
    private let grab: CGPoint
    private let alwaysAttached: Bool
    private let snapDistance: CGFloat
    private let breakDistance: CGFloat
    private var heldDisplay: String?
    private var heldEdge: DockEdge?
    private(set) var moved = false

    init(press: CGPoint, placement: DockEdgePlacement, defaults: UserDefaults = .standard) {
        self.press = press
        grab = CGPoint(x: (press.x - placement.frame.minX) / placement.frame.width,
                       y: (press.y - placement.frame.minY) / placement.frame.height)
        alwaysAttached = defaults.integer(forKey: "ModelPlanDockDragMode") == 2
        func threshold(_ key: String, fallback: CGFloat) -> CGFloat {
            let value = defaults.double(forKey: key)
            return value.isFinite && (1...1000).contains(value) ? value : fallback
        }
        snapDistance = threshold("ModelPlanDockSnapDistance", fallback: 96)
        breakDistance = max(snapDistance, threshold("ModelPlanDockBreakDistance", fallback: 120))
        heldDisplay = placement.displayID
        heldEdge = placement.edge
    }

    mutating func beginMovement(at pointer: CGPoint) -> Bool {
        guard pointer.x.isFinite, pointer.y.isFinite else { return false }
        if hypot(pointer.x - press.x, pointer.y - press.y) > 5 { moved = true }
        return moved
    }

    static func display(at pointer: CGPoint, in displays: [DockDisplayArea]) -> DockDisplayArea? {
        guard pointer.x.isFinite, pointer.y.isFinite else { return nil }
        return displays.first { $0.frame.contains(pointer) }
    }

    private static func distance(from edge: DockEdge, pointer: CGPoint, visible: CGRect) -> CGFloat {
        switch edge {
        case .left: return abs(pointer.x - visible.minX)
        case .right: return abs(pointer.x - visible.maxX)
        case .bottom: return abs(pointer.y - visible.minY)
        case .top: return .infinity
        }
    }

    private static func nearest(to pointer: CGPoint, visible: CGRect) -> DockEdge {
        [DockEdge.right, .left, .bottom].min {
            distance(from: $0, pointer: pointer, visible: visible) < distance(from: $1, pointer: pointer, visible: visible)
        } ?? .right
    }

    static func nearestPlacement(pointer: CGPoint, display: DockDisplayArea) -> DockEdgePreference {
        let room = display.usableFrame
        let edge = nearest(to: pointer, visible: room)
        let fraction = edge == .bottom ? (pointer.x - room.minX) / room.width : (pointer.y - room.minY) / room.height
        return .init(displayID: display.id, edge: edge, alongFraction: Double(max(0, min(1, fraction))))
    }

    private func preference(display: DockDisplayArea, edge: DockEdge, pointer: CGPoint,
                            layout: DockEdgeLayout?, useGrab: Bool) -> DockEdgePreference {
        let room = display.usableFrame
        let vertical = edge != .bottom
        let length = vertical ? room.height : room.width
        var along = vertical ? pointer.y - room.minY : pointer.x - room.minX
        if useGrab, let layout {
            let offset = vertical ? grab.y * layout.expandedSize.height : grab.x * layout.expandedSize.width
            along += layout.alongAnchor - offset
        }
        return .init(displayID: display.id, edge: edge, alongFraction: Double(max(0, min(1, along / length))))
    }

    /// The edge the carried panel shows at `pointer`, and whether it is attached.
    /// Carry and release share this decision so a release commits the edge the
    /// user saw: a held rail wins at a corner even when another edge is nearer.
    private func attachment(pointer: CGPoint, display: DockDisplayArea, layouts: [DockEdgeLayout])
        -> (edge: DockEdge, attached: Bool) {
        let visible = display.usableFrame
        let nearest = Self.nearest(to: pointer, visible: visible)
        let snaps = Self.distance(from: nearest, pointer: pointer, visible: visible) <= snapDistance
        // The held rail takes precedence over another edge entering snap range at a corner.
        if !alwaysAttached, heldDisplay == display.id, let heldEdge,
           let layout = layouts.first(where: { $0.displayID == display.id && $0.edge == heldEdge }) {
            let origin = CGPoint(x: pointer.x - grab.x * layout.expandedSize.width,
                                 y: pointer.y - grab.y * layout.expandedSize.height)
            let rail = CGPoint(x: heldEdge == .right ? origin.x + layout.expandedSize.width : origin.x, y: origin.y)
            if Self.distance(from: heldEdge, pointer: rail, visible: visible) < breakDistance {
                return (heldEdge, true)
            }
        }
        return (nearest, alwaysAttached || snaps)
    }

    mutating func carry(pointer: CGPoint, display: DockDisplayArea, layouts: [DockEdgeLayout])
        -> (DockEdgePreference, attached: Bool) {
        let (edge, attached) = attachment(pointer: pointer, display: display, layouts: layouts)
        heldDisplay = attached ? display.id : nil
        heldEdge = attached ? edge : nil
        let layout = layouts.first { $0.displayID == display.id && $0.edge == edge }
        return (preference(display: display, edge: edge, pointer: pointer, layout: layout, useGrab: !alwaysAttached), attached)
    }

    /// Commits the edge the carry shows at the release point (the held rail
    /// while attached), and the nearest edge only for a floating release.
    func release(pointer: CGPoint, display: DockDisplayArea, layouts: [DockEdgeLayout]) -> DockEdgePreference {
        let edge = attachment(pointer: pointer, display: display, layouts: layouts).edge
        let layout = layouts.first { $0.displayID == display.id && $0.edge == edge }
        return preference(display: display, edge: edge, pointer: pointer, layout: layout, useGrab: !alwaysAttached)
    }

    func floatingFrame(pointer: CGPoint, size: CGSize, visible: CGRect) -> CGRect {
        let x = min(max(pointer.x - grab.x * size.width, visible.minX), visible.maxX - size.width)
        let y = min(max(pointer.y - grab.y * size.height, visible.minY), visible.maxY - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
