// SPDX-License-Identifier: MIT
// Storyboard shot 3 with the owner's D111 rulings (2026-11-09), replacing the prototype camera:
//  1. it opens with the whole rocket visible and near upright (storyboard E still): tail at the handoff
//     diameter on the tail point, nose on screen, axis within 5 degrees of vertical;
//  2. the rocket visibly lifts one body length;
//  3. one continuous camera move at a constant field of view, no lens-shift slide and no zoom. The lens has one
//     constant horizontal shift that centres the rocket's plane on the cockpit column (a fixed shift lens, as
//     architecture photography uses to keep verticals upright off-centre); the camera only pitches, never yaws
//     or rolls, so the rocket stays upright;
//  4. D132 (owner 2026-11-11, replaces D111.4's overlap search): the end pose looks at the FRONT window from
//     slightly below, as the approved pass-5 window shot does, with the nose above it; the hand-over then dollies
//     through that window until the glass covers the cockpit's c01 aperture, so the cockpit is seen through it.
//     (The D111 search for the best window/c01 overlap ended 62-65 degrees below the window: foreshortened that
//     much, the front window became the top of the silhouette and read as a glass dome.)
// Pure Swift: every pose is solved numerically here, so the rules are checked on Linux.
import Foundation

public struct StoryboardRailInput: Equatable, Sendable {
    public var liftOff: LiftOffInput
    /// The c01 clear aperture outline in viewport points (from the cockpit page); nil uses its rect.
    public var aperture: [EntrancePoint]?
    /// Where the storyboard puts the nose at the opening frame (viewport y); nil aims for 20 % of the height.
    public var targetNoseY: Double?
    public var fovDegrees: Double

    public init(liftOff: LiftOffInput, aperture: [EntrancePoint]? = nil, targetNoseY: Double? = nil,
                fovDegrees: Double = StoryboardRail.defaultFov) {
        self.liftOff = liftOff; self.aperture = aperture; self.targetNoseY = targetNoseY; self.fovDegrees = fovDegrees
    }
}

public struct StoryboardPoseFacts: Equatable, Sendable {
    /// Top edge of the projected rocket (nose tip or canopy), the storyboard's `topY`.
    public let topY: Double
    public let noseY: Double
    public let noseInFront: Bool
    /// Projected rocket axis (tail plate centre to nose tip) from vertical, degrees.
    public let axisTiltDegrees: Double
    /// Projected window outline (convex hull of the glass) and its overlap with the aperture.
    public let windowHull: [EntrancePoint]
    public let windowIoU: Double
}

public struct StoryboardRail: Sendable {
    public static let defaultFov = 30.0
    public static let liftMetres = 14.2
    /// D132: the end-pose camera sits this many degrees below the window centre (the pass-5 window still looks up
    /// at the window from slightly below; the c01 overlap search had ended at 62-65 degrees).
    public static let frontElevation = 20.0
    /// D132: window width at the end pose as a fraction of the aperture width; its top edge sits on the aperture's
    /// bottom edge, so the nose shows above it. Round 9 (D146, the lower, wider pass-5 window, about 2.4:1): 0.7 put
    /// the official nose tip at y 10, under the menu bar; 0.58 keeps it at about y 41 (stand-in 131).
    public static let frontWindowWidth = 0.58
    /// D132 hand-over gate: at the end of the map the glass covers at least this much of the c01 aperture. It
    /// replaces D111.4's window/c01 IoU >= 0.80, which a front window cannot reach (the aperture is about 3:1; the D146
    /// window about 2.4:1, the file's was 1.5:1; the IoU is still reported, and D146 makes a higher one a goal).
    public static let minHandoverCoverage = 0.99
    static let solveTailSamples = 64

    public let input: StoryboardRailInput
    public let geometry: RocketGeometry
    public let start: EntranceCamera
    public let end: EntranceCamera
    public let startAngleDegrees: Double
    /// Degrees the end-pose camera sits below the window centre (`frontElevation`).
    public let endElevationDegrees: Double
    /// Window/aperture IoU at the end pose (reported only since D132).
    public let endIoU: Double
    /// The camera at the end of the hand-over: closer along the same line, the glass covering the aperture.
    public let handover: EntranceCamera
    /// Fraction of the c01 aperture inside the projected glass at the hand-over camera.
    public let handoverCoverage: Double
    let aperturePolygon: [EntrancePoint]
    let tailVertices: [EntranceVector]

    public init(input: StoryboardRailInput, geometry: RocketGeometry = .neutralStandIn) {
        self.input = input
        self.geometry = geometry
        let li = input.liftOff, vp = li.viewport, fov = input.fovDegrees
        let a = li.apertureRect
        let polygon = input.aperture.map { Self.resample($0, count: 128) } ?? [.init(a.left, a.top), .init(a.right, a.top), .init(a.right, a.bottom), .init(a.left, a.bottom)]
        aperturePolygon = polygon
        tailVertices = (0..<LiftOffRail.tailRingSamples).map { i in
            let t = 2 * Double.pi * Double(i) / Double(LiftOffRail.tailRingSamples)
            return .init(sin(t) * LiftOffRail.tailRingRadius, TailLayout.plateY, cos(t) * LiftOffRail.tailRingRadius)
        }
        let solveTail = (0..<Self.solveTailSamples).map { i -> EntranceVector in
            let t = 2 * Double.pi * Double(i) / Double(Self.solveTailSamples)
            return .init(sin(t) * LiftOffRail.tailRingRadius, TailLayout.plateY, cos(t) * LiftOffRail.tailRingRadius)
        }
        let tailCentre = EntranceVector(0, TailLayout.plateY, 0)
        let nose = EntranceVector(0, geometry.height, 0)
        let noseTarget = input.targetNoseY ?? 0.2 * vp.height
        let shift = EntrancePoint((li.tailPoint.x - vp.width / 2) * 2 / vp.width, 0)

        // 1. Opening frame: camera below and in front of the tail, looking up the body.
        var best: (camera: EntranceCamera, angle: Double, score: Double)?
        for angle in stride(from: 15.0, through: 75.0, by: 1.0) {
            let r = angle * Double.pi / 180
            func cameraAt(_ d: Double) -> EntranceCamera {
                let position = EntranceVector(0, TailLayout.plateY - d * sin(r), d * cos(r))
                var camera = Self.aim(position, toPut: tailCentre, at: li.tailPoint, lookingAt: .init(0, geometry.height * 0.5, 0), fov: fov, viewport: vp, shift: shift)
                // Centre the projected ring (not the projected disc centre) on the tail point, as the reference does.
                for _ in 0..<4 {
                    let ring = camera.projectBounds(solveTail), disc = camera.project(tailCentre).point
                    if abs(ring.centre.y - li.tailPoint.y) < 0.05 { break }
                    camera = Self.aim(position, toPut: tailCentre, at: .init(disc.x, disc.y + li.tailPoint.y - ring.centre.y),
                                      lookingAt: .init(0, geometry.height * 0.5, 0), fov: fov, viewport: vp, shift: shift)
                }
                return camera
            }
            var lo = 1.5, hi = 120.0
            for _ in 0..<40 {
                let m = (lo + hi) / 2
                if cameraAt(m).projectBounds(solveTail).width > li.handoffDiameter { lo = m } else { hi = m }
            }
            let camera = cameraAt((lo + hi) / 2)
            let n = camera.project(nose), base = camera.project(tailCentre)
            guard n.inFront, n.point.y >= li.menuBarHeight + 12, n.point.y < base.point.y else { continue }
            let tilt = atan2(n.point.x - base.point.x, base.point.y - n.point.y) * 180 / Double.pi
            guard abs(tilt) <= 5 else { continue }
            // The storyboard measures the silhouette's top edge; seen from below and in front, the canopy on the
            // nose capsule can rise above the nose tip, so match the higher of the two.
            let top = Self.silhouetteTop(camera, geometry: geometry, rise: 0)
            guard top >= li.menuBarHeight + 12 else { continue }
            let score = abs(top - noseTarget)
            if best == nil || score < best!.score { best = (camera, angle, score) }
        }
        // Fallback (never expected on supported screens): the steepest pose that keeps the tail on its point.
        let opening = best ?? (camera: Self.aim(.init(0, -6, 4), toPut: tailCentre, at: li.tailPoint, lookingAt: nose, fov: fov, viewport: vp, shift: shift),
                               angle: 56.0, score: Double.infinity)
        start = opening.camera
        startAngleDegrees = opening.angle

        // 4. D132 end pose on the risen rocket: the front window seen from `frontElevation` below its centre, as
        // wide as `frontWindowWidth` of the aperture, its top edge on the aperture's bottom edge (nose above it).
        let glass = geometry.glassVertices.map { EntranceVector($0.x, $0.y + Self.liftMetres, $0.z) }
        let centre = EntranceVector(geometry.glassCentre.x, geometry.glassCentre.y + Self.liftMetres, geometry.glassCentre.z)
        let apertureBounds = EntranceRect.bounds(polygon)
        let e = Self.frontElevation * Double.pi / 180
        let direction = EntranceVector(0, -sin(e), cos(e))
        /// A pitch-only camera `d` metres from the window centre along `direction`: the window's top edge on
        /// `windowTop`, or (nil) the window's box centre on the aperture centre.
        func placed(_ d: Double, windowTop: Double?) -> EntranceCamera {
            let position = centre + direction * d
            var camera = Self.aim(position, toPut: centre, at: apertureBounds.centre, lookingAt: centre, fov: fov, viewport: vp, shift: shift)
            for _ in 0..<8 {
                let box = camera.projectBounds(glass)
                let dy = windowTop.map { $0 - box.top } ?? (apertureBounds.centre.y - box.centre.y)
                if abs(dy) < 0.25 { break }
                let c = camera.project(centre).point
                camera = Self.aim(position, toPut: centre, at: .init(c.x, c.y + dy), lookingAt: centre, fov: fov, viewport: vp, shift: shift)
            }
            return camera
        }
        var lo = 0.8, hi = 40.0
        for _ in 0..<30 {
            let m = (lo + hi) / 2
            if placed(m, windowTop: apertureBounds.bottom).projectBounds(glass).width > Self.frontWindowWidth * apertureBounds.width { lo = m } else { hi = m }
        }
        let endDistance = (lo + hi) / 2
        let endCamera = placed(endDistance, windowTop: apertureBounds.bottom)
        end = endCamera
        endElevationDegrees = Self.frontElevation
        endIoU = Self.iou(Self.convexHull(glass.map { endCamera.project($0).point }), polygon, step: 2)

        // The hand-over: the farthest camera on the same line whose glass covers the aperture.
        func covered(_ camera: EntranceCamera, step: Double) -> Double {
            let projected = glass.map { camera.project($0) }
            guard projected.allSatisfy(\.inFront) else { return 0 }
            return Self.coverage(of: polygon, by: Self.convexHull(projected.map(\.point)), step: step)
        }
        lo = 1.0; hi = endDistance
        for _ in 0..<30 {
            let m = (lo + hi) / 2
            if covered(placed(m, windowTop: nil), step: 3) >= Self.minHandoverCoverage + 0.005 { lo = m } else { hi = m }
        }
        let handoverCamera = placed(lo, windowTop: nil)
        handover = handoverCamera
        handoverCoverage = covered(handoverCamera, step: 2)
    }

    /// One continuous move: position along a straight smootherstep path, orientation slerped over the whole
    /// stage, constant field of view and one constant lens shift; the rocket rises one body length with the same easing.
    public func pose(at t: Double) -> LiftOffPose {
        let t = min(1, max(0, t)), u = EntranceEasing.smootherstep(t)
        let camera = EntranceCamera(position: start.position.lerp(to: end.position, u),
                                    orientation: start.orientation.slerp(to: end.orientation, u),
                                    fovDegrees: input.fovDegrees, viewport: input.liftOff.viewport, shift: start.shift)
        return pose(camera, rise: Self.liftMetres * u, progress: t, turnTarget: end.orientation)
    }

    /// D132 hand-over (the map stage): from the end pose the camera dollies along the same line toward the window
    /// until the glass covers the c01 aperture. Same field of view and lens shift, pitch only; the rocket holds.
    public func handoverPose(at t: Double) -> LiftOffPose {
        let t = min(1, max(0, t)), u = EntranceEasing.smootherstep(t)
        let camera = EntranceCamera(position: end.position.lerp(to: handover.position, u),
                                    orientation: end.orientation.slerp(to: handover.orientation, u),
                                    fovDegrees: input.fovDegrees, viewport: input.liftOff.viewport, shift: start.shift)
        return pose(camera, rise: Self.liftMetres, progress: t, turnTarget: handover.orientation)
    }

    func pose(_ camera: EntranceCamera, rise: Double, progress: Double, turnTarget: EntranceQuaternion) -> LiftOffPose {
        let lift = { (p: EntranceVector) in EntranceVector(p.x, p.y + rise, p.z) }
        let tail = tailVertices.map(lift).map { camera.project($0) }
        return LiftOffPose(progress: progress, camera: camera, rise: rise,
                           windowRect: camera.projectBounds(geometry.glassVertices.map(lift)),
                           tailRect: .bounds(tail.map(\.point)), tailInFront: tail.allSatisfy(\.inFront),
                           turnRemainingDegrees: camera.orientation.angle(to: turnTarget) * 180 / Double.pi)
    }

    /// D146 (reported, a goal, not a gate): the highest window/aperture IoU along the hand-over dolly, and where.
    /// The end pose itself has the window under the aperture (IoU about 0); the canopy reads closest to the
    /// cockpit's outline part-way through the dolly.
    public func handoverPeakIoU(samples: Int = 20, step: Double = 3) -> (iou: Double, t: Double) {
        var best = (iou: 0.0, t: 0.0)
        for i in 0...samples {
            let t = Double(i) / Double(samples), camera = handoverPose(at: t).camera
            let projected = geometry.glassVertices.map { camera.project(.init($0.x, $0.y + Self.liftMetres, $0.z)) }
            guard projected.allSatisfy(\.inFront) else { continue }
            let value = Self.iou(Self.convexHull(projected.map(\.point)), aperturePolygon, step: step)
            if value > best.iou { best = (value, t) }
        }
        return best
    }

    public func facts(at t: Double) -> StoryboardPoseFacts {
        let pose = pose(at: t), camera = pose.camera, rise = pose.rise
        let nose = camera.project(.init(0, geometry.height + rise, 0))
        // The axis segment in front of the camera (the tail may be behind it late in the move).
        let axis = (0...40).map { i in camera.project(.init(0, TailLayout.plateY + rise + (geometry.height - TailLayout.plateY) * Double(i) / 40, 0)) }
            .filter(\.inFront)
        let low = axis.first ?? nose, high = axis.last ?? nose
        let hull = Self.convexHull(geometry.glassVertices.map { camera.project(.init($0.x, $0.y + rise, $0.z)).point })
        return .init(topY: Self.silhouetteTop(camera, geometry: geometry, rise: rise), noseY: nose.point.y, noseInFront: nose.inFront,
                     axisTiltDegrees: atan2(high.point.x - low.point.x, max(1e-9, low.point.y - high.point.y)) * 180 / Double.pi,
                     windowHull: hull, windowIoU: Self.iou(hull, aperturePolygon, step: 2))
    }

    /// Top edge of the projected rocket (nose tip and canopy glass), viewport y.
    static func silhouetteTop(_ camera: EntranceCamera, geometry: RocketGeometry, rise: Double) -> Double {
        let points = [EntranceVector(0, geometry.height + rise, 0)] + geometry.glassVertices.map { EntranceVector($0.x, $0.y + rise, $0.z) }
        return points.map { camera.project($0) }.filter(\.inFront).map(\.point.y).min() ?? .infinity
    }

    // MARK: - Solvers

    /// A camera at `position` that only pitches (no yaw, no roll) so that `point` lands on `screen.y`; the
    /// constant `shift` places the rocket's plane at `screen.x`.
    static func aim(_ position: EntranceVector, toPut point: EntranceVector, at screen: EntrancePoint,
                    lookingAt initial: EntranceVector, fov: Double, viewport: EntranceSize, shift: EntrancePoint) -> EntranceCamera {
        var target = EntranceVector(position.x, initial.y, initial.z)
        let tanHalf = tan(fov * Double.pi / 360)
        var camera = EntranceCamera(position: position, orientation: .lookAt(eye: position, target: target), fovDegrees: fov,
                                    viewport: viewport, shift: shift)
        for _ in 0..<40 {
            let s = camera.project(point).point
            let dy = s.y - screen.y
            if abs(dy) < 0.01 { break }
            // One pixel of screen motion is this much sideways motion of the look-at target.
            let perPixel = 2 * (target - position).length * tanHalf / viewport.height
            let up = camera.orientation.rotate(.init(0, 1, 0))
            target = target - up * (dy * perPixel)
            camera.orientation = .lookAt(eye: position, target: target)
        }
        return camera
    }

    /// Equal-arc-length resampling of a closed outline (the spec's 128-point outline).
    public static func resample(_ points: [EntrancePoint], count: Int) -> [EntrancePoint] {
        guard points.count > count else { return points }
        let n = points.count
        let lengths = (0..<n).map { i -> Double in
            let a = points[i], b = points[(i + 1) % n]; return ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
        }
        let total = lengths.reduce(0, +)
        var out: [EntrancePoint] = [], edge = 0, walked = 0.0
        for k in 0..<count {
            let want = Double(k) * total / Double(count)
            while edge < n - 1 && walked + lengths[edge] < want { walked += lengths[edge]; edge += 1 }
            let a = points[edge], b = points[(edge + 1) % n], u = lengths[edge] > 0 ? (want - walked) / lengths[edge] : 0
            out.append(.init(a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u))
        }
        return out
    }

    public static func convexHull(_ points: [EntrancePoint]) -> [EntrancePoint] {
        let p = points.sorted { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y) }
        guard p.count > 2 else { return p }
        func cross(_ o: EntrancePoint, _ a: EntrancePoint, _ b: EntrancePoint) -> Double { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        var lower: [EntrancePoint] = [], upper: [EntrancePoint] = []
        for q in p { while lower.count > 1 && cross(lower[lower.count - 2], lower[lower.count - 1], q) <= 0 { lower.removeLast() }; lower.append(q) }
        for q in p.reversed() { while upper.count > 1 && cross(upper[upper.count - 2], upper[upper.count - 1], q) <= 0 { upper.removeLast() }; upper.append(q) }
        return Array(lower.dropLast() + upper.dropLast())
    }

    static func inside(_ poly: [EntrancePoint], _ x: Double, _ y: Double) -> Bool {
        var c = false, j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > y) != (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x { c.toggle() }
            j = i
        }
        return c
    }

    /// Fraction of polygon `a`'s area that lies inside polygon `b`, by grid sampling (`step` points).
    public static func coverage(of a: [EntrancePoint], by b: [EntrancePoint], step: Double) -> Double {
        guard a.count > 2, b.count > 2 else { return 0 }
        let box = EntranceRect.bounds(a), bb = EntranceRect.bounds(b)
        var inA = 0, both = 0
        var y = box.top + step / 2
        while y < box.bottom {
            var x = box.left + step / 2
            while x < box.right {
                if inside(a, x, y) {
                    inA += 1
                    if x >= bb.left && x <= bb.right && y >= bb.top && y <= bb.bottom && inside(b, x, y) { both += 1 }
                }
                x += step
            }
            y += step
        }
        return inA > 0 ? Double(both) / Double(inA) : 0
    }

    /// Area overlap of two polygons by grid sampling (`step` points).
    public static func iou(_ a: [EntrancePoint], _ b: [EntrancePoint], step: Double) -> Double {
        guard a.count > 2, b.count > 2 else { return 0 }
        let box = EntranceRect.bounds(a + b), ba = EntranceRect.bounds(a), bb = EntranceRect.bounds(b)
        func within(_ r: EntranceRect, _ x: Double, _ y: Double) -> Bool { x >= r.left && x <= r.right && y >= r.top && y <= r.bottom }
        var both = 0, either = 0
        var y = box.top + step / 2
        while y < box.bottom {
            var x = box.left + step / 2
            while x < box.right {
                let ia = within(ba, x, y) && inside(a, x, y), ib = within(bb, x, y) && inside(b, x, y)
                if ia && ib { both += 1 }
                if ia || ib { either += 1 }
                x += step
            }
            y += step
        }
        return either > 0 ? Double(both) / Double(either) : 0
    }
}
