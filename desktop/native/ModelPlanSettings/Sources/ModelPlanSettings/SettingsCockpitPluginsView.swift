// SPDX-License-Identifier: MIT
import AppKit

/// Settings › Cockpit › "Cockpit plugins" (v1.1, D121/D124/D127): turn plugins on or off (off is the cockpit key's
/// ×), change their order, pin up to two to the engine table's first page, and each plugin's own settings
/// (for example a sampling interval of 3–30 seconds). Shown on the Cockpit pane and for matching searches.
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
        heading.setAccessibilityIdentifier("settings.section.cockpit.plugins")
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

    /// Re-labels and shows the section on the Cockpit pane, or for a search that names it.
    public func apply(language: SettingsLanguage, paneID: String, query: String) {
        self.language = language
        isHidden = query.isEmpty ? paneID != "cockpit"
            : !["plugin", "cockpit", "插件", "驾驶舱"].contains(where: { query.localizedCaseInsensitiveContains($0) })
        rebuild()
    }
    private func text(_ en: String, _ zh: String) -> String { SettingsWords.text(en, zh, language) }

    /// One row per catalogued plugin, in the saved order.
    func rebuild() {
        heading.stringValue = text("Cockpit plugins", "驾驶舱插件")
        note.stringValue = text("Plugins fill empty engine-table columns after your subscriptions. A pinned plugin stays on the first page (at most two).",
                                "插件放在订阅后面的空列里。固定的插件始终留在第一页（最多两个）。")
        for view in list.arrangedSubviews { list.removeArrangedSubview(view); view.removeFromSuperview() }
        let prefs = model.preferences.materialized(model.catalogue)
        let known = prefs.entries.filter { entry in model.catalogue.contains(where: { $0.id == entry.id }) }
        for (index, entry) in known.enumerated() {
            guard let plugin = model.catalogue.first(where: { $0.id == entry.id }) else { continue }
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
        let on = NSButton(checkboxWithTitle: plugin.title.value(language), target: self, action: #selector(toggleEnabled(_:)))
        on.state = entry.enabled ? .on : .off; on.identifier = .init(plugin.id); on.isEnabled = !busy
        on.setAccessibilityIdentifier(base + ".enabled")
        let pin = NSButton(checkboxWithTitle: text("Pin to first page", "固定在第一页"), target: self, action: #selector(togglePinned(_:)))
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
        let line = NSStackView(views: [on, pin, up, down])
        line.orientation = .horizontal; line.spacing = 10; line.alignment = .centerY
        var views: [NSView] = [line]
        // The per-plugin settings slot: one stepper per declared setting.
        for spec in plugin.settings {
            let value = prefs.value(plugin.id, spec.key, model.catalogue) ?? spec.defaultValue
            let label = NSTextField(labelWithString: spec.title.value(language))
            label.font = .systemFont(ofSize: 12); label.textColor = .secondaryLabelColor
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
            settingLine.edgeInsets = .init(top: 0, left: 22, bottom: 0, right: 0)
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
