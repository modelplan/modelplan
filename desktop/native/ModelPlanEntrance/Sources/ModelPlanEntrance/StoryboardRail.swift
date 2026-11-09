// SPDX-License-Identifier: MIT
// Storyboard shot 3 with the owner's D111 rulings (2026-11-09), replacing the prototype camera:
//  1. it opens with the whole rocket visible and near upright (storyboard E still): tail at the handoff
//     diameter on the tail point, nose on screen, axis within 5 degrees of vertical;
//  2. the rocket visibly lifts one body length;
//  3. one continuous camera move at a constant field of view, no lens-shift slide and no zoom. The lens has one
//     constant horizontal shift that centres the rocket's plane on the cockpit column (a fixed shift lens, as
//     architecture photography uses to keep verticals upright off-centre); the camera only pitches, never yaws
//     or rolls, so the rocket stays upright;
//  4. the end pose overlaps the rocket window with the cockpit's c01 aperture (IoU >= 0.80 when reachable).
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
    public static let minWindowIoU = 0.80
    static let solveTailSamples = 64

    public let input: StoryboardRailInput
    public let geometry: RocketGeometry
    public let start: EntranceCamera
    public let end: EntranceCamera
    public let startAngleDegrees: Double
    public let endElevationDegrees: Double
    public let endIoU: Double
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
                return Self.aim(position, toPut: tailCentre, at: li.tailPoint, lookingAt: .init(0, geometry.height * 0.5, 0), fov: fov, viewport: vp, shift: shift)
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
            let score = abs(n.point.y - noseTarget)
            if best == nil || score < best!.score { best = (camera, angle, score) }
        }
        // Fallback (never expected on supported screens): the steepest pose that keeps the tail on its point.
        let opening = best ?? (camera: Self.aim(.init(0, -6, 4), toPut: tailCentre, at: li.tailPoint, lookingAt: nose, fov: fov, viewport: vp, shift: shift),
                               angle: 56.0, score: Double.infinity)
        start = opening.camera
        startAngleDegrees = opening.angle

        // 4. End pose on the risen rocket: maximise the window / aperture overlap.
        let glass = geometry.glassVertices.map { EntranceVector($0.x, $0.y + Self.liftMetres, $0.z) }
        let centre = EntranceVector(geometry.glassCentre.x, geometry.glassCentre.y + Self.liftMetres, geometry.glassCentre.z)
        let apertureBounds = EntranceRect.bounds(polygon)
        let target = polygon
        var bestEnd: (camera: EntranceCamera, elevation: Double, iou: Double)?
        for elevation in stride(from: 20.0, through: 75.0, by: 2.5) {
            let e = elevation * Double.pi / 180
            let direction = EntranceVector(0, -sin(e), cos(e))
            for widthFactor in [1.0, 1.05, 1.1, 1.15, 1.2, 1.25, 1.3] {
                func cameraAt(_ d: Double) -> EntranceCamera {
                    Self.aim(centre + direction * d, toPut: centre, at: apertureBounds.centre, lookingAt: centre, fov: fov, viewport: vp, shift: shift)
                }
                var lo = 0.8, hi = 40.0
                for _ in 0..<30 {
                    let m = (lo + hi) / 2
                    if cameraAt(m).projectBounds(glass).width > widthFactor * apertureBounds.width { lo = m } else { hi = m }
                }
                let camera = cameraAt((lo + hi) / 2)
                let hull = Self.convexHull(glass.map { camera.project($0).point })
                let hb = EntranceRect.bounds(hull)
                // Small pitch changes translate the image vertically; search that offset on the hull, then aim exactly.
                for lift in stride(from: -50.0, through: 10.0, by: 10.0) {
                    let dy = apertureBounds.centre.y - hb.centre.y + lift
                    let moved = hull.map { EntrancePoint($0.x, $0.y + dy) }
                    let iou = Self.iou(moved, target, step: 6)
                    if bestEnd == nil || iou > bestEnd!.iou {
                        let aimed = Self.aim(camera.position, toPut: centre,
                                             at: .init(camera.project(centre).point.x, camera.project(centre).point.y + dy),
                                             lookingAt: centre, fov: fov, viewport: vp, shift: shift)
                        bestEnd = (aimed, elevation, iou)
                    }
                }
            }
        }
        end = bestEnd!.camera
        endElevationDegrees = bestEnd!.elevation
        endIoU = Self.iou(Self.convexHull(glass.map { bestEnd!.camera.project($0).point }), target, step: 2)
    }

    /// One continuous move: position along a straight smootherstep path, orientation slerped over the whole
    /// stage, constant field of view and one constant lens shift; the rocket rises one body length with the same easing.
    public func pose(at t: Double) -> LiftOffPose {
        let t = min(1, max(0, t)), u = EntranceEasing.smootherstep(t), rise = Self.liftMetres * u
        let camera = EntranceCamera(position: start.position.lerp(to: end.position, u),
                                    orientation: start.orientation.slerp(to: end.orientation, u),
                                    fovDegrees: input.fovDegrees, viewport: input.liftOff.viewport, shift: start.shift)
        let lift = { (p: EntranceVector) in EntranceVector(p.x, p.y + rise, p.z) }
        let tail = tailVertices.map(lift).map { camera.project($0) }
        return LiftOffPose(progress: t, camera: camera, rise: rise,
                           windowRect: camera.projectBounds(geometry.glassVertices.map(lift)),
                           tailRect: .bounds(tail.map(\.point)), tailInFront: tail.allSatisfy(\.inFront),
                           turnRemainingDegrees: camera.orientation.angle(to: end.orientation) * 180 / Double.pi)
    }

    public func facts(at t: Double) -> StoryboardPoseFacts {
        let pose = pose(at: t), camera = pose.camera, rise = pose.rise
        let nose = camera.project(.init(0, geometry.height + rise, 0)), base = camera.project(.init(0, TailLayout.plateY + rise, 0))
        let hull = Self.convexHull(geometry.glassVertices.map { camera.project(.init($0.x, $0.y + rise, $0.z)).point })
        return .init(noseY: nose.point.y, noseInFront: nose.inFront,
                     axisTiltDegrees: atan2(nose.point.x - base.point.x, base.point.y - nose.point.y) * 180 / Double.pi,
                     windowHull: hull, windowIoU: Self.iou(hull, aperturePolygon, step: 2))
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
