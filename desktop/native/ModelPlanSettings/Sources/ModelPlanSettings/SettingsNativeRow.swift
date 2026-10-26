// SPDX-License-Identifier: MIT
import AppKit

@MainActor final class SettingsNativeRow: NSStackView {
    let key: SettingKey
    let titleLabel = NSTextField(labelWithString: "")
    let subtitle = NSTextField(labelWithString: "")
    let group = NSTextField(labelWithString: "")
    let controls = NSStackView()
    let illustration = NSView()
    var diagram: SettingsDiagramView?
    var choices: [String: SettingsChoiceControl] = [:]
    var aliases: [String: SettingsAliasControl] = [:]
    var shortcut: SettingsShortcutControl?
    var order: SettingsOrderControl?
    var resetHints: SettingsActionControl?
    private var aliasLines: [String: NSStackView] = [:]
    private var aliasLabels: [String: NSTextField] = [:]
    private var subscriptionLabels: [String: NSTextField] = [:]
    private var readerDescriptions: [String: NSTextField] = [:]
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
            readout.widthAnchor.constraint(lessThanOrEqualToConstant: 230),
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
        for field in aliases.values { field.retire() }
        shortcut?.retire(); order?.retire(); resetHints?.retire()
        for view in controls.arrangedSubviews { controls.removeArrangedSubview(view); view.removeFromSuperview() }
        choices = [:]; subscriptionLabels = [:]; readerDescriptions = [:]; controlIDs = []
        aliases = [:]; aliasLines = [:]; aliasLabels = [:]; shortcut = nil; order = nil; resetHints = nil
    }

    func owns(_ view: NSView) -> Bool {
        choices.values.contains { $0 === view } || aliases.values.contains { $0 === view }
            || shortcut === view || order === view || resetHints === view
    }

    func apply(_ row: SettingsRow, language: SettingsLanguage, saving: Bool, input: SettingsDiagramInput?,
               reduced: Bool, onChoice: Selector, target: AnyObject, showGroup: Bool,
               snapshot: SettingsSnapshot, context: SettingsPageContext, holdAvailable: Bool,
               onEdit: @escaping (NSView & SettingsOwnedControl, SettingsB21Edit) -> Void) {
        let p = snapshot.preferences
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
        let enabled = (SettingsB20Edit.keys.contains(key) || SettingsB21Edit.keys.contains(key)) && row.availability == .available
        if key == .alias, case .subscriptions(let subs) = row.value {
            configureAliases(subs, enabled: enabled && !saving, language: language, onEdit: onEdit); return
        }
        if key == .order {
            configureOrder(p, context: context, enabled: enabled && !saving, language: language, onEdit: onEdit); return
        }
        if key == .openShortcut || key == .dockShortcut {
            configureShortcut(p, context: context, enabled: enabled && !saving, language: language, onEdit: onEdit); return
        }
        if key == .resetHints {
            if resetHints == nil {
                retireControls(); let button = SettingsActionControl(key: .resetHints)
                button.onInvoke = { onEdit($0, .resetHints) }; resetHints = button; controls.addArrangedSubview(button)
            }
            resetHints?.title = row.title.value(language); resetHints?.isEnabled = enabled && !saving; return
        }
        var values: [(String, String, String, [String])] = []
        switch row.value {
        case .choice(let value, let options): values = [("", "", value, options)]
        case .toggle(let value): values = [("", "", String(value), ["true", "false"])]
        case .subscriptions(let subs) where key == .percentagePin || key == .visible:
            values = subs.map { ($0.id, [$0.name, $0.plan].filter { !$0.isEmpty }.joined(separator: " · "), $0.value, $0.options) }
        case .login(let login): values = [("", "", String(login.requestedEnabled), ["true", "false"])]
        case .readers(let readers) where key == .optionalReaders:
            values = readers.compactMap { reader in reader.consent.map { (reader.id.rawValue, reader.title, String($0), ["true", "false"]) } }
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
                    name.setContentHuggingPriority(.defaultLow, for: .horizontal)
                    subscriptionLabels[id] = name
                    name.lineBreakMode = .byTruncatingTail; name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    let line = NSStackView(views: [name, popup]); line.spacing = 6; line.distribution = .fill
                    if case .readers(let readers) = row.value, let reader = readers.first(where: { $0.id.rawValue == id }) {
                        let description = NSTextField(labelWithString: reader.description.value(language))
                        readerDescriptions[id] = description
                        description.font = .systemFont(ofSize: 11); description.textColor = .secondaryLabelColor
                        description.lineBreakMode = .byTruncatingTail
                        let block = NSStackView(views: [line,description]); block.orientation = .vertical; block.alignment = .leading
                        controls.addArrangedSubview(block)
                        line.widthAnchor.constraint(equalTo: controls.widthAnchor).isActive = true
                        block.widthAnchor.constraint(equalTo: controls.widthAnchor).isActive = true
                        description.widthAnchor.constraint(equalTo: controls.widthAnchor).isActive = true
                    } else { controls.addArrangedSubview(line); line.widthAnchor.constraint(equalTo: controls.widthAnchor).isActive = true }
                }
            }
            if values.isEmpty { controls.addArrangedSubview(readout) }
        }
        for (id, label, value, options) in values {
            guard let popup = choices[id] else { continue }
            subscriptionLabels[id]?.stringValue = label
            popup.configure(value: value, options: options, key: key, language: language)
            popup.isEnabled = enabled && !saving
            if key == .countdown { popup.isEnabled = popup.isEnabled && holdAvailable && p.opening == .hold }
            if key == .opening { popup.itemArray.first { $0.representedObject as? String == "hold" }?.isEnabled = holdAvailable }
            popup.setAccessibilityLabel([row.title.value(language), label].filter { !$0.isEmpty }.joined(separator: " · "))
            popup.setAccessibilityHelp(enabled ? row.subtitle.value(language) : SettingsWords.text("Not editable in this build.", "此版本暂不提供编辑。", language))
            if case .readers(let readers) = row.value, let reader = readers.first(where: { $0.id.rawValue == id }) {
                readerDescriptions[id]?.stringValue = reader.description.value(language) + " · " + Self.readerStatus(reader.observation, language: language)
            }
        }
        if values.isEmpty {
            if key == .percentagePin { readout.stringValue = SettingsWords.text("No subscriptions detected", "尚未检测到订阅", language) }
            else if key == .captureHiding { readout.stringValue = SettingsWords.text("Unavailable", "不可用", language) }
            else if case .subscriptions(let subs) = row.value {
                readout.stringValue = subs.map { $0.name + " · " + Self.sourceStatus($0.value, language: language) }.joined(separator: "\n")
            }
            else if case .readers(let readers) = row.value {
                readout.stringValue = readers.map { $0.title + " · " + Self.readerStatus($0.observation, language: language) + "\n" + $0.description.value(language) }.joined(separator: "\n")
            }
            else if case .text(let text) = row.value { readout.stringValue = text }
            else { readout.stringValue = SettingsWords.text("Not available in this build", "此版本暂不可用", language) }
        }
        let status: String
        switch key {
        case .login: status = Self.loginStatus(context.capabilities.login, language: language)
        case .automaticUpdates: status = context.capabilities.updateServiceAvailable
            ? SettingsWords.text("Update service available", "更新服务可用", language)
            : SettingsWords.text("Update service unavailable", "更新服务不可用", language)
        case .opening, .countdown: status = holdAvailable ? "" : SettingsWords.text("Currently opens quickly", "当前使用快速打开", language)
        default: status = ""
        }
        if !status.isEmpty {
            if readout.superview == nil { controls.addArrangedSubview(readout) }
            readout.stringValue = status; readout.isHidden = false
        } else if !values.isEmpty { readout.isHidden = true }
    }

    private func configureAliases(_ subs: [SubscriptionRowValue], enabled: Bool, language: SettingsLanguage,
                                  onEdit: @escaping (NSView & SettingsOwnedControl, SettingsB21Edit) -> Void) {
        let ids = Set(subs.map(\.id))
        for id in Array(aliases.keys) where !ids.contains(id) {
            aliases.removeValue(forKey: id)?.retire()
            if let line = aliasLines.removeValue(forKey: id) { controls.removeArrangedSubview(line); line.removeFromSuperview() }
            aliasLabels.removeValue(forKey: id)
        }
        for (index, sub) in subs.enumerated() {
            if aliases[sub.id] == nil {
                let field = SettingsAliasControl(subscriptionID: sub.id); aliases[sub.id] = field
                field.widthAnchor.constraint(equalToConstant: 132).isActive = true; field.font = .systemFont(ofSize: 12)
                field.onFinish = { onEdit($0, .alias($1)) }
                let label = NSTextField(labelWithString: sub.name); label.font = .systemFont(ofSize: 12)
                label.setContentHuggingPriority(.defaultLow, for: .horizontal)
                label.lineBreakMode = .byTruncatingTail; label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                aliasLabels[sub.id] = label
                let line = NSStackView(views: [label,field]); line.spacing = 6; line.distribution = .fill; aliasLines[sub.id] = line
                controls.insertArrangedSubview(line, at: index); line.widthAnchor.constraint(equalTo: controls.widthAnchor).isActive = true
            }
            let field = aliases[sub.id]!, line = aliasLines[sub.id]!
            if controls.arrangedSubviews[index] !== line { controls.removeArrangedSubview(line); controls.insertArrangedSubview(line, at: index) }
            aliasLabels[sub.id]?.stringValue = sub.name
            field.configure(committed: sub.value); field.isEnabled = enabled || field.editing
            field.setAccessibilityLabel(SettingsWords.text("Alias: ", "别名：", language) + sub.name)
        }
        if subs.isEmpty {
            if readout.superview == nil { controls.addArrangedSubview(readout) }
            readout.stringValue = SettingsWords.text("No subscriptions detected", "尚未检测到订阅", language)
        } else if readout.superview != nil { controls.removeArrangedSubview(readout); readout.removeFromSuperview() }
    }
    private func configureOrder(_ p: SettingsPreferences, context: SettingsPageContext, enabled: Bool, language: SettingsLanguage,
                                onEdit: @escaping (NSView & SettingsOwnedControl, SettingsB21Edit) -> Void) {
        if order == nil {
            retireControls(); let view = SettingsOrderControl(frame: .zero); order = view; controls.addArrangedSubview(view)
            view.onMove = { onEdit($0, .moveSubscription($1, to: $2, expectedOrder: $3)) }
            view.onReset = { onEdit($0, .resetOrder) }
        }
        let ids = (try? p.presentedSubscriptionIDs(context.subscriptions.map(\.id), includingHidden: true)) ?? []
        var names = [String: String]()
        for sub in context.subscriptions {
            let alias = p.subscriptionSettings[sub.id]?.alias ?? ""
            names[sub.id] = (alias.isEmpty ? sub.name.value(language) : alias)
                + (p.subscriptions.hiddenIDs.contains(sub.id) ? SettingsWords.text(" (hidden)", "（隐藏）", language) : "")
        }
        order?.configure(ids: ids, names: names, language: language, canReset: !p.subscriptions.order.isEmpty)
        order?.isEnabled = enabled
    }
    private func configureShortcut(_ p: SettingsPreferences, context: SettingsPageContext, enabled: Bool, language: SettingsLanguage,
                                   onEdit: @escaping (NSView & SettingsOwnedControl, SettingsB21Edit) -> Void) {
        let action: ShortcutAction = key == .openShortcut ? .openCockpit : .toggleDock
        let chord = action == .openCockpit ? p.openShortcut : p.dockShortcut
        if shortcut == nil {
            retireControls(); let recorder = SettingsShortcutControl(key: key, chord: chord); shortcut = recorder
            recorder.onRecord = { onEdit($0, .shortcut(action, $1)) }; controls.addArrangedSubview(recorder)
        }
        shortcut?.configure(chord: chord, language: language); shortcut?.isEnabled = enabled
        let policy = context.shortcutPolicy(preferences: p)
        let state = action == .openCockpit ? policy.openRegistration : policy.dockRegistration
        let status: String
        switch state {
        case .registered: status = SettingsWords.text("Global shortcut registered", "全局快捷键已注册", language)
        case .conflict: status = SettingsWords.text("Global conflict; works in app", "全局冲突；应用内可用", language)
        case .denied: status = SettingsWords.text("Global access denied; works in app", "全局访问被拒绝；应用内可用", language)
        case .unavailable: status = SettingsWords.text("Global unavailable; works in app", "全局不可用；应用内可用", language)
        case .notRequested: status = SettingsWords.text("Not registered; works in app", "未注册；应用内可用", language)
        }
        if readout.superview == nil { controls.addArrangedSubview(readout) }
        readout.stringValue = status; readout.isHidden = false
    }
    private static func loginStatus(_ state: LoginServiceState, language: SettingsLanguage) -> String {
        switch state {
        case .notRegistered: return SettingsWords.text("System: not registered", "系统：未注册", language)
        case .enabled: return SettingsWords.text("System: enabled", "系统：已开启", language)
        case .requiresApproval: return SettingsWords.text("System: approval required", "系统：需要批准", language)
        case .unavailable: return SettingsWords.text("System service unavailable", "系统服务不可用", language)
        }
    }
    private static func sourceStatus(_ raw: String, language: SettingsLanguage) -> String {
        switch SubscriptionSourceState(rawValue: raw) {
        case .fresh: return SettingsWords.text("Current", "最新", language)
        case .stale: return SettingsWords.text("Stale", "数据已过时", language)
        case .denied: return SettingsWords.text("Access denied", "访问被拒绝", language)
        case .readerDisabled: return SettingsWords.text("Reader disabled", "读取器已关闭", language)
        default: return SettingsWords.text("Unavailable", "不可用", language)
        }
    }
    private static func readerStatus(_ state: ReaderObservation, language: SettingsLanguage) -> String {
        switch state {
        case .detected: return SettingsWords.text("Detected", "已检测到", language)
        case .denied: return SettingsWords.text("Access denied", "访问被拒绝", language)
        case .unavailable: return SettingsWords.text("Unavailable", "不可用", language)
        case .unknown: return SettingsWords.text("Not observed", "尚未观测", language)
        }
    }
}
