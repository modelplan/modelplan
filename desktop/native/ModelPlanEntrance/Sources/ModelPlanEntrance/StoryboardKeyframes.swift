// SPDX-License-Identifier: MIT
// Slice 2 (owner rule 2026-11-09): native frames are compared with the owner-approved storyboard key frames by
// structure (silhouette box, axis, area, nose position), not pixels, because the storyboard stills are
// illustrative grey boxes. The same measurement runs on the storyboard (private script, numbers embedded in
// StoryboardKeyframeData) and on native frames (this file), so both sides share one definition.
import Foundation

/// Structural measurement of the largest 8-connected foreground component of a frame, in viewport points.
public struct SilhouetteMeasurement: Equatable, Sendable, Codable {
    /// left, top, width, height
    public var bbox: [Double]
    public var centroid: [Double]
    /// Component area as a fraction of the viewport.
    public var areaFraction: Double
    /// Principal axis angle from vertical (degrees, signed); 90 for a horizontal shape.
    public var axisFromVerticalDegrees: Double
    /// sqrt(major / minor second moment).
    public var elongation: Double?
    /// Top edge (the nose for an upright rocket).
    public var topY: Double

    public init(bbox: [Double], centroid: [Double], areaFraction: Double, axisFromVerticalDegrees: Double,
                elongation: Double?, topY: Double) {
        self.bbox = bbox; self.centroid = centroid; self.areaFraction = areaFraction
        self.axisFromVerticalDegrees = axisFromVerticalDegrees; self.elongation = elongation; self.topY = topY
    }
}

public enum SilhouetteMeasure {
    /// Measures a binary mask (row-major, row 0 = top). `scale` converts mask pixels to viewport points.
    /// Rows above `ignoreTop` (the menu bar) are excluded. Returns nil for an empty mask.
    public static func measure(mask: [Bool], width: Int, height: Int, scale: Double = 1, ignoreTop: Int = 0,
                               viewport: EntranceSize) -> SilhouetteMeasurement? {
        precondition(mask.count == width * height)
        var label = [Int32](repeating: -1, count: mask.count)
        var best: [Int] = []
        var next: Int32 = 0
        var stack: [Int] = []
        for start in 0..<mask.count where mask[start] && label[start] < 0 && start / width >= ignoreTop {
            var component: [Int] = []
            label[start] = next; stack.append(start)
            while let j = stack.popLast() {
                component.append(j)
                let x = j % width, y = j / width
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, ny >= ignoreTop, nx < width, ny < height else { continue }
                        let q = ny * width + nx
                        if mask[q] && label[q] < 0 { label[q] = next; stack.append(q) }
                    }
                }
            }
            if component.count > best.count { best = component }
            next += 1
        }
        guard !best.isEmpty else { return nil }
        var n = 0.0, sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0
        var l = Double.infinity, t = Double.infinity, r = -Double.infinity, b = -Double.infinity
        for j in best {
            let x = Double(j % width) * scale, y = Double(j / width) * scale
            n += 1; sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y
            l = min(l, x); r = max(r, x); t = min(t, y); b = max(b, y)
        }
        let mx = sx / n, my = sy / n, cxx = sxx / n - mx * mx, cyy = syy / n - my * my, cxy = sxy / n - mx * my
        let theta = 0.5 * atan2(2 * cxy, cxx - cyy) * 180 / Double.pi
        let fromVertical = abs(theta) > 45 ? (theta < 0 ? -1.0 : 1.0) * (90 - abs(theta)) : theta
        let axis = cyy >= cxx ? fromVertical : 90 - abs(fromVertical)
        let elongation = (max(cxx, cyy) / max(1e-9, min(cxx, cyy))).squareRoot()
        return .init(bbox: [l, t, r - l, b - t], centroid: [mx, my],
                     areaFraction: n * scale * scale / (viewport.width * viewport.height),
                     axisFromVerticalDegrees: axis, elongation: elongation, topY: t)
    }
}

public struct StoryboardKeyframe: Equatable, Sendable, Codable {
    public var edge: String
    public var shot: String
    public var time: Double
    public var viewport: [Double]
    public var subscriptions: Int
    public var bbox: [Double]
    public var centroid: [Double]
    public var areaFraction: Double
    public var axisFromVerticalDegrees: Double
    public var elongation: Double?
    public var topY: Double

    public var measurement: SilhouetteMeasurement {
        .init(bbox: bbox, centroid: centroid, areaFraction: areaFraction, axisFromVerticalDegrees: axisFromVerticalDegrees,
              elongation: elongation, topY: topY)
    }
}

public struct StoryboardKeyframes: Equatable, Sendable, Codable {
    public struct Source: Equatable, Sendable, Codable { public var branch: String; public var board: String; public var note: String }
    public var source: Source
    public var frames: [StoryboardKeyframe]

    /// The embedded storyboard numbers.
    public static let approved: StoryboardKeyframes = {
        // The data is a compile-time constant; a decoding failure is a build defect caught by the checks.
        (try? JSONDecoder().decode(StoryboardKeyframes.self, from: Data(StoryboardKeyframeData.json.utf8)))
            ?? StoryboardKeyframes(source: .init(branch: "", board: "", note: "decode failed"), frames: [])
    }()

    public func frame(edge: String, shot: String) -> StoryboardKeyframe? {
        frames.first { $0.edge == edge && $0.shot == shot }
    }
}

/// Structural gates for one key frame (spec §8). Tolerances are fractions of the viewport unless stated.
public struct KeyframeGate: Equatable, Sendable, Codable {
    public var axisDegrees = 5.0
    public var bboxSize = 0.10
    public var centroid = 0.10
    public var areaRatio = 0.25
    public var topY = 0.05
    public init() {}
}

public struct KeyframeComparison: Equatable, Sendable, Codable {
    public struct Check: Equatable, Sendable, Codable {
        public var name: String
        public var storyboard: Double
        public var native: Double
        public var tolerance: Double
        public var passed: Bool
    }
    public var edge: String
    public var shot: String
    public var checks: [Check]
    public var passed: Bool { checks.allSatisfy(\.passed) }
    /// The checks that do not depend on the rocket's exact silhouette (stand-in vs official model).
    public static let poseChecks: Set<String> = ["axisFromVertical", "bboxWidth", "centroidX", "topY"]
    public var posePassed: Bool { checks.filter { Self.poseChecks.contains($0.name) }.allSatisfy(\.passed) }

    public static func compare(native: SilhouetteMeasurement, to frame: StoryboardKeyframe,
                               gate: KeyframeGate = .init()) -> KeyframeComparison {
        let w = frame.viewport[0], h = frame.viewport[1], s = frame.measurement
        var checks: [Check] = []
        func add(_ name: String, _ a: Double, _ b: Double, _ tol: Double) {
            checks.append(.init(name: name, storyboard: a, native: b, tolerance: tol, passed: abs(a - b) <= tol))
        }
        add("axisFromVertical", s.axisFromVerticalDegrees, native.axisFromVerticalDegrees, gate.axisDegrees)
        add("bboxWidth", s.bbox[2], native.bbox[2], gate.bboxSize * w)
        add("bboxHeight", s.bbox[3], native.bbox[3], gate.bboxSize * h)
        add("centroidX", s.centroid[0], native.centroid[0], gate.centroid * w)
        add("centroidY", s.centroid[1], native.centroid[1], gate.centroid * h)
        add("topY", s.topY, native.topY, gate.topY * h)
        let ratio = native.areaFraction / max(1e-9, s.areaFraction)
        checks.append(.init(name: "areaRatio", storyboard: 1, native: ratio, tolerance: gate.areaRatio,
                            passed: abs(ratio - 1) <= gate.areaRatio))
        return .init(edge: frame.edge, shot: frame.shot, checks: checks)
    }
}
