// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
@testable import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

// Only the engine is synthetic. First run and Settings use the production entry.
private actor G1SettingsEngine: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g1-settings", floor: .init(storeEpoch: "g1-settings", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-settings-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// Window journeys are compiled locally; execution requires an admitted GUI CI runner.
@MainActor final class G1SettingsJourneys: XCTestCase {
    private func entry(locale: String, discoveredMembers: Int? = nil, profileURL: URL? = nil,
                       startsComposition: Bool = true) async throws -> EngineDockMenuApplication {
        let profile = profileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("g1-settings-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        if let discoveredMembers {
            var projection = try XCTUnwrap(root["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            var row = try XCTUnwrap(rows.first)
            let template = try XCTUnwrap((row["accounts"] as? [[String: Any]])?.first)
            row["name"] = ["en": "Synthetic tool", "zh": "合成工具"]
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu", "settings"]
            row["expiresAt"] = "2099-01-01T00:00:00Z"
            row["accounts"] = (0..<discoveredMembers).map { index -> [String: Any] in
                var account = template
                account["subscriptionRef"] = String(repeating: String(index + 1), count: 16)
                account["valueState"] = "current"; account["freshUntil"] = "2099-01-01T00:00:00Z"
                return account
            }
            rows = discoveredMembers == 0 ? [] : [row]
            projection["rows"] = rows; root["projection"] = projection
        }
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), makeClient: { _, target in G1SettingsEngine(store: target, rows: rows) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        if startsComposition { await app.composition.start() }
        return app
    }
    private func flatten(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(flatten) }
    private func firstRun(_ app: EngineDockMenuApplication) async throws -> NSWindow {
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.restoreFirstRunIfNeeded()
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        addTeardownBlock { @MainActor in window.close() }
        return window
    }
    private func control<T: NSView>(_ id: String, in window: NSWindow, as type: T.Type) throws -> T {
        let root = try XCTUnwrap(window.contentView)
        return try XCTUnwrap(flatten(root).first { $0.accessibilityIdentifier() == id } as? T, "Missing \(id)")
    }
    private func settings(_ app: EngineDockMenuApplication, pane: String) async throws -> NSWindow {
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: pane, origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        addTeardownBlock { @MainActor in window.close() }
        return window
    }
    private func assertControls(_ ids: [String], in window: NSWindow) throws {
        let views = flatten(try XCTUnwrap(window.contentView))
        for id in ids { XCTAssertNotNil(views.first { $0.accessibilityIdentifier() == id }, "Missing \(id)") }
    }
    private func assertLabel(_ text: String, in window: NSWindow) throws {
        let fields = flatten(try XCTUnwrap(window.contentView)).compactMap { $0 as? NSTextField }
        XCTAssertTrue(fields.contains { !$0.isHiddenOrHasHiddenAncestor && $0.stringValue == text }, "Missing \(text)")
    }
    /// One explicit choice through the real window controller, then wait until that controller has
    /// finished the whole transaction (store commit, observer acknowledgments, UI refresh). A store
    /// receipt alone is not enough: the editor stays busy until every commit observer acknowledges.
    private func choose(_ id: String, value: String, in window: NSWindow) async throws {
        let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
        let popup = try control(id, in: window, as: NSPopUpButton.self)
        XCTAssertTrue(popup.isEnabled, "\(id) must accept the explicit choice")
        let item = try XCTUnwrap(popup.itemArray.first { ($0.representedObject as? String) == value })
        popup.select(item)
        XCTAssertTrue(popup.sendAction(popup.action, to: popup.target))
        await controller.waitForPendingSave()
        XCTAssertFalse(controller.editor.isSaving, "\(id) must settle before the next edit")
    }
    /// A slow app consumer: the store commit lands before the UI may accept the next edit.
    @MainActor private final class Acknowledgments { var count = 0 }
    private func delayAcknowledgments(_ app: EngineDockMenuApplication) -> @MainActor () -> Int {
        let acknowledged = Acknowledgments()
        let editor = app.settingsHost.application.editor
        let id = editor.observeCommittedEdits { _ in
            try? await Task.sleep(for: .milliseconds(150)); acknowledged.count += 1
        }
        addTeardownBlock { @MainActor in editor.removeCommitObserver(id) }
        return { acknowledged.count }
    }
    func testG1_FR_9_02_FirstRunPrivacyText() async throws {
        for (locale, expected) in [("en-US", "Nothing on this Mac is uploaded; only public data is downloaded"), ("zh-CN", "不上传任何本机数据，只下载公开数据")] {
            let app = try await entry(locale: locale)
            let window = try await firstRun(app)
            let privacy = try control("firstRun.privacy", in: window, as: NSTextField.self)
            XCTAssertEqual(privacy.stringValue, expected)
            XCTAssertFalse(privacy.isHiddenOrHasHiddenAncestor)
            XCTAssertEqual(privacy.accessibilityValue() ?? privacy.accessibilityLabel(), expected)
        }
    }

    func testG1_FR_9_03_PublicRecommendationFollowsPrivacy() async throws {
        for locale in ["en-US", "zh-CN"] {
            let app = try await entry(locale: locale)
            let window = try await firstRun(app)
            let privacy = try control("firstRun.privacy", in: window, as: NSTextField.self)
            let line = try control("firstRun.publicRecommendation", in: window, as: NSTextField.self)
            XCTAssertFalse(line.isHiddenOrHasHiddenAncestor)
            XCTAssertEqual(line.stringValue, locale.hasPrefix("zh") ? "推荐用的是 ModelPlan 公开发布的模型数据，不会上传你的使用记录。" : "Recommendations use ModelPlan's published model data; your usage never leaves this Mac.")
            let privacyFrame = privacy.convert(privacy.bounds, to: nil)
            let recommendationFrame = line.convert(line.bounds, to: nil)
            XCTAssertLessThan(recommendationFrame.midY, privacyFrame.midY)
        }
    }

    func testG1_FR_9_06_LoginChoiceDefaultAndCompletion() async throws {
        for enabled in [true, false] {
            let app = try await entry(locale: "en-US")
            let window = try await firstRun(app)
            let login = try control("firstRun.login", in: window, as: NSButton.self)
            let done = try control("firstRun.done", in: window, as: NSButton.self)
            XCTAssertEqual(login.state, .on)
            XCTAssertEqual(login.accessibilityHelp(), "You can turn this off in Settings")
            XCTAssertGreaterThan(login.convert(login.bounds, to: nil).midY, done.convert(done.bounds, to: nil).midY)
            if !enabled { XCTAssertTrue(login.isEnabled); login.performClick(nil) }
            XCTAssertTrue(done.isEnabled); done.performClick(nil)
            var saved = await app.foundationStore.snapshot()
            for _ in 0..<1000 where !saved.preferences.onboarding.completed {
                await Task.yield(); saved = await app.foundationStore.snapshot()
            }
            XCTAssertTrue(saved.preferences.onboarding.completed)
            XCTAssertEqual(saved.preferences.openAtLogin, enabled)
        }
    }

    // G3-24 (owner ledger): on a fresh profile the first-run sheet appears by itself on the normal launch
    // path, and never again once onboarding is complete. Nothing here calls restoreFirstRunIfNeeded():
    // the lifecycle's ready step does (EngineDockMenuApplication.startLifecycle onReady), exactly as
    // applicationDidFinishLaunching starts it; only the OS signal sources are synthetic.
    private func launch(_ app: EngineDockMenuApplication) {
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(),
                           displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
    }
    private func firstRunWindow(after before: Set<ObjectIdentifier>, seconds: Double) async throws -> NSWindow? {
        let end = ContinuousClock.now + .seconds(seconds)
        repeat {
            if let window = NSApplication.shared.windows.first(where: { window in
                !before.contains(ObjectIdentifier(window)) && window.isVisible &&
                    (window.contentView.map { flatten($0).contains { $0.accessibilityIdentifier() == "firstRun.done" } } ?? false)
            }) { return window }
            try await Task.sleep(for: .milliseconds(20))
        } while ContinuousClock.now < end
        return nil
    }
    func testG1_G3_24_FirstRunAppearsOnlyUntilOnboardingCompletes() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-g3-24-" + UUID().uuidString)
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.path), "Precondition: a fresh synthetic profile")
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        let app = try await entry(locale: "en-US", profileURL: profile, startsComposition: false)
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.onboarding.completed, false)
        launch(app)
        let presented = try await firstRunWindow(after: before, seconds: 5)
        let window = try XCTUnwrap(presented, "The normal launch must present the first-run sheet on a fresh profile")
        addTeardownBlock { @MainActor in window.close() }
        XCTAssertFalse(app.lifecyclePaused)
        let done = try control("firstRun.done", in: window, as: NSButton.self)
        XCTAssertTrue(done.isEnabled); done.performClick(nil)
        var saved = await app.foundationStore.snapshot()
        for _ in 0..<1000 where !saved.preferences.onboarding.completed {
            await Task.yield(); saved = await app.foundationStore.snapshot()
        }
        XCTAssertTrue(saved.preferences.onboarding.completed)
        window.close(); await app.stopLifecycle(); await app.composition.stop()

        let relaunchBefore = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        let reopened = try await entry(locale: "en-US", profileURL: profile, startsComposition: false)
        launch(reopened)
        let end = ContinuousClock.now + .seconds(5)
        while reopened.lifecyclePaused && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(reopened.lifecyclePaused, "Precondition: the relaunch reached the ready step that restores first run")
        let again = try await firstRunWindow(after: relaunchBefore, seconds: 1.5)
        XCTAssertNil(again, "A completed profile must not get the first-run sheet again")
        again?.close(); await reopened.stopLifecycle()
    }

    func testG1_SET_9_08_DockSectionHeadings() async throws {
        for (locale, expected) in [
            ("en-US", ["Display", "Numbers", "Position", "Order"]),
            ("zh-CN", ["显示", "数字", "位置", "顺序"])
        ] {
            let app = try await entry(locale: locale)
            let window = try await settings(app, pane: "dock")
            let labels = flatten(try XCTUnwrap(window.contentView)).compactMap { ($0 as? NSTextField)?.stringValue }
            for heading in expected {
                XCTAssertTrue(labels.contains { $0 == heading || $0.hasSuffix(" · " + heading) }, "Missing Dock section \(heading)")
            }
        }
    }

    func testG1_SET_9_03_GeneralLoginChoiceDefaultsOn() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "general")
        let login = try control("settings.login", in: window, as: NSPopUpButton.self)
        XCTAssertEqual(login.selectedItem?.representedObject as? String, "true")
        let saved = await app.foundationStore.snapshot()
        XCTAssertTrue(saved.preferences.openAtLogin)
    }

    func testG1_SET_9_05_GeneralControlsArePresent() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "general")
        let views = flatten(try XCTUnwrap(window.contentView))
        for id in ["settings.language", "settings.menuDisplay", "settings.openShortcut", "settings.dockShortcut", "settings.resetHints"] {
            let view = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == id }, "Missing \(id)")
            XCTAssertFalse(view.isHiddenOrHasHiddenAncestor)
        }
    }

    // SET-9-07 (automatic update checks) and SET-9-20 (manual check) are removed in v1 by D16.
    // The normal entry must not offer any update control, in either language, on any pane.
    func testG1_SET_9_07_D16_NoUpdateControlsInV1() async throws {
        for locale in ["en-US", "zh-CN"] {
            let app = try await entry(locale: locale)
            let window = try await settings(app, pane: "general")
            for pane in SettingsStructure.task65.panes {
                await app.settingsHost.present(paneID: pane.id, origin: .userInitiated)
                let views = flatten(try XCTUnwrap(window.contentView)).filter { !$0.isHiddenOrHasHiddenAncestor }
                for id in ["settings.automaticUpdates", "settings.updateStatus"] {
                    XCTAssertFalse(views.contains { $0.accessibilityIdentifier() == id }, "\(pane.id) offers \(id)")
                }
                let labels = views.compactMap { ($0 as? NSTextField)?.stringValue ?? ($0 as? NSButton)?.title }
                for title in ["Check for updates automatically", "App updates", "自动检查更新", "应用更新"] {
                    XCTAssertFalse(labels.contains(title), "\(pane.id) shows \(title)")
                }
            }
        }
    }

    func testG1_SET_9_19_PrivacyDefaultsAndRetentionLabels() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "privacy")
        let projectNames = try control("settings.projectNames", in: window, as: NSPopUpButton.self)
        XCTAssertEqual(projectNames.selectedItem?.representedObject as? String, "true")
        let saved = await app.foundationStore.snapshot()
        XCTAssertTrue(saved.preferences.showProjectNames)
        let copy = flatten(try XCTUnwrap(window.contentView)).compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
        XCTAssertTrue(copy.contains("35")); XCTAssertTrue(copy.contains("371"))
    }

    // The synthetic bundle has no packaged notices; packaged provenance remains a separate check.
    func testG1_SET_9_22_MissingLicenseBundleIsDisclosed() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "about")
        let views = flatten(try XCTUnwrap(window.contentView))
        let notice = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "settings.licenses.text" } as? NSScrollView)
        let text = try XCTUnwrap(notice.documentView as? NSTextView)
        XCTAssertTrue(text.string.contains("Bundled licence notices could not be loaded"))
        XCTAssertTrue(text.string.contains("ModelPlan"))
    }

    func testG1_SET_9_25_ExcludedSettingsStayAbsent() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "general")
        for pane in SettingsStructure.task65.panes {
            await app.settingsHost.present(paneID: pane.id, origin: .userInitiated)
            let views = flatten(try XCTUnwrap(window.contentView)).filter { !$0.isHiddenOrHasHiddenAncestor }
            let labels = views.compactMap { view -> String? in
                if let text = view as? NSTextField { return text.stringValue }
                if let button = view as? NSButton { return button.title }
                return nil
            }
            XCTAssertFalse(labels.isEmpty, "The visible pane must contain controls or labels")
            let titles = Set(labels.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            for forbidden in ["sign in", "cookies", "api keys", "money estimates", "floating dock", "mascots", "proxy", "refresh interval", "custom identity colour", "column tint"] {
                XCTAssertFalse(titles.contains(forbidden), "Unexpected setting: \(forbidden)")
            }
        }
    }

    func testG1_SET_9_23_DockDiagramsHaveExpectedRolesAndWidth() async throws {
        let app = try await entry(locale: "en-US", discoveredMembers: 2)
        let window = try await settings(app, pane: "dock")
        let diagrams = flatten(try XCTUnwrap(window.contentView)).compactMap { $0 as? SettingsDiagramView }.filter { !$0.isHiddenOrHasHiddenAncestor }
        let roles = diagrams.map { diagram -> String in
            switch diagram.input {
            case .edge: return "edge"
            case .percentages: return "percentages"
            case .autoCollapse: return "autoCollapse"
            case .size: return "size"
            case .quotaWindow: return "quotaWindow"
            }
        }
        XCTAssertEqual(roles.count, 5)
        XCTAssertEqual(Set(roles), Set(["edge", "percentages", "autoCollapse", "size", "quotaWindow"]))
        for diagram in diagrams { XCTAssertEqual(diagram.bounds.width, 96, accuracy: 0.01) }
    }

    func testG1_SET_9_04_NativeLoginItemOperation() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "general")
        try assertControls(["settings.login"], in: window)
        XCTAssertNil(app.loginServiceAdapter, "The synthetic non-app bundle must not register a system login item")
        throw XCTSkip("Native SMAppService operations and denial require a separately admitted system test")
    }

    func testG1_SET_9_06_RealShortcutOperationAndPersistence() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "general")
        try assertControls(["settings.openShortcut", "settings.dockShortcut"], in: window)
        throw XCTSkip("Global shortcut input and resulting host actions require an admitted GUI session")
    }

    func testG1_SET_9_10_DockNumbersAndEventPresentation() async throws {
        let app = try await entry(locale: "en-US", discoveredMembers: 2)
        let window = try await settings(app, pane: "dock")
        try assertControls(["settings.showPercentages", "settings.percentageMode", "settings.redBelow", "settings.sliverAlert"], in: window)
        let acknowledged = delayAcknowledgments(app)
        try await choose("settings.showPercentages", value: "false", in: window)
        var saved = await app.foundationStore.snapshot()
        XCTAssertFalse(saved.preferences.showPercentages)
        XCTAssertEqual(app.composition.dock.currentMenuBarPreferences?.showPercentages, false)
        try await choose("settings.percentageMode", value: "used", in: window)
        saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.percentageMode, .used)
        try await choose("settings.redBelow", value: "15", in: window)
        saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.redBelow, 15)
        XCTAssertEqual(app.composition.dock.currentMenuBarPreferences?.redBelow, 15)
        XCTAssertEqual(acknowledged(), 3, "each chained edit waited for the slow consumer's acknowledgment")
        throw XCTSkip("Actual widget values, event dots, per-member pin and relaunch remain unverified")
    }

    func testG1_SET_9_11_DockPositionAndDisplayBehaviour() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "dock")
        try assertControls(["settings.dockDisplay", "settings.dockEdge", "settings.fullscreen", "settings.activeDisplay"], in: window)
        try assertLabel("Hide from capture", in: window)
        try await choose("settings.dockEdge", value: "left", in: window)
        let saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.dockEdge, .left)
        XCTAssertEqual(app.composition.dock.currentMenuBarPreferences?.dockEdge, .left)
        throw XCTSkip("Multi-display placement and actual fullscreen/capture behaviour require an admitted GUI session")
    }

    func testG1_SET_9_12_CaptureVisibilityPersists() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "dock")
        try assertLabel("Hide from capture", in: window)
        throw XCTSkip("Actual widget sharing state and relaunch require an admitted GUI session")
    }

    func testG1_SET_9_13_SubscriptionOrderChangesAndReset() async throws {
        let app = try await entry(locale: "en-US", discoveredMembers: 3)
        let window = try await settings(app, pane: "dock")
        try assertControls(["settings.order.list"], in: window)
        throw XCTSkip("Three-member drag, arrow actions, engine-column order and relaunch are not yet exercised")
    }

    func testG1_SET_9_15_AppearanceAndAccessibilityApplyLive() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "appearance")
        try assertControls(["settings.motion", "settings.transparency"], in: window)
        let snapshot = await app.foundationStore.snapshot()
        XCTAssertEqual(snapshot.preferences.motion, .system)
        XCTAssertEqual(snapshot.preferences.transparency, .system)
        let acknowledged = delayAcknowledgments(app)
        try await choose("settings.motion", value: "on", in: window)
        var saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.motion, .on)
        try await choose("settings.transparency", value: "on", in: window)
        saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.transparency, .on)
        XCTAssertEqual(acknowledged(), 2, "each chained edit waited for the slow consumer's acknowledgment")
        throw XCTSkip("Theme and accessibility effects on all open surfaces and relaunch remain unverified")
    }

    func testG1_SET_9_18_NotificationKindsDispatch() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "notifications")
        try assertControls(["settings.notificationConsent", "settings.reset"], in: window)
        throw XCTSkip("Notification authorization and matching/nonmatching delivery require an admitted system test")
    }

    func testG1_SET_9_24_SettingsDiagramMotionAndReduceMotion() async throws {
        let app = try await entry(locale: "en-US", discoveredMembers: 2)
        let window = try await settings(app, pane: "dock")
        let diagrams = flatten(try XCTUnwrap(window.contentView)).compactMap { $0 as? SettingsDiagramView }
        XCTAssertFalse(diagrams.isEmpty)
        throw XCTSkip("Actual hover, focus, value-change timing and Reduce Motion require controlled GUI input")
    }

    func testG1_SET_9_27_SettingsPersistAcrossRestart() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-relaunch-" + UUID().uuidString)
        let app = try await entry(locale: "en-US", profileURL: profile)
        let window = try await settings(app, pane: "general")
        try assertControls(["settings.language", "settings.menuDisplay"], in: window)
        try await choose("settings.language", value: "zh-CN", in: window)
        let saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.language, .chinese)
        window.close(); await app.composition.stop()
        let reopened = try await entry(locale: "en-US", profileURL: profile)
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.language, .chinese)
        throw XCTSkip("One actual edit per pane, relaunch and all downstream consumers remain unverified")
    }

    func testG1_SET_9_28_SignedBuildNoticeApplicability() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await settings(app, pane: "about")
        try assertControls(["settings.licenses.text"], in: window)
        throw XCTSkip("Signed/unsigned packaged build comparison requires separately authorized signed artifacts")
    }
}
