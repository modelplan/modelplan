// SPDX-License-Identifier: MIT
// Storyboard shot 3, lift-off and oblique approach (owner 2026-10-25): the tail starts at the handoff diameter
// under the cockpit, the camera travels forward/up along one smooth rail, stops turning at 70 % and never
// levels; the rocket rises 1.5 m and never rotates (nose up). Port of the reference `scene.js` camera code.
import Foundation

/// The rocket facts the camera needs. Model metres, +Y up, +Z canopy-facing, base at the origin.
public struct RocketGeometry: Equatable, Sendable, Codable {
    public var height: Double
    public var skirtRadius: Double
    /// Canopy glass vertices in model space (the reference uses every vertex of `curved_canopy_glass`).
    public var glassVertices: [EntranceVector]
    /// Height of the window anchor; the glass centre is the glass vertex nearest (x 0, this height).
    public var windowAnchorY: Double

    public init(height: Double, skirtRadius: Double, glassVertices: [EntranceVector], windowAnchorY: Double) {
        self.height = height; self.skirtRadius = skirtRadius; self.glassVertices = glassVertices; self.windowAnchorY = windowAnchorY
    }

    public var glassCentre: EntranceVector {
        glassVertices.min { a, b in
            a.x * a.x + (a.y - windowAnchorY) * (a.y - windowAnchorY) < b.x * b.x + (b.y - windowAnchorY) * (b.y - windowAnchorY)
        } ?? .init(0, windowAnchorY, 0)
    }

    /// Neutral stand-in (MIT, plain shapes) with the official model's outer dimensions: 14.2 m tall, 2.4 m skirt,
    /// a cylindrical canopy patch (r 0.96 m, ±0.74 rad, y 12.40...13.27 m). Used by self-builds and public CI.
    public static let neutralStandIn: RocketGeometry = {
        var glass: [EntranceVector] = []
        for j in 0..<StandIn.glassRows {
            for i in 0..<StandIn.glassColumns {
                let theta = -StandIn.glassHalfAngle + Double(i) * 2 * StandIn.glassHalfAngle / Double(StandIn.glassColumns - 1)
                let y = StandIn.glassBottom + Double(j) * (StandIn.glassTop - StandIn.glassBottom) / Double(StandIn.glassRows - 1)
                glass.append(.init(StandIn.glassRadius * sin(theta), y, StandIn.glassRadius * cos(theta)))
            }
        }
        return RocketGeometry(height: 14.2, skirtRadius: 1.2, glassVertices: glass, windowAnchorY: 12.835)
    }()

    public enum StandIn {
        public static let glassRadius = 0.96, glassHalfAngle = 0.74, glassBottom = 12.40, glassTop = 13.27
        public static let glassColumns = 9, glassRows = 5
    }
}

public struct LiftOffInput: Equatable, Sendable, Codable {
    /// Overlay viewport in points.
    public var viewport: EntranceSize
    /// Tail handoff diameter in points: 0.80 (or 0.78) × cockpit width.
    public var handoffDiameter: Double
    /// Tail point under the cockpit (centre of the projected tail ring at the start).
    public var tailPoint: EntrancePoint
    /// c01 clear aperture of the cockpit at its landing frame (or the closed cap on short screens).
    public var apertureRect: EntranceRect
    public var shortScreen: Bool
    public var menuBarHeight: Double

    public init(viewport: EntranceSize, handoffDiameter: Double, tailPoint: EntrancePoint, apertureRect: EntranceRect,
                shortScreen: Bool = false, menuBarHeight: Double = 26) {
        self.viewport = viewport; self.handoffDiameter = handoffDiameter; self.tailPoint = tailPoint
        self.apertureRect = apertureRect; self.shortScreen = shortScreen; self.menuBarHeight = menuBarHeight
    }
}

public struct LiftOffPose: Equatable, Sendable {
    public let progress: Double
    public let camera: EntranceCamera
    /// Metres the rocket has risen.
    public let rise: Double
    public let windowRect: EntranceRect
    public let tailRect: EntranceRect
    /// True when every tail ring sample is in front of the camera (tailRect is meaningful).
    public let tailInFront: Bool
    public let turnRemainingDegrees: Double
}

public struct LiftOffRail: Sendable {
    public static let startFov = 32.0, endFov = 50.0
    public static let startElevationDegrees = 37.0, startYawDegrees = 32.0
    public static let endElevationDegrees = 50.0, endYawDegrees = 4.0
    public static let riseMetres = 1.5
    /// The camera stops turning at this fraction of the stage.
    public static let turnStop = 0.70
    public static let tailRingRadius = 1.2
    public static let tailRingSamples = 256

    public let input: LiftOffInput
    public let geometry: RocketGeometry
    public let start: EntranceVector, end: EntranceVector, p1: EntranceVector, p2: EntranceVector
    public let startOrientation: EntranceQuaternion, endOrientation: EntranceQuaternion
    public let startDistance: Double, endDistance: Double
    public let initialWindowCentre: EntrancePoint, finalWindowCentre: EntrancePoint
    public let tailVertices: [EntranceVector]

    public init(input: LiftOffInput, geometry: RocketGeometry = .neutralStandIn) {
        self.input = input
        self.geometry = geometry
        let rad = Double.pi / 180, vp = input.viewport
        let tail = (0..<Self.tailRingSamples).map { i -> EntranceVector in
            let a = 2 * Double.pi * Double(i) / Double(Self.tailRingSamples)
            return .init(sin(a) * Self.tailRingRadius, TailLayout.plateY, cos(a) * Self.tailRingRadius)
        }
        tailVertices = tail
        let tailTarget = EntranceVector(0, TailLayout.plateY, 0)
        func look(_ eye: EntranceVector, _ target: EntranceVector, _ fov: Double) -> EntranceCamera {
            .init(position: eye, orientation: .lookAt(eye: eye, target: target), fovDegrees: fov, viewport: vp)
        }
        func startCamera(_ d: Double) -> EntranceVector {
            let e = Self.startElevationDegrees * rad, y = Self.startYawDegrees * rad
            return .init(d * sin(e) * sin(y), TailLayout.plateY - d * cos(e), d * sin(e) * cos(y))
        }
        var lo = 2.1, hi = 100.0
        for _ in 0..<60 {
            let m = (lo + hi) / 2
            if look(startCamera(m), tailTarget, Self.startFov).projectBounds(tail).width > input.handoffDiameter { lo = m } else { hi = m }
        }
        startDistance = (lo + hi) / 2
        let start = startCamera(startDistance)
        let glass = geometry.glassVertices, centre = geometry.glassCentre
        let e = Self.endElevationDegrees * rad, yaw = Self.endYawDegrees * rad
        let direction = EntranceVector(cos(e) * sin(yaw), -sin(e), cos(e) * cos(yaw))
        var dl = 1.05, dh = 30.0
        for _ in 0..<48 {
            let m = (dl + dh) / 2
            if look(centre + direction * m, centre, Self.endFov).projectBounds(glass).width > input.apertureRect.width { dl = m } else { dh = m }
        }
        endDistance = (dl + dh) / 2
        let end = centre + direction * endDistance
        let endViewHeight = look(end, centre, Self.endFov).projectBounds(glass).height

        let startView = look(start, tailTarget, Self.startFov)
        startOrientation = startView.orientation
        let tb = startView.projectBounds(tail)
        var shifted = startView
        shifted.shift = Self.shift(toCentre: input.tailPoint, from: tb, viewport: vp)
        initialWindowCentre = shifted.projectBounds(glass).centre
        let aperture = input.apertureRect
        finalWindowCentre = .init(aperture.centre.x,
                                  input.shortScreen ? input.menuBarHeight + 6 + endViewHeight / 2 : aperture.centre.y)
        endOrientation = look(end, centre, Self.endFov).orientation

        let handle = min(2, (start.z - end.z) * 0.4 / direction.z, (start.x - end.x) * 0.4 / direction.x)
        let p2 = end + direction * handle
        var p1 = start.lerp(to: end, 0.25)
        p1.y = start.y + (p2.y - start.y) * 0.35
        self.start = start; self.end = end; self.p1 = p1; self.p2 = p2
    }

    static func shift(toCentre target: EntrancePoint, from rect: EntranceRect, viewport: EntranceSize) -> EntrancePoint {
        .init((target.x - rect.centre.x) * 2 / viewport.width, -(target.y - rect.centre.y) * 2 / viewport.height)
    }

    func rail(_ u: Double) -> EntranceVector {
        let a = (1 - u) * (1 - u) * (1 - u), b = 3 * (1 - u) * (1 - u) * u, c = 3 * (1 - u) * u * u, d = u * u * u
        return start * a + p1 * b + p2 * c + end * d
    }

    /// Camera and projected facts at stage progress `t` (0...1).
    public func pose(at t: Double) -> LiftOffPose {
        let t = min(1, max(0, t))
        let u = EntranceEasing.smootherstep(t), rise = Self.riseMetres * u
        var position = rail(u)
        position.y += rise
        let orientation = startOrientation.slerp(to: endOrientation, EntranceEasing.smootherstep(min(1, t / Self.turnStop)))
        var camera = EntranceCamera(position: position, orientation: orientation,
                                    fovDegrees: Self.startFov + (Self.endFov - Self.startFov) * u, viewport: input.viewport)
        let lifted = { (points: [EntranceVector]) in points.map { EntranceVector($0.x, $0.y + rise, $0.z) } }
        let glass = lifted(geometry.glassVertices), tail = lifted(tailVertices)
        if t == 0 {
            camera.shift = Self.shift(toCentre: input.tailPoint, from: camera.projectBounds(tail), viewport: input.viewport)
        } else {
            let target = EntrancePoint(initialWindowCentre.x + (finalWindowCentre.x - initialWindowCentre.x) * u,
                                       initialWindowCentre.y + (finalWindowCentre.y - initialWindowCentre.y) * u)
            camera.shift = Self.shift(toCentre: target, from: camera.projectBounds(glass), viewport: input.viewport)
        }
        let tailProjected = tail.map { camera.project($0) }
        return LiftOffPose(progress: t, camera: camera, rise: rise, windowRect: camera.projectBounds(glass),
                           tailRect: .bounds(tailProjected.map(\.point)), tailInFront: tailProjected.allSatisfy(\.inFront),
                           turnRemainingDegrees: orientation.angle(to: endOrientation) * 180 / Double.pi)
    }
}
