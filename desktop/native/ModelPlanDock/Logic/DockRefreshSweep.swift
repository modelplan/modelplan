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

    /// G3-98: the number never counts along with the ring. It fades out, stays hidden, then fades in
    /// showing the admitted value. Alpha only; the text is never an intermediate value.
    public static let readoutFadeOut: TimeInterval = 0.15
    public static let readoutFadeIn: TimeInterval = 0.15
    public static func readoutAlpha(elapsed: TimeInterval, reduceMotion: Bool) -> Double {
        guard !reduceMotion, elapsed.isFinite, elapsed >= 0 else { return 1 }
        if elapsed < readoutFadeOut { return 1 - elapsed / readoutFadeOut }
        let inStart = duration - readoutFadeIn
        if elapsed < inStart { return 0 }
        return min(1, (elapsed - inStart) / readoutFadeIn)
    }
}
