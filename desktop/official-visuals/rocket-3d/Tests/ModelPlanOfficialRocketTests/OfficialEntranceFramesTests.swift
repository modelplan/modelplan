// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Slice 4: the brand rocket in the native entrance scene. The main package never references this pack, so the
// official-model frames are rendered here: grey box (pose gates against the storyboard) and the night and day
// looks with the canopy glass, both on black space (owner D116). With MODELPLAN_ENTRANCE_FRAMES_DIR set,
// full-size PNGs and the comparison JSON are written there for the owner boards.
#if canImport(RealityKit) && canImport(Metal)
import AppKit
import CoreGraphics
import Foundation
import ImageIO
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

    /// Round 10 (owner Q3): a stored cockpit snapshot for the renders, from MODELPLAN_ENTRANCE_COCKPIT_NIGHT/_DAY
    /// (a PNG of the cockpit page, 1 px per point of its 636 pt raster, transparent outside the shell). It covers
    /// the storyboard cockpit's raster: x from the cockpit left minus its 8 pt margin, y from the cockpit top. Never
    /// committed (it shows the user's own screen); without it the bundled cockpit image is used.
    @available(macOS 15.0, *)
    private func snapshot(_ theme: EntranceTheme) -> CockpitSnapshot? {
        let key = "MODELPLAN_ENTRANCE_COCKPIT_" + (theme == .night ? "NIGHT" : "DAY")
        guard let path = ProcessInfo.processInfo.environment[key],
              let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let width = 636.0, height = width * Double(image.height) / Double(image.width)
        return CockpitSnapshot(image: image, frame: .init(left: StoryboardScenario.cockpitLeft - 8, top: StoryboardScenario.cockpitTop,
                                                          width: width, height: height))
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
            let stored = StoredCockpitSnapshot(snapshot(theme))
            let scene = try await EntranceScene.make(plan: plan, parts: [.hull, .glass], flat: false, rocket: source, look: look, cockpit: stored)
            print("OFFICIAL-SNAPSHOT \(theme.rawValue) cockpit \(scene.cockpit)" +
                  (stored.snapshot.map { " \($0.image.width)x\($0.image.height) px at \(Int($0.frame.left)),\(Int($0.frame.top))" } ?? ""))
            if stored.snapshot != nil { XCTAssertEqual(scene.cockpit, "snapshot", "\(theme) snapshot not used") }
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
            // Round 9 (D146): centred on the new window (centre 12.78, glass surface z ~0.82).
            let windowCentre = EntranceVector(0, 12.78, 0.82), e = 20.0 * Double.pi / 180
            let eye = windowCentre + EntranceVector(0, -sin(e), cos(e)) * 4.0
            let closeup = EntranceCamera(position: eye, orientation: .lookAt(eye: eye, target: .init(0, 12.945, 0.5)), fovDegrees: 30,
                                         viewport: .init(width: 1000, height: 1000))
            let image = try await scene.render(camera: closeup, rise: 0)
            print("OFFICIAL-FRAME \(theme.rawValue) window-closeup coverage \(String(format: "%.3f", coverage(image)))")
            XCTAssertGreaterThan(coverage(image), 0.2, "\(theme) close-up misses the capsule")
            try save(image, "official-window-closeup-\(theme.rawValue)")
            // Round 10 (owner: the lower body read as ceramic tile at night): a close-up of the lower stage, from
            // about 4 m, slightly below and to the right, the key light from the upper left.
            let bodyTarget = EntranceVector(0, 4.2, 0), bodyEye = EntranceVector(1.1, 2.9, 3.9)
            let body = EntranceCamera(position: bodyEye, orientation: .lookAt(eye: bodyEye, target: bodyTarget), fovDegrees: 30,
                                      viewport: .init(width: 1000, height: 1000))
            let bodyImage = try await scene.render(camera: body, rise: 0)
            print("OFFICIAL-FRAME \(theme.rawValue) lower-body coverage \(String(format: "%.3f", coverage(bodyImage)))")
            XCTAssertGreaterThan(coverage(bodyImage), 0.3, "\(theme) lower-body close-up misses the hull")
            try save(bodyImage, "official-lower-body-\(theme.rawValue)")
            // Round 11: the middle and lower body framed like the prototype crop on the owner board (pass-5 three-quarter
            // still: about 6.1 m of hull from y 1.0 to 7.1, the lower stage about 46 % of the width, 5:6), so the panel
            // language is compared at the same scale.
            let matchedTarget = EntranceVector(0, 4.05, 0), matchedEye = EntranceVector(3.9, 3.6, 10.7)
            let matched = EntranceCamera(position: matchedEye, orientation: .lookAt(eye: matchedEye, target: matchedTarget), fovDegrees: 30,
                                         viewport: .init(width: 1000, height: 1200))
            let matchedImage = try await scene.render(camera: matched, rise: 0)
            print("OFFICIAL-FRAME \(theme.rawValue) lower-body-matched coverage \(String(format: "%.3f", coverage(matchedImage)))")
            XCTAssertGreaterThan(coverage(matchedImage), 0.2, "\(theme) matched lower-body frame misses the hull")
            try save(matchedImage, "official-lower-body-matched-\(theme.rawValue)")
            // CKP-ENT-13: the decals close up, from the front: the skirt and lower stage (plate 18, vents 16/17,
            // stencil panel 19, door 11, L hatch 12) and the upper door U1 with its handle box U2.
            for (name, eye, target) in [("decals-lower", EntranceVector(0.5, 1.7, 4.6), EntranceVector(-0.15, 1.9, 0)),
                                        ("decals-upper", EntranceVector(0.3, 8.4, 3.4), EntranceVector(0, 8.5, 0))] {
                let camera = EntranceCamera(position: eye, orientation: .lookAt(eye: eye, target: target), fovDegrees: 30,
                                            viewport: .init(width: 1000, height: 1000))
                let image = try await scene.render(camera: camera, rise: 0)
                print("OFFICIAL-FRAME \(theme.rawValue) \(name) coverage \(String(format: "%.3f", coverage(image)))")
                XCTAssertGreaterThan(coverage(image), 0.3, "\(theme) \(name) misses the hull")
                try save(image, "official-\(name)-\(theme.rawValue)")
            }
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
                    if look.hullKit != nil {
                        // CKP-ENT-13: the base metal's roughness tile (and the decals') is a map with the theme's
                        // roughness already in it.
                        XCTAssertNotNil(pbr.roughness.texture, "\(theme) hull roughness map")
                        XCTAssertEqual(pbr.roughness.scale, 1, accuracy: 0.001, "\(theme) hull roughness map scale")
                    } else {
                        XCTAssertLessThanOrEqual(pbr.roughness.scale, 0.4, "\(theme) hull roughness")
                        XCTAssertNil(pbr.roughness.texture, "\(theme) hull roughness texture")
                    }
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
            // Round 10 (owner on r9: "why is there a white frame round the window?"): the rim is dark metal now.
            for tint in try tints("canopy_inner_rim") {
                XCTAssertLessThan(tint, 0.35, "\(theme) inner rim must not be white")
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
                let backdrop = try XCTUnwrap(scene.entity(named: "cockpit-backdrop"), "\(theme) no cockpit image behind the window")
                // Round 8: the image sits behind the middle of the window (r7b: only its bottom edge showed) and
                // stays inside the capsule (the plane is clipped to the capsule radius).
                let box = backdrop.visualBounds(relativeTo: backdrop.parent)
                print("OFFICIAL-BACKDROP \(theme.rawValue) y \(String(format: "%.2f-%.2f", box.min.y, box.max.y)) " +
                      "x \(String(format: "%.2f-%.2f", box.min.x, box.max.x)) z \(String(format: "%.2f-%.2f", box.min.z, box.max.z))")
                XCTAssertGreaterThan(box.max.y, 13.3, "\(theme) cockpit image does not reach above the window centre")
                XCTAssertLessThan(box.min.y, 12.6, "\(theme) cockpit image does not reach below the window centre")
                XCTAssertLessThan(max(abs(box.min.x), abs(box.max.x)), 0.85, "\(theme) cockpit image pokes out of the capsule")
                for material in try XCTUnwrap(backdrop.components[ModelComponent.self]).materials {
                    XCTAssertNotNil((material as? UnlitMaterial)?.color.texture, "\(theme) cockpit image is not an unlit texture")
                }
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
            // D146 (round 9): the window's shape follows the pass-5 prototype. Measured on the window still with a
            // camera fitted to the capsule silhouette and two panel rings (entrance-r9/cam5.py): the cast glass
            // edge is 2.09 x as wide as tall (chart width along the glass arc), its top quarter 0.77 x as wide as
            // its bottom quarter, from y 12.48 to 13.08 (the file's window: 1.65, 0.79, 12.40-13.27).
            let rocketFrame = try XCTUnwrap(scene.entity(named: "canopy-hull-patch")?.parent, "\(theme) no hull patch round the window")
            var glassPoints: [SIMD3<Float>] = []
            func gather(_ e: Entity) {
                if let model = e.components[ModelComponent.self] {
                    for part in model.mesh.contents.models.flatMap({ Array($0.parts) }) {
                        glassPoints += part.positions.elements.map { e.convert(position: $0, to: rocketFrame) }
                    }
                }
                e.children.forEach(gather)
            }
            gather(try XCTUnwrap(scene.entity(named: "curved_canopy_glass")))
            let glassY = glassPoints.map(\.y)
            let bottomY = try XCTUnwrap(glassY.min()), topY = try XCTUnwrap(glassY.max()), glassHeight = topY - bottomY
            func chartWidth(_ lo: Float, _ hi: Float) -> Float {
                let xs = glassPoints.filter { $0.y >= lo && $0.y <= hi }.map { atan2($0.x, $0.z) * ($0.x * $0.x + $0.z * $0.z).squareRoot() }
                return (xs.max() ?? 0) - (xs.min() ?? 0)
            }
            let ratio = chartWidth(bottomY, topY) / glassHeight
            let taper = chartWidth(topY - 0.25 * glassHeight, topY) / chartWidth(bottomY, bottomY + 0.25 * glassHeight)
            print("OFFICIAL-WINDOW \(theme.rawValue) y \(String(format: "%.3f-%.3f", bottomY, topY)) width/height \(String(format: "%.2f", ratio)) " +
                  "top/bottom \(String(format: "%.3f", taper)) nose above \(String(format: "%.2f", 14.2 - topY)) m")
            XCTAssertEqual(ratio, 2.09, accuracy: 0.05 * 2.09, "\(theme) window proportions differ from the prototype")
            XCTAssertEqual(taper, 0.77, accuracy: 0.05 * 0.77, "\(theme) window taper differs from the prototype")
            XCTAssertEqual(bottomY, 12.48, accuracy: 0.03, "\(theme) window bottom")
            XCTAssertEqual(topY, 13.08, accuracy: 0.03, "\(theme) window top")
            // Round 5: the hull albedo and normal map are the code-drawn panel maps.
            print("OFFICIAL-ALBEDO \(theme.rawValue) \(scene.hullAlbedo)")
            XCTAssertTrue(scene.hullAlbedo.hasPrefix("panels"), "\(theme) hull albedo: \(scene.hullAlbedo)")
            // CKP-ENT-13: the official pack ships the hull kit; the lower body has its own band.
            XCTAssertNotNil(look.hullKit, "the official pack has no hull kit")
            XCTAssertTrue(scene.hullAlbedo.contains("lower 4096x2048"), "\(theme) hull albedo: \(scene.hullAlbedo)")
            XCTAssertTrue(scene.hullAlbedo.contains("kit \(theme.rawValue) 6 kinds 9 decals"), "\(theme) hull albedo: \(scene.hullAlbedo)")
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

    // MARK: D185 step 1: material and light sample matrix (test only, opt-in)

    /// D185 (owner: the hull still reads block by block next to pass 5, satin brushed aluminium under broad soft
    /// light with dark flanks). Roughness alone has looped (rounds 10-11c: rough + thin strips read as paper, glossy
    /// + strips as chrome), so the light is the primary axis: (a) the current strip studio, (b) two wide vertical
    /// softboxes (left key wide, right fill narrower) in a dark room, (c) the same softboxes twice as wide plus a
    /// soft top fill; day rooms are a light-grey backdrop like the pass-5 day still. Per light: roughness
    /// {current map (night 0.22 / day 0.25), 0.38, 0.5}, anisotropy {0.4, 0}, clearcoat {current, off}, minus the
    /// combinations that cannot match (strips at 0.5). Two controls under (b): the seam normal map off ("smooth")
    /// and the base-colour map off ("flat", a plain colour at the plain panel's tone), to see whether the per-panel
    /// steps come from the normals, the maps or the light. Overrides are applied to the built hull materials; the
    /// product is unchanged. Runs only with MODELPLAN_ENTRANCE_MATRIX=1 and writes
    /// `matrix-<theme>-<light>-r..-a..-cc..-<control>-<side|tq>.png` to MODELPLAN_ENTRANCE_FRAMES_DIR.
    @MainActor
    func testD185MaterialSampleMatrix() async throws {
        guard ProcessInfo.processInfo.environment["MODELPLAN_ENTRANCE_MATRIX"] == "1" else {
            throw XCTSkip("set MODELPLAN_ENTRANCE_MATRIX=1 to render the D185 material matrix")
        }
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        struct Tile {
            var light = "strips", rough: Float? = nil, aniso: Float? = nil, clearcoat: Float? = nil, control = "none"
            var name: String {
                func f(_ v: Float?) -> String { v.map { String(format: "%.2f", $0) } ?? "cur" }
                return "\(light)-r\(f(rough))-a\(f(aniso))-cc\(f(clearcoat))-\(control)"
            }
        }
        var tiles: [Tile] = []
        // (a) strips: roughness {current, 0.38} x anisotropy {current, 0}, plus clearcoat off at 0.38 (5).
        for rough: Float? in [nil, 0.38] {
            for aniso: Float? in [nil, 0] { tiles.append(Tile(light: "strips", rough: rough, aniso: aniso)) }
        }
        tiles.append(Tile(light: "strips", rough: 0.38, aniso: 0, clearcoat: 0))
        // (b), (c) softboxes: roughness {current, 0.38, 0.5} x anisotropy {current, 0}, plus clearcoat off at 0.38 and
        // 0.5 (8 each).
        for light in ["softbox", "softbox-wide"] {
            for rough: Float? in [nil, 0.38, 0.5] {
                for aniso: Float? in [nil, 0] { tiles.append(Tile(light: light, rough: rough, aniso: aniso)) }
            }
            for rough: Float in [0.38, 0.5] { tiles.append(Tile(light: light, rough: rough, aniso: 0, clearcoat: 0)) }
        }
        // Controls (2).
        tiles.append(Tile(light: "softbox", rough: 0.38, aniso: 0, control: "smooth"))
        tiles.append(Tile(light: "softbox", rough: 0.38, aniso: 0, control: "flat"))
        XCTAssertEqual(tiles.count, 23)
        // The pass-5 side still (day-side.jpg / night-side.jpg, 1024 x 1536): hull level-on, the 0.24-7.0 m stretch
        // in the crop x 380-650, y 735-1340 (270 x 605 px), the skirt 228 px wide. Same stretch here, nearly
        // orthographic (fov 20, 19.17 m away), 540 x 1210 px (2x the crop). Plus a three-quarter view.
        let sideEye = EntranceVector(0, 3.62, 19.17)
        let side = EntranceCamera(position: sideEye, orientation: .lookAt(eye: sideEye, target: .init(0, 3.62, 0)),
                                  fovDegrees: 20, viewport: .init(width: 540, height: 1210))
        let tqEye = EntranceVector(9.6, 1.2, 16.6)
        let threeQuarter = EntranceCamera(position: tqEye, orientation: .lookAt(eye: tqEye, target: .init(0, 3.62, 0)),
                                          fovDegrees: 20, viewport: .init(width: 540, height: 1210))
        let source = try OfficialRocket.source(), look = try OfficialRocket.lookImages()
        let hullNames = ["aft_skirt", "lower_stage", "long_slanted_interstage", "slender_upper_body", "capsule_lower",
                         "capsule_aperture_shell", "capsule_nose", "canopy-hull-patch"]
        for theme in EntranceTheme.allCases {
            let plan = StoryboardScenario.plan(edge: "right", theme: theme, geometry: source.geometry)
            let scene = try EntranceScene(plan: plan, parts: [.hull, .glass], flat: false, rocket: source, look: look)
            var originals: [(Entity, [any RealityKit.Material])] = []
            func collect(_ e: Entity) {
                if let model = e.components[ModelComponent.self] { originals.append((e, model.materials)) }
                e.children.forEach(collect)
            }
            for name in hullNames { if let e = scene.entity(named: name) { collect(e) } }
            XCTAssertFalse(originals.isEmpty, "\(theme): no hull meshes")
            var lights: [String: CGImage] = ["strips": try XCTUnwrap(EntranceLook.studio(theme))]
            for light in ["softbox", "softbox-wide"] { lights[light] = try XCTUnwrap(softboxes(theme, wide: light == "softbox-wide")) }
            // The plain panel's tone for "flat": the kit's base metal is ~0.74 (night) / ~0.9 (day) of the tint.
            let plainTone: CGFloat = theme == .day ? 0.9 : 0.74
            for tile in tiles {
                for (e, materials) in originals {
                    guard var model = e.components[ModelComponent.self] else { continue }
                    model.materials = materials.map { material -> any RealityKit.Material in
                        guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                        if let r = tile.rough { pbr.roughness = .init(floatLiteral: r) }
                        if let a = tile.aniso { pbr.anisotropyLevel = .init(floatLiteral: a) }
                        if let c = tile.clearcoat { pbr.clearcoat = .init(floatLiteral: c) }
                        if tile.control == "smooth" { pbr.normal.texture = nil }
                        if tile.control == "flat", let tint = pbr.baseColor.tint.usingColorSpace(.sRGB) {
                            pbr.baseColor = .init(tint: NSColor(srgbRed: tint.redComponent * plainTone, green: tint.greenComponent * plainTone,
                                                                blue: tint.blueComponent * plainTone, alpha: 1))
                        }
                        return pbr
                    }
                    e.components.set(model)
                }
                try await scene.setEnvironment(try XCTUnwrap(lights[tile.light]), intensityExponent: EntranceLook.environmentExponent(theme))
                for (view, camera) in [("side", side), ("tq", threeQuarter)] {
                    let image = try await scene.render(camera: camera, rise: 0)
                    let name = "matrix-\(theme.rawValue)-\(tile.name)-\(view)"
                    print("D185-MATRIX \(name) coverage \(String(format: "%.3f", coverage(image)))")
                    XCTAssertGreaterThan(coverage(image), 0.2, "\(name) misses the hull")
                    try save(image, name)
                }
            }
        }
    }

    /// Softbox rooms for the D185 matrix, equirectangular 512 x 256, sRGB-encoded linear light, azimuths in the
    /// scene's convention (0 = +z, the camera side; `EntranceLook.imageCentreAzimuth` turns the image as the
    /// product's studio does). Two tall vertical softboxes: a wide key at the left (-50) and a narrower, dimmer
    /// fill at the right (+40), soft edges. `wide`: both twice as wide, plus a soft top fill. Night: a dark room;
    /// day: a light-grey backdrop like the pass-5 day still.
    private func softboxes(_ theme: EntranceTheme, wide: Bool) -> CGImage? {
        let w = 512, h = 256, day = theme == .day
        let room = day ? 0.35 : 0.012, floor = day ? 0.25 : 0.008
        let scale = wide ? 2.0 : 1.0
        func box(_ az: Double, _ e: Double, centre: Double, half: Double, low: Double, high: Double, soft: Double) -> Double {
            let da = abs((az - centre + 540).truncatingRemainder(dividingBy: 360) - 180)
            let fx = max(0, 1 - max(0, da - half) / soft), fy = max(0, 1 - max(0, low - e, e - high) / 20)
            return fx * fx * (3 - 2 * fx) * fy * fy * (3 - 2 * fy)
        }
        guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = c.data
        else { return nil }
        let p = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        for y in 0..<h {
            let e = 90 - 180 * (Double(y) + 0.5) / Double(h)
            for x in 0..<w {
                let image = 360 * (Double(x) + 0.5) / Double(w) - 180
                let az = (image + EntranceLook.imageCentreAzimuth + 540).truncatingRemainder(dividingBy: 360) - 180
                var v = e >= 0 ? room : floor + (room - floor) * max(0, 1 + e / 25)
                v = max(v, box(az, e, centre: -50, half: 14 * scale, low: -20, high: 70, soft: 12 * scale))
                v = max(v, 0.5 * box(az, e, centre: 40, half: 7 * scale, low: -15, high: 65, soft: 10 * scale))
                if wide { v = max(v, (day ? 0.7 : 0.25) * max(0, (e - 35) / 55)) }
                let linear = min(1, max(0, v))
                let encoded = linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1 / 2.4) - 0.055
                let level = UInt8((encoded * 255).rounded()), o = (y * w + x) * 4
                p[o] = level; p[o + 1] = level; p[o + 2] = level; p[o + 3] = 255
            }
        }
        return c.makeImage()
    }
}
#endif
