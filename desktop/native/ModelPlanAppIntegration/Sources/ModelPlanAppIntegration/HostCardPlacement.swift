// SPDX-License-Identifier: MIT
import CoreGraphics
import ModelPlanDock
import ModelPlanOfficialDock

/// Calculates both candidates from the actual visible station ring, then lets
/// the shared geometry choose a non-overlapping, in-bounds placement.
enum HostCardPlacement {
    /// `ring` is the painted clock ring and `hull` the face's bounds, both screen rectangles (y up);
    /// `unit` is D/52. Like the prototype, the card keeps 12 x unit from the ring, and the face may
    /// push it out so it never comes closer than a 2 x unit seam past the face's inner side.
    /// Prototype: opus-r7/src/rocket-r1/card.js:173-201 (place: gap, boundary, seam).
    static func place(ring: CGRect?, hull: CGRect?, unit: CGFloat, size: CGSize, available: CGRect, edge: DockEdge) -> CGRect? {
        guard let ring, unit.isFinite, unit > 0, let spacing = QuotaWidgetCardGeometry.anchorSpacing(nozzleDiameter: 52 * unit),
              size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
        let seam = 2 * unit, face = hull.flatMap { $0.isNull || $0.isEmpty ? nil : $0 }
        let left = min(ring.minX, face.map { $0.minX + spacing - seam } ?? .infinity)
        let right = max(ring.maxX, face.map { $0.maxX - spacing + seam } ?? -.infinity)
        let below = min(ring.minY, face.map { $0.minY + spacing - seam } ?? .infinity)
        let above = max(ring.maxY, face.map { $0.maxY - spacing + seam } ?? -.infinity)
        let preferred: CGRect, flipped: CGRect
        switch edge {
        case .left:
            preferred = CGRect(x: right + spacing, y: ring.midY - size.height / 2, width: size.width, height: size.height)
            flipped = CGRect(x: ring.minX - spacing - size.width, y: preferred.minY, width: size.width, height: size.height)
        case .right:
            preferred = CGRect(x: left - spacing - size.width, y: ring.midY - size.height / 2, width: size.width, height: size.height)
            flipped = CGRect(x: ring.maxX + spacing, y: preferred.minY, width: size.width, height: size.height)
        case .bottom:
            preferred = CGRect(x: ring.midX - size.width / 2, y: above + spacing, width: size.width, height: size.height)
            flipped = CGRect(x: preferred.minX, y: ring.minY - spacing - size.height, width: size.width, height: size.height)
        case .top:
            // Below the menu bar the card unfolds downwards, mirroring the bottom edge.
            preferred = CGRect(x: ring.midX - size.width / 2, y: below - spacing - size.height, width: size.width, height: size.height)
            flipped = CGRect(x: preferred.minX, y: ring.maxY + spacing, width: size.width, height: size.height)
        }
        return QuotaWidgetCardGeometry.place(anchorRing: ring, preferred: preferred,
                                               flipped: flipped, available: available)?.plate
    }
}
