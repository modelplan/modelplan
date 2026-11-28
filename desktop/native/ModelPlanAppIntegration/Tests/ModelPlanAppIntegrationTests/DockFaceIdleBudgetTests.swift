// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
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

    /// macrev2-1201-1 (G3-161): through the official normal entry, a newer rows delivery replaces the admitted content
    /// by clearing and reinstalling it in one driver step. The clear used to retire the face and redraw an empty Dock
    /// first, so even an unchanged delivery painted twice and re-laid the geometry. Invariant: identical displayed
    /// readings paint nothing; a quota change repaints without new geometry or material; privacy still clears all.
    func testNormalEntryReplacementPaintsOnlyChangedReadings() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-face-idle-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let rows = try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 12)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, edition: .official, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation()
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.composition.start()
        let composition = app.composition, dock = composition.dock
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        func deliver(_ next: WireRowsSnapshot) async throws {
            await composition.store.consume(.rowsChanged(try EngineReply(envelope: .init(sessionId: context.sessionID,
                storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: next), delivery: context), invalidRowCount: 0))
        }
        XCTAssertFalse(composition.presentedContent.snapshot.inputs.isEmpty, "the admitted rows are on the widget")
        XCTAssertGreaterThan(dock.officialFacePaintsForChecks, 0, "the official face is drawn")
        let paints = dock.officialFacePaintsForChecks, catalogue = dock.catalogueReportsForChecks
        let preparations = T2ProductionAppearance.preparationsTotalForChecks
        let materials = T2ProductionAppearance.materialRendersTotalForChecks

        try await deliver(try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 12, sequence: 8))
        XCTAssertEqual(dock.officialFacePaintsForChecks, paints, "a newer sequence with the same readings paints nothing")
        XCTAssertEqual(T2ProductionAppearance.preparationsTotalForChecks, preparations, "and builds no geometry")
        XCTAssertEqual(T2ProductionAppearance.materialRendersTotalForChecks, materials, "and renders no material")
        XCTAssertEqual(dock.catalogueReportsForChecks, catalogue, "and reports no catalogue change")
        XCTAssertFalse(composition.presentedContent.snapshot.inputs.isEmpty)

        let shown = dock.dockView.presentedReadingsForChecks
        XCTAssertFalse(shown.isEmpty, "the unchanged readings are still presented")
        try await deliver(try HostPairedProjectionTests.rows(weekly: 40, secondWeekly: 12, sequence: 9))
        XCTAssertGreaterThan(dock.officialFacePaintsForChecks, paints, "a quota change repaints")
        XCTAssertEqual(T2ProductionAppearance.preparationsTotalForChecks, preparations, "with the same layout")
        XCTAssertEqual(T2ProductionAppearance.materialRendersTotalForChecks, materials, "and the same static material")
        XCTAssertNotEqual(dock.dockView.presentedReadingsForChecks, shown, "the new reading is presented")

        // Control: a privacy withdrawal still clears every value and evicts the prepared layout.
        let evictions = T2ProductionAppearance.preparedEvictionsTotalForChecks
        await composition.store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertTrue(composition.presentedContent.snapshot.inputs.isEmpty, "nothing private stays after a clear")
        XCTAssertTrue(dock.dockView.presentedReadingsForChecks.isEmpty, "the face no longer shows the old values")
        XCTAssertGreaterThan(T2ProductionAppearance.preparedEvictionsTotalForChecks, evictions, "the prepared layout is evicted")
    }
}
