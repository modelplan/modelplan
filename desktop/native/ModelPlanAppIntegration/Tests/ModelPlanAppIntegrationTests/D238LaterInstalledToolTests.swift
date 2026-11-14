// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest
@_spi(SettingsAcceptance) import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration


/// Synthetic engine for the normal entry: the session starts with the baseline rows; the test
/// then delivers the engine's next view, as its observation tick does after an install.
private actor D238EntryClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool {
        context.sessionID == "synthetic-d238-entry" && context.floor.storeEpoch == "synthetic-d238-entry" &&
            context.floor.generation == 1 && context.revision == 1
    }
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "synthetic-d238-entry", floor: .init(storeEpoch: "synthetic-d238-entry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string(request.requestId)) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-refresh")) }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-plugin")) }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class D238SettingsSurface: SettingsWindowSurface {
    var panes: [String?] = []
    var onShow: (() -> Void)?
    func prepare() async {}
    func show(paneID: String?) { panes.append(paneID); onShow?() }
    func hide() {}
}

/// D238: a supported tool installed while ModelPlan runs reaches the app through the normal
/// engine rows path as detected-not-enabled: a status-menu line that opens Settings, no values
/// and no Quota Widget ring (G3-38, owner D76) until the user grants the tool's scope.
@MainActor final class D238LaterInstalledToolTests: XCTestCase {
    // The engine's own output for Kiro installed after the first run (rows.Build, D238). Kiro is
    // read through its runtime, so it stays opt-in; local-log-only tools are allowed without an
    // offer (D240).
    private static let kiroOffered = #"{"id":"kiro","kind":"tool","order":10,"name":{"en":"Kiro","zh":"Kiro"},"vendorKey":null,"surfaces":["menu","settings"],"consent":"unset","state":"needs_consent","reason":{"code":"consent_required","text":{"en":"Reader consent is needed","zh":"需要读取授权"}},"nextStep":{"action":"open_settings_consent","text":{"en":"Review reader consent in Settings","zh":"在设置中检查读取授权"}},"accounts":[],"expiresAt":null,"stateAfterExpiry":null}"#
    // The same tool when it was already there at first run and left undecided: Settings only.
    private static let kiroBaseline = kiroOffered.replacingOccurrences(of: #"["menu","settings"]"#, with: #"["settings"]"#)
    private static let summary = #"{"state":"no_consent","reason":{"code":"no_consent","text":{"en":"Choose tools to allow in Settings","zh":"在设置中选择允许读取的工具"}},"text":{"en":"Choose tools to allow in Settings","zh":"在设置中选择允许读取的工具"},"nextStep":{"action":"open_settings_consent","text":{"en":"Review reader consent in Settings","zh":"在设置中检查读取授权"}}}"#

    private func snapshot(_ sequence: Int, rows: [String]) throws -> WireRowsSnapshot {
        let json = #"{"sequence":"# + String(sequence) + #","projection":{"rowsVersion":1,"rows":["# + rows.joined(separator: ",") + #"],"rowsSummary":"# + Self.summary + "}}"
        return try WireDecoder.decode(WireRowsSnapshot.self, from: Data(json.utf8))
    }
    private func deliver(_ value: WireRowsSnapshot, to store: EngineStore) async throws {
        let context = EngineDeliveryContext(sessionID: "synthetic-d238", floor: .init(storeEpoch: "synthetic-d238", generation: 7), revision: 1)
        let reply = EngineReply(envelope: try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 7, data: value), delivery: context)
        await store.consume(.rowsChanged(reply, invalidRowCount: 0))
    }

    func testToolInstalledAfterLaunchAppearsAsDetectedNotEnabled() async throws {
        let store = EngineStore()
        let provider = EngineDockMenuProvider(store: store)
        try await deliver(snapshot(1, rows: []), to: store)
        XCTAssertTrue(DetectedToolOffer.offers(provider.dockContent.menuRows, english: true).isEmpty)

        // The engine's next view after the install (its 30 s observation tick, Settings or wake).
        try await deliver(snapshot(2, rows: [Self.kiroOffered]), to: store)
        XCTAssertEqual(provider.dockContent.menuRows.map(\.id), ["kiro"])
        XCTAssertTrue(provider.dockContent.dockRows.isEmpty, "an undecided tool has no Quota Widget ring")
        XCTAssertTrue(EngineAccountMemberCatalogue(rows: provider.dockContent.menuRows).members.isEmpty, "no values before consent")
        XCTAssertEqual(DetectedToolOffer.offers(provider.dockContent.menuRows, english: true),
                       [.init(rowID: "kiro", title: "Kiro: Detected · Enable…")])
        XCTAssertEqual(DetectedToolOffer.offers(provider.dockContent.menuRows, english: false).map(\.title), ["Kiro：已检测到 · 启用…"])

        // Uninstalled: the engine drops the row and the line goes with it.
        try await deliver(snapshot(3, rows: []), to: store)
        XCTAssertTrue(DetectedToolOffer.offers(provider.dockContent.menuRows, english: true).isEmpty)
    }

    func testFirstRunToolLeftUndecidedIsNotOfferedAgain() throws {
        let rows = try snapshot(1, rows: [Self.kiroBaseline]).projection.rows
        XCTAssertTrue(DetectedToolOffer.offers(rows.filter { $0.surfaces.contains(.menu) }, english: true).isEmpty)
        XCTAssertTrue(DetectedToolOffer.offers(rows, english: true).isEmpty)
    }

    // Gemini CLI installed later: local logs only, so the engine allowed them without a prompt
    // (D240) and the row is waiting for its first reading (engine output, rows.Build).
    private static let geminiAutoRead = #"{"id":"gemini","kind":"tool","order":4,"name":{"en":"Gemini CLI","zh":"Gemini CLI"},"vendorKey":null,"surfaces":["menu","settings"],"consent":"allowed","state":"pending","reason":{"code":"not_read_yet","text":{"en":"Waiting for the first reading","zh":"等待首次读取"}},"nextStep":{"action":"none","text":{"en":"Wait for the next available reading","zh":"等待下一次可用读数"}},"accounts":[],"expiresAt":null,"stateAfterExpiry":null}"#

    /// FR-9-13 at the normal entry: `EngineRowsEntry.make` builds the real status menu. Tools
    /// appear after launch; only the opt-in one gets the line, and the line opens Subscriptions.
    func testStatusMenuOffersOnlyTheOptInToolInstalledAfterLaunch() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("d238-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let settingsStore = try SettingsStore(url: profile.appendingPathComponent("settings.json"))
        try await settingsStore.update { $0.language = .english }
        let surface = D238SettingsSurface()
        let baseline = try snapshot(1, rows: [])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settingsStore, createsNativePanels: false,
            makeClient: { _, store in D238EntryClient(store: store, rows: baseline) },
            makeSettingsSurface: { _ in surface }, activateSettings: {})
        await app.prepare()
        await app.composition.start()
        func titles() throws -> [String] { try XCTUnwrap(app.liveStatusMenu).items.filter { !$0.isSeparatorItem }.map(\.title) }
        let before = try titles()
        XCTAssertFalse(before.contains { $0.contains("Detected") })

        let context = EngineDeliveryContext(sessionID: "synthetic-d238-entry", floor: .init(storeEpoch: "synthetic-d238-entry", generation: 1), revision: 1)
        let next = try snapshot(2, rows: [Self.geminiAutoRead, Self.kiroOffered])
        await app.composition.store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: next), delivery: context), invalidRowCount: 0))
        let after = try titles()
        XCTAssertEqual(after.filter { $0 == "Kiro: Detected · Enable…" }.count, 1, "the opt-in tool gets one line: \(after)")
        XCTAssertFalse(after.contains { $0.hasPrefix("Gemini CLI") }, "a local-log tool is read without an offer (D240): \(after)")
        XCTAssertEqual(after.filter { $0 != "Kiro: Detected · Enable…" }, before, "nothing else in the menu changes")
        XCTAssertTrue(app.composition.provider.dockContent.dockRows.isEmpty, "no Quota Widget ring for an unread tool (G3-38)")

        let menu = try XCTUnwrap(app.liveStatusMenu)
        let index = try XCTUnwrap(menu.items.firstIndex { $0.title == "Kiro: Detected · Enable…" })
        let shown = expectation(description: "The line opens Settings › Subscriptions")
        surface.onShow = { shown.fulfill() }
        menu.performActionForItem(at: index)
        await fulfillment(of: [shown], timeout: 2)
        XCTAssertEqual(surface.panes.last ?? nil, "subscriptions")

        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(try titles().filter { $0.contains("已检测到") }, ["Kiro：已检测到 · 启用…"])
        await app.composition.stop()
    }
}
