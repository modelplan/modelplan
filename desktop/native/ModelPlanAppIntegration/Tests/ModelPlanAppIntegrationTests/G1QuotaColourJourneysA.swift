// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor private final class G1AClock {
    var wall = Date(timeIntervalSince1970: 1_800_000_000)
    var elapsed = 10.0
}
@MainActor private final class G1ATimer: DockEdgeScheduling {
    var deadline: Double?, action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline; self.action = action }
    func cancel() { deadline = nil; action = nil }
    func fireIfDue(_ now: Double) { if let deadline, now >= deadline { let saved = action; cancel(); saved?() } }
}
private actor G1AEngine: EngineClient {
    let store: EngineStore
    let context = EngineDeliveryContext(sessionID: "g1-d", floor: .init(storeEpoch: "g1-d", generation: 1), revision: 1)
    var rows: WireRowsSnapshot
    var requests: [String] = []
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool { value.sessionID == "g1-d" && value.revision == 1 }
    func supportsCapability(_ value: String) async -> Bool { value == "memberRefreshV1" }
    func start() async throws -> EngineDeliveryContext { requests.append("start"); await store.consume(.connection(.ready(context))); await store.consume(.context(context)); return context }
    func stop() async { requests.append("stop") }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func deliver(_ value: WireRowsSnapshot) async throws { rows = value; await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: value), delivery: context), invalidRowCount: 0)) }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { requests.append("rows"); try await deliver(rows); return .init(requestID: .string("rows")) }
    func consent(timeout: Duration?) throws -> EngineRequestCompletion { requests.append("consent"); throw EngineClientError.unsupportedCapability }
    func grant(_ value: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ value: WireRefreshRequestParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ value: WireRefreshRequestParams, timeout: Duration?, prepared: @escaping @Sendable (WireRequestID) async -> Void) async throws -> EngineRequestCompletion {
        guard value.member != nil else { throw EngineClientError.unsupportedCapability }
        requests.append("member-refresh"); let id = WireRequestID.string("refresh-\(requests.count)")
        await prepared(id)
        await store.consume(.response(requestID: id, .memberRefresh(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: WireMemberRefreshResult(outcome: .started)), delivery: context))))
        return .init(requestID: id)
    }
    func trace() -> [String] { requests }
    func history(_ value: WireHistoryQueryParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ value: WirePluginInstallParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class G1AFixture {
    static let ids = ["aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb", "cccccccccccccccc"]
    let clock = G1AClock(), timer = G1ATimer()
    let root: URL, store: SettingsStore
    var app: EngineDockMenuApplication!
    var engine: G1AEngine!
    var raw: [String: Any]
    var pointer = CGPoint(x: 700, y: 400), cardFrame: CGRect?, presence = DockPresence()
    var displays = [DockDisplayArea(id: "primary", frame: .init(x: 0,y: 0,width: 1440,height: 900), visibleFrame: .init(x: 0,y: 80,width: 1440,height: 820))]
    var notificationRequests: [String] = []
    var host: StaticDockPreviewHost { app.composition.dock }
    var editor: SettingsEditor { app.settingsHost.application.editor }
    static func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    init(profile: URL? = nil, wall: Date? = nil) throws {
        root = profile ?? FileManager.default.temporaryDirectory.appendingPathComponent("g1-d-" + UUID().uuidString)
        store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../..").standardizedFileURL
        raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("schema/app-cli/captures/WireRowsSnapshot.json"))) as? [String: Any])
        if let wall { clock.wall = wall }
        var projection = try XCTUnwrap(raw["projection"] as? [String: Any])
        let base = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        let account = try XCTUnwrap((base["accounts"] as? [[String: Any]])?.first)
        let window = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        var rows: [[String: Any]] = []
        for rowIndex in 0..<1 {
            var row = base; row["id"] = rowIndex == 0 ? "codex" : "claude-code"; row["order"] = rowIndex
            row["name"] = ["en": rowIndex == 0 ? "Synthetic Alpha" : "Synthetic Beta", "zh": rowIndex == 0 ? "合成甲" : "合成乙"]
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock","menu","settings"]; row["expiresAt"] = "2099-01-01T00:00:00Z"
            row["accounts"] = [0].map { index -> [String: Any] in
                var a = account; a["subscriptionRef"] = Self.ids[index]; a["route"] = "runtime_rpc"; a["valueState"] = "current"
                a["observedAt"] = Self.stamp(clock.wall.addingTimeInterval(-60)); a["freshUntil"] = "2099-01-01T00:00:00Z"
                a["plan"] = ["id":"pro", "name":["en":"Synthetic Pro","zh":"合成专业"]]
                a["credits"] = ["balance":1500,"unit":"credits"]
                a["windows"] = [0,1].map { number -> [String: Any] in
                    var w = window; w["id"] = number == 0 ? "short" : "week"; w["role"] = number == 0 ? "session" : "weekly"
                    w["durationSeconds"] = number == 0 ? 18000 : 604800; w["limitKey"] = number == 0 ? "five_hour" : "weekly"; w["poolKey"] = "main"
                    w["remainingPercent"] = number == 0 ? [41,26,0][index] : [70,60,50][index]
                    w["current"] = true; w["observedAt"] = Self.stamp(clock.wall.addingTimeInterval(-60)); w["validUntil"] = "2099-01-01T00:00:00Z"
                    w["resetsAt"] = Self.stamp(clock.wall.addingTimeInterval(number == 0 ? 8040 : 86400)); w["validUntil"] = w["resetsAt"]; w.removeValue(forKey:"modelScope")
                    return w
                }
                return a
            }
            rows.append(row)
        }
        projection["rows"] = rows; projection["resetEvents"] = []; raw["projection"] = projection
    }
    func open(autoHide: Bool = false, cockpitEnabled: Bool = false, notifications: Bool = false) async throws {
        _ = try await store.update { p in p.autoHide = autoHide; p.showDock = true; p.language = .english; p.motion = .on; if notifications { p.notifications.optedIn = true }; for _ in 0..<16 { p.onboarding.next() } }
        let rows = try decode()
        let previousLedger = EngineRowsEntry.isolatedNativeNotificationLedgerForChecks
        EngineRowsEntry.isolatedNativeNotificationLedgerForChecks = root.appendingPathComponent("g1-notifications.json")
        app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: cockpitEnabled,
            dockEnvironment: { [weak self] in guard let self else { return .init(displays: [], layouts: []) }; return .init(displays: self.displays, layouts: [], primaryDisplayID: "primary", pointer: self.pointer, presence: self.presence, cardFrame: self.cardFrame) },
            deadlineNow: { [clock] in clock.wall }, deadlineElapsed: { [clock] in clock.elapsed }, deadlineScheduling: timer,
            makeClient: { [weak self] _, store in let engine = G1AEngine(store: store, rows: rows); self?.engine = engine; return engine }, activateSettings: {})
        EngineRowsEntry.isolatedNativeNotificationLedgerForChecks = previousLedger
        app.composition.setResetNotificationDelivery { [weak self] in self?.notificationRequests.append($0) }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start(); tick(0.5)
    }
    func decode() throws -> WireRowsSnapshot { try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: raw)) }
    func publish() async throws { raw["sequence"] = ((raw["sequence"] as? Int) ?? 1) + 1; try await engine.deliver(decode()) }
    func mutateFirst(_ edit: (inout [String: Any]) -> Void) {
        var p = raw["projection"] as! [String: Any], rows = p["rows"] as! [[String: Any]], accounts = rows[0]["accounts"] as! [[String: Any]]
        edit(&accounts[0]); rows[0]["accounts"] = accounts; p["rows"] = rows; raw["projection"] = p
    }
    func tick(_ seconds: Double) { clock.elapsed += seconds; clock.wall.addTimeInterval(seconds); timer.fireIfDue(clock.elapsed); host.refreshPresence(); host.interactionControllerForChecks?.refresh() }
    func close() async { if let app { await app.composition.stop() }; try? FileManager.default.removeItem(at: root) }
}

@MainActor final class G1QuotaColourJourneysA: XCTestCase {
    private func checkSliver(_ percent: Int, threshold: Int = 25, expected: String?) async throws {
        let fixture = try G1AFixture()
        addTeardownBlock { @MainActor in await fixture.close() }
        try await fixture.open(autoHide: true)
        _ = try await fixture.store.update { $0.redBelow = threshold }
        fixture.mutateFirst { account in
            var windows = account["windows"] as! [[String: Any]]
            windows[0]["remainingPercent"] = percent
            windows[1]["remainingPercent"] = 100
            account["windows"] = windows
        }
        try await fixture.publish()
        let reading = try XCTUnwrap(fixture.host.dockView.presentedReadingsForChecks[G1AFixture.ids[0]])
        XCTAssertEqual(reading.remainingPercent, Double(percent), "Synthetic reading must reach the actual Dock")
        let role: DockQuotaStatus = percent <= threshold ? .critical : percent < 41 ? .warning : .normal
        XCTAssertEqual(reading.status, role)
        let skin = try XCTUnwrap(fixture.host.dockView.presentedSkinForChecks)
        let ink = try XCTUnwrap(skin.palette[role.rawValue])
        let expectedRGB: (Double, Double, Double) = role == .normal ? (90, 217, 186) : role == .warning ? (234, 193, 123) : (239, 68, 68)
        XCTAssertEqual(ink.r, expectedRGB.0 / 255, accuracy: 0.000001)
        XCTAssertEqual(ink.g, expectedRGB.1 / 255, accuracy: 0.000001)
        XCTAssertEqual(ink.b, expectedRGB.2 / 255, accuracy: 0.000001)
        XCTAssertEqual(ink.a, 1, accuracy: 0.000001)
        _ = try fixture.host.prepareSliver(size: CGSize(width: 4, height: 180))
        let actual = fixture.host.sliverQuotaColorsForChecks.map(\.rgbaHex)
        XCTAssertFalse(actual.isEmpty, "The actual Sliver must have a resolved drawing")
        if let expected {
            XCTAssertTrue(actual.contains(expected), "Actual Sliver RGBA runs: \(actual), expected \(expected)")
        } else {
            XCTAssertFalse(actual.contains("#EAC17BFF"), "An OK reading must not produce an amber alert segment: \(actual)")
            XCTAssertFalse(actual.contains("#EF4444FF"), "An OK reading must not produce a red alert segment: \(actual)")
        }
    }
    func testCOL_2_1_01() async throws { try await checkSliver(41, expected: nil) }
    func testCOL_2_1_02() async throws { try await checkSliver(40, expected: "#EAC17BFF"); try await checkSliver(26, expected: "#EAC17BFF") }
    func testCOL_2_1_03() async throws { try await checkSliver(25, expected: "#EF4444FF"); try await checkSliver(0, expected: "#EF4444FF") }
    func testCOL_2_1_05() async throws {
        for (percent, threshold, colour) in [(41,25,nil),(40,25,"#EAC17BFF" as String?),(26,25,"#EAC17BFF"),(25,25,"#EF4444FF"),(0,25,"#EF4444FF"),(17,16,"#EAC17BFF"),(16,16,"#EF4444FF")] {
            try await checkSliver(percent, threshold: threshold, expected: colour)
        }
    }
    func testCOL_2_1_04() throws { throw XCTSkip("COL-2.1-04: NOT RUN: day surface resolved quota colour inspection unavailable") }
    func testCOL_2_1_06() throws { throw XCTSkip("COL-2.1-06: NOT RUN: surface-role colour inspection and approved visual reference unavailable") }
    func testCOL_2_1_07() throws { throw XCTSkip("COL-2.1-07: NOT RUN: identity-colour surface inspection and approved visual reference unavailable") }
    func testCOL_2_1_08() throws { throw XCTSkip("COL-2.1-08: NOT RUN: real-state colour surface inspection unavailable") }
    func testCOL_2_1_09() throws { throw XCTSkip("COL-2.1-09: NOT RUN: preview-state colour surface inspection unavailable") }
    func testCOL_2_1_10() throws { throw XCTSkip("COL-2.1-10: NOT RUN: recommendation-star colour surface inspection unavailable") }
    func testCOL_2_1_11() throws { throw XCTSkip("COL-2.1-11: NOT RUN: actual jet colour and lifecycle inspection unavailable") }
    func testCOL_2_1_12() throws { throw XCTSkip("COL-2.1-12: NOT RUN: brand-red surface-role inspection unavailable") }
    func testCOL_2_1_13() throws { throw XCTSkip("COL-2.1-13: NOT RUN: identity and status surface-role inspection unavailable") }
    func testCOL_2_1_14() throws { throw XCTSkip("COL-2.1-14: NOT RUN: actual maker-accent inspection unavailable") }
    func testCOL_2_1_15() throws { throw XCTSkip("COL-2.1-15: NOT RUN: actual vendor-mark colour inspection unavailable") }
    func testCOL_2_1_16() throws { throw XCTSkip("COL-2.1-16: NOT RUN: user-facing status-colour setting absence needs complete Settings surface inspection") }
    func testCOL_2_1_17() throws { throw XCTSkip("COL-2.1-17: NOT RUN: status-bearing colour-role inspection unavailable") }
    func testHINT_9_02() throws { throw XCTSkip("HINT-9-02: NOT RUN: actual normal-entry hint visibility and dismissal timing are not observable without the admitted GUI journey") }
}
