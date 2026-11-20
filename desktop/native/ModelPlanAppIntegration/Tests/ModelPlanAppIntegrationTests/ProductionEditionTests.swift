// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

/// D57/D321: a neutral package (built from source) renders no reserved Dock or menu-bar artwork.
@MainActor final class ProductionEditionTests: XCTestCase {
    func testOnlyAnExplicitNeutralKeySelectsTheNeutralEdition() {
        XCTAssertEqual(ProductionEdition.from(info: ["ModelPlanEdition": "neutral"]), .neutral)
        XCTAssertEqual(ProductionEdition.from(info: ["ModelPlanEdition": "official"]), .official)
        // Outside a package (tests, swift run) there is no key: the official appearance stays the default.
        XCTAssertEqual(ProductionEdition.from(info: [:]), .official)
        XCTAssertEqual(ProductionEdition.from(info: nil), .official)
    }
    func testNeutralEditionUsesTheCommunityRenderingNotTheT2Skin() {
        XCTAssertNil(ProductionDockFactory.appearance(for: .neutral))
        XCTAssertNotNil(ProductionDockFactory.appearance(for: .official))
    }
    func testAPackageWithoutTheReservedTrayStillGetsATemplateStatusImage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("edition-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("ModelPlan.app")
        let bundle = app.appendingPathComponent("Contents/Resources/" + CommunityMenuBarResources.bundleName)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        XCTAssertNil(CommunityMenuBarResources.templateImage(appURL: app))
        let image = try XCTUnwrap(CommunityMenuBarResources.statusImage(appURL: app))
        XCTAssertTrue(image.isTemplate)
    }
}
