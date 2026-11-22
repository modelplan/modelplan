// SPDX-License-Identifier: MIT
import CoreGraphics

/// The resource plugin's white line mark (the heartbeat line alone, no square frame: owner 11-21 D371;
/// desktop/cockpit/src/resource-plugin.ts `icon`) from its 16-unit outline, in y-down coordinates. The ring's centre
/// and the card header (macrevb-1096-6) both draw it, so the two never differ.
public enum DockPluginIcon {
    /// The outline paths fitted to the square centred in `rect`; stroke each at `lineWidth(in:)`.
    public static func paths(in rect: CGRect) -> [CGPath] {
        let side = min(rect.width, rect.height), s = side / 16
        guard side.isFinite, side > 0 else { return [] }
        let o = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        let line = CGMutablePath()
        line.addLines(between: [p(1, 8.5), p(4.5, 8.5), p(6.3, 3.5), p(9.5, 12.5), p(11.3, 8.5), p(15, 8.5)])
        return [line]
    }
    public static func lineWidth(in rect: CGRect) -> CGFloat { 1.5 * min(rect.width, rect.height) / 16 }
}
