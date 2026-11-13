// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

public struct CautionCondition: Equatable, Sendable {
    public enum Severity: Int, Comparable, Sendable { case amber = 1, red = 2
        public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }
    public let id: String, severity: Severity
    public init(id: String, severity: Severity) { self.id = id; self.severity = severity }
}
public struct CautionState: Equatable, Sendable {
    public enum Mode: String, Sendable { case off, blinking, steadyUnacknowledged, acknowledged }
    public private(set) var mode: Mode = .off
    public private(set) var severity: CautionCondition.Severity?
    public private(set) var deadline: Double?
    public private(set) var blinkStart: Double?
    private var active: [String: CautionCondition.Severity] = [:]
    private var acknowledged: [String: CautionCondition.Severity] = [:]
    public init() {}
    public mutating func update(_ conditions: [CautionCondition], now: Double, reduceMotion: Bool) {
        var next: [String: CautionCondition.Severity] = [:]
        for c in conditions { next[c.id] = max(next[c.id] ?? c.severity, c.severity) }
        let newEpisodeIDs = Set(next.compactMap { id, severity -> String? in
            guard let previous = active[id] else { return id }
            return severity > previous ? id : nil
        })
        let newEpisode = !newEpisodeIDs.isEmpty
        // A renewed/worsened condition needs a fresh press; unrelated acknowledgements survive.
        acknowledged = acknowledged.filter { next[$0.key] != nil && !newEpisodeIDs.contains($0.key) }
        active = next; severity = next.values.max()
        guard !next.isEmpty else { mode = .off; deadline = nil; blinkStart = nil; return }
        if newEpisode {
            mode = reduceMotion ? .steadyUnacknowledged : .blinking
            blinkStart = now; deadline = reduceMotion ? nil : now + 10
        } else if next.allSatisfy({ (acknowledged[$0.key]?.rawValue ?? 0) >= $0.value.rawValue }) {
            mode = .acknowledged; deadline = nil
        } else { validate(now: now, reduceMotion: reduceMotion) }
    }
    public mutating func validate(now: Double, reduceMotion: Bool) {
        guard mode == .blinking else { return }
        if reduceMotion || deadline.map({ now >= $0 }) == true { mode = .steadyUnacknowledged; deadline = nil }
    }
    public mutating func press() {
        guard !active.isEmpty else { return }
        acknowledged = active; mode = .acknowledged; deadline = nil
    }
}

/// One CA animation with a finite duration and a steady model value; no forwards-fill/repeating timer.
@MainActor public enum BoundedOpacity {
    public static func apply(to layer: CALayer, remaining: Double, phase: Double = 0, key: String) {
        layer.removeAnimation(forKey: key); layer.opacity = 1
        guard remaining > 0 else { return }
        let duration = min(remaining, 120)
        var times = [0.0], values: [Float] = [phase.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.2]
        var next = 0.5 - phase.truncatingRemainder(dividingBy: 0.5)
        while next < duration { times.append(next / duration); values.append(values.last! == 1 ? 0.2 : 1); next += 0.5 }
        times.append(1) // Discrete keyTimes must contain values.count + 1 interval boundaries.
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = values.map(NSNumber.init(value:)); animation.keyTimes = times.map(NSNumber.init(value:))
        animation.duration = duration; animation.calculationMode = .discrete; animation.isRemovedOnCompletion = true
        layer.add(animation, forKey: key)
    }
}
