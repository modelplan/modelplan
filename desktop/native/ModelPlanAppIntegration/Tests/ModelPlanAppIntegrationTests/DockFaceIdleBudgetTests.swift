// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class DockFaceIdleBudgetTests: XCTestCase {
    func testIdleProductionFaceDrawsOnceAndReadingChangesReuseItsMaterial() throws {
        let face = T2ProductionAppearance()
        let view = DockInstrumentView(frame: .zero)
        defer { view.dispose() }
        view.appearanceDisplaySize = CGSize(width: 1440, height: 2560)
        view.presentationBackingScale = 1
        var prefs = SettingsPreferences()
        prefs.dockEdge = .right
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func render(_ percent: Double) throws {
            let window = DockQuotaWindowInput(id: "week", period: .week, label: "Week", remainingPercent: percent,
                                              resetsAt: nil, durationSeconds: nil)
            var input = DockInstrumentInput(id: "codex", name: "Codex", windows: [window])
            input.dataState = .fresh
            let row = try DockInstrumentProjection.evaluate(input, now: now)
            _ = try face.apply(view, [row], prefs)
        }
        try render(65)
        for _ in 0..<20 { try render(65) }
        XCTAssertEqual(face.preparationsForChecks, 1, "idle ticks must not rebuild the geometry")
        XCTAssertEqual(face.materialRendersForChecks, 1, "idle ticks must not rasterize the face")
        XCTAssertEqual(view.officialPaintsForChecks, 1, "an identical projection needs no new pixels")

        try render(40)
        XCTAssertEqual(view.officialPaintsForChecks, 2, "a different reading must repaint")
        XCTAssertEqual(face.materialRendersForChecks, 1, "a different reading reuses the static face")
        view.retireOfficialPresentation(keepingRefreshHolds: true)
        try render(40)
        XCTAssertEqual(view.officialPaintsForChecks, 3, "a retired projection needs to be admitted before repaint")
        XCTAssertEqual(face.materialRendersForChecks, 1, "normal replacement reuses the prepared material")

        prefs.dockEdge = .left
        try render(40)
        XCTAssertEqual(face.preparationsForChecks, 2, "a new edge must be laid out")
        XCTAssertEqual(face.materialRendersForChecks, 2)
        view.presentationBackingScale = 2
        try render(40)
        XCTAssertEqual(face.preparationsForChecks, 2, "a scale change reuses point geometry")
        XCTAssertEqual(face.materialRendersForChecks, 3, "a scale change needs a new bitmap")
    }
}
