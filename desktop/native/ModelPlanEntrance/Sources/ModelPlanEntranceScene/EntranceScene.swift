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
            try ModelRocket.build(into: stage, url: url, tail: plan.tail, parts: parts, flat: flat, theme: plan.scenario.theme)
        } else {
            StandInRocket.build(into: stage, tail: plan.tail, parts: parts, theme: plan.scenario.theme, flat: flat)
        }
        if parts.contains(.tailRing), rocket.modelURL(for: plan.scenario.theme) != nil {
            StandInRocket.build(into: stage, tail: [], parts: [.tailRing], theme: plan.scenario.theme, flat: true)
        }
        if !flat {
            // Look mode: a top-left sun like the reference studio key, plus warm firelight from the base. On the
            // metal finish the sun only adds a narrow glint; the image-based light carries the look.
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

    static func build(into stage: Entity, url: URL, tail: [TailSlot], parts: Set<EntrancePart>, flat: Bool,
                      theme: EntranceTheme) throws {
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
        if flat {
            forEachModel(body) { e in
                guard var model = e.components[ModelComponent.self] else { return }
                let level = greyLevel(partName(e))
                model.materials = model.materials.map { _ in
                    var m = UnlitMaterial(color: .init(white: level / 255, alpha: 1))
                    m.faceCulling = .none
                    return m
                }
                e.components.set(model)
            }
        } else {
            try HullFinish(theme).dress(body)
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
                try HullFinish(theme).dress(bell)
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

/// The model file's look-mode finish: one approved model, two finishes (owner 2026-10-24: night graphite gunmetal,
/// day satin aluminium), drawn as smooth polished metal like the approved pass-5 reference art.
///
/// The model's own hull material reads as foam in RealityKit: its roughness and metallic come from a texture whose
/// USD scale (roughness x 0.5) the import does not appear to apply, so the hull renders at roughness ~0.88; the
/// normal map's 0.16 strength is likewise lost and its grain shows at full strength. Here the hull keeps the albedo
/// atlas (panel lines, hatches) as the metal's colour and gets fixed metal values; the joint rings lose their
/// near-black ink look; every mesh gets smooth vertex normals (`SmoothNormals`).
@available(macOS 15.0, *)
@MainActor
struct HullFinish {
    let theme: EntranceTheme
    init(_ theme: EntranceTheme) { self.theme = theme }

    /// The textured outer hull sections.
    static let hullParts: Set<String> = ["aft_skirt", "lower_stage", "long_slanted_interstage", "slender_upper_body",
                                         "capsule_aperture_shell", "capsule_lower", "capsule_nose"]

    /// Ring joints, their edges, the axial seams and the dark canopy gasket: near-black in the file.
    static func isJoint(_ name: String) -> Bool {
        name.hasPrefix("panel_joint_") || name.hasPrefix("joint_edge_") || name.hasPrefix("axial_panel_seam_")
            || name == "canopy_frame_bevel_0" || name == "canopy_frame_bevel_2"
    }

    /// The bells' outer wall and throat collar: white chrome in the file, the hull finish here.
    static func isBellMetal(_ name: String) -> Bool {
        name.hasPrefix("P1_outer_wall_") || name.hasPrefix("P1_throat_collar_")
    }

    /// Height of the 2 cm `panel_joint_*` rings, as a fraction (their local z is the rocket axis). Thinner and
    /// lighter seams, not heavy black lines. Look mode only; the grey box keeps the file's rings.
    static let jointThickness: Float = 0.45

    /// Roughness of the hull metal: satin, low enough to carry the studio strips as soft highlight bands.
    var roughness: Float { theme == .night ? 0.30 : 0.34 }
    /// A thin glossy layer over the metal: a crisp copy of the strips on top of the soft band.
    var clearcoat: Float { theme == .night ? 0.35 : 0.2 }
    /// Multiplies the albedo atlas (night ~0.36, day ~0.71 in sRGB) to give the metal colour.
    var tint: NSColor {
        theme == .night ? NSColor(srgbRed: 0.97, green: 0.98, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 1.0, green: 1.0, blue: 0.985, alpha: 1)
    }
    /// The finish as a flat colour (bells, and the hull if its material is not a PBR).
    var plainColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.36, green: 0.365, blue: 0.375, alpha: 1)
            : NSColor(srgbRed: 0.72, green: 0.72, blue: 0.71, alpha: 1)
    }
    /// Joints: darker than the hull, never ink black.
    var jointColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.22, green: 0.225, blue: 0.235, alpha: 1)
            : NSColor(srgbRed: 0.42, green: 0.42, blue: 0.41, alpha: 1)
    }

    func metal(_ color: NSColor, roughness: Float) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.metallic = 1.0
        m.roughness = .init(floatLiteral: roughness)
        m.clearcoat = .init(floatLiteral: clearcoat)
        m.clearcoatRoughness = 0.06
        m.faceCulling = .none
        return m
    }

    /// Materials, normals and joint thickness for everything under `root` (the model, or one cloned bell).
    func dress(_ root: Entity) throws {
        var models: [Entity] = []
        ModelRocket.forEachModel(root) { models.append($0) }
        for e in models {
            guard var model = e.components[ModelComponent.self] else { continue }
            if ModelRocket.isGlass(e) {
                // Owner D116: the canopy is real glass, not the model's flat grey.
                let glass = CanopyGlass.material()
                model.materials = model.materials.map { _ in glass }
                e.components.set(model)
                continue
            }
            let name = ModelRocket.partName(e)
            model.materials = model.materials.map { material -> any RealityKit.Material in
                if Self.hullParts.contains(name) {
                    guard var pbr = material as? PhysicallyBasedMaterial else { return metal(plainColor, roughness: roughness) }
                    pbr.baseColor.tint = tint
                    pbr.metallic = 1.0
                    pbr.roughness = .init(floatLiteral: roughness)
                    pbr.normal.texture = nil
                    pbr.clearcoat = .init(floatLiteral: clearcoat)
                    pbr.clearcoatRoughness = 0.06
                    pbr.faceCulling = .none
                    return pbr
                }
                if Self.isJoint(name) { return metal(jointColor, roughness: 0.45) }
                if Self.isBellMetal(name) { return metal(plainColor, roughness: roughness + 0.02) }
                guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                pbr.faceCulling = .none
                return pbr
            }
            model.mesh = try SmoothNormals.mesh(model.mesh)
            e.components.set(model)
        }
        func thin(_ e: Entity) {
            if e.name.hasPrefix("panel_joint_") {
                e.scale = SIMD3<Float>(e.scale.x, e.scale.y, e.scale.z * Self.jointThickness)
                return
            }
            e.children.forEach(thin)
        }
        thin(root)
    }
}

/// Smooth vertex normals for a model file's meshes. The brand rocket's LOD1 normals do not match its vertices:
/// on the 24-sided hull they sit 2.5-7.5 degrees off the radial direction, twist between the bottom and top rows
/// of a section, and jump 15 degrees at the texture seam that faces the camera (the hard vertical light/dark
/// line). Recomputed here from the triangles: vertices at the same position share one normal (the seam closes),
/// faces meeting at more than `creaseDegrees` keep a hard edge. Tangents follow the new normals.
@available(macOS 15.0, *)
@MainActor
enum SmoothNormals {
    static let creaseDegrees: Float = 50

    static func mesh(_ mesh: MeshResource) throws -> MeshResource {
        var contents = mesh.contents
        var models: [MeshResource.Model] = []
        for var model in contents.models {
            model.parts = MeshPartCollection(model.parts.map { smoothed($0) })
            models.append(model)
        }
        contents.models = MeshModelCollection(models)
        return try MeshResource.generate(from: contents)
    }

    static func smoothed(_ part: MeshResource.Part) -> MeshResource.Part {
        guard let triangles = part.triangleIndices?.elements, triangles.count >= 3 else { return part }
        let positions = part.positions.elements
        guard !positions.isEmpty, triangles.allSatisfy({ Int($0) < positions.count }) else { return part }
        let given = part.normals?.elements
        let original = given?.count == positions.count ? given : nil
        // Weld by position (0.1 mm) so the duplicated vertices along a texture seam share one normal.
        var slots: [SIMD3<Int32>: Int] = [:]
        let weld: [Int] = positions.map { p in
            let key = SIMD3<Int32>(p * 10_000, rounding: .toNearestOrAwayFromZero)
            if let slot = slots[key] { return slot }
            slots[key] = slots.count
            return slots.count - 1
        }
        // Unit face normals, weighted by the face's corner angle at the vertex: a quad then counts the same however
        // it is split into triangles (area weights tilt the normal toward the side with two triangles).
        var faceNormals: [SIMD3<Float>] = []
        var cornersAt = [[(face: Int, weight: Float)]](repeating: [], count: slots.count)
        var ownFaces = [[Int]](repeating: [], count: positions.count)
        for f in 0..<(triangles.count / 3) {
            let corners = [Int(triangles[3 * f]), Int(triangles[3 * f + 1]), Int(triangles[3 * f + 2])]
            let a = positions[corners[0]], b = positions[corners[1]], c = positions[corners[2]]
            var n = cross(b - a, c - a)
            if length(n) > 0 { n = normalize(n) }
            if let original, dot(n, original[corners[0]] + original[corners[1]] + original[corners[2]]) < 0 { n = -n }
            faceNormals.append(n)
            for k in 0..<3 {
                let v = corners[k], p = positions[v]
                let e1 = positions[corners[(k + 1) % 3]] - p, e2 = positions[corners[(k + 2) % 3]] - p
                let l = length(e1) * length(e2)
                let angle = l > 0 ? acos(max(-1, min(1, dot(e1, e2) / l))) : 0
                cornersAt[weld[v]].append((face: f, weight: angle))
                ownFaces[v].append(f)
            }
        }
        let crease = cos(creaseDegrees * .pi / 180)
        var normals = [SIMD3<Float>](repeating: [0, 1, 0], count: positions.count)
        for v in 0..<positions.count {
            var reference = ownFaces[v].reduce(SIMD3<Float>.zero) { $0 + faceNormals[$1] }
            if let original, length(original[v]) > 0 { reference = original[v] }
            guard length(reference) > 0 else { continue }
            reference = normalize(reference)
            var sum = SIMD3<Float>.zero
            for corner in cornersAt[weld[v]] {
                let n = faceNormals[corner.face]
                if dot(n, reference) >= crease { sum += n * corner.weight }
            }
            normals[v] = length(sum) > 0 ? normalize(sum) : reference
        }
        var result = part
        result.normals = MeshBuffers.Normals(normals)
        if let uvs = part.textureCoordinates?.elements, uvs.count == positions.count {
            var tu = [SIMD3<Float>](repeating: .zero, count: positions.count), tv = tu
            for f in 0..<(triangles.count / 3) {
                let a = Int(triangles[3 * f]), b = Int(triangles[3 * f + 1]), c = Int(triangles[3 * f + 2])
                let e1 = positions[b] - positions[a], e2 = positions[c] - positions[a]
                let d1 = uvs[b] - uvs[a], d2 = uvs[c] - uvs[a]
                let det = d1.x * d2.y - d2.x * d1.y
                guard abs(det) > 1e-12 else { continue }
                let t = (e1 * d2.y - e2 * d1.y) / det, s = (e2 * d1.x - e1 * d2.x) / det
                for v in [a, b, c] { tu[v] += t; tv[v] += s }
            }
            var tangents: [SIMD3<Float>] = [], bitangents: [SIMD3<Float>] = []
            for v in 0..<positions.count {
                let n = normals[v]
                var t = tu[v] - n * dot(n, tu[v])
                if length(t) < 1e-8 { t = cross(abs(n.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0), n) }
                t = normalize(t)
                var b = cross(n, t)
                if dot(b, tv[v]) < 0 { b = -b }
                tangents.append(t)
                bitangents.append(b)
            }
            result.tangents = MeshBuffers.Tangents(tangents)
            result.bitangents = MeshBuffers.Tangents(bitangents)
        }
        return result
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

/// Code-drawn look settings (no art files). Both themes are black space (owner D116): there is no sky and the
/// studio is never drawn, only reflected. Metal looks like metal when it has something to reflect, so the studio is
/// dark with tall soft-edged light strips; on the 24-sided hull they become long vertical highlight bands, as in
/// the approved pass-5 art.
public enum EntranceLook {
    /// The directional sun, top left. Day has twice the night sun. On the metal it only adds a narrow glint (the
    /// earlier 12000 lux day sun blew the lit side out to white).
    public static func sunIntensity(_ theme: EntranceTheme) -> Float { theme == .day ? 3000 : 1500 }

    /// Image-based light exponent for `EntranceScene.setEnvironment(_:intensityExponent:)`. The studio's brightest
    /// strip is 1.0, so the strips reach 2^exponent: about 5.7 at night (dark gunmetal, albedo ~0.1, needs bright
    /// strips to show its bands) and 2 by day (aluminium, albedo ~0.45, would clip higher).
    public static func environmentExponent(_ theme: EntranceTheme) -> Float { theme == .day ? 1.0 : 2.5 }

    /// Equirectangular studio, 512 x 256, sRGB-encoded linear light. Dark room (night) or a light grey one (day:
    /// satin aluminium needs light to be light), a faint horizon band, and three tall soft strips: the key at upper
    /// left (azimuth -50), a dim fill (+30) and a narrow rim (+125). Image-based light only; it is never drawn.
    public static func studio(_ theme: EntranceTheme = .night) -> CGImage? {
        let w = 512, h = 256
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data
        else { return nil }
        let day = theme == .day
        let floor = day ? 0.16 : 0.015, wall = day ? 0.30 : 0.04, ceiling = day ? 0.5 : 0.16, horizon = day ? 0.1 : 0.05
        let p = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        // A tall strip centred at azimuth `centre`, `half` degrees wide, from elevation `low` to `high`, with soft
        // edges (a hard edge reflects as a sharp line down a metal cylinder).
        func strip(_ az: Double, _ e: Double, centre: Double, half: Double, low: Double, high: Double) -> Double {
            let da = abs((az - centre + 540).truncatingRemainder(dividingBy: 360) - 180)
            let fx = max(0, 1 - max(0, da - half) / 12)
            let fy = max(0, 1 - max(0, low - e, e - high) / 15)
            return fx * fx * (3 - 2 * fx) * fy * fy * (3 - 2 * fy)
        }
        for y in 0..<h {
            let e = 90 - 180 * (Double(y) + 0.5) / Double(h)
            for x in 0..<w {
                let az = 360 * (Double(x) + 0.5) / Double(w) - 180
                let s = sin(max(0, e) * Double.pi / 180)
                var v = e >= 0 ? wall + (ceiling - wall) * s * s : floor + (wall - floor) * max(0, 1 + e / 25)
                v += horizon * exp(-(e / 8) * (e / 8))
                v = max(v, strip(az, e, centre: -50, half: 10, low: -25, high: 80))
                v = max(v, 0.3 * strip(az, e, centre: 30, half: 5, low: -10, high: 70))
                v = max(v, 0.85 * strip(az, e, centre: 125, half: 4, low: -15, high: 75))
                let linear = min(1, v)
                let encoded = linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1 / 2.4) - 0.055
                let o = (y * w + x) * 4
                let level = UInt8((encoded * 255).rounded())
                p[o] = level; p[o + 1] = level; p[o + 2] = level; p[o + 3] = 255
            }
        }
        return context.makeImage()
    }
}
#endif
