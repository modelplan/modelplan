// SPDX-License-Identifier: MIT
import AppKit

/// Settings › Subscriptions › "Plugins" (CKP-PLG-54, D293, D371): one row per plugin on the same column grid as "My
/// subscriptions" (icon, name and one sentence, an empty alias cell, a switch, a grip, up, down). Under each row a small
/// indented line holds the plugin's options (for example the sampling interval as one segmented control) and the
/// "Pin to cockpit page 1" switch (at most two; off by default). Turning a plugin off here is the same edit as Remove in
/// the cockpit key's right-click menu. Shown on the Subscriptions pane, right after "My subscriptions", and for matching
/// searches.
@MainActor public final class SettingsCockpitPluginsView: NSView {
    public let model: CockpitPluginSettingsModel
    private var language: SettingsLanguage
    private let heading = NSTextField(labelWithString: "")
    private let note = NSTextField(wrappingLabelWithString: "")
    private let list = NSStackView()
    private var busy = false
    /// Wrapping labels of the current rows; they take their column's width so long sentences wrap.
    private var wrapping: [NSTextField] = []
    public init(model: CockpitPluginSettingsModel, language: SettingsLanguage) {
        self.model = model; self.language = language
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityIdentifier("settings.cockpitPlugins"); isHidden = true
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.setAccessibilityIdentifier("settings.section.subscriptions.plugins")
        note.font = .systemFont(ofSize: 12); note.textColor = .secondaryLabelColor
        list.orientation = .vertical; list.alignment = .leading; list.spacing = 0
        let stack = NSStackView(views: [heading, note, list])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor), list.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        rebuild()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    /// The pane that shows the section (WP-16 moved it from Cockpit to Subscriptions).
    public static let paneID = "subscriptions"
    /// The pasteboard type of a plugin row's grip: plugin rows reorder among themselves only.
    static let dragType = NSPasteboard.PasteboardType("ai.modelplan.settings.plugin-row")
    /// Re-labels and shows the section on the Subscriptions pane, or for a search that names it.
    public func apply(language: SettingsLanguage, paneID: String, query: String) {
        self.language = language
        isHidden = query.isEmpty ? paneID != Self.paneID
            : !["plugin", "subscription", "cockpit", "插件", "订阅", "驾驶舱"].contains(where: { query.localizedCaseInsensitiveContains($0) })
        rebuild()
    }
    private func text(_ en: String, _ zh: String) -> String { SettingsWords.text(en, zh, language) }
    public override func layout() {
        super.layout()
        for label in wrapping {
            let width = label.bounds.width
            if width > 0, abs(label.preferredMaxLayoutWidth - width) > 0.5 { label.preferredMaxLayoutWidth = width; label.invalidateIntrinsicContentSize() }
        }
    }

    /// One row per listed plugin, in the saved order. Owner 11-21: a framework test plugin (the placeholder) is never
    /// listed. Owner D124: an unpinned plugin takes a free column after the subscriptions, so with few subscriptions it
    /// shows on page 1 without a pin; the note says so (B4).
    /// Counts rebuilds, for the G3-161 checks (an unchanged catalogue and state must not rebuild the section).
    private(set) var rebuildCountForChecks = 0
    func rebuild() {
        rebuildCountForChecks += 1
        heading.stringValue = text("Plugins", "插件")
        note.stringValue = text("Plugin columns come after your subscriptions in the cockpit and use free columns on the last page. A pinned plugin always stays on page 1 (at most two).",
                                "插件列排在驾驶舱订阅的后面，占用最后一页的空位。固定的插件总在第 1 页（最多两个）。")
        for view in list.arrangedSubviews { list.removeArrangedSubview(view); view.removeFromSuperview() }
        wrapping = []
        let prefs = model.preferences.materialized(model.catalogue)
        let listed = CockpitPluginCatalogue.listed(model.catalogue)
        let known = prefs.entries.filter { entry in listed.contains(where: { $0.id == entry.id }) }
        let order = known.map(\.id)
        for (index, entry) in known.enumerated() {
            guard let plugin = listed.first(where: { $0.id == entry.id }) else { continue }
            let view = row(plugin, entry: entry, first: index == 0, last: index == known.count - 1, prefs: prefs, order: order)
            list.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
            if index < known.count - 1 {
                let line = SettingsGrid.divider(); list.addArrangedSubview(line); line.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
            }
        }
    }
    /// An arrow in a 26 pt column: a picture, so no bordered text button is clipped.
    private func arrow(_ symbol: String, id: String, label: String, action: Selector, pluginID: String, enabled: Bool) -> NSButton {
        let b = NSButton(title: "", target: self, action: action)
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        b.imagePosition = .imageOnly; b.bezelStyle = .smallSquare; b.controlSize = .small
        b.isEnabled = enabled && !busy
        b.setAccessibilityIdentifier(id); b.setAccessibilityLabel(label); b.identifier = .init(pluginID)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: SettingsGrid.step).isActive = true
        return b
    }
    private func label(_ value: String, size: CGFloat = 12, secondary: Bool = true) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.font = .systemFont(ofSize: size); field.textColor = secondary ? .secondaryLabelColor : .labelColor
        return field
    }
    private func row(_ plugin: CockpitPluginDefinition, entry: CockpitPluginEntry, first: Bool, last: Bool,
                     prefs: CockpitPluginPreferences, order: [String]) -> NSView {
        let base = "settings.cockpitPlugins.\(plugin.id)"
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: plugin.symbol, accessibilityDescription: nil)
        icon.contentTintColor = .labelColor; icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        icon.setAccessibilityIdentifier(base + ".icon")
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true; icon.heightAnchor.constraint(equalToConstant: 16).isActive = true
        let on = PlainSwitchButton(frame: .zero)
        on.target = self; on.action = #selector(toggleEnabled(_:))
        on.state = entry.enabled ? .on : .off; on.identifier = .init(plugin.id); on.isEnabled = !busy
        on.setAccessibilityIdentifier(base + ".enabled"); on.setAccessibilityLabel(plugin.title.value(language))
        on.translatesAutoresizingMaskIntoConstraints = false
        on.widthAnchor.constraint(equalToConstant: SettingsGrid.toggle).isActive = true
        let pin = PlainSwitchButton(frame: .zero)
        pin.title = text("Pin to cockpit page 1", "固定到驾驶舱第 1 页")
        pin.target = self; pin.action = #selector(togglePinned(_:))
        pin.state = entry.pinned ? .on : .off; pin.identifier = .init(plugin.id)
        pin.isEnabled = !busy && (entry.pinned || prefs.canPin(plugin.id, model.catalogue))
        pin.setAccessibilityIdentifier(base + ".pinned"); pin.setAccessibilityLabel(pin.title)
        pin.translatesAutoresizingMaskIntoConstraints = false
        pin.widthAnchor.constraint(equalToConstant: SettingsGrid.toggle).isActive = true
        if !entry.pinned, entry.enabled, !prefs.canPin(plugin.id, model.catalogue) {
            pin.toolTip = text("Two plugins are already pinned.", "已经固定了两个插件。")
        }
        let up = arrow("arrow.up", id: base + ".up", label: text("Move earlier", "前移"), action: #selector(movePluginEarlier(_:)), pluginID: plugin.id, enabled: !first)
        let down = arrow("arrow.down", id: base + ".down", label: text("Move later", "后移"), action: #selector(movePluginLater(_:)), pluginID: plugin.id, enabled: !last)
        let handle = SubscriptionDragHandle()
        handle.dragType = Self.dragType; handle.rowID = plugin.id; handle.isDragEnabled = !busy
        handle.setAccessibilityIdentifier(base + ".drag")
        handle.setAccessibilityLabel(text("Drag to reorder \(plugin.title.english)", "拖动以调整 \(plugin.title.chinese) 的顺序"))
        // Name and one sentence, in the grid's name column.
        let name = label(plugin.title.value(language), size: 14, secondary: false)
        name.font = .systemFont(ofSize: 14, weight: .semibold)
        name.setAccessibilityIdentifier(base + ".name")
        let summary = NSTextField(wrappingLabelWithString: plugin.summary.value(language))
        summary.font = .systemFont(ofSize: SettingsGrid.statusFont); summary.textColor = .secondaryLabelColor
        summary.setAccessibilityIdentifier(base + ".summary")
        summary.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        wrapping.append(summary)
        let column = NSStackView(views: [name, summary]); column.orientation = .vertical; column.alignment = .leading; column.spacing = 2
        column.setContentHuggingPriority(.init(1), for: .horizontal)
        column.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        summary.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        let main = SubscriptionDropRow(frame: .zero)
        main.dragType = Self.dragType; main.rowID = plugin.id
        let cells: [NSView] = [SettingsGrid.cell(icon, width: SettingsGrid.mark), column, SettingsGrid.spacer(SettingsGrid.alias), on, handle, up, down]
        for view in cells { main.addArrangedSubview(view) }
        main.orientation = .horizontal; main.alignment = .centerY; main.distribution = .fill; main.spacing = SettingsGrid.gap
        main.heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsGrid.rowHeight).isActive = true
        if !busy {
            main.onDrop = { [weak self] source, target in
                guard let self, let from = order.firstIndex(of: source), let to = order.firstIndex(of: target), from != to else { return }
                self.moveBy(source, to - from)
            }
        }
        // The small indented line under the row: the plugin's options on the left, "Pin to cockpit page 1" on the right
        // in the switch column.
        var subViews: [NSView] = [SettingsGrid.spacer(SettingsGrid.mark + SettingsGrid.gap)]
        // The per-plugin settings slot: one stepper per declared setting, or one segmented control when the
        // setting lists its choices (the resource plugin's 2 / 5 / 10 s, D324).
        for spec in plugin.settings {
            let value = prefs.value(plugin.id, spec.key, model.catalogue) ?? spec.defaultValue
            let title = label(spec.title.value(language))
            if !spec.choices.isEmpty {
                let control = CockpitPluginChoices(pluginID: plugin.id, key: spec.key, choices: spec.choices)
                control.segmentCount = spec.choices.count; control.trackingMode = .selectOne
                for (i, choice) in spec.choices.enumerated() {
                    control.setLabel(text("\(choice) s", "\(choice) 秒"), forSegment: i)
                    control.setWidth(0, forSegment: i)
                }
                control.selectedSegment = spec.choices.firstIndex(of: value) ?? -1
                control.controlSize = .small
                control.isEnabled = !busy && entry.enabled
                control.target = self; control.action = #selector(chooseSetting(_:))
                control.setAccessibilityIdentifier(base + "." + spec.key)
                control.setAccessibilityLabel(spec.title.value(language))
                subViews += [title, control]
                continue
            }
            let shown = label(text("\(value) s", "\(value) 秒"), secondary: false)
            shown.setAccessibilityIdentifier(base + "." + spec.key + ".value")
            let stepper = CockpitPluginStepper(pluginID: plugin.id, key: spec.key)
            stepper.minValue = Double(spec.minimum); stepper.maxValue = Double(spec.maximum); stepper.increment = 1
            stepper.integerValue = value; stepper.valueWraps = false; stepper.isEnabled = !busy && entry.enabled
            stepper.target = self; stepper.action = #selector(changeSetting(_:))
            stepper.setAccessibilityIdentifier(base + "." + spec.key)
            stepper.setAccessibilityLabel(spec.title.value(language))
            subViews += [title, shown, stepper]
        }
        let flexible = NSView(); flexible.translatesAutoresizingMaskIntoConstraints = false
        flexible.setContentHuggingPriority(.init(1), for: .horizontal)
        flexible.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        subViews += [flexible, label(pin.title), pin, SettingsGrid.spacer(SettingsGrid.orderColumns)]
        let sub = NSStackView(views: subViews)
        sub.orientation = .horizontal; sub.alignment = .centerY; sub.distribution = .fill; sub.spacing = SettingsGrid.gap
        sub.setAccessibilityIdentifier(base + ".options")
        let rowColumn = NSStackView(views: [main, sub])
        rowColumn.orientation = .vertical; rowColumn.alignment = .leading; rowColumn.spacing = 2
        rowColumn.edgeInsets = .init(top: 0, left: 0, bottom: 8, right: 0)
        main.widthAnchor.constraint(equalTo: rowColumn.widthAnchor).isActive = true
        sub.widthAnchor.constraint(equalTo: rowColumn.widthAnchor).isActive = true
        rowColumn.setAccessibilityIdentifier(base)
        return rowColumn
    }
    /// A grip drop moves the plugin by the distance among the listed plugins, one visible step at a time.
    private func moveBy(_ id: String, _ delta: Int) {
        guard !busy, delta != 0 else { return }
        busy = true; rebuild()
        Task { @MainActor in
            let step = delta < 0 ? -1 : 1
            for _ in 0..<abs(delta) {
                if !(await model.perform(.move(id, step))) { break }
            }
            busy = false; rebuild()
        }
    }
    private func run(_ edit: CockpitPluginEdit) {
        guard !busy else { return }
        busy = true; rebuild()
        Task { @MainActor in
            await model.perform(edit)
            busy = false; rebuild()
        }
    }
    @objc private func toggleEnabled(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        run(.setEnabled(id, sender.state == .on))
    }
    @objc private func togglePinned(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        run(.setPinned(id, sender.state == .on))
    }
    @objc private func movePluginEarlier(_ sender: NSButton) { if let id = sender.identifier?.rawValue { run(.move(id, -1)) } }
    @objc private func movePluginLater(_ sender: NSButton) { if let id = sender.identifier?.rawValue { run(.move(id, 1)) } }
    @objc private func changeSetting(_ sender: CockpitPluginStepper) { run(.setSetting(sender.pluginID, sender.key, sender.integerValue)) }
    @objc private func chooseSetting(_ sender: CockpitPluginChoices) {
        guard sender.choices.indices.contains(sender.selectedSegment) else { return }
        run(.setSetting(sender.pluginID, sender.key, sender.choices[sender.selectedSegment]))
    }
}

@MainActor final class CockpitPluginChoices: NSSegmentedControl {
    let pluginID: String
    let key: String
    let choices: [Int]
    init(pluginID: String, key: String, choices: [Int]) {
        self.pluginID = pluginID; self.key = key; self.choices = choices
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
}

@MainActor final class CockpitPluginStepper: NSStepper {
    let pluginID: String
    let key: String
    init(pluginID: String, key: String) {
        self.pluginID = pluginID; self.key = key
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
}
