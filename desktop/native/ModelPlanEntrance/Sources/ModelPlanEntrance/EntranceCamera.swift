// SPDX-License-Identifier: MIT
// A perspective camera with a lens shift, matching the web reference (Three.js PerspectiveCamera with a
// projection-matrix translation, no geometry stretch). RealityKit has no lens-shift parameter, so the scene
// renders a larger unshifted canvas and crops it (`renderPlan`); a lens shift is exactly a 2D image translation.
import Foundation

public struct EntranceCamera: Equatable, Sendable, Codable {
    public var position: EntranceVector
    public var orientation: EntranceQuaternion
    /// Vertical field of view in degrees.
    public var fovDegrees: Double
    /// Output viewport in points.
    public var viewport: EntranceSize
    /// Lens shift in normalised device coordinates (+x right, +y up).
    public var shift: EntrancePoint

    public init(position: EntranceVector, orientation: EntranceQuaternion, fovDegrees: Double, viewport: EntranceSize,
                shift: EntrancePoint = .init(0, 0)) {
        self.position = position; self.orientation = orientation; self.fovDegrees = fovDegrees
        self.viewport = viewport; self.shift = shift
    }

    public static let near = 0.01, far = 1000.0

    public struct Projected: Equatable, Sendable {
        public let point: EntrancePoint
        /// True when the point is in front of the camera (camera-space z < 0).
        public let inFront: Bool
    }

    /// Projects a world point to viewport points (top-left origin, y down), as Three.js `Vector3.project`.
    /// Points behind the camera produce the same (meaningless) values as the reference; check `inFront`.
    public func project(_ world: EntranceVector) -> Projected {
        let c = orientation.conjugate.rotate(world - position)
        let f = 1 / tan(fovDegrees * Double.pi / 360), aspect = viewport.width / viewport.height
        let w = -c.z
        let nx = (f / aspect) * c.x / w + shift.x, ny = f * c.y / w + shift.y
        return .init(point: .init((nx + 1) * viewport.width / 2, (1 - ny) * viewport.height / 2), inFront: c.z < 0)
    }

    public func projectBounds(_ points: [EntranceVector]) -> EntranceRect {
        .bounds(points.map { project($0).point })
    }

    /// Forward direction (local −Z) in world space.
    public var forward: EntranceVector { orientation.rotate(.init(0, 0, -1)) }
    public var pitchDegrees: Double { asin(max(-1, min(1, forward.y))) * 180 / Double.pi }

    /// How a renderer without lens shift reproduces this camera: render `canvas` with `canvasFovDegrees`
    /// (same focal length), then copy the viewport-sized rect at `crop` (top-left origin).
    public struct RenderPlan: Equatable, Sendable {
        public let canvas: EntranceSize
        public let canvasFovDegrees: Double
        public let crop: EntrancePoint
    }

    public var renderPlan: RenderPlan {
        let dx = shift.x * viewport.width / 2, dy = -shift.y * viewport.height / 2
        let canvas = EntranceSize(width: viewport.width + 2 * abs(dx), height: viewport.height + 2 * abs(dy))
        let focal = viewport.height / 2 / tan(fovDegrees * Double.pi / 360)
        let fov = 2 * atan(canvas.height / 2 / focal) * 180 / Double.pi
        return .init(canvas: canvas, canvasFovDegrees: fov, crop: .init(abs(dx) - dx, abs(dy) - dy))
    }
}
