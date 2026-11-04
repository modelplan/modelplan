// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

// The engine transport is synthetic; the entry, store and Settings composition are production.
private actor G1BEngine: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g1-b-synthetic", floor: .init(storeEpoch: "g1-b-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-b-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class G1PresentationHelpJourneysB: XCTestCase {
    private func entry(profile: URL, preferredLanguages: [String], fixture: WireRowsSnapshot? = nil) async throws -> EngineDockMenuApplication {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try fixture ?? WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: preferredLanguages)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            makeClient: { _, store in G1BEngine(store: store, rows: rows) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        await app.composition.start()
        return app
    }
    private func profile() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-b-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func quotaFixture() throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = try XCTUnwrap(rows.first)
        var accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = try XCTUnwrap(accounts.first)
        let original = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu"]
        row["name"] = ["en": "Synthetic", "zh": "合成"]
        row["expiresAt"] = "2099-01-01T00:00:00Z"
        account["subscriptionRef"] = "0123456789abcdef"; account["valueState"] = "current"
        account["observedAt"] = "2026-01-01T00:00:00Z"; account["freshUntil"] = "2099-01-01T00:00:00Z"
        account["windows"] = [("five", "session", 40.0, 18000), ("weekly", "weekly", 25.0, 604800)].map { id, role, value, duration in
            var window = original
            window["id"] = id; window["role"] = role; window["remainingPercent"] = value
            window["durationSeconds"] = duration; window["current"] = true
            window["limitKey"] = "main"; window["poolKey"] = "main"
            window["resetsAt"] = "2099-01-01T00:00:00Z"; window["validUntil"] = "2099-01-01T00:00:00Z"
            window.removeValue(forKey: "modelScope")
            return window
        }
        accounts = [account]; row["accounts"] = accounts; rows = [row]
        projection["rows"] = rows; root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }

    func testG1_LBL_2_2_09_CardResetTimesAreRelative() async throws {
        let app = try await entry(profile: profile(), preferredLanguages: ["en"], fixture: quotaFixture())
        let id = try XCTUnwrap(app.composition.presentedContent.snapshot.inputs.first?.id)
        let deadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2099-01-01T00:00:00Z"))
        for (language, expectations) in [
            (SettingsLanguage.english, ["45m", "3h 18m", "3d 5h"]),
            (.chinese, ["45分", "3小时18分", "3天5小时"])
        ] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(language))
            for (seconds, expected) in zip([2700.0, 11880.0, 277200.0], expectations) {
                let card = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: deadline.addingTimeInterval(-seconds)))
                let detail = try XCTUnwrap(card.rows.first { $0.id == "quota:five" }?.detail)
                XCTAssertTrue(detail.contains(expected), "Expected relative reset time: \(detail)")
                XCTAssertFalse(detail.contains("2099"))
            }
        }
    }

    func testG1_LBL_2_2_12_CardQuotaValuesAndBarsMeanRemaining() async throws {
        let app = try await entry(profile: profile(), preferredLanguages: ["en"], fixture: quotaFixture())
        let id = try XCTUnwrap(app.composition.presentedContent.snapshot.inputs.first?.id)
        for language in [SettingsLanguage.english, .chinese] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(language))
            let card = try XCTUnwrap(app.composition.dock.cardContent(for: id))
            for (id, value, fraction) in [("quota:five", "40%", 0.4), ("quota:weekly", "25%", 0.25)] {
                let row = try XCTUnwrap(card.rows.first { $0.id == id })
                XCTAssertEqual(row.value, value)
                XCTAssertEqual(try XCTUnwrap(row.remainingFraction), fraction, accuracy: 0.0001)
            }
        }
    }

    func testG1_LBL_2_2_07_ChineseMenusDoNotLeakEnglish() async throws {
        let app = try await entry(profile: profile(), preferredLanguages: ["zh-CN"], fixture: quotaFixture())
        let menu = try XCTUnwrap(app.liveStatusMenu)
        // The first status row and provider rows contain externally supplied data.
        // Check the app-owned actions separately, without treating vendor names as UI copy.
        let expected = ["刷新", "即将推出", "网站", "方法论", "隐私", "检查更新", "说明…", "设置…", "关于", "退出"]
        let statusTitles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
        let dockTitles = app.composition.dock.menu().items.filter { !$0.isSeparatorItem }.map(\.title)
        XCTAssertGreaterThan(statusTitles.count, 1)
        XCTAssertGreaterThanOrEqual(dockTitles.count, 3)
        XCTAssertEqual(Array(statusTitles.dropFirst()), expected)
        XCTAssertEqual(Array(dockTitles.suffix(3)), ["即将推出", "设置…", "隐藏挂件"])
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.english))
        let english = try XCTUnwrap(app.liveStatusMenu).items.filter { !$0.isSeparatorItem }.map(\.title)
        XCTAssertGreaterThan(english.count, 1)
        XCTAssertNotEqual(Array(english.dropFirst()), expected, "The check must reject English app-owned actions")
    }

    func testG1_LBL_2_2_15_MenuCopyOmitsInternalVocabulary() async throws {
        let app = try await entry(profile: profile(), preferredLanguages: ["en"], fixture: quotaFixture())
        for language in [SettingsLanguage.english, .chinese] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(language))
            let menu = try XCTUnwrap(app.liveStatusMenu)
            let statusTitles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
            let dockTitles = app.composition.dock.menu().items.filter { !$0.isSeparatorItem }.map(\.title)
            XCTAssertTrue(statusTitles.contains(language == .english ? "Settings…" : "设置…"))
            XCTAssertTrue(dockTitles.contains(language == .english ? "Settings…" : "设置…"))
            let copy = (statusTitles + dockTitles).joined(separator: " ").lowercased()
            for forbidden in ["source scope", "read here", "observation", "fixture", "envelope"] {
                XCTAssertFalse(copy.contains(forbidden), "Internal term appears in menu: \(forbidden)")
            }
        }
    }

    // Settings semantic coverage only: visible widget/cockpit locale evidence is a separate gate.
    func testG1_LBL_2_2_18_SettingsChoicesPersistThroughNormalEntryRelaunch() async throws {
        let root = try profile()
        let app = try await entry(profile: root, preferredLanguages: ["en-US"])
        let editor = app.settingsHost.application.editor
        let initial = try XCTUnwrap(editor.snapshot)
        let rows = try SettingsCatalogue.rows(preferences: initial.preferences, context: editor.context, paneID: nil)
        let language = try XCTUnwrap(rows.first { $0.key == .language })
        guard case .choice(_, let options) = language.value else { return XCTFail("Language must offer choices") }
        XCTAssertEqual(Set(options), Set(["en", "zh-CN"]))
        for choice in [SettingsLanguage.chinese, .english] {
            _ = try await editor.commit(SettingsB21Edit.language(choice))
            let persisted = await app.foundationStore.snapshot()
            XCTAssertEqual(persisted.preferences.language, choice)
            await app.composition.stop()
            let reopened = try await entry(profile: root, preferredLanguages: ["zh-CN"])
            XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.language, choice)
            await reopened.composition.stop()
        }
    }

    // The first-run window is not opened; this checks the persisted normal-entry selection.
    func testG1_LBL_2_2_19_FirstRunSelectionFollowsSupportedPreferences() async throws {
        let root = try profile()
        for (index, pair) in [(["en-US"], SettingsLanguage.english), (["zh-CN"], .chinese)].enumerated() {
            let (preferred, expected) = pair
            let app = try await entry(profile: root.appendingPathComponent(String(index)), preferredLanguages: preferred)
            let editor = app.settingsHost.application.editor
            let snapshot = try XCTUnwrap(editor.snapshot)
            XCTAssertEqual(snapshot.preferences.language, expected)
            let result = try await editor.completeFirstRun(options: .init(preferences: snapshot.preferences), action: .done, host: .popup, expectedRevision: snapshot.revision)
            XCTAssertTrue(result.snapshot.preferences.onboarding.completed)
            let saved = await app.foundationStore.snapshot()
            XCTAssertEqual(saved.preferences.language, expected)
            await app.composition.stop()
        }
    }

    // Status and Dock menu coverage; open Settings and cockpit surfaces are not exercised here.
    func testG1_LBL_2_2_20_NormalEntryMenusSwitchLanguageTogether() async throws {
        let root = try profile()
        let app = try await entry(profile: root, preferredLanguages: ["en-US"])
        let editor = app.settingsHost.application.editor
        for (language, expected, unexpected) in [
            (SettingsLanguage.english, "Settings…", "设置…"),
            (.chinese, "设置…", "Settings…")
        ] {
            _ = try await editor.commit(SettingsB21Edit.language(language))
            let menu = try XCTUnwrap(app.liveStatusMenu)
            let dockMenu = app.composition.dock.menu()
            XCTAssertTrue(menu.items.contains { $0.title == expected })
            XCTAssertFalse(menu.items.contains { $0.title == unexpected })
            XCTAssertTrue(dockMenu.items.contains { $0.title == expected })
            XCTAssertFalse(dockMenu.items.contains { $0.title == unexpected })
        }
    }
}
