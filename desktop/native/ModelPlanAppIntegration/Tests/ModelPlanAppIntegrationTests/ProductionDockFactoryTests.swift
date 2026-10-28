// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class ProductionDockFactoryTests: XCTestCase {
    func testProductionAndSelfTestMenusAreExplicitlyDifferentWithoutOpeningWindows() {
        _ = NSApplication.shared
        let production = ProductionDockFactory.community()
        let preview = StaticDockPreviewHost(purpose: .selfTest)
        defer { production.close(); preview.close() }
        XCTAssertEqual(production.purpose, .production)
        XCTAssertEqual(preview.purpose, .selfTest)
        let productionTitles = production.menu().items.map(\.title).joined(separator: " | ")
        XCTAssertTrue(productionTitles.contains("Quit ModelPlan"))
        XCTAssertFalse(productionTitles.contains("preview")); XCTAssertFalse(productionTitles.contains("自测"))
        XCTAssertTrue(preview.menu().items.contains { $0.title.contains("Quit preview") })
        XCTAssertNil(production.nativePanel); XCTAssertNil(preview.nativePanel)
    }
    func testOfficialProductionFactoryRequiresAndUsesTheActualSupplier() async throws {
        XCTAssertThrowsError(try ProductionDockFactory.official(appearance: nil))
        var calls = 0
        let dock = try ProductionDockFactory.official { view, rows, _ in
            calls += 1
            try view.applyCommunity(rows)
            return .init(hoverRects: [view.bounds])
        }
        defer { dock.close() }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("production-dock-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json"))) { dock.apply($0) }
        await app.reload()
        XCTAssertEqual(dock.purpose, .production)
        XCTAssertGreaterThan(calls, 0, "the actual returned Host must use the supplied appearance")
        XCTAssertNil(dock.nativePanel, "construction and a settings transaction must not launch panels")
    }
}
