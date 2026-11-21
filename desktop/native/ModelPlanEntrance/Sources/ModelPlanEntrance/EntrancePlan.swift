// SPDX-License-Identifier: MIT
// One entrance, planned once at ignition. Every visual layer reads `facts(at:)` from the same clock, so frame
// drops never move a stage boundary. `EntranceFrameFacts` is the read-only seam tests and the frame-match
// capture observe (it mirrors the web reference's per-frame receipt fields).
import Foundation

/// Scene environment and rocket finish. One shared model; the theme picks the approved finish
/// (night graphite gunmetal / day satin aluminium, owner 2026-10-24) and the environment preset.
/// Geometry, timing and camera never depend on it.
public enum EntranceTheme: String, Sendable, Codable, CaseIterable {
    case night, day
}

public struct EntranceScenario: Equatable, Sendable, Codable {
    /// Visible dock subscription IDs in dock order (no empty or +N slots).
    public var dockIDs: [String]
    /// Points from the closed dock ring centre to the tail point (drives the roll duration).
    public var rollDistance: Double
    public var liftOff: LiftOffInput
    public var theme: EntranceTheme
    public var restoreClosed: Bool
    public var glide: Bool
    public var beat: Double

    public init(dockIDs: [String], rollDistance: Double, liftOff: LiftOffInput, theme: EntranceTheme = .night,
                restoreClosed: Bool = false, glide: Bool = false, beat: Double = EntranceTimeline.defaultBeat) {
        self.dockIDs = dockIDs; self.rollDistance = rollDistance; self.liftOff = liftOff; self.theme = theme
        self.restoreClosed = restoreClosed; self.glide = glide; self.beat = beat
    }
}

public struct EntranceFrameFacts: Equatable, Sendable {
    public let time: Double
    public let stage: EntranceStage
    public let progress: Double
    public let countdownDigit: Int?
    public let theme: EntranceTheme
    /// Tail cylinder order (= visible dock order).
    public let stationOrder: [String]
    /// Rocket nose direction; always up (owner rule).
    public let noseUp: Bool
    /// Camera pose for the 3D stages (lift-off, and the held end pose during and after the map).
    public let liftOff: LiftOffPose?
    /// Rocket opacity during the map crossfade (1 before it, 0 after it).
    public let rocketOpacity: Double
    /// Nozzle landing progress (0 until the last 150 ms of the map, eased).
    public let landing: Double
    /// Flame strength (D111.6): full through the rise, going out with the rocket during the window map.
    public var flameStrength: Double { stage == .liftOff ? 1 : stage == .map ? rocketOpacity : 0 }
}

/// Which camera drives shot 3: the owner's D111 storyboard camera (default) or the superseded prototype path,
/// kept only to prove the port of the web reference (provisional goldens).
public enum EntranceCameraPath: Sendable { case storyboard, prototype }

public struct EntrancePlan: Sendable {
    public let scenario: EntranceScenario
    public let timeline: EntranceTimeline
    public let tail: [TailSlot]
    public let rail: LiftOffRail
    public let storyboard: StoryboardRail?

    public init(_ scenario: EntranceScenario, geometry: RocketGeometry = .neutralStandIn, camera: EntranceCameraPath = .storyboard,
                aperture: [EntrancePoint]? = nil, targetNoseY: Double? = nil) {
        self.scenario = scenario
        timeline = EntranceTimeline(distance: scenario.rollDistance, restoreClosed: scenario.restoreClosed,
                                    glide: scenario.glide, beat: scenario.beat)
        tail = TailLayout.slots(for: scenario.dockIDs)
        rail = LiftOffRail(input: scenario.liftOff, geometry: geometry)
        storyboard = camera == .storyboard
            ? StoryboardRail(input: .init(liftOff: scenario.liftOff, aperture: aperture, targetNoseY: targetNoseY), geometry: geometry)
            : nil
    }

    func shot3(_ t: Double) -> LiftOffPose { storyboard?.pose(at: t) ?? rail.pose(at: t) }

    public func facts(at t: Double) -> EntranceFrameFacts {
        let position = timeline.position(at: t)
        let pose: LiftOffPose?
        var rocketOpacity = 1.0, landing = 0.0
        switch position.stage {
        case .countdown, .curl, .roll: pose = nil
        case .liftOff: pose = shot3(position.progress)
        case .map:
            pose = shot3(1)
            rocketOpacity = 1 - position.progress
            landing = EntranceEasing.smootherstep((position.time - timeline.landingStart) / EntranceTimeline.landingDuration)
        case .shutter, .glide, .done:
            pose = shot3(1); rocketOpacity = 0; landing = 1
        }
        return EntranceFrameFacts(time: position.time, stage: position.stage, progress: position.progress,
                                  countdownDigit: timeline.countdownDigit(at: position.time), theme: scenario.theme,
                                  stationOrder: tail.map(\.id), noseUp: true, liftOff: pose,
                                  rocketOpacity: rocketOpacity, landing: landing)
    }

    /// The frame-match timestamps of spec §8 for this plan (seconds after ignition).
    public var frameMatchTimestamps: [Double] {
        let t = timeline, p = t.liftOffStart, i = t.mapStart
        var stamps = [-t.countdown, -t.countdown + 0.5, 0, 0.15, EntranceTimeline.curlDuration,
                      t.rollStart + t.roll / 2, p]
        stamps += [0.1, 0.3, 0.5, 0.7, 0.9].map { p + $0 * EntranceTimeline.liftOffDuration }
        stamps += [i, i + 0.15, i + 0.30, i + 0.375, t.mapEnd]
        if t.restoresClosed { stamps.append(t.shutterEnd) }
        if t.glides { stamps.append(t.end) }
        return stamps
    }
}
