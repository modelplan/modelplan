// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanDock
import ModelPlanOfficialDock

/// The card's pointer arrow toward its ring (G3-05 / R64 D-3).
/// Prototype: design-handoffs/opus-r7/src/rocket-r1/card.js:226-247 (tip stops 2 pt before the ring,
/// 16 pt wide, 1 pt overlap hides the plate seam) and clients/official-visuals/dock-aftview-integration/
/// face.css:84-99 (fill = plate, 1 pt seam stroke, round joins).
enum HostCardPointer {
    enum Side: Equatable { case left, right, up, down }
    struct Layout: Equatable {
        /// The panel frame (plate plus arrow), the plate inside it and the arrow polygon, all in screen coordinates.
        let panel: CGRect, plate: CGRect, arrow: [CGPoint], side: Side
    }
    /// `plate` and `ring` are screen rectangles (y up). Returns nil when the plate touches or covers
    /// the ring (no room for an arrow): the plate is then shown alone.
    static func layout(plate: CGRect, ring: CGRect) -> Layout? {
        let transverse = QuotaWidgetCardGeometry.arrowTransverseSize, beyond = QuotaWidgetCardGeometry.arrowTipBeyondRing
        let overlap = QuotaWidgetCardGeometry.arrowPlateOverlap
        let side: Side, length: CGFloat
        if plate.maxX <= ring.minX { side = .right; length = ring.minX - plate.maxX - beyond }
        else if plate.minX >= ring.maxX { side = .left; length = plate.minX - ring.maxX - beyond }
        else if plate.maxY <= ring.minY { side = .up; length = ring.minY - plate.maxY - beyond }
        else if plate.minY >= ring.maxY { side = .down; length = plate.minY - ring.maxY - beyond }
        else { return nil }
        guard length > 0, plate.width >= 2 * transverse, plate.height >= 2 * transverse else { return nil }
        let tip = length + overlap, half = transverse / 2
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat { max(low, min(high, value)) }
        let arrow: [CGPoint], box: CGRect
        switch side {
        case .right, .left:
            let centre = clamp(ring.midY, plate.minY + transverse, plate.maxY - transverse)
            let baseX = side == .right ? plate.maxX - overlap : plate.minX + overlap
            let tipX = side == .right ? baseX + tip : baseX - tip
            arrow = [CGPoint(x: baseX, y: centre + half), CGPoint(x: tipX, y: centre), CGPoint(x: baseX, y: centre - half)]
            box = CGRect(x: min(baseX, tipX), y: centre - half, width: tip, height: transverse)
        case .up, .down:
            let centre = clamp(ring.midX, plate.minX + transverse, plate.maxX - transverse)
            let baseY = side == .up ? plate.maxY - overlap : plate.minY + overlap
            let tipY = side == .up ? baseY + tip : baseY - tip
            arrow = [CGPoint(x: centre - half, y: baseY), CGPoint(x: centre, y: tipY), CGPoint(x: centre + half, y: baseY)]
            box = CGRect(x: centre - half, y: min(baseY, tipY), width: transverse, height: tip)
        }
        return Layout(panel: plate.union(box).integral, plate: plate, arrow: arrow, side: side)
    }
}

/// The pointer arrow, a sibling above the card so its 1 pt overlap hides the plate seam at the base.
@MainActor final class HostCardArrowView: NSView {
    private(set) var points: [CGPoint] = []
    private var fill: NSColor = .windowBackgroundColor, seam: NSColor?
    override var isFlipped: Bool { false }
    /// `points` are in this view's coordinates.
    func setArrow(_ points: [CGPoint], fill: NSColor, seam: NSColor?) {
        self.points = points; self.fill = fill; self.seam = seam; needsDisplay = true
    }
    private var path: NSBezierPath? {
        guard points.count == 3 else { return nil }
        let path = NSBezierPath(); path.move(to: points[0]); path.line(to: points[1]); path.line(to: points[2]); path.close()
        return path
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); bounds.fill(using: .copy)
        guard let path else { return }
        fill.setFill(); path.fill()
        if let seam {
            // Stroke only the two outer edges; the base lies on the plate.
            let edge = NSBezierPath()
            edge.move(to: points[0]); edge.line(to: points[1]); edge.line(to: points[2])
            edge.lineWidth = 1; edge.lineJoinStyle = .round
            seam.setStroke(); edge.stroke()
        }
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let path, path.contains(convert(point, from: superview)) else { return nil }
        return self
    }
}
