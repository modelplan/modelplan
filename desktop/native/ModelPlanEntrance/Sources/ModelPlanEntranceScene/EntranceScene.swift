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
import ImageIO
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
    /// Which hull albedo look mode uses: "cleaned WxH" (D132: the file's atlas with grime and baked shading
    /// removed, panel lines kept), "file" (the atlas as shipped) or "none" (stand-in or grey box).
    public private(set) var hullAlbedo = "none"

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
            hullAlbedo = try ModelRocket.build(into: stage, url: url, tail: plan.tail, parts: parts, flat: flat, theme: plan.scenario.theme)
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
        // The model file's canopy glass reflects its own dark environment (round 3: no white chrome).
        var glassLight: Entity?
        if stage.findEntity(named: ModelRocket.glassName) != nil, let image = EntranceLook.glassStudio() {
            let light = root.findEntity(named: "entry-glass-light") ?? Entity()
            light.name = "entry-glass-light"
            let glass = try await EnvironmentResource(equirectangular: image)
            light.components.set(ImageBasedLightComponent(source: .single(glass),
                                                          intensityExponent: EntranceLook.glassEnvironmentExponent(plan.scenario.theme)))
            if light.parent == nil { root.addChild(light) }
            glassLight = light
        }
        let glassSource = glassLight
        func receive(_ e: Entity) {
            if e.components.has(ModelComponent.self) {
                let source = glassSource.flatMap { ModelRocket.isGlass(e) ? $0 : nil } ?? root
                e.components.set(ImageBasedLightReceiverComponent(imageBasedLight: source))
            }
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
        return EntranceRenderedFrame(image: try await render(camera: pose.camera, rise: pose.rise), facts: facts)
    }

    /// Renders one frame from any camera with the rocket risen by `rise` metres (owner boards: the front-window
    /// close-up beside the pass-5 window still, D132).
    public func render(camera view: EntranceCamera, rise: Double) async throws -> CGImage {
        stage.position = SIMD3<Float>(0, Float(rise), 0)
        let plan = view.renderPlan
        camera.position = SIMD3<Float>(Float(view.position.x), Float(view.position.y), Float(view.position.z))
        let q = view.orientation
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
                          width: view.viewport.width.rounded(), height: view.viewport.height.rounded())
        guard let image = full.cropping(to: crop) else { throw SceneError.noImage }
        return image
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

    /// Builds the model into `stage`; returns which hull albedo look mode uses (see `EntranceScene.hullAlbedo`).
    @discardableResult
    static func build(into stage: Entity, url: URL, tail: [TailSlot], parts: Set<EntrancePart>, flat: Bool,
                      theme: EntranceTheme) throws -> String {
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
        }
        var albedo = "none"
        var finish = HullFinish(theme)
        if !flat {
            if let clean = CleanAtlas.texture(modelURL: url) {
                finish.albedo = clean.texture
                albedo = "cleaned \(clean.width)x\(clean.height)"
            } else {
                albedo = "file"
            }
            try finish.dress(body)
        }
        guard parts.contains(.hull) else { return albedo }
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
                try finish.dress(bell)
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
        return albedo
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
/// atlas (panel lines, hatches) as the metal's colour and gets fixed metal values; every mesh gets smooth vertex
/// normals (`SmoothNormals`). Round 3 (owner 11-10): joints and the window surround become hairlines
/// (`JointLine`, `GasketFrame`), the hull is rounded to 96 sides (`RoundHull`), and the cockpit shows faintly
/// through the glass (`CockpitInterior`).
@available(macOS 15.0, *)
@MainActor
struct HullFinish {
    let theme: EntranceTheme
    /// D132: the cleaned hull albedo (`CleanAtlas`); nil keeps the file's atlas.
    var albedo: TextureResource?
    init(_ theme: EntranceTheme) { self.theme = theme }

    /// The textured outer hull sections.
    static let hullParts: Set<String> = ["aft_skirt", "lower_stage", "long_slanted_interstage", "slender_upper_body",
                                         "capsule_aperture_shell", "capsule_lower", "capsule_nose"]

    /// The axial seams: thin strips along the body, near-black in the file. They keep their geometry and take the
    /// groove colour.
    static func isAxialSeam(_ name: String) -> Bool { name.hasPrefix("axial_panel_seam_") }

    /// The proud 2 cm torus rings at the section joints. Seen from below at a metre or two they were the thick black
    /// arcs (owner 11-10, round 2), so look mode hides them and draws each joint from its `joint_edge_*` ring
    /// instead: a hairline groove with a light lip above it (`JointLine`).
    static func isPanelJoint(_ name: String) -> Bool { name.hasPrefix("panel_joint_") }
    static func isJointEdge(_ name: String) -> Bool { name.hasPrefix("joint_edge_") }

    /// The bells' outer wall and throat collar: white chrome in the file, the hull finish here.
    static func isBellMetal(_ name: String) -> Bool {
        name.hasPrefix("P1_outer_wall_") || name.hasPrefix("P1_throat_collar_")
    }

    /// Roughness of the hull metal: satin, low enough to carry the studio strips as soft highlight bands.
    var roughness: Float { theme == .night ? 0.30 : 0.34 }
    /// A thin glossy layer over the metal: a crisp copy of the strips on top of the soft band.
    var clearcoat: Float { theme == .night ? 0.35 : 0.2 }
    /// Multiplies the albedo atlas (night ~0.36, day ~0.71 in sRGB) to give the metal colour.
    var tint: NSColor {
        theme == .night ? NSColor(srgbRed: 0.97, green: 0.98, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 1.0, green: 1.0, blue: 0.985, alpha: 1)
    }
    /// The finish as a flat colour (bells, the window surround, and the hull if its material is not a PBR).
    var plainColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.36, green: 0.365, blue: 0.375, alpha: 1)
            : NSColor(srgbRed: 0.72, green: 0.72, blue: 0.71, alpha: 1)
    }
    /// Seam grooves (joint lines, axial seams, the outer line of the window surround): a dark-grey groove, never
    /// ink black, so it reads as a cut in the metal rather than a drawn line.
    var grooveColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.12, green: 0.122, blue: 0.13, alpha: 1)
            : NSColor(srgbRed: 0.30, green: 0.30, blue: 0.295, alpha: 1)
    }
    /// The light lip beside each groove: polished, lighter than the hull, so it catches the studio strip as a
    /// faint bright edge like the pass-5 art.
    var lipColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.62, green: 0.625, blue: 0.64, alpha: 1)
            : NSColor(srgbRed: 0.88, green: 0.88, blue: 0.87, alpha: 1)
    }
    /// The canopy gasket: dark grey with a soft sheen (rubber-like, not metal), not black.
    var gasketColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.075, green: 0.078, blue: 0.085, alpha: 1)
            : NSColor(srgbRed: 0.14, green: 0.14, blue: 0.145, alpha: 1)
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

    /// The window surround: a light satin dielectric, not metal. Seen from below, the surround faces down and, as
    /// metal, mirrored the dark studio floor, so at night it read as part of a heavy dark band (round 3).
    var surround: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: lipColor)
        m.metallic = 0.0
        m.roughness = 0.35
        m.clearcoat = 0.4
        m.clearcoatRoughness = 0.08
        m.faceCulling = .none
        return m
    }

    var gasket: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: gasketColor)
        m.metallic = 0.0
        m.roughness = 0.38
        m.clearcoat = 0.5
        m.clearcoatRoughness = 0.12
        m.faceCulling = .none
        return m
    }

    /// Materials, geometry and normals for everything under `root` (the model, or one cloned bell).
    func dress(_ root: Entity) throws {
        // The window surround first: it reshapes three meshes together, before they are rounded and smoothed.
        try GasketFrame.reshape(in: root)
        var models: [Entity] = []
        ModelRocket.forEachModel(root) { models.append($0) }
        for e in models where e.isEnabledInHierarchy {
            guard var model = e.components[ModelComponent.self] else { continue }
            let name = ModelRocket.partName(e)
            if Self.isPanelJoint(name) {
                // The named ring entity, not only the mesh entity under it (round 3 disabled only the child).
                var node: Entity? = e
                while let n = node, n.name != name { node = n.parent }
                (node ?? e).isEnabled = false
                continue
            }
            if CockpitInterior.isInterior(name) {
                CockpitInterior.dress(e, name: name)
                continue
            }
            let round = RoundHull.applies(to: name)
            if ModelRocket.isGlass(e) {
                // Owner D116: the canopy is real glass, not the model's flat grey.
                let glass = CanopyGlass.material()
                model.materials = model.materials.map { _ in glass }
                if round { model.mesh = try RoundHull.mesh(model.mesh, entity: e, root: root) }
                model.mesh = try SmoothNormals.mesh(model.mesh)
                e.components.set(model)
                continue
            }
            model.materials = model.materials.map { material -> any RealityKit.Material in
                if Self.hullParts.contains(name) {
                    guard var pbr = material as? PhysicallyBasedMaterial else { return metal(plainColor, roughness: roughness) }
                    if let albedo {
                        pbr.baseColor = .init(tint: tint, texture: .init(albedo))
                    } else {
                        pbr.baseColor.tint = tint
                    }
                    pbr.metallic = 1.0
                    pbr.roughness = .init(floatLiteral: roughness)
                    pbr.normal.texture = nil
                    pbr.clearcoat = .init(floatLiteral: clearcoat)
                    pbr.clearcoatRoughness = 0.06
                    pbr.faceCulling = .none
                    return pbr
                }
                if Self.isJointEdge(name) || Self.isAxialSeam(name) { return metal(grooveColor, roughness: 0.5) }
                if let frame = GasketFrame.role(name) {
                    switch frame {
                    case .outerLine: return metal(grooveColor, roughness: 0.5)
                    case .surround: return surround
                    case .gasket: return gasket
                    }
                }
                if Self.isBellMetal(name) { return metal(plainColor, roughness: roughness + 0.02) }
                guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                pbr.faceCulling = .none
                return pbr
            }
            if round { model.mesh = try RoundHull.mesh(model.mesh, entity: e, root: root) }
            model.mesh = try SmoothNormals.mesh(model.mesh)
            e.components.set(model)
        }
        JointLine.draw(in: root, lip: metal(lipColor, roughness: 0.16))
        if let plane = root.findEntity(named: CockpitInterior.screenPlane), plane.isEnabledInHierarchy {
            try CockpitCeiling.add(to: root)
        }
    }
}

/// Each section joint as a hairline (owner 11-10, round 2: "why are the seams so big"). The file's joint is a
/// proud 2 cm torus (hidden in look mode) plus a 6 mm `joint_edge_*` ring 17 mm above it. Here the edge ring moves
/// down onto the joint, is cut to `grooveHeight` and keeps the dark groove colour; a copy of it, `lipHeight` tall,
/// sits directly above as the light lip. At the end pose (about 850 px per metre on the capsule) the groove is
/// about 2 px and the lip 1 px, like the pass-5 reference.
@available(macOS 15.0, *)
@MainActor
enum JointLine {
    /// Groove height in metres (the edge ring is 6 mm in the file).
    static let grooveHeight: Float = 0.0021
    /// Lip height in metres, directly above the groove.
    static let lipHeight: Float = 0.0012
    /// The file's `joint_edge_*` ring height.
    static let fileEdgeHeight: Float = 0.006

    static func draw(in root: Entity, lip: PhysicallyBasedMaterial) {
        var edges: [Entity] = []
        func find(_ e: Entity) {
            if HullFinish.isJointEdge(e.name) { edges.append(e); return }
            e.children.forEach(find)
        }
        find(root)
        for edge in edges {
            guard let parent = edge.parent else { continue }
            // Onto the joint itself (the section boundary), not 17 mm above it.
            let suffix = String(edge.name.dropFirst("joint_edge_".count))
            if let joint = parent.children.first(where: { $0.name == "panel_joint_" + suffix }) {
                edge.position.y = joint.position.y
            }
            // The ring's local z is the rocket axis (it is rotated 90 degrees about x).
            let base = edge.scale
            edge.scale = SIMD3<Float>(base.x, base.y, base.z * grooveHeight / fileEdgeHeight)
            let copy = edge.clone(recursive: true)
            copy.name = "joint_lip_" + suffix
            copy.scale = SIMD3<Float>(base.x, base.y, base.z * lipHeight / fileEdgeHeight)
            copy.position.y = edge.position.y + (grooveHeight + lipHeight) / 2
            ModelRocket.forEachModel(copy) { e in
                guard var model = e.components[ModelComponent.self] else { return }
                model.materials = model.materials.map { _ in lip }
                e.components.set(model)
            }
            parent.addChild(copy)
        }
    }
}

/// The window surround (owner 11-10, round 2: "the seam around the window is very wide"). The file draws it as
/// three nested strips of about 3.5 cm each between the hull opening and the glass: dark, light, dark, so about
/// 10 cm of near-black frame. The pass-5 art has a hairline groove, a metal rim and a thin dark rounded gasket.
/// The outer and inner edges stay where they are (the hull opening and the glass edge); the two inner boundaries
/// move along each cross-section so the outer strip becomes the groove (`outerLine` of the width), the middle
/// strip the metal surround, and the inner strip the gasket (`gasket` of the width, about 1 cm).
@available(macOS 15.0, *)
@MainActor
enum GasketFrame {
    enum Role { case outerLine, surround, gasket }
    static let names = ["canopy_frame_bevel_0", "canopy_frame_bevel_1", "canopy_frame_bevel_2"]
    /// Width fractions from the hull opening to the glass edge.
    static let outerLine: Float = 0.04
    static let gasket: Float = 0.10

    static func role(_ name: String) -> Role? {
        switch name {
        case names[0]: return .outerLine
        case names[1]: return .surround
        case names[2]: return .gasket
        default: return nil
        }
    }

    static func key(_ p: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>(p * 10_000, rounding: .toNearestOrAwayFromZero) }

    /// Moves the shared edges between the three strips. Leaves the meshes alone if they do not have the expected
    /// shape (three strips sharing two edge loops).
    static func reshape(in root: Entity) throws {
        let strips = names.map { root.findEntity(named: $0) }
        guard strips.allSatisfy({ $0 != nil }) else { return }
        // Every model entity of each strip, with its positions in root space.
        var meshes: [[(entity: Entity, model: ModelComponent)]] = [[], [], []]
        var points: [Set<SIMD3<Int32>>] = [[], [], []]
        var at: [SIMD3<Int32>: SIMD3<Float>] = [:]
        for (k, strip) in strips.enumerated() {
            ModelRocket.forEachModel(strip!) { e in
                guard let model = e.components[ModelComponent.self] else { return }
                meshes[k].append((e, model))
                for part in model.mesh.contents.models.flatMap({ Array($0.parts) }) {
                    for p in part.positions.elements {
                        let q = e.convert(position: p, to: root)
                        points[k].insert(key(q))
                        at[key(q)] = q
                    }
                }
            }
        }
        let loop1 = points[0].intersection(points[1]), loop2 = points[1].intersection(points[2])
        let loop0 = points[0].subtracting(loop1), loop3 = points[2].subtracting(loop2)
        guard !loop0.isEmpty, loop0.count == loop1.count, loop1.count == loop2.count, loop2.count == loop3.count else { return }
        let l1 = loop1.compactMap { at[$0] }, l2 = loop2.compactMap { at[$0] }, l3 = loop3.compactMap { at[$0] }
        func nearest(_ p: SIMD3<Float>, _ loop: [SIMD3<Float>]) -> SIMD3<Float> {
            loop.min { simd_distance($0, p) < simd_distance($1, p) }!
        }
        // Each cross-section is the polyline hull opening -> edge 1 -> edge 2 -> glass edge; loop points are 9 cm
        // or more apart along the window and the strips are 2-5 cm wide, so the nearest point is the partner.
        var moved: [SIMD3<Int32>: SIMD3<Float>] = [:]
        for o in loop0.compactMap({ at[$0] }) {
            let p1 = nearest(o, l1), p2 = nearest(p1, l2), p3 = nearest(p2, l3)
            let polyline = [o, p1, p2, p3]
            var lengths: [Float] = [0]
            for i in 1..<4 { lengths.append(lengths[i - 1] + simd_distance(polyline[i - 1], polyline[i])) }
            func along(_ f: Float) -> SIMD3<Float> {
                let s = f * lengths[3]
                for i in 1..<4 where s <= lengths[i] || i == 3 {
                    let span = lengths[i] - lengths[i - 1]
                    let t = span > 0 ? (s - lengths[i - 1]) / span : 0
                    return polyline[i - 1] + (polyline[i] - polyline[i - 1]) * min(1, max(0, t))
                }
                return p3
            }
            moved[key(p1)] = along(outerLine)
            moved[key(p2)] = along(1 - gasket)
        }
        for strip in meshes {
            for (e, model) in strip {
                var contents = model.mesh.contents
                var models: [MeshResource.Model] = []
                for var m in contents.models {
                    m.parts = MeshPartCollection(m.parts.map { (original: MeshResource.Part) -> MeshResource.Part in
                        var part = original
                        let positions = part.positions.elements.map { p -> SIMD3<Float> in
                            guard let to = moved[key(e.convert(position: p, to: root))] else { return p }
                            return e.convert(position: to, from: root)
                        }
                        part.positions = MeshBuffers.Positions(positions)
                        return part
                    })
                    models.append(m)
                }
                contents.models = MeshModelCollection(models)
                var updated = model
                updated.mesh = try MeshResource.generate(from: contents)
                e.components.set(updated)
            }
        }
    }
}

/// Round hull sections (owner 11-10, round 2: "the arc seam still looks polygonal"). The LOD1 file is 24-sided.
/// Every triangle of a part that is a surface of revolution is split `steps` x `steps` and each new vertex is put
/// back on the round surface: its distance from the rocket axis is interpolated from the corners' distances, its
/// angle and height stay linear. With 4 steps the hull, joints, glass and window surround are 96-sided; with the
/// recomputed smooth normals (`SmoothNormals`) neither the silhouette nor the joint arcs show corners. Look mode
/// only: the grey box, its pose gates and the D111 overlap check keep the file's geometry (and its hashes).
@available(macOS 15.0, *)
@MainActor
enum RoundHull {
    static let steps = 4

    /// Parts that are surfaces of revolution about their root's y axis (the rocket, or one bell).
    static func applies(to name: String) -> Bool {
        HullFinish.hullParts.contains(name) || name == "aft_skirt_inner_return" || HullFinish.isJointEdge(name)
            || name == ModelRocket.glassName || GasketFrame.role(name) != nil || name.hasPrefix("P1_")
    }

    static func mesh(_ mesh: MeshResource, entity: Entity, root: Entity) throws -> MeshResource {
        // The axis in the mesh's own space: the root's y axis through the root's origin.
        let origin = entity.convert(position: .zero, from: root)
        let axis = normalize(entity.convert(direction: [0, 1, 0], from: root))
        var contents = mesh.contents
        var models: [MeshResource.Model] = []
        for var model in contents.models {
            model.parts = MeshPartCollection(model.parts.map { subdivided($0, origin: origin, axis: axis, steps: RoundHull.steps) })
            models.append(model)
        }
        contents.models = MeshModelCollection(models)
        return try MeshResource.generate(from: contents)
    }

    static func subdivided(_ part: MeshResource.Part, origin: SIMD3<Float>, axis: SIMD3<Float>, steps n: Int) -> MeshResource.Part {
        guard n > 1, let triangles = part.triangleIndices?.elements, triangles.count >= 3 else { return part }
        var positions = part.positions.elements
        guard triangles.allSatisfy({ Int($0) < positions.count }) else { return part }
        let given = part.normals?.elements, uvGiven = part.textureCoordinates?.elements
        var normals = given?.count == positions.count ? given : nil
        var uvs = uvGiven?.count == positions.count ? uvGiven : nil
        let radius = positions.map { p -> Float in
            let d = p - origin
            return length(d - axis * dot(d, axis))
        }

        // A new vertex from corner weights: linear, then pushed out (or in) to the interpolated distance from the axis.
        func add(_ corners: [(index: Int, weight: Float)]) -> UInt32 {
            var p = SIMD3<Float>.zero, r: Float = 0
            var nn = SIMD3<Float>.zero, uv = SIMD2<Float>.zero
            for c in corners {
                p += positions[c.index] * c.weight
                r += radius[c.index] * c.weight
                if let normals { nn += normals[c.index] * c.weight }
                if let uvs { uv += uvs[c.index] * c.weight }
            }
            let d = p - origin, h = dot(d, axis), q = d - axis * h
            if length(q) > 1e-6 { p = origin + axis * h + q / length(q) * r }
            positions.append(p)
            if normals != nil { normals!.append(length(nn) > 0 ? normalize(nn) : [0, 1, 0]) }
            if uvs != nil { uvs!.append(uv) }
            return UInt32(positions.count - 1)
        }

        // Points inside an edge, shared by the two triangles on it: ordered from the lower index to the higher.
        var edges: [SIMD2<UInt32>: [UInt32]] = [:]
        func edgePoint(_ u: UInt32, _ v: UInt32, _ k: Int) -> UInt32 {
            let lo = min(u, v), hi = max(u, v)
            let points: [UInt32]
            if let cached = edges[SIMD2(lo, hi)] {
                points = cached
            } else {
                points = (1..<n).map { i in
                    let t = Float(i) / Float(n)
                    return add([(Int(lo), 1 - t), (Int(hi), t)])
                }
                edges[SIMD2(lo, hi)] = points
            }
            return u == lo ? points[k - 1] : points[n - k - 1]
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(triangles.count * n * n)
        for f in 0..<(triangles.count / 3) {
            let a = triangles[3 * f], b = triangles[3 * f + 1], c = triangles[3 * f + 2]
            // Grid point (i, j): weight i/n on b, j/n on c, the rest on a.
            var grid: [SIMD2<Int>: UInt32] = [:]
            func point(_ i: Int, _ j: Int) -> UInt32 {
                if let v = grid[SIMD2(i, j)] { return v }
                let v: UInt32
                if i == 0 && j == 0 { v = a }
                else if i == n { v = b }
                else if j == n { v = c }
                else if j == 0 { v = edgePoint(a, b, i) }
                else if i == 0 { v = edgePoint(a, c, j) }
                else if i + j == n { v = edgePoint(b, c, j) }
                else {
                    let wb = Float(i) / Float(n), wc = Float(j) / Float(n)
                    v = add([(Int(a), 1 - wb - wc), (Int(b), wb), (Int(c), wc)])
                }
                grid[SIMD2(i, j)] = v
                return v
            }
            for j in 0..<n {
                for i in 0..<(n - j) {
                    indices += [point(i, j), point(i + 1, j), point(i, j + 1)]
                    if i < n - j - 1 { indices += [point(i + 1, j), point(i + 1, j + 1), point(i, j + 1)] }
                }
            }
        }
        var result = MeshResource.Part(id: part.id, materialIndex: part.materialIndex)
        result.positions = MeshBuffers.Positions(positions)
        if let normals { result.normals = MeshBuffers.Normals(normals) }
        if let uvs { result.textureCoordinates = MeshBuffers.TextureCoordinates(uvs) }
        result.triangleIndices = MeshBuffer<UInt32>(indices)
        return result
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

/// The canopy glass in look mode (owner D116; round 3: "the glass does not look like glass yet"). Dark, glossy and
/// partly see-through: clearcoat with a near-zero roughness carries crisp reflections, the dielectric Fresnel term
/// makes the edges reflect more than the centre, and partial opacity lets the lit cockpit (`CockpitInterior`) show
/// faintly. RealityKit has no transmission term, so see-through is opacity blending. Round 2 read as white chrome:
/// seen from below, the glass reflected the bright studio ceiling at grazing angles. The glass therefore gets its
/// own dark environment (`EntranceLook.glassStudio`, set by `EntranceScene.setEnvironment`) with one soft strip.
@available(macOS 15.0, *)
@MainActor
enum CanopyGlass {
    static let opacity: Float = 0.5

    static func material() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .init(srgbRed: 0.02, green: 0.026, blue: 0.036, alpha: 1))
        m.metallic = 0.0
        m.roughness = 0.04
        m.specular = 1.0
        m.clearcoat = 1.0
        m.clearcoatRoughness = 0.02
        m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        m.faceCulling = .none
        return m
    }
}

/// The cockpit behind the front window. The file's interior parts (`recessed_cockpit`, `cockpit_back_half_lining`)
/// become a dim unlit room. D132: `interior_soft_screen_plane` keeps the model file's own cockpit screen (the
/// emissive cockpit image the pass-5 renders show through the window and the pass-5 hand-over ends on), shown
/// unlit at `fileScreenBrightness`; only if the file has no screen image does it become a dark console with
/// code-drawn panels. Unlit, so the studio light does not wash it out and both themes show the same cockpit.
@available(macOS 15.0, *)
@MainActor
enum CockpitInterior {
    static let screenPlane = "interior_soft_screen_plane"
    static func isInterior(_ name: String) -> Bool {
        name == screenPlane || name == "recessed_cockpit" || name == "cockpit_back_half_lining"
    }

    /// Screen brightness (multiplies every panel colour). The glass shows about half of it.
    static let brightness: Float = 1.0
    /// The file's cockpit screen image, unlit, times this (the glass shows about half of it).
    static let fileScreenBrightness: CGFloat = 0.85

    /// The file's screen image as an unlit material, if the plane's material carries one (USD emissive texture).
    static func fileScreen(_ materials: [any RealityKit.Material]) -> UnlitMaterial? {
        for material in materials {
            guard let pbr = material as? PhysicallyBasedMaterial else { continue }
            let texture = pbr.emissiveColor.texture ?? pbr.baseColor.texture
            guard let texture else { continue }
            var m = UnlitMaterial()
            m.color = .init(tint: NSColor(white: fileScreenBrightness, alpha: 1), texture: texture)
            m.faceCulling = .none
            return m
        }
        return nil
    }

    /// Panels on the console in its own plane (metres; the plane is 0.92 x 0.76, facing the window along +z):
    /// centre x, centre y, width, height, colour (sRGB). Two clusters of screens and a status strip, like pass 5.
    static let panels: [(x: Float, y: Float, w: Float, h: Float, rgb: SIMD3<Float>)] = {
        let cool: SIMD3<Float> = [0.46, 0.58, 0.74], dim: SIMD3<Float> = [0.22, 0.29, 0.40], amber: SIMD3<Float> = [0.82, 0.58, 0.30]
        return [
            (-0.27, 0.06, 0.15, 0.11, cool), (-0.10, 0.06, 0.13, 0.11, amber),
            (-0.27, -0.08, 0.15, 0.10, dim), (-0.10, -0.08, 0.13, 0.10, cool),
            (0.15, 0.09, 0.14, 0.12, cool), (0.30, 0.09, 0.10, 0.12, dim),
            (0.15, -0.07, 0.14, 0.10, amber), (0.30, -0.07, 0.10, 0.10, cool),
            (0.0, 0.25, 0.56, 0.03, dim),
            (-0.36, -0.22, 0.025, 0.025, amber), (-0.31, -0.22, 0.025, 0.025, cool), (0.36, -0.22, 0.025, 0.025, cool),
        ]
    }()

    static func unlit(_ rgb: SIMD3<Float>) -> UnlitMaterial {
        let c = rgb * brightness
        var m = UnlitMaterial(color: NSColor(srgbRed: CGFloat(min(1, c.x)), green: CGFloat(min(1, c.y)), blue: CGFloat(min(1, c.z)), alpha: 1))
        m.faceCulling = .none
        return m
    }

    static func dress(_ e: Entity, name: String) {
        guard var model = e.components[ModelComponent.self] else { return }
        if name == screenPlane, let screen = fileScreen(model.materials) {
            model.materials = model.materials.map { _ in screen }
            e.components.set(model)
            return
        }
        let room: SIMD3<Float> = name == screenPlane ? [0.025, 0.032, 0.045] : [0.018, 0.02, 0.026]
        let material = unlit(room)
        model.materials = model.materials.map { _ in material }
        e.components.set(model)
        guard name == screenPlane, e.findEntity(named: "cockpit-screen-0") == nil else { return }
        // On both faces of the console: which face looks at the window is not checked on a render yet.
        for (i, p) in panels.enumerated() {
            for side: Float in [1, -1] {
                // A soft halo (a larger, dimmer plane just behind) and the screen itself.
                let halo = ModelEntity(mesh: .generatePlane(width: p.w * 1.35, height: p.h * 1.45), materials: [unlit(p.rgb * 0.28)])
                halo.position = [p.x, p.y, 0.004 * side]
                halo.name = "cockpit-halo-\(i)"
                e.addChild(halo)
                let screen = ModelEntity(mesh: .generatePlane(width: p.w, height: p.h), materials: [unlit(p.rgb)])
                screen.position = [p.x, p.y, 0.007 * side]
                screen.name = "cockpit-screen-\(i)"
                e.addChild(screen)
            }
        }
    }
}

/// The dark lining inside the capsule (r3b-r3d; D132 moved its screens to the back side walls, see `screens`).
/// History: what the 62-degree end-pose camera saw through the canopy (r3b feedback: the flat console read as a
/// sticker on the rim). Measured on the model file (`entrance-r3/land3.py`): from the end pose, looking up about 62-65
/// degrees, every sight line through the glass runs up inside the capsule and lands on the inside of the nose,
/// about y 13.45-14.2, x within +-0.42, front half; a flat console anywhere inside is either cut by the rim or seen
/// edge-on. So the interior is a dark lining just inside the skin (`radiusFraction` of the hull radius, y 12.3 to
/// the tip), textured in code with softly glowing screens on that overhead band. It also hides the lit metal of
/// the hull's inner faces, which made the glass read light grey. Unlit: the same cockpit in both themes, veiled by
/// the glass tint and under the glass reflection. No art files.
@available(macOS 15.0, *)
@MainActor
enum CockpitCeiling {
    static let name = "cockpit-ceiling"
    static let radiusFraction: Float = 0.92
    static let bottom: Float = 12.3
    static let top: Float = 14.17
    /// Multiplies the screen colours in the texture.
    static let brightness: CGFloat = 1.0
    /// The opening in the lining behind the window (r3c showed nothing: every sight line through the glass first
    /// crosses the lining just behind the glass, so the near wall hid the far one). Measured with
    /// `entrance-r3/hole.py` for camera elevations 61-66 degrees: all entry points lie below y 13.75 within 52.3
    /// degrees of the window side; 85 % of the landing points lie outside this opening, on the lining.
    static let openingTop: Float = 13.78
    static let openingHalfAzimuth: Float = 56
    /// The capsule's outer radius by height, measured on the brand rocket model file (rings of capsule_lower,
    /// capsule_aperture_shell and capsule_nose).
    static let profile: [(y: Float, r: Float)] = [
        (12.061, 0.894), (12.281, 0.886), (12.4, 0.875), (12.487, 0.862), (12.574, 0.848), (12.661, 0.831),
        (12.748, 0.812), (12.835, 0.791), (12.922, 0.768), (13.009, 0.743), (13.096, 0.715), (13.183, 0.686),
        (13.27, 0.657), (13.4, 0.608), (13.587, 0.523), (13.78, 0.422), (13.95, 0.311), (14.07, 0.224),
        (14.144, 0.146), (14.18, 0.086), (14.194, 0.039), (14.2, 0.0),
    ]

    static func radius(_ y: Float) -> Float {
        guard let first = profile.first, y > first.y else { return profile.first?.r ?? 0 }
        for (a, b) in zip(profile, profile.dropFirst()) where y <= b.y {
            return a.r + (b.r - a.r) * (y - a.y) / (b.y - a.y)
        }
        return 0
    }

    /// Screens on the texture: azimuth (degrees, 0 = the window side), height (metres in the rocket frame),
    /// width and height (metres along the surface), colour (sRGB). D132: the camera now looks through the front
    /// window from about 20 degrees below, so the sight lines cross the capsule rising gently: the centre ones end
    /// on the file's cockpit screen, the outer columns on the back side walls (|az| about 110-160, y 12.6-13.4) and
    /// the top rows on the upper back wall (y 13.3-13.6). Screens sit there, in two clusters left and right of the
    /// main screen like the pass-5 window still. (The r3 overhead band served the 62-degree dome view.)
    static let screens: [(az: Float, y: Float, w: Float, h: Float, rgb: SIMD3<Float>)] = {
        let cool: SIMD3<Float> = [0.58, 0.72, 0.95], dim: SIMD3<Float> = [0.32, 0.42, 0.58], amber: SIMD3<Float> = [1.0, 0.72, 0.38]
        return [
            (-118, 12.95, 0.15, 0.11, cool), (-118, 12.78, 0.15, 0.09, amber), (-134, 13.06, 0.12, 0.12, dim),
            (-134, 12.86, 0.10, 0.07, cool), (-150, 13.18, 0.09, 0.07, amber), (-112, 13.2, 0.08, 0.05, dim),
            (118, 12.95, 0.15, 0.11, dim), (118, 12.78, 0.15, 0.09, cool), (134, 13.06, 0.12, 0.12, cool),
            (134, 12.86, 0.10, 0.07, amber), (150, 13.18, 0.09, 0.07, cool), (112, 13.2, 0.08, 0.05, amber),
            (-165, 13.42, 0.12, 0.05, dim), (165, 13.42, 0.12, 0.05, cool), (-160, 13.55, 0.07, 0.035, amber),
            (160, 13.55, 0.07, 0.035, dim),
        ]
    }()

    static func add(to root: Entity) throws {
        guard root.findEntity(named: name) == nil else { return }
        let image = try texture()
        let resource = try TextureResource.generate(from: image, options: .init(semantic: .color))
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(resource))
        material.faceCulling = .none
        let entity = ModelEntity(mesh: try mesh(), materials: [material])
        entity.name = name
        root.addChild(entity)
    }

    /// A surface of revolution at `radiusFraction` of the capsule radius. u runs with the azimuth (0.5 = the window
    /// side, +z), v with the height (0 at `bottom`, 1 at `top`; the texture's top row is v = 1).
    static func mesh(columns: Int = 128, rows: Int = 64) throws -> MeshResource {
        var positions: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], indices: [UInt32] = []
        for j in 0...rows {
            let v = Float(j) / Float(rows), y = bottom + (top - bottom) * v
            let r = radius(y) * radiusFraction
            for i in 0...columns {
                let u = Float(i) / Float(columns), a = (u - 0.5) * 2 * .pi
                positions.append([sin(a) * r, y, cos(a) * r])
                uvs.append([u, v])
            }
        }
        let stride = UInt32(columns + 1)
        for j in 0..<UInt32(rows) {
            for i in 0..<UInt32(columns) {
                let a = j * stride + i, b = a + 1, c = a + stride, d = c + 1
                let centre = (positions[Int(a)] + positions[Int(d)]) / 2
                let azimuth = atan2(centre.x, centre.z) * 180 / .pi
                if centre.y < openingTop && abs(azimuth) < openingHalfAzimuth { continue }
                indices += [a, b, d, a, d, c]
            }
        }
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    enum TextureError: Error { case context }

    /// 2048 x 1024: near-black lining, faint panel structure, and the screens as soft-edged rounded rectangles
    /// with a blurred glow and dim content lines, so they read as lit displays seen through tinted glass.
    static func texture() throws -> CGImage {
        let w = 2048, h = 1024
        guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw TextureError.context }
        // CoreGraphics' origin is bottom left, so drawing y = v * h puts content at texture v.
        func color(_ rgb: SIMD3<Float>, _ k: CGFloat = 1, alpha: CGFloat = 1) -> CGColor {
            CGColor(srgbRed: min(1, CGFloat(rgb.x) * k), green: min(1, CGFloat(rgb.y) * k), blue: min(1, CGFloat(rgb.z) * k), alpha: alpha)
        }
        c.setFillColor(color([0.012, 0.014, 0.02]))
        c.fill(CGRect(x: 0, y: 0, width: w, height: h))
        func rect(az: Float, y: Float, w mw: Float, h mh: Float) -> CGRect {
            let r = max(0.05, radius(y) * radiusFraction)
            let cx = CGFloat((az / 360 + 0.5) * Float(w)), cy = CGFloat((y - bottom) / (top - bottom) * Float(h))
            let pw = CGFloat(mw / (2 * .pi * r) * Float(w)), ph = CGFloat(mh / (top - bottom) * Float(h))
            return CGRect(x: cx - pw / 2, y: cy - ph / 2, width: pw, height: ph)
        }
        // Faint console housings behind the screens: barely lighter than the lining, so no hard outline shows.
        c.setFillColor(color([0.03, 0.035, 0.045]))
        // D132: no mirrored copies any more (the r3d hedge against a reversed v). Seen through the front window,
        // a reversed v only moves the side screens up to the upper back wall, still in view.
        let screens = Self.screens
        for s in screens {
            c.addPath(CGPath(roundedRect: rect(az: s.az, y: s.y, w: s.w * 1.35, h: s.h * 1.4).insetBy(dx: 0, dy: 0),
                             cornerWidth: 10, cornerHeight: 10, transform: nil))
        }
        c.fillPath()
        for s in screens {
            let r = rect(az: s.az, y: s.y, w: s.w, h: s.h)
            // Glow: the screen drawn with a wide blurred shadow of its own colour.
            c.saveGState()
            c.setShadow(offset: .zero, blur: max(r.width, r.height) * 0.6, color: color(s.rgb, brightness * 0.9, alpha: 0.9))
            c.setFillColor(color(s.rgb, brightness * 0.75))
            c.addPath(CGPath(roundedRect: r, cornerWidth: min(r.width, r.height) * 0.12, cornerHeight: min(r.width, r.height) * 0.12, transform: nil))
            c.fillPath()
            c.restoreGState()
            // Dim content: a few lighter lines and a darker block, low contrast.
            c.setFillColor(color(s.rgb, brightness, alpha: 0.6))
            for k in 0..<3 {
                let line = CGRect(x: r.minX + r.width * 0.12, y: r.minY + r.height * (0.22 + 0.22 * CGFloat(k)),
                                  width: r.width * (0.7 - 0.15 * CGFloat(k)), height: max(1, r.height * 0.06))
                c.fill(line)
            }
            c.setFillColor(color(s.rgb, brightness * 0.45))
            c.fill(CGRect(x: r.minX + r.width * 0.6, y: r.minY + r.height * 0.15, width: r.width * 0.28, height: r.height * 0.3))
        }
        guard let image = c.makeImage() else { throw TextureError.context }
        return image
    }
}

/// D132 finish: the hull albedo without the grime. The model file's atlas (one 1024 x 2048 image for the five hull
/// sections) carries panel lines and hatch outlines, but also blotchy grime and baked vertical shading bands that
/// read as dirt on the polished metal. This derives a clean albedo from it in code: flat metal at the atlas's mean
/// level, and only the thin dark features kept (a pixel stays dark when it is darker than its 21 x 21 neighbourhood
/// by more than `lineThreshold` and lies on a straight run of such pixels, so spots and smudges drop out). No new art
/// file: the source is the shipped atlas, read from the model file at run time; on any failure the file's atlas stays.
@available(macOS 15.0, *)
@MainActor
enum CleanAtlas {
    /// The hull atlas inside the model file (both finishes; a stored, uncompressed zip entry as USDZ requires).
    static let entry = "textures/Texture_9_false.jpg"
    static let lineThreshold: Float = 0.06
    /// Line depth: 0 keeps no lines, 1 the full depth (lines at about a quarter of the metal level).
    static let lineStrength: Float = 1.0
    static var cache: [String: (texture: TextureResource, width: Int, height: Int)] = [:]

    static func texture(modelURL url: URL) -> (texture: TextureResource, width: Int, height: Int)? {
        if let hit = cache[url.path] { return hit }
        guard let data = try? Data(contentsOf: url), let jpeg = storedEntry(entry, in: data),
              let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let clean = cleaned(image),
              let resource = try? TextureResource.generate(from: clean, options: .init(semantic: .color))
        else { return nil }
        let result = (texture: resource, width: clean.width, height: clean.height)
        cache[url.path] = result
        return result
    }

    /// A stored (method 0) entry of a zip archive, by walking the local file headers.
    static func storedEntry(_ name: String, in data: Data) -> Data? {
        let bytes = [UInt8](data)
        func u16(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
        var offset = 0
        while offset + 30 <= bytes.count, u32(offset) == 0x0403_4b50 {
            let flags = u16(offset + 6), method = u16(offset + 8), size = u32(offset + 18)
            let nameLength = u16(offset + 26), extra = u16(offset + 28)
            let start = offset + 30 + nameLength + extra
            // Bit 3: sizes follow the data, so the walk cannot continue.
            guard flags & 0x8 == 0, nameLength > 0, start + size <= bytes.count else { return nil }
            let entryName = String(decoding: bytes[(offset + 30)..<(offset + 30 + nameLength)], as: UTF8.self)
            if entryName == name { return method == 0 ? Data(bytes[start..<(start + size)]) : nil }
            offset = start + size
        }
        return nil
    }

    static func cleaned(_ image: CGImage) -> CGImage? {
        let w = image.width, h = image.height, n = w * h
        guard w > 32, h > 32 else { return nil }
        var rgba = [UInt8](repeating: 0, count: n * 4)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let c = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                    space: space, bitmapInfo: info) else { return false }
            c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        var level = [Float](repeating: 0, count: n)
        var mean: Float = 0
        for i in 0..<n {
            level[i] = (Float(rgba[4 * i]) + Float(rgba[4 * i + 1]) + Float(rgba[4 * i + 2])) / (3 * 255)
            mean += level[i]
        }
        mean /= Float(n)
        // Separable box blur, radius 10 at 1024 wide.
        let r = max(2, w / 100)
        var row = [Float](repeating: 0, count: n), low = [Float](repeating: 0, count: n)
        for y in 0..<h {
            var sum: Float = 0
            for x in -r...r { sum += level[y * w + min(w - 1, max(0, x))] }
            for x in 0..<w {
                row[y * w + x] = sum / Float(2 * r + 1)
                sum += level[y * w + min(w - 1, x + r + 1)] - level[y * w + max(0, x - r)]
            }
        }
        for x in 0..<w {
            var sum: Float = 0
            for y in -r...r { sum += row[min(h - 1, max(0, y)) * w + x] }
            for y in 0..<h {
                low[y * w + x] = sum / Float(2 * r + 1)
                sum += row[min(h - 1, y + r + 1) * w + x] - row[max(0, y - r) * w + x]
            }
        }
        var dark = [UInt8](repeating: 0, count: n)
        for i in 0..<n where level[i] - low[i] < -lineThreshold * 0.6 { dark[i] = 1 }
        // A straight run: at least 7 of the 9 pixels through it, vertically or horizontally.
        func lineish(_ x: Int, _ y: Int) -> Bool {
            var v = 0, hz = 0
            for k in -4...4 {
                v += Int(dark[min(h - 1, max(0, y + k)) * w + x])
                hz += Int(dark[y * w + min(w - 1, max(0, x + k))])
            }
            return v >= 7 || hz >= 7
        }
        let base: Float = 0.62
        var out = [UInt8](repeating: 255, count: n * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x, d = level[i] - low[i]
                var k: Float = 0
                if d < -lineThreshold || d > lineThreshold * 1.4, lineish(x, y) {
                    k = d < 0 ? max(-0.45, (d + lineThreshold) * 2.2) : min(0.05, (d - lineThreshold * 1.4) * 0.6)
                }
                let value = min(1, max(0, mean * (base + k * lineStrength) / base))
                let byte = UInt8((value * 255).rounded())
                out[4 * i] = byte; out[4 * i + 1] = byte; out[4 * i + 2] = byte
            }
        }
        // An image that owns a copy of the bytes (a bitmap context's image may still point at `out`).
        guard let provider = CGDataProvider(data: Data(out) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: info), provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
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

    /// Image-based light exponent for the canopy glass's own environment (`glassStudio`).
    public static func glassEnvironmentExponent(_ theme: EntranceTheme) -> Float { theme == .day ? 1.5 : 1.0 }

    /// The canopy glass's environment: the same strips as `studio` but in a near-black room with no bright
    /// ceiling, so the glass reflects one soft streak and a faint rim instead of turning white at grazing angles.
    public static func glassStudio() -> CGImage? {
        equirect { az, e in
            var v = 0.006 + 0.012 * max(0, sin(e * Double.pi / 180))
            v = max(v, 0.7 * strip(az, e, centre: -50, half: 7, low: -10, high: 70, soft: 18))
            v = max(v, 0.25 * strip(az, e, centre: 125, half: 3, low: 0, high: 60, soft: 14))
            return v
        }
    }

    /// A tall strip centred at azimuth `centre`, `half` degrees wide, from elevation `low` to `high`, with soft
    /// edges (a hard edge reflects as a sharp line down a metal cylinder).
    static func strip(_ az: Double, _ e: Double, centre: Double, half: Double, low: Double, high: Double, soft: Double = 12) -> Double {
        let da = abs((az - centre + 540).truncatingRemainder(dividingBy: 360) - 180)
        let fx = max(0, 1 - max(0, da - half) / soft)
        let fy = max(0, 1 - max(0, low - e, e - high) / 15)
        return fx * fx * (3 - 2 * fx) * fy * fy * (3 - 2 * fy)
    }

    /// A 512 x 256 equirectangular grey image from linear light values (azimuth, elevation in degrees), sRGB-encoded.
    static func equirect(_ value: (Double, Double) -> Double) -> CGImage? {
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
                let linear = min(1, max(0, value(az, e)))
                let encoded = linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1 / 2.4) - 0.055
                let o = (y * w + x) * 4
                let level = UInt8((encoded * 255).rounded())
                p[o] = level; p[o + 1] = level; p[o + 2] = level; p[o + 3] = 255
            }
        }
        return context.makeImage()
    }

    /// Equirectangular studio, 512 x 256, sRGB-encoded linear light. Dark room (night) or a light grey one (day:
    /// satin aluminium needs light to be light), a faint horizon band, and three tall soft strips: the key at upper
    /// left (azimuth -50), a dim fill (+30) and a narrow rim (+125). Image-based light only; it is never drawn.
    public static func studio(_ theme: EntranceTheme = .night) -> CGImage? {
        let day = theme == .day
        let floor = day ? 0.16 : 0.015, wall = day ? 0.30 : 0.04, ceiling = day ? 0.5 : 0.16, horizon = day ? 0.1 : 0.05
        return equirect { az, e in
            let s = sin(max(0, e) * Double.pi / 180)
            var v = e >= 0 ? wall + (ceiling - wall) * s * s : floor + (wall - floor) * max(0, 1 + e / 25)
            v += horizon * exp(-(e / 8) * (e / 8))
            v = max(v, strip(az, e, centre: -50, half: 10, low: -25, high: 80))
            v = max(v, 0.3 * strip(az, e, centre: 30, half: 5, low: -10, high: 70))
            v = max(v, 0.85 * strip(az, e, centre: 125, half: 4, low: -15, high: 75))
            return v
        }
    }
}
#endif
