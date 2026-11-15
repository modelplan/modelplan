// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import XCTest

/// MOT-2.3-13, Dock leg: the collapsed strip stays dock-length (its exact length is pinned by
/// StaticDockPresentationTests), and no native surface uses Pulse's spring motion.
final class DockMotionPolicyTests: XCTestCase {
    func testCollapsedStripIsDockLengthNotAShortHandle() {
        XCTAssertEqual(DockSliverParameters.current.visibleLength, .fullSpan)
    }

    func testNativeProductSourcesHaveNoSpringMotion() throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent() // ModelPlanAppIntegrationTests
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var scanned = 0
        for folder in ["ModelPlanDock/Native", "ModelPlanAppIntegration/Sources", "ModelPlanCockpitShell/Sources", "ModelPlanSettings/Sources"] {
            let root = native.appendingPathComponent(folder)
            let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            for case let file as URL in files where file.pathExtension == "swift" {
                let text = try String(contentsOf: file, encoding: .utf8)
                scanned += 1
                for banned in ["CASpringAnimation", "interpolatingSpring", ".spring("] {
                    XCTAssertFalse(text.contains(banned), "\(file.lastPathComponent) uses \(banned)")
                }
            }
        }
        XCTAssertGreaterThan(scanned, 20)
    }
}
