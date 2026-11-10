// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Slice 4: the brand rocket in the native entrance scene. The main package never references this pack, so the
// official-model frames are rendered here: grey box (pose gates against the storyboard), night look, the capsule
// close-up with the code detail (asset audit option A) and the day-sky trial. With MODELPLAN_ENTRANCE_FRAMES_DIR
// set, full-size PNGs and the comparison JSON are written there for the owner boards.
#if canImport(RealityKit) && canImport(Metal)
import CoreGraphics
import Foundation
import ModelPlanEntrance
import ModelPlanEntranceScene
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
        for i in stride(from: 0, to: bytes.count, by: 4) where abs(Int(bytes[i]) - Int(bytes[0])) + abs(Int(bytes[i + 1]) - Int(bytes[1])) + abs(Int(bytes[i + 2]) - Int(bytes[2])) > 30 { n += 1 }
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

    /// Night look and the day-sky trial with the official finishes, right edge, three stages; the end frame also
    /// renders with the capsule detail (option A) so the owner can compare the close-up with and without it.
    @MainActor
    func testOfficialRocketLookFramesNightDayAndCapsuleDetail() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let source = try OfficialRocket.source()
        for theme in EntranceTheme.allCases {
            let plan = StoryboardScenario.plan(edge: "right", theme: theme, geometry: source.geometry)
            for detail in [false, true] {
                let scene = try EntranceScene(plan: plan, parts: [.hull, .glass], flat: false, rocket: source, capsuleDetail: detail)
                try await scene.setEnvironment(XCTUnwrap(EntranceLookImages.studio(day: theme == .day)),
                                               intensityExponent: theme == .day ? 0.5 : -0.5)
                if theme == .day { try await scene.setSky(XCTUnwrap(EntranceLookImages.daySkyStrip())) }
                for (shot, t) in StoryboardScenario.stages(plan) where !detail || shot != "shot3start" {
                    let frame = try await scene.render(at: t)
                    let covered = coverage(frame.image)
                    print("OFFICIAL-FRAME \(theme.rawValue) \(shot) detail \(detail) coverage \(String(format: "%.3f", covered))")
                    if theme == .night { XCTAssertGreaterThan(covered, 0.01, "\(theme) \(shot) is empty") }
                    try save(frame.image, "official-right-\(shot)-\(theme.rawValue)\(detail ? "-detail" : "")")
                }
            }
        }
    }
}
#endif
