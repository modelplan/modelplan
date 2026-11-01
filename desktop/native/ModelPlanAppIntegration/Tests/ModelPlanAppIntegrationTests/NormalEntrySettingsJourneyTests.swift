// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor SettingsJourneyClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { false }
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

@MainActor private final class JourneyAppearanceConsumer: EngineRowsConsoleSurface {
    var applied: EffectiveSettings?
    func show() {}
    func render() {}
    func hide() {}
    func applySettings(_ value: SettingsApplication) { applied = value.effective }
}

@MainActor final class NormalEntrySettingsJourneyTests: XCTestCase {
    func testNormalEntrySettingsAndDragUpdateTheDockAndSurviveRelaunch() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("settings-journey-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]
        rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let appearanceConsumer = JourneyAppearanceConsumer()
        func makeApp() throws -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration: configuration,
                settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
                createsNativePanels: false,
                makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) },
                makeConsole: { _ in appearanceConsumer },
                activateSettings: {})
        }

        let first = try makeApp()
        await first.prepare()
        first.composition.dock.setPresentationAllowed(true)
        await first.composition.start()
        let dock = first.composition.dock
        let englishMenu = try XCTUnwrap(first.liveStatusMenu)
        XCTAssertTrue(englishMenu.items.contains { $0.title == "Settings…" })
        XCTAssertTrue(englishMenu.items.contains { $0.title == "Dock readings…" })
        XCTAssertFalse(englishMenu.items.contains { $0.title.contains(" / ") })
        let editor = first.settingsHost.application.editor
        first.showConsole()
        var syntheticSystem = editor.environment
        syntheticSystem.reduceMotion = true; syntheticSystem.reduceTransparency = true
        first.updateSystemAccessibility(syntheticSystem)
        XCTAssertEqual(appearanceConsumer.applied?.reduceMotion, true)
        XCTAssertEqual(appearanceConsumer.applied?.reduceTransparency, true)
        syntheticSystem.reduceMotion = false; syntheticSystem.reduceTransparency = false
        first.updateSystemAccessibility(syntheticSystem)
        _ = try await editor.commit(SettingsB20Edit.motion(.on))
        _ = try await editor.commit(SettingsB20Edit.transparency(.on))
        XCTAssertEqual(appearanceConsumer.applied?.reduceMotion, true)
        XCTAssertEqual(appearanceConsumer.applied?.reduceTransparency, true)
        XCTAssertEqual(first.composition.latestSettings?.effective.reduceMotion, true)
        XCTAssertEqual(first.composition.latestSettings?.effective.reduceTransparency, true)
        XCTAssertTrue(editor.context.v1NormalEntry)
        XCTAssertTrue(try XCTUnwrap(editor.effective).darkAppearance)
        XCTAssertEqual(try XCTUnwrap(editor.effective).opening, .quick)
        let visible = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        XCTAssertFalse(visible.contains { [.theme, .opening, .countdown].contains($0.key) })
        XCTAssertEqual(visible.first { $0.key == .motion }?.availability, .available)
        XCTAssertEqual(visible.first { $0.key == .transparency }?.availability, .available)
        XCTAssertEqual(visible.first { $0.key == .openShortcut }?.availability, .serviceUnavailable)
        XCTAssertTrue(visible.first { $0.key == .openShortcut }?.subtitle.english.contains("Unavailable") == true)
        XCTAssertEqual(first.composition.provider.dockContent.dockRows.map(\.id), ["codex"])
        XCTExpectFailure("#697: member projection has not yet been integrated") {
            XCTAssertTrue(editor.context.subscriptions.contains { $0.id == "0123456789abcdef" }, "The Settings catalogue must reflect the Dock's detected subscription")
        }
        XCTAssertEqual(editor.snapshot?.preferences.language, .english, "A fresh install follows the macOS preferred language")
        XCTAssertEqual(editor.snapshot?.preferences.percentageMode, .remaining)
        _ = try await editor.commit(SettingsB20Edit.percentageMode(.used))
        XCTAssertEqual(dock.currentMenuBarPreferences?.percentageMode, .used)
        let initialNozzle = dock.dockView.requestedNozzleDiameter
        _ = try await editor.commit(SettingsB20Edit.size(.large))
        XCTAssertEqual(dock.currentMenuBarPreferences?.size, .large)
        XCTAssertNotEqual(dock.dockView.requestedNozzleDiameter, initialNozzle, "A Settings size edit changes the retained Dock presentation")

        // The host receives the same committed-placement event its real drag controller produces.
        dock.commitDisplayPlacement?("synthetic-display", .left, 0.3)
        for _ in 0..<40 {
            if (await first.foundationStore.snapshot()).preferences.dockEdge == .left { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertEqual(dock.currentMenuBarPreferences?.dockEdge, .left, "The dragged edge applies without a restart")
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        let chineseMenu = try XCTUnwrap(first.liveStatusMenu)
        XCTAssertTrue(chineseMenu.items.contains { $0.title == "设置…" })
        XCTAssertTrue(chineseMenu.items.contains { $0.title == "挂件读数…" })
        XCTAssertFalse(chineseMenu.items.contains { $0.title.contains(" / ") || $0.title.contains("Dock") })
        await first.composition.stop()

        let reopened = try makeApp()
        await reopened.prepare()
        reopened.composition.dock.setPresentationAllowed(true)
        await reopened.composition.start()
        let saved = await reopened.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.size, .large)
        XCTAssertEqual(saved.preferences.language, .chinese, "An explicit choice survives relaunch")
        XCTAssertEqual(saved.preferences.percentageMode, .used)
        XCTAssertEqual(saved.preferences.motion, .on)
        XCTAssertEqual(saved.preferences.transparency, .on)
        XCTAssertEqual(EngineRowsText.readingsTitle.value(.chinese), "挂件读数")
        XCTAssertEqual(EngineRowsText.waiting.value(.chinese), "等待读数")
        XCTAssertEqual(saved.preferences.dockEdge, .left)
        XCTAssertEqual(saved.preferences.dockDisplayID, "synthetic-display")
        XCTAssertEqual(saved.preferences.dockAlongFraction, 0.3, accuracy: 0.0001)
        XCTAssertEqual(reopened.composition.dock.currentMenuBarPreferences?.dockEdge, .left)
        XCTAssertEqual(reopened.composition.dock.dockView.requestedNozzleDiameter, dock.dockView.requestedNozzleDiameter)
        await reopened.composition.stop()

        let otherProfile = profile.appendingPathComponent("system-language")
        let chineseStore = try EngineRowsEntry.makeSettingsStore(applicationSupport: otherProfile,
            preferredLanguages: ["zh-Hans", "en-US"])
        let chinese = await chineseStore.snapshot()
        XCTAssertEqual(chinese.preferences.language, .chinese, "Use Chinese when the Mac prefers Chinese")
        let otherLanguage = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile.appendingPathComponent("other-language"),
            preferredLanguages: ["fr-FR", "zh-Hans", "en-US"])
        let otherSnapshot = await otherLanguage.snapshot()
        XCTAssertEqual(otherSnapshot.preferences.language, .english, "A non-Chinese Mac preference defaults to English")
        let noLanguage = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile.appendingPathComponent("no-language"), preferredLanguages: [])
        let noLanguageSnapshot = await noLanguage.snapshot()
        XCTAssertEqual(noLanguageSnapshot.preferences.language, .english, "A missing Mac preference defaults to English")
        let legacyProfile = profile.appendingPathComponent("legacy-language")
        let legacyFile = legacyProfile.appendingPathComponent("ModelPlan/Native/settings-v1.json")
        try FileManager.default.createDirectory(at: legacyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacyBytes = Data(#"{"schemaVersion":1,"preferences":{"language":"zh-CN"}}"#.utf8)
        try legacyBytes.write(to: legacyFile)
        let migrated = try EngineRowsEntry.makeSettingsStore(applicationSupport: legacyProfile, preferredLanguages: ["en-US"])
        let migratedSnapshot = await migrated.snapshot()
        XCTAssertEqual(migratedSnapshot.preferences.language, .chinese)
        XCTAssertEqual(try Data(contentsOf: legacyFile), legacyBytes)
    }
    func testFreshChineseNormalEntryShowsChineseDockCardAge() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("chinese-card-age-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["zh-CN"]),
            createsNativePanels: false, makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) }, activateSettings: {})
        await app.prepare(); app.composition.dock.setPresentationAllowed(true); await app.composition.start()
        defer { app.composition.dock.close() }
        let dock = app.composition.dock
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.language, .chinese)
        dock.dockView.onAction?(.subscription("codex"))
        XCTAssertFalse(dock.card.isHidden)
        func field(_ view: NSView) -> NSTextField? {
            if let value = view as? NSTextField, value.accessibilityIdentifier() == "dock.card.text.source" { return value }
            return view.subviews.lazy.compactMap(field).first
        }
        let age = try XCTUnwrap(field(dock.card)?.stringValue)
        XCTAssertTrue(age == "读数时间未知" || age.hasPrefix("读取于 "), "Fresh Chinese entry must render the actual card age in Chinese: \(age)")
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.english))
        dock.dockView.onAction?(.subscription("codex"))
        let englishAge = try XCTUnwrap(field(dock.card)?.stringValue)
        XCTAssertTrue(englishAge == "Reading time unknown" || englishAge.hasPrefix("Reading taken "), "The same card must follow an explicit English choice: \(englishAge)")
        await app.composition.stop()
    }

}
