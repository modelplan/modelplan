// SPDX-License-Identifier: MIT
// Thin RealityKit layer for the native entrance (CKP-ENT-04, macOS 15+). All timing, layout and camera numbers
// come from ModelPlanEntrance; this file only turns them into entities and renders frames offscreen.
// Slice 1 builds the neutral stand-in rocket (plain shapes, no official art); the official USDZ arrives with
// its own asset slice. Theme is a parameter from the start: it selects the finish and environment only.
#if canImport(RealityKit) && canImport(Metal)
import AppKit
import CoreGraphics
import Foundation
import Metal
import ModelPlanEntrance
import RealityKit
import simd

@available(macOS 15.0, *)
public enum EntrancePart: String, CaseIterable, Sendable {
    /// Body, nose and tail cylinders.
    case hull
    /// The canopy glass patch.
    case glass
    /// A disc of the tail ring's radius at the plate height (for projection checks).
    case tailRing
}

@available(macOS 15.0, *)
public struct EntranceRenderedFrame: @unchecked Sendable {
    public let image: CGImage
    public let facts: EntranceFrameFacts
}

@available(macOS 15.0, *)
@MainActor
public final class EntranceScene {
    public enum SceneError: Error { case noMetalDevice, textureAllocation, noImage, notA3DStage(EntranceStage) }

    public let plan: EntrancePlan
    public let parts: Set<EntrancePart>
    private let renderer: RealityRenderer
    private let device: MTLDevice
    private let stage = Entity()
    private let camera = PerspectiveCamera()

    /// - Parameters:
    ///   - parts: which parts to draw; tests isolate one part to compare its silhouette with the core's projection.
    ///   - flat: unlit flat materials (the reference's `look=grey`); false uses the theme finish (stand-in values).
    public init(plan: EntrancePlan, parts: Set<EntrancePart> = [.hull, .glass], flat: Bool = true) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw SceneError.noMetalDevice }
        self.device = device
        self.plan = plan
        self.parts = parts
        renderer = try RealityRenderer()
        let root = Entity()
        root.addChild(stage)
        StandInRocket.build(into: stage, tail: plan.tail, parts: parts, theme: plan.scenario.theme, flat: flat)
        renderer.entities.append(root)
        renderer.entities.append(camera)
        renderer.activeCamera = camera
    }

    /// Renders the frame at `t` seconds after ignition at 1 point = 1 pixel. Only the 3D stages (lift-off and
    /// the held end pose of the map) have a rocket; earlier stages are 2D overlay work.
    public func render(at t: Double) async throws -> EntranceRenderedFrame {
        let facts = plan.facts(at: t)
        guard let pose = facts.liftOff else { throw SceneError.notA3DStage(facts.stage) }
        stage.position = SIMD3<Float>(0, Float(pose.rise), 0)
        let plan = pose.camera.renderPlan
        camera.position = SIMD3<Float>(Float(pose.camera.position.x), Float(pose.camera.position.y), Float(pose.camera.position.z))
        let q = pose.camera.orientation
        camera.orientation = simd_quatf(ix: Float(q.x), iy: Float(q.y), iz: Float(q.z), r: Float(q.w))
        camera.camera.fieldOfViewInDegrees = Float(plan.canvasFovDegrees)
        camera.camera.near = Float(EntranceCamera.near)
        camera.camera.far = Float(EntranceCamera.far)

        let width = Int(plan.canvas.width.rounded(.up)), height = Int(plan.canvas.height.rounded(.up))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw SceneError.textureAllocation }
        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: output, onComplete: { _ in
                    continuation.resume()
                })
            } catch {
                continuation.resume(throwing: error)
            }
        }
        let full = try Self.image(from: texture, width: width, height: height)
        let crop = CGRect(x: plan.crop.x.rounded(), y: plan.crop.y.rounded(),
                          width: pose.camera.viewport.width.rounded(), height: pose.camera.viewport.height.rounded())
        guard let image = full.cropping(to: crop) else { throw SceneError.noImage }
        return EntranceRenderedFrame(image: image, facts: facts)
    }

    private static func image(from texture: MTLTexture, width: Int, height: Int) throws -> CGImage {
        let rowBytes = width * 4
        var bytes = [UInt8](repeating: 0, count: rowBytes * height)
        bytes.withUnsafeMutableBytes { buffer in
            texture.getBytes(buffer.baseAddress!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info, provider: provider,
                                  decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw SceneError.noImage }
        return image
    }
}

/// Neutral procedural rocket (MIT): plain cylinders and a cone with the official model's outer dimensions and
/// the stand-in canopy patch of `RocketGeometry.neutralStandIn`. It deliberately does not imitate the official finish.
@available(macOS 15.0, *)
@MainActor
enum StandInRocket {
    static func build(into stage: Entity, tail: [TailSlot], parts: Set<EntrancePart>, theme: EntranceTheme, flat: Bool) {
        let hull: any RealityKit.Material, dark: any RealityKit.Material, glass: any RealityKit.Material
        if flat {
            // The reference grey box: flat untextured greys, no lights.
            hull = UnlitMaterial(color: .init(white: 0x8e / 255.0, alpha: 1))
            dark = UnlitMaterial(color: .init(white: 0x30 / 255.0, alpha: 1))
            glass = UnlitMaterial(color: .init(white: 0x44 / 255.0, alpha: 1))
        } else {
            let base: CGFloat = theme == .night ? 0.22 : 0.78
            var metal = PhysicallyBasedMaterial()
            metal.baseColor = .init(tint: .init(white: base, alpha: 1))
            metal.metallic = 0.85
            metal.roughness = theme == .night ? 0.45 : 0.35
            hull = metal
            dark = UnlitMaterial(color: .init(white: 0x10 / 255.0, alpha: 1))
            glass = UnlitMaterial(color: .init(white: 0.08, alpha: 1))
        }
        if parts.contains(.hull) {
            func cylinder(_ radius: Float, _ from: Float, _ to: Float) {
                let e = ModelEntity(mesh: .generateCylinder(height: to - from, radius: radius), materials: [hull])
                e.position = [0, (from + to) / 2, 0]
                stage.addChild(e)
            }
            cylinder(1.2, 0.5, 10.5)
            cylinder(1.0, 10.5, 12.2)
            cylinder(0.95, 12.2, 13.4)
            let nose = ModelEntity(mesh: .generateCone(height: 0.8, radius: 0.95), materials: [hull])
            nose.position = [0, 13.8, 0]
            stage.addChild(nose)
            let plate = ModelEntity(mesh: .generateCylinder(height: 0.26, radius: Float(TailLayout.plateRadius)), materials: [hull])
            plate.position = [0, Float(TailLayout.plateY) + 0.13, 0]
            stage.addChild(plate)
            for slot in tail {
                let bell = ModelEntity(mesh: .generateCylinder(height: 0.38, radius: Float(slot.radius)), materials: [hull])
                bell.position = [Float(slot.x), 0.02 - 0.19, Float(slot.z)]
                bell.name = "entry-bell-\(slot.index)"
                stage.addChild(bell)
                let mouth = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: Float(slot.radius) * 0.92), materials: [dark])
                mouth.position = [Float(slot.x), -0.381, Float(slot.z)]
                stage.addChild(mouth)
            }
        }
        if parts.contains(.glass), let mesh = try? glassMesh() {
            let e = ModelEntity(mesh: mesh, materials: [glass])
            e.name = "canopy-glass"
            stage.addChild(e)
        }
        if parts.contains(.tailRing) {
            let ring = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: Float(LiftOffRail.tailRingRadius)),
                                   materials: [UnlitMaterial(color: .white)])
            ring.position = [0, Float(TailLayout.plateY), 0]
            ring.name = "tail-ring"
            stage.addChild(ring)
        }
    }

    /// The stand-in canopy as a grid mesh over exactly the vertices the camera rail projects.
    static func glassMesh() throws -> MeshResource {
        let g = RocketGeometry.neutralStandIn, columns = RocketGeometry.StandIn.glassColumns, rows = RocketGeometry.StandIn.glassRows
        // r 0.96 m: the patch sits just proud of the 0.95 m capsule.
        let positions: [SIMD3<Float>] = g.glassVertices.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
        var indices: [UInt32] = []
        for j in 0..<(rows - 1) {
            for i in 0..<(columns - 1) {
                let a = UInt32(j * columns + i), b = a + 1, c = a + UInt32(columns), d = c + 1
                indices += [a, b, d, a, d, c, a, d, b, a, c, d]  // both faces
            }
        }
        var descriptor = MeshDescriptor(name: "canopy-glass")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
#endif
