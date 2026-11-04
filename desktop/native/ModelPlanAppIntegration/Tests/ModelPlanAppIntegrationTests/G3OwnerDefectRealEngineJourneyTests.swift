// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanInstruments
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

// These are synthetic normal-entry behaviour checks. The real-server and
// candidate-window evidence required by the G3 gate is a separate run.
private actor G3SyntheticEngine: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g3-synthetic", floor: .init(storeEpoch: "g3-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context)); return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("g3-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class G3NoWindowSurface: SettingsWindowSurface {
    func prepare() async {}
    func show(paneID: String?) { XCTFail("Unexpected settings window") }
    func hide() {}
}

@MainActor final class G3OwnerDefectJourneyTests: XCTestCase {
    // A detached real-engine preflight is useful evidence, but does not claim
    // a displayed status-item contour or visible-extent result.
    private func realStatusPreflight() async throws -> (EngineDockMenuApplication, NSImage) {
        let environment = ProcessInfo.processInfo.environment
        guard let candidate = environment["MODELPLAN_G3_CANDIDATE_APP"],
              let expectedHash = environment["MODELPLAN_G3_HELPER_SHA256"], expectedHash.count == 64 else {
            throw XCTSkip("NOT RUN: an identity-bound packaged candidate and helper are required")
        }
        let bundle = URL(fileURLWithPath: candidate, isDirectory: true).standardizedFileURL
        guard bundle.pathExtension == "app" else { throw XCTSkip("NOT RUN: candidate is not a packaged app") }
        let binary = bundle.appendingPathComponent("Contents/Helpers/modelplan")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { throw XCTSkip("NOT RUN: packaged app-server is unavailable") }
        let digest = SHA256.hash(data: try Data(contentsOf: binary)).map { String(format: "%02x", $0) }.joined()
        guard digest == expectedHash.lowercased() else { throw XCTSkip("NOT RUN: candidate helper identity mismatch") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-real-engine-" + UUID().uuidString, isDirectory: true)
        let session = root.appendingPathComponent(".codex/sessions/2026/11/05", isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        let timestamp = Date(), formatter = ISO8601DateFormatter()
        let synthetic: [String: Any] = ["timestamp": formatter.string(from: timestamp), "type": "event_msg", "payload": ["type": "token_count", "rate_limits": ["limit_id": "codex", "plan_type": "plus", "primary": ["used_percent": 25, "window_minutes": 300, "resets_at": Int(timestamp.addingTimeInterval(7200).timeIntervalSince1970)]]]]
        var bytes = try JSONSerialization.data(withJSONObject: synthetic, options: [.sortedKeys]); bytes.append(0x0a)
        try bytes.write(to: session.appendingPathComponent("rollout-2026-11-05T00-00-00-synthetic.jsonl"), options: .atomic)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("settings"), preferredLanguages: ["en"])
        let configuration = EngineClientConfiguration(executableURL: binary, applicationVersion: "g3-synthetic", allowedEnvironment: ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"], offline: true, readOnly: true)
        let entry = EngineRowsEntry.make(configuration: configuration, settingsStore: settings, createsNativePanels: false, bundleURL: bundle, activateSettings: {})
        addTeardownBlock { @MainActor in await entry.composition.stop(); entry.composition.dock.close(); try? FileManager.default.removeItem(at: root) }
        await entry.prepare(); entry.allowDockPresentation(); await entry.composition.start()
        XCTAssertTrue(entry.composition.client is ProcessEngineClient)
        for _ in 0..<200 {
            if entry.composition.store.snapshot.delivery != nil && entry.composition.store.snapshot.rows != nil { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertNotNil(entry.composition.store.snapshot.delivery, "The real app-server must complete its handshake")
        XCTAssertNotNil(entry.composition.store.snapshot.rows, "The real app-server must deliver a synthetic snapshot")
        let image = try XCTUnwrap(CommunityMenuBarResources.templateImage(appURL: bundle))
        return (entry, image)
    }

    func testG3_07RealEnginePackagedGlyphPreflight() async throws {
        let (entry, image) = try await realStatusPreflight()
        XCTAssertTrue(image.isTemplate)
        XCTAssertNotNil(entry.composition.client)
        // Actual status-item contour and ring absence require an approved
        // reference and a GUI reservation; detached asset evidence is not G3.
    }

    func testG3_08RealEnginePackagedGlyphPreflight() async throws {
        let (entry, image) = try await realStatusPreflight()
        XCTAssertTrue(image.isTemplate)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        XCTAssertNotNil(entry.composition.client)
        // Nominal image dimensions do not establish visible extent, alignment,
        // actual status-item display, or 1x/2x and appearance comparisons.
    }

    private func app(language: String = "en") async throws -> EngineDockMenuApplication {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g3-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [language])
        _ = try await settings.update { preferences in
            preferences.autoHide = false
            for _ in 0..<16 { preferences.onboarding.next() }
        }
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), cockpitEntryEnabled: false,
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            makeClient: { _, target in G3SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in G3NoWindowSurface() }, activateSettings: {})
        entry.makeFirstRunSurface = { _ in G3NoWindowSurface() }
        entry.makeFirstRunSurfaceWithConsent = { _, _ in G3NoWindowSurface() }
        addTeardownBlock { @MainActor in await entry.stopLifecycle(); entry.composition.dock.close() }
        await entry.prepare()
        entry.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 {
            if !entry.lifecyclePaused { return entry }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Synthetic entry did not become ready")
        return entry
    }

    func testG3_04DisabledIgnitionIsUnavailableAndShapeClipped() async throws {
        let entry = try await app()
        let container = try XCTUnwrap(entry.composition.dock.dockView.superview)
        let button = try XCTUnwrap(container.subviews.compactMap { $0 as? NSButton }.first)
        let veil = try XCTUnwrap(container.subviews.first { $0 !== button && $0.frame == button.frame && $0.layer?.backgroundColor != nil })
        let layer = try XCTUnwrap(veil.layer)
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(layer.masksToBounds)
        XCTAssertEqual(layer.cornerRadius, min(veil.bounds.width, veil.bounds.height) / 2, accuracy: 0.01)
    }

    func testG3_07StatusMenuRetainsTemplateWhenTitleChanges() async throws {
        let entry = try await app()
        let button = NSButton()
        let image = try XCTUnwrap(CommunityMenuBarResources.templateImage())
        EngineDockMenuApplication.configureStatusButton(button, image: image, barThickness: 24)
        entry.applyStatusContent(to: button, detail: "synthetic")
        XCTAssertTrue(try XCTUnwrap(button.image).isTemplate)
        let before = button.image
        entry.applyStatusContent(to: button, detail: "updated")
        XCTAssertTrue(button.image === before)
        XCTAssertEqual(button.title, entry.composition.menuPresentation.title)
    }

    func testG3_08StatusItemRespectsAvailableBarSize() async throws {
        let entry = try await app()
        let button = NSButton()
        let image = try XCTUnwrap(CommunityMenuBarResources.templateImage())
        EngineDockMenuApplication.configureStatusButton(button, image: image, barThickness: 12)
        entry.applyStatusContent(to: button, detail: "synthetic")
        let displayed = try XCTUnwrap(button.image)
        XCTAssertTrue(displayed.isTemplate)
        XCTAssertLessThanOrEqual(displayed.size.width, 12)
        XCTAssertLessThanOrEqual(displayed.size.height, 12)
        XCTAssertEqual(button.title, entry.composition.menuPresentation.title)
    }

    func testG3_10RingHelpOnlyOffersAvailableRefresh() async throws {
        let entry = try await app()
        let anchor = DockRequestedHelpAnchor(id: "nozzle", region: .nozzle, rect: CGRect(x: 400, y: 300, width: 40, height: 40), visible: true)
        XCTAssertFalse(entry.composition.dock.ringRefreshAvailable)
        let recipe = NeutralHelpUIRecipeProvider()
        let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(), viewport: CGSize(width: 1000, height: 800), language: .english, anchors: [anchor], blocked: [], recipe: recipe, refreshAvailable: entry.composition.dock.ringRefreshAvailable))
        let label = try XCTUnwrap(recipe.presentation(for: input).mapLabels.first { $0.anchorID == "nozzle" })
        XCTAssertFalse(label.text.contains("click to refresh"))
    }

    func testG3_11WidgetHasDistinctMoveAndRingInteractions() async throws {
        let entry = try await app()
        let view = entry.composition.dock.dockView
        XCTAssertNotNil(view.nozzleEventDelegate)
        XCTAssertNotNil(view.backgroundDragDelegate, "The displayed widget must register a separate move handler")
        let menu = entry.composition.dock.menu()
        XCTAssertTrue(menu.items.contains { $0.title == "Hide Quota Widget" })
        XCTAssertFalse(entry.composition.dock.ringRefreshAvailable)
    }

    func testG3_12HelpMenuReportsUnavailableWithoutSurfaceInBothLanguages() async throws {
        for (language, title, failure) in [("en", "Help…", "Help unavailable. Try again when the Quota Widget is visible."), ("zh-CN", "说明…", "说明暂不可用，请在额度挂件可见时重试。")] {
            let entry = try await app(language: language)
            let item = try XCTUnwrap(entry.liveStatusMenu?.items.first { $0.title == title })
            XCTAssertTrue(item.isEnabled)
            _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
            XCTAssertTrue(entry.liveStatusMenu?.items.contains { $0.title == failure } == true)
            let recipe = NeutralHelpUIRecipeProvider()
            let anchor = DockRequestedHelpAnchor(id: "ring", region: .rings,
                rect: CGRect(x: 400, y: 300, width: 40, height: 40), visible: true)
            let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: UUID(),
                viewport: CGSize(width: 1000, height: 800), language: language == "en" ? .english : .chinese,
                anchors: [anchor], blocked: [], recipe: recipe))
            var shown: HelpUIPresentation?
            let map = RequestedHelpMap(apply: { value, _, _, _ in
                let result = recipe.presentation(for: value)
                if value.map.mode == .latched { shown = result }
                return result
            }, isCurrent: { $0.sessionID == input.sessionID })
            entry.requestHelpMap = { (try? map.presentHelpMap(input: input, content: [:], context: .init())) == true }
            let retry = try XCTUnwrap(entry.liveStatusMenu?.items.first { $0.title == title })
            _ = try XCTUnwrap(retry.target as? NSObject).perform(try XCTUnwrap(retry.action), with: retry)
            XCTAssertTrue(try XCTUnwrap(shown).mapLabels.contains { $0.anchorID == "ring" })
            XCTAssertFalse(entry.liveStatusMenu?.items.contains { $0.title == failure } == true)
            XCTAssertTrue(try map.handleHelpAction(.dismissMap(reason: .escape, returnFocusID: nil)))
        }
    }
}
