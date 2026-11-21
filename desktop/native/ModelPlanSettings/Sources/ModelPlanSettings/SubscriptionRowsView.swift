// SPDX-License-Identifier: MIT
import AppKit

/// D87 slice 6/7 and D371 (B5): the Subscriptions rows. Every row sits on one column grid (`SettingsGrid`): mark, name and
/// status line, alias field, display switch, grip, up, down. The status line carries the fix action as a blue word
/// (D202). Then "Detected, not added yet" with an Add button on the right, then a collapsed "Supported, not installed".
/// It draws a `SubscriptionRowModel` and reports presses to the host; it never grants, revokes or saves anything itself.
@MainActor final class SubscriptionRowsView: NSStackView {
    struct Handlers {
        var setVisible: (String, Bool) -> Void = { _, _ in }
        var move: (String, Int) -> Void = { _, _ in }
        /// A move made with ⌥↑ / ⌥↓ on a selected row (the host puts the keyboard focus back on that row afterwards).
        var keyboardMoved: (String) -> Void = { _ in }
        var resetOrder: () -> Void = {}
        var fix: (SubscriptionRow) -> Void = { _ in }
        var add: (String) -> Void = { _ in }
        var toggleNotInstalled: () -> Void = {}
    }
    struct Configuration {
        var model: SubscriptionRowModel
        var language: SettingsLanguage
        var mark: (String) -> NSView
        var toolName: (String) -> SettingsText
        /// Why a subscription cannot be changed yet (unverified account), nil when it can.
        var lockedReason: (String) -> SettingsText?
        var canMutate: Bool
        var canSave: Bool
        /// A saved order exists, so Reset order is available.
        var canResetOrder: Bool
        /// Whether the app can perform this row's fix action now; false shows the button disabled.
        var fixAvailable: (SubscriptionRow) -> Bool
        var notInstalledExpanded: Bool
        var notices: [String: SettingsText]
        var handlers: Handlers
        /// A row the host wants the user to see (a widget card's reason links here).
        var highlightedID: String?
        /// D90 / SET-9-41: the optional key entry the host mounts under a key-only tool's row (nil: none).
        var keyEntry: (SubscriptionRow) -> NSView? = { _ in nil }
        /// D371: the editable alias field of a verified subscription (the host owns it, so a draft survives a redraw).
        var aliasField: (SubscriptionRow) -> NSView? = { _ in nil }
    }
    /// macrev2-804-4: the added rows that can be reordered, in display order. The host commits a move against the
    /// order of verified subscriptions only, so up, down and drop distances are counted in this same list.
    static func movableOrder(_ model: SubscriptionRowModel, locked: (String) -> Bool) -> [String] {
        model.added.filter { !$0.isPending && !locked($0.id) }.map(\.id)
    }
    /// The distance from `source` to `target` in `order`; nil when either cannot move or they are the same row.
    static func moveDelta(source: String, target: String, in order: [String]) -> Int? {
        guard let from = order.firstIndex(of: source), let to = order.firstIndex(of: target), from != to else { return nil }
        return to - from
    }
    /// D371: what a disabled alias cell says (an unverified account cannot save settings yet).
    static func lockedAliasPlaceholder(_ language: SettingsLanguage) -> String { SettingsWords.text("Verify to edit", "验证后可改", language) }
    static func lockedAliasTip(_ language: SettingsLanguage) -> String {
        SettingsWords.text("Verify the account before saving an alias.", "验证账号后才能保存", language)
    }
    static func keyboardHint(_ language: SettingsLanguage) -> String {
        SettingsWords.text("Keyboard: select a row, then ⌥↑ / ⌥↓ moves it; the ↑ ↓ buttons work too.",
                           "键盘：选中一行，⌥↑ / ⌥↓ 移动；也可用 ↑ ↓ 按钮。", language)
    }

    private(set) var buttons: [ConnectionButton] = []
    private(set) var wrappingLabels: [NSTextField] = []
    private let configuration: Configuration
    private var rowViews: [String: NSView] = [:]

    init(_ configuration: Configuration) {
        self.configuration = configuration
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 8
        setAccessibilityIdentifier("subscriptions.rows")
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    /// Scroll the row into view (after the host showed the pane).
    func scrollToRow(_ id: String) { if let view = rowViews[id] { view.scrollToVisible(view.bounds) } }
    /// Put the keyboard selection back on a row after the host redrew the list (a ⌥↑ / ⌥↓ move rebuilds every row).
    func restoreKeyboardFocus(_ id: String) {
        guard let row = rowViews[id] as? SubscriptionDropRow, row.onKeyMove != nil, let window,
              window.firstResponder === window || window.firstResponder == nil else { return }
        window.makeFirstResponder(row)
    }
    func retire() {
        for button in buttons { button.retire() }
        buttons = []
        for view in arrangedSubviews { removeArrangedSubview(view); view.removeFromSuperview() }
    }
    /// Wrapping labels take the column width so long status lines wrap instead of spilling.
    override func layout() {
        super.layout()
        for label in wrappingLabels {
            let width = label.bounds.width
            if width > 0, abs(label.preferredMaxLayoutWidth - width) > 0.5 { label.preferredMaxLayoutWidth = width; label.invalidateIntrinsicContentSize() }
        }
    }

    private var language: SettingsLanguage { configuration.language }
    private func text(_ value: SettingsText) -> String { value.value(language) }

    private func fullWidth(_ view: NSView) { addArrangedSubview(view); view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true }
    private func heading(_ value: SettingsText, id: String) {
        let field = NSTextField(wrappingLabelWithString: text(value))
        field.font = .systemFont(ofSize: 13, weight: .semibold); field.setAccessibilityIdentifier(id)
        fullWidth(field); wrappingLabels.append(field)
    }
    private func note(_ value: SettingsText, id: String) { noteString(text(value), id: id) }
    private func noteString(_ value: String, id: String) {
        let field = NSTextField(wrappingLabelWithString: value)
        field.font = .systemFont(ofSize: 12); field.textColor = .secondaryLabelColor; field.setAccessibilityIdentifier(id)
        fullWidth(field); wrappingLabels.append(field)
    }
    private func button(_ title: SettingsText, id: String, enabled: Bool, help: SettingsText? = nil,
                        action: @escaping () -> Void) -> ConnectionButton {
        let value = ConnectionButton(title: text(title), identifier: id, invoke: action)
        value.isEnabled = enabled; buttons.append(value)
        if let help, !enabled { value.toolTip = text(help); value.setAccessibilityHelp(text(help)) }
        return value
    }
    private func divider() { fullWidth(SettingsGrid.divider()) }

    /// The small column titles above the first row, on the same widths as the cells below.
    private func columnHeader() {
        let lead = NSView(); lead.translatesAutoresizingMaskIntoConstraints = false
        lead.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let order = SettingsGrid.headerLabel(SettingsWords.text("Order", "顺序", language), width: SettingsGrid.orderColumns, alignment: .center)
        let views: [NSView] = [lead,
            SettingsGrid.headerLabel(SettingsWords.text("Alias", "别名", language), width: SettingsGrid.alias, alignment: .left),
            SettingsGrid.headerLabel(SettingsWords.text("Show", "显示", language), width: SettingsGrid.toggle, alignment: .center), order]
        let line = NSStackView(views: views); line.orientation = .horizontal; line.alignment = .centerY; line.spacing = SettingsGrid.gap
        line.setAccessibilityIdentifier("subscriptions.columns")
        fullWidth(line)
    }

    private func build() {
        let model = configuration.model
        heading(.init("My subscriptions", "我的订阅"), id: "subscriptions.added.heading")
        note(.init("The order sets the Quota Widget rings and the cockpit columns. An alias changes only the displayed name.",
                   "顺序同时决定额度挂件的圈和驾驶舱的列。别名只改显示名。"), id: "subscriptions.added.note")
        if model.added.isEmpty {
            note(.init("Nothing is being read yet. Add a detected tool below.", "目前没有在读取的订阅，可以从下面添加已检测到的工具。"), id: "subscriptions.added.empty")
        } else { columnHeader() }
        for (index, row) in model.added.enumerated() {
            addedRow(row)
            if index < model.added.count - 1 { divider() }
        }
        if model.added.contains(where: { !$0.isPending }) {
            noteString(Self.keyboardHint(language), id: "subscriptions.keyboardHint")
        }
        if model.added.filter({ !$0.isPending }).count > 1 {
            let reset = button(.init("Reset order", "恢复默认顺序"), id: "subscriptions.resetOrder",
                               enabled: configuration.canSave && configuration.canResetOrder) { [handlers = configuration.handlers] in handlers.resetOrder() }
            addArrangedSubview(reset)
        }
        if !model.detected.isEmpty {
            if let last = arrangedSubviews.last { setCustomSpacing(16, after: last) }
            heading(.init("Detected, not added yet", "已检测到，尚未添加"), id: "subscriptions.detected.heading")
            note(.init("ModelPlan reads a tool only after you add it.", "添加之后，ModelPlan 才会读取这个工具。"), id: "subscriptions.detected.note")
            for (index, row) in model.detected.enumerated() {
                detectedRow(row)
                if index < model.detected.count - 1 { divider() }
            }
        }
        if !model.notInstalled.isEmpty {
            if let last = arrangedSubviews.last { setCustomSpacing(16, after: last) }
            let title: SettingsText = configuration.notInstalledExpanded
                ? .init("Hide supported tools that are not installed", "收起未安装的受支持工具")
                : .init("Supported, not installed (\(model.notInstalled.count))", "受支持，未安装（\(model.notInstalled.count)）")
            let toggle = button(title, id: "subscriptions.notInstalled.toggle", enabled: true) { [handlers = configuration.handlers] in handlers.toggleNotInstalled() }
            addArrangedSubview(toggle)
            if configuration.notInstalledExpanded {
                for (index, row) in model.notInstalled.enumerated() {
                    notInstalledRow(row)
                    if index < model.notInstalled.count - 1 { divider() }
                }
            }
        }
    }

    /// One row on the grid. `cells` are the columns after the name: alias, switch, grip, up, down (or an Add button).
    /// The name column takes the free width, so every cell lands on the same vertical line in every row.
    private func rowShell(_ row: SubscriptionRow, prefix: String, fix: ConnectionButton?, cells: [NSView]) -> SubscriptionDropRow {
        let mark = SettingsGrid.cell(configuration.mark(row.tool), width: SettingsGrid.mark)
        let name = NSTextField(labelWithString: text(row.name))
        name.font = .systemFont(ofSize: 14, weight: .semibold); name.setAccessibilityIdentifier(prefix + "name." + row.id)
        name.lineBreakMode = .byTruncatingTail
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        var titleViews: [NSView] = [name]
        if !row.plan.isEmpty {
            let plan = NSTextField(labelWithString: row.plan)
            plan.font = .systemFont(ofSize: 11); plan.textColor = .secondaryLabelColor; plan.setAccessibilityIdentifier(prefix + "plan." + row.id)
            plan.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            titleViews.append(plan)
        }
        let title = NSStackView(views: titleViews); title.orientation = .horizontal; title.alignment = .firstBaseline; title.spacing = 8
        let column = NSStackView(views: [title]); column.orientation = .vertical; column.alignment = .leading; column.spacing = 2
        // The reason in grey (orange when it needs attention), then the fix as a blue word in the same line.
        let status = NSTextField(wrappingLabelWithString: text(row.status))
        status.font = .systemFont(ofSize: SettingsGrid.statusFont); status.textColor = row.needsAttention ? .systemOrange : .secondaryLabelColor
        status.setAccessibilityIdentifier(prefix + "status." + row.id)
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        status.setContentHuggingPriority(.defaultLow, for: .horizontal)
        wrappingLabels.append(status)
        var statusViews: [NSView] = [status]
        if let fix { SettingsGrid.styleAsLink(fix); statusViews.append(fix) }
        let statusLine = NSStackView(views: statusViews); statusLine.orientation = .horizontal; statusLine.alignment = .firstBaseline; statusLine.spacing = 6
        column.addArrangedSubview(statusLine)
        statusLine.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        if let entry = configuration.keyEntry(row) { column.addArrangedSubview(entry) }
        if let notice = configuration.notices[row.id] {
            let field = NSTextField(wrappingLabelWithString: text(notice))
            field.font = .systemFont(ofSize: 11); field.textColor = .systemOrange; field.setAccessibilityIdentifier(prefix + "notice." + row.id)
            column.addArrangedSubview(field); wrappingLabels.append(field)
            field.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        column.setContentHuggingPriority(.defaultLow, for: .horizontal)
        column.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let line = SubscriptionDropRow(frame: .zero)
        for view in [mark, column] + cells { line.addArrangedSubview(view) }
        line.rowID = row.id
        line.orientation = .horizontal; line.alignment = .centerY; line.spacing = SettingsGrid.gap
        line.heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsGrid.rowHeight).isActive = true
        line.setAccessibilityIdentifier(prefix + "row." + row.id)
        rowViews[row.id] = line
        if configuration.highlightedID == row.id {
            line.wantsLayer = true
            line.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
            line.layer?.cornerRadius = 6
        }
        fullWidth(line)
        return line
    }

    private func fixButton(_ row: SubscriptionRow, prefix: String) -> ConnectionButton? {
        guard let fix = row.fix, !fix.isInformational else { return nil }
        let available = configuration.fixAvailable(row)
        // An action the app cannot perform is not offered (no dead buttons); the status line still says what to do.
        // Keychain and key entry stay visible while they wait for a moment when the engine can take the change.
        if !available, fix.target != .allowKeychain, fix.target != .addKey { return nil }
        return button(fix.action, id: prefix + "fix." + row.id, enabled: available,
                      help: .init("Not available in this version yet.", "此版本暂不可用。")) { [handlers = configuration.handlers] in handlers.fix(row) }
    }

    /// The alias cell: the host's editable field, or a greyed field that says why it cannot be edited yet.
    private func aliasCell(_ row: SubscriptionRow, locked: Bool) -> NSView {
        if !locked, let field = configuration.aliasField(row) { return field }
        let field = NSTextField(string: "")
        field.placeholderString = Self.lockedAliasPlaceholder(language)
        field.isEnabled = false; field.font = .systemFont(ofSize: 12)
        field.toolTip = Self.lockedAliasTip(language)
        field.setAccessibilityIdentifier("subscriptions.alias.locked." + row.id)
        field.setAccessibilityLabel(SettingsWords.text("Alias: ", "别名：", language) + text(row.name))
        field.setAccessibilityHelp(Self.lockedAliasTip(language))
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: SettingsGrid.alias).isActive = true
        return field
    }

    private func addedRow(_ row: SubscriptionRow) {
        // Reading by default, no engine row yet (Cursor, Grok Build): the same columns, switched off until the account
        // exists, because there is no subscription to show, hide or order yet. D322: a failed reader with no account yet
        // also offers its one next step in the status line.
        let pending = row.isPending
        let locked = configuration.lockedReason(row.id)
        let editable = !pending && configuration.canSave && locked == nil
        let alias = aliasCell(row, locked: pending || locked != nil)
        let visibility = ConnectionSwitchButton(title: "", identifier: "subscriptions.visible." + row.id) { [handlers = configuration.handlers] in
            handlers.setVisible(row.id, !row.visible)
        }
        visibility.becomeSwitch(); buttons.append(visibility)
        visibility.isEnabled = editable; visibility.state = row.visible ? .on : .off
        if !editable, let locked { visibility.toolTip = text(locked); visibility.setAccessibilityHelp(text(locked)) }
        visibility.setAccessibilityLabel(language == .english ? "Show \(row.name.english) in the Quota Widget and Cockpit" : "在额度挂件和驾驶舱显示 \(row.name.chinese)")
        if editable { visibility.toolTip = language == .english ? "Show in the Quota Widget and cockpit (display only)" : "在额度挂件和驾驶舱显示（仅影响显示）" }
        let movable = Self.movableOrder(configuration.model) { configuration.lockedReason($0) != nil }
        let index = movable.firstIndex(of: row.id)
        let up = button(.init("↑", "↑"), id: "subscriptions.up." + row.id, enabled: editable && (index.map { $0 > 0 } ?? false)) { [handlers = configuration.handlers] in handlers.move(row.id, -1) }
        let down = button(.init("↓", "↓"), id: "subscriptions.down." + row.id, enabled: editable && (index.map { $0 < movable.count - 1 } ?? false)) { [handlers = configuration.handlers] in handlers.move(row.id, 1) }
        up.setAccessibilityLabel(language == .english ? "Move \(row.name.english) up" : "上移 \(row.name.chinese)")
        down.setAccessibilityLabel(language == .english ? "Move \(row.name.english) down" : "下移 \(row.name.chinese)")
        for (step, symbol) in [(up, "arrow.up"), (down, "arrow.down")] {
            // A picture, not a letter: a 26 pt column cannot hold a bordered text button without clipping it.
            step.title = ""; step.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            step.imagePosition = .imageOnly; step.bezelStyle = .smallSquare; step.controlSize = .small
            step.translatesAutoresizingMaskIntoConstraints = false
            step.widthAnchor.constraint(equalToConstant: SettingsGrid.step).isActive = true
        }
        let handle = SubscriptionDragHandle()
        handle.rowID = row.id; handle.isDragEnabled = editable
        handle.setAccessibilityIdentifier("subscriptions.drag." + row.id)
        handle.setAccessibilityLabel(language == .english ? "Drag to reorder \(row.name.english)" : "拖动以调整 \(row.name.chinese) 的顺序")
        if !editable { handle.alphaValue = 0.35 }
        visibility.translatesAutoresizingMaskIntoConstraints = false
        visibility.widthAnchor.constraint(equalToConstant: SettingsGrid.toggle).isActive = true
        let line = rowShell(row, prefix: "subscriptions.", fix: fixButton(row, prefix: "subscriptions."),
                            cells: [alias, visibility, handle, up, down])
        guard editable else { return }
        let move = configuration.handlers.move
        line.onDrop = { source, target in
            guard let delta = Self.moveDelta(source: source, target: target, in: movable) else { return }
            move(source, delta)
        }
        // ⌥↑ / ⌥↓ on the selected row moves it one place, like the buttons.
        line.onKeyMove = { [handlers = configuration.handlers] delta in
            guard let index, movable.indices.contains(index + delta) else { return }
            handlers.keyboardMoved(row.id); handlers.move(row.id, delta)
        }
    }

    private func detectedRow(_ row: SubscriptionRow) {
        let add = button(.init("Add", "添加"), id: "subscriptions.add." + row.id, enabled: configuration.canMutate && row.canAdd,
                         help: .init("Fix the problem shown first, then add it.", "请先解决上面提到的问题，再添加。")) { [handlers = configuration.handlers] in handlers.add(row.tool) }
        add.setAccessibilityLabel(language == .english ? "Add \(row.name.english)" : "添加 \(row.name.chinese)")
        _ = rowShell(row, prefix: "subscriptions.", fix: fixButton(row, prefix: "subscriptions."), cells: [add])
    }

    private func notInstalledRow(_ row: SubscriptionRow) {
        _ = rowShell(row, prefix: "subscriptions.", fix: nil, cells: [])
    }
}

/// The grip on an added row. Dragging it onto another row moves the subscription there (the same shared order as up and down).
@MainActor final class SubscriptionDragHandle: NSImageView, NSDraggingSource {
    static let dragType = NSPasteboard.PasteboardType("ai.modelplan.settings.subscription-row")
    var rowID = ""
    var isDragEnabled = true
    /// A plugin row's grip drags within the plugin list only (its own type), never onto a subscription row.
    var dragType = SubscriptionDragHandle.dragType
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: SettingsGrid.handle, height: 20))
        image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)
        contentTintColor = .secondaryLabelColor; imageScaling = .scaleProportionallyDown
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: SettingsGrid.handle).isActive = true
        heightAnchor.constraint(equalToConstant: 20).isActive = true
        alphaValue = 0.8
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override func mouseDown(with event: NSEvent) {
        guard isDragEnabled, !rowID.isEmpty else { return }
        let item = NSPasteboardItem(); item.setString(rowID, forType: dragType)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        dragging.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [dragging], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }
}

/// One row line. Added rows accept a dropped handle and, once selected, ⌥↑ / ⌥↓; every other row ignores drags.
@MainActor final class SubscriptionDropRow: NSStackView {
    var rowID = ""
    /// The pasteboard type this row accepts (a plugin row uses its own).
    var dragType = SubscriptionDragHandle.dragType
    /// (dragged id, id of the row it was dropped on); set only on rows that can be reordered.
    var onDrop: ((String, String) -> Void)? {
        didSet { if onDrop != nil { registerForDraggedTypes([dragType]) } else { unregisterDraggedTypes() } }
    }
    /// -1 or +1 for ⌥↑ / ⌥↓; set only on rows that can be reordered. Such a row can be selected.
    var onKeyMove: ((Int) -> Void)? { didSet { focusRingType = onKeyMove == nil ? .none : .exterior } }
    override init(frame: NSRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    private func dragged(_ info: NSDraggingInfo) -> String? { info.draggingPasteboard.string(forType: dragType) }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard onDrop != nil, let source = dragged(sender), source != rowID else { return [] }
        return .move
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let onDrop, let source = dragged(sender), source != rowID else { return false }
        onDrop(source, rowID); return true
    }
    override var acceptsFirstResponder: Bool { onKeyMove != nil }
    override func mouseDown(with event: NSEvent) {
        if onKeyMove != nil { window?.makeFirstResponder(self) } else { super.mouseDown(with: event) }
    }
    override func keyDown(with event: NSEvent) {
        guard let onKeyMove, event.modifierFlags.contains(.option) else { super.keyDown(with: event); return }
        switch event.keyCode {
        case 126: onKeyMove(-1)
        case 125: onKeyMove(1)
        default: super.keyDown(with: event)
        }
    }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill() }
    override var focusRingMaskBounds: NSRect { bounds }
}
