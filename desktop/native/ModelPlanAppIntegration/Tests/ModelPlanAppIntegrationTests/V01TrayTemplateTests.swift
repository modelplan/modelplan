// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

@MainActor final class V01TrayTemplateTests: XCTestCase {
    private func assertReferenceAlpha(_ image: NSImage, slotHeight: CGFloat) throws {
        XCTAssertTrue(image.isTemplate)
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { repo.deleteLastPathComponent() }
        for scale in [1, 2] {
            let size = 16 * scale
            let actual = try XCTUnwrap(image.representations.compactMap { $0 as? NSBitmapImageRep }.first { $0.pixelsWide == size && $0.pixelsHigh == size }, "Missing actual status image representation at scale \(scale)")
            let name = scale == 1 ? "tray-outline.png" : "tray-outline@2x.png"
            let reference = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: repo.appendingPathComponent("desktop/official-visuals/icons/" + name))))
            XCTAssertEqual(reference.pixelsWide, size); XCTAssertEqual(reference.pixelsHigh, size)
            var minY = size, maxY = -1
            for y in 0..<size {
                for x in 0..<size {
                    let expected = try XCTUnwrap(reference.colorAt(x: x, y: y)).alphaComponent
                    let observed = try XCTUnwrap(actual.colorAt(x: x, y: y)).alphaComponent
                    XCTAssertEqual(observed, expected, accuracy: 1.0 / 255.0, "Unexpected orbit or contour at \(x),\(y), scale \(scale)")
                    if observed > 0 { minY = min(minY, y); maxY = max(maxY, y) }
                }
            }
            XCTAssertGreaterThanOrEqual(maxY, minY)
            XCTAssertLessThanOrEqual(CGFloat(maxY - minY + 1) / CGFloat(scale), slotHeight)
        }
    }
    func testV01BundledTemplateMatchesOrbitFreeReferenceAtBothScales() throws {
        let image = try XCTUnwrap(CommunityMenuBarResources.templateImage())
        try assertReferenceAlpha(image, slotHeight: 16)
    }
    func testV01StatusItemUsesOrbitFreeTemplateAtBothScales() throws {
        guard ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true",
              ProcessInfo.processInfo.environment["RUNNER_ENVIRONMENT"] == "github-hosted" else {
            throw XCTSkip("The native status item requires an approved GUI session")
        }
        _ = NSApplication.shared
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        let source = try XCTUnwrap(CommunityMenuBarResources.templateImage())
        EngineDockMenuApplication.configureStatusButton(button, image: source, barThickness: NSStatusBar.system.thickness)
        let image = try XCTUnwrap(button.image)
        XCTAssertEqual(image.size.width, 16, accuracy: 0.001)
        XCTAssertLessThanOrEqual(image.size.height, NSStatusBar.system.thickness)
        try assertReferenceAlpha(image, slotHeight: NSStatusBar.system.thickness)
    }
}
