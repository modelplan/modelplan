// SPDX-License-Identifier: MIT
import CoreGraphics

/// Finds an actual registered hit inside visible geometry; never invents an
/// anchor from the panel frame when no safe point is present.
@MainActor enum DockHelpAnchorSearch {
    static func find(paths: [CGPath], visible: CGRect, contains: (CGPoint) -> Bool) -> CGRect? {
        guard !visible.isNull, !visible.isInfinite, visible.width > 0, visible.height > 0 else { return nil }
        for path in paths {
            let bounds = path.boundingBoxOfPath
            guard !bounds.isNull, !bounds.isInfinite, bounds.width.isFinite, bounds.height.isFinite,
                  bounds.width > 0, bounds.height > 0 else { continue }
            for row in 0..<8 {
                for column in 0..<8 {
                    let point = CGPoint(x: bounds.minX + bounds.width * (CGFloat(column) + 0.5) / 8,
                                        y: bounds.minY + bounds.height * (CGFloat(row) + 0.5) / 8)
                    let anchor = CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)
                    if visible.contains(anchor), contains(point) { return anchor }
                }
            }
        }
        return nil
    }
}
