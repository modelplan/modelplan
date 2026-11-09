// SPDX-License-Identifier: MIT
// Pure-Swift entrance checks. They run on Linux (`swift run ModelPlanEntranceChecks`, no Mac runner) and on
// the Mac through `ModelPlanEntranceTests`, which calls the same suite.
// Reference rule (owner 2026-11-09): the storyboard is the truth for the flight. Groups tagged STORYBOARD
// assert storyboard rules. The camera-path numbers in `ReferenceGoldens` come from the web prototype's
// scene.js (PROVISIONAL): they only prove the port is faithful and will be replaced once the owner rules on
// the prototype deviations (spec entrance-prototype-deviations.md, F1-F8).
import Foundation
import ModelPlanEntrance

public struct EntranceCheckFailure: Error, CustomStringConvertible {
    public let description: String
}

public final class EntranceCheckRun {
    public private(set) var assertions = 0
    public private(set) var passed: [String] = []
    public private(set) var failures: [String] = []

    public init() {}

    func expect(_ value: Bool, _ message: @autoclosure () -> String, line: UInt = #line) throws {
        assertions += 1
        if !value { throw EntranceCheckFailure(description: "EntranceChecks.swift:\(line) \(message())") }
    }

    func near(_ a: Double, _ b: Double, _ tolerance: Double, _ what: String, line: UInt = #line) throws {
        try expect(abs(a - b) <= tolerance, "\(what): \(a) vs \(b) (±\(tolerance))", line: line)
    }

    func near(_ a: EntranceRect, _ b: [Double], _ tolerance: Double, _ what: String, line: UInt = #line) throws {
        try near(a.left, b[0], tolerance, "\(what).left", line: line)
        try near(a.top, b[1], tolerance, "\(what).top", line: line)
        try near(a.width, b[2], tolerance, "\(what).width", line: line)
        try near(a.height, b[3], tolerance, "\(what).height", line: line)
    }

    func group(_ name: String, _ body: () throws -> Void) {
        do { try body(); passed.append(name) } catch { failures.append("\(name): \(error)") }
    }
}

public enum ReferenceGoldens {
    /// REF scenario: 1470 × 956 viewport, 496 pt handoff (80 % of a 620 pt cockpit), tail point (1100, 900),
    /// c01 aperture (880, 70, 420 × 160).
    public static let liftOff = LiftOffInput(
        viewport: .init(width: 1470, height: 956), handoffDiameter: 496, tailPoint: .init(1100, 900),
        apertureRect: .init(left: 880, top: 70, width: 420, height: 160))
    public static let startDistance = 8.098111, endDistance = 3.325344

    public struct Pose {
        public let t: Double, camera: [Double], fov: Double, shift: [Double], window: [Double], tail: [Double]?
        public let pitch: Double, turn: Double, rise: Double
    }

    /// PROVISIONAL prototype poses (rail-golden.mjs over the dc9a1b52d scene.js camera code). Tail rects are
    /// omitted where part of the ring is behind the camera (the reference's numbers there are meaningless).
    public static let poses: [Pose] = [
        .init(t: 0, camera: [2.582596, -6.227439, 4.133017], fov: 32, shift: [0.496591, -0.919944],
              window: [1012.6868, 117.2489, 104.0615, 90.0093], tail: [852, 701.1446, 496, 397.7107],
              pitch: 53, turn: 28.1571, rise: 0),
        .init(t: 0.25, camera: [2.358767, -4.193027, 4.04893], fov: 33.863281, shift: [0.554174, -0.840729],
              window: [1009.2697, 119.3651, 116.1301, 83.2402], tail: [744.1872, 862.0406, 585.4852, 416.4927],
              pitch: 52.2664, turn: 21.2202, rise: 0.155273),
        .init(t: 0.5, camera: [1.148626, 4.69593, 3.671192], fov: 41, shift: [0.615145, -0.343112],
              window: [981.1127, 108.593, 192.4921, 95.0675], tail: nil, pitch: 50.4287, turn: 4.0744, rise: 0.75),
        .init(t: 0.7, camera: [0.291504, 10.572537, 3.291573], fov: 47.06456, shift: [0.516654, 0.505741],
              window: [910.2387, 56.3433, 351.2766, 191.31], tail: nil, pitch: 50, turn: 0, rise: 1.25538),
        .init(t: 1, camera: [0.149104, 11.787638, 3.092283], fov: 50, shift: [0.472617, 0.774768],
              window: [880, 29.3179, 420, 241.3641], tail: nil, pitch: 50, turn: 0, rise: 1.5),
    ]
}

public enum EntranceChecks {
    /// Runs every check group; returns the run with passed groups and failures.
    public static func run() -> EntranceCheckRun {
        let run = EntranceCheckRun()

        run.group("STORYBOARD timeline: roll clamps and stage boundaries") {
            for (distance, roll) in [(100.0, 0.35), (800, 0.5), (3000, 0.7)] {
                let line = EntranceTimeline(distance: distance)
                try run.near(line.roll, roll, 1e-12, "roll for \(distance)")
                try run.near(line.liftOffStart, 0.30 + roll, 1e-12, "lift-off start")
                try run.near(line.mapStart, 0.90 + roll, 1e-12, "map start")
                try run.near(line.mapEnd, 1.35 + roll, 1e-12, "map end")
                try run.near(line.end, line.mapEnd, 1e-12, "end without shutter/glide")
                try run.expect(line.position(at: 0).stage == .curl, "t 0 is the curl")
                try run.expect(line.position(at: 0.30).stage == .roll, "0.30 starts the roll")
                try run.expect(line.position(at: line.liftOffStart).stage == .liftOff, "lift-off boundary")
                try run.expect(line.position(at: line.mapStart).stage == .map, "map boundary")
                try run.expect(line.position(at: line.mapEnd).stage == .done, "done at the map end")
                try run.expect(line.position(at: 99).time == line.end, "clamped to the end")
            }
            let full = EntranceTimeline(distance: 3000, restoreClosed: true, glide: true)
            try run.near(full.end - full.mapEnd, 0.43, 1e-12, "shutter 0.18 + glide 0.25")
            try run.expect(full.position(at: full.mapEnd + 0.1).stage == .shutter, "shutter after the map")
            try run.expect(full.position(at: full.shutterEnd + 0.1).stage == .glide, "glide after the shutter")
            try run.near(EntranceTimeline(distance: 100).end, 1.70, 1e-12, "shortest open core 1.70 s")
            try run.near(EntranceTimeline(distance: 3000).end, 2.05, 1e-12, "longest open core 2.05 s")
            try run.near(full.landingStart, full.mapEnd - 0.15, 1e-12, "landing is the last 150 ms of the map")
        }

        run.group("countdown: 200 ms threshold, three 250 ms beats, ignition at 950 ms (DOCK-3.1-27)") {
            let line = EntranceTimeline(distance: 800)
            try run.near(line.countdown, 0.95, 1e-12, "countdown")
            try run.expect(line.position(at: -2).stage == .countdown, "countdown before ignition")
            try run.near(line.position(at: -2).time, -0.95, 1e-12, "clamped to the press")
            try run.expect(line.countdownDigit(at: -0.95) == nil, "no digit during the 200 ms threshold")
            try run.expect(line.countdownDigit(at: -0.74) == 3, "3 from 200 ms")
            try run.expect(line.countdownDigit(at: -0.49) == 2, "2 from 450 ms")
            try run.expect(line.countdownDigit(at: -0.24) == 1, "1 from 700 ms")
            try run.expect(line.countdownDigit(at: -0.01) == 1, "1 until ignition")
            try run.expect(line.countdownDigit(at: 0) == nil, "no digit after ignition")
            try run.near(EntranceTimeline(distance: 800, beat: 0.3).countdown, 1.10, 1e-12, "beat setting (SET-9-14)")
        }

        run.group("easing: smootherstep and the CSS ease-out used by the shutter") {
            try run.near(EntranceEasing.smootherstep(0.5), 0.5, 1e-12, "smootherstep midpoint")
            try run.near(EntranceEasing.smootherstep(-1), 0, 0, "smootherstep clamps")
            try run.near(EntranceEasing.easeOut(0), 0, 0, "ease-out start")
            try run.near(EntranceEasing.easeOut(1), 1, 0, "ease-out end")
            try run.expect(EntranceEasing.easeOut(0.5) > 0.5, "ease-out is ahead at the midpoint")
            var last = 0.0
            for i in 1...100 { let v = EntranceEasing.easeOut(Double(i) / 100); try run.expect(v >= last, "ease-out monotone"); last = v }
        }

        run.group("STORYBOARD tail layout: visible IDs in dock order, shapes, no overlaps, dock cap (CKP-ENT-05)") {
            for n in [1, 2, 3, 4, 5, 6, 7, 8, 12, 16, 32] {
                let ids = (0..<n).map { "sub-\($0)" }, slots = TailLayout.slots(for: ids)
                try run.expect(slots.map(\.id) == ids, "order for \(n)")
                try run.expect(slots.filter(\.centre).count == (n == 1 || n >= 7 ? 1 : 0), "centre slot for \(n)")
                if n >= 3 {
                    let ring = slots.filter { !$0.centre }
                    for i in 1..<ring.count { try run.expect(ring[i].angle > ring[i - 1].angle, "clockwise ring for \(n)") }
                }
                for i in 0..<n {
                    try run.expect((slots[i].x * slots[i].x + slots[i].z * slots[i].z).squareRoot() + slots[i].radius <= TailLayout.plateRadius,
                                   "slot \(i) of \(n) inside the plate")
                    for k in (i + 1)..<n {
                        let gap = ((slots[i].x - slots[k].x) * (slots[i].x - slots[k].x) + (slots[i].z - slots[k].z) * (slots[i].z - slots[k].z)).squareRoot()
                        try run.expect(gap > slots[i].radius + slots[k].radius, "slots \(i)/\(k) of \(n) do not overlap")
                    }
                }
            }
            try run.expect(TailLayout.slots(for: ["a", "b", "c"], maxVisible: 2).count == 2, "dock cap")
            try run.expect(TailLayout.slots(for: ["a"], maxVisible: 0).isEmpty, "zero visible")
            try run.near(TailLayout.slots(for: ["a", "b", "c", "d"])[0].angle, Double.pi / 4, 1e-12, "square is rotated 45°")
        }

        run.group("PROVISIONAL lift-off rail ports the prototype camera faithfully (not storyboard truth)") {
            let rail = LiftOffRail(input: ReferenceGoldens.liftOff)
            try run.near(rail.startDistance, ReferenceGoldens.startDistance, 1e-5, "start distance")
            try run.near(rail.endDistance, ReferenceGoldens.endDistance, 1e-5, "end distance")
            for golden in ReferenceGoldens.poses {
                let pose = rail.pose(at: golden.t), c = pose.camera, tag = "t \(golden.t)"
                try run.near(c.position.x, golden.camera[0], 1e-4, "\(tag) camera x")
                try run.near(c.position.y, golden.camera[1], 1e-4, "\(tag) camera y")
                try run.near(c.position.z, golden.camera[2], 1e-4, "\(tag) camera z")
                try run.near(c.fovDegrees, golden.fov, 1e-4, "\(tag) fov")
                try run.near(c.shift.x, golden.shift[0], 1e-4, "\(tag) shift x")
                try run.near(c.shift.y, golden.shift[1], 1e-4, "\(tag) shift y")
                try run.near(pose.windowRect, golden.window, 0.05, "\(tag) window")
                if let tail = golden.tail {
                    try run.expect(pose.tailInFront, "\(tag) tail ring in front of the camera")
                    try run.near(pose.tailRect, tail, 0.05, "\(tag) tail")
                }
                try run.near(c.pitchDegrees, golden.pitch, 1e-3, "\(tag) pitch")
                try run.near(pose.turnRemainingDegrees, golden.turn, 1e-3, "\(tag) turn remaining")
                try run.near(pose.rise, golden.rise, 1e-5, "\(tag) rise")
            }
        }

        run.group("STORYBOARD lift-off rules: handoff size, nose up, turn stops, no levelling, window lands on the aperture") {
            let rail = LiftOffRail(input: ReferenceGoldens.liftOff), first = rail.pose(at: 0), last = rail.pose(at: 1)
            try run.near(first.tailRect.width, 496, 0.01, "tail starts at the handoff diameter")
            try run.near(first.tailRect.centre.x, 1100, 0.01, "tail centred on the tail point x")
            try run.near(first.tailRect.centre.y, 900, 0.01, "tail centred on the tail point y")
            try run.near(last.windowRect.width, 420, 0.01, "window as wide as the c01 aperture")
            try run.near(last.windowRect.centre.x, 1090, 0.01, "window centred on the aperture x")
            try run.near(last.windowRect.centre.y, 150, 0.01, "window centred on the aperture y")
            var lastRise = -1.0
            for i in 0...60 {
                let pose = rail.pose(at: Double(i) / 60)
                try run.expect(pose.rise >= lastRise, "rise is monotone"); lastRise = pose.rise
                try run.expect(pose.camera.pitchDegrees >= 45, "camera stays oblique (never levels): \(pose.camera.pitchDegrees)")
                if Double(i) / 60 >= LiftOffRail.turnStop { try run.near(pose.turnRemainingDegrees, 0, 1e-4, "no turning after 70 %") }
            }
        }

        run.group("lens shift renders as a crop of a larger unshifted canvas") {
            let camera = LiftOffRail(input: ReferenceGoldens.liftOff).pose(at: 0.25).camera
            let plan = camera.renderPlan
            var canvas = camera
            canvas.shift = .init(0, 0); canvas.viewport = plan.canvas; canvas.fovDegrees = plan.canvasFovDegrees
            for p in [EntranceVector(0, 0.24, 1.2), .init(1.2, 0.24, 0), .init(0, 12.835, 0.96), .init(-0.5, 5, 1)] {
                let shifted = camera.project(p).point, onCanvas = canvas.project(p).point
                try run.near(onCanvas.x - plan.crop.x, shifted.x, 1e-6, "crop x")
                try run.near(onCanvas.y - plan.crop.y, shifted.y, 1e-6, "crop y")
            }
        }

        run.group("plan facts: stages, station order, crossfade, landing, theme is a parameter") {
            let ids = ["claude", "codex", "zcode", "glm"]
            for theme in EntranceTheme.allCases {
                let plan = EntrancePlan(.init(dockIDs: ids, rollDistance: 800, liftOff: ReferenceGoldens.liftOff, theme: theme))
                let line = plan.timeline
                try run.expect(plan.facts(at: 0.1).liftOff == nil, "no 3D camera during the curl")
                try run.expect(plan.facts(at: line.liftOffStart + 0.3).liftOff != nil, "camera during lift-off")
                try run.expect(plan.facts(at: 1).stationOrder == ids, "station order = dock order")
                try run.expect(plan.facts(at: 1).theme == theme, "theme carried")
                try run.near(plan.facts(at: line.mapStart + 0.225).rocketOpacity, 0.5, 1e-9, "crossfade midpoint")
                try run.near(plan.facts(at: line.landingStart - 0.01).landing, 0, 0, "no landing before the last 150 ms")
                try run.near(plan.facts(at: line.mapEnd).landing, 1, 0, "landed at the map end")
                let night = EntrancePlan(.init(dockIDs: ids, rollDistance: 800, liftOff: ReferenceGoldens.liftOff, theme: .night))
                try run.expect(plan.facts(at: line.liftOffStart + 0.3).liftOff == night.facts(at: line.liftOffStart + 0.3).liftOff,
                               "camera does not depend on the theme")
                let stamps = plan.frameMatchTimestamps
                try run.expect(stamps == stamps.sorted(), "timestamps ascending")
                try run.expect(stamps.count == 17, "17 frame-match timestamps for an open landing")
            }
        }
        return run
    }
}
