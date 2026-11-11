// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanAppIntegration

/// G3-67: an owner test build shows its CLI version and readiness in About, as the engine entry builds it; a bundle
/// without the owner-test marker and without the release pins still shows neither.
extension CommunityCockpitEntryTests {
    @MainActor func testOwnerTestBuildShowsItsCliVersionInAbout() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-67-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let helper = root.appendingPathComponent("helper"), page = root.appendingPathComponent("page")
        try FileManager.default.createDirectory(at: page, withIntermediateDirectories: true)
        try Data("synthetic helper".utf8).write(to: helper)
        try Data("synthetic page".utf8).write(to: page.appendingPathComponent("index.html"))
        for ownerTest in [true, false] {
            let app = try Self.ownerTestShapedApp(at: root.appendingPathComponent("a" + String(ownerTest)), helper: helper, ownerTest: ownerTest, official: page)
            let source = EngineSettingsContext(bundle: app, executable: app.appendingPathComponent("Contents/Helpers/modelplan"))
            let about = source.make(engineReady: true).about
            XCTAssertEqual(about.cliVersion, ownerTest ? CommunityConsentBundleIdentity.version : "unknown")
            XCTAssertEqual(about.cliState, ownerTest ? .ready : .unavailable)
        }
    }
}
