// SPDX-License-Identifier: MIT
import CoreGraphics
import ModelPlanDock
import ModelPlanOfficialDock

/// Calculates both candidates from the actual visible station ring, then lets
/// the shared geometry choose a non-overlapping, in-bounds placement.
enum HostCardPlacement {
    static func place(anchor: CGRect?, size: CGSize, available: CGRect, edge: DockEdge) -> CGRect? {
        guard let anchor, let spacing = QuotaWidgetCardGeometry.anchorSpacing(nozzleDiameter: anchor.width),
              size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
        let preferred: CGRect, flipped: CGRect
        switch edge {
        case .left:
            preferred = CGRect(x: anchor.maxX + spacing, y: anchor.midY - size.height / 2, width: size.width, height: size.height)
            flipped = CGRect(x: anchor.minX - spacing - size.width, y: preferred.minY, width: size.width, height: size.height)
        case .right:
            preferred = CGRect(x: anchor.minX - spacing - size.width, y: anchor.midY - size.height / 2, width: size.width, height: size.height)
            flipped = CGRect(x: anchor.maxX + spacing, y: preferred.minY, width: size.width, height: size.height)
        case .bottom:
            preferred = CGRect(x: anchor.midX - size.width / 2, y: anchor.maxY + spacing, width: size.width, height: size.height)
            flipped = CGRect(x: preferred.minX, y: anchor.minY - spacing - size.height, width: size.width, height: size.height)
        case .top:
            // Quota Widget permits left, right and bottom only.
            return nil
        }
        return QuotaWidgetCardGeometry.place(anchorRing: anchor, preferred: preferred,
                                               flipped: flipped, available: available)?.plate
    }
}
