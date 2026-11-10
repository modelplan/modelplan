// SPDX-License-Identifier: MIT
// Thin RealityKit layer for the native entrance (CKP-ENT-04, macOS 15+). All timing, layout and camera numbers
// come from ModelPlanEntrance; this file only turns them into entities and renders frames offscreen.
// The rocket comes from a RocketModelSource: the neutral stand-in (plain shapes, MIT) or a model file the
// official edition passes in (slice 4). This file never names the official pack; it only loads the URL it is given.
// Theme is a parameter from the start: it selects the finish and environment only.
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
    private let root = Entity()
    private let stage = Entity()
    private let camera = PerspectiveCamera()

    /// Both themes are black space (owner D116): nothing is drawn behind the rocket, and day differs from night
    /// only by a stronger sun (`EntranceLook.sunIntensity`).
    ///
    /// - Parameters:
    ///   - parts: which parts to draw; tests isolate one part to compare its silhouette with the core's projection.
    ///   - flat: unlit flat materials (the reference's `look=grey`); false uses the theme finish (stand-in values).
    ///   - rocket: the stand-in, or a model file (the official edition's brand rocket). Build the plan with
    ///     `rocket.geometry` so the camera frames the rocket that is drawn.
    public init(plan: EntrancePlan, parts: Set<EntrancePart> = [.hull, .glass], flat: Bool = true,
                rocket: RocketModelSource = .communityDefault) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw SceneError.noMetalDevice }
        self.device = device
        self.plan = plan
        self.parts = parts
        renderer = try RealityRenderer()
        root.addChild(stage)
        if let url = rocket.modelURL(for: plan.scenario.theme) {
            try ModelRocket.build(into: stage, url: url, tail: plan.tail, parts: parts, flat: flat)
        } else {
            StandInRocket.build(into: stage, tail: plan.tail, parts: parts, theme: plan.scenario.theme, flat: flat)
        }
        if parts.contains(.tailRing), rocket.modelURL(for: plan.scenario.theme) != nil {
            StandInRocket.build(into: stage, tail: [], parts: [.tailRing], theme: plan.scenario.theme, flat: true)
        }
        if !flat {
            // Look mode: a top-left sun like the reference studio key, plus warm firelight from the base.
            let key = DirectionalLight()
            key.light.intensity = EntranceLook.sunIntensity(plan.scenario.theme)
            key.look(at: [0, 7, 0], from: [-8, 15, 10], relativeTo: nil)
            root.addChild(key)
            let fire = PointLight()
            fire.light.color = .init(red: 1, green: 0.59, blue: 0.25, alpha: 1)
            fire.light.intensity = 40000
            fire.light.attenuationRadius = 11.5
            fire.position = [-2.4, -0.8, 3.8]
            stage.addChild(fire)
        }
        renderer.entities.append(root)
        renderer.entities.append(camera)
        renderer.activeCamera = camera
    }

    /// Look mode: image-based lighting from an equirectangular image (top row = zenith) for every model in the
    /// scene. Without it, metal finishes render nearly black under the two lights alone.
    public func setEnvironment(_ equirectangular: CGImage, intensityExponent: Float = 0) async throws {
        let environment = try await EnvironmentResource(equirectangular: equirectangular)
        root.components.set(ImageBasedLightComponent(source: .single(environment), intensityExponent: intensityExponent))
        func receive(_ e: Entity) {
            if e.components.has(ModelComponent.self) { e.components.set(ImageBasedLightReceiverComponent(imageBasedLight: root)) }
            e.children.forEach(receive)
        }
        receive(stage)
    }

    /// The first entity with this name in the rocket stage, for material and part checks.
    public func entity(named name: String) -> Entity? { stage.findEntity(named: name) }

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
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
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
                bell.position = [Float(slot.x), Float(0.02 - 0.19), Float(slot.z)]
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
/// A rocket from a model file (the official edition passes the brand rocket's USDZ). Treated as the web reference
/// treats the model: its fixed engines and aft face are hidden, and the entrance adds one bell per tail slot and
/// a tail plate with a hole for each. Flat mode uses the reference grey box (`look=grey`) colours and its simple
/// bells; look mode keeps the model's own materials (the canopy becomes `CanopyGlass`) and clones `engine_0` for
/// each bell.
@available(macOS 15.0, *)
@MainActor
enum ModelRocket {
    static let glassName = "curved_canopy_glass"

    static func hidden(_ name: String) -> Bool {
        if name == "T2_continuous_aft_face" || name.hasPrefix("T2_internal_seam_") { return true }
        guard name.hasPrefix("engine_"), let n = Int(name.dropFirst("engine_".count)) else { return false }
        return (0...6).contains(n)
    }

    /// Whether `e` is the canopy glass or a mesh under it.
    static func isGlass(_ e: Entity) -> Bool {
        var node: Entity? = e
        while let n = node {
            if n.name == glassName { return true }
            node = n.parent
        }
        return false
    }

    /// The reference grey box colours by part name.
    static func greyLevel(_ name: String) -> CGFloat {
        if name.range(of: "glass|screen|display", options: .regularExpression) != nil { return 0x44 }
        if name.contains("bevel") { return 0xaa }
        if name.range(of: "seam|lining|inner", options: .regularExpression) != nil { return 0x55 }
        return 0x8e
    }

    /// The nearest named entity at or above `e` (a mesh may sit on an unnamed child of its USD prim).
    static func partName(_ e: Entity) -> String {
        var node: Entity? = e
        while let n = node {
            if !n.name.isEmpty, n.name != "Geometry" { return n.name }
            node = n.parent
        }
        return ""
    }

    static func forEachModel(_ e: Entity, _ body: (Entity) -> Void) {
        if e.components.has(ModelComponent.self) { body(e) }
        for child in e.children { forEachModel(child, body) }
    }

    static func build(into stage: Entity, url: URL, tail: [TailSlot], parts: Set<EntrancePart>, flat: Bool) throws {
        let loaded = try Entity.load(contentsOf: url)
        // Use the model itself, not the file's scene root: the root may carry AR anchoring, which an offscreen
        // renderer never resolves.
        let body = loaded.findEntity(named: "modelplan_rocket_LOD1") ?? loaded
        body.removeFromParent()
        func clearAnchors(_ e: Entity) { e.components.remove(AnchoringComponent.self); e.children.forEach(clearAnchors) }
        clearAnchors(body)
        stage.addChild(body)
        let template = body.findEntity(named: "engine_0")?.clone(recursive: true)
        func visit(_ e: Entity) {
            if hidden(e.name) { e.isEnabled = false; return }
            e.children.forEach(visit)
        }
        visit(body)
        if !parts.contains(.glass) { body.findEntity(named: glassName)?.isEnabled = false }
        if !parts.contains(.hull) {
            for child in body.children where child.name != glassName { child.isEnabled = false }
        }
        // Both faces, as the reference draws the model (DoubleSide): with the aft face hidden, the plate holes look
        // into the hull, whose inside must not cull away to the background.
        forEachModel(body) { e in
            guard var model = e.components[ModelComponent.self] else { return }
            let name = partName(e)
            if flat {
                let level = greyLevel(name)
                model.materials = model.materials.map { _ in
                    var m = UnlitMaterial(color: .init(white: level / 255, alpha: 1))
                    m.faceCulling = .none
                    return m
                }
            } else if isGlass(e) {
                // Owner D116: the canopy is real glass, not the model's flat grey.
                let glass = CanopyGlass.material()
                model.materials = model.materials.map { _ in glass }
            } else {
                model.materials = model.materials.map { material -> any RealityKit.Material in
                    guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                    pbr.faceCulling = .none
                    return pbr
                }
            }
            e.components.set(model)
        }
        guard parts.contains(.hull) else { return }
        let engines = Entity()
        engines.name = "entry-engines"
        stage.addChild(engines)
        for slot in tail {
            if flat || template == nil {
                // The reference grey box bell: an open cylinder and a dark mouth disc.
                let grey = UnlitMaterial(color: .init(white: 0x8e / 255.0, alpha: 1))
                let bell = ModelEntity(mesh: .generateCylinder(height: 0.38, radius: Float(slot.radius)), materials: [grey])
                bell.position = [Float(slot.x), Float(0.02 - 0.19), Float(slot.z)]
                bell.name = "entry-bell-\(slot.index)"
                engines.addChild(bell)
                let mouth = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: Float(slot.radius) * 0.92),
                                        materials: [UnlitMaterial(color: .init(white: 0x30 / 255.0, alpha: 1))])
                mouth.position = [Float(slot.x), -0.381, Float(slot.z)]
                engines.addChild(mouth)
            } else if let template {
                let bell = template.clone(recursive: true)
                bell.isEnabled = true
                bell.name = "entry-bell-\(slot.index)"
                bell.position = [Float(slot.x), -0.394, Float(slot.z)]
                bell.scale = [Float(slot.radius / 0.293), 0.78, Float(slot.radius / 0.293)]
                engines.addChild(bell)
            }
        }
        let plateMaterial: any RealityKit.Material
        if flat {
            plateMaterial = UnlitMaterial(color: .init(white: 0x77 / 255.0, alpha: 1))
        } else {
            var m = PhysicallyBasedMaterial()
            m.baseColor = .init(tint: .init(red: 0x24 / 255.0, green: 0x25 / 255.0, blue: 0x29 / 255.0, alpha: 1))
            m.metallic = 0.45
            m.roughness = 0.75
            plateMaterial = m
        }
        let plate = ModelEntity(mesh: try TailPlate.mesh(tail: tail), materials: [plateMaterial])
        plate.name = "entry-tail-plate"
        plate.position = [0, Float(TailLayout.plateY), 0]
        engines.addChild(plate)
    }
}

/// The tail plate (r 1.17 m) with a hole of 0.8 x the bell radius for every slot, both faces.
@available(macOS 15.0, *)
@MainActor
enum TailPlate {
    static func mesh(tail: [TailSlot], rings: Int = 48, sectors: Int = 192) throws -> MeshResource {
        let outer = Float(TailLayout.plateRadius)
        var positions: [SIMD3<Float>] = []
        for j in 0...rings {
            let r = outer * Float(j) / Float(rings)
            for i in 0..<sectors {
                let a = 2 * Float.pi * Float(i) / Float(sectors)
                positions.append([sin(a) * r, 0, cos(a) * r])
            }
        }
        func inHole(_ p: SIMD3<Float>) -> Bool {
            tail.contains { s in
                let dx = p.x - Float(s.x), dz = p.z - Float(s.z)
                return dx * dx + dz * dz < Float(s.radius * 0.8 * s.radius * 0.8)
            }
        }
        var indices: [UInt32] = []
        for j in 0..<rings {
            for i in 0..<sectors {
                let a = UInt32(j * sectors + i), b = UInt32(j * sectors + (i + 1) % sectors)
                let c = a + UInt32(sectors), d = b + UInt32(sectors)
                let centre = (positions[Int(a)] + positions[Int(b)] + positions[Int(c)] + positions[Int(d)]) / 4
                if inHole(centre) { continue }
                indices += [a, c, d, a, d, b, a, d, c, a, b, d]
            }
        }
        var descriptor = MeshDescriptor(name: "entry-tail-plate")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(positions.map { _ in SIMD3<Float>(0, -1, 0) })
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

/// The canopy glass in look mode (owner D116): a clear, dark-tinted, glossy sheet. Clearcoat with a near-zero
/// roughness carries the image-based light as crisp reflections, and partial opacity lets the dim capsule interior
/// read through it. RealityKit has no transmission term, so see-through is opacity blending.
@available(macOS 15.0, *)
@MainActor
enum CanopyGlass {
    static let opacity: Float = 0.42

    static func material() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .init(srgbRed: 0.035, green: 0.045, blue: 0.06, alpha: 1))
        m.metallic = 0.0
        m.roughness = 0.05
        m.specular = 1.0
        m.clearcoat = 1.0
        m.clearcoatRoughness = 0.02
        m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        m.faceCulling = .none
        return m
    }
}

/// Code-drawn look settings (no art files). Both themes are black space (owner D116): there is no sky; day is
/// the same studio light with a stronger sun.
public enum EntranceLook {
    /// The directional sun, top left. Day is four times night; nothing else changes with the theme.
    public static func sunIntensity(_ theme: EntranceTheme) -> Float { theme == .day ? 12000 : 3000 }

    /// Image-based light exponent for `EntranceScene.setEnvironment(_:intensityExponent:)`, the same for both themes.
    public static let environmentExponent: Float = -0.5

    /// Equirectangular studio, 512 x 256: soft bright ceiling, two softboxes (key at upper left, rim at right),
    /// darker floor. Image-based light only (reflections on the hull and the canopy glass); it is never drawn.
    public static func studio() -> CGImage? {
        let w = 512, h = 256
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data
        else { return nil }
        let p = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        for y in 0..<h {
            let e = 90 - 180 * (Double(y) + 0.5) / Double(h)
            for x in 0..<w {
                let az = 360 * (Double(x) + 0.5) / Double(w) - 180
                var v = e >= 0 ? 0.32 + 0.38 * sin(e * Double.pi / 180) : 0.12 + 0.08 * (1 + e / 90)
                // Soft-edged boxes: a hard edge reflects as a sharp line down a metal cylinder.
                func box(_ da: Double, _ de: Double, _ half: (Double, Double)) -> Double {
                    let fx = max(0, 1 - max(0, abs(da) - half.0) / 25), fy = max(0, 1 - max(0, abs(de) - half.1) / 20)
                    return fx * fx * (3 - 2 * fx) * fy * fy * (3 - 2 * fy)
                }
                v = max(v, box(az + 50, e - 40, (10, 8)))
                v = max(v, 0.8 * box(az - 120, e - 20, (4, 10)))
                let o = (y * w + x) * 4
                let level = UInt8(min(1, v) * 255)
                p[o] = level; p[o + 1] = level; p[o + 2] = level; p[o + 3] = 255
            }
        }
        return context.makeImage()
    }
}
#endif
