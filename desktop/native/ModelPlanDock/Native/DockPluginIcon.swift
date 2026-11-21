// SPDX-License-Identifier: MIT
import CoreGraphics

/// The resource plugin's white line mark (a rounded screen with a heartbeat line, desktop/cockpit/src/resource-plugin.ts
/// `icon`) from its 16-unit outline, in y-down coordinates. The ring's centre and the card header (macrevb-1096-6) both
/// draw it, so the two never differ.
public enum DockPluginIcon {
    /// The outline paths fitted to the square centred in `rect`; stroke each at `lineWidth(in:)`.
    public static func paths(in rect: CGRect) -> [CGPath] {
        let side = min(rect.width, rect.height), s = side / 16
        guard side.isFinite, side > 0 else { return [] }
        let o = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        let screen = CGPath(roundedRect: CGRect(origin: p(1, 1.5), size: CGSize(width: 14 * s, height: 13 * s)),
                            cornerWidth: 3 * s, cornerHeight: 3 * s, transform: nil)
        let line = CGMutablePath()
        line.addLines(between: [p(3.5, 8.5), p(5.5, 8.5), p(6.8, 5.5), p(8.8, 10.5), p(10, 8.5), p(12.5, 8.5)])
        return [screen, line]
    }
    public static func lineWidth(in rect: CGRect) -> CGFloat { 1.3 * min(rect.width, rect.height) / 16 }
}
