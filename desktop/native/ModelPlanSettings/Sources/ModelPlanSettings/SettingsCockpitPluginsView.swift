// SPDX-License-Identifier: MIT
import AppKit

/// Settings › Subscriptions › "Plugins" (CKP-PLG-54, D293): one row per plugin with its white line icon, one sentence,
/// an on/off toggle, its options (for example a sampling interval of 3–30 seconds) and "Pin to page 1" (at most two).
/// Turning a plugin off here is the same edit as Remove in the cockpit key's right-click menu. Shown on the
/// Subscriptions pane, after the subscription rows, and for matching searches.
@MainActor public final class SettingsCockpitPluginsView: NSView {
    public let model: CockpitPluginSettingsModel
    private var language: SettingsLanguage
    private let heading = NSTextField(labelWithString: "")
    private let note = NSTextField(wrappingLabelWithString: "")
    private let list = NSStackView()
    private var busy = false
    public init(model: CockpitPluginSettingsModel, language: SettingsLanguage) {
        self.model = model; self.language = language
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityIdentifier("settings.cockpitPlugins"); isHidden = true
        heading.font = .systemFont(ofSize: 12, weight: .semibold)
        heading.setAccessibilityIdentifier("settings.section.subscriptions.plugins")
        note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
        list.orientation = .vertical; list.alignment = .leading; list.spacing = 6
        let stack = NSStackView(views: [heading, note, list])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        rebuild()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    /// The pane that shows the section (WP-16 moved it from Cockpit to Subscriptions).
    public static let paneID = "subscriptions"
    /// Re-labels and shows the section on the Subscriptions pane, or for a search that names it.
    public func apply(language: SettingsLanguage, paneID: String, query: String) {
        self.language = language
        isHidden = query.isEmpty ? paneID != Self.paneID
            : !["plugin", "subscription", "cockpit", "插件", "订阅", "驾驶舱"].contains(where: { query.localizedCaseInsensitiveContains($0) })
        rebuild()
    }
    private func text(_ en: String, _ zh: String) -> String { SettingsWords.text(en, zh, language) }

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
        let prefs = model.preferences.materialized(model.catalogue)
        let listed = CockpitPluginCatalogue.listed(model.catalogue)
        let known = prefs.entries.filter { entry in listed.contains(where: { $0.id == entry.id }) }
        for (index, entry) in known.enumerated() {
            guard let plugin = listed.first(where: { $0.id == entry.id }) else { continue }
            list.addArrangedSubview(row(plugin, entry: entry, first: index == 0, last: index == known.count - 1, prefs: prefs))
        }
    }
    private func button(_ title: String, id: String, action: Selector, enabled: Bool = true) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded; b.controlSize = .small; b.isEnabled = enabled && !busy
        b.setAccessibilityIdentifier(id)
        return b
    }
    private func row(_ plugin: CockpitPluginDefinition, entry: CockpitPluginEntry, first: Bool, last: Bool, prefs: CockpitPluginPreferences) -> NSView {
        let base = "settings.cockpitPlugins.\(plugin.id)"
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: plugin.symbol, accessibilityDescription: nil)
        icon.contentTintColor = .labelColor; icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        icon.setAccessibilityIdentifier(base + ".icon")
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true; icon.heightAnchor.constraint(equalToConstant: 16).isActive = true
        let on = NSButton(checkboxWithTitle: plugin.title.value(language), target: self, action: #selector(toggleEnabled(_:)))
        on.state = entry.enabled ? .on : .off; on.identifier = .init(plugin.id); on.isEnabled = !busy
        on.setAccessibilityIdentifier(base + ".enabled")
        let pin = NSButton(checkboxWithTitle: text("Pin to page 1", "固定到第 1 页"), target: self, action: #selector(togglePinned(_:)))
        pin.state = entry.pinned ? .on : .off; pin.identifier = .init(plugin.id)
        pin.isEnabled = !busy && (entry.pinned || prefs.canPin(plugin.id, model.catalogue))
        pin.setAccessibilityIdentifier(base + ".pinned")
        if !entry.pinned, entry.enabled, !prefs.canPin(plugin.id, model.catalogue) {
            pin.toolTip = text("Two plugins are already pinned.", "已经固定了两个插件。")
        }
        let up = button("↑", id: base + ".up", action: #selector(movePluginEarlier(_:)), enabled: !first)
        up.identifier = .init(plugin.id); up.setAccessibilityLabel(text("Move earlier", "前移"))
        let down = button("↓", id: base + ".down", action: #selector(movePluginLater(_:)), enabled: !last)
        down.identifier = .init(plugin.id); down.setAccessibilityLabel(text("Move later", "后移"))
        let line = NSStackView(views: [icon, on, pin, up, down])
        line.orientation = .horizontal; line.spacing = 10; line.alignment = .centerY
        let summary = NSTextField(wrappingLabelWithString: plugin.summary.value(language))
        summary.font = .systemFont(ofSize: 11); summary.textColor = .secondaryLabelColor
        summary.setAccessibilityIdentifier(base + ".summary")
        let summaryLine = NSStackView(views: [summary])
        summaryLine.edgeInsets = .init(top: 0, left: 26, bottom: 0, right: 0)
        var views: [NSView] = [line, summaryLine]
        // The per-plugin settings slot: one stepper per declared setting, or one segmented control when the
        // setting lists its choices (the resource plugin's 2 / 5 / 10 s, D324).
        for spec in plugin.settings {
            let value = prefs.value(plugin.id, spec.key, model.catalogue) ?? spec.defaultValue
            let label = NSTextField(labelWithString: spec.title.value(language))
            label.font = .systemFont(ofSize: 12); label.textColor = .secondaryLabelColor
            if !spec.choices.isEmpty {
                let control = CockpitPluginChoices(pluginID: plugin.id, key: spec.key, choices: spec.choices)
                control.segmentCount = spec.choices.count; control.trackingMode = .selectOne
                for (i, choice) in spec.choices.enumerated() {
                    control.setLabel(text("\(choice) s", "\(choice) 秒"), forSegment: i)
                    control.setWidth(0, forSegment: i)
                }
                control.selectedSegment = spec.choices.firstIndex(of: value) ?? -1
                control.isEnabled = !busy && entry.enabled
                control.target = self; control.action = #selector(chooseSetting(_:))
                control.setAccessibilityIdentifier(base + "." + spec.key)
                control.setAccessibilityLabel(spec.title.value(language))
                let settingLine = NSStackView(views: [label, control])
                settingLine.orientation = .horizontal; settingLine.spacing = 8; settingLine.alignment = .centerY
                settingLine.edgeInsets = .init(top: 0, left: 26, bottom: 0, right: 0)
                views.append(settingLine)
                continue
            }
            let shown = NSTextField(labelWithString: text("\(value) s", "\(value) 秒"))
            shown.setAccessibilityIdentifier(base + "." + spec.key + ".value")
            let stepper = CockpitPluginStepper(pluginID: plugin.id, key: spec.key)
            stepper.minValue = Double(spec.minimum); stepper.maxValue = Double(spec.maximum); stepper.increment = 1
            stepper.integerValue = value; stepper.valueWraps = false; stepper.isEnabled = !busy && entry.enabled
            stepper.target = self; stepper.action = #selector(changeSetting(_:))
            stepper.setAccessibilityIdentifier(base + "." + spec.key)
            stepper.setAccessibilityLabel(spec.title.value(language))
            let settingLine = NSStackView(views: [label, shown, stepper])
            settingLine.orientation = .horizontal; settingLine.spacing = 8; settingLine.alignment = .centerY
            settingLine.edgeInsets = .init(top: 0, left: 26, bottom: 0, right: 0)
            views.append(settingLine)
        }
        let column = NSStackView(views: views)
        column.orientation = .vertical; column.alignment = .leading; column.spacing = 4
        column.setAccessibilityIdentifier(base)
        return column
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
