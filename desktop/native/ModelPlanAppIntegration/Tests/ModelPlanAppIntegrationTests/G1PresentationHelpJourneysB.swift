// SPDX-License-Identifier: MIT
import Foundation
import XCTest
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
    private func entry(profile: URL, preferredLanguages: [String]) async throws -> EngineDockMenuApplication {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
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
        for (index, preferred) in [["en-US"], ["zh-CN"]].enumerated() {
            let app = try await entry(profile: root.appendingPathComponent(String(index)), preferredLanguages: preferred)
            let editor = app.settingsHost.application.editor
            let snapshot = try XCTUnwrap(editor.snapshot)
            XCTAssertTrue(SettingsLanguage.allCases.contains(snapshot.preferences.language))
            let result = try await editor.completeFirstRun(options: .init(preferences: snapshot.preferences), action: .done, host: .popup, expectedRevision: snapshot.revision)
            XCTAssertTrue(result.snapshot.preferences.onboarding.completed)
            let saved = await app.foundationStore.snapshot()
            XCTAssertEqual(saved.preferences.language, snapshot.preferences.language)
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
