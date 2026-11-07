// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import Foundation
import CoreGraphics

public struct T2Subscription: Sendable {
    public let id: String
    public let alias: String
    public let hasEvent: Bool
    public init(id: String, alias: String = "", hasEvent: Bool = false) {
        self.id = id; self.alias = alias; self.hasEvent = hasEvent
    }
}

public struct T2GeometryInput: Sendable {
    public let coordinates: T2EdgeCoordinates
    public let diameter: CGFloat
    public let showsPercentages: Bool
    public let along: CGFloat
    public let ignitionAtEnd: Bool
    /// Owner test option only: each ring sits halfway across the face at its own height.
    public let centresRings: Bool
    public init(coordinates: T2EdgeCoordinates, diameter: CGFloat = 44,
                showsPercentages: Bool = true, along: CGFloat = 0.5,
                ignitionAtEnd: Bool? = nil, centresRings: Bool = false) {
        self.coordinates = coordinates; self.diameter = diameter; self.centresRings = centresRings
        self.showsPercentages = showsPercentages; self.along = along
        self.ignitionAtEnd = ignitionAtEnd ?? (coordinates.edge == .bottom)
    }
}

public struct T2Station: Sendable {
    public let subscription: T2Subscription?
    public let isOverflow: Bool
    public let isEmpty: Bool
    public let arcPosition: CGFloat
    public let centre: CGPoint
    public let inwardNormal: CGVector
    public let readoutCentre: CGPoint
    public let pitch: CGFloat
}

/// Pure native translation of the accepted T2 study's geometry.js.
/// Coordinates remain top-left-origin throughout, including local samples.
public struct T2Geometry: Sendable {
    public let input: T2GeometryInput
    public let stations: [T2Station]
    public let shown: [T2Subscription]
    public let overflow: [T2Subscription]
    public let outline: [CGPoint]
    public let outlineLocal: [CGPoint]
    public let button: CGPoint
    public let grip: CGPoint
    /// DOCK-3.1-29: the grip's position along the arc and its depth (half the tip width, at least 9).
    public let gripArc: CGFloat
    public let gripDepth: CGFloat
    public let buttonOverhang: CGFloat
    public let radius: CGFloat
    public let sliceAngle: CGFloat
    public let arcLength: CGFloat
    public let span: CGFloat
    public let gap: CGFloat
    public let midpoint: CGFloat
    public let placementCentre: CGFloat
    public let start: CGFloat
    public let end: CGFloat
    public let topJoin: CGFloat
    public let bottomJoin: CGFloat
    public let freeDepth: CGFloat
    public let stationDepth: CGFloat
    public let clockRadius: CGFloat
    public let sliverCentre: CGPoint

    /// DOCK-3.1-22/-24: the control is the registered guard, not the smaller
    /// lacquer cap or the contact shadow. Coordinates use the same study space.
    public var ignitionBounds: CGRect {
        let diameter = 34 * input.diameter / 52
        return CGRect(x: button.x - diameter / 2, y: button.y - diameter / 2,
                      width: diameter, height: diameter)
    }

    /// Value for StaticDockGeometry.consoleButton after the appearance chooses
    /// its raster bounds. Refuse a crop that would leave part of the control
    /// outside the view rather than silently clipping or guessing a new target.
    public func consoleButtonRect(in rasterBounds: CGRect) throws -> CGRect {
        guard !rasterBounds.isEmpty,
              [rasterBounds.minX, rasterBounds.minY, rasterBounds.width, rasterBounds.height].allSatisfy(\.isFinite),
              rasterBounds.contains(ignitionBounds) else { throw InputError.invalidGeometry }
        return ignitionBounds.offsetBy(dx: -rasterBounds.minX, dy: -rasterBounds.minY)
    }

    public func point(arc: CGFloat, depth: CGFloat, onFace: Bool = false) -> CGPoint {
        let first = stations[0].arcPosition
        let depthCentre = stationDepth - radius * cos(first / radius)
        let inward = depth + (onFace ? depth / freeDepth : 1) *
            (depthCentre + radius * cos(arc / radius) - stationDepth)
        return input.coordinates.point(along: radius * sin(arc / radius), inward: inward, midpoint: midpoint)
    }

    public enum InputError: Error { case invalidGeometry }
    private struct Slot {
        let subscription: T2Subscription?
        let overflow: Bool
        let empty: Bool
    }
    private struct Measure {
        let pitches: [CGFloat], positions: [CGFloat]
        let arcLength: CGFloat, angle: CGFloat, radius: CGFloat, depthCentre: CGFloat
        let start: CGFloat, end: CGFloat, topJoin: CGFloat, bottomJoin: CGFloat
        let freeDepth: CGFloat, stationDepth: CGFloat
        func local(_ s: CGFloat, _ d: CGFloat, face: Bool = false) -> CGPoint {
            CGPoint(x: radius * sin(s / radius),
                    y: d + (face ? d / freeDepth : 1) *
                        (depthCentre + radius * cos(s / radius) - stationDepth))
        }
        var span: CGFloat { local(end, stationDepth).x - local(start, stationDepth).x }
        func width(at s: CGFloat) -> CGFloat {
            if s < topJoin {
                let x = (s - topJoin) / (topJoin - start)
                return freeDepth * sqrt(max(0, 1 - x * x))
            }
            if s > bottomJoin {
                let x = (s - bottomJoin) / (end - bottomJoin)
                return freeDepth * sqrt(max(0, 1 - x * x))
            }
            return freeDepth
        }
    }

    public static func make(subscriptions: [T2Subscription], input p: T2GeometryInput) throws -> Self {
        let c = p.coordinates, d = p.diameter, scale = d / 52
        guard [c.width, c.height, c.menuBarExclusion, d, p.along].allSatisfy(\.isFinite),
              [CGFloat(36), 44, 52].contains(d), c.width > 0, c.height > 0,
              c.menuBarExclusion >= 0, (0...1).contains(p.along),
              subscriptions.count <= 256,
              Set(subscriptions.map(\.id)).count == subscriptions.count else { throw InputError.invalidGeometry }
        let vertical = c.edge == .left || c.edge == .right
        let clock = d / 2 + 3 * scale, depth = d / 2 + 14 * scale
        let lo: CGFloat = vertical ? c.menuBarExclusion + 24 : 24
        let hi = (vertical ? c.height : c.width) - 24, available = hi - lo
        guard available > 0 else { throw InputError.invalidGeometry }
        func aliasWidth(_ text: String) -> CGFloat {
            // JavaScript's spread iteration counts Unicode code points, not grapheme clusters.
            text.unicodeScalars.reduce(0) { total, scalar in
                let value = scalar.value
                return total + ((0x3000...0x9fff).contains(value) ||
                    (0xff00...0xffef).contains(value) ? 10 : 6) * scale
            }
        }
        func slots(_ shown: [T2Subscription], more: Bool) -> [Slot] {
            shown.map { Slot(subscription: $0, overflow: false, empty: false) } +
                (more ? [Slot(subscription: nil, overflow: true, empty: false)] : []) +
                (subscriptions.isEmpty ? [Slot(subscription: nil, overflow: false, empty: true)] : [])
        }
        func follows(_ slot: Slot) -> CGFloat {
            let alias = slot.subscription?.alias ?? "", event = slot.subscription?.hasEvent ?? false
            if vertical {
                return (p.showsPercentages ? 16 * scale : event ? 12 * scale : 0) +
                    (alias.isEmpty ? 0 : 16 * scale)
            }
            return p.showsPercentages || event || !alias.isEmpty ? max(58 * scale, aliasWidth(alias) + 10 * scale) : 0
        }
        let capSpan = d / 2 + 10 * scale + 44 * scale / 2
        func measure(_ slots: [Slot], gap: CGFloat) -> Measure {
            let pitches = slots.map { d + (vertical && follows($0) > 0 ? max(gap, 14 * scale) : gap) + follows($0) }
            let length = 2 * capSpan + follows(slots.last!) + pitches.dropLast().reduce(0, +)
            let angle = T2GeometryConstants.slice(for: length / scale), radius = length / angle
            var positions = [CGFloat](), s = -length / 2 + capSpan
            for i in slots.indices { positions.append(s); s += pitches[i] }
            let first = positions.first!, last = positions.last!
            let top = first - 34 * scale
            let bottom = last + max(50 * scale, follows(slots.last!) + d / 2)
            return Measure(pitches: pitches, positions: positions, arcLength: length, angle: angle,
                radius: radius, depthCentre: depth - radius * cos(first / radius),
                start: first - 66 * scale, end: bottom + 32 * scale, topJoin: top,
                bottomJoin: bottom, freeDepth: depth + clock + 7 * scale, stationDepth: depth)
        }
        func fit(_ slots: [Slot]) -> CGFloat? {
            if measure(slots, gap: 14 * scale).span <= available { return 14 * scale }
            if measure(slots, gap: 6 * scale).span > available { return nil }
            var low = 6 * scale, high = 14 * scale
            for _ in 0..<20 {
                let mid = (low + high) / 2
                if measure(slots, gap: mid).span <= available { low = mid } else { high = mid }
            }
            return low
        }
        var visible = subscriptions, more = [T2Subscription]()
        var selected = slots(visible, more: false), gap = fit(selected)
        if gap == nil {
            var count = max(1, subscriptions.count - 1)
            while count > 1 && fit(slots(Array(subscriptions.prefix(count)), more: true)) == nil { count -= 1 }
            visible = Array(subscriptions.prefix(count)); more = Array(subscriptions.dropFirst(count))
            selected = slots(visible, more: true); gap = fit(selected) ?? 6 * scale
        }
        let m = measure(selected, gap: gap!)
        let u0 = m.local(m.start, depth).x, u1 = m.local(m.end, depth).x
        let centre = max(lo + m.span / 2, min(hi - m.span / 2, lo + p.along * available))
        let midpoint = centre - (u0 + u1) / 2
        func screen(_ point: CGPoint) -> CGPoint { c.point(along: point.x, inward: point.y, midpoint: midpoint) }
        let free = (0...480).map { i -> CGPoint in
            let s = m.start + (m.end - m.start) * CGFloat(i) / 480
            return m.local(s, m.width(at: s), face: true)
        }
        let attached = (0...480).reversed().map { i -> CGPoint in
            m.local(m.start + (m.end - m.start) * CGFloat(i) / 480, 0, face: true)
        }
        let localOutline = free + attached
        func inside(_ u: CGFloat, _ d: CGFloat) -> Bool {
            if u < free[0].x || u > free[480].x || d < 0 { return false }
            var low = 0, high = 480
            while low + 1 < high {
                let mid = (low + high) / 2
                if free[mid].x < u { low = mid } else { high = mid }
            }
            let a = free[low], b = free[high]
            return d <= a.y + (b.y - a.y) * (u - a.x) / (b.x - a.x)
        }
        let disc = (0..<4096).map { i -> CGPoint in
            let angle = CGFloat(i) * 2.399963229728653, radius = sqrt((CGFloat(i) + 0.5) / 4096)
            return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
        }
        let buttonDepth = 28 * scale, guardRadius = 34 * scale / 2
        func overhang(_ u: CGFloat) -> CGFloat {
            CGFloat(disc.reduce(0) { n, q in n + (inside(u + q.x * guardRadius, buttonDepth + q.y * guardRadius) ? 0 : 1) }) / 4096
        }
        var low = p.ignitionAtEnd ? u1 + guardRadius : u0 - guardRadius
        var high = m.local(p.ignitionAtEnd ? m.bottomJoin : m.topJoin, depth).x
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if overhang(mid) > 0.4 { low = mid } else { high = mid }
        }
        let buttonU = (low + high) / 2
        let stations = selected.indices.map { i -> T2Station in
            let slot = selected[i], s = m.positions[i], local = m.local(s, depth)
            let point = screen(p.centresRings ? CGPoint(x: local.x, y: (m.freeDepth + local.y - depth) / 2) : local)
            let readout = vertical ? CGPoint(x: point.x, y: point.y + d / 2 + 14 * scale +
                ((slot.subscription?.alias.isEmpty ?? true) ? 0 : 6 * scale)) :
                CGPoint(x: point.x + d / 2 + 31 * scale, y: point.y)
            return T2Station(subscription: slot.subscription, isOverflow: slot.overflow, isEmpty: slot.empty,
                arcPosition: s, centre: point, inwardNormal: c.direction(along: sin(s / m.radius), inward: cos(s / m.radius)),
                readoutCentre: readout, pitch: m.pitches[i])
        }
        let gripS = p.ignitionAtEnd ? m.start + 18 * scale : m.end - 18 * scale
        let gripDepth = max(9 * scale, m.width(at: gripS) / 2)
        return Self(input: p, stations: stations, shown: visible, overflow: more, outline: localOutline.map(screen),
            outlineLocal: localOutline, button: screen(CGPoint(x: buttonU, y: buttonDepth)),
            grip: screen(m.local(gripS, gripDepth, face: true)), gripArc: gripS, gripDepth: gripDepth,
            buttonOverhang: overhang(buttonU), radius: m.radius, sliceAngle: m.angle, arcLength: m.arcLength,
            span: m.span, gap: gap!, midpoint: midpoint, placementCentre: centre, start: m.start, end: m.end,
            topJoin: m.topJoin, bottomJoin: m.bottomJoin, freeDepth: m.freeDepth, stationDepth: depth,
            clockRadius: clock, sliverCentre: c.point(along: 0, inward: 4 * (d / 44) / 2, midpoint: centre))
    }
}
