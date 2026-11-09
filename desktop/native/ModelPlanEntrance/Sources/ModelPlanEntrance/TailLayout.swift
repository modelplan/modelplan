// SPDX-License-Identifier: MIT
// CKP-ENT-05: one tail cylinder per visible dock subscription, in dock order (owner 2026-10-25).
// centre / pair / triangle / square for 1-4, one ring for 5-6, ring plus centre for 7+.
// Model metres on the tail plate (x right, z toward the canopy side). Port of the reference `tail-layout.js`.
import Foundation

public struct TailSlot: Equatable, Sendable, Codable {
    public let id: String
    public let index: Int
    public let x: Double
    public let z: Double
    /// Clock angle of the slot around the rocket axis (radians); 0 for a centre slot.
    public let angle: Double
    public let centre: Bool
    /// Cylinder radius in metres.
    public let radius: Double
}

public enum TailLayout {
    /// Radius of the tail plate the cylinders sit in.
    public static let plateRadius = 1.17
    /// Height of the tail plate above the model base.
    public static let plateY = 0.24

    /// - Parameters:
    ///   - ids: visible dock subscription IDs in dock order; empty and overflow (+N) slots must not be passed.
    ///   - maxVisible: cap from the dock's visible list.
    public static func slots(for ids: [String], maxVisible: Int? = nil) -> [TailSlot] {
        let shown = Array(ids.prefix(max(0, maxVisible ?? ids.count)))
        let n = shown.count
        guard n > 0 else { return [] }
        let radius: Double
        switch n {
        case 1: radius = 0.35
        case 2: radius = 0.31
        case 3: radius = 0.285
        case 4: radius = 0.265
        case 5, 6: radius = 0.22
        default: radius = min(0.19, 0.78 * sin(Double.pi / Double(n - 1)) * 0.75)
        }
        return shown.enumerated().map { i, id in
            if n == 1 { return TailSlot(id: id, index: i, x: 0, z: 0, angle: 0, centre: true, radius: radius) }
            if n == 2 {
                return TailSlot(id: id, index: i, x: i == 1 ? 0.52 : -0.52, z: 0,
                                angle: i == 1 ? Double.pi / 2 : -Double.pi / 2, centre: false, radius: radius)
            }
            if n >= 7 && i == n - 1 { return TailSlot(id: id, index: i, x: 0, z: 0, angle: 0, centre: true, radius: radius) }
            let ringCount = n >= 7 ? n - 1 : n
            let angle = (n == 4 ? Double.pi / 4 : 0) + Double(i) * Double.pi * 2 / Double(ringCount)
            let r = n == 3 ? 0.70 : n == 4 ? 0.74 : 0.78
            return TailSlot(id: id, index: i, x: sin(angle) * r, z: cos(angle) * r, angle: angle, centre: false, radius: radius)
        }
    }
}
