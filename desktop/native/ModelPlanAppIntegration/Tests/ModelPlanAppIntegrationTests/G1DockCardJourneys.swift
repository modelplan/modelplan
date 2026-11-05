// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

/// This client supplies only the synthetic wire snapshot; the app, host and card
/// are constructed through the same entry and rendering path as the product.
private actor G1CardRowsClient: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    private var refreshCalls = 0
    let context = EngineDeliveryContext(sessionID: "g1-card", floor: .init(storeEpoch: "g1-card", generation: 1), revision: 1)

    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { context.sessionID == "g1-card" && context.revision == 1 }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func supportsCapability(_ capability: String) async -> Bool { capability == "memberRefreshV1" }
    func requestCount() -> Int { refreshCalls }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?, prepared: @escaping @Sendable (WireRequestID) async -> Void) async throws -> EngineRequestCompletion {
        refreshCalls += 1
        let id = WireRequestID.string("g1-refresh-\(refreshCalls)")
        await prepared(id)
        let result = try WireMemberRefreshResult(outcome: .started)
        let envelope = try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: result)
        await store.consume(.response(requestID: id, .memberRefresh(.init(envelope: envelope, delivery: context))))
        return .init(requestID: id)
    }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class G1DockCardJourneys: XCTestCase {
    private let memberID = "aaaaaaaaaaaaaaaa"

    private func snapshot(credits: [String: Any]? = nil, includeScoped: Bool = false, includeResetEvent: Bool = false,
                          includeResetCards: Bool = false, rowState: String = "fresh", refreshFloor: Bool = false, eventStatus: String = "announced",
                          missingPercentage: Bool = false) throws -> WireRowsSnapshot {
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var row = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        var account = try XCTUnwrap((row["accounts"] as? [[String: Any]])?.first)
        let source = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        let now = Date(), format = ISO8601DateFormatter()
        let observed = format.string(from: now.addingTimeInterval(-30))
        let reset = format.string(from: now.addingTimeInterval(2 * 3600 + 13 * 60 + 30))
        let deadline = format.string(from: now.addingTimeInterval(86400))
        func window(_ id: String, role: String, duration: Int, percent: Any) -> [String: Any] {
            var value = source
            value["id"] = id; value["role"] = role; value["durationSeconds"] = duration
            value["label"] = ["en": id, "zh": id]
            value["limitKey"] = "main"; value["poolKey"] = "main"; value.removeValue(forKey: "modelScope")
            value["remainingPercent"] = percent; value["current"] = true
            value["observedAt"] = observed; value["resetsAt"] = reset; value["validUntil"] = reset
            return value
        }
        let percent: Any = missingPercentage ? NSNull() : 41
        var windows = [window("five", role: "session", duration: 18000, percent: percent),
                       window("week", role: "weekly", duration: 604800, percent: missingPercentage ? NSNull() : 70)]
        if includeScoped {
            var extra = window("scoped", role: "weekly", duration: 604800, percent: 1)
            extra["modelScope"] = ["models": ["synthetic-model"]]
            windows.append(extra)
        }
        row["id"] = "codex"; row["name"] = ["en": "Synthetic Tool", "zh": "Synthetic Tool"]
        row["vendorKey"] = "codex"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu"]
        row["state"] = rowState; row["expiresAt"] = deadline; row["stateAfterExpiry"] = NSNull()
        row["reason"] = ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
        account["subscriptionRef"] = memberID; account["valueState"] = "current"
        account["observedAt"] = observed; account["freshUntil"] = deadline
        account["plan"] = ["id": "synthetic-plan", "name": ["en": "Synthetic Plan", "zh": "Synthetic Plan"]]
        account["windows"] = windows
        if let credits { account["credits"] = credits } else { account.removeValue(forKey: "credits") }
        if includeResetCards {
            var cards = try XCTUnwrap(account["resetCards"] as? [String: Any])
            cards["count"] = 2; cards["earliestExpiresAt"] = "2099-01-01T00:00:00Z"
            account["resetCards"] = cards
        } else { account.removeValue(forKey: "resetCards") }
        if refreshFloor { account["refreshNotBefore"] = deadline } else { account.removeValue(forKey: "refreshNotBefore") }
        row["accounts"] = [account]
        projection["rows"] = [row]
        if includeResetEvent {
            var event = try XCTUnwrap((projection["resetEvents"] as? [[String: Any]])?.first)
            event["publishedAt"] = observed; event["expiresAt"] = deadline; event["status"] = eventStatus
            event["schedule"] = ["precision": "window", "from": observed, "through": deadline]
            projection["resetEvents"] = [event]
        } else { projection.removeValue(forKey: "resetEvents") }
        root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }

    private func nodes(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(nodes) }
    private func text(_ root: NSView, _ identifier: String) -> String? {
        nodes(root).compactMap { $0 as? NSTextField }.first { $0.accessibilityIdentifier() == identifier }?.stringValue
    }

    private func withRenderedCard(credits: [String: Any]? = nil, includeScoped: Bool = false, includeResetEvent: Bool = false,
                                  includeResetCards: Bool = false, rowState: String = "fresh", refreshFloor: Bool = false, eventStatus: String = "announced", reduceMotion: Bool = false,
                                  missingPercentage: Bool = false, presentCard: Bool = true,
                                  check: (StaticDockPreviewHost, EngineDockMenuApplication) async throws -> Void) async throws {
        _ = NSApplication.shared
        let rows = try snapshot(credits: credits, includeScoped: includeScoped, includeResetEvent: includeResetEvent, includeResetCards: includeResetCards, rowState: rowState, refreshFloor: refreshFloor, eventStatus: eventStatus, missingPercentage: missingPercentage)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-card-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        try await store.update { $0.language = .english; $0.showDock = true; $0.autoHide = false; if reduceMotion { $0.motion = .on } }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"),
            applicationVersion: "g1-synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: false,
            makeClient: { _, store in G1CardRowsClient(store: store, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let host = app.composition.dock
        do {
            // Exercise the production controller's hover dwell and host callback.
            if presentCard {
                try presentSyntheticHostCard(host, id: memberID)
                XCTAssertFalse(host.card.isHidden, "normal entry must present an actual card for the admitted member")
            }
            try await check(host, app)
            await app.composition.stop(); host.close()
        } catch {
            await app.composition.stop(); host.close()
            throw error
        }
    }

    func testDOCK_3_8_06RenderedFiveHourAndWeeklyRowsHaveBarsAndValues() async throws {
        try await withRenderedCard { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:five.value"), "41%")
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:week.value"), "70%")
            let ids = Set(nodes(host.card).compactMap { $0.accessibilityIdentifier() })
            XCTAssertTrue(ids.contains("dock.card.quota.quota:five"))
            XCTAssertTrue(ids.contains("dock.card.quota.quota:week"))
        }
    }

    func testDOCK_3_8_07RenderedResetUsesRelativeGlossaryCopy() async throws {
        try await withRenderedCard { host, app in
            let detail = try XCTUnwrap(text(host.card, "dock.card.text.row.quota:five.detail"))
            XCTAssertEqual(detail, "Resets in 2h 14m")
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:five.detail"), "2小时14分后重置")
        }
    }

    func testDOCK_3_8_08RenderedReserveUsesReportedCreditsAndUnknownUnit() async throws {
        try await withRenderedCard(credits: ["balance": 19614, "unit": "credits"]) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.credits.value"), "19,614")
        }
        try await withRenderedCard(credits: ["balance": 0.42, "unit": "credits"]) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.credits.value"), "<1")
        }
        try await withRenderedCard(credits: ["balance": 19614, "unit": "synthetic-unknown"]) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.credits.label"), "Reserve")
        }
    }

    func testDOCK_3_8_12ScopedWindowIsCardOnlyAndNotAGeneralRing() async throws {
        try await withRenderedCard(includeScoped: true) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:scoped.value"), "1%")
            let reading = try XCTUnwrap(host.dockView.presentedReadingsForChecks[memberID])
            XCTAssertEqual(reading.outer?.windowID, "five")
            XCTAssertEqual(reading.inner?.windowID, "week")
            XCTAssertNotEqual(reading.remainingPercent, 1)
        }
    }

    func testDOCK_3_8_13MissingFactsAreNotInventedInRenderedCard() async throws {
        try await withRenderedCard(missingPercentage: true) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:five.value"), "--")
            XCTAssertNil(text(host.card, "dock.card.text.row.credits.value"))
        }
    }

    func test_DOCK_3_8_03_hoverDwellAndLeave() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-03 waits for G1RenderedSnapshot")
        try await withRenderedCard(presentCard: false) { _, app in
            let ring = try XCTUnwrap(app.renderedSnapshotForChecks().find("dock.subscription." + memberID))
            app.movePointer(to: CGPoint(x: ring.frame.midX, y: ring.frame.midY))
            app.advanceClock(by: 0.249)
            XCTAssertNil(app.renderedSnapshotForChecks().card)
            app.advanceClock(by: 0.001)
            let card = try XCTUnwrap(app.renderedSnapshotForChecks().card)
            XCTAssertTrue(card.visible)
            let dock = app.renderedSnapshotForChecks().dock.frame
            let gap = max(card.frame.minX - dock.maxX, dock.minX - card.frame.maxX,
                          card.frame.minY - dock.maxY, dock.minY - card.frame.maxY)
            XCTAssertEqual(gap, 12, accuracy: 1)
            app.movePointer(to: CGPoint(x: card.frame.midX, y: card.frame.midY))
            app.advanceClock(by: 0.3)
            XCTAssertTrue(app.renderedSnapshotForChecks().card?.visible == true)
            app.movePointer(to: CGPoint(x: ring.frame.minX - 1000, y: ring.frame.minY - 1000))
            app.advanceClock(by: 0.3)
            XCTAssertFalse(app.renderedSnapshotForChecks().card?.visible == true)
        }
    }

    func test_DOCK_3_8_07_snapshotRelativeCopy() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-07 waits for G1RenderedSnapshot")
        try await withRenderedCard { _, app in
            XCTAssertEqual(app.renderedSnapshotForChecks().find("dock.card.text.row.quota:five.detail")?.text, "Resets in 2h 14m")
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
            XCTAssertEqual(app.renderedSnapshotForChecks().find("dock.card.text.row.quota:five.detail")?.text, "2小时14分后重置")
        }
    }

    func test_DOCK_3_8_08_snapshotReportedCredits() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-08 waits for G1RenderedSnapshot")
        try await withRenderedCard(credits: ["balance": 19614, "unit": "credits"]) { _, app in
            XCTAssertEqual(app.renderedSnapshotForChecks().find("dock.card.text.row.credits.value")?.text, "19,614")
        }
        try await withRenderedCard(credits: ["balance": 0.42, "unit": "credits"]) { _, app in
            XCTAssertEqual(app.renderedSnapshotForChecks().find("dock.card.text.row.credits.value")?.text, "<1")
        }
        try await withRenderedCard(credits: ["balance": 0, "unit": "credits"]) { _, app in
            XCTAssertEqual(app.renderedSnapshotForChecks().find("dock.card.text.row.credits.value")?.text, "0")
        }
        try await withRenderedCard(credits: ["balance": 19614, "unit": "synthetic-unknown"]) { _, app in
            XCTAssertEqual(app.renderedSnapshotForChecks().find("dock.card.text.row.credits.label")?.text, "Reserve")
        }
        try await withRenderedCard(includeResetCards: true) { _, app in
            let rendered = app.renderedSnapshotForChecks()
            let options = XCTExpectedFailure.Options(); options.isStrict = true
            XCTExpectFailure("DOCK-3.8-08 product-missing: reset card facts, M2 follow-up 0fb3e12d", options: options) {
                XCTAssertEqual(rendered.find("dock.card.text.row.reset-cards.value")?.text, "2")
                XCTAssertEqual(rendered.find("dock.card.text.row.reset-cards.detail")?.text, "Earliest expiry: 2099-01-01T00:00:00Z")
            }
        }
    }

    func test_DOCK_3_8_12_snapshotScopedWindow() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-12 waits for G1RenderedSnapshot")
        try await withRenderedCard(includeScoped: true) { host, app in
            XCTAssertEqual(app.renderedSnapshotForChecks().find("dock.card.text.row.quota:scoped.value")?.text, "1%")
            let reading = try XCTUnwrap(host.dockView.presentedReadingsForChecks[memberID])
            XCTAssertEqual(reading.outer?.windowID, "five")
            XCTAssertEqual(reading.inner?.windowID, "week")
        }
    }

    func test_DOCK_3_8_10_ringRefreshDoesNotPin() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-10 waits for G1RenderedSnapshot")
        try await withRenderedCard(presentCard: false) { host, app in
            let client = try XCTUnwrap(app.composition.client as? G1CardRowsClient)
            for _ in 0..<100 where app.memberRefreshAdapter == nil { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertNotNil(app.memberRefreshAdapter)
            host.dockView.onAction?(.subscription(memberID))
            for _ in 0..<100 {
                if await client.requestCount() > 0 { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            let calls = await client.requestCount()
            XCTAssertEqual(calls, 1)
            XCTAssertFalse(app.renderedSnapshotForChecks().card?.visible == true)
            XCTAssertEqual(host.dockView.refreshSweepCountForChecks, 1)
        }
        try await withRenderedCard(refreshFloor: true, reduceMotion: true, presentCard: false) { host, app in
            let client = try XCTUnwrap(app.composition.client as? G1CardRowsClient)
            for _ in 0..<100 where app.memberRefreshAdapter == nil { try await Task.sleep(for: .milliseconds(10)) }
            host.dockView.onAction?(.subscription(memberID))
            try await Task.sleep(for: .milliseconds(50))
            let calls = await client.requestCount()
            XCTAssertEqual(calls, 0, "Refresh floor must suppress requests")
            XCTAssertFalse(host.dockView.refreshSweepAnimatingForChecks, "Reduce Motion must use a static indication")
            XCTAssertFalse(app.renderedSnapshotForChecks().card?.visible == true)
        }
    }

    func test_DOCK_3_8_11_announcedResetDetails() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-11 waits for G1RenderedSnapshot")
        try await withRenderedCard(includeResetEvent: true) { _, app in
            let rendered = app.renderedSnapshotForChecks()
            let prefix = "dock.card.text.row.reset-event:synthetic-reset:announced"
            XCTAssertNotNil(rendered.find(prefix + ".label"))
            XCTAssertEqual(rendered.find(prefix + ".detail")?.text, "Public status does not confirm a personal quota reset")
            let options = XCTExpectedFailure.Options(); options.isStrict = true
            XCTExpectFailure("DOCK-3.8-11 product-missing: reset timing and source link", options: options) {
                XCTAssertTrue(rendered.all(role: .control).contains { $0.text == "Source · Original" })
                let detail = rendered.find(prefix + ".detail")?.text ?? ""
                XCTAssertTrue(detail.contains(String(Calendar.current.component(.year, from: Date()))), "The announced reset must show reported timing")
            }
        }
        try await withRenderedCard(includeResetEvent: true, eventStatus: "confirmed") { _, app in
            let rendered = app.renderedSnapshotForChecks()
            let prefix = "dock.card.text.row.reset-event:synthetic-reset:confirmed"
            XCTAssertEqual(rendered.find(prefix + ".label")?.text, "Public reset confirmed")
            XCTAssertEqual(rendered.find(prefix + ".detail")?.text, "Public status does not confirm a personal quota reset")
        }
    }

    func test_DOCK_3_8_05_snapshotHeader() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-05 waits for G1RenderedSnapshot")
        try await withRenderedCard { _, app in
            let rendered = app.renderedSnapshotForChecks()
            let heading = try XCTUnwrap(rendered.find("dock.card.text.name")?.text)
            XCTAssertTrue(heading.contains("Synthetic Tool"))
            XCTAssertTrue(heading.contains("Synthetic Plan"))
            let source = try XCTUnwrap(rendered.find("dock.card.text.source")?.text)
            XCTAssertTrue(source.contains("Saved sign-in"))
            XCTAssertTrue(source.contains("ago") || source.contains("just now"))
            XCTAssertNil(rendered.find("dock.card.text.state"))
            func hasImage(_ element: G1Element) -> Bool {
                element.imageSource != nil || element.children.contains(where: hasImage)
            }
            let card = try XCTUnwrap(rendered.card)
            let options = XCTExpectedFailure.Options()
            options.isStrict = true
            XCTExpectFailure("DOCK-3.8-05 product-missing: card glyph", options: options) {
                XCTAssertTrue(hasImage(card), "The rendered card header must have a glyph")
            }
        }
        try await withRenderedCard(rowState: "stale") { _, app in
            let rendered = app.renderedSnapshotForChecks()
            XCTAssertFalse(try XCTUnwrap(rendered.find("dock.card.text.state")?.text).isEmpty,
                           "A nonhealthy reading needs its own visible status")
        }
    }

    func test_DOCK_3_8_06_snapshotSegments() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-06 waits for G1RenderedSnapshot")
        try await withRenderedCard { _, app in
            let rendered = app.renderedSnapshotForChecks()
            func segments(_ element: G1Element) -> Int {
                (element.role == .segment ? 1 : 0) + element.children.reduce(0) { $0 + segments($1) }
            }
            for id in ["dock.card.quota.quota:five", "dock.card.quota.quota:week"] {
                let bar = try XCTUnwrap(rendered.find(id))
                XCTAssertEqual(segments(bar), 10, "Each actual quota bar must render ten segments")
            }
        }
    }

    func test_DOCK_3_8_13_snapshotHealthyFacts() async throws {
        try XCTSkipUnless(G1Seams.snapshotAvailable, "DOCK-3.8-13 waits for G1RenderedSnapshot")
        try await withRenderedCard(missingPercentage: true) { _, app in
            let rendered = app.renderedSnapshotForChecks()
            XCTAssertEqual(rendered.find("dock.card.text.row.quota:five.value")?.text, "--")
            XCTAssertNil(rendered.find("dock.card.text.row.credits.value"))
            XCTAssertNil(rendered.find("dock.card.text.state"))
            let source = try XCTUnwrap(rendered.find("dock.card.text.source")?.text)
            XCTAssertTrue(source.contains("Saved sign-in"))
            XCTAssertTrue(source.contains("ago") || source.contains("just now"))
        }
    }
}
