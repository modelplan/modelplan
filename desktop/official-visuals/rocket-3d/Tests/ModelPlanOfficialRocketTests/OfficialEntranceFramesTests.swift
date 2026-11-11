// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Slice 4: the brand rocket in the native entrance scene. The main package never references this pack, so the
// official-model frames are rendered here: grey box (pose gates against the storyboard) and the night and day
// looks with the canopy glass, both on black space (owner D116). With MODELPLAN_ENTRANCE_FRAMES_DIR set,
// full-size PNGs and the comparison JSON are written there for the owner boards.
#if canImport(RealityKit) && canImport(Metal)
import AppKit
import CoreGraphics
import Foundation
import ModelPlanEntrance
import ModelPlanEntranceScene
import RealityKit
import simd
@testable import ModelPlanOfficialRocket
import XCTest

final class OfficialEntranceFramesTests: XCTestCase {
    private var out: URL? {
        ProcessInfo.processInfo.environment["MODELPLAN_ENTRANCE_FRAMES_DIR"].map { URL(fileURLWithPath: $0) }
    }

    private func save(_ image: CGImage, _ name: String) throws {
        guard let out else { return }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try EntranceFrameFile.writePNG(image, to: out.appendingPathComponent(name + ".png"))
    }

    /// Fraction of pixels that differ from the top-left background pixel.
    private func coverage(_ image: CGImage) -> Double {
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let c = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return 0 }
        var n = 0
        let r0 = Int(bytes[0]), g0 = Int(bytes[1]), b0 = Int(bytes[2])
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let dr: Int = abs(Int(bytes[i]) - r0), dg: Int = abs(Int(bytes[i + 1]) - g0), db: Int = abs(Int(bytes[i + 2]) - b0)
            if dr + dg + db > 30 { n += 1 }
        }
        return Double(n) / Double(w * h)
    }

    /// The official rocket in the grey box at the storyboard stages for every edge. The structural comparison with
    /// the approved storyboard stills is printed (the blocking pose gate stays on the stand-in in the main package).
    @MainActor
    func testOfficialRocketGreyBoxAtTheStoryboardStages() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let source = try OfficialRocket.source()
        let results = try await StoryboardCapture.run(rocket: source)
        XCTAssertEqual(results.count, 9)
        for r in results {
            let measured = try XCTUnwrap(r.measurement, "no silhouette for \(r.edge) \(r.shot)")
            XCTAssertGreaterThan(measured.areaFraction, 0.01)
            if let c = r.comparison {
                print("OFFICIAL-POSE \(r.edge) \(r.shot) pose \(c.posePassed ? "pass" : "FAIL") " +
                      c.checks.map { "\($0.name)=\($0.passed ? "ok" : "diff") sb \($0.storyboard) native \($0.native)" }.joined(separator: "; "))
            }
            if r.edge == "right" { try save(r.image, "official-right-\(r.shot)-grey") }
        }
        if let out {
            try StoryboardCapture.report(results).write(to: out.appendingPathComponent("official-storyboard-comparison.json"))
        }
    }

    /// Night and day looks with the official finishes, right edge, every storyboard stage. Both themes are black
    /// space (no sky); day only has the stronger sun. The canopy is the glass material (owner D116).
    @MainActor
    func testOfficialRocketLookFramesNightAndDay() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let source = try OfficialRocket.source(), look = try OfficialRocket.lookImages()
        for theme in EntranceTheme.allCases {
            let plan = StoryboardScenario.plan(edge: "right", theme: theme, geometry: source.geometry)
            let scene = try EntranceScene(plan: plan, parts: [.hull, .glass], flat: false, rocket: source, look: look)
            try await scene.setEnvironment(XCTUnwrap(EntranceLook.studio(theme)), intensityExponent: EntranceLook.environmentExponent(theme))
            for (shot, t) in StoryboardScenario.stages(plan) {
                let frame = try await scene.render(at: t)
                let covered = coverage(frame.image)
                print("OFFICIAL-FRAME \(theme.rawValue) \(shot) coverage \(String(format: "%.3f", covered))")
                XCTAssertGreaterThan(covered, 0.01, "\(theme) \(shot) is empty")
                try save(frame.image, "official-right-\(shot)-\(theme.rawValue)")
            }
            // D132: the hand-over through the front window (end of the map stage: the glass covers the aperture).
            let handover = try await scene.render(at: plan.timeline.mapEnd - 0.001)
            XCTAssertGreaterThan(coverage(handover.image), 0.01, "\(theme) hand-over is empty")
            try save(handover.image, "official-right-handover-\(theme.rawValue)")
            // D132: the front window close-up, framed like the pass-5 window still (from about 20 degrees below,
            // the window about 60 % of the width, the nose above it), for the owner board.
            let windowCentre = EntranceVector(0, 12.835, 0.81), e = 20.0 * Double.pi / 180
            let eye = windowCentre + EntranceVector(0, -sin(e), cos(e)) * 4.0
            let closeup = EntranceCamera(position: eye, orientation: .lookAt(eye: eye, target: .init(0, 13.0, 0.5)), fovDegrees: 30,
                                         viewport: .init(width: 1000, height: 1000))
            let image = try await scene.render(camera: closeup, rise: 0)
            print("OFFICIAL-FRAME \(theme.rawValue) window-closeup coverage \(String(format: "%.3f", coverage(image)))")
            XCTAssertGreaterThan(coverage(image), 0.2, "\(theme) close-up misses the capsule")
            try save(image, "official-window-closeup-\(theme.rawValue)")
        }
    }

    /// Look mode dresses the hull as smooth polished metal (owner 2026-11-10: metal like the pass-5 art, not foam):
    /// metallic 1, satin roughness, no roughness texture; joints are dark metal, not ink; and the normals are
    /// smooth and radial, so the 24-sided hull has no facets and no hard seam where the texture wraps. Round 5: the
    /// file's grainy normal map is replaced by the code-drawn panel maps (seams, hatches, brushed grain).
    @MainActor
    func testOfficialHullIsSmoothMetalInLookMode() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let source = try OfficialRocket.source(), look = try OfficialRocket.lookImages()
        for theme in EntranceTheme.allCases {
            let plan = StoryboardScenario.plan(edge: "right", theme: theme, geometry: source.geometry)
            let scene = try EntranceScene(plan: plan, parts: [.hull, .glass], flat: false, rocket: source, look: look)
            func models(_ name: String) throws -> [ModelComponent] {
                let root = try XCTUnwrap(scene.entity(named: name), "no \(name)")
                var found: [ModelComponent] = []
                func collect(_ e: Entity) {
                    if let model = e.components[ModelComponent.self] { found.append(model) }
                    e.children.forEach(collect)
                }
                collect(root)
                XCTAssertFalse(found.isEmpty, "\(name) has no mesh")
                return found
            }
            for model in try models("slender_upper_body") {
                for material in model.materials {
                    let pbr = try XCTUnwrap(material as? PhysicallyBasedMaterial, "the hull must be a PBR metal")
                    XCTAssertEqual(pbr.metallic.scale, 1, accuracy: 0.001, "\(theme) hull metallic")
                    XCTAssertNil(pbr.metallic.texture, "\(theme) hull metallic texture")
                    XCTAssertLessThanOrEqual(pbr.roughness.scale, 0.4, "\(theme) hull roughness")
                    XCTAssertNil(pbr.roughness.texture, "\(theme) hull roughness texture")
                    XCTAssertNotNil(pbr.normal.texture, "\(theme) hull has no panel normal map")
                    XCTAssertNotNil(pbr.baseColor.texture, "\(theme) hull has no panel albedo")
                }
                // Normals point straight out from the axis: no 2.5-7.5 degree offsets, no 15 degree seam jump.
                var worst: Float = 0
                for part in model.mesh.contents.models.flatMap({ Array($0.parts) }) {
                    let positions = part.positions.elements
                    let normals = try XCTUnwrap(part.normals?.elements)
                    for (p, n) in zip(positions, normals) where simd_length(SIMD2<Float>(p.x, p.z)) > 0.1 {
                        let radial = simd_normalize(SIMD2<Float>(p.x, p.z)), side = simd_normalize(SIMD2<Float>(n.x, n.z))
                        worst = max(worst, acos(min(1, simd_dot(radial, side))) * 180 / .pi)
                    }
                }
                print("OFFICIAL-NORMALS \(theme.rawValue) slender_upper_body worst \(String(format: "%.2f", worst)) deg")
                XCTAssertLessThan(worst, 1, "\(theme) hull normals are not radial")
            }
            // Round 3: the hull is round (96 sides, was 24), seen on the top rim of the upper body.
            for model in try models("slender_upper_body") {
                let positions = model.mesh.contents.models.flatMap { Array($0.parts) }.flatMap { $0.positions.elements }
                let top = try XCTUnwrap(positions.map(\.y).max())
                let sides = Set(positions.filter { abs($0.y - top) < 0.001 && simd_length(SIMD2<Float>($0.x, $0.z)) > 0.1 }
                    .map { Int((atan2($0.x, $0.z) * 180 / .pi * 2).rounded()) })
                print("OFFICIAL-ROUND \(theme.rawValue) slender_upper_body top rim \(sides.count) sides")
                XCTAssertGreaterThanOrEqual(sides.count, 72, "\(theme) hull is still polygonal")
            }
            // Round 3: joints are hairlines. The proud torus is hidden; the edge ring is a dark-grey groove (not ink
            // black) with a light lip copy above it.
            XCTAssertEqual(scene.entity(named: "panel_joint_118")?.isEnabled, false, "\(theme) proud joint ring still drawn")
            XCTAssertNotNil(scene.entity(named: "joint_lip_118"), "\(theme) joint has no light lip")
            func tints(_ name: String) throws -> [CGFloat] {
                try models(name).flatMap(\.materials).map { material in
                    let pbr = try XCTUnwrap(material as? PhysicallyBasedMaterial, "\(name) is not a PBR")
                    return try XCTUnwrap(pbr.baseColor.tint.usingColorSpace(.sRGB)).redComponent
                }
            }
            for tint in try tints("joint_edge_118") {
                XCTAssertGreaterThan(tint, 0.08, "\(theme) joints must not be ink black")
            }
            // Round 5: the window frame is a thin dark band (not ink) with a bright rim on the glass edge.
            for tint in try tints("canopy_frame_bevel_2") {
                XCTAssertGreaterThan(tint, 0.05, "\(theme) frame must not be ink black")
            }
            for tint in try tints("canopy_inner_rim") {
                XCTAssertGreaterThan(tint, 0.6, "\(theme) inner rim must be bright")
            }
            func positions(_ name: String) throws -> [SIMD3<Float>] {
                try models(name).flatMap { $0.mesh.contents.models.flatMap { Array($0.parts) } }.flatMap { $0.positions.elements }
            }
            let glass = try positions("curved_canopy_glass")
            // Band width: how far a strip's outer edge lies from the glass edge (the file's inner strip was up to
            // 3.5 cm, the three strips 8-12 cm together).
            func width(_ name: String) throws -> Float {
                try positions(name).map { g in glass.map { simd_distance($0, g) }.min() ?? 0 }.max() ?? 0
            }
            let frame = try width("canopy_frame_bevel_2"), rim = try width("canopy_inner_rim")
            print("OFFICIAL-GASKET \(theme.rawValue) frame to glass \(String(format: "%.1f", frame * 100)) cm, " +
                  "rim \(String(format: "%.1f", rim * 100)) cm")
            XCTAssertLessThan(frame, 0.07, "\(theme) window frame is too wide")
            XCTAssertLessThan(rim, 0.012, "\(theme) inner rim is too wide")
            // Round 5/6: the cockpit is dim: the code-drawn console texture with small glowing screens and two nearer
            // screens, not the file's bright UI.
            if look.cockpitInterior(for: theme) == nil {
                for model in try models("interior_soft_screen_plane") {
                    for material in model.materials {
                        XCTAssertNotNil(material as? UnlitMaterial, "\(theme) cockpit console must be unlit")
                    }
                }
            }
            // D142: the pack's cockpit image when it ships, the code console until then.
            print("OFFICIAL-COCKPIT \(theme.rawValue) \(scene.cockpit) WINDOW \(scene.windowShape)")
            if look.cockpitInterior(for: theme) != nil {
                XCTAssertEqual(scene.cockpit, "image")
                XCTAssertNotNil(scene.entity(named: "cockpit-backdrop"), "\(theme) no cockpit image behind the window")
            } else {
                XCTAssertEqual(scene.cockpit, "code")
                XCTAssertNotNil(scene.entity(named: "cockpit-screen-0"), "\(theme) cockpit has no screens")
                let console = try XCTUnwrap(scene.entity(named: "cockpit-console")?.components[ModelComponent.self], "\(theme) no console")
                for material in console.materials {
                    XCTAssertNotNil((material as? UnlitMaterial)?.color.texture, "\(theme) console is not the drawn texture")
                }
            }
            // D142: the window's corners are rounded (glass and frame bands rebuilt from one outline).
            XCTAssertTrue(scene.windowShape.hasPrefix("rounded"), "\(theme) window: \(scene.windowShape)")
            // Round 5: the hull albedo and normal map are the code-drawn panel maps.
            print("OFFICIAL-ALBEDO \(theme.rawValue) \(scene.hullAlbedo)")
            XCTAssertTrue(scene.hullAlbedo.hasPrefix("panels"), "\(theme) hull albedo: \(scene.hullAlbedo)")
            XCTAssertEqual(scene.entity(named: "axial_panel_seam_0_66")?.isEnabled, false, "\(theme) file seam strips still drawn")
            // The cockpit lining around the screen, with the side screens: an unlit textured surface.
            let ceiling = try XCTUnwrap(scene.entity(named: "cockpit-ceiling")?.components[ModelComponent.self], "\(theme) no cockpit lining")
            for material in ceiling.materials {
                let unlit = try XCTUnwrap(material as? UnlitMaterial, "\(theme) cockpit lining must be unlit")
                XCTAssertNotNil(unlit.color.texture, "\(theme) cockpit lining has no screens texture")
            }
        }
    }

    /// The canopy in look mode is the glass material: see-through, glossy, clear-coated, never the flat grey.
    @MainActor
    func testOfficialCanopyIsGlassInLookMode() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let source = try OfficialRocket.source()
        let plan = StoryboardScenario.plan(edge: "right", theme: .night, geometry: source.geometry)
        let scene = try EntranceScene(plan: plan, parts: [.glass], flat: false, rocket: source)
        let glass = try XCTUnwrap(scene.entity(named: "curved_canopy_glass"))
        var materials: [any RealityKit.Material] = []
        func collect(_ e: Entity) {
            if let model = e.components[ModelComponent.self] { materials += model.materials }
            e.children.forEach(collect)
        }
        collect(glass)
        XCTAssertFalse(materials.isEmpty)
        for material in materials {
            let pbr = try XCTUnwrap(material as? PhysicallyBasedMaterial, "the canopy must be a PBR glass")
            XCTAssertLessThanOrEqual(pbr.roughness.scale, 0.1)
            XCTAssertGreaterThanOrEqual(pbr.clearcoat.scale, 0.9)
            guard case .transparent(let opacity) = pbr.blending else { return XCTFail("the canopy must be see-through") }
            XCTAssertLessThan(opacity.scale, 0.8)
            XCTAssertGreaterThan(opacity.scale, 0.2)
        }
    }
}
#endif
