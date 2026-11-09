// SPDX-License-Identifier: MIT
import AppKit

/// D87 slice 6/7: the Subscriptions rows. One row per subscription (mark, name, plan, a status line with one
/// fix action, a display-only visibility switch, up and down), then "Detected, not added" with an Add button,
/// then a collapsed "Supported, not installed". It draws a `SubscriptionRowModel` and reports presses to the
/// host; it never grants, revokes or saves anything itself.
@MainActor final class SubscriptionRowsView: NSStackView {
    struct Handlers {
        var setVisible: (String, Bool) -> Void = { _, _ in }
        var move: (String, Int) -> Void = { _, _ in }
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
        /// Whether the app can perform this row's fix action now; false shows the button disabled.
        var fixAvailable: (SubscriptionRow) -> Bool
        var notInstalledExpanded: Bool
        var notices: [String: SettingsText]
        var handlers: Handlers
        /// A row the host wants the user to see (a widget card's reason links here).
        var highlightedID: String?
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

    private func heading(_ value: SettingsText, id: String) {
        let field = NSTextField(wrappingLabelWithString: text(value))
        field.font = .systemFont(ofSize: 13, weight: .semibold); field.setAccessibilityIdentifier(id)
        addArrangedSubview(field); wrappingLabels.append(field)
        field.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
    private func note(_ value: SettingsText, id: String) {
        let field = NSTextField(wrappingLabelWithString: text(value))
        field.font = .systemFont(ofSize: 12); field.textColor = .secondaryLabelColor; field.setAccessibilityIdentifier(id)
        addArrangedSubview(field); wrappingLabels.append(field)
        field.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
    private func button(_ title: SettingsText, id: String, enabled: Bool, help: SettingsText? = nil,
                        action: @escaping () -> Void) -> ConnectionButton {
        let value = ConnectionButton(title: text(title), identifier: id, invoke: action)
        value.isEnabled = enabled; buttons.append(value)
        if let help, !enabled { value.toolTip = text(help); value.setAccessibilityHelp(text(help)) }
        return value
    }

    private func build() {
        let model = configuration.model
        heading(.init("My subscriptions", "我的订阅"), id: "subscriptions.added.heading")
        if model.added.isEmpty {
            note(.init("Nothing is being read yet. Add a detected tool below.", "目前没有在读取的订阅，可以从下面添加已检测到的工具。"), id: "subscriptions.added.empty")
        }
        for row in model.added { addedRow(row); }
        if !model.detected.isEmpty {
            if let last = arrangedSubviews.last { setCustomSpacing(16, after: last) }
            heading(.init("Detected, not added", "已检测到，尚未添加"), id: "subscriptions.detected.heading")
            note(.init("ModelPlan reads a tool only after you add it.", "添加之后，ModelPlan 才会读取这个工具。"), id: "subscriptions.detected.note")
            for row in model.detected { detectedRow(row) }
        }
        if !model.notInstalled.isEmpty {
            if let last = arrangedSubviews.last { setCustomSpacing(16, after: last) }
            let title: SettingsText = configuration.notInstalledExpanded
                ? .init("Hide supported tools that are not installed", "收起未安装的受支持工具")
                : .init("Supported, not installed (\(model.notInstalled.count))", "受支持，未安装（\(model.notInstalled.count)）")
            let toggle = button(title, id: "subscriptions.notInstalled.toggle", enabled: true) { [handlers = configuration.handlers] in handlers.toggleNotInstalled() }
            addArrangedSubview(toggle)
            if configuration.notInstalledExpanded { for row in model.notInstalled { notInstalledRow(row) } }
        }
    }

    /// Mark, then a column: name and plan, the status line, any notice. Returns the column.
    private func rowShell(_ row: SubscriptionRow, prefix: String, trailing: [NSView]) -> NSStackView {
        let mark = configuration.mark(row.tool)
        let name = NSTextField(labelWithString: text(row.name))
        name.font = .systemFont(ofSize: 14, weight: .semibold); name.setAccessibilityIdentifier(prefix + "name." + row.id)
        var titleViews: [NSView] = [name]
        if !row.plan.isEmpty {
            let plan = NSTextField(labelWithString: row.plan)
            plan.font = .systemFont(ofSize: 11); plan.textColor = .secondaryLabelColor; plan.setAccessibilityIdentifier(prefix + "plan." + row.id)
            titleViews.append(plan)
        }
        let title = NSStackView(views: titleViews); title.orientation = .horizontal; title.alignment = .firstBaseline; title.spacing = 8
        let column = NSStackView(views: [title]); column.orientation = .vertical; column.alignment = .leading; column.spacing = 3
        let status = NSTextField(wrappingLabelWithString: text(row.status))
        status.font = .systemFont(ofSize: 12); status.textColor = row.needsAttention ? .systemOrange : .secondaryLabelColor
        status.setAccessibilityIdentifier(prefix + "status." + row.id)
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        column.addArrangedSubview(status); wrappingLabels.append(status)
        status.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        if let notice = configuration.notices[row.id] {
            let field = NSTextField(wrappingLabelWithString: text(notice))
            field.font = .systemFont(ofSize: 11); field.textColor = .systemOrange; field.setAccessibilityIdentifier(prefix + "notice." + row.id)
            column.addArrangedSubview(field); wrappingLabels.append(field)
            field.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        column.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let line = NSStackView(views: [mark, column] + trailing)
        line.orientation = .horizontal; line.alignment = .top; line.spacing = 10
        line.setAccessibilityIdentifier(prefix + "row." + row.id)
        rowViews[row.id] = line
        if configuration.highlightedID == row.id {
            line.wantsLayer = true
            line.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
            line.layer?.cornerRadius = 6
        }
        addArrangedSubview(line)
        line.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        return column
    }

    private func fixButton(_ row: SubscriptionRow, prefix: String) -> ConnectionButton? {
        guard let fix = row.fix else { return nil }
        let available = configuration.fixAvailable(row)
        return button(fix.action, id: prefix + "fix." + row.id, enabled: available,
                      help: .init("Not available in this version yet.", "此版本暂不可用。")) { [handlers = configuration.handlers] in handlers.fix(row) }
    }

    private func addedRow(_ row: SubscriptionRow) {
        let locked = configuration.lockedReason(row.id)
        let editable = configuration.canSave && locked == nil
        var trailing: [NSView] = []
        if let fix = fixButton(row, prefix: "subscriptions.") { trailing.append(fix) }
        let visibility = button(.init("", ""), id: "subscriptions.visible." + row.id, enabled: editable,
                                help: locked) { [handlers = configuration.handlers] in handlers.setVisible(row.id, !row.visible) }
        visibility.setButtonType(.switch); visibility.title = ""; visibility.state = row.visible ? .on : .off
        visibility.setAccessibilityLabel(language == .english ? "Show \(row.name.english) in the Quota Widget and Cockpit" : "在额度挂件和驾驶舱显示 \(row.name.chinese)")
        visibility.toolTip = language == .english ? "Show in the Quota Widget and cockpit (display only)" : "在额度挂件和驾驶舱显示（仅影响显示）"
        trailing.append(visibility)
        let up = button(.init("↑", "↑"), id: "subscriptions.up." + row.id, enabled: editable && row.canMoveUp) { [handlers = configuration.handlers] in handlers.move(row.id, -1) }
        let down = button(.init("↓", "↓"), id: "subscriptions.down." + row.id, enabled: editable && row.canMoveDown) { [handlers = configuration.handlers] in handlers.move(row.id, 1) }
        up.setAccessibilityLabel(language == .english ? "Move \(row.name.english) up" : "上移 \(row.name.chinese)")
        down.setAccessibilityLabel(language == .english ? "Move \(row.name.english) down" : "下移 \(row.name.chinese)")
        trailing.append(contentsOf: [up, down])
        _ = rowShell(row, prefix: "subscriptions.", trailing: trailing)
    }

    private func detectedRow(_ row: SubscriptionRow) {
        var trailing: [NSView] = []
        if let fix = fixButton(row, prefix: "subscriptions.") { trailing.append(fix) }
        let add = button(.init("Add", "添加"), id: "subscriptions.add." + row.id, enabled: configuration.canMutate && row.canAdd,
                         help: .init("Fix the problem shown first, then add it.", "请先解决上面提到的问题，再添加。")) { [handlers = configuration.handlers] in handlers.add(row.tool) }
        add.setAccessibilityLabel(language == .english ? "Add \(row.name.english)" : "添加 \(row.name.chinese)")
        trailing.append(add)
        _ = rowShell(row, prefix: "subscriptions.", trailing: trailing)
    }

    private func notInstalledRow(_ row: SubscriptionRow) {
        _ = rowShell(row, prefix: "subscriptions.", trailing: [])
    }
}
