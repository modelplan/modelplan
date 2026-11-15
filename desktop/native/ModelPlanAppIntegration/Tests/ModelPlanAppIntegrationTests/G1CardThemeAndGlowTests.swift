// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanOfficialDock
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor B2Client: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g1-b2", floor: .init(storeEpoch: "g1-b2", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("b2-rows")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class B2Timer: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

/// v1 gate G1, batch 2 (test-only): the open-card ring glow (PROTO-HOT-GLOW) and the card's dark plate and LCD
/// under both themes (THM-2.4-07). The Settings window leg of THM-2.4-07 is in NativeSettingsWindowTests.
@MainActor final class G1CardThemeAndGlowTests: XCTestCase {
    private func openCard(theme: SettingsTheme) async throws -> (app: EngineDockMenuApplication, dock: StaticDockPreviewHost, id: String) {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-b2-card-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
        row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["expiresAt"] = "2028-12-01T00:00:00Z"
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = "2028-12-01T00:00:00Z"
        account["lastFailure"] = NSNull()
        windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
        windows[0]["observedAt"] = "2026-12-01T00:00:00Z"; windows[0]["validUntil"] = "2028-12-01T00:00:00Z"
        windows[0]["resetsAt"] = "2028-12-01T00:00:00Z"; windows[0]["remainingPercent"] = 42.0
        account["windows"] = [windows[0]]; row["accounts"] = [account]; rows[0] = row
        projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let snapshot = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let settings = try await expandedWidgetSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await settings.update { $0.theme = theme }
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z"))
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: pointer) },
            deadlineNow: { now }, deadlineElapsed: { elapsed }, deadlineScheduling: B2Timer(),
            makeClient: { _, store in B2Client(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in app.composition.dock.close() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let dock = app.composition.dock, id = "aaaaaaaaaaaaaaaa"
        let placement = try XCTUnwrap(dock.edgePresentation?.placement), anchor = try XCTUnwrap(dock.dockView.interactionAnchor(id))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - dock.dockView.bounds.minX, y: placement.frame.maxY - anchor.midY + dock.dockView.bounds.minY)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(dock.card.isHidden)
        return (app, dock, id)
    }

    /// PROTO-HOT-GLOW: dock.css:68, drop-shadow 0 0 7px #ffffff2e outside the rim of the ring whose card is open.
    func testHotNozzleGlowIsSevenPointWhiteAtTwoE() async throws {
        let material = QuotaWidgetCardMaterial.hotGlow
        XCTAssertEqual([material.red, material.green, material.blue], [1, 1, 1])
        XCTAssertEqual(Double(material.alpha), Double(0x2e) / 255, accuracy: 0.0001)
        XCTAssertEqual(QuotaWidgetCardMaterial.hotGlowBlur, 7)
        let (_, dock, id) = try await openCard(theme: .night)
        XCTAssertEqual(dock.dockView.hotNozzleForChecks, id)
        let glow = try XCTUnwrap(dock.dockView.hotGlowForChecks, "the open card's ring carries a glow layer")
        let colour = try XCTUnwrap(glow.shadowColor?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components)
        XCTAssertEqual(Array(colour.prefix(3)), [1, 1, 1], "white")
        XCTAssertEqual(Double(glow.shadowOpacity), Double(0x2e) / 255, accuracy: 0.005, "alpha 0x2e")
        XCTAssertEqual(glow.shadowRadius, 3.5, accuracy: 0.01, "CSS blur 7 px is a 3.5 pt Gaussian radius")
        XCTAssertEqual(glow.shadowOffset, .zero)
        XCTAssertNotNil(glow.shadowPath, "the halo follows the ring disc")
        XCTAssertNotNil(glow.mask, "only the halo outside the rim; the ring art is not washed")
        // Leaving the ring clears it again.
        dock.dockView.setHotNozzle(nil)
        XCTAssertNil(dock.dockView.hotGlowForChecks); XCTAssertNil(dock.dockView.hotNozzleForChecks)
    }

    /// THM-2.4-07: the hover card keeps its dark plate and dark LCD window in the day and the night theme.
    func testCardLcdStaysDarkInDayAndNightThemes() async throws {
        for theme in [SettingsTheme.day, .night] {
            let (_, dock, _) = try await openCard(theme: theme)
            let lcd = try XCTUnwrap(dock.card.readoutWindowForChecks, "\(theme)")
            let rep = try XCTUnwrap(dock.card.bitmapImageRepForCachingDisplay(in: dock.card.bounds))
            dock.card.cacheDisplay(in: dock.card.bounds, to: rep)
            func colour(_ point: CGPoint) throws -> [Double] {
                let c = try XCTUnwrap(rep.colorAt(x: Int(point.x * CGFloat(rep.pixelsWide) / dock.card.bounds.width), y: Int(point.y * CGFloat(rep.pixelsHigh) / dock.card.bounds.height))?.usingColorSpace(.sRGB))
                return [c.redComponent, c.greenComponent, c.blueComponent].map { Double($0) * 255 }
            }
            let plate = try colour(CGPoint(x: 5, y: lcd.midY)), window = try colour(CGPoint(x: lcd.minX + 3, y: lcd.midY))
            for (got, want) in zip(plate, [0x10, 0x1b, 0x24]) { XCTAssertEqual(got, Double(want), accuracy: 3, "plate \(theme)") }
            for (got, want) in zip(window, [0x03, 0x06, 0x0a]) { XCTAssertEqual(got, Double(want), accuracy: 3, "LCD \(theme)") }
        }
    }
}
