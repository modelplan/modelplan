// SPDX-License-Identifier: MIT
import CoreGraphics

/// Shared width policy for the first-run scroll document.
enum FirstRunLayoutMetrics {
    static let preferredWidth: CGFloat = 570
    static let horizontalInset: CGFloat = 28
    static let minimumWindowWidth: CGFloat = 480
    static let minimumWindowHeight: CGFloat = 360
    static func contentWidth(viewportWidth: CGFloat) -> CGFloat {
        guard viewportWidth.isFinite else { return 0 }
        return max(0, min(preferredWidth, viewportWidth - 2 * horizontalInset))
    }
}
