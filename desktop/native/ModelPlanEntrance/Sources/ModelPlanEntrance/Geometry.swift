// SPDX-License-Identifier: MIT
// Small double-precision vector, quaternion and rect types for the entrance. Foundation only, so the
// whole frame logic builds and is tested on Linux; the RealityKit layer converts to SIMD at its edge.
import Foundation

public struct EntranceVector: Equatable, Sendable, Codable {
    public var x: Double, y: Double, z: Double
    public init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    public static let zero = EntranceVector(0, 0, 0)
    public static func + (a: Self, b: Self) -> Self { .init(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Self, b: Self) -> Self { .init(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static func * (a: Self, s: Double) -> Self { .init(a.x * s, a.y * s, a.z * s) }
    public func dot(_ b: Self) -> Double { x * b.x + y * b.y + z * b.z }
    public func cross(_ b: Self) -> Self { .init(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x) }
    public var length: Double { dot(self).squareRoot() }
    public var normalized: Self { let l = length; return l > 0 ? self * (1 / l) : self }
    public func lerp(to b: Self, _ t: Double) -> Self { self + (b - self) * t }
}

/// Unit quaternion (x, y, z, w), the same convention as simd_quatd and the web reference.
public struct EntranceQuaternion: Equatable, Sendable, Codable {
    public var x: Double, y: Double, z: Double, w: Double
    public init(x: Double, y: Double, z: Double, w: Double) { self.x = x; self.y = y; self.z = z; self.w = w }
    public static let identity = EntranceQuaternion(x: 0, y: 0, z: 0, w: 1)

    /// Rotation whose basis columns are `xAxis`, `yAxis`, `zAxis` (standard trace-based conversion).
    public init(basisX a: EntranceVector, basisY b: EntranceVector, basisZ c: EntranceVector) {
        let m11 = a.x, m12 = b.x, m13 = c.x, m21 = a.y, m22 = b.y, m23 = c.y, m31 = a.z, m32 = b.z, m33 = c.z
        let trace = m11 + m22 + m33
        if trace > 0 {
            let s = 0.5 / (trace + 1).squareRoot()
            self.init(x: (m32 - m23) * s, y: (m13 - m31) * s, z: (m21 - m12) * s, w: 0.25 / s)
        } else if m11 > m22 && m11 > m33 {
            let s = 2 * (1 + m11 - m22 - m33).squareRoot()
            self.init(x: 0.25 * s, y: (m12 + m21) / s, z: (m13 + m31) / s, w: (m32 - m23) / s)
        } else if m22 > m33 {
            let s = 2 * (1 + m22 - m11 - m33).squareRoot()
            self.init(x: (m12 + m21) / s, y: 0.25 * s, z: (m23 + m32) / s, w: (m13 - m31) / s)
        } else {
            let s = 2 * (1 + m33 - m11 - m22).squareRoot()
            self.init(x: (m13 + m31) / s, y: (m23 + m32) / s, z: 0.25 * s, w: (m21 - m12) / s)
        }
    }

    /// Orientation of a camera at `eye` looking at `target` with +Y up (the standard camera look-at:
    /// the camera looks down its local −Z).
    public static func lookAt(eye: EntranceVector, target: EntranceVector, up: EntranceVector = .init(0, 1, 0)) -> Self {
        var z = eye - target
        if z.length == 0 { z = .init(0, 0, 1) }
        z = z.normalized
        var x = up.cross(z)
        if x.length == 0 {
            z = abs(up.z) == 1 ? z + .init(0.0001, 0, 0) : z + .init(0, 0, 0.0001)
            z = z.normalized; x = up.cross(z)
        }
        x = x.normalized
        let y = z.cross(x)
        return .init(basisX: x, basisY: y, basisZ: z)
    }

    public func dot(_ q: Self) -> Double { x * q.x + y * q.y + z * q.z + w * q.w }

    public func rotate(_ v: EntranceVector) -> EntranceVector {
        let u = EntranceVector(x, y, z), t = u.cross(v) * 2
        return v + t * w + u.cross(t)
    }
    public var conjugate: Self { .init(x: -x, y: -y, z: -z, w: w) }

    /// Shortest-path spherical interpolation (standard algorithm).
    public func slerp(to b: Self, _ t: Double) -> Self {
        if t <= 0 { return self }
        if t >= 1 { return b }
        var cosHalf = dot(b), target = b
        if cosHalf < 0 { cosHalf = -cosHalf; target = .init(x: -b.x, y: -b.y, z: -b.z, w: -b.w) }
        if cosHalf >= 1 { return self }
        let sqrSin = 1 - cosHalf * cosHalf
        if sqrSin <= Double.ulpOfOne {
            let s = 1 - t
            let q = EntranceQuaternion(x: s * x + t * target.x, y: s * y + t * target.y, z: s * z + t * target.z, w: s * w + t * target.w)
            let l = q.dot(q).squareRoot()
            return .init(x: q.x / l, y: q.y / l, z: q.z / l, w: q.w / l)
        }
        let sinHalf = sqrSin.squareRoot(), half = atan2(sinHalf, cosHalf)
        let a = sin((1 - t) * half) / sinHalf, c = sin(t * half) / sinHalf
        return .init(x: x * a + target.x * c, y: y * a + target.y * c, z: z * a + target.z * c, w: w * a + target.w * c)
    }

    /// Angle in radians between two orientations.
    public func angle(to b: Self) -> Double { 2 * acos(min(1, abs(dot(b)))) }
}

/// Screen rect in overlay points, top-left origin, y down (the same space as the web reference's CSS pixels).
public struct EntranceRect: Equatable, Sendable, Codable {
    public var left: Double, top: Double, width: Double, height: Double
    public init(left: Double, top: Double, width: Double, height: Double) {
        self.left = left; self.top = top; self.width = width; self.height = height
    }
    public var right: Double { left + width }
    public var bottom: Double { top + height }
    public var centre: EntrancePoint { .init(left + width / 2, top + height / 2) }

    public static func bounds(_ points: [EntrancePoint]) -> EntranceRect {
        guard let first = points.first else { return .init(left: 0, top: 0, width: 0, height: 0) }
        var l = first.x, t = first.y, r = first.x, b = first.y
        for p in points.dropFirst() { l = min(l, p.x); t = min(t, p.y); r = max(r, p.x); b = max(b, p.y) }
        return .init(left: l, top: t, width: r - l, height: b - t)
    }
}

public struct EntrancePoint: Equatable, Sendable, Codable {
    public var x: Double, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

public struct EntranceSize: Equatable, Sendable, Codable {
    public var width: Double, height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}
