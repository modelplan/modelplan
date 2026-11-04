// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import Foundation

/// Deterministic, non-stitched SVG fractal noise for the accepted T2 material.
/// Algorithm definition: https://www.w3.org/TR/SVG11/filters.html#feTurbulenceElement
/// The renderer samples in study user coordinates, independently of backing density.
public struct T2Grain: Sendable {
    private let permutation: [Int]
    private let vectors: [[[Double]]]
    public static let seed = 23
    public static let frequencyX = 0.91
    public static let frequencyY = 0.73
    public static let octaves = 3
    public static let opacity = 0.018

    public init() {
        var state: Int64 = 23
        func next() -> Int {
            state = (state * 16807) % 2147483647
            return Int(state)
        }
        // SVG assigns gradients for four channels before shuffling the lattice.
        var channels = [[[Double]]]()
        for _ in 0..<4 {
            var channel = [[Double]]()
            for _ in 0..<256 {
                let x = Double(next() % 512 - 256) / 256
                let y = Double(next() % 512 - 256) / 256
                let length = hypot(x, y)
                channel.append([x / length, y / length])
            }
            channels.append(channel)
        }
        var table = Array(0..<256)
        for i in stride(from: 255, through: 1, by: -1) {
            table.swapAt(i, next() % 256)
        }
        for i in 0..<258 {
            table.append(table[i])
            for c in 0..<4 { channels[c].append(channels[c][i]) }
        }
        permutation = table; vectors = channels
    }

    private func noise(channel: Int, x: Double, y: Double) -> Double {
        let xx = x + 4096, yy = y + 4096
        let ix = Int(xx), iy = Int(yy)
        let dx = xx - Double(ix), dy = yy - Double(iy)
        let x0 = permutation[ix & 255], x1 = permutation[(ix + 1) & 255]
        func dot(_ latticeX: Int, _ latticeY: Int, _ u: Double, _ v: Double) -> Double {
            let gradient = vectors[channel][permutation[latticeX + (latticeY & 255)]]
            return u * gradient[0] + v * gradient[1]
        }
        let sx = dx * dx * (3 - 2 * dx), sy = dy * dy * (3 - 2 * dy)
        let a = dot(x0, iy, dx, dy), b = dot(x1, iy, dx - 1, dy)
        let c = dot(x0, iy + 1, dx, dy - 1), d = dot(x1, iy + 1, dx - 1, dy - 1)
        let top = a + sx * (b - a), bottom = c + sx * (d - c)
        return top + sy * (bottom - top)
    }

    public func channels(x: Double, y: Double) -> [Double] {
        precondition(x.isFinite && y.isFinite && abs(x) <= 1_000_000 && abs(y) <= 1_000_000)
        return (0..<4).map { channel in
            var px = x * Self.frequencyX, py = y * Self.frequencyY
            var sum = 0.0, weight = 1.0
            for _ in 0..<Self.octaves {
                sum += noise(channel: channel, x: px, y: py) * weight
                px *= 2; py *= 2; weight /= 2
            }
            return min(1, max(0, (sum + 1) / 2))
        }
    }
}
