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
    private var sky: ModelEntity?

    /// - Parameters:
    ///   - parts: which parts to draw; tests isolate one part to compare its silhouette with the core's projection.
    ///   - flat: unlit flat materials (the reference's `look=grey`); false uses the theme finish (stand-in values).
    ///   - rocket: the stand-in, or a model file (the official edition's brand rocket). Build the plan with
    ///     `rocket.geometry` so the camera frames the rocket that is drawn.
    ///   - capsuleDetail: look mode with a model file only: crisp panel lines and fine grain on the capsule
    ///     (asset audit option A), for the close-up at the end of the approach.
    public init(plan: EntrancePlan, parts: Set<EntrancePart> = [.hull, .glass], flat: Bool = true,
                rocket: RocketModelSource = .communityDefault, capsuleDetail: Bool = false) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw SceneError.noMetalDevice }
        self.device = device
        self.plan = plan
        self.parts = parts
        renderer = try RealityRenderer()
        root.addChild(stage)
        if let url = rocket.modelURL(for: plan.scenario.theme) {
            try ModelRocket.build(into: stage, url: url, tail: plan.tail, parts: parts, flat: flat,
                                  capsuleDetail: capsuleDetail && !flat, geometry: rocket.geometry)
        } else {
            StandInRocket.build(into: stage, tail: plan.tail, parts: parts, theme: plan.scenario.theme, flat: flat)
        }
        if parts.contains(.tailRing), rocket.modelURL(for: plan.scenario.theme) != nil {
            StandInRocket.build(into: stage, tail: [], parts: [.tailRing], theme: plan.scenario.theme, flat: true)
        }
        if !flat {
            // Look mode: a top-left key light like the reference studio rig, plus warm firelight from the base.
            let key = DirectionalLight()
            key.light.intensity = plan.scenario.theme == .night ? 3000 : 6000
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

    /// A world-fixed sky dome behind everything, coloured by elevation from a vertical strip image (top row =
    /// zenith, middle row = horizon, bottom row = nadir). It follows the camera position, so only pitch moves it.
    public func setSky(_ strip: CGImage) async throws {
        let texture = try TextureResource.generate(from: strip, options: .init(semantic: .color))
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        let dome = ModelEntity(mesh: try SkyDome.mesh(radius: Float(EntranceCamera.far) * 0.8), materials: [material])
        dome.name = "sky-dome"
        sky?.removeFromParent()
        root.addChild(dome)
        sky = dome
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
        sky?.position = camera.position

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
/// bells; look mode keeps the model's own materials and clones `engine_0` for each bell.
@available(macOS 15.0, *)
@MainActor
enum ModelRocket {
    static let glassName = "curved_canopy_glass"
    static let capsuleParts = ["capsule_lower", "capsule_aperture_shell", "capsule_nose"]

    static func hidden(_ name: String) -> Bool {
        if name == "T2_continuous_aft_face" || name.hasPrefix("T2_internal_seam_") { return true }
        guard name.hasPrefix("engine_"), let n = Int(name.dropFirst("engine_".count)) else { return false }
        return (0...6).contains(n)
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

    static func build(into stage: Entity, url: URL, tail: [TailSlot], parts: Set<EntrancePart>, flat: Bool,
                      capsuleDetail: Bool, geometry: RocketGeometry) throws {
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
            if flat {
                let level = greyLevel(partName(e))
                model.materials = model.materials.map { _ in
                    var m = UnlitMaterial(color: .init(white: level / 255, alpha: 1))
                    m.faceCulling = .none
                    return m
                }
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
        if capsuleDetail { try CapsuleDetail.add(to: body, stage: stage, geometry: geometry) }
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

/// Asset audit option A for the capsule close-up: the capsule's own texture is about 144 texels per metre, which
/// looks soft at the end pose. A thin overlay skin (the capsule's own triangles, 1.5 mm proud) carries crisp
/// panel lines and a fine grain from a code-generated 2048 x 1024 map in cylindrical coordinates, so the official
/// albedo stays underneath and nothing new is drawn by hand.
@available(macOS 15.0, *)
@MainActor
enum CapsuleDetail {
    static let offset: Float = 0.0015
    static let lineWidthMetres = 0.006

    struct Skin { var positions: [SIMD3<Float>] = []; var normals: [SIMD3<Float>] = []; var indices: [UInt32] = [] }

    static func add(to body: Entity, stage: Entity, geometry: RocketGeometry) throws {
        var skin = Skin()
        var bands: [Float] = []
        for name in ModelRocket.capsuleParts {
            guard let part = body.findEntity(named: name) else { continue }
            var minY = Float.infinity, maxY = -Float.infinity
            ModelRocket.forEachModel(part) { e in
                guard let model = e.components[ModelComponent.self] else { return }
                let m = e.transformMatrix(relativeTo: stage)
                for meshModel in model.mesh.contents.models {
                    for p in meshModel.parts {
                        guard let tris = p.triangleIndices?.elements else { continue }
                        let base = UInt32(skin.positions.count)
                        let normals = p.normals?.elements
                        for (k, v) in p.positions.elements.enumerated() {
                            let w = m * SIMD4<Float>(v, 1)
                            var n = normals.map { m * SIMD4<Float>($0[k], 0) }.map { SIMD3<Float>($0.x, $0.y, $0.z) }
                                ?? SIMD3<Float>(w.x, 0, w.z)
                            if simd_length(n) < 1e-6 { n = [0, 1, 0] }
                            n = simd_normalize(n)
                            skin.positions.append(SIMD3<Float>(w.x, w.y, w.z) + n * offset)
                            skin.normals.append(n)
                            minY = min(minY, w.y); maxY = max(maxY, w.y)
                        }
                        skin.indices += tris.map { $0 + base }
                    }
                }
            }
            if minY.isFinite { bands += [minY, maxY] }
        }
        guard !skin.positions.isEmpty, let low = bands.min(), let high = bands.max(), high > low else { return }
        // Panel joints: every part boundary below the very top, plus one joint halfway up the lowest part.
        var joints = Set(bands.filter { $0 > low + 0.01 && $0 < high - 0.05 }.map { ($0 * 100).rounded() / 100 })
        if let second = bands.sorted().dropFirst().first(where: { $0 > low + 0.2 }) { joints.insert((low + second) / 2) }
        // Axial seams every 30 degrees, kept clear of the canopy (its azimuth range plus a margin).
        let glassAngles = geometry.glassVertices.map { atan2($0.x, $0.z) * 180 / Double.pi }
        let glassHalf = (glassAngles.map(abs).max() ?? 40) + 8
        let seams = stride(from: 15.0, to: 360.0, by: 30.0).map { $0 > 180 ? $0 - 360 : $0 }.filter { abs($0) > glassHalf }
        var uvs: [SIMD2<Float>] = []
        for p in skin.positions {
            let u = (atan2(p.x, p.z) + Float.pi) / (2 * Float.pi)
            uvs.append([u, (p.y - low) / (high - low)])
        }
        let maps = try detailMaps(height: Double(high - low), joints: joints.map { Double(($0 - low) / (high - low)) },
                                  seams: seams.map { ($0 + 180) / 360 })
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white, texture: .init(try TextureResource.generate(from: maps.colour, options: .init(semantic: .color))))
        material.blending = .transparent(opacity: .init(scale: 1, texture: .init(try TextureResource.generate(from: maps.opacity, options: .init(semantic: .raw)))))
        material.metallic = 0.3
        material.roughness = 0.6
        var descriptor = MeshDescriptor(name: "capsule-detail")
        descriptor.positions = MeshBuffers.Positions(skin.positions)
        descriptor.normals = MeshBuffers.Normals(skin.normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(skin.indices)
        let overlay = ModelEntity(mesh: try MeshResource.generate(from: [descriptor]), materials: [material])
        overlay.name = "capsule-detail"
        stage.addChild(overlay)
    }

    /// Colour and opacity maps, u around the capsule (0 = back), v up the capsule (row 0 = bottom, as texture
    /// coordinates read). Lines are near-black at 85 % opacity; the grain is faint deterministic light/dark specks.
    static func detailMaps(height: Double, joints: [Double], seams: [Double], width: Int = 2048,
                           rows: Int = 1024) throws -> (colour: CGImage, opacity: CGImage) {
        func context(_ space: CGColorSpace, _ bytes: Int, _ info: UInt32) -> CGContext? {
            CGContext(data: nil, width: width, height: rows, bitsPerComponent: 8, bytesPerRow: width * bytes, space: space, bitmapInfo: info)
        }
        guard let colour = context(CGColorSpace(name: CGColorSpace.sRGB)!, 4, CGImageAlphaInfo.noneSkipLast.rawValue),
              let opacity = context(CGColorSpaceCreateDeviceGray(), 1, CGImageAlphaInfo.none.rawValue),
              let c = colour.data?.bindMemory(to: UInt8.self, capacity: width * rows * 4),
              let o = opacity.data?.bindMemory(to: UInt8.self, capacity: width * rows)
        else { throw EntranceScene.SceneError.noImage }
        var seed: UInt32 = 0x9e3779b9
        for i in 0..<(width * rows) {
            seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
            let level: UInt8 = seed & 0x1000 != 0 ? 216 : 18
            c[i * 4] = level; c[i * 4 + 1] = level; c[i * 4 + 2] = level; c[i * 4 + 3] = 255
            o[i] = UInt8(seed % 18)
        }
        // CG's origin is bottom-left: y = v * rows draws at texture coordinate v.
        let circumference = 2 * Double.pi * 0.95
        for (ctx, ink) in [(colour, CGColor(srgbRed: 0.03, green: 0.03, blue: 0.035, alpha: 1)), (opacity, CGColor(gray: 0.85, alpha: 1))] {
            ctx.setStrokeColor(ink)
            ctx.setLineCap(.butt)
            ctx.setLineWidth(max(1.5, lineWidthMetres / height * Double(rows)))
            for v in joints {
                ctx.move(to: CGPoint(x: 0, y: v * Double(rows))); ctx.addLine(to: CGPoint(x: Double(width), y: v * Double(rows)))
            }
            ctx.strokePath()
            ctx.setLineWidth(max(1.5, lineWidthMetres / circumference * Double(width)))
            for u in seams {
                ctx.move(to: CGPoint(x: u * Double(width), y: 0)); ctx.addLine(to: CGPoint(x: u * Double(width), y: Double(rows)))
            }
            ctx.strokePath()
        }
        guard let colourImage = colour.makeImage(), let opacityImage = opacity.makeImage() else { throw EntranceScene.SceneError.noImage }
        return (colourImage, opacityImage)
    }
}

/// An inward-facing sphere whose texture coordinate v follows elevation (v 1 = zenith), for `setSky`.
@available(macOS 15.0, *)
@MainActor
enum SkyDome {
    static func mesh(radius: Float, rings: Int = 64, sectors: Int = 64) throws -> MeshResource {
        var positions: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = []
        for j in 0...rings {
            let elevation = Float.pi / 2 - Float.pi * Float(j) / Float(rings)
            for i in 0...sectors {
                let a = 2 * Float.pi * Float(i) / Float(sectors)
                positions.append([cos(elevation) * sin(a) * radius, sin(elevation) * radius, cos(elevation) * cos(a) * radius])
                uvs.append([Float(i) / Float(sectors), 1 - Float(j) / Float(rings)])
            }
        }
        var indices: [UInt32] = []
        let row = UInt32(sectors + 1)
        for j in 0..<UInt32(rings) {
            for i in 0..<UInt32(sectors) {
                let a = j * row + i, b = a + 1, c = a + row, d = c + 1
                indices += [a, b, d, a, d, c, a, d, b, a, c, d]  // both faces
            }
        }
        var descriptor = MeshDescriptor(name: "sky-dome")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

/// Code-drawn environment images (no art files): the day-sky trial strip and a provisional neutral studio for
/// image-based lighting until the look pass bakes the reference room.
public enum EntranceLookImages {
    /// Vertical strip, row 0 = zenith, middle = horizon, last row = nadir.
    public static func daySkyStrip(rows: Int = 512) -> CGImage? {
        // Elevation (degrees) -> sRGB: deep zenith blue, pale hazy horizon, muted ground.
        let stops: [(Double, (Double, Double, Double))] = [
            (90, (0.16, 0.38, 0.70)), (45, (0.30, 0.55, 0.84)), (15, (0.56, 0.74, 0.92)),
            (2, (0.80, 0.88, 0.95)), (0, (0.86, 0.90, 0.93)), (-5, (0.55, 0.58, 0.60)), (-90, (0.30, 0.31, 0.32)),
        ]
        return strip(rows: rows) { e in
            for k in 1..<stops.count where e >= stops[k].0 {
                let (e0, c0) = stops[k - 1], (e1, c1) = stops[k], f = (e - e1) / (e0 - e1)
                return (c1.0 + (c0.0 - c1.0) * f, c1.1 + (c0.1 - c1.1) * f, c1.2 + (c0.2 - c1.2) * f)
            }
            return stops.last!.1
        }
    }

    /// Equirectangular studio, 512 x 256: soft bright ceiling, two softboxes (key at upper left, rim at right),
    /// darker floor; `day` cools it slightly.
    public static func studio(day: Bool) -> CGImage? {
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
                let r = day ? v * 0.95 : v, g = day ? v * 0.98 : v, b = day ? min(1, v * 1.06) : v
                let o = (y * w + x) * 4
                p[o] = UInt8(r * 255); p[o + 1] = UInt8(g * 255); p[o + 2] = UInt8(b * 255); p[o + 3] = 255
            }
        }
        return context.makeImage()
    }

    static func strip(rows: Int, colour: (Double) -> (Double, Double, Double)) -> CGImage? {
        let w = 4
        guard let context = CGContext(data: nil, width: w, height: rows, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data
        else { return nil }
        let p = data.bindMemory(to: UInt8.self, capacity: w * rows * 4)
        for y in 0..<rows {
            let (r, g, b) = colour(90 - 180 * (Double(y) + 0.5) / Double(rows))
            for x in 0..<w {
                let o = (y * w + x) * 4
                p[o] = UInt8(r * 255); p[o + 1] = UInt8(g * 255); p[o + 2] = UInt8(b * 255); p[o + 3] = 255
            }
        }
        return context.makeImage()
    }
}
#endif
