// SPDX-License-Identifier: MIT
import AppKit

/// Local-only drag payloads contain random tokens, never subscription/account identifiers.
@MainActor final class SettingsOrderControl: NSStackView, SettingsOwnedControl, NSTableViewDataSource, NSTableViewDelegate {
    let settingKey: SettingKey = .order
    let subscriptionID: String? = nil
    private(set) var isRetired = false
    var isEnabled = true { didSet { updateButtons() } }
    let table = NSTableView()
    let up = NSButton(), down = NSButton(), reset = NSButton()
    var onMove: ((SettingsOrderControl, String, Int, [String]) -> Void)?
    var onReset: ((SettingsOrderControl) -> Void)?
    private(set) var ids: [String] = []
    private var names: [String: String] = [:]
    private var canReset = false
    private var drag: (token: String, id: String, order: [String])?
    private var scrollHeight: NSLayoutConstraint?
    static let dragType = NSPasteboard.PasteboardType("ai.modelplan.settings.order-token")

    override init(frame: NSRect) {
        super.init(frame: frame)
        orientation = .vertical; alignment = .trailing; spacing = 6
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.documentView = table; addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalToConstant: 230).isActive = true
        scrollHeight = scroll.heightAnchor.constraint(equalToConstant: 80); scrollHeight?.isActive = true
        table.addTableColumn(NSTableColumn(identifier: .init("subscription")))
        table.headerView = nil; table.rowHeight = 26; table.allowsMultipleSelection = false
        table.delegate = self; table.dataSource = self
        table.registerForDraggedTypes([Self.dragType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.setDraggingSourceOperationMask([], forLocal: false)
        table.setAccessibilityIdentifier("settings.order.list")
        for button in [up, down, reset] { button.bezelStyle = .rounded; button.target = self }
        up.title = "↑"; down.title = "↓"
        up.action = #selector(moveSubscriptionUp); down.action = #selector(moveSubscriptionDown); reset.action = #selector(resetOrder)
        let buttons = NSStackView(views: [up,down,reset]); buttons.spacing = 6; addArrangedSubview(buttons)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func configure(ids: [String], names: [String: String], language: SettingsLanguage, canReset: Bool) {
        let selected = table.selectedRow >= 0 && self.ids.indices.contains(table.selectedRow) ? self.ids[table.selectedRow] : nil
        if self.ids != ids { drag = nil }
        self.ids = ids; self.names = names; self.canReset = canReset
        table.reloadData()
        if let index = selected.flatMap({ ids.firstIndex(of: $0) }) ?? (ids.isEmpty ? nil : 0) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        scrollHeight?.constant = CGFloat(max(52,min(208,ids.count * 26)))
        reset.title = language == .english ? "Reset order" : "恢复默认顺序"
        up.setAccessibilityLabel(language == .english ? "Move subscription up" : "订阅上移")
        down.setAccessibilityLabel(language == .english ? "Move subscription down" : "订阅下移")
        reset.setAccessibilityLabel(reset.title); updateButtons()
    }
    private func updateButtons() {
        let enabled = isEnabled && !isRetired
        table.isEnabled = enabled
        up.isEnabled = enabled && table.selectedRow > 0
        down.isEnabled = enabled && table.selectedRow >= 0 && table.selectedRow < ids.count - 1
        reset.isEnabled = enabled && canReset
    }
    func numberOfRows(in tableView: NSTableView) -> Int { ids.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard ids.indices.contains(row) else { return nil }
        let label = NSTextField(labelWithString: names[ids[row]] ?? ids[row])
        label.font = .systemFont(ofSize: 12); label.lineBreakMode = .byTruncatingTail
        return label
    }
    func tableViewSelectionDidChange(_ notification: Notification) { updateButtons() }
    @objc private func moveSubscriptionUp() { moveSelected(by: -1) }
    @objc private func moveSubscriptionDown() { moveSelected(by: 1) }
    private func moveSelected(by offset: Int) {
        let index = table.selectedRow, target = index + offset
        guard isEnabled, !isRetired, ids.indices.contains(index), ids.indices.contains(target) else { return }
        onMove?(self, ids[index], target, ids)
    }
    @objc private func resetOrder() { guard isEnabled, !isRetired, canReset else { return }; onReset?(self) }
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard isEnabled, !isRetired, ids.indices.contains(row) else { return nil }
        let token = UUID().uuidString
        drag = (token, ids[row], ids)
        let item = NSPasteboardItem(); item.setString(token, forType: Self.dragType); return item
    }
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
                   proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
        guard operation == .above, isEnabled, !isRetired, info.draggingSource as? NSTableView === table,
              let drag, drag.order == ids, (0...ids.count).contains(row),
              info.draggingPasteboard.string(forType: Self.dragType) == drag.token else { return [] }
        return .move
    }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        guard dropOperation == .above else { return false }
        return acceptLocalDrop(token: info.draggingPasteboard.string(forType: Self.dragType), source: info.draggingSource as? NSView, row: row)
    }
    func acceptLocalDrop(token: String?, source: NSView?, row: Int) -> Bool {
        guard isEnabled, !isRetired, source === table, let drag, token == drag.token, drag.order == ids,
              (0...ids.count).contains(row), let from = ids.firstIndex(of: drag.id) else { return false }
        self.drag = nil
        let target = row > from ? row - 1 : row
        guard target != from else { return false }
        onMove?(self, drag.id, target, drag.order); return true
    }
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { drag = nil }
    func retire() {
        isRetired = true; isEnabled = false; drag = nil; onMove = nil; onReset = nil
        table.unregisterDraggedTypes(); table.delegate = nil; table.dataSource = nil
        for button in [up,down,reset] { button.isEnabled = false; button.target = nil; button.action = nil }
    }
}
