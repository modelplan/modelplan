// SPDX-License-Identifier: MIT
import Foundation

/// One-off progress toward an already-admitted value. It never updates the value or its age.
public enum DockRefreshSweep {
    public static let duration: TimeInterval = 0.6
    public static func fraction(elapsed: TimeInterval, target: Double, reduceMotion: Bool) -> Double? {
        guard elapsed.isFinite, elapsed >= 0, target.isFinite, (0...1).contains(target) else { return nil }
        if reduceMotion { return target }
        let t = min(1, elapsed / duration)
        return target * (1 - pow(1 - t, 3))
    }
}
