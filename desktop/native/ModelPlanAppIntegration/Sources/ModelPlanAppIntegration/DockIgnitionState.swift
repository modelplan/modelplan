// SPDX-License-Identifier: MIT
import CoreGraphics
import Foundation

/// D-6: the ignition's pointer states, from the prototype's ignition.css:38-44,86-106. The cap rises
/// 1 pt on hover or focus and sinks 1 pt when pressed, showing the pressed export; the inner contact
/// shadow deepens from .33 to .55 (`extraContact` is the overlay that gets there over the resting .33).
enum DockIgnitionState: Equatable {
    case rest, raised, pressed
    static let transition: TimeInterval = 0.12
    static func resolve(enabled: Bool, hovering: Bool, focused: Bool, pressing: Bool) -> Self {
        guard enabled else { return .rest }
        return pressing ? .pressed : hovering || focused ? .raised : .rest
    }
    var capLift: CGFloat { self == .raised ? 1 : self == .pressed ? -1 : 0 }
    var extraContact: Float { self == .pressed ? 0.33 : 0 }
}
