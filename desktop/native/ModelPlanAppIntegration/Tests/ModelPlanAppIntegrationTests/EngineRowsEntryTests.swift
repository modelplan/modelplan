// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor RowsEntryClient: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "synthetic-entry", floor: .init(storeEpoch: "synthetic-entry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-refresh")) }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class EntrySettingsSurface: SettingsWindowSurface {
    var shown = 0
    private var waiter: CheckedContinuation<Void, Never>?
    func prepare() async {}
    func show(paneID: String?) { shown += 1; waiter?.resume(); waiter = nil }
    func hide() {}
    func waitForShow() async { if shown > 0 { return }; await withCheckedContinuation { waiter = $0 } }
}
@MainActor private final class EntryConsoleSurface: EngineRowsConsoleSurface {
    var shown = 0
    var lastRows: [String] = []
    let composition: EngineDockMenuComposition
    init(_ composition: EngineDockMenuComposition) { self.composition = composition }
    func show() { shown += 1; render() }
    func render() { lastRows = composition.provider.dockContent.dockRows.map(\.id) }
    func hide() {}
}
@MainActor final class EngineRowsEntryTests: XCTestCase {
    func testNormalEntryFactoryFeedsActualDockAndMenuThenWithdrawsBeforeClearAck() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("u6-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(object["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]
        rows[0]["expiresAt"] = "2027-01-01T00:00:00Z" // This scenario is live; the separate expiry scenario advances beyond it.
        rows[0]["name"] = ["en": "Engine-only row", "zh": "引擎行"]
        rows[0]["reason"] = ["code": "ok", "text": ["en": "Engine-only reason", "zh": "引擎原因"]]
        projection["rows"] = rows; object["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        let settingsSurface = EntrySettingsSurface()
        var consoleSurface: EntryConsoleSurface?
        var activationCount = 0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try SettingsStore(url: profile.appendingPathComponent("settings.json")), createsNativePanels: false,
            makeClient: { _, store in RowsEntryClient(store: store, rows: fixture) },
            makeSettingsSurface: { _ in settingsSurface },
            makeConsole: { let surface = EntryConsoleSurface($0); consoleSurface = surface; return surface },
            activateSettings: { activationCount += 1 })
        XCTAssertNotNil(app.composition.dock.showSettings, "Normal Dock Settings must not be a nil action")
        XCTAssertNotNil(app.composition.dock.showConsole, "Normal Dock Console must not be a nil action")
        await app.prepare(); await app.composition.start()
        app.composition.dock.showSettings?(); await settingsSurface.waitForShow()
        XCTAssertEqual(settingsSurface.shown, 1); XCTAssertEqual(activationCount, 1)
        app.composition.dock.showConsole?(); XCTAssertEqual(consoleSurface?.shown, 1)
        XCTAssertEqual(consoleSurface?.lastRows, ["codex"])
        XCTAssertEqual(app.composition.provider.dockContent.dockRows.map(\.id), ["codex"])
        XCTAssertTrue(app.composition.dock.menu().items.contains { $0.title.contains("Engine-only reason") })
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("Engine-only reason"))
        XCTAssertNil(app.composition.dock.nativePanel)
        // Simulate tracking while retaining the actual instances that were already displayed.
        let trackedStatus = try XCTUnwrap(app.liveStatusMenu)
        let trackedDock = app.composition.dock.menu()
        app.menuWillOpen(trackedStatus); app.composition.dock.menuWillOpen(trackedDock)
        NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: trackedDock)
        let retainedButUntrackedDock = app.composition.dock.menu()
        let unrelated = NSMenu()
        unrelated.addItem(withTitle: "Unrelated synthetic title", action: nil, keyEquivalent: "")
        let retainedItems = trackedStatus.items + trackedDock.items + retainedButUntrackedDock.items
        let retainedReading = try XCTUnwrap(retainedItems.first { $0.title.contains("Engine-only reason") })
        retainedReading.attributedTitle = NSAttributedString(string: "Engine-only reason")
        retainedReading.toolTip = "Engine-only reason"
        retainedReading.representedObject = "Engine-only reason"
        XCTAssertTrue(trackedStatus.items.contains { $0.title.contains("Engine-only reason") })
        XCTAssertTrue(trackedDock.items.contains { $0.title.contains("Engine-only reason") })
        var clearObservedBeforeReturn = false
        let originalMenuChange = app.composition.menuDidChange
        app.composition.menuDidChange = {
            originalMenuChange?()
            if app.composition.provider.dockContent.status == .cleared {
                clearObservedBeforeReturn = true
                XCTAssertFalse(trackedStatus.items.contains { $0.title.contains("Engine-only reason") }, "The tracked status menu must be scrubbed before acknowledgement")
                XCTAssertFalse(trackedDock.items.contains { $0.title.contains("Engine-only reason") }, "The tracked Dock menu must be scrubbed before acknowledgement")
                XCTAssertFalse(retainedButUntrackedDock.items.contains { $0.title.contains("Engine-only reason") })
                XCTAssertEqual(unrelated.items.first?.title, "Unrelated synthetic title", "Only this app composition's owned menus may be scrubbed")
                XCTAssertFalse(retainedItems.contains { $0.title.contains("Engine-only reason") }, "Retained item instances must also lose private titles")
                XCTAssertNil(retainedReading.attributedTitle)
                XCTAssertNil(retainedReading.toolTip)
                XCTAssertNil(retainedReading.representedObject)
                XCTAssertFalse(app.composition.dock.menu().items.contains { $0.title.contains("Engine-only reason") })
                XCTAssertFalse(app.composition.menuPresentation.detail.contains("Engine-only reason"))
            }
        }
        await app.composition.store.consume(.clearPrivateViews(.init(revision: 2, reason: .connectionLost, previous: nil, nextFloor: nil)))
        XCTAssertFalse(app.composition.dock.menu().items.contains { $0.title.contains("Engine-only reason") })
        XCTAssertFalse(app.composition.menuPresentation.detail.contains("Engine-only reason"))
        XCTAssertEqual(consoleSurface?.lastRows, [])
        app.composition.dock.menuDidClose(trackedDock)
        XCTAssertTrue(clearObservedBeforeReturn)
        XCTAssertTrue(app.composition.provider.dockContent.dockRows.isEmpty)
        await app.composition.stop()
    }
    func testFreshGeneratedWindowReachesDockInputAndMenuReading() async throws {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["state"] = "fresh"
        rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        rows[0]["stateAfterExpiry"] = ["state": "stale", "reason": ["code": "ok", "text": ["en": "Engine expiry reason", "zh": "引擎到期原因"]]]
        var accounts = try XCTUnwrap(rows[0]["accounts"] as? [[String: Any]])
        accounts[0]["valueState"] = "current"; accounts[0]["freshUntil"] = "2027-01-01T00:00:00Z"
        var windows = try XCTUnwrap(accounts[0]["windows"] as? [[String: Any]])
        windows[0]["current"] = true; windows[0]["remainingPercent"] = 73
        windows[0]["validUntil"] = "2027-01-01T00:00:00Z"; windows[0]["resetsAt"] = "2027-01-01T00:00:00Z"
        accounts[0]["windows"] = windows; rows[0]["accounts"] = accounts
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let store = EngineStore(), source = EngineDockMenuProvider(store: store)
        let adapter = EngineDockContentProvider(source: source)
        let fake = RowsEntryClient(store: store, rows: fixture); _ = try await fake.start()
        let content = adapter.makeContent(.init(snapshot: nil, diagnostics: .init(), now: Date()))
        XCTAssertEqual(content.snapshot.inputs.first?.windows.first?.remainingPercent, 73)
        XCTAssertEqual(content.snapshot.inputs.first?.dataState, .fresh)
        XCTAssertTrue((content.menuStatusLines ?? []).joined().contains("73%"))
        let expired = adapter.makeContent(.init(snapshot: nil, diagnostics: .init(), now: Date(timeIntervalSince1970: 1_830_297_600)))
        XCTAssertNil(expired.snapshot.inputs.first?.windows.first?.remainingPercent)
        XCTAssertEqual(expired.snapshot.presentationRows["codex"]?.reason, "Engine expiry reason")
        XCTAssertTrue((expired.menuStatusLines ?? []).joined().contains("Engine expiry reason"))
    }

    func testNormalSettingsContextUsesBundleNoticesAndAcceptedEngineReadiness() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("u6-about-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let bundle = profile.appendingPathComponent("Synthetic.app")
        let resources = bundle.appendingPathComponent("Contents/Resources")
        let helpers = bundle.appendingPathComponent("Contents/Helpers")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        let helper = Data("synthetic-not-executable".utf8)
        let hash = SHA256.hash(data: helper).map { String(format: "%02x", $0) }.joined()
        try helper.write(to: helpers.appendingPathComponent("modelplan"))
        try Data(hash.utf8).write(to: resources.appendingPathComponent("modelplan.sha256"))
        let info: [String: Any] = ["CFBundleShortVersionString": "3.2.1", "ModelPlanPublicSource": String(repeating: "a", count: 40),
            "ModelPlanHelperVersion": CommunityConsentBundleIdentity.version,
            "ModelPlanBundledHelperSHA256": hash,
            "ModelPlanSourceHelperSHA256": try XCTUnwrap(CommunityConsentBundleIdentity.sourceSHA256ByArchitecture.values.first)]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        try Data("Synthetic MIT notice".utf8).write(to: resources.appendingPathComponent("LICENSE.txt"))
        try Data("Synthetic dependency notices".utf8).write(to: resources.appendingPathComponent("CLI-THIRD-PARTY-NOTICES.md"))
        XCTAssertTrue(CommunityConsentBundleIdentity.matches(bundle: bundle))
        let summary = try RowsRowsSummary(state: .empty, reason: .init(code: .ok, text: .init(en: "Synthetic", zh: "合成")), text: .init(en: "Synthetic", zh: "合成"))
        let fixture = try WireRowsSnapshot(sequence: 1, projection: .init(rowsVersion: 1, rows: [], rowsSummary: summary))
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helpers.appendingPathComponent("modelplan"), applicationVersion: "3.2.1", allowedEnvironment: [:]),
            settingsStore: try SettingsStore(url: profile.appendingPathComponent("settings.json")), createsNativePanels: false, bundleURL: bundle,
            makeClient: { _, store in RowsEntryClient(store: store, rows: fixture) })
        XCTAssertEqual(app.currentSettingsContext.about.appVersion, "3.2.1")
        XCTAssertEqual(app.currentSettingsContext.licenseNotices.count, 2)
        XCTAssertNotEqual(app.currentSettingsContext.about.macOSVersion, "unknown")
        XCTAssertNotEqual(app.currentSettingsContext.about.cliState, .ready)
        await app.prepare(); await app.composition.start()
        XCTAssertEqual(app.currentSettingsContext.about.cliVersion, CommunityConsentBundleIdentity.version)
        XCTAssertEqual(app.currentSettingsContext.about.cliState, .ready)
        await app.composition.store.consume(.connection(.stopped(.requested)))
        XCTAssertEqual(app.currentSettingsContext.about.cliState, .unavailable)
        await app.composition.stop()
        try Data("synthetic-mismatched-helper".utf8).write(to: helpers.appendingPathComponent("modelplan"))
        let unverified = EngineRowsEntry.make(configuration: .init(executableURL: helpers.appendingPathComponent("modelplan"), applicationVersion: "3.2.1", allowedEnvironment: [:]),
            settingsStore: try SettingsStore(url: profile.appendingPathComponent("settings-unverified.json")), createsNativePanels: false, bundleURL: bundle,
            makeClient: { _, store in RowsEntryClient(store: store, rows: fixture) })
        await unverified.prepare(); await unverified.composition.start()
        XCTAssertEqual(unverified.currentSettingsContext.about.appVersion, "3.2.1")
        XCTAssertEqual(unverified.currentSettingsContext.licenseNotices.count, 2)
        XCTAssertEqual(unverified.currentSettingsContext.about.cliState, .unavailable, "Protocol readiness cannot promote an unverified helper")
        XCTAssertEqual(unverified.currentSettingsContext.about.cliVersion, "unknown")
        await unverified.composition.stop()
    }

}
