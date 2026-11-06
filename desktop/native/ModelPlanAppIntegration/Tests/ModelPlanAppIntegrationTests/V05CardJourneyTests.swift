// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor V05SyntheticClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "reserve-synthetic", floor: .init(storeEpoch: "reserve-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class V05Timer: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class V05CardJourneyTests: XCTestCase {
    func testV05NormalEntryRendersReserveWithoutDiagnosticLinesInBothLanguages() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("v05-card-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
        row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["expiresAt"] = "2028-12-01T00:00:00Z"
        row["reason"] = ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
        row["nextStep"] = ["action": "open_settings_consent", "text": ["en": "Check read access in Settings", "zh": "在设置检查读取权限"], "availableAt": NSNull(), "disabledReason": NSNull()]
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = "2028-12-01T00:00:00Z"
        account["lastFailure"] = NSNull(); account["credits"] = ["balance": 123.45, "unit": "unknown"]
        windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
        windows[0]["observedAt"] = "2026-12-01T00:00:00Z"; windows[0]["validUntil"] = "2028-12-01T00:00:00Z"
        windows[0]["resetsAt"] = "2028-12-01T00:00:00Z"; windows[0]["remainingPercent"] = 42.0
        account["windows"] = [windows[0]]; row["accounts"] = [account]; rows[0] = row
        projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let snapshot = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        XCTAssertEqual(snapshot.projection.invalidRowCount, 0)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z"))
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let timer = V05Timer()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: pointer) },
            deadlineNow: { now }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
            makeClient: { _, store in V05SyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let dock = app.composition.dock, id = "aaaaaaaaaaaaaaaa"
        let placement = try XCTUnwrap(dock.edgePresentation?.placement), anchor = try XCTUnwrap(dock.dockView.interactionAnchor(id))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - dock.dockView.bounds.minX, y: placement.frame.maxY - anchor.midY + dock.dockView.bounds.minY)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(dock.card.isHidden)
        // G3-31: the card uses the accepted r7 plate width and ten-segment bar measurements.
        XCTAssertEqual(dock.card.frame.width, 304, accuracy: 0.5)
        func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
        let bar = try XCTUnwrap(views(dock.card).first { $0.accessibilityIdentifier().hasPrefix("dock.card.quota.") })
        XCTAssertEqual(bar.intrinsicContentSize, NSSize(width: 78, height: 7))
        // G3-05 / G3-31 (R64 D-3, D-4): the prototype card look on the real card.
        // Plate 304 with 10/11 padding, a dark readout window inset 11 pt, fixed 56/78/34 grid, header name 13 semibold.
        let lcd = try XCTUnwrap(dock.card.readoutWindowForChecks, "the card has a readout window")
        XCTAssertEqual(lcd.minX, 11, accuracy: 0.5); XCTAssertEqual(lcd.width, 304 - 22, accuracy: 0.5)
        let quotaRow = try XCTUnwrap(dock.cardContent(for: id)?.rows.first { $0.kind == .quota || $0.kind == .extraQuota })
        // The grid line itself (a time that does not fit the column wraps onto the next line).
        let rowFrame = try XCTUnwrap(dock.card.rowFrameForChecks(quotaRow.id))
        let cells = dock.card.rowCellsForChecks(quotaRow.id).filter { $0.minY < rowFrame.minY + 18 }
        XCTAssertGreaterThanOrEqual(cells.count, 3)
        XCTAssertEqual(cells.prefix(3).map { $0.width.rounded() }, [56, 78, 34], "label / bar / percent columns")
        XCTAssertEqual(cells[1].minX - cells[0].maxX, 5, accuracy: 0.5); XCTAssertEqual(cells[2].minX - cells[1].maxX, 5, accuracy: 0.5)
        XCTAssertEqual(cells[0].minX, lcd.minX + 7, accuracy: 0.5, "rows start inside the window's 7 pt padding")
        XCTAssertGreaterThanOrEqual(rowFrame.height, 18)
        let nameField = try XCTUnwrap(views(dock.card).compactMap { $0 as? NSTextField }.first { $0.accessibilityIdentifier() == "dock.card.text.name" })
        XCTAssertEqual(nameField.font?.pointSize, 13)
        XCTAssertTrue(views(dock.card).compactMap { $0 as? NSButton }.filter { ["dock.card.enter", "dock.card.close"].contains($0.accessibilityIdentifier()) }.isEmpty, "D37: no card buttons")
        // Material: flat plate #101b24 and window #03060a (face.css #card.c7), read back from the drawn card.
        let rep = try XCTUnwrap(dock.card.bitmapImageRepForCachingDisplay(in: dock.card.bounds))
        dock.card.cacheDisplay(in: dock.card.bounds, to: rep)
        func colour(_ point: CGPoint) throws -> NSColor { try XCTUnwrap(rep.colorAt(x: Int(point.x * CGFloat(rep.pixelsWide) / dock.card.bounds.width), y: Int(point.y * CGFloat(rep.pixelsHigh) / dock.card.bounds.height))?.usingColorSpace(.sRGB)) }
        let plate = try colour(CGPoint(x: 5, y: lcd.midY)), window = try colour(CGPoint(x: lcd.minX + 3, y: lcd.midY))
        XCTAssertEqual(plate.redComponent * 255, 0x10, accuracy: 3); XCTAssertEqual(plate.greenComponent * 255, 0x1b, accuracy: 3); XCTAssertEqual(plate.blueComponent * 255, 0x24, accuracy: 3)
        XCTAssertEqual(window.redComponent * 255, 0x03, accuracy: 3); XCTAssertEqual(window.greenComponent * 255, 0x06, accuracy: 3); XCTAssertEqual(window.blueComponent * 255, 0x0a, accuracy: 3)
        // M-1: the ring whose card is open glows; closing the card clears it.
        XCTAssertEqual(dock.dockView.hotNozzleForChecks, id)
        func textFields(_ view: NSView) -> [NSTextField] { ((view as? NSTextField).map { [$0] } ?? []) + view.subviews.flatMap(textFields) }
        for (language, label, forbidden) in [(SettingsLanguage.english, "Reserve", ["unit not reported", "reading available", "check read access in settings"]), (.chinese, "储备", ["未报告单位", "读数可用", "在设置检查读取权限"])] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(language))
            let texts = textFields(dock.card).filter { !$0.isHiddenOrHasHiddenAncestor }.map(\.stringValue)
            XCTAssertTrue(texts.contains(label), "The real card must retain the reserve row")
            for phrase in forbidden { XCTAssertFalse(texts.contains { $0.localizedCaseInsensitiveContains(phrase) }, "Diagnostic copy must not appear on the card") }
        }
        await app.composition.stop()
    }
}
