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

/// Round 10 (owner Q3, 2026-11-11: show the real cockpit inside the front window): a picture of the cockpit as it
/// will appear when the entrance hands over, taken just before the entrance starts (the cockpit page's own
/// snapshot), and where that picture lies on the entrance viewport. The scene shows it behind the front-window
/// glass, mapped so that at the end of the hand-over every pixel lands where the real cockpit will draw it; the
/// cut from the rocket window to the cockpit then changes nothing inside the glass. Held in memory only, never
/// written anywhere. Transparent pixels (outside the cockpit's shell) show as the dark cabin.
@available(macOS 15.0, *)
public struct CockpitSnapshot: @unchecked Sendable {
    public var image: CGImage
    /// The rect the image covers on the entrance viewport, in points (top-left origin), usually the cockpit
    /// window's frame. The image may have any pixel density.
    public var frame: EntranceRect

    public init(image: CGImage, frame: EntranceRect) {
        self.image = image
        self.frame = frame
    }
}

/// Where the entrance gets the cockpit snapshot. The app passes its cockpit page (for a web view: its snapshot of
/// the visible page and its frame on the entrance viewport); tests and renders inject a stored image. Returning nil
/// falls back to the bundled cockpit image (the official pack), or to the code-drawn console without one.
@available(macOS 15.0, *)
@MainActor
public protocol CockpitSnapshotSource: AnyObject {
    func cockpitSnapshot() async -> CockpitSnapshot?
}

/// A fixed snapshot (tests, renders, or a snapshot the app already took).
@available(macOS 15.0, *)
@MainActor
public final class StoredCockpitSnapshot: CockpitSnapshotSource {
    public let snapshot: CockpitSnapshot?
    public init(_ snapshot: CockpitSnapshot?) { self.snapshot = snapshot }
    public func cockpitSnapshot() async -> CockpitSnapshot? { snapshot }
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
    /// Which hull albedo look mode uses: "panels ..." (round 5: the code-drawn panel maps of `HullPanels`),
    /// "file" (the atlas as shipped, if the maps could not be made) or "none" (stand-in or grey box).
    public private(set) var hullAlbedo = "none"
    /// The front window in look mode: "rounded ..." (owner D142: corners rounded like the pass-5 art) or "file".
    public private(set) var windowShape = "none"
    /// What is behind the front window in look mode: "snapshot" (round 10: the real cockpit), "image" (the pack's
    /// cockpit interior) or "code" (the console).
    public private(set) var cockpit = "none"
    /// Look-mode frames are rendered at this multiple of the output size and scaled down (round 5: the day
    /// silhouette and the hairline seams aliased at 1x). Flat mode stays at 1, so the pose gates see the same pixels.
    public var supersample: Int

    /// Both themes are black space (owner D116): nothing is drawn behind the rocket, and day differs from night
    /// only by a stronger sun (`EntranceLook.sunIntensity`).
    ///
    /// - Parameters:
    ///   - parts: which parts to draw; tests isolate one part to compare its silhouette with the core's projection.
    ///   - flat: unlit flat materials (the reference's `look=grey`); false uses the theme finish (stand-in values).
    ///   - rocket: the stand-in, or a model file (the official edition's brand rocket). Build the plan with
    ///     `rocket.geometry` so the camera frames the rocket that is drawn.
    ///   - look: optional look images that come with the model file (owner D142); missing ones are code-drawn.
    ///   - cockpitSnapshot: round 10, the real cockpit shown behind the front window (look mode, storyboard camera
    ///     only); nil uses the bundled cockpit image in `look`, or the code console.
    public init(plan: EntrancePlan, parts: Set<EntrancePart> = [.hull, .glass], flat: Bool = true,
                rocket: RocketModelSource = .communityDefault, look: RocketLookImages = .none,
                cockpitSnapshot: CockpitSnapshot? = nil) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw SceneError.noMetalDevice }
        self.device = device
        self.plan = plan
        self.parts = parts
        supersample = flat ? 1 : 2
        renderer = try RealityRenderer()
        root.addChild(stage)
        if let url = rocket.modelURL(for: plan.scenario.theme) {
            // The snapshot is mapped from the hand-over camera (the end of the map stage, rocket risen one length).
            let placement = cockpitSnapshot.flatMap { snapshot in
                plan.storyboard.map { CockpitBackdrop.Placement(snapshot: snapshot, camera: $0.handover, rise: StoryboardRail.liftMetres) }
            }
            let built = try ModelRocket.build(into: stage, url: url, tail: plan.tail, parts: parts, flat: flat,
                                              theme: plan.scenario.theme, look: look, snapshot: placement)
            hullAlbedo = built.albedo
            windowShape = built.window
            cockpit = built.cockpit
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

    /// Round 10: builds the scene with the cockpit snapshot from `source` (taken now, just before the entrance).
    public static func make(plan: EntrancePlan, parts: Set<EntrancePart> = [.hull, .glass], flat: Bool = true,
                            rocket: RocketModelSource = .communityDefault, look: RocketLookImages = .none,
                            cockpit source: (any CockpitSnapshotSource)?) async throws -> EntranceScene {
        var snapshot: CockpitSnapshot?
        if !flat, let source { snapshot = await source.cockpitSnapshot() }
        return try EntranceScene(plan: plan, parts: parts, flat: flat, rocket: rocket, look: look, cockpitSnapshot: snapshot)
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

        let s = Double(max(1, supersample))
        let width = Int((plan.canvas.width * s).rounded(.up)), height = Int((plan.canvas.height * s).rounded(.up))
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
        let crop = CGRect(x: (plan.crop.x * s).rounded(), y: (plan.crop.y * s).rounded(),
                          width: (view.viewport.width * s).rounded(), height: (view.viewport.height * s).rounded())
        guard let image = full.cropping(to: crop) else { throw SceneError.noImage }
        guard s > 1 else { return image }
        return try Self.downscaled(image, width: Int(view.viewport.width.rounded()), height: Int(view.viewport.height.rounded()))
    }

    /// Scales a supersampled frame down to the output size (high-quality interpolation).
    private static func downscaled(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info)
        else { throw SceneError.noImage }
        c.interpolationQuality = .high
        c.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let out = c.makeImage() else { throw SceneError.noImage }
        return out
    }

    /// Round 11 (the thin white rim round the whole rocket in every frame): the sRGB render target holds
    /// encode(colour x alpha), premultiplied in linear light, but Core Graphics reads premultiplied sRGB as
    /// encode(colour) x alpha. Along the antialiased silhouette, where alpha is small, the encoded value is far above
    /// alpha (encode(0.01) is about 0.1), so un-premultiplying (PNG export, any compositing) clipped those pixels to
    /// near white. Each partly covered pixel is converted here.
    static func repremultiplied(_ bytes: inout [UInt8]) {
        func decode(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        func encode(_ v: Float) -> Float { v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055 }
        let table = (0..<256).map { decode(Float($0) / 255) }
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let a = bytes[i + 3]
            guard a > 0, a < 255 else { continue }
            let alpha = Float(a) / 255
            for k in 0..<3 {
                let straight = min(1, table[Int(bytes[i + k])] / alpha)
                bytes[i + k] = UInt8(min(Float(a), (encode(straight) * alpha * 255).rounded()))
            }
        }
    }

    private static func image(from texture: MTLTexture, width: Int, height: Int) throws -> CGImage {
        let rowBytes = width * 4
        var bytes = [UInt8](repeating: 0, count: rowBytes * height)
        bytes.withUnsafeMutableBytes { buffer in
            texture.getBytes(buffer.baseAddress!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        repremultiplied(&bytes)
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
    static func isGlass(_ e: Entity) -> Bool { isUnder(e, glassName) }

    /// Whether `e` or one of its ancestors is named `name`.
    static func isUnder(_ e: Entity, _ name: String) -> Bool {
        var node: Entity? = e
        while let n = node {
            if n.name == name { return true }
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

    /// Builds the model into `stage`; returns what look mode used (see `EntranceScene.hullAlbedo`, `windowShape`
    /// and `cockpit`).
    @discardableResult
    static func build(into stage: Entity, url: URL, tail: [TailSlot], parts: Set<EntrancePart>, flat: Bool,
                      theme: EntranceTheme, look: RocketLookImages = .none,
                      snapshot: CockpitBackdrop.Placement? = nil) throws -> (albedo: String, window: String, cockpit: String) {
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
            let detail = look.brushedDetail.flatMap(LookImage.load)
            if let maps = HullPanels.maps(detail: detail) {
                finish.panels = maps
                albedo = "panels " + [HullPanels.capsule, HullPanels.body].map { "\($0.name) \($0.width)x\($0.height)" }
                    .joined(separator: ", ") + (detail != nil ? ", detail image" : ", detail code")
            } else {
                albedo = "file"
            }
            finish.cockpitImage = look.cockpitInterior(for: theme).flatMap(LookImage.load)
            finish.snapshot = snapshot
            try finish.dress(body)
        }
        let result = (albedo: albedo, window: flat ? "none" : finish.windowShape, cockpit: flat ? "none" : finish.cockpitUsed)
        guard parts.contains(.hull) else { return result }
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
        return result
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
/// normal map's 0.16 strength is likewise lost and its grain shows at full strength. Here the hull gets fixed metal
/// values and every mesh gets smooth vertex normals (`SmoothNormals`). Round 3 (owner 11-10): joints and the window
/// surround become hairlines (`JointLine`, `GasketFrame`), the hull is rounded to 96 sides (`RoundHull`), and the
/// cockpit shows faintly through the glass (`CockpitInterior`). Round 5 (owner 11-11: "the glass, the seams and the
/// material still clearly differ from the prototype"): the hull is mapped around its axis and dressed with the
/// code-drawn panel maps of `HullPanels` (dense panel grid, access hatches, nose tip cap, brushed grain and
/// micro-scratches), the night finish is darker, and the window frame is a thin dark band with a bright inner rim.
@available(macOS 15.0, *)
@MainActor
struct HullFinish {
    let theme: EntranceTheme
    /// Round 5: the code-drawn panel maps (`HullPanels`); nil keeps the file's atlas.
    var panels: [String: HullPanels.Maps]?
    /// D142: the pack's cockpit interior image for this theme; nil draws the code console.
    var cockpitImage: CGImage?
    /// Round 10: the real cockpit snapshot and how it maps; it wins over `cockpitImage`.
    var snapshot: CockpitBackdrop.Placement?
    /// What `dress` did with the window and the cockpit (reported by the scene).
    private(set) var windowShape = "file"
    private(set) var cockpitUsed = "code"
    init(_ theme: EntranceTheme) { self.theme = theme }

    /// The textured outer hull sections.
    static let hullParts: Set<String> = ["aft_skirt", "lower_stage", "long_slanted_interstage", "slender_upper_body",
                                         "capsule_aperture_shell", "capsule_lower", "capsule_nose"]

    /// The axial seams: thin near-black strips along the body in the file. With the panel maps they are hidden; the
    /// maps draw the body's vertical seams at the same azimuths, as grooves.
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
    /// Round 11 (owner: pass 5 has a soft, long highlight down the hull; r10 had one hot spot): night 0.30 -> 0.34,
    /// day 0.34 -> 0.36.
    /// Round 11b (r11a at 0.34 / 0.36 lost the metal's contrast: the studio averaged into flat grey): night 0.28,
    /// day 0.32; the hot spot is handled by a softer sun and coat instead.
    /// Round 11c (r11b still read as flat grey / paper next to pass 5's bright bands and dark flanks): night 0.22,
    /// day 0.25, with a brighter metal (`tint`) in a darker studio, so the strips are what the hull shows.
    var roughness: Float { theme == .night ? 0.22 : 0.25 }
    /// A thin glossy layer over the metal: a crisp copy of the strips on top of the soft band. The clearcoat has no
    /// normal map, so it stays smooth over the brushed grain. Round 10 (owner: the hull read as ceramic tile or
    /// plaster up close; pass 5 is smooth painted/anodised metal under a gentle gloss): night 0.35 -> 0.5, day
    /// 0.2 -> 0.3, with `clearcoatRoughness` 0.08.
    /// Round 11: night 0.5 -> 0.15, day 0.3 -> 0.1, `clearcoatRoughness` 0.08 -> 0.22. The crisp coat mirrored the
    /// sun as a blown-out spot on the lower body and, at grazing angles (where any coat reflects nearly all light),
    /// the studio's rim strips as a thin white line round the whole silhouette, which pass 5 does not have.
    /// Round 11b: night 0.25, day 0.15, roughness 0.18 (r11a's 0.15 / 0.1 / 0.22 looked matte).
    var clearcoat: Float { theme == .night ? 0.25 : 0.15 }
    static let clearcoatRoughness: Float = 0.18
    /// Brushed metal: how far the highlights stretch across the grain (0 = round highlights). The grain runs around
    /// the hull, like a turned part, so the studio strips stretch along the axis.
    /// Round 11: 0.3 -> 0.55, so the key strip and the sun draw long soft vertical highlights, as on pass 5.
    /// Round 11b: 0.4 (0.55 smeared the strips into an even grey).
    static let anisotropy: Float = 0.4
    /// Multiplies the panel maps (`HullPanels.base` 0.74 on a plain panel). Night is dark gunmetal: a panel ~0.31
    /// sRGB (r4 ~0.35 read mid-grey; r5 ~0.25 read black, so the dark grooves had nothing to cut into); day satin
    /// aluminium (~0.72).
    var tint: NSColor {
        // Round 11c: night 0.42 -> 0.62, day 0.98 -> 0.88. A metal's colour is its reflectance: at 0.42 the night
        // hull reflected about 4 % of the studio, so the strips barely beat the room and it all read as one grey;
        // real steel reflects far more, and pass 5's darkness comes from a dark room, not a dull metal (the studio
        // is darker to match, `EntranceLook.studio`). Day is mid steel, not white.
        theme == .night ? NSColor(srgbRed: 0.62, green: 0.625, blue: 0.64, alpha: 1)
            : NSColor(srgbRed: 0.88, green: 0.88, blue: 0.875, alpha: 1)
    }
    /// The finish as a flat colour, the tone of a plain panel (bells, the window surround, and the hull if its
    /// material is not a PBR).
    var plainColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.31, green: 0.315, blue: 0.325, alpha: 1)
            : NSColor(srgbRed: 0.725, green: 0.725, blue: 0.718, alpha: 1)
    }
    /// Seam grooves (joint lines, the outer line of the window surround): a dark-grey groove, never ink black, so it
    /// reads as a cut in the metal rather than a drawn line.
    var grooveColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.09, green: 0.092, blue: 0.097, alpha: 1)
            : NSColor(srgbRed: 0.26, green: 0.26, blue: 0.255, alpha: 1)
    }
    /// The light lip beside each joint groove: polished, lighter than the hull, so it catches the studio strip as a
    /// faint bright edge like the pass-5 art.
    var lipColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.36, green: 0.365, blue: 0.375, alpha: 1)
            : NSColor(srgbRed: 0.84, green: 0.84, blue: 0.83, alpha: 1)
    }
    /// The window frame (round 5): a thin dark metal band like the pass-5 window, glossy enough to carry a highlight.
    var frameColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.085, green: 0.087, blue: 0.095, alpha: 1)
            : NSColor(srgbRed: 0.2, green: 0.2, blue: 0.205, alpha: 1)
    }
    /// The inner rim between the frame and the glass. Round 10 (owner on r9: "why is there a white frame round the
    /// window?"; pass 5 has a dark metal frame whose edge only catches a thin specular line): rounds 6-9 made it a
    /// white polished strip with its own glow. It is now dark polished metal with no glow, a little lighter than the
    /// frame, so it shows only where it reflects a studio strip.
    var rimColor: NSColor {
        theme == .night ? NSColor(srgbRed: 0.16, green: 0.165, blue: 0.175, alpha: 1)
            : NSColor(srgbRed: 0.3, green: 0.3, blue: 0.305, alpha: 1)
    }

    /// Round 6 (r5: the frame read as a light band along the bottom of the window, where its faces tilt up at the
    /// lit studio ceiling): the frame is a dark non-metal (it reflects only a few per cent, plus one crisp clearcoat
    /// line), and the surround outside it is the hull colour, darker and rougher, so it does not mirror the ceiling.
    var frameMaterial: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: frameColor)
        m.metallic = 0.0
        m.roughness = 0.3
        m.clearcoat = 0.7
        m.clearcoatRoughness = 0.04
        m.faceCulling = .none
        return m
    }
    var surroundMaterial: PhysicallyBasedMaterial {
        var m = metal(plainColor.blended(withFraction: 0.35, of: .black) ?? plainColor, roughness: 0.55)
        m.clearcoat = 0.0
        return m
    }
    var rimMaterial: PhysicallyBasedMaterial {
        var m = metal(rimColor, roughness: 0.14)
        m.clearcoat = 0.6
        m.clearcoatRoughness = 0.05
        return m
    }

    func metal(_ color: NSColor, roughness: Float) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.metallic = 1.0
        m.roughness = .init(floatLiteral: roughness)
        m.clearcoat = .init(floatLiteral: clearcoat)
        m.clearcoatRoughness = .init(floatLiteral: Self.clearcoatRoughness)
        m.faceCulling = .none
        return m
    }

    /// Materials, geometry and normals for everything under `root` (the model, or one cloned bell).
    mutating func dress(_ root: Entity) throws {
        // The window first, before the meshes are rounded and smoothed. D142: the glass and the frame bands are
        // rebuilt with round corners (`WindowShape`); if the file does not have the expected window, the round-5
        // reshape of the file's strips is the fallback.
        let rounded = try WindowShape.build(in: root)
        if rounded {
            windowShape = String(format: "rounded r %.2f/%.2f", WindowShape.bottomRadius, WindowShape.topRadius)
        } else {
            try GasketFrame.reshape(in: root)
        }
        let backdrop = snapshot != nil || cockpitImage != nil
        if backdrop, root.findEntity(named: CockpitInterior.screenPlane) != nil { cockpitUsed = snapshot != nil ? "snapshot" : "image" }
        var models: [Entity] = []
        ModelRocket.forEachModel(root) { models.append($0) }
        for e in models where e.isEnabledInHierarchy {
            guard var model = e.components[ModelComponent.self] else { continue }
            let name = ModelRocket.partName(e)
            if Self.isPanelJoint(name) || (panels != nil && Self.isAxialSeam(name)) {
                // The named entity, not only the mesh entity under it (round 3 disabled only the child).
                var node: Entity? = e
                while let n = node, n.name != name { node = n.parent }
                (node ?? e).isEnabled = false
                continue
            }
            if CockpitInterior.isInterior(name) {
                if backdrop, name != "cockpit_back_half_lining" {
                    // D142: the cockpit image replaces the file's screen plane and recess (it sits where they are).
                    var node: Entity? = e
                    while let n = node, n.name != name { node = n.parent }
                    (node ?? e).isEnabled = false
                    continue
                }
                CockpitInterior.dress(e, name: name)
                continue
            }
            var frame = GasketFrame.role(of: e)
            // D142: in the rebuilt window the outer strip is the surround and the middle one the frame's outer wall.
            if rounded, let role = frame {
                frame = role == .outerLine ? .surround : role == .surround ? .outerLine : role
            }
            // Rebuilt window meshes are already round and dense.
            let round = RoundHull.applies(to: name) && !(rounded && (ModelRocket.isGlass(e) || frame != nil))
            if ModelRocket.isGlass(e) {
                // Owner D116: the canopy is real glass, not the model's flat grey.
                let glass = CanopyGlass.material()
                model.materials = model.materials.map { _ in glass }
                if round { model.mesh = try RoundHull.mesh(model.mesh, entity: e, root: root) }
                model.mesh = try SmoothNormals.mesh(model.mesh)
                e.components.set(model)
                continue
            }
            let band = Self.hullParts.contains(name) ? HullPanels.band(for: name) : nil
            let maps = band.flatMap { panels?[$0.name] }
            model.materials = model.materials.map { material -> any RealityKit.Material in
                if Self.hullParts.contains(name) {
                    guard var pbr = material as? PhysicallyBasedMaterial else { return metal(plainColor, roughness: roughness) }
                    if let maps {
                        pbr.baseColor = .init(tint: tint, texture: HullPanels.texture(maps.albedo))
                        pbr.normal = .init(texture: HullPanels.texture(maps.normal))
                        pbr.anisotropyLevel = .init(floatLiteral: Self.anisotropy)
                        pbr.anisotropyAngle = .init(floatLiteral: 0)
                    } else {
                        pbr.baseColor.tint = tint
                        pbr.normal.texture = nil
                    }
                    pbr.metallic = 1.0
                    pbr.roughness = .init(floatLiteral: roughness)
                    pbr.clearcoat = .init(floatLiteral: clearcoat)
                    pbr.clearcoatRoughness = .init(floatLiteral: Self.clearcoatRoughness)
                    pbr.faceCulling = .none
                    return pbr
                }
                if Self.isJointEdge(name) || Self.isAxialSeam(name) { return metal(grooveColor, roughness: 0.5) }
                if let frame {
                    switch frame {
                    case .outerLine: return metal(grooveColor, roughness: 0.5)
                    case .surround: return surroundMaterial
                    case .frame: return frameMaterial
                    case .rim: return rimMaterial
                    }
                }
                if Self.isBellMetal(name) { return metal(plainColor, roughness: roughness + 0.02) }
                guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                pbr.faceCulling = .none
                return pbr
            }
            if round || (frame != nil && !rounded) { model.mesh = try RoundHull.mesh(model.mesh, entity: e, root: root) }
            // D146: the hull behind the new window and its patch is cut away (the old opening is covered too).
            if rounded, HullPanels.capsuleParts.contains(name) { model.mesh = try WindowShape.cut(model.mesh, entity: e, root: root) }
            // The panel maps are drawn around the rocket's axis: map the hull the same way.
            if let band, maps != nil { model.mesh = try HullPanels.remap(model.mesh, entity: e, root: root, band: band) }
            model.mesh = try SmoothNormals.mesh(model.mesh)
            e.components.set(model)
        }
        JointLine.draw(in: root, lip: metal(lipColor, roughness: 0.16))
        // D146: the hull patch round the new window wears the capsule's own (panel) material.
        if rounded, let shell = root.findEntity(named: "capsule_aperture_shell") {
            var material: (any RealityKit.Material)?
            ModelRocket.forEachModel(shell) { m in
                if material == nil { material = m.components[ModelComponent.self]?.materials.first }
            }
            if let material { try WindowShape.addPatch(to: root, material: material) }
        }
        if let plane = root.findEntity(named: CockpitInterior.screenPlane) {
            if let snapshot {
                try CockpitBackdrop.add(to: root, snapshot: snapshot)
                try CockpitCeiling.add(to: root, screens: false)
            } else if let cockpitImage {
                try CockpitBackdrop.add(to: root, image: cockpitImage)
                try CockpitCeiling.add(to: root, screens: false)
            } else if plane.isEnabledInHierarchy {
                try CockpitCeiling.add(to: root)
            }
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
    /// Round 8: 2.1 -> 4 mm and the lip 1.2 -> 2 mm, in step with the panel grooves in the maps (`HullPanels`).
    static let grooveHeight: Float = 0.004
    /// Lip height in metres, directly above the groove.
    static let lipHeight: Float = 0.002
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
/// 10 cm of near-black frame. The outer and inner edges stay where they are (the hull opening and the glass edge);
/// the boundaries between the strips move along each cross-section. Round 5 (pass-5 window: a hairline groove, the
/// hull running up to a thin dark frame, a bright inner rim on the glass edge) splits it into four bands, as
/// fractions of the width from the hull opening to the glass:
/// - `canopy_frame_bevel_0`, 0 to `outerLine`: the groove;
/// - `canopy_frame_bevel_1`, to `frameStart`: hull-coloured metal, so the surround reads as hull;
/// - `canopy_frame_bevel_2`, to 1 - `rim` (its glass-side edge moves in too): the dark frame. Round 6: about
///   4 cm (r5's 2-2.5 cm frame was lost beside the lit surround; the pass-5 frame is about 3 % of the window
///   width, ~4 cm);
/// - `canopy_inner_rim`, a copy of the inner strip, to the glass edge: the bright polished rim (about 0.8 cm).
@available(macOS 15.0, *)
@MainActor
enum GasketFrame {
    enum Role { case outerLine, surround, frame, rim }
    static let names = ["canopy_frame_bevel_0", "canopy_frame_bevel_1", "canopy_frame_bevel_2"]
    static let rimName = "canopy_inner_rim"
    /// Width fractions from the hull opening to the glass edge.
    static let outerLine: Float = 0.04
    static let frameStart: Float = 0.45
    static let rim: Float = 0.09

    static func role(_ name: String) -> Role? {
        switch name {
        case names[0]: return .outerLine
        case names[1]: return .surround
        case names[2]: return .frame
        case rimName: return .rim
        default: return nil
        }
    }

    /// The role of a mesh entity: the rim copy first (its meshes may keep the inner strip's names).
    static func role(of e: Entity) -> Role? {
        if ModelRocket.isUnder(e, rimName) { return .rim }
        return role(ModelRocket.partName(e))
    }

    static func key(_ p: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>(p * 10_000, rounding: .toNearestOrAwayFromZero) }

    /// Moves the shared edges between the strips and adds the rim. Leaves the meshes alone if they do not have the
    /// expected shape (three strips sharing two edge loops).
    static func reshape(in root: Entity) throws {
        let strips = names.map { root.findEntity(named: $0) }
        guard root.findEntity(named: rimName) == nil, strips.allSatisfy({ $0 != nil }) else { return }
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
        var moved: [SIMD3<Int32>: SIMD3<Float>] = [:], rimMoved: [SIMD3<Int32>: SIMD3<Float>] = [:]
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
            moved[key(p2)] = along(frameStart)
            // The frame stops where the rim starts (no two coplanar strips), the rim runs on to the glass edge.
            moved[key(p3)] = along(1 - rim)
            rimMoved[key(p2)] = along(1 - rim)
        }
        // The rim: a copy of the inner strip (its outer edge loop is edge 2, its inner edge the glass edge).
        let inner = strips[2]!
        let copy = inner.clone(recursive: true)
        copy.name = rimName
        inner.parent?.addChild(copy)
        var copies: [(entity: Entity, model: ModelComponent)] = []
        ModelRocket.forEachModel(copy) { e in
            if let model = e.components[ModelComponent.self] { copies.append((e, model)) }
        }
        for (strip, map) in meshes.map({ ($0, moved) }) + [(copies, rimMoved)] {
            for (e, model) in strip {
                var contents = model.mesh.contents
                var models: [MeshResource.Model] = []
                for var m in contents.models {
                    m.parts = MeshPartCollection(m.parts.map { (original: MeshResource.Part) -> MeshResource.Part in
                        var part = original
                        let positions = part.positions.elements.map { p -> SIMD3<Float> in
                            guard let to = map[key(e.convert(position: p, to: root))] else { return p }
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
///
/// Round 5 (pass 5: dark smoked glass, curved reflection streaks along the edges, the cockpit mostly in shadow):
/// darker and more opaque, and `EntranceLook.glassStudio` has two narrow bright strips that land near the glass's
/// left and right edges plus an overhead patch that curves along its top-left.
@available(macOS 15.0, *)
@MainActor
enum CanopyGlass {
    /// Round 8: 0.62 -> 0.5, so half of the (now brighter) cockpit shows through, as in the pass-5 window. The
    /// blending also scales the glass's own reflection, so `EntranceLook.glassEnvironmentExponent` went up 0.5.
    /// Round 10 (owner on r9: "the glass looks fake"): 0.5 laid a flat dark-milky layer over the cockpit. Real
    /// window glass passes most light: 0.3 of a dark blue-grey tint, and the reflection (dielectric Fresnel, so it
    /// grows toward the grazing edges) carries the glass; its environment exponent went up again to match.
    static let opacity: Float = 0.3
    /// The glass's own colour: a dark blue-grey, so what is seen through it is a little cooler and darker.
    static let tint = NSColor(srgbRed: 0.035, green: 0.045, blue: 0.06, alpha: 1)

    static func material() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: tint)
        m.metallic = 0.0
        m.roughness = 0.02
        m.specular = 1.0
        m.clearcoat = 1.0
        m.clearcoatRoughness = 0.01
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

    /// Screen brightness (multiplies every screen colour). The glass shows about 40 % of it.
    static let brightness: Float = 0.75
    /// Round 5: the file's full cockpit screen read as a bright dashboard behind clear glass; pass 5 shows a dim
    /// cockpit with a few small warm and white screens mostly in shadow. So the code panels are the default; true
    /// shows the file's screen image again (unlit, times `fileScreenBrightness`).
    static let useFileScreen = false
    static let fileScreenBrightness: CGFloat = 0.35

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

    /// What is drawn on the console, in its own plane (metres; the plane is 0.92 x 0.76, facing the window along
    /// +z): centre x, centre y, width, height, colour (sRGB), and whether it is a lit screen (soft glow, dim content
    /// lines) or dark structure (a housing a little lighter than the room, with a faint edge). Round 6 (r5 read as
    /// flat squares pasted on black): the console is one code-drawn texture with darker structure silhouettes and
    /// screens that glow into the room, plus two screens nearer the window (`nearScreens`) for depth.
    typealias Item = (x: Float, y: Float, w: Float, h: Float, rgb: SIMD3<Float>, lit: Bool)
    static let panels: [Item] = {
        let white: SIMD3<Float> = [0.78, 0.84, 0.95], dim: SIMD3<Float> = [0.22, 0.28, 0.38], amber: SIMD3<Float> = [0.95, 0.66, 0.32]
        let housing: SIMD3<Float> = [0.045, 0.05, 0.062], monitor: SIMD3<Float> = [0.03, 0.036, 0.048]
        let faint: SIMD3<Float> = [0.1, 0.13, 0.18]
        return [
            // Structure: two posts, a top beam, the two screen housings, the dark centre monitor, a lower desk.
            (-0.33, 0.0, 0.03, 0.76, housing, false), (0.33, 0.0, 0.03, 0.76, housing, false), (0.0, 0.22, 0.66, 0.035, housing, false),
            (-0.165, 0.0, 0.19, 0.2, housing, false), (0.19, 0.005, 0.17, 0.19, housing, false),
            (0.0, -0.02, 0.17, 0.14, monitor, false), (0.0, -0.2, 0.6, 0.06, housing, false),
            // Screens: white-blue and amber, small, mostly dim.
            (-0.21, 0.045, 0.075, 0.06, white, true), (-0.12, 0.045, 0.06, 0.06, amber, true),
            (-0.21, -0.04, 0.075, 0.05, dim, true), (-0.12, -0.04, 0.06, 0.05, white, true),
            (0.15, 0.05, 0.075, 0.065, dim, true), (0.23, 0.05, 0.05, 0.065, white, true),
            (0.15, -0.04, 0.075, 0.05, amber, true), (0.23, -0.04, 0.05, 0.05, dim, true),
            (0.0, -0.02, 0.12, 0.08, faint, true),
            (-0.36, -0.2, 0.014, 0.014, white, true), (-0.33, -0.2, 0.014, 0.014, amber, true), (0.35, -0.2, 0.014, 0.014, white, true),
        ]
    }()

    /// Two small screens nearer the window than the console (x, y, distance in front of it, width, height,
    /// colour), so the screens sit at different depths like the pass-5 cockpit.
    static let nearScreens: [(x: Float, y: Float, z: Float, w: Float, h: Float, rgb: SIMD3<Float>)] = [
        (-0.36, 0.1, 0.09, 0.07, 0.05, [0.78, 0.84, 0.95]), (0.37, -0.06, 0.06, 0.06, 0.045, [0.95, 0.66, 0.32]),
    ]

    enum ConsoleError: Error { case context }

    /// Draws `items` on a `width` x `height` metre panel at 1600 px per metre: a near-black room with a soft
    /// vignette, dark housings with a faint top edge, and screens with a blurred glow of their own colour and dim
    /// content lines. `margin` metres of room around the items lets a glow fade out before the quad's edge.
    static func consoleTexture(width mw: Float, height mh: Float, items: [Item]) throws -> CGImage {
        let scale: Float = 1600
        let w = Int(mw * scale), h = Int(mh * scale)
        guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ConsoleError.context }
        func color(_ rgb: SIMD3<Float>, _ k: Float = 1, alpha: CGFloat = 1) -> CGColor {
            CGColor(srgbRed: CGFloat(min(1, rgb.x * k)), green: CGFloat(min(1, rgb.y * k)), blue: CGFloat(min(1, rgb.z * k)), alpha: alpha)
        }
        // Room: darker towards the edges.
        let room: SIMD3<Float> = [0.018, 0.021, 0.028]
        c.setFillColor(color(room * 0.6))
        c.fill(CGRect(x: 0, y: 0, width: w, height: h))
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(room * 1.5), color(room * 0.6)] as CFArray,
                                     locations: [0, 1]) {
            c.drawRadialGradient(gradient, startCenter: CGPoint(x: w / 2, y: h / 2), startRadius: 0,
                                 endCenter: CGPoint(x: w / 2, y: h / 2), endRadius: CGFloat(max(w, h)) * 0.6, options: [.drawsAfterEndLocation])
        }
        func rect(_ i: Item) -> CGRect {
            CGRect(x: CGFloat((i.x - i.w / 2 + mw / 2) * scale), y: CGFloat((i.y - i.h / 2 + mh / 2) * scale),
                   width: CGFloat(i.w * scale), height: CGFloat(i.h * scale))
        }
        for i in items where !i.lit {
            let r = rect(i)
            c.setFillColor(color(i.rgb))
            c.fill(r)
            c.setFillColor(color(i.rgb, 1.8))
            c.fill(CGRect(x: r.minX, y: r.maxY - 2, width: r.width, height: 2))
        }
        for i in items where i.lit {
            let r = rect(i), k = brightness
            let corner = min(r.width, r.height) * 0.1
            // Glow: twice, a wide faint one and a tight one, from the screen's own shadow.
            for (blur, alpha) in [(max(r.width, r.height) * 1.1, CGFloat(0.55)), (max(r.width, r.height) * 0.3, CGFloat(0.8))] {
                c.saveGState()
                c.setShadow(offset: .zero, blur: blur, color: color(i.rgb, k, alpha: alpha))
                c.setFillColor(color(i.rgb, k * 0.8))
                c.addPath(CGPath(roundedRect: r, cornerWidth: corner, cornerHeight: corner, transform: nil))
                c.fillPath()
                c.restoreGState()
            }
            // Content: a darker inset with a few lighter lines, low contrast.
            c.setFillColor(color(i.rgb, k * 0.45))
            c.fill(r.insetBy(dx: r.width * 0.1, dy: r.height * 0.14))
            c.setFillColor(color(i.rgb, k * 1.1, alpha: 0.7))
            for line in 0..<3 {
                c.fill(CGRect(x: r.minX + r.width * 0.16, y: r.minY + r.height * (0.25 + 0.2 * CGFloat(line)),
                              width: r.width * (0.6 - 0.12 * CGFloat(line)), height: max(1, r.height * 0.05)))
            }
        }
        guard let image = c.makeImage() else { throw ConsoleError.context }
        return image
    }

    static func unlit(_ rgb: SIMD3<Float>) -> UnlitMaterial {
        let c = rgb * brightness
        var m = UnlitMaterial(color: NSColor(srgbRed: CGFloat(min(1, c.x)), green: CGFloat(min(1, c.y)), blue: CGFloat(min(1, c.z)), alpha: 1))
        m.faceCulling = .none
        return m
    }

    static func textured(_ image: CGImage) throws -> UnlitMaterial {
        let resource = try TextureResource.generate(from: image, options: .init(semantic: .color))
        var m = UnlitMaterial()
        m.color = .init(tint: .white, texture: .init(resource))
        m.faceCulling = .none
        return m
    }

    static func dress(_ e: Entity, name: String) {
        guard var model = e.components[ModelComponent.self] else { return }
        if name == screenPlane, useFileScreen, let screen = fileScreen(model.materials) {
            model.materials = model.materials.map { _ in screen }
            e.components.set(model)
            return
        }
        let room: SIMD3<Float> = name == screenPlane ? [0.012, 0.014, 0.019] : [0.014, 0.016, 0.021]
        let material = unlit(room)
        model.materials = model.materials.map { _ in material }
        e.components.set(model)
        guard name == screenPlane, e.findEntity(named: "cockpit-console") == nil,
              let console = try? textured(consoleTexture(width: 0.92, height: 0.76, items: panels))
        else { return }
        // On both faces of the plane (which face looks at the window is not checked on a render yet); the back
        // copy is turned round so it also reads the right way.
        for side: Float in [1, -1] {
            let quad = ModelEntity(mesh: .generatePlane(width: 0.92, height: 0.76), materials: [console])
            quad.name = "cockpit-console"
            quad.position = [0, 0, 0.004 * side]
            if side < 0 { quad.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) }
            e.addChild(quad)
            for (i, n) in nearScreens.enumerated() {
                // A small quad with the screen and its glow on room colour, so its edge disappears into the room.
                let item: Item = (0, 0, n.w, n.h, n.rgb, true)
                guard let near = try? textured(consoleTexture(width: n.w * 2.6, height: n.h * 3, items: [item])) else { continue }
                let screen = ModelEntity(mesh: .generatePlane(width: n.w * 2.6, height: n.h * 3), materials: [near])
                screen.name = "cockpit-screen-\(i)"
                screen.position = [n.x * side, n.y, n.z * side]
                if side < 0 { screen.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) }
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
    /// Multiplies the screen colours in the texture (round 5: dimmer, read as glows in a dark room, not cards).
    static let brightness: CGFloat = 0.45
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
    /// Round 5: fewer, smaller and dimmer (r4's side screens read as floating icon cards).
    static let screens: [(az: Float, y: Float, w: Float, h: Float, rgb: SIMD3<Float>)] = {
        let white: SIMD3<Float> = [0.75, 0.82, 0.95], dim: SIMD3<Float> = [0.3, 0.36, 0.46], amber: SIMD3<Float> = [1.0, 0.7, 0.36]
        return [
            (-120, 12.95, 0.09, 0.07, white), (-120, 12.83, 0.09, 0.05, dim), (-138, 13.05, 0.06, 0.06, amber),
            (120, 12.95, 0.09, 0.07, dim), (120, 12.83, 0.09, 0.05, white), (138, 13.05, 0.06, 0.06, white),
            (-158, 13.3, 0.05, 0.03, amber), (158, 13.3, 0.05, 0.03, dim),
        ]
    }()

    /// - Parameter screens: false draws the lining only (D142: the cockpit image carries the screens).
    static func add(to root: Entity, screens: Bool = true) throws {
        guard root.findEntity(named: name) == nil else { return }
        let image = try texture(screens: screens)
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
    static func texture(screens drawScreens: Bool = true) throws -> CGImage {
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
        let screens = drawScreens ? Self.screens : []
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

/// Round 5 finish: the hull's panel maps, drawn in code (no art files). The owner compared round 4 with the pass-5
/// art and found the seams and the material still clearly different: pass 5 has a dense panel grid (rings and
/// staggered vertical joints, small access hatches, a tip cap on the nose) cut as hairline grooves with a faint
/// light lip, on brushed metal with fine streaks and micro-scratches. The file's atlas has only a few long lines on
/// the capsule (its capsule strip is 137 px tall) and grime that read as dirt, so the hull is mapped around its
/// axis instead (`remap`: u = azimuth, 0.5 facing the window; v = height within the band) and gets two code-drawn
/// maps per band:
/// - albedo: plain panels at `base`, grooves darker, a thin lighter lip beside each groove, faint streaks and
///   lighter scratches (multiplied by the theme tint, so one map serves both finishes);
/// - normal: the same grooves, lips and scratches as a height field, plus the brushed grain, so the studio strips
///   break along the seams and shimmer along the grain.
/// Two bands: the capsule (y 11.8-14.2, 4096 x 2048, about 7 px per cm, for the window close-up and the end pose)
/// and the body (y 0.24-11.8, 2048 x 2048, seen whole). The section joints stay geometry (`JointLine`); the maps
/// add the rings between them.
@available(macOS 15.0, *)
@MainActor
enum HullPanels {
    struct Band: Sendable {
        let name: String
        let bottom: Float, top: Float
        let width: Int, height: Int
    }

    struct Maps {
        let albedo: TextureResource
        let normal: TextureResource
    }

    static let capsule = Band(name: "capsule", bottom: 11.8, top: 14.2, width: 4096, height: 2048)
    static let body = Band(name: "body", bottom: 0.24, top: 11.8, width: 2048, height: 2048)
    static let capsuleParts: Set<String> = ["capsule_lower", "capsule_aperture_shell", "capsule_nose"]

    static func band(for name: String) -> Band? {
        if capsuleParts.contains(name) { return capsule }
        return HullFinish.hullParts.contains(name) ? body : nil
    }

    // MARK: Knobs

    /// Albedo of a plain panel (the theme tint multiplies it).
    static let base: Float = 0.74
    /// Groove and lip widths in metres (clamped to at least one texel). Round 6: r5's 2.5 / 1.2 mm vanished at the
    /// close-up's scale (about 5 px per cm, then the 2x downsample); 4 / 2.5 mm are 2 and 1.2 output pixels there.
    /// Round 8 (r7b: the grid still too faint at the full close-up; pass 5's grooves read as about 2-3 px dark lines
    /// with a light edge at a smaller scale): 6 / 3 mm, about 2.8 and 1.4 px in the close-up.
    /// Round 10 (owner: fine panel seams, not tiles): 5 / 2.5 mm.
    static let grooveWidth: Float = 0.005
    static let lipWidth: Float = 0.0025
    /// How much darker a groove is (0-1) and how far a lip goes toward white.
    static let grooveDark: Float = 0.85
    static let lipLight: Float = 0.8
    /// Round 6: a soft shadow beside every groove (`aoWidth` metres each side, `aoStrength` darkening) and a
    /// matching gentle slope into it in the normal map, so a seam still reads where the hairline itself is sub-pixel.
    /// Round 8: the blur runs twice (a tent, not a flat band) and is normalised so the shade is 1 at the groove and
    /// falls off linearly to nothing at about 2 x `aoWidth`; 8 mm and 0.55 (r7b: 6 mm, 0.45, a flat band at ~0.8).
    /// Round 10: strength 0.55 -> 0.4 (thin, shallow seams).
    static let aoWidth: Float = 0.008
    static let aoStrength: Float = 0.4
    /// Brushed grain: albedo streak contrast; the grain runs around the hull or along it, chosen per panel, and
    /// each panel's tone varies by up to +-`panelTone` (pass 5's panels are not one flat sheet).
    static let brush: Float = 0.06
    /// Round 8: 0.05 -> 0.07, so neighbouring panels separate a little more (pass 5's grid reads partly by tone).
    static let panelTone: Float = 0.07
    static let scratchLight: Float = 0.3

    /// Round 11 (owner on r10: the lower body still reads "block by block" next to the pass-5 prototype, whose
    /// seams are hairlines, slightly darker than the metal): the body band gets lighter seams than the capsule
    /// (whose window close-up keeps the round-10 values): a groove that only darkens, almost no lip, a faint
    /// shadow beside it, and more tone difference between panels (pass 5's panels separate by tone, not by
    /// trenches).
    struct Weights {
        let grooveDark: Float, lipLight: Float, aoStrength: Float, grooveSlope: Float, panelTone: Float
    }
    static func weights(_ band: Band) -> Weights {
        band.name == "body"
            ? Weights(grooveDark: 0.55, lipLight: 0.25, aoStrength: 0.1, grooveSlope: 0.08, panelTone: 0.2)
            : Weights(grooveDark: grooveDark, lipLight: lipLight, aoStrength: aoStrength, grooveSlope: grooveSlope, panelTone: panelTone)
    }
    /// Round 10 (owner on r9: up close, at the end of the approach, at the hand-over and on the lower body at night,
    /// the hull read as ceramic tile or rough plaster): the normal map now carries ONLY the seams (groove, lip and a
    /// shallow slope into the groove) at a lower strength (1.5 -> 1.0). Grain, scratches and the detail tile no
    /// longer bump the surface (`grainHeight`, `scratchHeight`, `detailHeight` 0); the panels are smooth, and
    /// the brushed look comes from the anisotropic highlight and a faint albedo grain.
    static let normalStrength: Float = 1.0
    static let grooveSlope: Float = 0.3
    static let grainHeight: Float = 0
    static let scratchHeight: Float = 0
    /// Micro-scratches per band.
    static let scratches: [String: Int] = ["capsule": 9000, "body": 7000]

    // MARK: Layout (metres, degrees; azimuth 0 faces the window, +x is positive)

    /// The section joints drawn as geometry by `JointLine` (and the band ends): the maps draw no line here.
    static let joints: [Float] = [0.24, 1.88, 5.2, 6.57, 7.63, 10.7, 11.8, 13.56, 14.2]
    /// Rings drawn in the maps. On the capsule as on the pass-5 window still: a narrow sill band under the window
    /// (12.06, 12.29), a ring just above it (13.35), two rings on the nose and the tip cap (14.12).
    /// Round 9 (D146): the sill ring and the ring above the window follow the new window (`sillRing`, `aboveRing`).
    /// Round 11 (pass 5's middle and lower body): one ring across the lower stage (3.05), a narrow ring band under
    /// the taper (5.02-5.2) and above it (6.57-6.95), one ring round the taper's middle (5.9) and two on the upper
    /// body (9.15, 11.25), so the panels are tall and narrow (r10: rings every 0.85 m made wide plates).
    static let rings: [Float] = [3.05, 5.02, 5.9, 6.95, 9.15, 11.25, 12.06, sillRing, aboveRing, 13.78, 13.98, 14.12]
    /// Just under the window's surround, and a little above it, like the pass-5 window still.
    static var sillRing: Float { WindowShape.bottom - WindowShape.bandsWidth - 0.012 }
    static var aboveRing: Float { WindowShape.top + WindowShape.bandsWidth + 0.03 }
    static let tipCap: Float = 14.12

    /// Vertical seams of the panel row that starts at `y` (the `k`-th row from the bottom). The body has eight
    /// seams per row at the file's axial-seam azimuths (12.5 + 45 n), staggered every other row like brickwork.
    /// The capsule follows the pass-5 still: no seam down the middle of the window side; seams at the window's
    /// corners below it, beside it in the window row, and a pair at +-17 degrees from above the window to the tip cap.
    static func seamAzimuths(row y: Float, index k: Int) -> [Float] {
        func both(_ a: [Float]) -> [Float] { a.flatMap { $0 >= 180 ? [180] : [-$0, $0] } }
        switch y {
        case ..<11.79:
            // Round 11: tall narrow panels whose seams line up from row to row, as on pass 5 (r10: eight seams per
            // row, staggered like brickwork, read as tiles). The lower stage and skirt have 12 (0.61 m wide), the
            // taper and upper body 16 (0.35-0.45 m), the narrow ring bands 24.
            let count: Int
            switch y {
            case ..<5.01: count = 12
            case ..<5.19: count = 24
            case ..<6.56: count = 16
            case ..<6.94: count = 24
            default: count = 16
            }
            let step = 360 / Float(count)
            return (0..<count).map { i in
                let a = step / 2 + step * Float(i)
                return a > 180 ? a - 360 : a
            }
        case ..<(sillRing - 0.01): return both([52, 100, 145, 180])
        case ..<(aboveRing - 0.01): return both([60, 105, 150])
        case ..<13.55: return both([17, 60, 105, 150])
        case ..<13.77: return both([17, 75, 130])
        case ..<13.97: return both([17, 80, 140])
        case ..<14.11: return both([17, 100])
        default: return []
        }
    }

    /// The hull's outer radius by height (the capsule from `CockpitCeiling.profile`, the body from the file's
    /// sections).
    static func radius(_ y: Float) -> Float {
        if y >= 11.8 { return CockpitCeiling.radius(y) }
        if y >= 6.57 { return 0.894 }
        if y >= 5.2 { return 1.152 + (0.896 - 1.152) * (y - 5.2) / (6.57 - 5.2) }
        if y >= 1.89 { return 1.17 }
        return 1.2
    }

    // MARK: Mapping

    /// Repeat around the hull (the wrap behind the rocket uses u slightly above 1), clamp along it; trilinear and
    /// anisotropic filtering keep the hairlines steady at grazing angles.
    static func texture(_ resource: TextureResource) -> MaterialParameters.Texture {
        var texture = MaterialParameters.Texture(resource)
        texture.sampler = sampler()
        return texture
    }

    static func sampler() -> MaterialParameters.Texture.Sampler {
        let d = MTLSamplerDescriptor()
        d.sAddressMode = .repeat
        d.tAddressMode = .clampToEdge
        d.minFilter = .linear
        d.magFilter = .linear
        d.mipFilter = .linear
        d.maxAnisotropy = 8
        return .init(d)
    }

    /// The mesh with texture coordinates around the root's y axis: u = azimuth / 360 + 0.5 (0.5 = +z, the window
    /// side), v = (height - bottom) / (top - bottom). Triangles across the wrap behind the rocket get copies of
    /// their low-u corners at u + 1; a corner on the axis (the nose tip) takes the mean u of the others.
    static func remap(_ mesh: MeshResource, entity: Entity, root: Entity, band: Band) throws -> MeshResource {
        let matrix = entity.transformMatrix(relativeTo: root)
        var contents = mesh.contents
        var models: [MeshResource.Model] = []
        for var model in contents.models {
            model.parts = MeshPartCollection(model.parts.map { cylindrical($0, matrix: matrix, band: band) })
            models.append(model)
        }
        contents.models = MeshModelCollection(models)
        return try MeshResource.generate(from: contents)
    }

    static func cylindrical(_ part: MeshResource.Part, matrix: simd_float4x4, band: Band) -> MeshResource.Part {
        guard let triangles = part.triangleIndices?.elements, triangles.count >= 3 else { return part }
        var positions = part.positions.elements
        guard triangles.allSatisfy({ Int($0) < positions.count }) else { return part }
        let given = part.normals?.elements
        var normals = given?.count == positions.count ? given : nil
        var uvs: [SIMD2<Float>] = [], onAxis: [Bool] = []
        for p in positions {
            let q = matrix * SIMD4<Float>(p.x, p.y, p.z, 1)
            uvs.append(SIMD2<Float>(atan2(q.x, q.z) / (2 * Float.pi) + 0.5, (q.y - band.bottom) / (band.top - band.bottom)))
            onAxis.append(q.x * q.x + q.z * q.z < 1e-8)
        }
        var copies: [SIMD2<UInt32>: UInt32] = [:]
        func vertex(_ v: UInt32, u: Float) -> UInt32 {
            if uvs[Int(v)].x == u { return v }
            let key = SIMD2<UInt32>(v, u.bitPattern)
            if let copy = copies[key] { return copy }
            positions.append(positions[Int(v)])
            if normals != nil { normals!.append(normals![Int(v)]) }
            uvs.append(SIMD2<Float>(u, uvs[Int(v)].y))
            onAxis.append(onAxis[Int(v)])
            let copy = UInt32(positions.count - 1)
            copies[key] = copy
            return copy
        }
        var indices: [UInt32] = []
        indices.reserveCapacity(triangles.count)
        for f in 0..<(triangles.count / 3) {
            let corners = [triangles[3 * f], triangles[3 * f + 1], triangles[3 * f + 2]]
            var us = corners.map { uvs[Int($0)].x }
            let regular = (0..<3).filter { !onAxis[Int(corners[$0])] }
            if let lo = regular.map({ us[$0] }).min(), let hi = regular.map({ us[$0] }).max(), hi - lo > 0.5 {
                for k in regular where us[k] < 0.5 { us[k] += 1 }
            }
            let mean = regular.isEmpty ? 0.5 : regular.map { us[$0] }.reduce(0, +) / Float(regular.count)
            for k in 0..<3 where onAxis[Int(corners[k])] { us[k] = mean }
            for k in 0..<3 { indices.append(vertex(corners[k], u: us[k])) }
        }
        var result = MeshResource.Part(id: part.id, materialIndex: part.materialIndex)
        result.positions = MeshBuffers.Positions(positions)
        if let normals { result.normals = MeshBuffers.Normals(normals) }
        result.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        result.triangleIndices = MeshBuffer<UInt32>(indices)
        return result
    }

    // MARK: Maps

    static var cache: [String: Maps] = [:]

    /// D142: a generated brushed-steel tile replaces the code grain and scratches when the pack has one. It is
    /// tiled every `detailTile` metres (rotated a quarter turn on panels whose grain runs along the hull) and enters
    /// the albedo at `detailAlbedo` and the height (normal map) at `detailHeight` per standard deviation.
    ///
    /// Round 10: the tile was point-sampled at the map's texel spacing (about 11 tile texels per map texel on the
    /// body, 2-3 on the capsule), so the maps got aliased noise instead of brushing, which the normal map turned into
    /// bumps: the "ceramic tile / plaster" of r9. It is now box-filtered over each map texel's footprint (a rip-map
    /// per level pair, `Detail.box`) and enters the albedo only (`detailAlbedo` 0.05 -> 0.08 of the filtered value,
    /// whose spread is smaller); `detailHeight` is 0.
    static let detailTile: Float = 0.5
    static let detailAlbedo: Float = 0.08
    static let detailHeight: Float = 0

    /// A greyscale detail tile, normalised to zero mean and unit deviation (clamped to +-3).
    struct Detail {
        let size: Int
        let values: [Float]

        init?(_ image: CGImage) {
            let n = 1024
            var grey = [UInt8](repeating: 0, count: n * n)
            let drawn = grey.withUnsafeMutableBytes { buffer -> Bool in
                guard let c = CGContext(data: buffer.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n,
                                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
                else { return false }
                c.interpolationQuality = .high
                c.draw(image, in: CGRect(x: 0, y: 0, width: n, height: n))
                return true
            }
            guard drawn else { return nil }
            let raw = grey.map { Float($0) / 255 }
            let mean = raw.reduce(0, +) / Float(raw.count)
            let deviation = max(0.01, (raw.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(raw.count)).squareRoot())
            size = n
            values = raw.map { min(3, max(-3, ($0 - mean) / deviation)) }
        }

        /// The tile averaged over boxes of 2^lx x 2^ly texels: (size >> lx) x (size >> ly) values.
        func box(_ lx: Int, _ ly: Int) -> [Float] {
            let n = size, fx = 1 << lx, fy = 1 << ly, wx = n >> lx, wy = n >> ly
            var out = [Float](repeating: 0, count: wx * wy)
            let norm = 1 / Float(fx * fy)
            values.withUnsafeBufferPointer { v in
                for y in 0..<wy {
                    for x in 0..<wx {
                        var sum: Float = 0
                        for j in 0..<fy {
                            let row = (y * fy + j) * n + x * fx
                            for i in 0..<fx { sum += v[row + i] }
                        }
                        out[y * wx + x] = sum * norm
                    }
                }
            }
            return out
        }

        /// The rip-map level (0...10) for a footprint of `texels` tile texels.
        static func level(_ texels: Float) -> Int { min(10, max(0, Int(log2(max(1, texels)).rounded()))) }
    }

    /// Both bands' maps (made once per process and detail source), or nil if a texture could not be made.
    static func maps(detail image: CGImage? = nil) -> [String: Maps]? {
        var result: [String: Maps] = [:]
        let detail = image.flatMap(Detail.init)
        for band in [capsule, body] {
            let key = band.name + (detail != nil ? "+detail" : "")
            if let hit = cache[key] { result[band.name] = hit; continue }
            guard let drawn = try? images(band, detail: detail),
                  let albedo = try? TextureResource.generate(from: drawn.albedo, options: .init(semantic: .color)),
                  let normal = try? TextureResource.generate(from: drawn.normal, options: .init(semantic: .normal))
            else { return nil }
            let maps = Maps(albedo: albedo, normal: normal)
            cache[key] = maps
            result[band.name] = maps
        }
        return result
    }

    enum MapError: Error { case context }

    /// A small deterministic random generator (the maps are the same on every run).
    struct Random {
        var state: UInt64
        mutating func next() -> Float {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(state >> 40) / Float(1 << 24)
        }
        mutating func signed() -> Float { next() * 2 - 1 }
    }

    /// The albedo and normal images of one band.
    static func images(_ band: Band, detail: Detail? = nil) throws -> (albedo: CGImage, normal: CGImage) {
        let w = band.width, h = band.height
        // Masks, drawn additively with CoreGraphics: red = grooves, green = lips, blue = scratches. Drawing y is
        // texture v (CoreGraphics' origin is bottom left; the image's top row is v = 1).
        guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw MapError.context }
        c.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        c.fill(CGRect(x: 0, y: 0, width: w, height: h))
        c.setBlendMode(.plusLighter)
        let groove = CGColor(red: 1, green: 0, blue: 0, alpha: 1), lip = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
        let span = band.top - band.bottom
        let pxPerMetreV = CGFloat(Float(h) / span)
        func pxPerMetreU(_ y: Float) -> CGFloat { CGFloat(Float(w) / (2 * .pi * max(0.05, radius(y)))) }
        func x(_ az: Float) -> CGFloat { CGFloat((az / 360 + 0.5) * Float(w)) }
        func yv(_ y: Float) -> CGFloat { CGFloat((y - band.bottom) / span) * CGFloat(h) }
        let grooveV = max(1, CGFloat(grooveWidth) * pxPerMetreV), lipV = max(0.8, CGFloat(lipWidth) * pxPerMetreV)

        // Rings: a groove across the whole width, the lip just above it (the key light comes from above).
        for y in rings where y > band.bottom && y < band.top {
            let cy = yv(y)
            let g = y == tipCap ? grooveV * 1.6 : grooveV
            c.setFillColor(groove)
            c.fill(CGRect(x: 0, y: cy - g / 2, width: CGFloat(w), height: g))
            c.setFillColor(lip)
            c.fill(CGRect(x: 0, y: cy + g / 2, width: CGFloat(w), height: lipV))
        }
        // Vertical seams, row by row, with the lip on the left (the key is top left); the width in texels follows
        // the radius so the groove stays the same in metres up the nose.
        let heights = Array(Set(rings + joints)).sorted()
        var random = Random(state: band.name == "capsule" ? 0x5EED_CA95 : 0x5EED_B0D4)
        // Per-panel tone and grain direction (round 6), one grey byte per texel: below 128 the grain runs around
        // the hull, from 128 along it; the rest is the tone. Not antialiased, so no edge texel mixes two panels
        // (the grooves cover the edges anyway).
        guard let tone = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { throw MapError.context }
        tone.setShouldAntialias(false)
        tone.setFillColor(gray: 60 / 255, alpha: 1)
        tone.fill(CGRect(x: 0, y: 0, width: w, height: h))
        func panel(_ a0: Float, _ a1: Float, _ y0: Float, _ y1: Float) {
            // Round 11: every body panel is brushed along the hull (pass 5's fine vertical brushing).
            let along = band.name == "body" || random.next() < 0.35
            let level = (along ? 150 : 20) + 80 * random.next()
            tone.setFillColor(gray: CGFloat(level / 255), alpha: 1)
            let lo = yv(max(y0, band.bottom)), hi = yv(min(y1, band.top))
            for shift: Float in [0, -360] where a1 + shift > -180 {
                tone.fill(CGRect(x: x(a0 + shift), y: lo, width: x(a1 + shift) - x(a0 + shift), height: hi - lo))
            }
        }
        for (k, (y0, y1)) in zip(heights, heights.dropFirst()).enumerated() where y1 > band.bottom && y0 < band.top {
            let azimuths = seamAzimuths(row: y0, index: k).sorted()
            if azimuths.isEmpty { panel(-180, 180, y0, y1) }
            for (i, a0) in azimuths.enumerated() { panel(a0, i + 1 < azimuths.count ? azimuths[i + 1] : azimuths[0] + 360, y0, y1) }
            let steps = 24
            // A seam at 180 degrees sits on the wrap: draw it at both edges of the map.
            for az in azimuths + (azimuths.contains(180) ? [-180] : []) {
                for s in 0..<steps {
                    let ya = y0 + (y1 - y0) * Float(s) / Float(steps), yb = y0 + (y1 - y0) * Float(s + 1) / Float(steps)
                    let perU = pxPerMetreU((ya + yb) / 2)
                    let g = min(8, max(1, CGFloat(grooveWidth) * perU)), l = min(4, max(0.8, CGFloat(lipWidth) * perU))
                    let cx = x(az)
                    c.setFillColor(groove)
                    c.fill(CGRect(x: cx - g / 2, y: yv(ya), width: g, height: yv(yb) - yv(ya)))
                    c.setFillColor(lip)
                    c.fill(CGRect(x: cx - g / 2 - l, y: yv(ya), width: l, height: yv(yb) - yv(ya)))
                }
            }
            // Access hatches: about two panels in five get a small rounded hatch near a corner, some body panels a
            // larger one in the middle. Not in the window row between its side seams.
            guard azimuths.count >= 2, y1 - y0 > 0.14 else { continue }
            for (i, a0) in azimuths.enumerated() {
                let a1 = i + 1 < azimuths.count ? azimuths[i + 1] : azimuths[0] + 360
                if y0 >= sillRing - 0.01 && y1 <= aboveRing + 0.01 && a0 < 0 && a1 > 0 { continue }
                let roll = random.next()
                let r = radius((y0 + y1) / 2), arc = (a1 - a0) * .pi / 180 * r
                guard arc > 0.14 else { continue }
                var size: (w: Float, h: Float)?, centre: (az: Float, y: Float) = (0, 0)
                if roll < 0.22 {
                    size = (0.03, 0.045)
                    centre = (a0 + (0.05 / r) * 180 / .pi, y1 - 0.055)
                } else if roll < 0.4 {
                    size = (0.035, 0.05)
                    centre = (a1 - (0.055 / r) * 180 / .pi, y0 + 0.06)
                } else if roll < 0.5, band.name == "body", y1 - y0 > 0.6, arc > 0.5 {
                    size = (0.14, 0.22)
                    centre = ((a0 + a1) / 2, (y0 + y1) / 2)
                }
                guard let size else { continue }
                let perU = pxPerMetreU(centre.y)
                let rect = CGRect(x: x(centre.az > 180 ? centre.az - 360 : centre.az) - CGFloat(size.w) * perU / 2,
                                  y: yv(centre.y) - CGFloat(size.h) * pxPerMetreV / 2,
                                  width: CGFloat(size.w) * perU, height: CGFloat(size.h) * pxPerMetreV)
                let corner = min(rect.width, rect.height) * 0.18
                c.setLineWidth(max(1, grooveV * 0.8))
                c.setStrokeColor(groove)
                c.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
                c.strokePath()
                c.setLineWidth(lipV)
                c.setStrokeColor(lip)
                c.addPath(CGPath(roundedRect: rect.offsetBy(dx: -grooveV * 0.8, dy: grooveV * 0.8), cornerWidth: corner,
                                 cornerHeight: corner, transform: nil))
                c.strokePath()
            }
        }
        // Round 11: dark marks multiplied into the albedo (rivet heads, slot recesses, grime streaks), one grey byte
        // per texel, added up.
        guard let marks = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { throw MapError.context }
        marks.setFillColor(gray: 0, alpha: 1)
        marks.fill(CGRect(x: 0, y: 0, width: w, height: h))
        marks.setBlendMode(.plusLighter)
        // Lighter marks (worn streaks and scuffs), the same way, mixed toward white.
        guard let lights = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                     space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { throw MapError.context }
        lights.setFillColor(gray: 0, alpha: 1)
        lights.fill(CGRect(x: 0, y: 0, width: w, height: h))
        lights.setBlendMode(.plusLighter)
        if band.name == "body" {
            // Round 11 (owner on r10: "block by block"; pass 5's middle and lower body have many fine seams, ring
            // bands with small slots at the section joints, rivet rows, rectangular access panels, a tall door and
            // grime streaks running down from the seams). Its own random stream, so the capsule maps stay as they were.
            var r = Random(state: 0x5EED_B0D5)
            func wrapped(_ rect: CGRect, _ draw: (CGRect) -> Void) {
                for dx in [0, -CGFloat(w), CGFloat(w)] { draw(rect.offsetBy(dx: dx, dy: 0)) }
            }
            func px(_ az: Float) -> CGFloat { x(az >= 180 ? az - 360 : (az < -180 ? az + 360 : az)) }
            /// A seam down part of a panel (groove plus its lip on the left), stepped so it follows the radius.
            func cutDown(_ az: Float, _ y0: Float, _ y1: Float) {
                let steps = 8
                for s in 0..<steps {
                    let ya = y0 + (y1 - y0) * Float(s) / Float(steps), yb = y0 + (y1 - y0) * Float(s + 1) / Float(steps)
                    let perU = pxPerMetreU((ya + yb) / 2)
                    let g = min(8, max(1, CGFloat(grooveWidth) * perU)), l = min(4, max(0.8, CGFloat(lipWidth) * perU))
                    let cx = px(az)
                    c.setFillColor(groove)
                    wrapped(CGRect(x: cx - g / 2, y: yv(ya), width: g, height: yv(yb) - yv(ya))) { c.fill($0) }
                    c.setFillColor(lip)
                    wrapped(CGRect(x: cx - g / 2 - l, y: yv(ya), width: l, height: yv(yb) - yv(ya))) { c.fill($0) }
                }
            }
            /// A seam across one panel, the lip above it.
            func cutAcross(_ a0: Float, _ a1: Float, _ y: Float) {
                let x0 = px(a0), width = CGFloat((a1 - a0) / 360) * CGFloat(w), cy = yv(y)
                c.setFillColor(groove)
                wrapped(CGRect(x: x0, y: cy - grooveV / 2, width: width, height: grooveV)) { c.fill($0) }
                c.setFillColor(lip)
                wrapped(CGRect(x: x0, y: cy + grooveV / 2, width: width, height: lipV)) { c.fill($0) }
            }
            /// A rounded rectangle cut into the skin (access panel, door, slot), `fill` darkening its inside.
            func outline(_ az: Float, _ y: Float, _ mw: Float, _ mh: Float, corner k: CGFloat = 0.18, fill: CGFloat = 0) {
                let perU = pxPerMetreU(y)
                let rect = CGRect(x: px(az) - CGFloat(mw) * perU / 2, y: yv(y) - CGFloat(mh) * pxPerMetreV / 2,
                                  width: CGFloat(mw) * perU, height: CGFloat(mh) * pxPerMetreV)
                let corner = min(rect.width, rect.height) * k
                wrapped(rect) { box in
                    if fill > 0 {
                        marks.setFillColor(gray: fill, alpha: 1)
                        marks.addPath(CGPath(roundedRect: box, cornerWidth: corner, cornerHeight: corner, transform: nil))
                        marks.fillPath()
                    }
                    c.setLineWidth(max(1, grooveV * 0.8))
                    c.setStrokeColor(groove)
                    c.addPath(CGPath(roundedRect: box, cornerWidth: corner, cornerHeight: corner, transform: nil))
                    c.strokePath()
                    c.setLineWidth(lipV)
                    c.setStrokeColor(lip)
                    c.addPath(CGPath(roundedRect: box.offsetBy(dx: -grooveV * 0.8, dy: grooveV * 0.8), cornerWidth: corner,
                                     cornerHeight: corner, transform: nil))
                    c.strokePath()
                }
            }
            func dot(_ az: Float, _ y: Float, _ level: CGFloat) {
                let d = max(1.2, 0.006 * pxPerMetreU(y))
                marks.setFillColor(gray: level, alpha: 1)
                wrapped(CGRect(x: px(az) - d / 2, y: yv(y) - d / 2, width: d, height: d)) { marks.fill($0) }
            }
            // Second sheets: about a third of the tall panels are split by a seam down part of them (the part to
            // the right a different tone), a fifth by a seam across.
            for (k, (y0, y1)) in zip(heights, heights.dropFirst()).enumerated() where y1 > band.bottom && y0 < band.top {
                guard y1 - y0 > 0.5 else { continue }
                let azimuths = seamAzimuths(row: y0, index: k).sorted()
                for (i, a0) in azimuths.enumerated() {
                    let a1 = i + 1 < azimuths.count ? azimuths[i + 1] : azimuths[0] + 360
                    let roll = r.next()
                    if roll < 0.32 {
                        let mid = a0 + (a1 - a0) * (0.4 + 0.2 * r.next())
                        let top = r.next() < 0.5 ? y1 : y0 + (y1 - y0) * (0.45 + 0.4 * r.next())
                        panel(mid, a1, y0, top)
                        cutDown(mid, y0, top)
                        if top < y1 { cutAcross(mid, a1, top) }
                    } else if roll < 0.52 {
                        let y = y0 + (y1 - y0) * (0.25 + 0.5 * r.next())
                        panel(a0, a1, y0, y)
                        cutAcross(a0, a1, y)
                    }
                }
            }
            // Round 11c (pass 5: each section joint is a dark recessed band, two parallel dark grooves with small
            // rectangular slots between them; the lower ring and the ring bands' edges are strong dark lines too).
            // Drawn as wide grooves (normal map) plus dark marks, so they stay dark although body seams are light.
            func strongLine(_ y: Float, _ metres: Float, _ level: CGFloat) {
                let hpx = max(1.5, CGFloat(metres) * pxPerMetreV), cy = yv(y)
                c.setFillColor(groove)
                c.fill(CGRect(x: 0, y: cy - hpx / 2, width: CGFloat(w), height: hpx))
                marks.setFillColor(gray: level, alpha: 1)
                marks.fill(CGRect(x: 0, y: cy - hpx / 2 - 1, width: CGFloat(w), height: hpx + 2))
                c.setFillColor(lip)
                c.fill(CGRect(x: 0, y: cy + hpx / 2, width: CGFloat(w), height: lipV))
            }
            for y in joints where y > band.bottom + 0.05 && y < band.top - 0.05 {
                strongLine(y - 0.028, 0.009, 0.6)
                strongLine(y + 0.028, 0.009, 0.6)
                for i in 0..<36 {
                    guard r.next() < 0.6 else { continue }
                    outline(10 * Float(i) + 5, y, 0.045, 0.022, corner: 0.15, fill: 0.6)
                }
            }
            for y: Float in [3.05, 5.02, 6.95] { strongLine(y, 0.008, 0.5) }
            // Panel-scale grime (pass 5's panels are mottled and darker along their edges, not one clean sheet):
            // a dark wash fading down from the top edge of most panels, a darker strip down one side of some, and
            // soft blotches.
            for (k, (y0, y1)) in zip(heights, heights.dropFirst()).enumerated() where y1 > band.bottom && y0 < band.top {
                let azimuths = seamAzimuths(row: y0, index: k).sorted()
                for (i, a0) in azimuths.enumerated() {
                    let a1 = i + 1 < azimuths.count ? azimuths[i + 1] : azimuths[0] + 360
                    let x0 = px(a0), width = CGFloat((a1 - a0) / 360) * CGFloat(w)
                    if r.next() < 0.75 {
                        let depth = min(y1 - y0, 0.06 + 0.25 * r.next()), strength = 0.06 + 0.16 * r.next()
                        for s in 0..<8 {
                            let ya = y1 - depth * Float(s) / 8, yb = y1 - depth * Float(s + 1) / 8
                            marks.setFillColor(gray: CGFloat(strength * (1 - Float(s) / 8)), alpha: 1)
                            wrapped(CGRect(x: x0, y: yv(yb), width: width, height: yv(ya) - yv(yb))) { marks.fill($0) }
                        }
                    }
                    if r.next() < 0.4 {
                        let side = CGFloat(0.02 + 0.06 * r.next()) * pxPerMetreU((y0 + y1) / 2)
                        let left = r.next() < 0.5, strength = CGFloat(0.05 + 0.1 * r.next())
                        for s in 0..<6 {
                            marks.setFillColor(gray: strength * CGFloat(6 - s) / 6, alpha: 1)
                            let sx = left ? x0 + side * CGFloat(s) / 6 : x0 + width - side * CGFloat(s + 1) / 6
                            wrapped(CGRect(x: sx, y: yv(y0), width: side / 6, height: yv(y1) - yv(y0))) { marks.fill($0) }
                        }
                    }
                }
            }
            for _ in 0..<700 {
                let az = r.signed() * 180, y = band.bottom + r.next() * span
                let size = 0.08 + 0.35 * r.next(), strength = 0.015 + 0.03 * r.next()
                let target = r.next() < 0.35 ? lights : marks
                let perU = pxPerMetreU(y)
                for ring in 1...5 {
                    let f = CGFloat(ring) / 5
                    let rw = CGFloat(size) * perU * f, rh = CGFloat(size * (1 + r.next())) * pxPerMetreV * f
                    target.setFillColor(gray: CGFloat(strength), alpha: 1)
                    wrapped(CGRect(x: px(az) - rw / 2, y: yv(y) - rh / 2, width: rw, height: rh)) { target.fillEllipse(in: $0) }
                }
            }
            // Rivet rows beside every ring and joint, in runs (pass 5's seams are dotted here and there).
            for y in Set(rings + joints) where y > band.bottom + 0.05 && y < band.top - 0.05 {
                for side: Float in [-0.022, 0.022] {
                    let n = Int(2 * .pi * radius(y + side) / 0.07)
                    var on = true
                    for j in 0..<n {
                        if j % 6 == 0 { on = r.next() < 0.55 }
                        if on { dot(-180 + 360 * Float(j) / Float(n), y + side, 0.32) }
                    }
                }
            }
            // Rivet columns beside some lower-stage seams.
            for az in seamAzimuths(row: 1.88, index: 0) {
                guard r.next() < 0.4 else { continue }
                let offset = 0.022 / radius(3) * 180 / .pi
                var y: Float = 1.95
                while y < 5.0 { dot(az + offset, y, 0.28); y += 0.08 }
            }
            // The ring bands under and above the taper: a small dark slot in about half their panels.
            for top: Float in [5.2, 6.95] {
                for i in 0..<24 {
                    guard r.next() < 0.5 else { continue }
                    outline(15 * Float(i), top - 0.065, 0.05, 0.045, corner: 0.1, fill: 0.55)
                }
            }
            // Skirt: tall slots and small access panels.
            for i in 0..<12 {
                let roll = r.next()
                if roll < 0.45 {
                    outline(30 * Float(i) + 8 * r.signed(), 0.95 + 0.25 * r.signed(), 0.06, 0.16, corner: 0.15, fill: 0.6)
                } else if roll < 0.7 {
                    outline(30 * Float(i) + 6 * r.signed(), 1.4, 0.13, 0.08, corner: 0.1, fill: 0.15)
                }
            }
            // On the side the camera sees: the tall door and an L-shaped hatch on the lower stage, a pair of conduit
            // lines beside them, a small hatch and a conduit on the upper body.
            outline(6, 2.55, 0.2, 0.95, corner: 0.05, fill: 0.06)
            outline(-4, 2.3, 0.11, 0.42, corner: 0.15)
            outline(-4, 2.42, 0.05, 0.1, corner: 0.2, fill: 0.4)
            cutDown(11, 2.1, 3.05); cutDown(12, 2.1, 3.05)
            outline(2, 9.45, 0.07, 0.1, corner: 0.2, fill: 0.35)
            cutDown(4.5, 7.75, 9.1); cutDown(5.8, 7.75, 9.1)
            // Grime: thin streaks running down from the seams or anywhere, fading out; about a third are lighter
            // (worn), the rest darker. Round 11b: 1400 -> 2600 and stronger (r11a: hardly visible next to pass 5).
            let seamHeights = Array(Set(rings + joints)).filter { $0 > band.bottom && $0 < band.top }.sorted()
            for _ in 0..<2600 {
                let az = r.signed() * 180
                let fromSeam = r.next() < 0.5, pick = r.next()
                let seam = seamHeights[min(seamHeights.count - 1, Int(pick * Float(seamHeights.count)))]
                let start: Float = fromSeam ? seam - 0.01 : band.bottom + pick * span
                let length = 0.12 + 0.9 * r.next() * r.next(), strength = 0.05 + 0.2 * r.next() * r.next()
                let target = r.next() < 0.35 ? lights : marks
                let width = max(1, CGFloat(0.003 + 0.008 * r.next()) * pxPerMetreU(start))
                let cx = px(az), steps = 10
                for s in 0..<steps {
                    let ya = start - length * Float(s) / Float(steps), yb = start - length * Float(s + 1) / Float(steps)
                    target.setFillColor(gray: CGFloat(strength * (1 - Float(s) / Float(steps))), alpha: 1)
                    wrapped(CGRect(x: cx - width / 2, y: yv(yb), width: width, height: yv(ya) - yv(yb))) { target.fill($0) }
                }
            }
            // Specks and scuffs: small dark and light spots all over (pass 5's weathered skin).
            for _ in 0..<5500 {
                let az = r.signed() * 180, y = band.bottom + r.next() * span
                let d = CGFloat(0.003 + 0.01 * r.next() * r.next()) * pxPerMetreU(y)
                let target = r.next() < 0.3 ? lights : marks
                target.setFillColor(gray: CGFloat(0.08 + 0.3 * r.next()), alpha: 1)
                let stretch = 1 + 3 * CGFloat(r.next())
                wrapped(CGRect(x: px(az) - d / 2, y: yv(y) - d * stretch / 2, width: max(1, d), height: max(1, d * stretch))) {
                    target.fillEllipse(in: $0)
                }
            }
        }
        // Micro-scratches: short thin strokes at random angles, mostly faint.
        for _ in 0..<(detail == nil ? scratches[band.name] ?? 0 : 0) {
            let az = random.signed() * 180, y = band.bottom + random.next() * span
            let length = 0.008 + 0.05 * random.next() * random.next(), angle = random.next() * .pi
            let perU = pxPerMetreU(y)
            let dx = CGFloat(cos(angle) * length) * perU / 2, dy = CGFloat(sin(angle) * length) * pxPerMetreV / 2
            let p = CGPoint(x: x(az), y: yv(y))
            c.setStrokeColor(CGColor(red: 0, green: 0, blue: 1, alpha: CGFloat(0.25 + 0.6 * random.next())))
            c.setLineWidth(0.7)
            c.move(to: CGPoint(x: p.x - dx, y: p.y - dy))
            c.addLine(to: CGPoint(x: p.x + dx, y: p.y + dy))
            c.strokePath()
        }
        guard let data = c.data else { throw MapError.context }
        let masks = data.bindMemory(to: UInt8.self, capacity: w * h * 4)

        guard let toneData = tone.data else { throw MapError.context }
        let tones = toneData.bindMemory(to: UInt8.self, capacity: w * h)
        guard let marksData = marks.data else { throw MapError.context }
        let darks = marksData.bindMemory(to: UInt8.self, capacity: w * h)
        guard let lightsData = lights.data else { throw MapError.context }
        let brights = lightsData.bindMemory(to: UInt8.self, capacity: w * h)
        let wt = weights(band)

        // Soft groove shadow: the groove mask box-blurred over `aoWidth` each side.
        let radiusAO = max(2, Int(aoWidth * Float(h) / span))
        var ao = [Float](repeating: 0, count: w * h), pass = ao
        for i in 0..<(w * h) { ao[i] = Float(masks[4 * i]) / 255 }
        for _ in 0..<2 { ao.withUnsafeMutableBufferPointer { a in
            pass.withUnsafeMutableBufferPointer { t in
                let norm = 1 / Float(2 * radiusAO + 1)
                for row in 0..<h {
                    var sum: Float = 0
                    for k in -radiusAO...radiusAO { sum += a[row * w + (k + w) % w] }
                    for col in 0..<w {
                        t[row * w + col] = sum * norm
                        sum += a[row * w + (col + radiusAO + 1) % w] - a[row * w + (col - radiusAO + w) % w]
                    }
                }
                for col in 0..<w {
                    var sum: Float = 0
                    for k in -radiusAO...radiusAO { sum += t[min(h - 1, max(0, k)) * w + col] }
                    for row in 0..<h {
                        a[row * w + col] = sum * norm
                        sum += t[min(h - 1, row + radiusAO + 1) * w + col] - t[max(0, row - radiusAO) * w + col]
                    }
                }
            }
        } }
        // A groove `grooveTexels` wide blurred twice by a box of `2 r + 1` peaks at about grooveTexels / (2 r + 1).
        let aoGain = Float(2 * radiusAO + 1) / max(1, grooveWidth * Float(h) / span)

        // Brushed grain: one random level per texel row (around) or column (along), broken into 48-texel runs.
        let rowNoise = (0..<h).map { _ in random.signed() }, colNoise = (0..<w).map { _ in random.signed() }
        let runNoise = (0..<4096).map { _ in random.next() }
        var height = [Float](repeating: 0, count: w * h)
        var albedo = [UInt8](repeating: 255, count: w * h * 4), normal = albedo
        func srgb(_ linearish: Float) -> UInt8 { UInt8((min(1, max(0, linearish)) * 255).rounded()) }
        // The detail tile's texel size in metres, and the hull circumference per texel row (u spans it).
        let tileScale = Float(detail?.size ?? 1) / detailTile
        let circumference = (0..<h).map { row -> Float in
            2 * .pi * radius(band.bottom + (Float(h - 1 - row) + 0.5) / Float(h) * span)
        }
        // Round 10: the detail tile filtered over each map texel's footprint (see `detailTile`).
        var ripMaps: [Int: [Float]] = [:]
        func ripMap(_ lx: Int, _ ly: Int) -> [Float] {
            if let hit = ripMaps[lx * 16 + ly] { return hit }
            let made = detail?.box(lx, ly) ?? []
            ripMaps[lx * 16 + ly] = made
            return made
        }
        let metresPerRow = span / Float(h)
        height.withUnsafeMutableBufferPointer { hb in
            albedo.withUnsafeMutableBufferPointer { ab in
                for row in 0..<h {
                    let metresV = (Float(h - 1 - row) + 0.5) / Float(h) * span, metresPerCol = circumference[row] / Float(w)
                    // Footprint levels: tile x runs around the hull on "around" panels and along it on "along" ones.
                    let lu = Detail.level(metresPerCol * tileScale), lv = Detail.level(metresPerRow * tileScale)
                    let around = detail == nil ? [] : ripMap(lu, lv), alongMap = detail == nil ? [] : ripMap(lv, lu)
                    for col in 0..<w {
                        let i = row * w + col
                        let g = Float(masks[4 * i]) / 255, l = Float(masks[4 * i + 1]) / 255, s = Float(masks[4 * i + 2]) / 255
                        let t = Int(tones[i]), along = t >= 128
                        let variation = (Float(along ? t - 150 : t - 20) / 80) * 2 - 1, dark = Float(darks[i]) / 255
                        var streak: Float = 0, grain: Float = 0
                        if let detail {
                            let mu = Float(col) * metresPerCol
                            let lx = along ? lv : lu, ly = along ? lu : lv
                            let wx = detail.size >> lx, wy = detail.size >> ly
                            let tx = Int((along ? metresV : mu) * tileScale) >> lx, ty = Int((along ? mu : metresV) * tileScale) >> ly
                            grain = (along ? alongMap : around)[(ty % wy) * wx + tx % wx]
                        } else {
                            streak = along ? colNoise[col] * (0.5 + 0.5 * runNoise[(row / 48 + col * 7) & 4095])
                                : rowNoise[row] * (0.5 + 0.5 * runNoise[(col / 48 + row * 7) & 4095])
                        }
                        let shade = min(1, ao[i] * aoGain)
                        var v = base * (1 + brush * streak + detailAlbedo * grain) * (1 + wt.panelTone * variation)
                        v *= 1 - min(0.85, dark)
                        v += (1 - v) * 0.6 * min(1, Float(brights[i]) / 255)
                        v *= 1 - wt.aoStrength * shade
                        v *= 1 - wt.grooveDark * g
                        v += (1 - v) * wt.lipLight * l
                        v += (1 - v) * scratchLight * s
                        let byte = srgb(v)
                        ab[4 * i] = byte; ab[4 * i + 1] = byte; ab[4 * i + 2] = byte
                        hb[i] = -g - wt.grooveSlope * shade + 0.5 * l - scratchHeight * s + grainHeight * streak + detailHeight * grain
                    }
                }
            }
        }
        height.withUnsafeBufferPointer { hb in
            normal.withUnsafeMutableBufferPointer { nb in
                for row in 0..<h {
                    let up = max(0, row - 1), down = min(h - 1, row + 1)
                    for col in 0..<w {
                        let left = (col + w - 1) % w, right = (col + 1) % w
                        // Image rows run down, texture v up: the row above is higher v.
                        let du = (hb[row * w + right] - hb[row * w + left]) / 2
                        let dv = (hb[up * w + col] - hb[down * w + col]) / 2
                        let n = simd_normalize(SIMD3<Float>(-du * normalStrength, -dv * normalStrength, 1))
                        let i = row * w + col
                        nb[4 * i] = UInt8(((n.x * 0.5 + 0.5) * 255).rounded())
                        nb[4 * i + 1] = UInt8(((n.y * 0.5 + 0.5) * 255).rounded())
                        nb[4 * i + 2] = UInt8(((n.z * 0.5 + 0.5) * 255).rounded())
                    }
                }
            }
        }
        func image(_ bytes: [UInt8], space: CGColorSpace) throws -> CGImage {
            guard let provider = CGDataProvider(data: Data(bytes) as CFData),
                  let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider,
                                      decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            else { throw MapError.context }
            return image
        }
        return (try image(albedo, space: CGColorSpace(name: CGColorSpace.sRGB)!),
                try image(normal, space: CGColorSpace(name: CGColorSpace.linearSRGB)!))
    }
}

/// Loads a look image (PNG or JPEG) from a file URL; nil if it cannot be read.
enum LookImage {
    static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

/// D142: the cockpit interior image behind the front window, in place of the code console. One unlit plane in the
/// rocket frame, tilted `tilt` degrees to face the end-pose camera (20 degrees below the window).
///
/// Round 8 (r7b: only a few screens peeked in along the bottom of the glass, and the room was far too dark): the
/// r7 plane was centred at y 12.85, below the window-centre sight line, and the image's screens sit at 30 % of its
/// height, so they landed in the bottom fifth of the glass. Now (measured with `entrance-r8/backdrop.py` on the
/// rounded glass for the close-up, the end pose and the hand-over):
/// - the plane is centred where the end pose's window-centre sight line crosses z = `centre.z` (y 12.99), and
///   every sight line through the glass lands on it within s -0.47...+0.47 m;
/// - the image is placed on the plane (`imageHeight`, `imageCentre`) so that its screen band (rows at 23-37 % of
///   the height) lies on s -0.1...+0.1, the middle third of the visible glass, and the screen clusters span about
///   80 % of the glass width; below the image a short `padBelow` continues its bottom rows, fading dark (the lower
///   console in shadow), so no sight line runs off the picture;
/// - the plane is a grid whose sides are clipped to `clearance` of the capsule radius, so it never pokes through
///   the hull or the dark lining (0.92), whatever the placement;
/// - the image gets an exposure lift (`exposure`, a soft shoulder in linear light): the dim room comes up about 5x
///   (structure sRGB ~0.05 to ~0.2) while the lit screens only reach near white instead of clipping.
/// The file's back-half lining sits at z <= 0, behind the plane's lowest edge (z ~0.02).
@available(macOS 15.0, *)
@MainActor
enum CockpitBackdrop {
    static let name = "cockpit-backdrop"
    /// Round 9 (D146): derived from the window, so it follows the new glass: where the end pose's sight line
    /// through the glass centre (20 degrees below) crosses z = `depth` (r8: y 12.99 for the file's window).
    static let depth: Float = 0.2
    static var centre: SIMD3<Float> {
        let g = WindowShape.point(WindowShape.centre, lift: WindowShape.glassLift)
        return SIMD3<Float>(0, g.y + (g.z - depth) * tan(tilt * .pi / 180), depth)
    }
    static let tilt: Float = 20
    /// The plane's extent along its up axis (metres from `centre`) and half-width before clipping.
    static let planeBottom: Float = -0.53, planeTop: Float = 0.55, planeHalfWidth: Float = 0.95
    /// The plane is clipped to this fraction of the capsule radius at each height.
    static let clearance: Float = 0.915
    /// The image's height on the plane in metres (its width follows its aspect: 7:5) and its centre along the up
    /// axis: screens (30 % up the image) at s = imageCentre - 0.2 x imageHeight. Round 9 (D146, the window is 0.58 m
    /// tall, not 0.87): sight lines land on s -0.37...+0.29 (`entrance-r9/check9.py`), so 1.2 m (1.68 m wide) with
    /// the screens at s -0.04 puts them at 37-63 % of the glass height and about 83 % of its width (r8: 1.45 / 0.29).
    static let imageHeight: Float = 1.2
    static let imageCentre: Float = 0.2
    /// Metres of faded continuation under the image.
    static let padBelow: Float = 0.12
    /// Exposure lift in linear light: out = (1 - e^(-k x)) / (1 - e^(-k)), about k times for the dark room.
    static let exposure: Double = 5
    /// Multiplies the image (unlit tint, at most 1).
    static let brightness: CGFloat = 1.0

    enum BackdropError: Error { case context }

    /// The image with `padBelow` added under it and the exposure lift applied, as an sRGB RGBA bitmap.
    static func prepared(_ image: CGImage) throws -> CGImage {
        let w = image.width, h = image.height
        let pad = max(1, Int((Float(h) * padBelow / imageHeight).rounded()))
        let total = h + pad
        guard let c = CGContext(data: nil, width: w, height: total, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw BackdropError.context }
        c.interpolationQuality = .high
        // CoreGraphics draws from the bottom: the image on top, the pad under it.
        c.draw(image, in: CGRect(x: 0, y: pad, width: w, height: h))
        let strip = max(2, h / 40)
        if let bottomRows = image.cropping(to: CGRect(x: 0, y: h - strip, width: w, height: strip)) {
            c.draw(bottomRows, in: CGRect(x: 0, y: 0, width: w, height: pad))
        }
        if let fade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                 colors: [CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25), CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.9)] as CFArray,
                                 locations: [0, 1]) {
            c.saveGState()
            c.clip(to: CGRect(x: 0, y: 0, width: w, height: pad))
            c.drawLinearGradient(fade, start: CGPoint(x: 0, y: pad), end: CGPoint(x: 0, y: 0), options: [])
            c.restoreGState()
        }
        guard let data = c.data else { throw BackdropError.context }
        let lut: [UInt8] = (0..<256).map { b in
            let s = Double(b) / 255
            let linear = s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
            let lifted = min(1, (1 - exp(-exposure * linear)) / (1 - exp(-exposure)))
            let encoded = lifted <= 0.0031308 ? 12.92 * lifted : 1.055 * pow(lifted, 1 / 2.4) - 0.055
            return UInt8((min(1, max(0, encoded)) * 255).rounded())
        }
        let p = data.bindMemory(to: UInt8.self, capacity: w * total * 4)
        for i in 0..<(w * total) {
            p[4 * i] = lut[Int(p[4 * i])]; p[4 * i + 1] = lut[Int(p[4 * i + 1])]; p[4 * i + 2] = lut[Int(p[4 * i + 2])]
            p[4 * i + 3] = 255
        }
        guard let out = c.makeImage() else { throw BackdropError.context }
        return out
    }

    /// The plane as a grid in (x, s), sides clipped to the capsule, with the image's texture coordinates
    /// (v = 0 at the bottom of the pad, 1 at the image's top row).
    static func mesh(imageAspect: Float, columns: Int = 24, rows: Int = 24) throws -> MeshResource {
        let imageWidth = imageHeight * imageAspect
        let vBottom = imageCentre - imageHeight / 2 - padBelow, vSpan = imageHeight + padBelow
        return try mesh(columns: columns, rows: rows) { p, x, s in [x / imageWidth + 0.5, (s - vBottom) / vSpan] }
    }

    /// The plane grid with texture coordinates from `uv(position, x, s)`.
    static func mesh(columns: Int = 24, rows: Int = 24, uv: (SIMD3<Float>, Float, Float) -> SIMD2<Float>) throws -> MeshResource {
        let angle = tilt * .pi / 180
        // Plane axes in the rocket frame: right = +x, up = y tilted toward +z, normal toward the camera below.
        let up = SIMD3<Float>(0, cos(angle), sin(angle))
        var positions: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], indices: [UInt32] = []
        for j in 0...rows {
            let s = planeBottom + (planeTop - planeBottom) * Float(j) / Float(rows)
            let base = centre + up * s
            let free = clearance * CockpitCeiling.radius(base.y)
            let half = min(planeHalfWidth, sqrt(max(0, free * free - base.z * base.z)))
            for i in 0...columns {
                let x = -half + 2 * half * Float(i) / Float(columns)
                let p = base + SIMD3<Float>(x, 0, 0)
                positions.append(p)
                uvs.append(uv(p, x, s))
            }
        }
        let stride = UInt32(columns + 1)
        for j in 0..<UInt32(rows) {
            for i in 0..<UInt32(columns) {
                let a = j * stride + i, b = a + 1, c = a + stride, d = c + 1
                indices += [a, b, d, a, d, c]
            }
        }
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    static func add(to root: Entity, image: CGImage) throws {
        let aspect = Float(image.width) / Float(max(1, image.height))
        try add(to: root, texture: prepared(image), mesh: mesh(imageAspect: aspect), brightness: brightness)
    }

    // MARK: Round 10: the real cockpit snapshot

    /// A snapshot and the camera it is mapped from: the hand-over camera, with the rocket risen by `rise`.
    struct Placement {
        let snapshot: CockpitSnapshot
        let camera: EntranceCamera
        let rise: Double
    }
    /// The snapshot is a lit screen seen through glass: slightly below full brightness, its edges darkened by a soft
    /// vignette (`vignette` at the corners), on the dark cabin colour where it is transparent or ends.
    static let snapshotBrightness: CGFloat = 0.92
    static let vignette: CGFloat = 0.35
    static let cabin = CGColor(srgbRed: 0.018, green: 0.02, blue: 0.026, alpha: 1)
    /// Dark texels round the picture, so clamp-to-edge continues the cabin colour, not the picture's edge.
    static let border = 4

    /// The snapshot on the dark cabin colour with the vignette and a dark border, as an sRGB bitmap.
    static func preparedSnapshot(_ image: CGImage) throws -> CGImage {
        let w = image.width + 2 * border, h = image.height + 2 * border
        guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw BackdropError.context }
        c.setFillColor(cabin)
        c.fill(CGRect(x: 0, y: 0, width: w, height: h))
        c.interpolationQuality = .high
        let inner = CGRect(x: border, y: border, width: image.width, height: image.height)
        c.draw(image, in: inner)
        if let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0), CGColor(srgbRed: 0, green: 0, blue: 0, alpha: vignette)] as CFArray,
                                  locations: [0.55, 1]) {
            c.saveGState()
            c.clip(to: inner)
            let centre = CGPoint(x: inner.midX, y: inner.midY)
            c.drawRadialGradient(shade, startCenter: centre, startRadius: 0, endCenter: centre,
                                 endRadius: (inner.width * inner.width + inner.height * inner.height).squareRoot() / 2, options: [.drawsAfterEndLocation])
            c.restoreGState()
        }
        guard let out = c.makeImage() else { throw BackdropError.context }
        return out
    }

    /// The backdrop showing the real cockpit. Each grid vertex takes the texture coordinate of where the hand-over
    /// camera sees it on the viewport, inside the snapshot's frame: projective texturing baked into the 24 x 24
    /// grid. At the end of the hand-over the glass therefore shows the snapshot exactly where the cockpit will draw
    /// it; from the end pose (the same line of sight, farther back) it reads as the same picture behind the glass.
    static func add(to root: Entity, snapshot placement: Placement) throws {
        let snapshot = placement.snapshot, frame = snapshot.frame
        let image = try preparedSnapshot(snapshot.image)
        let pxPerPoint = Double(snapshot.image.width) / max(1, frame.width)
        let w = Double(image.width), h = Double(image.height), b = Double(border)
        let grid = try mesh { p, _, _ in
            let world = root.convert(position: p, to: nil)
            let seen = placement.camera.project(EntranceVector(Double(world.x), Double(world.y) + placement.rise, Double(world.z))).point
            let px = (seen.x - frame.left) * pxPerPoint + b, py = (seen.y - frame.top) * pxPerPoint + b
            return [Float(px / w), Float(1 - py / h)]
        }
        try add(to: root, texture: image, mesh: grid, brightness: snapshotBrightness)
    }

    static func add(to root: Entity, texture image: CGImage, mesh: MeshResource, brightness: CGFloat) throws {
        guard root.findEntity(named: name) == nil else { return }
        let resource = try TextureResource.generate(from: image, options: .init(semantic: .color))
        var texture = MaterialParameters.Texture(resource)
        let d = MTLSamplerDescriptor()
        d.sAddressMode = .clampToEdge
        d.tAddressMode = .clampToEdge
        d.minFilter = .linear
        d.magFilter = .linear
        d.mipFilter = .linear
        texture.sampler = .init(d)
        var material = UnlitMaterial()
        material.color = .init(tint: NSColor(white: brightness, alpha: 1), texture: texture)
        material.faceCulling = .none
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = name
        root.addChild(entity)
    }
}

/// D142/D146 (owner): the front window. D142 rounded the file's chamfered window; D146 (round 9) makes its SHAPE
/// follow the pass-5 prototype (it stands for the cockpit's top canopy window): wider and lower than the file's,
/// top edge clearly shorter than the bottom, generous rounded corners, more nose above it. Look mode rebuilds the
/// glass, the frame bands and a hull patch from one rounded outline; the hull is cut behind them.
///
/// The outline lives in a chart on the capsule: X = azimuth (radians) x glass radius, Y = height. There the
/// window is a trapezoid, bottom `bottom`, top `top`, side edges from X -+`sideAtBottom` to -+`sideAtTop`, its
/// corners filleted with `bottomRadius` / `topRadius`. Round 9 measured it on the pass-5 window still
/// (`references/night-window.jpg`): a camera fitted to the capsule silhouette round the window, the picked glass
/// edge cast onto the hull, and this trapezoid fitted to it (`entrance-r9/cam3.py`, `fitshape.py`; numbers in the
/// lane handoff). Offsets of the outline give the bands, from the glass outwards:
/// - `canopy_inner_rim`: the bright rim, `rimWidth`, sloping from the frame top down to the glass;
/// - `canopy_frame_bevel_2`: the dark frame, `frameWidth`, `frameLift` above the glass;
/// - `canopy_frame_bevel_1`: the frame's outer wall, `wallWidth`, down to the hull;
/// - `canopy_frame_bevel_0`: the light surround, `surroundWidth`, down to `patchLift`;
/// - `canopy-hull-patch`: hull metal (the hull's own panel material) from the surround out to an outline that
///   also covers the file's old window opening (`patchMargin` beyond both), `patchLift` above the profile.
/// The hull parts lose every triangle whose centre lies inside `cutOutline` (the patch outline `cutInset` in), so
/// neither the old opening nor hull metal behind the new glass shows. The glass is `glassLift` above the profile.
/// The camera rail, the D132 end pose and the hand-over use the same glass: the pack's rocket-geometry.json carries
/// this outline (centre plus two rings), written by `entrance-r9/geometry.py` with the same construction.
@available(macOS 15.0, *)
@MainActor
enum WindowShape {
    static let bottomRadius: Float = 0.12
    static let topRadius: Float = 0.13
    static let bottom: Float = 12.49, top: Float = 13.07
    static let sideAtBottom: Float = 0.695, sideAtTop: Float = 0.435
    static var centre: SIMD2<Float> { SIMD2<Float>(0, (bottom + top) / 2) }
    static let glassLift: Float = 0.018, frameLift: Float = 0.022, openingLift: Float = 0.004
    /// Round 8: rim 0.8 -> 1.0 cm (about 4.7 px in the close-up), frame 3.6 -> 3.4 cm.
    static let rimWidth: Float = 0.01, frameWidth: Float = 0.034, wallWidth: Float = 0.004
    /// Round 9: the light surround outside the frame wall, and the hull patch.
    static let surroundWidth: Float = 0.022
    /// Rim, frame, wall and surround together, from the glass edge out.
    static var bandsWidth: Float { rimWidth + frameWidth + wallWidth + surroundWidth }
    static let patchMargin: Float = 0.06, patchLift: Float = 0.0015, cutInset: Float = 0.03
    /// Rings of the patch ribbon, so it follows the curved hull instead of cutting chords under it.
    static let patchRings = 8
    /// Points per corner arc and per straight edge.
    static let arcPoints = 16, edgePoints = 16
    static let glassRings = 12
    /// Set by `build`: the outline (chart) inside which the hull parts are cut away, and the patch mesh in the
    /// rocket frame.
    static var cutOutline: [SIMD2<Float>] = []
    static var patch: (positions: [SIMD3<Float>], triangles: [UInt32])?
    static let patchName = "canopy-hull-patch"

    static func radius(_ y: Float) -> Float { CockpitCeiling.radius(y) }

    /// A chart point at `lift` above the capsule profile, in the rocket frame.
    static func point(_ c: SIMD2<Float>, lift: Float) -> SIMD3<Float> {
        let a = c.x / (radius(c.y) + glassLift), r = radius(c.y) + lift
        return SIMD3<Float>(r * sin(a), c.y, r * cos(a))
    }

    static func chart(_ p: SIMD3<Float>) -> SIMD2<Float> {
        SIMD2<Float>(atan2(p.x, p.z) * (radius(p.y) + glassLift), p.y)
    }

    /// The rounded outline offset `d` metres outwards, counter-clockwise from the bottom-left corner arc. Every
    /// offset has the same number of points, in step, so neighbouring outlines join into ribbons.
    static func outline(_ d: Float) -> [SIMD2<Float>] {
        let quad: [SIMD2<Float>] = [[-sideAtBottom, bottom], [sideAtBottom, bottom], [sideAtTop, top], [-sideAtTop, top]]
        let radii = [bottomRadius, bottomRadius, topRadius, topRadius].map { $0 + d }
        // Edge lines (point, unit direction), moved outwards (to the right of a counter-clockwise edge).
        let lines: [(p: SIMD2<Float>, t: SIMD2<Float>)] = (0..<4).map { i in
            let a = quad[i], b = quad[(i + 1) % 4], t = simd_normalize(b - a)
            return (a + SIMD2<Float>(t.y, -t.x) * d, t)
        }
        func intersect(_ l1: (p: SIMD2<Float>, t: SIMD2<Float>), _ l2: (p: SIMD2<Float>, t: SIMD2<Float>)) -> SIMD2<Float> {
            let den = l1.t.x * l2.t.y - l1.t.y * l2.t.x
            let s = ((l2.p.x - l1.p.x) * l2.t.y - (l2.p.y - l1.p.y) * l2.t.x) / den
            return l1.p + l1.t * s
        }
        // Corner i joins edge i-1 (incoming) and edge i (outgoing).
        var arcs: [(start: SIMD2<Float>, end: SIMD2<Float>, centre: SIMD2<Float>, r: Float)] = []
        for i in 0..<4 {
            let incoming = lines[(i + 3) % 4].t, outgoing = lines[i].t
            let corner = intersect(lines[(i + 3) % 4], lines[i])
            let angle = acos(max(-1, min(1, -simd_dot(incoming, outgoing))))
            let tangent = radii[i] / tan(angle / 2)
            let bisector = simd_normalize(outgoing - incoming)
            arcs.append((corner - incoming * tangent, corner + outgoing * tangent,
                         corner + bisector * (radii[i] / sin(angle / 2)), radii[i]))
        }
        var points: [SIMD2<Float>] = []
        for i in 0..<4 {
            let arc = arcs[i]
            let a0 = atan2(arc.start.y - arc.centre.y, arc.start.x - arc.centre.x)
            var a1 = atan2(arc.end.y - arc.centre.y, arc.end.x - arc.centre.x)
            while a1 < a0 { a1 += 2 * .pi }
            for k in 0..<arcPoints {
                let a = a0 + (a1 - a0) * Float(k) / Float(arcPoints)
                points.append(arc.centre + SIMD2<Float>(cos(a), sin(a)) * arc.r)
            }
            let next = arcs[(i + 1) % 4].start
            for k in 0..<edgePoints {
                points.append(arc.end + (next - arc.end) * (Float(k) / Float(edgePoints)))
            }
        }
        return points
    }

    /// Rebuilds the glass and the strips under `root`; false (nothing changed) if the file's window is not there.
    static func build(in root: Entity) throws -> Bool {
        guard let glass = root.findEntity(named: ModelRocket.glassName) else { return false }
        let strips = GasketFrame.names.map { root.findEntity(named: $0) }
        guard strips.allSatisfy({ $0 != nil }), root.findEntity(named: GasketFrame.rimName) == nil else { return false }
        // The hull opening: the outer strip's vertices that it does not share with the middle strip.
        func rootPoints(_ e: Entity) -> [SIMD3<Float>] {
            var points: [SIMD3<Float>] = []
            ModelRocket.forEachModel(e) { m in
                guard let model = m.components[ModelComponent.self] else { return }
                for part in model.mesh.contents.models.flatMap({ Array($0.parts) }) {
                    points += part.positions.elements.map { m.convert(position: $0, to: root) }
                }
            }
            return points
        }
        let middle = Set(rootPoints(strips[1]!).map(GasketFrame.key))
        var seen = Set<SIMD3<Int32>>()
        let opening = rootPoints(strips[0]!).filter { p in
            let k = GasketFrame.key(p)
            return !middle.contains(k) && seen.insert(k).inserted
        }
        guard opening.count >= 8 else { return false }
        // The opening as a polygon around the window centre, by angle in the chart.
        let around = opening.map { p -> (angle: Float, p: SIMD3<Float>) in
            let c = chart(p) - centre
            return (atan2(c.y, c.x), p)
        }.sorted { $0.angle < $1.angle }

        /// The opening's edge where the ray from the centre through `c` crosses it: azimuth, height and radius
        /// interpolated between the two opening vertices, as `RoundHull` subdivides that edge.
        func onOpening(_ c: SIMD2<Float>) -> SIMD3<Float> {
            let d = c - centre, angle = atan2(d.y, d.x)
            var i = around.lastIndex { $0.angle <= angle } ?? around.count - 1
            if around[i].angle > angle { i = around.count - 1 }
            let a = around[i].p, b = around[(i + 1) % around.count].p
            let ca = chart(a) - centre, cb = chart(b) - centre
            // Solve d * s = ca + (cb - ca) * t for t (all relative to the centre): t = -(d x ca) / (d x e).
            let e = cb - ca, den = d.x * e.y - d.y * e.x
            let t = abs(den) > 1e-9 ? max(0, min(1, (d.y * ca.x - d.x * ca.y) / den)) : 0.5
            let az = atan2(a.x, a.z) + (atan2(b.x, b.z) - atan2(a.x, a.z)) * t
            let y = a.y + (b.y - a.y) * t
            let r = simd_length(SIMD2<Float>(a.x, a.z)) + (simd_length(SIMD2<Float>(b.x, b.z)) - simd_length(SIMD2<Float>(a.x, a.z))) * t
            return SIMD3<Float>(r * sin(az), y, r * cos(az))
        }

        let glassEdge = outline(0), rimOuter = outline(rimWidth)
        let frameOuter = outline(rimWidth + frameWidth), wallOuter = outline(rimWidth + frameWidth + wallWidth)
        let surroundOuter = outline(rimWidth + frameWidth + wallWidth + surroundWidth)
        func ring(_ outline: [SIMD2<Float>], lift: Float) -> [SIMD3<Float>] { outline.map { point($0, lift: lift) } }
        let rim = ribbon(ring(rimOuter, lift: frameLift), ring(glassEdge, lift: glassLift))
        let frame = ribbon(ring(frameOuter, lift: frameLift), ring(rimOuter, lift: frameLift))
        let wall = ribbon(ring(wallOuter, lift: openingLift), ring(frameOuter, lift: frameLift))
        let surround = ribbon(ring(surroundOuter, lift: patchLift), ring(wallOuter, lift: openingLift))
        // D146: the patch reaches `patchMargin` beyond the surround and beyond the file's old opening, whichever is
        // farther along each ray from the window centre, so the old opening is covered wherever it was larger.
        let reach = outline(rimWidth + frameWidth + wallWidth + surroundWidth + patchMargin)
        let patchOuter = reach.map { o -> SIMD2<Float> in
            let d = o - centre, r = simd_length(d)
            let q = simd_length(chart(onOpening(o)) - centre) + patchMargin
            return centre + d * max(1, q / max(r, 1e-4))
        }
        cutOutline = patchOuter.map { o -> SIMD2<Float> in
            let d = o - centre, r = simd_length(d)
            return centre + d * max(0, 1 - cutInset / max(r, 1e-4))
        }
        let patchMesh = band(surroundOuter, patchOuter, lift: patchLift, rings: patchRings)
        patch = (positions: patchMesh.0, triangles: patchMesh.1)

        // Glass: rings from the centre out to the rounded edge.
        var glassPoints: [SIMD3<Float>] = [point(centre, lift: glassLift)], glassTriangles: [UInt32] = []
        let n = glassEdge.count
        for k in 1...glassRings {
            let s = Float(k) / Float(glassRings)
            glassPoints += glassEdge.map { point(centre + ($0 - centre) * s, lift: glassLift) }
        }
        for i in 0..<n { glassTriangles += [0, UInt32(1 + i), UInt32(1 + (i + 1) % n)] }
        for k in 1..<glassRings {
            let inner = 1 + (k - 1) * n, outer = 1 + k * n
            for i in 0..<n {
                let a = UInt32(inner + i), b = UInt32(inner + (i + 1) % n), c = UInt32(outer + i), d = UInt32(outer + (i + 1) % n)
                glassTriangles += [a, c, d, a, d, b]
            }
        }

        try replace(glass, with: (glassPoints, glassTriangles), root: root)
        try replace(strips[0]!, with: surround, root: root)
        try replace(strips[1]!, with: wall, root: root)
        // The rim is a copy of the inner strip (its materials and place in the hierarchy), then rebuilt.
        let rimEntity = strips[2]!.clone(recursive: true)
        rimEntity.name = GasketFrame.rimName
        strips[2]!.parent?.addChild(rimEntity)
        try replace(strips[2]!, with: frame, root: root)
        try replace(rimEntity, with: rim, root: root)
        return true
    }

    /// Two chart outlines in step joined by `rings` intermediate outlines, all at `lift` above the profile.
    static func band(_ inner: [SIMD2<Float>], _ outer: [SIMD2<Float>], lift: Float, rings: Int) -> ([SIMD3<Float>], [UInt32]) {
        let n = inner.count
        var positions: [SIMD3<Float>] = [], triangles: [UInt32] = []
        for k in 0...rings {
            let t = Float(k) / Float(rings)
            positions += zip(inner, outer).map { point($0 + ($1 - $0) * t, lift: lift) }
        }
        for k in 0..<rings {
            let a0 = k * n, b0 = (k + 1) * n
            for i in 0..<n {
                let a = UInt32(a0 + i), b = UInt32(a0 + (i + 1) % n), c = UInt32(b0 + i), d = UInt32(b0 + (i + 1) % n)
                triangles += [a, c, d, a, d, b]
            }
        }
        return (positions, triangles)
    }

    /// True if the chart point lies inside `cutOutline`.
    static func insideCut(_ c: SIMD2<Float>) -> Bool {
        let poly = cutOutline
        guard poly.count >= 3 else { return false }
        var inside = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > c.y) != (b.y > c.y), c.x < (b.x - a.x) * (c.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    /// The hull mesh without the triangles whose centre lies inside `cutOutline` (the new window and the patch
    /// cover that area); normals and texture coordinates are kept.
    static func cut(_ mesh: MeshResource, entity: Entity, root: Entity) throws -> MeshResource {
        guard !cutOutline.isEmpty else { return mesh }
        let m = entity.transformMatrix(relativeTo: root)
        var contents = mesh.contents
        var models: [MeshResource.Model] = []
        for var model in contents.models {
            model.parts = MeshPartCollection(model.parts.map { part -> MeshResource.Part in
                guard let triangles = part.triangleIndices?.elements else { return part }
                let positions = part.positions.elements
                var kept: [UInt32] = []
                kept.reserveCapacity(triangles.count)
                for f in 0..<(triangles.count / 3) {
                    let a = Int(triangles[3 * f]), b = Int(triangles[3 * f + 1]), c = Int(triangles[3 * f + 2])
                    guard a < positions.count, b < positions.count, c < positions.count else { continue }
                    let local = (positions[a] + positions[b] + positions[c]) / 3
                    let world = m * SIMD4<Float>(local, 1)
                    let p = SIMD3<Float>(world.x, world.y, world.z)
                    // Only the window side (the chart's azimuth wraps behind the rocket).
                    if p.z > 0, insideCut(chart(p)) { continue }
                    kept += [UInt32(a), UInt32(b), UInt32(c)]
                }
                var result = MeshResource.Part(id: part.id, materialIndex: part.materialIndex)
                result.positions = part.positions
                if let normals = part.normals { result.normals = normals }
                if let uvs = part.textureCoordinates { result.textureCoordinates = uvs }
                result.triangleIndices = MeshBuffer<UInt32>(kept)
                return result
            })
            models.append(model)
        }
        contents.models = MeshModelCollection(models)
        return try MeshResource.generate(from: contents)
    }

    /// The hull patch as an entity on `root`, with the hull's panel material and the panel maps' cylindrical
    /// texture coordinates (u = azimuth / 360 + 0.5, v up the capsule band).
    static func addPatch(to root: Entity, material: any RealityKit.Material) throws {
        guard let patch, root.findEntity(named: patchName) == nil else { return }
        let band = HullPanels.capsule
        var descriptor = MeshDescriptor(name: patchName)
        descriptor.positions = MeshBuffers.Positions(patch.positions)
        descriptor.normals = MeshBuffers.Normals(patch.positions.map { simd_normalize(SIMD3<Float>($0.x, 0, $0.z)) })
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(patch.positions.map { p in
            SIMD2<Float>(atan2(p.x, p.z) / (2 * .pi) + 0.5, (p.y - band.bottom) / (band.top - band.bottom))
        })
        descriptor.primitives = .triangles(patch.triangles)
        let mesh = try SmoothNormals.mesh(try MeshResource.generate(from: [descriptor]))
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = patchName
        root.addChild(entity)
    }

    /// Two outlines in step joined into a strip (both faces are drawn by the materials).
    static func ribbon(_ outer: [SIMD3<Float>], _ inner: [SIMD3<Float>]) -> ([SIMD3<Float>], [UInt32]) {
        let n = outer.count
        var triangles: [UInt32] = []
        for i in 0..<n {
            let a = UInt32(i), b = UInt32((i + 1) % n), c = UInt32(n + i), d = UInt32(n + (i + 1) % n)
            triangles += [a, c, d, a, d, b]
        }
        return (outer + inner, triangles)
    }

    /// Puts the mesh (rocket-frame positions) on the first model under `entity`, in that model's own space, with
    /// outward (radial) normals for `SmoothNormals` to orient by; any further models under it are hidden.
    static func replace(_ entity: Entity, with mesh: ([SIMD3<Float>], [UInt32]), root: Entity) throws {
        var models: [Entity] = []
        ModelRocket.forEachModel(entity) { models.append($0) }
        guard let first = models.first, var model = first.components[ModelComponent.self] else { return }
        var descriptor = MeshDescriptor(name: entity.name)
        descriptor.positions = MeshBuffers.Positions(mesh.0.map { first.convert(position: $0, from: root) })
        descriptor.normals = MeshBuffers.Normals(mesh.0.map { p in
            first.convert(direction: simd_normalize(SIMD3<Float>(p.x, 0, p.z)), from: root)
        })
        descriptor.primitives = .triangles(mesh.1)
        model.mesh = try MeshResource.generate(from: [descriptor])
        first.components.set(model)
        for other in models.dropFirst() { other.isEnabled = false }
    }
}

/// Code-drawn look settings (no art files). Both themes are black space (owner D116): there is no sky and the
/// studio is never drawn, only reflected. Metal looks like metal when it has something to reflect, so the studio is
/// dark with tall soft-edged light strips; on the 24-sided hull they become long vertical highlight bands, as in
/// the approved pass-5 art.
public enum EntranceLook {
    /// The directional sun, top left. Day has twice the night sun. On the metal it only adds a narrow glint (the
    /// earlier 12000 lux day sun blew the lit side out to white).
    /// Round 11 (owner: pass 5 has a soft long highlight; r10 a blown-out spot on the lower body): night 1500 -> 700,
    /// day 3000 -> 1500; the studio key strip carries the highlight.
    /// Round 11c: night 400, day 800 (the smoother, brighter metal would turn the sun back into a spot).
    public static func sunIntensity(_ theme: EntranceTheme) -> Float { theme == .day ? 800 : 400 }

    /// Image-based light exponent for `EntranceScene.setEnvironment(_:intensityExponent:)`. The studio's brightest
    /// strip is 1.0, so the strips reach 2^exponent: about 5.7 at night (dark gunmetal, albedo ~0.1, needs bright
    /// strips to show its bands) and 2 by day (aluminium, albedo ~0.45, would clip higher).
    public static func environmentExponent(_ theme: EntranceTheme) -> Float { theme == .day ? 1.0 : 2.5 }

    /// Image-based light exponent for the canopy glass's own environment (`glassStudio`).
    /// Round 8: +0.5 (night 1.5, day 2.0), making up for the lower glass opacity, which also dims the reflection.
    /// Round 10: +0.9 (night 2.4, day 2.9) for the glass opacity 0.5 -> 0.3, which dims the reflection with it.
    public static func glassEnvironmentExponent(_ theme: EntranceTheme) -> Float { theme == .day ? 2.9 : 2.4 }

    /// The canopy glass's environment: a near-black room with no bright ceiling, so the glass never turns white at
    /// grazing angles. Round 5 (pass 5: curved reflection streaks along the glass's edges): the glass spans about
    /// +-47 degrees of azimuth and reflects a direction at about twice its own azimuth plus the camera's own
    /// angle to it (about 7 degrees from the 4 m close-up), so two bright strips at +-`glassStreakAzimuth` land
    /// along its left and right edges (glass edge at 40-45 degrees: 87-97), the left one brighter, on the key side. From
    /// the end pose (about 20 degrees below) the top of the glass reflects the zenith and its bottom about 40 degrees
    /// up in front, so an overhead patch to the left curves along the top-left and a faint low band glints along
    /// the bottom.
    public static let glassStreakAzimuth = 88.0
    public static func glassStudio() -> CGImage? {
        equirect { az, e in
            var v = 0.004 + 0.008 * max(0, sin(e * Double.pi / 180))
            v = max(v, 1.0 * strip(az, e, centre: -glassStreakAzimuth, half: 5, low: -15, high: 80, soft: 5))
            v = max(v, 0.8 * strip(az, e, centre: glassStreakAzimuth, half: 4, low: -15, high: 80, soft: 5))
            v = max(v, 0.35 * strip(az, e, centre: -35, half: 25, low: 70, high: 84, soft: 8))
            v = max(v, 0.2 * strip(az, e, centre: 0, half: 30, low: 36, high: 42, soft: 6))
            v = max(v, glassSheen * sheen(az, e))
            v = max(v, sun(az, e))
            return v
        } star: { x, y in EntranceLook.stars[y &* 512 &+ x] }
    }

    /// Round 10 (owner: glass that looks real): what the glass reflects besides the studio strips, very faintly:
    /// the sun where the key light comes from (above left, in front) and the starfield of the black sky.
    public static let sunAzimuth = -38.7, sunElevation = 49.5
    static func sun(_ az: Double, _ e: Double) -> Double {
        let da = abs((az - sunAzimuth + 540).truncatingRemainder(dividingBy: 360) - 180) * cos(e * Double.pi / 180)
        let d = (da * da + (e - sunElevation) * (e - sunElevation)).squareRoot()
        return 0.9 * exp(-(d / 1.6) * (d / 1.6)) + 0.08 * exp(-(d / 6) * (d / 6))
    }
    /// About 600 single-texel stars in the upper hemisphere of the 512 x 256 glass environment (deterministic).
    static let stars: [Double] = {
        var field = [Double](repeating: 0, count: 512 * 256)
        var state: UInt64 = 0x57A2_F1E1
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 40) / Double(1 << 24)
        }
        for _ in 0..<600 {
            let x = Int(next() * 512) % 512, y = Int(next() * 120) % 128
            let level = next()
            field[y * 512 + x] = 0.08 + 0.5 * level * level * level
        }
        return field
    }()

    /// Round 8 (pass 5: soft reflection streaks across the glass, not only one glint): a broad, faint, slanted
    /// sheen. From 20 degrees below, the glass centre reflects about 49 degrees up in front (az 0), its top higher
    /// and its bottom about 40 degrees, its sides about twice their own azimuth. Two wide soft bands in that part of
    /// the sky, leaning so their reflection runs diagonally from upper left to lower right across the glass, the
    /// left one brighter (the key side). Glass reflects only a few per cent at these angles, so `glassSheen` is
    /// high for a faint result.
    /// Round 10: 0.3 -> 0 (owner: the glass looked fake; the broad soft bands read as a milky veil, not glass).
    public static let glassSheen = 0.0
    static func sheen(_ az: Double, _ e: Double) -> Double {
        func band(_ centre: Double, _ half: Double) -> Double {
            // The band's centre azimuth moves with elevation, so it slants across the glass.
            strip(az, e, centre: centre - (e - 50) * 0.9, half: half, low: 25, high: 75, soft: 22)
        }
        return max(band(-30, 10), 0.6 * band(30, 6))
    }

    /// A tall strip centred at azimuth `centre`, `half` degrees wide, from elevation `low` to `high`, with soft
    /// edges (a hard edge reflects as a sharp line down a metal cylinder).
    static func strip(_ az: Double, _ e: Double, centre: Double, half: Double, low: Double, high: Double, soft: Double = 12) -> Double {
        let da = abs((az - centre + 540).truncatingRemainder(dividingBy: 360) - 180)
        let fx = max(0, 1 - max(0, da - half) / soft)
        let fy = max(0, 1 - max(0, low - e, e - high) / 15)
        return fx * fx * (3 - 2 * fx) * fy * fy * (3 - 2 * fy)
    }

    /// Where the image's centre column points, as an azimuth in this file's convention (0 = +z, the window side and
    /// the end-pose camera; +90 = +x). Round 6: the r5 frames show the image centre faces -z, i.e. RealityKit's
    /// forward: the rim strips meant for +-160 lit the middle of the hull (normal azimuth +-10) and the glass
    /// streaks meant for its edges missed it, while the key meant for the upper left lit the right. So every
    /// azimuth in `studio` and `glassStudio` is now written in the scene's convention and turned here.
    public static let imageCentreAzimuth = 180.0

    /// A 512 x 256 equirectangular grey image from linear light values (azimuth in the scene's convention,
    /// elevation, in degrees), sRGB-encoded.
    static func equirect(_ value: (Double, Double) -> Double, star: ((Int, Int) -> Double)? = nil) -> CGImage? {
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
                let image = 360 * (Double(x) + 0.5) / Double(w) - 180
                let az = (image + imageCentreAzimuth + 540).truncatingRemainder(dividingBy: 360) - 180
                let linear = min(1, max(0, value(az, e) + (star?(x, y) ?? 0)))
                let encoded = linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1 / 2.4) - 0.055
                let o = (y * w + x) * 4
                let level = UInt8((encoded * 255).rounded())
                p[o] = level; p[o + 1] = level; p[o + 2] = level; p[o + 3] = 255
            }
        }
        return context.makeImage()
    }

    /// Equirectangular studio, 512 x 256, sRGB-encoded linear light. Dark room (night) or a light grey one (day:
    /// satin aluminium needs light to be light), a faint horizon band, and tall soft strips: the key at upper left
    /// (azimuth -50), a dim fill (+30) and a narrow rim (+125). Round 5 (pass 5 at night: strong rim light on both
    /// hull edges, dark in between): a metal cylinder seen from the front reflects, near its silhouette, what lies
    /// almost behind it, so two rim strips at +-`rimAzimuth` light both edges; the night room is darker.
    /// Image-based light only; it is never drawn.
    public static let rimAzimuth = 160.0
    public static func studio(_ theme: EntranceTheme = .night) -> CGImage? {
        let day = theme == .day
        // Round 11c: a darker room (night wall 0.04 -> 0.015, ceiling 0.13 -> 0.04; day wall 0.3 -> 0.1, ceiling
        // 0.5 -> 0.2, floor 0.16 -> 0.06), so the reflecting hull shows bright strips with dark flanks as on pass 5
        // instead of an evenly lit grey (r11b day read as paper). The fill strip 0.3 -> 0.45.
        let floor = day ? 0.06 : 0.012, wall = day ? 0.1 : 0.015, ceiling = day ? 0.2 : 0.04, horizon = day ? 0.04 : 0.02
        // Round 11 (owner: a thin white rim round the whole rocket, not in pass 5): the rim strips lit only the last
        // few pixels of the silhouette, at grazing angles where the metal reflects almost everything, so they drew
        // a hard white outline. They are now dim and broad (night 1.0 -> 0.2, day 0.8 -> 0.15; 4 -> 10 degrees
        // wide, softer edges), and the narrow strip at +125 is dimmed too (0.85 -> 0.35): the edges keep a faint
        // soft sheen, like pass 5, instead of a line.
        let rim = day ? 0.15 : 0.2
        return equirect { az, e in
            let s = sin(max(0, e) * Double.pi / 180)
            var v = e >= 0 ? wall + (ceiling - wall) * s * s : floor + (wall - floor) * max(0, 1 + e / 25)
            v += horizon * exp(-(e / 8) * (e / 8))
            v = max(v, strip(az, e, centre: -50, half: 10, low: -25, high: 80))
            v = max(v, 0.45 * strip(az, e, centre: 30, half: 5, low: -10, high: 70))
            v = max(v, 0.35 * strip(az, e, centre: 125, half: 4, low: -15, high: 75))
            v = max(v, rim * strip(az, e, centre: -rimAzimuth, half: 10, low: -15, high: 75, soft: 20))
            v = max(v, rim * 0.9 * strip(az, e, centre: rimAzimuth, half: 10, low: -15, high: 75, soft: 20))
            return v
        }
    }
}
#endif
