// SPDX-License-Identifier: MIT
// Slice 1 render checks (GUI leg: Metal + RealityKit offscreen, no window). The core's camera math is the
// contract; these tests prove RealityKit draws what the core projects, so frame-matching against the web
// reference reduces to the numeric goldens plus look differences. Neutral stand-in only, no official art.
#if canImport(RealityKit) && canImport(Metal)
import CoreGraphics
import Foundation
import ImageIO
import ModelPlanEntrance
import ModelPlanEntranceChecksKit
import ModelPlanEntranceScene
import UniformTypeIdentifiers
import XCTest

final class EntranceSceneRenderTests: XCTestCase {
    private func plan(_ theme: EntranceTheme = .night) -> EntrancePlan {
        EntrancePlan(.init(dockIDs: ["claude", "codex", "zcode", "glm"], rollDistance: 800,
                           liftOff: ReferenceGoldens.liftOff, theme: theme))
    }

    /// Bounding box of pixels that differ from the top-left background pixel, in image pixels.
    private func silhouette(_ image: CGImage) -> CGRect? {
        let w = image.width, h = image.height, rowBytes = w * 4
        var bytes = [UInt8](repeating: 0, count: rowBytes * h)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: rowBytes,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        let bg = Array(bytes[0..<4])
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                let o = y * rowBytes + x * 4
                var differs = false
                for c in 0..<4 where abs(Int(bytes[o + c]) - Int(bg[c])) > 64 { differs = true }
                if differs { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
            }
        }
        guard maxX >= 0 else { return nil }
        // Row 0 of a bitmap context's memory is the image's top row.
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func clipped(_ r: EntranceRect, _ viewport: EntranceSize) -> CGRect {
        CGRect(x: r.left, y: r.top, width: r.width, height: r.height)
            .intersection(CGRect(x: 0, y: 0, width: viewport.width, height: viewport.height))
    }

    /// The core's expected on-screen silhouette of the filled tail disc: dense samples of the disc, projected,
    /// keeping only those inside the viewport (a clipped ellipse is narrower than its clipped bounding box).
    private func visibleTailDisc(_ pose: LiftOffPose) -> CGRect? {
        let vp = pose.camera.viewport
        var points: [EntrancePoint] = []
        for ring in 1...24 {
            let r = LiftOffRail.tailRingRadius * Double(ring) / 24
            for i in 0..<256 {
                let a = 2 * Double.pi * Double(i) / 256
                let p = pose.camera.project(.init(sin(a) * r, TailLayout.plateY + pose.rise, cos(a) * r)).point
                if p.x >= 0, p.x < vp.width, p.y >= 0, p.y < vp.height { points.append(p) }
            }
        }
        guard !points.isEmpty else { return nil }
        let b = EntranceRect.bounds(points)
        return CGRect(x: b.left, y: b.top, width: b.width, height: b.height)
    }

    private func assertNear(_ actual: CGRect, _ expected: CGRect, tolerance: CGFloat, _ what: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        let t = max(tolerance, 0.01 * max(expected.width, expected.height))
        for (a, e, edge) in [(actual.minX, expected.minX, "left"), (actual.minY, expected.minY, "top"),
                             (actual.maxX, expected.maxX, "right"), (actual.maxY, expected.maxY, "bottom")] {
            XCTAssertLessThanOrEqual(abs(a - e), t, "\(what) \(edge): rendered \(a), core \(e)", file: file, line: line)
        }
    }

    @MainActor
    func testRealityKitTailRingLandsWhereTheCoreProjectsItAtLiftOff() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let plan = plan(), scene = try EntranceScene(plan: plan, parts: [.tailRing])
        for progress in [0.0, 0.25] {
            let t = plan.timeline.liftOffStart + progress * EntranceTimeline.liftOffDuration
            let frame = try await scene.render(at: t)
            let pose = try XCTUnwrap(frame.facts.liftOff)
            XCTAssertTrue(pose.tailInFront)
            XCTAssertEqual(frame.image.width, Int(pose.camera.viewport.width))
            let rendered = try XCTUnwrap(silhouette(frame.image), "tail ring not drawn at \(progress)")
            let expected = try XCTUnwrap(visibleTailDisc(pose))
            assertNear(rendered, expected, tolerance: 2, "tail ring at \(progress)")
        }
    }

    @MainActor
    func testRealityKitCanopyLandsOnTheC01ApertureAtTheEndOfLiftOff() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let plan = plan(), scene = try EntranceScene(plan: plan, parts: [.glass])
        for progress in [0.5, 1.0] {
            let t = plan.timeline.liftOffStart + progress * EntranceTimeline.liftOffDuration
            let frame = try await scene.render(at: t)
            let pose = try XCTUnwrap(frame.facts.liftOff)
            let rendered = try XCTUnwrap(silhouette(frame.image), "glass not drawn at \(progress)")
            assertNear(rendered, clipped(pose.windowRect, pose.camera.viewport), tolerance: 2, "canopy at \(progress)")
        }
        // The end pose: the window is exactly the aperture's width and centred on it (spec §3.3).
        let end = try await scene.render(at: plan.timeline.mapStart)
        let rendered = try XCTUnwrap(silhouette(end.image))
        XCTAssertEqual(rendered.midX, 1090, accuracy: 2)
        XCTAssertEqual(rendered.width, 420, accuracy: 4)
    }

    /// Slice 2: the native frame at each storyboard key-frame stage is measured and compared structurally with
    /// the approved storyboard still. Report-only until slice 3 (D111 camera); the harness itself must work.
    @MainActor
    func testStoryboardKeyFrameComparisonProducesAReportForEveryEdge() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let results = try await StoryboardCapture.run()
        XCTAssertEqual(results.map(\.edge), ["right", "bottom", "left"])
        for r in results {
            let measured = try XCTUnwrap(r.measurement, "no silhouette for \(r.edge)")
            XCTAssertGreaterThan(measured.areaFraction, 0.01)
            let comparison = try XCTUnwrap(r.comparison, "no storyboard key frame for \(r.edge) \(r.shot)")
            XCTAssertEqual(comparison.checks.count, 7)
            for check in comparison.checks where !check.passed {
                print("STORYBOARD-DIFF \(r.edge) \(r.shot) \(check.name): storyboard \(check.storyboard) native \(check.native) tol \(check.tolerance)")
            }
        }
        let report = try StoryboardCapture.report(results)
        if let dir = ProcessInfo.processInfo.environment["MODELPLAN_ENTRANCE_FRAMES_DIR"] {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try report.write(to: URL(fileURLWithPath: dir).appendingPathComponent("storyboard-comparison.json"))
        }
    }

    /// Renders every 3D frame-match timestamp for both themes; with MODELPLAN_ENTRANCE_FRAMES_DIR set, writes the
    /// PNGs there (neutral stand-in only, safe for public CI artifacts).
    @MainActor
    func testStandInRendersEveryLiftOffTimestampInBothThemes() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let out = ProcessInfo.processInfo.environment["MODELPLAN_ENTRANCE_FRAMES_DIR"].map { URL(fileURLWithPath: $0) }
        for theme in EntranceTheme.allCases {
            for flat in [true, false] {
                let plan = plan(theme), scene = try EntranceScene(plan: plan, parts: [.hull, .glass], flat: flat)
                for t in plan.frameMatchTimestamps where plan.facts(at: t).liftOff != nil {
                    let frame = try await scene.render(at: t)
                    XCTAssertNotNil(silhouette(frame.image), "empty frame at \(t) \(theme) flat \(flat)")
                    if let out {
                        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
                        let url = out.appendingPathComponent(String(format: "standin-%@-%@-%.3f.png", theme.rawValue, flat ? "grey" : "look", t))
                        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
                        CGImageDestinationAddImage(destination, frame.image, nil)
                        XCTAssertTrue(CGImageDestinationFinalize(destination))
                    }
                }
            }
        }
    }
}
#endif
