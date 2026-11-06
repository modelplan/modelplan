// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
@testable import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

// Only the engine is synthetic. First run and Settings use the production entry.
private actor G3LayoutEngine: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g3-layout", floor: .init(storeEpoch: "g3-layout", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g3-layout-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// G3-25 / G3-26 (owner ledger): the first-run sheet and Settings > Subscriptions must not overlap,
/// clip or misalign. Layout oracle and journeys adapted from #476 (G1 settings journeys), here as
/// regressions without the expected-failure wrapper; #476 can drop its copies of these two journeys.
@MainActor final class G3FirstRunSubscriptionsLayoutTests: XCTestCase {
    private func entry(locale: String, discoveredMembers: Int? = nil, profileURL: URL? = nil) async throws -> EngineDockMenuApplication {
        let profile = profileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("g3-layout-" + UUID().uuidString)
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
        let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), makeClient: { _, target in G3LayoutEngine(store: target, rows: rows) }, activateSettings: {})
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

    func testG3_25_FirstRunLayoutHasNoOverlapClippingOrMisalignment() async throws {
        for locale in ["en-US", "zh-CN"] {
            for members in [0, 2] {
                let app = try await entry(locale: locale, discoveredMembers: members)
                let window = try await firstRun(app)
                let root = try XCTUnwrap(window.contentView)
                let views = flatten(root).filter { $0 is NSControl || $0 is SettingsDiagramView }
                var problems = layoutProblems(in: views, root: root)
                let column = try ["firstRun.title", "firstRun.privacy", "firstRun.subscriptions", "firstRun.login", "firstRun.done"]
                    .map { try control($0, in: window, as: NSView.self) }
                problems += leadingEdgeProblems(column, label: "leading edge")
                // The permissions column shares the page's leading edge and width.
                if let scope = flatten(root).first(where: { $0.accessibilityIdentifier() == "settings.scopeConsent" }), !scope.isHiddenOrHasHiddenAncestor {
                    problems += leadingEdgeProblems([column[0], scope], label: "permissions edge")
                    let title = column[0].convert(column[0].bounds, to: nil), box = scope.convert(scope.bounds, to: nil)
                    if box.width < 560 { problems.append("permissions column is \(box.width) wide, page column is 570 from x=\(title.minX)") }
                    for id in ["scope.diagnostics", "scope.plugin.codex", "scope.plugin.claude"] where flatten(scope).contains(where: { $0.accessibilityIdentifier() == id }) {
                        problems.append("\(id) belongs to Settings, not the first-run page")
                    }
                }
                XCTAssertEqual(problems, [], "G3-25 first-run layout (\(locale), \(members) members)")
                window.close()
            }
        }
    }

    func testG3_26_SubscriptionsPaneLayoutHasNoOverlapClippingOrMisalignment() async throws {
        for locale in ["en-US", "zh-CN"] {
            for members in [0, 3] {
                let app = try await entry(locale: locale, discoveredMembers: members)
                let window = try await settings(app, pane: "subscriptions")
                let root = try XCTUnwrap(window.contentView)
                let rows = flatten(root).compactMap { $0 as? SettingsNativeRow }.filter { !$0.isHiddenOrHasHiddenAncestor }
                XCTAssertFalse(rows.isEmpty, "Subscriptions pane must show rows")
                let scope = flatten(root).filter { $0.accessibilityIdentifier() == "settings.scopeConsent" && !$0.isHiddenOrHasHiddenAncestor }
                let views: [NSView] = rows.map { $0 as NSView } + rows.flatMap { flatten($0).filter { $0 is NSControl || $0 is SettingsDiagramView } }
                    + scope.flatMap { flatten($0).filter { $0 is NSControl } }
                var problems = layoutProblems(in: views, root: root)
                problems += leadingEdgeProblems(rows, label: "row edge")
                problems += leadingEdgeProblems(rows.map(\.titleLabel), label: "title column")
                problems += leadingEdgeProblems(rows.map(\.controls), label: "control column")
                XCTAssertEqual(problems, [], "G3-26 Subscriptions layout (\(locale), \(members) members)")
                window.close()
            }
        }
    }
}
