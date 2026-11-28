// SPDX-License-Identifier: MIT
// Slice 2: renders native frames at the storyboard key-frame stages and compares them structurally with the
// owner-approved storyboard stills (StoryboardKeyframes). Report-only until slice 3 brings the D111 camera;
// then the shot-3 gates become blocking.
#if canImport(RealityKit) && canImport(Metal)
import CoreGraphics
import Foundation
import ModelPlanEntrance

/// The storyboard E-still scenario (1470 x 956, 4 subscriptions) for one dock edge. Cockpit and tail positions
/// are the storyboard's own final-cockpit measurements: 620 pt wide cockpit at x ~807, top ~41.
public enum StoryboardScenario {
    public static let viewport = EntranceSize(width: 1470, height: 956)
    public static let cockpitLeft = 807.0, cockpitTop = 41.0, cockpitWidth = 620.0

    public static func liftOff() -> LiftOffInput {
        // c01 clear aperture: x 17...618.5, y 0...199 in the 636 pt raster (8 pt margin around the 620 pt shell).
        LiftOffInput(viewport: viewport, handoffDiameter: 0.80 * cockpitWidth,
                     tailPoint: .init(cockpitLeft + cockpitWidth / 2, 900),
                     apertureRect: .init(left: cockpitLeft - 8 + 17, top: cockpitTop, width: 601.5, height: 199))
    }

    public static func plan(edge: String) -> EntrancePlan {
        // Roll distances from the storyboard boards: right/bottom clamp to 0.35 s, left 0.673 s.
        let distance = edge == "left" ? 1077.1 : 494.2
        return EntrancePlan(.init(dockIDs: ["claude", "codex", "zcode", "glm"], rollDistance: distance, liftOff: liftOff()))
    }
}

@available(macOS 15.0, *)
public struct StoryboardCaptureResult: @unchecked Sendable {
    public let edge: String
    public let shot: String
    public let image: CGImage
    public let measurement: SilhouetteMeasurement?
    public let comparison: KeyframeComparison?
}

@available(macOS 15.0, *)
@MainActor
public enum StoryboardCapture {
    /// The stages the native 3D scene renders today. Shots 1-2 are 2D overlay work (slice 5) and the final
    /// frame is the web cockpit (slice 6).
    public static let renderedShots = ["shot3start"]

    public static func run(edges: [String] = ["right", "bottom", "left"],
                           keyframes: StoryboardKeyframes = .approved) async throws -> [StoryboardCaptureResult] {
        var results: [StoryboardCaptureResult] = []
        for edge in edges {
            let plan = StoryboardScenario.plan(edge: edge)
            let scene = try EntranceScene(plan: plan, parts: [.hull, .glass], flat: true)
            for shot in renderedShots {
                let t = plan.timeline.liftOffStart
                let frame = try await scene.render(at: t)
                let measured = measure(frame.image, viewport: StoryboardScenario.viewport)
                let comparison = keyframes.frame(edge: edge, shot: shot).flatMap { key in
                    measured.map { KeyframeComparison.compare(native: $0, to: key) }
                }
                results.append(.init(edge: edge, shot: shot, image: frame.image, measurement: measured, comparison: comparison))
            }
        }
        return results
    }

    /// Foreground = pixels that differ from the top-left background pixel; the 26 pt menu bar is ignored,
    /// matching the storyboard measurement.
    public static func measure(_ image: CGImage, viewport: EntranceSize) -> SilhouetteMeasurement? {
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
        var mask = [Bool](repeating: false, count: w * h)
        for i in 0..<(w * h) {
            var differs = false
            for c in 0..<4 where abs(Int(bytes[i * 4 + c]) - Int(bg[c])) > 40 { differs = true }
            mask[i] = differs
        }
        let scale = viewport.width / Double(w)
        return SilhouetteMeasure.measure(mask: mask, width: w, height: h, scale: scale, ignoreTop: Int((26 / scale).rounded(.up)),
                                         viewport: viewport)
    }

    /// JSON report (numbers only).
    public static func report(_ results: [StoryboardCaptureResult]) throws -> Data {
        struct Row: Encodable { let edge: String; let shot: String; let native: SilhouetteMeasurement?; let comparison: KeyframeComparison?; let passed: Bool? }
        let rows = results.map { Row(edge: $0.edge, shot: $0.shot, native: $0.measurement, comparison: $0.comparison, passed: $0.comparison?.passed) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(rows)
    }
}
#endif
