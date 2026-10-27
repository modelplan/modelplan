// SPDX-License-Identifier: MIT
import Foundation

/// Cyclic interpolation of an immutable, already-counted image sequence. No image production or timer.
public struct DockTemporalSample: Equatable, Sendable {
    public let lower: Int, upper: Int
    public let fraction: Double
    public static func at(seconds: Double, count: Int, period: Double = 1) -> Self? {
        guard seconds.isFinite, period.isFinite, period > 0, (2...32).contains(count) else { return nil }
        let phase = max(0, seconds).truncatingRemainder(dividingBy: period) / period
        let position = phase * Double(count), lower = min(count - 1, Int(position))
        return .init(lower: lower, upper: (lower + 1) % count, fraction: position - Double(lower))
    }
}
