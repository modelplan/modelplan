// SPDX-License-Identifier: MIT
import AppKit

private enum SettingsWords {
    static func text(_ en: String, _ zh: String, _ language: SettingsLanguage) -> String { language == .english ? en : zh }
    static func option(_ raw: String, key: SettingKey, language: SettingsLanguage) -> String {
        let pair: (String, String)
        switch raw {
        case "system": pair = key == .theme ? ("System", "跟随系统") : ("Follow system", "跟随系统")
        case "day": pair = ("Day", "白天")
        case "night": pair = ("Night", "夜间")
        case "on": pair = ("On", "开启")
        case "remaining": pair = ("Remaining", "剩余")
        case "used": pair = ("Used", "已用")
        case "auto": pair = ("Auto (tightest)", "自动（最紧的）")
        case "5h": pair = ("5 hours", "5 小时")
        case "week": pair = ("Weekly", "每周")
        case "true": pair = key == .showPercentages ? ("Shown", "显示") : ("On", "开启")
        case "false": pair = key == .showPercentages ? ("Hidden", "隐藏") : ("Off", "关闭")
        case "right": pair = ("Right", "右侧")
        case "left": pair = ("Left", "左侧")
        case "bottom": pair = ("Bottom", "底部")
        default: pair = (raw, raw)
        }
        return key == .redBelow ? raw + " %" : text(pair.0, pair.1, language)
    }
}

@MainActor private final class SettingsBackground: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { NSColor.windowBackgroundColor.setFill(); bounds.fill() }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay = true
    }
}

@MainActor final class SettingsChoiceControl: NSPopUpButton {
    let settingKey: SettingKey
    let subscriptionID: String?
    var onInteraction: (() -> Void)?
    private(set) var isRetired = false
    init(key: SettingKey, subscriptionID: String?) {
        settingKey = key; self.subscriptionID = subscriptionID
        super.init(frame: .zero, pullsDown: false)
        controlSize = .regular
        setAccessibilityIdentifier("settings.\(key.rawValue)" + (subscriptionID.map { "." + $0 } ?? ""))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override func becomeFirstResponder() -> Bool {
        guard !isRetired else { return false }
        let accepted = super.becomeFirstResponder(); if accepted { onInteraction?() }; return accepted
    }
    func retire() {
        isRetired = true; isEnabled = false
        target = nil; action = nil; onInteraction = nil
        menu?.cancelTracking()
    }
    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        guard !isRetired else { return false }
        return super.sendAction(action, to: target)
    }
    override func accessibilityPerformPress() -> Bool {
        guard !isRetired, isEnabled else { return false }
        return super.accessibilityPerformPress()
    }
    func configure(value: String, options: [String], key: SettingKey, language: SettingsLanguage) {
        // Keep the native control and its focus identity across appearance/locale/value transactions.
        if itemArray.compactMap({ $0.representedObject as? String }) != options {
            removeAllItems()
            for raw in options { addItem(withTitle: raw); lastItem?.representedObject = raw }
        }
        for (item, raw) in zip(itemArray, options) { item.title = SettingsWords.option(raw, key: key, language: language) }
        if let index = options.firstIndex(of: value) { selectItem(at: index) }
    }
}

@MainActor private final class SettingsNativeRow: NSStackView {
    let key: SettingKey
    let titleLabel = NSTextField(labelWithString: "")
    let subtitle = NSTextField(labelWithString: "")
    let group = NSTextField(labelWithString: "")
    let controls = NSStackView()
    let illustration = NSView()
    var diagram: SettingsDiagramView?
    var choices: [String: SettingsChoiceControl] = [:]
    private var subscriptionLabels: [String: NSTextField] = [:]
    private var controlIDs: [String] = []
    private var tracking: NSTrackingArea?
    private let readout = NSTextField(wrappingLabelWithString: "")

    init(key: SettingKey) {
        self.key = key
        super.init(frame: .zero)
        orientation = .horizontal; alignment = .centerY; distribution = .fill; spacing = 16
        edgeInsets = .init(top: 14, left: 8, bottom: 14, right: 8)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitle.font = .systemFont(ofSize: 12); subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        group.font = .systemFont(ofSize: 11, weight: .medium); group.textColor = .secondaryLabelColor
        let copy = NSStackView(views: [group, titleLabel, subtitle])
        copy.orientation = .vertical; copy.alignment = .leading; copy.spacing = 5
        copy.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controls.orientation = .vertical; controls.alignment = .trailing; controls.distribution = .fill; controls.spacing = 7
        readout.font = .systemFont(ofSize: 12); readout.textColor = .secondaryLabelColor
        addArrangedSubview(copy); addArrangedSubview(illustration); addArrangedSubview(controls)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 74),
            copy.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            illustration.widthAnchor.constraint(equalToConstant: 96), illustration.heightAnchor.constraint(equalToConstant: 40),
            controls.widthAnchor.constraint(equalToConstant: 230),
        ])
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(next); tracking = next
    }
    override func mouseEntered(with event: NSEvent) { diagram?.play() }

    func retireControls() {
        diagram?.stop()
        for popup in choices.values { popup.retire() }
        for view in controls.arrangedSubviews { controls.removeArrangedSubview(view); view.removeFromSuperview() }
        choices = [:]; subscriptionLabels = [:]; controlIDs = []
    }

    func apply(_ row: SettingsRow, language: SettingsLanguage, saving: Bool, input: SettingsDiagramInput?,
               reduced: Bool, onChoice: Selector, target: AnyObject, showGroup: Bool) {
        titleLabel.stringValue = row.title.value(language)
        subtitle.stringValue = row.subtitle.value(language)
        group.stringValue = [row.paneTitle.value(language), row.groupTitle?.value(language)].compactMap { $0 }.joined(separator: " · ")
        group.isHidden = !showGroup
        if let input {
            if diagram == nil {
                let view = SettingsDiagramView(input: input); diagram = view
                view.playsOnHover = false
                view.frame = illustration.bounds; view.autoresizingMask = [.width, .height]; illustration.addSubview(view)
            }
            diagram?.language = language
            diagram?.apply(input, reduceMotion: reduced, animate: true)
        }
        let enabled = SettingsB20Edit.keys.contains(key) && row.availability == .available
        var values: [(String, String, String, [String])] = []
        switch row.value {
        case .choice(let value, let options): values = [("", "", value, options)]
        case .toggle(let value): values = [("", "", String(value), ["true", "false"])]
        case .subscriptions(let subs) where key == .percentagePin:
            values = subs.map { ($0.id, [$0.name, $0.plan].filter { !$0.isEmpty }.joined(separator: " · "), $0.value, $0.options) }
        default: break
        }
        let ids = values.map(\.0)
        if controlIDs != ids || (values.isEmpty && controls.arrangedSubviews.isEmpty) {
            retireControls(); controlIDs = ids
            for (id, label, _, _) in values {
                let popup = SettingsChoiceControl(key: key, subscriptionID: id.isEmpty ? nil : id)
                popup.translatesAutoresizingMaskIntoConstraints = false
                popup.widthAnchor.constraint(equalToConstant: id.isEmpty ? 180 : 132).isActive = true
                popup.target = target; popup.action = onChoice
                popup.onInteraction = { [weak self] in self?.diagram?.play() }
                choices[id] = popup
                if label.isEmpty { controls.addArrangedSubview(popup) }
                else {
                    let name = NSTextField(labelWithString: label); name.font = .systemFont(ofSize: 12)
                    subscriptionLabels[id] = name
                    name.lineBreakMode = .byTruncatingTail; name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    let line = NSStackView(views: [name, popup]); line.spacing = 6
                    controls.addArrangedSubview(line); line.widthAnchor.constraint(equalTo: controls.widthAnchor).isActive = true
                }
            }
            if values.isEmpty { controls.addArrangedSubview(readout) }
        }
        for (id, label, value, options) in values {
            guard let popup = choices[id] else { continue }
            subscriptionLabels[id]?.stringValue = label
            popup.configure(value: value, options: options, key: key, language: language)
            popup.isEnabled = enabled && !saving
            popup.setAccessibilityLabel([row.title.value(language), label].filter { !$0.isEmpty }.joined(separator: " · "))
            popup.setAccessibilityHelp(enabled ? row.subtitle.value(language) : SettingsWords.text("Not editable in this build.", "此版本暂不提供编辑。", language))
        }
        if values.isEmpty {
            if key == .percentagePin { readout.stringValue = SettingsWords.text("No subscriptions detected", "尚未检测到订阅", language) }
            else if case .text(let text) = row.value { readout.stringValue = text }
            else { readout.stringValue = SettingsWords.text("Not available in this build", "此版本暂不可用", language) }
        }
    }
}

/// App-owned singleton Settings surface. Assembly supplies its existing store and consumes commit receipts.
/// It does not activate the application, register services, run readers or own a second locale/store.
@MainActor public final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate,
                                                        NSSearchFieldDelegate, NSWindowDelegate {
    public let editor: SettingsEditor
    public private(set) var selectedPaneID = "appearance"
    public private(set) var errorMessage: String?
    public let searchField = NSSearchField()
    private let sidebar = NSTableView()
    private let glass = NSVisualEffectView()
    private let stack = NSStackView()
    private let heading = NSTextField(labelWithString: "")
    private let status = NSTextField(wrappingLabelWithString: "")
    private let empty = NSTextField(wrappingLabelWithString: "")
    private var rows: [SettingKey: SettingsNativeRow] = [:]
    private var displayedKeys: [SettingKey] = []
    private var observers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?
    private let environmentProvider: @MainActor () -> SettingsEnvironment
    private var refreshing = false, pendingEdit = false

    public init(editor: SettingsEditor, environmentProvider: (@MainActor () -> SettingsEnvironment)? = nil) {
        self.editor = editor; self.environmentProvider = environmentProvider ?? Self.systemEnvironment
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 980, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.contentMinSize = .init(width: 900, height: 500)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildWindow(window)
        editor.onChange = { [weak self] in self?.refresh() }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.refreshEnvironment() } })
        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshEnvironment() }
        }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    deinit { for token in observers { NSWorkspace.shared.notificationCenter.removeObserver(token) } }

    /// Reads only public OS UI preferences. The host may inject its authoritative environment instead.
    public static func systemEnvironment() -> SettingsEnvironment {
        var result = SettingsEnvironment()
        result.darkAppearance = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        result.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        result.reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        result.increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        result.macOSMajor = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        return result
    }
    public func prepare() async { refreshEnvironment(); await editor.reload() }
    public func present(paneID: String? = nil) async {
        await prepare()
        if let paneID { selectPane(paneID) }
        showWindow(nil); window?.makeKeyAndOrderFront(nil)
    }
    public func selectPane(_ id: String) {
        guard let index = SettingsStructure.task65.panes.firstIndex(where: { $0.id == id }) else { return }
        selectedPaneID = id
        sidebar.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        refresh()
    }
    public func refreshEnvironment() { editor.update(environment: environmentProvider()) }
    public func windowWillClose(_ notification: Notification) { for row in rows.values { row.diagram?.stop() } }
    public func controlTextDidChange(_ obj: Notification) { if obj.object as? NSSearchField === searchField { refresh() } }
    public func numberOfRows(in tableView: NSTableView) -> Int { SettingsStructure.task65.panes.count }
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let label = NSTextField(labelWithString: SettingsStructure.task65.panes[row].title.value(language))
        label.font = .systemFont(ofSize: 13); label.setAccessibilityIdentifier("settings.pane." + SettingsStructure.task65.panes[row].id)
        return label
    }
    public func tableViewSelectionDidChange(_ notification: Notification) {
        guard !refreshing, SettingsStructure.task65.panes.indices.contains(sidebar.selectedRow) else { return }
        selectedPaneID = SettingsStructure.task65.panes[sidebar.selectedRow].id; refresh()
    }
    private var language: SettingsLanguage { editor.snapshot?.preferences.language ?? .chinese }
    private func buildWindow(_ window: NSWindow) {
        let root = SettingsBackground(); window.contentView = root
        let side = SettingsBackground(); side.translatesAutoresizingMaskIntoConstraints = false
        glass.material = .sidebar; glass.blendingMode = .withinWindow; glass.state = .followsWindowActiveState
        glass.translatesAutoresizingMaskIntoConstraints = false; side.addSubview(glass)
        root.addSubview(side)
        searchField.translatesAutoresizingMaskIntoConstraints = false; searchField.delegate = self
        searchField.setAccessibilityIdentifier("settings.search"); side.addSubview(searchField)
        let tableScroll = NSScrollView(); tableScroll.drawsBackground = false; tableScroll.hasVerticalScroller = true
        tableScroll.translatesAutoresizingMaskIntoConstraints = false; side.addSubview(tableScroll)
        sidebar.addTableColumn(NSTableColumn(identifier: .init("pane")))
        sidebar.headerView = nil; sidebar.rowHeight = 36; sidebar.style = .sourceList
        sidebar.dataSource = self; sidebar.delegate = self; sidebar.backgroundColor = .clear
        sidebar.setAccessibilityIdentifier("settings.sidebar"); tableScroll.documentView = sidebar
        let divider = NSBox(); divider.boxType = .separator; divider.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(divider)
        let scroll = NSScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.hasVerticalScroller = true
        scroll.drawsBackground = false; root.addSubview(scroll)
        let document = SettingsBackground(); document.translatesAutoresizingMaskIntoConstraints = false; scroll.documentView = document
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false; document.addSubview(stack)
        heading.font = .systemFont(ofSize: 23, weight: .semibold)
        status.font = .systemFont(ofSize: 12); status.textColor = .systemRed
        status.setAccessibilityIdentifier("settings.status"); status.setAccessibilityRole(.staticText)
        empty.font = .systemFont(ofSize: 13); empty.textColor = .secondaryLabelColor
        for view in [heading, status, empty] { stack.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        NSLayoutConstraint.activate([
            side.leadingAnchor.constraint(equalTo: root.leadingAnchor), side.topAnchor.constraint(equalTo: root.topAnchor),
            side.bottomAnchor.constraint(equalTo: root.bottomAnchor), side.widthAnchor.constraint(equalToConstant: 236),
            glass.leadingAnchor.constraint(equalTo: side.leadingAnchor), glass.trailingAnchor.constraint(equalTo: side.trailingAnchor),
            glass.topAnchor.constraint(equalTo: side.topAnchor), glass.bottomAnchor.constraint(equalTo: side.bottomAnchor),
            searchField.leadingAnchor.constraint(equalTo: side.leadingAnchor, constant: 13), searchField.trailingAnchor.constraint(equalTo: side.trailingAnchor, constant: -13),
            searchField.topAnchor.constraint(equalTo: side.topAnchor, constant: 20), searchField.heightAnchor.constraint(equalToConstant: 28),
            tableScroll.leadingAnchor.constraint(equalTo: side.leadingAnchor, constant: 8), tableScroll.trailingAnchor.constraint(equalTo: side.trailingAnchor, constant: -8),
            tableScroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 20), tableScroll.bottomAnchor.constraint(equalTo: side.bottomAnchor, constant: -12),
            divider.leadingAnchor.constraint(equalTo: side.trailingAnchor), divider.widthAnchor.constraint(equalToConstant: 1),
            divider.topAnchor.constraint(equalTo: root.topAnchor), divider.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: divider.trailingAnchor), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: root.topAnchor), scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 30), stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -28),
        ])
        window.initialFirstResponder = searchField
    }
    private func refresh() {
        guard !refreshing else { return }; refreshing = true; defer { refreshing = false }
        window?.title = SettingsWords.text("Settings", "设置", language)
        searchField.placeholderString = SettingsWords.text("Search settings", "搜索设置", language)
        searchField.setAccessibilityLabel(searchField.placeholderString)
        sidebar.reloadData()
        if let index = SettingsStructure.task65.panes.firstIndex(where: { $0.id == selectedPaneID }) {
            sidebar.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        guard let snapshot = editor.snapshot, let effective = editor.effective else {
            heading.stringValue = SettingsWords.text("Loading settings…", "正在读取设置…", language); return
        }
        // Accessibility appearance names are matching-only, not constructible (NSAppearance.h).
        // AppKit resolves the system contrast variant; semantic inks are re-resolved on workspace changes.
        let desiredAppearance: NSAppearance.Name? = snapshot.preferences.theme == .system ? nil : effective.darkAppearance ? .darkAqua : .aqua
        if window?.appearance?.name != desiredAppearance { window?.appearance = desiredAppearance.flatMap(NSAppearance.init(named:)) }
        glass.isHidden = effective.reduceTransparency
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        heading.stringValue = query.isEmpty
            ? SettingsStructure.task65.panes.first(where: { $0.id == selectedPaneID })!.title.value(language)
            : SettingsWords.text("Search results", "搜索结果", language)
        status.stringValue = errorMessage ?? (editor.isSaving ? SettingsWords.text("Saving…", "正在保存…", language) : "")
        status.textColor = errorMessage == nil ? .secondaryLabelColor : .systemRed
        status.isHidden = status.stringValue.isEmpty
        do {
            let visible = try SettingsCatalogue.rows(preferences: snapshot.preferences, context: editor.context,
                                                     paneID: query.isEmpty ? selectedPaneID : nil, query: query)
            let ordered = try snapshot.preferences.presentedSubscriptionIDs(editor.context.subscriptions.map(\.id), includingHidden: true)
            let inputs = SettingsDiagrams.inputs(snapshot.preferences, orderedIDs: ordered, lastChangedSubscriptionID: editor.lastChangedSubscriptionID)
            let diagrams: [SettingKey: SettingsDiagramInput] = [.dockEdge: inputs[0], .showPercentages: inputs[1], .autoHide: inputs[2], .size: inputs[3], .percentagePin: inputs[4]]
            let keys = visible.map(\.key)
            if keys != displayedKeys {
                let remaining = Set(keys)
                for key in displayedKeys where !remaining.contains(key) {
                    if let row = rows[key] { row.retireControls(); stack.removeArrangedSubview(row); row.removeFromSuperview() }
                }
                // Catalogue order is stable. Insert returning/new rows without detaching controls still displayed.
                for (index, key) in keys.enumerated() {
                    let row = rows[key] ?? SettingsNativeRow(key: key); rows[key] = row
                    if row.superview !== stack {
                        stack.insertArrangedSubview(row, at: index + 3)
                        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
                    }
                }
                displayedKeys = keys
            }
            var previousGroup = ""
            for item in visible {
                let groupID = item.paneID + "." + item.groupID
                rows[item.key]?.apply(item, language: language, saving: editor.isSaving, input: diagrams[item.key],
                                     reduced: effective.reduceMotion, onChoice: #selector(changeChoice(_:)), target: self,
                                     showGroup: !query.isEmpty || groupID != previousGroup)
                previousGroup = groupID
            }
            // Hidden diagrams also stop immediately on a runtime accessibility transaction.
            if effective.reduceMotion { for row in rows.values { row.diagram?.stop() } }
            empty.isHidden = !visible.isEmpty
            empty.stringValue = SettingsWords.text("No matching settings", "没有匹配的设置", language)
        } catch {
            for row in rows.values { row.diagram?.stop(); for choice in row.choices.values { choice.isEnabled = false } }
            status.stringValue = SettingsWords.text("Settings are unavailable. Check the supplied subscription data.", "设置暂不可用，请检查订阅数据。", language)
            status.isHidden = false
        }
    }
    @objc private func changeChoice(_ sender: SettingsChoiceControl) {
        guard !pendingEdit, sender.isEnabled, !sender.isRetired,
              displayedKeys.contains(sender.settingKey), let row = rows[sender.settingKey],
              row.superview === stack, !row.isHiddenOrHasHiddenAncestor,
              row.choices[sender.subscriptionID ?? ""] === sender, sender.isDescendant(of: row),
              let value = sender.selectedItem?.representedObject as? String else { return }
        do {
            let edit = try SettingsB20Edit(key: sender.settingKey, value: value, subscriptionID: sender.subscriptionID)
            pendingEdit = true; errorMessage = nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.pendingEdit = false; self.refresh() }
                do { try await self.editor.commit(edit) }
                catch {
                    self.errorMessage = (error as? SettingsError) == .staleRevision
                        ? SettingsWords.text("Settings changed elsewhere. Review the current value and try again.", "设置已在别处更新，请检查当前值后重试。", self.language)
                        : SettingsWords.text("Could not save this change. The saved settings are retained.", "无法保存此次更改，已保留原设置。", self.language)
                    NSAccessibility.post(element: self.status, notification: .valueChanged)
                }
            }
        } catch { refresh() }
    }
    // Native-control integration tests use these identities without exposing test-only actions in the product.
    func choice(key: SettingKey, subscriptionID: String = "") -> SettingsChoiceControl? { rows[key]?.choices[subscriptionID] }
    func diagram(key: SettingKey) -> SettingsDiagramView? { rows[key]?.diagram }
    var visibleSettingKeys: [SettingKey] { displayedKeys }
}
