// SPDX-License-Identifier: MIT
// `swift run ModelPlanEntranceCapture <out-dir>`: renders the native stand-in at the storyboard key-frame stages,
// writes PNGs and storyboard-comparison.json (structural numbers) to <out-dir>. macOS 15+ only.
import Foundation
#if canImport(RealityKit) && canImport(Metal)
import ImageIO
import ModelPlanEntranceScene
import UniformTypeIdentifiers

@MainActor
func capture(to out: URL) async throws -> Bool {
    guard #available(macOS 15.0, *) else { print("the native entrance needs macOS 15"); return false }
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let results = try await StoryboardCapture.run()
    for r in results {
        let url = out.appendingPathComponent("native-\(r.edge)-\(r.shot).png")
        if let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(d, r.image, nil); _ = CGImageDestinationFinalize(d)
        }
        let verdict = r.comparison.map { $0.passed ? "PASS" : "DIFF" } ?? "NO-KEYFRAME"
        print("\(verdict) \(r.edge) \(r.shot)")
        for check in r.comparison?.checks ?? [] where !check.passed {
            print("  \(check.name): storyboard \(check.storyboard), native \(check.native), tolerance \(check.tolerance)")
        }
    }
    try StoryboardCapture.report(results).write(to: out.appendingPathComponent("storyboard-comparison.json"))
    return true
}

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "entrance-capture")
let ok = try await capture(to: out)
exit(ok ? 0 : 1)
#else
print("ModelPlanEntranceCapture needs RealityKit (macOS 15+)")
exit(1)
#endif
