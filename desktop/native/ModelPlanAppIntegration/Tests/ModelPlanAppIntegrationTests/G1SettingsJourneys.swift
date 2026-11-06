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
    private func entry(locale: String, discoveredMembers: Int? = nil, profileURL: URL? = nil) async throws -> EngineDockMenuApplication {
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
        await app.prepare(); await app.composition.start()
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
    /// Visible controls and labels that overlap, spill outside their container or cannot show their text.
    private func layoutProblems(in views: [NSView], root: NSView) -> [String] {
        root.layoutSubtreeIfNeeded()
        for case let scroll as NSScrollView in flatten(root) { scroll.documentView?.layoutSubtreeIfNeeded() }
        func name(_ view: NSView) -> String {
            if let row = view as? SettingsNativeRow { return "row " + row.key.rawValue }
            let id = view.accessibilityIdentifier()
            if !id.isEmpty { return id }
            if let field = view as? NSTextField, !field.stringValue.isEmpty { return "label '\(field.stringValue.prefix(40))'" }
            if let button = view as? NSButton, !button.title.isEmpty { return "button '\(button.title.prefix(40))'" }
            return String(describing: type(of: view))
        }
        func container(_ view: NSView) -> NSView {
            var current = view.superview
            while let candidate = current {
                if let scroll = candidate.enclosingScrollView, scroll.documentView === candidate { return candidate }
                current = candidate.superview
            }
            return root
        }
        let shown = views.filter { view in
            !view.isHiddenOrHasHiddenAncestor && view.alphaValue > 0 && view.bounds.width > 0.5 && view.bounds.height > 0.5
                && !(view is NSScroller) && !(view is NSTableView)
                && ((view as? NSTextField).map { !$0.stringValue.isEmpty || $0.isEditable } ?? true)
        }
        var problems: [String] = []
        for view in shown {
            let box = container(view)
            let frame = view.convert(view.bounds, to: box)
            if !box.bounds.insetBy(dx: -0.5, dy: -0.5).contains(frame) { problems.append("\(name(view)) spills outside its container") }
            if let parent = view.superview, !parent.bounds.insetBy(dx: -0.5, dy: -0.5).contains(view.frame) {
                problems.append("\(name(view)) spills outside \(name(parent))")
            }
            if let field = view as? NSTextField, !field.isEditable, let cell = field.cell {
                let needed = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: field.bounds.width, height: .greatestFiniteMagnitude))
                if needed.height > field.bounds.height + 1 { problems.append("\(name(view)) text is cut off vertically") }
                if !cell.wraps, cell.cellSize.width > field.bounds.width + 1 { problems.append("\(name(view)) text is truncated") }
            } else if let button = view as? NSButton, !(view is NSPopUpButton), !button.title.isEmpty,
                      button.intrinsicContentSize.width > button.bounds.width + 1 {
                problems.append("\(name(view)) title is truncated")
            }
        }
        for (index, first) in shown.enumerated() {
            for second in shown[(index + 1)...] where !first.isDescendant(of: second) && !second.isDescendant(of: first) {
                let a = first.convert(first.visibleRect, to: nil), b = second.convert(second.visibleRect, to: nil)
                let overlap = a.intersection(b)
                if !overlap.isNull, overlap.width > 1, overlap.height > 1 { problems.append("\(name(first)) overlaps \(name(second))") }
            }
        }
        return problems
    }
    private func leadingEdgeProblems(_ views: [NSView], label: String) -> [String] {
        let visible = views.filter { !$0.isHiddenOrHasHiddenAncestor }
        guard let reference = visible.first.map({ $0.convert($0.bounds, to: nil).minX }) else { return ["no visible \(label)"] }
        var problems: [String] = []
        for view in visible {
            let x = view.convert(view.bounds, to: nil).minX
            guard abs(x - reference) > 1 else { continue }
            let id = view.accessibilityIdentifier()
            let name = (view as? SettingsNativeRow).map { "row " + $0.key.rawValue } ?? (id.isEmpty ? String(describing: type(of: view)) : id)
            problems.append("\(name) \(label) starts at x=\(x), others at x=\(reference)")
        }
        return problems
    }
    private func nonStrict() -> XCTExpectedFailure.Options {
        let options = XCTExpectedFailure.Options(); options.isStrict = false; return options
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
            XCTAssertEqual(line.stringValue, locale.hasPrefix("zh") ? "推荐基于公开数据。" : "Recommendations use public data.")
            let privacyFrame = privacy.convert(privacy.bounds, to: nil)
            let recommendationFrame = line.convert(line.bounds, to: nil)
            XCTAssertLessThan(recommendationFrame.midY, privacyFrame.midY)
        }
    }

    func testG1_FR_9_04_DiscoveredSubscriptionsAndEmptyState() async throws {
        for count in [0, 2] {
            let app = try await entry(locale: "en-US", discoveredMembers: count)
            let window = try await firstRun(app)
            let subscriptions = try control("firstRun.subscriptions", in: window, as: NSTextField.self)
            XCTAssertFalse(subscriptions.isHiddenOrHasHiddenAncestor)
            if count == 0 { XCTAssertTrue(subscriptions.stringValue.contains("No subscriptions detected")) }
            else {
                XCTAssertTrue(subscriptions.stringValue.contains("Account 1"))
                XCTAssertTrue(subscriptions.stringValue.contains("Account 2"))
            }
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

    // G3-24 (owner ledger): no first-run sheet on first launch of a profile whose onboarding was already
    // completed is expected. The same normal launch restore shows it for a profile that has not completed it.
    func testG1_G3_24_FirstRunAppearsOnlyUntilOnboardingCompletes() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-g3-24-" + UUID().uuidString)
        let app = try await entry(locale: "en-US", profileURL: profile)
        let window = try await firstRun(app)
        let done = try control("firstRun.done", in: window, as: NSButton.self)
        XCTAssertTrue(done.isEnabled); done.performClick(nil)
        var saved = await app.foundationStore.snapshot()
        for _ in 0..<1000 where !saved.preferences.onboarding.completed {
            await Task.yield(); saved = await app.foundationStore.snapshot()
        }
        XCTAssertTrue(saved.preferences.onboarding.completed)
        window.close(); await app.composition.stop()
        let reopened = try await entry(locale: "en-US", profileURL: profile)
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await reopened.restoreFirstRunIfNeeded()
        let shown = NSApplication.shared.windows.filter { !before.contains(ObjectIdentifier($0)) && $0.isVisible }
        XCTAssertEqual(shown.map(\.title), [], "A completed profile must not get the first-run sheet again")
        for extra in shown { extra.close() }
    }

    // G3-25 (owner ledger): the owner reports a messy first-run sheet. Expected failure until fixed; drop
    // the XCTExpectFailure wrapper with the fix so this becomes the regression.
    func testG1_G3_25_FirstRunLayoutHasNoOverlapClippingOrMisalignment() async throws {
        for locale in ["en-US", "zh-CN"] {
            for members in [0, 2] {
                let app = try await entry(locale: locale, discoveredMembers: members)
                let window = try await firstRun(app)
                let root = try XCTUnwrap(window.contentView)
                let views = flatten(root).filter { $0 is NSControl || $0 is SettingsDiagramView }
                var problems = layoutProblems(in: views, root: root)
                let column = try ["firstRun.title", "firstRun.privacy", "firstRun.publicRecommendation", "firstRun.subscriptions", "firstRun.login", "firstRun.done"]
                    .map { try control($0, in: window, as: NSView.self) }
                problems += leadingEdgeProblems(column, label: "leading edge")
                XCTExpectFailure("G3-25: owner-reported messy first-run sheet layout", options: nonStrict()) {
                    XCTAssertEqual(problems, [], "G3-25 first-run layout (\(locale), \(members) members)")
                }
            }
        }
    }

    // G3-26 (owner ledger): the owner reports a messy Settings > Subscriptions pane. Expected failure until
    // fixed; drop the XCTExpectFailure wrapper with the fix so this becomes the regression.
    func testG1_G3_26_SubscriptionsPaneLayoutHasNoOverlapClippingOrMisalignment() async throws {
        for locale in ["en-US", "zh-CN"] {
            for members in [0, 3] {
                let app = try await entry(locale: locale, discoveredMembers: members)
                let window = try await settings(app, pane: "subscriptions")
                let root = try XCTUnwrap(window.contentView)
                let rows = flatten(root).compactMap { $0 as? SettingsNativeRow }.filter { !$0.isHiddenOrHasHiddenAncestor }
                XCTAssertFalse(rows.isEmpty, "Subscriptions pane must show rows")
                let views: [NSView] = rows.map { $0 as NSView } + rows.flatMap { flatten($0).filter { $0 is NSControl || $0 is SettingsDiagramView } }
                var problems = layoutProblems(in: views, root: root)
                problems += leadingEdgeProblems(rows, label: "row edge")
                problems += leadingEdgeProblems(rows.map(\.titleLabel), label: "title column")
                problems += leadingEdgeProblems(rows.map(\.controls), label: "control column")
                XCTExpectFailure("G3-26: owner-reported messy Settings > Subscriptions layout", options: nonStrict()) {
                    XCTAssertEqual(problems, [], "G3-26 Subscriptions layout (\(locale), \(members) members)")
                }
            }
        }
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
        try await choose("settings.redBelow", value: "16", in: window)
        saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.redBelow, 16)
        XCTAssertEqual(app.composition.dock.currentMenuBarPreferences?.redBelow, 16)
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

    func testG1_SET_9_17_OneReaderConsentModel() async throws {
        let app = try await entry(locale: "en-US")
        let window = try await firstRun(app)
        try assertControls(["settings.scopeConsent"], in: window)
        throw XCTSkip("Synthetic engine consent grant/revoke and Settings relaunch are not yet exercised")
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
