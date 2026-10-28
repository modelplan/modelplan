// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
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
    func testFreshCommunityProductionFactoryRegistersItsActualPaintedBodyWithoutAnOfficialSkin() async throws {
        let host = ProductionDockFactory.community()
        defer { host.close() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("community-drag-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { host.apply($0) }
        await app.reload()
        XCTAssertEqual(host.purpose, .production)
        XCTAssertNotNil(host.dockView.registeredHullPath, "The real neutral rectangle must supply its own move outline")
        let regions = try XCTUnwrap(host.dockView.registeredDragRegions(excluding: []),
            "Normal Community construction must offer a painted drag area without any injected official skin")
        XCTAssertTrue(regions.contains(CGPoint(x: 2, y: 2)))
        XCTAssertFalse(regions.contains(CGPoint(x: -1, y: 2)))
        XCTAssertNil(host.nativePanel)
    }

    func testNeutralGrabMarginKeepsRowControlsAndRetiresWithTheView() throws {
        let view = DockInstrumentView(frame: .zero)
        let row = try DockInstrumentProjection.evaluate(.init(id: "synthetic", name: "Synthetic", windows: []), now: Date(timeIntervalSince1970: 1_800_000_000))
        try view.applyCommunity([row])
        let regions = try XCTUnwrap(view.registeredDragRegions(excluding: [CGRect(x: 0, y: 0, width: 4, height: 4)]))
        XCTAssertTrue(regions.contains(CGPoint(x: view.bounds.maxX - 2, y: view.bounds.midY)))
        XCTAssertFalse(regions.contains(CGPoint(x: view.bounds.midX, y: view.bounds.midY)))
        XCTAssertFalse(regions.contains(CGPoint(x: 2, y: 2)), "Caller-owned controls remain excluded")
        var pressed = false; view.onAction = { _ in pressed = true }
        XCTAssertTrue(view.performPointerPress(atLocal: CGPoint(x: view.bounds.midX, y: view.bounds.midY)))
        XCTAssertTrue(pressed, "Adding a background margin must keep the existing row action")
        pressed = false
        XCTAssertFalse(view.performPointerPress(atLocal: CGPoint(x: view.bounds.maxX - 2, y: view.bounds.midY)))
        XCTAssertFalse(pressed, "The grab margin cannot also be a row control")
        view.isHidden = true
        XCTAssertFalse(regions.contains(CGPoint(x: view.bounds.maxX - 2, y: view.bounds.midY)))
        view.isHidden = false; view.dispose()
        XCTAssertFalse(regions.contains(CGPoint(x: view.bounds.maxX - 2, y: view.bounds.midY)))
        XCTAssertNil(view.registeredHullPath)
    }

}
