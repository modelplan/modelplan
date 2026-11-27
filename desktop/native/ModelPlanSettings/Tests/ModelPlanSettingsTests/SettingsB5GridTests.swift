// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// D371 (B5): the Subscriptions page is one column grid, and the Quota Widget page has one control column.
/// SET-9-13 (order: buttons, grip, keyboard), SET-9-16 (display switch), SET-9-29 (unavailable settings are not listed),
/// CKP-PLG-54 (Settings > Plugins), SET-9-51 (three sections). Each test fails on the layout before D371: the controls
/// followed the name and the fix button, the alias was a separate block, the plugins sat under the read paths.
@MainActor final class SettingsB5GridTests: XCTestCase {
    private func all(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(all) }
    private func find<T: NSView>(_ root: NSView, _ id: String, _ type: T.Type) -> T? {
        all(root).first { $0.accessibilityIdentifier() == id } as? T
    }
    private func texts(_ root: NSView) -> [String] { all(root).compactMap { ($0 as? NSTextField)?.stringValue } }
    private func rect(_ view: NSView, in root: NSView) -> NSRect { view.convert(view.bounds, to: root) }

    private func controller() throws -> ScopeConsentController {
        let commands = EngineClientScopeConsentCommands(client: ScopeConsentTestClient(), ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let value = ScopeConsentController(commands: commands)
        value.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        return value
    }
    private func subs() -> [SettingsSubscription] {
        [SettingsSubscription(id: "a", name: .init("Codex", "Codex"), plan: "Pro 100", vendor: "openai", source: .fresh),
         SettingsSubscription(id: "u", name: .init("ZCode / GLM", "ZCode / GLM"), vendor: "glm", source: .fresh, isUnstable: true),
         SettingsSubscription(id: "b", name: .init("Kiro", "Kiro"), vendor: "kiro", source: .fresh)]
    }
    private func page(language: SettingsLanguage = .chinese, aliasField: Bool = true,
                      moves: ((String, Int) -> Void)? = nil) throws -> SettingsScopeConsentView {
        let view = SettingsScopeConsentView(controller: try controller(), language: language, compactTools: true)
        if let moves { view.rowActions.move = { id, delta in moves(id, delta) } }
        if aliasField {
            view.rowActions.aliasField = { id in
                let field = SettingsAliasControl(subscriptionID: id)
                field.translatesAutoresizingMaskIntoConstraints = false
                field.widthAnchor.constraint(equalToConstant: SettingsGrid.alias).isActive = true
                return field
            }
        }
        view.frame = NSRect(x: 0, y: 0, width: 760, height: 1400)
        view.setSubscriptionRows(SubscriptionRowsContext(subscriptions: subs(), orderedIDs: ["a", "u", "b"], hiddenIDs: ["b"], canSave: true))
        view.layoutSubtreeIfNeeded()
        return view
    }

    /// Points 1, 2 and 3: a switch (not a checkbox), and the same x for every control in every row, Cursor and Grok included.
    func testEveryRowHasTheSameControlColumns() throws {
        let view = try page()
        let ids = ["a", "u", "b"]
        for column in ["visible", "drag", "up", "down"] {
            let xs = try ids.map { id -> CGFloat in
                rect(try XCTUnwrap(find(view, "subscriptions.\(column).\(id)", NSView.self), "\(column).\(id)"), in: view).minX
            }
            XCTAssertEqual(Set(xs.map { Int($0.rounded()) }).count, 1, "\(column) is on one vertical line in every row: \(xs)")
        }
        let first = try XCTUnwrap(find(view, "subscriptions.visible.a", NSButton.self))
        XCTAssertTrue(first is ConnectionSwitchButton, "a painted switch, not the checkbox the .switch button type draws")
        XCTAssertEqual(first.accessibilityRole(), .checkBox)
        XCTAssertEqual(rect(first, in: view).width, SettingsGrid.toggle, accuracy: 1)
        XCTAssertEqual(first.state, .on); XCTAssertEqual(try XCTUnwrap(find(view, "subscriptions.visible.b", NSButton.self)).state, .off, "hidden keeps its switch, off")
        // Order: grip, up, down are 22 / 26 / 26 wide and in that order.
        let grip = rect(try XCTUnwrap(find(view, "subscriptions.drag.a", NSView.self)), in: view)
        let up = rect(try XCTUnwrap(find(view, "subscriptions.up.a", NSView.self)), in: view)
        let down = rect(try XCTUnwrap(find(view, "subscriptions.down.a", NSView.self)), in: view)
        XCTAssertLessThan(grip.maxX, up.minX); XCTAssertLessThan(up.maxX, down.minX)
        XCTAssertEqual(up.width, SettingsGrid.step, accuracy: 1)
        XCTAssertEqual(down.maxX, view.bounds.maxX, accuracy: 2, "the last column ends on the page's right edge")
    }

    /// Point 3: Cursor and Grok Build (reading by default, no account yet) get the same controls, switched off.
    func testAPendingRowHasTheSameControlsDisabled() throws {
        let pending = SubscriptionRow(id: "cursor", tool: "cursor", name: .init("Cursor", "Cursor"), plan: "", section: .added, consent: nil, state: nil,
                                      causeCode: nil, visible: true, position: nil, addedCount: 0, status: .init("Reading…", "正在读取…"),
                                      needsAttention: false, fix: nil, canAdd: false)
        let model = SubscriptionRowModel(added: [pending], detected: [], notInstalled: [])
        let view = SubscriptionRowsView(.init(model: model, language: .chinese, mark: { _ in NSView() }, toolName: { _ in .init("", "") },
            lockedReason: { _ in nil }, canMutate: true, canSave: true, canResetOrder: false, fixAvailable: { _ in true },
            notInstalledExpanded: false, notices: [:], handlers: .init(), highlightedID: nil))
        view.frame = NSRect(x: 0, y: 0, width: 760, height: 300); view.layoutSubtreeIfNeeded()
        for id in ["visible", "drag", "up", "down"] {
            let control = try XCTUnwrap(find(view, "subscriptions.\(id).cursor", NSView.self), "a pending row has \(id)")
            if let button = control as? NSButton { XCTAssertFalse(button.isEnabled, "\(id) cannot change a subscription that does not exist yet") }
        }
        let alias = try XCTUnwrap(find(view, "subscriptions.alias.locked.cursor", NSTextField.self))
        XCTAssertFalse(alias.isEnabled)
    }

    /// Point 6: the alias is a 132 pt field in the row; an unverified account gets a disabled field saying "验证后可改".
    func testAliasIsAFieldInTheRowAndUnverifiedIsDisabledWithItsPlaceholder() throws {
        let view = try page()
        XCTAssertFalse(texts(view).contains("订阅别名"), "no separate alias block")
        let field = try XCTUnwrap(find(view, "settings.alias.a", SettingsAliasControl.self))
        XCTAssertEqual(rect(field, in: view).width, SettingsGrid.alias, accuracy: 1)
        let row = try XCTUnwrap(find(view, "subscriptions.row.a", NSView.self))
        XCTAssertTrue(field.isDescendant(of: row), "the alias sits in its own row")
        let locked = try XCTUnwrap(find(view, "subscriptions.alias.locked.u", NSTextField.self))
        XCTAssertFalse(locked.isEnabled)
        XCTAssertEqual(locked.placeholderString, "验证后可改")
        XCTAssertEqual(locked.toolTip, "验证账号后才能保存")
        XCTAssertEqual(rect(locked, in: view).minX, rect(field, in: view).minX, accuracy: 1, "same column as an editable alias")
    }

    /// Point 4 (D202): a fix is a word in the status line, not a button between the name and the controls.
    func testFixActionIsALinkInTheStatusLine() throws {
        let model = SubscriptionRowModel.build(
            subscriptions: [SettingsSubscription(id: "kiro", name: .init("Kiro", "Kiro"), vendor: "kiro", source: .unavailable, causeCode: "runtime_missing")],
            orderedIDs: ["kiro"], hiddenIDs: [], tools: [], facts: [:], isReading: { _ in false }, name: { .init($0, $0) })
        let view = SubscriptionRowsView(.init(model: model, language: .chinese, mark: { _ in NSView() }, toolName: { _ in .init("", "") },
            lockedReason: { _ in nil }, canMutate: true, canSave: true, canResetOrder: false, fixAvailable: { _ in true },
            notInstalledExpanded: false, notices: [:], handlers: .init(), highlightedID: nil))
        view.frame = NSRect(x: 0, y: 0, width: 760, height: 300); view.layoutSubtreeIfNeeded()
        let fix = try XCTUnwrap(find(view, "subscriptions.fix.kiro", NSButton.self))
        let status = try XCTUnwrap(find(view, "subscriptions.status.kiro", NSTextField.self))
        XCTAssertFalse(fix.isBordered, "a word, not a button")
        XCTAssertTrue(fix.superview === status.superview, "in the status line, beside the reason")
        XCTAssertGreaterThan(rect(fix, in: view).minX, rect(status, in: view).minX)
        let switchRect = rect(try XCTUnwrap(find(view, "subscriptions.visible.kiro", NSView.self)), in: view)
        XCTAssertLessThan(rect(fix, in: view).maxX, switchRect.minX, "the fix never pushes the controls")
    }

    /// Points 5 and 2: the keyboard hint, and ⌥↓ / ⌥↑ on a selected row moves it like the arrows.
    func testKeyboardHintAndOptionArrowsMoveTheSelectedRow() throws {
        var moves: [String] = []
        let view = try page(moves: { moves.append("\($0):\($1)") })
        XCTAssertTrue(texts(view).contains("键盘：选中一行，⌥↑ / ⌥↓ 移动；也可用 ↑ ↓ 按钮。"))
        let row = try XCTUnwrap(find(view, "subscriptions.row.a", SubscriptionDropRow.self))
        XCTAssertTrue(row.acceptsFirstResponder, "a reorderable row can be selected")
        func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                                           characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
        }
        row.keyDown(with: try key(125, [.option]))
        XCTAssertEqual(moves, ["a:1"])
        row.keyDown(with: try key(125, []))
        XCTAssertEqual(moves, ["a:1"], "a plain arrow does nothing")
        let last = try XCTUnwrap(find(view, "subscriptions.row.b", SubscriptionDropRow.self))
        last.keyDown(with: try key(125, [.option]))
        XCTAssertEqual(moves, ["a:1"], "the last verified row cannot go down")
        let pending = try XCTUnwrap(find(view, "subscriptions.row.u", SubscriptionDropRow.self))
        XCTAssertFalse(pending.acceptsFirstResponder, "an unverified row cannot be reordered")
    }

    /// Points 9 and 10, plus 11 and 12, with D376: the plugins have their own pane (no longer inside the Subscriptions
    /// surface) but keep the subscription rows' grid when both span the window's column; the read access rows are rows
    /// with their buttons on the right and a line between rows.
    func testPluginsKeepTheSubscriptionGridOnTheirOwnPaneAndReadAccessAreRows() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("b5-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = CockpitPluginSettingsModel(store: CockpitPluginStore(directory: directory))
        let plugins = SettingsCockpitPluginsView(model: model, language: .chinese)
        plugins.apply(language: .chinese, paneID: "plugins", query: "")
        let view = try page()
        XCTAssertFalse(all(view).contains { $0 === plugins }, "D376: the Subscriptions surface no longer holds the plugins")
        XCTAssertNil(find(view, "settings.cockpitPlugins.resources.enabled", NSView.self))
        XCTAssertNil(find(plugins, "settings.cockpitPlugins.calendar.enabled", NSView.self), "D466: the 日历 is a fixed tab, not a plugin row")
        // The window's content column: both views take its full width.
        let column = NSStackView(views: [view, plugins])
        column.orientation = .vertical; column.alignment = .leading; column.spacing = 0
        column.frame = NSRect(x: 0, y: 0, width: 760, height: 2000)
        for child in [view, plugins] { child.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true }
        column.layoutSubtreeIfNeeded()
        let order = view.arrangedSubviews
        let readIndex = try XCTUnwrap(order.firstIndex { $0.accessibilityIdentifier() == "scope.row.permissions" })
        // Same grid: a plugin's switch, grip and arrows are on the subscription rows' x lines.
        for (plugin, subscription) in [("enabled", "visible"), ("up", "up"), ("down", "down")] {
            let p = rect(try XCTUnwrap(find(plugins, "settings.cockpitPlugins.resources.\(plugin)", NSView.self)), in: column).minX
            let s = rect(try XCTUnwrap(find(view, "subscriptions.\(subscription).a", NSView.self)), in: column).minX
            XCTAssertEqual(p, s, accuracy: 1, "plugin \(plugin) shares the subscription \(subscription) column")
        }
        // The pin switch sits in the sub-row, off by default, in the same switch column.
        let pin = try XCTUnwrap(find(plugins, "settings.cockpitPlugins.resources.pinned", NSButton.self))
        XCTAssertEqual(pin.state, .off, "pinning is off by default")
        XCTAssertEqual(pin.title, "固定到驾驶舱第 1 页")
        XCTAssertEqual(rect(pin, in: column).minX, rect(try XCTUnwrap(find(plugins, "settings.cockpitPlugins.resources.enabled", NSView.self)), in: column).minX, accuracy: 1)
        // D376: the resource sampling note starts at the sub-row's 38 pt indent, under the options line.
        let sampling = try XCTUnwrap(find(plugins, "settings.cockpitPlugins.resources.samplingNote", NSTextField.self))
        let row = try XCTUnwrap(find(plugins, "settings.cockpitPlugins.resources", NSStackView.self))
        // Measured on the label's alignment rect: a stack view places a label's text edge, and its frame overhangs that
        // edge by the label's alignment inset (2 pt).
        XCTAssertEqual(rect(sampling, in: column).minX + sampling.alignmentRectInsets.left - rect(row, in: column).minX,
                       SettingsGrid.mark + SettingsGrid.gap, accuracy: 1)
        XCTAssertEqual(row.arrangedSubviews.suffix(2).map { $0.accessibilityIdentifier() },
                       ["settings.cockpitPlugins.resources.options", "settings.cockpitPlugins.resources.samplingLine"], "directly under the options line")
        // Reading permissions: name and note left, the buttons right of them.
        let readRow = order[readIndex]
        let note = try XCTUnwrap(all(readRow).compactMap { $0 as? NSTextField }.first { $0.stringValue == "读取权限" })
        let inspect = try XCTUnwrap(find(view, "scope.inspect", NSButton.self))
        XCTAssertTrue(inspect.isDescendant(of: readRow))
        XCTAssertGreaterThan(rect(inspect, in: view).minX, rect(note, in: view).maxX - 1)
        let installCodex = try XCTUnwrap(find(view, "scope.plugin.codex", NSButton.self))
        XCTAssertEqual(installCodex.title, "安装…")
        XCTAssertTrue(order.contains { $0 is NSBox }, "thin lines between the rows")
    }

    /// Point 8: the "Supported, not installed (N)" disclosure sits under "Detected, not added yet".
    func testSupportedNotInstalledDisclosureFollowsDetected() throws {
        let model = SubscriptionRowModel.build(
            subscriptions: [], orderedIDs: [], hiddenIDs: [],
            tools: [FirstRunTool(tool: "cursor", scopes: ["cursor.local"], routes: [], block: nil, promptsKeychain: false, detected: true),
                    FirstRunTool(tool: "kiro", scopes: [], routes: [], block: nil, promptsKeychain: false, detected: false),
                    FirstRunTool(tool: "amp", scopes: [], routes: [], block: nil, promptsKeychain: false, detected: false)],
            facts: [:], isReading: { _ in false }, name: { .init($0.capitalized, $0.capitalized) })
        let view = SubscriptionRowsView(.init(model: model, language: .chinese, mark: { _ in NSView() }, toolName: { _ in .init("", "") },
            lockedReason: { _ in nil }, canMutate: true, canSave: true, canResetOrder: false, fixAvailable: { _ in true },
            notInstalledExpanded: false, notices: [:], handlers: .init(), highlightedID: nil))
        view.frame = NSRect(x: 0, y: 0, width: 760, height: 500); view.layoutSubtreeIfNeeded()
        let toggle = try XCTUnwrap(find(view, "subscriptions.notInstalled.toggle", NSButton.self))
        XCTAssertEqual(toggle.title, "受支持，未安装（2）")
        let add = try XCTUnwrap(find(view, "subscriptions.add.cursor", NSButton.self))
        // Point 7: Add is on the right edge, on the control column's right edge.
        XCTAssertEqual(rect(add, in: view).maxX, view.bounds.maxX, accuracy: 2)
    }

    /// Quota Widget page: every dropdown is 150 pt in the 230 pt control column; the percentage window is a list of
    /// indented per-subscription lines whose dropdowns end on that column's right edge; the little picture sits under the
    /// text, not in the control column.
    func testWidgetRowsUseOneControlColumnAndIndentedSubscriptionLines() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("b5-widget-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("settings.json"))
        let snapshot = await store.snapshot()
        let row = SettingsNativeRow(key: .percentagePin)
        var context = SettingsPageContext()
        context.subscriptions = [.init(id: "a", name: .init("Codex", "Codex")), .init(id: "b", name: .init("Kiro", "Kiro"))]
        let item = try XCTUnwrap(SettingsCatalogue.rows(preferences: snapshot.preferences, context: context, paneID: "dock").first { $0.key == .percentagePin })
        row.apply(item, language: .chinese, saving: false, input: nil, reduced: true, onChoice: #selector(NSApplication.terminate(_:)),
                  target: NSApplication.shared, snapshot: snapshot, context: context, holdAvailable: false, hasHost: false, onEdit: { _, _ in }, onSurfaceAction: { _, _ in }, onDraftCleared: { _ in })
        row.frame = NSRect(x: 0, y: 0, width: 760, height: 400); row.layoutSubtreeIfNeeded()
        XCTAssertEqual(SettingsNativeRow.dropdownWidth, 150)
        XCTAssertEqual(Set(row.choices.values.map { rect($0, in: row).width.rounded() }), [150])
        XCTAssertTrue(row.subList.arrangedSubviews.count == 2 && !row.subList.isHidden, "one indented line per subscription")
        XCTAssertTrue(row.controls.arrangedSubviews.isEmpty, "the dropdowns are not stacked in the control column")
        let edges = row.choices.values.map { rect($0, in: row).maxX }
        XCTAssertEqual(Set(edges.map { $0.rounded() }).count, 1, "dropdowns end on one right edge")
        XCTAssertEqual(edges[0], row.bounds.maxX - 8, accuracy: 2, "that edge is the control column's right edge")
        for line in row.subList.arrangedSubviews { XCTAssertGreaterThan((line as? NSStackView)?.edgeInsets.left ?? 0, 0, "indented") }
    }
}
