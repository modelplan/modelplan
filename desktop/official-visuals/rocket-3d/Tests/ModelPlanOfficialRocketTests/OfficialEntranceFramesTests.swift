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
        let source = try OfficialRocket.source()
        for theme in EntranceTheme.allCases {
            let plan = StoryboardScenario.plan(edge: "right", theme: theme, geometry: source.geometry)
            let scene = try EntranceScene(plan: plan, parts: [.hull, .glass], flat: false, rocket: source)
            try await scene.setEnvironment(XCTUnwrap(EntranceLook.studio(theme)), intensityExponent: EntranceLook.environmentExponent(theme))
            for (shot, t) in StoryboardScenario.stages(plan) {
                let frame = try await scene.render(at: t)
                let covered = coverage(frame.image)
                print("OFFICIAL-FRAME \(theme.rawValue) \(shot) coverage \(String(format: "%.3f", covered))")
                XCTAssertGreaterThan(covered, 0.01, "\(theme) \(shot) is empty")
                try save(frame.image, "official-right-\(shot)-\(theme.rawValue)")
            }
        }
    }

    /// Look mode dresses the hull as smooth polished metal (owner 2026-11-10: metal like the pass-5 art, not foam):
    /// metallic 1, satin roughness, no grainy normal map; joints are dark metal, not ink; and the normals are
    /// smooth and radial, so the 24-sided hull has no facets and no hard seam where the texture wraps.
    @MainActor
    func testOfficialHullIsSmoothMetalInLookMode() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let source = try OfficialRocket.source()
        for theme in EntranceTheme.allCases {
            let plan = StoryboardScenario.plan(edge: "right", theme: theme, geometry: source.geometry)
            let scene = try EntranceScene(plan: plan, parts: [.hull, .glass], flat: false, rocket: source)
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
                    XCTAssertNil(pbr.normal.texture, "\(theme) hull normal map")
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
            for tint in try tints("canopy_frame_bevel_2") {
                XCTAssertGreaterThan(tint, 0.05, "\(theme) gasket must not be ink black")
            }
            let gasket = try models("canopy_frame_bevel_2").flatMap { $0.mesh.contents.models.flatMap { Array($0.parts) } }
                .flatMap { $0.positions.elements }
            let glass = try models("curved_canopy_glass").flatMap { $0.mesh.contents.models.flatMap { Array($0.parts) } }
                .flatMap { $0.positions.elements }
            // Gasket width: how far its outer edge lies from the glass edge (the file's strip was up to 3.5 cm).
            let width = gasket.map { g in glass.map { simd_distance($0, g) }.min() ?? 0 }.max() ?? 0
            print("OFFICIAL-GASKET \(theme.rawValue) gasket width \(String(format: "%.1f", width * 100)) cm")
            XCTAssertLessThan(width, 0.02, "\(theme) gasket is still wide")
            // The cockpit behind the glass: a lit console drawn in code.
            XCTAssertNotNil(scene.entity(named: "cockpit-screen-0"), "\(theme) no cockpit screens behind the glass")
            XCTAssertNotNil(scene.entity(named: "cockpit-console-screen-0"), "\(theme) no overhead console where the end-pose camera looks")
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
