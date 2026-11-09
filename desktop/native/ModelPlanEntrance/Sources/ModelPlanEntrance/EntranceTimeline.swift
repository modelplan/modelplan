// SPDX-License-Identifier: MIT
// CKP-ENT-03 timing (storyboard, owner 2026-10-25) and DOCK-3.1-27 countdown. Seconds after ignition;
// the countdown runs before t = 0. Ported from the approved web reference `timeline.js`.
import Foundation

public enum EntranceStage: String, Sendable, Codable, CaseIterable {
    case countdown, curl, roll, liftOff, map, shutter, glide, done
}

public struct EntranceTimeline: Equatable, Sendable, Codable {
    public static let holdThreshold = 0.20
    public static let defaultBeat = 0.25
    public static let beats = 3
    public static let curlDuration = 0.30
    public static let liftOffDuration = 0.60
    public static let mapDuration = 0.45
    /// The last part of the map in which the tail nozzles land on the cockpit base.
    public static let landingDuration = 0.15
    public static let shutterDuration = 0.18
    public static let glideDuration = 0.25
    /// Roll speed in points per second and its clamp.
    public static let rollSpeed = 1600.0
    public static let rollClamp: ClosedRange<Double> = 0.35...0.70

    public let countdown: Double
    public let roll: Double
    /// Stage starts, seconds after ignition.
    public let rollStart: Double, liftOffStart: Double, mapStart: Double, mapEnd: Double, shutterEnd: Double, end: Double
    public let restoresClosed: Bool, glides: Bool

    /// - Parameters:
    ///   - distance: points between the closed dock ring centre and the tail point under the cockpit.
    ///   - restoreClosed: the user left the cockpit closed and it is not a short screen (180 ms shutter after the map).
    ///   - glide: a detached cockpit lands at an anchor that differs from its saved position (250 ms glide).
    ///   - beat: countdown beat (Settings, SET-9-14).
    public init(distance: Double, restoreClosed: Bool = false, glide: Bool = false, beat: Double = defaultBeat) {
        countdown = Self.holdThreshold + Double(Self.beats) * beat
        roll = Self.clampRoll(distance)
        rollStart = Self.curlDuration
        liftOffStart = rollStart + roll
        mapStart = liftOffStart + Self.liftOffDuration
        mapEnd = mapStart + Self.mapDuration
        shutterEnd = mapEnd + (restoreClosed ? Self.shutterDuration : 0)
        end = shutterEnd + (glide ? Self.glideDuration : 0)
        restoresClosed = restoreClosed
        glides = glide
    }

    public static func clampRoll(_ distance: Double) -> Double {
        min(rollClamp.upperBound, max(rollClamp.lowerBound, distance / rollSpeed))
    }

    /// Start of the nozzle landing inside the map stage.
    public var landingStart: Double { mapEnd - Self.landingDuration }

    public struct Position: Equatable, Sendable, Codable {
        public let stage: EntranceStage
        /// 0...1 within the stage (1 for `.done`).
        public let progress: Double
        /// The clamped time that was sampled.
        public let time: Double
    }

    /// Stage and progress at `t` seconds after ignition; negative times are the countdown.
    public func position(at t: Double) -> Position {
        let time = max(-countdown, min(end, t))
        func p(_ from: Double, _ duration: Double, _ stage: EntranceStage) -> Position {
            .init(stage: stage, progress: duration > 0 ? min(1, max(0, (time - from) / duration)) : 1, time: time)
        }
        if time < 0 { return p(-countdown, countdown, .countdown) }
        if time < rollStart { return p(0, Self.curlDuration, .curl) }
        if time < liftOffStart { return p(rollStart, roll, .roll) }
        if time < mapStart { return p(liftOffStart, Self.liftOffDuration, .liftOff) }
        if time < mapEnd { return p(mapStart, Self.mapDuration, .map) }
        if restoresClosed && time < shutterEnd { return p(mapEnd, Self.shutterDuration, .shutter) }
        if glides && time < end { return p(shutterEnd, Self.glideDuration, .glide) }
        return .init(stage: .done, progress: 1, time: time)
    }

    /// Countdown digit lit at `t` (3, 2, 1), or nil before the hold threshold and after ignition.
    public func countdownDigit(at t: Double) -> Int? {
        let sinceThreshold = t + countdown - Self.holdThreshold
        guard t < 0, sinceThreshold >= 0 else { return nil }
        let beat = (countdown - Self.holdThreshold) / Double(Self.beats)
        return Self.beats - min(Self.beats - 1, Int(sinceThreshold / beat))
    }
}

public enum EntranceEasing {
    /// Quintic smootherstep, the reference's camera rail and landing easing.
    public static func smootherstep(_ t: Double) -> Double {
        let t = min(1, max(0, t)); return t * t * t * (10 + t * (-15 + 6 * t))
    }
    public static func smoothstep(_ t: Double) -> Double {
        let t = min(1, max(0, t)); return t * t * (3 - 2 * t)
    }
    /// CSS ease-out, cubic-bezier(0, 0, .58, 1), shared with the 180 ms shutter (bisection as in the reference).
    public static func easeOut(_ t: Double) -> Double {
        let t = min(1, max(0, t))
        if t == 0 || t == 1 { return t }
        var a = 0.0, b = 1.0
        for _ in 0..<28 {
            let s = (a + b) / 2, x = 3 * (1 - s) * s * s * 0.58 + s * s * s
            if x < t { a = s } else { b = s }
        }
        let s = (a + b) / 2
        return 3 * (1 - s) * s * s + s * s * s
    }
}
