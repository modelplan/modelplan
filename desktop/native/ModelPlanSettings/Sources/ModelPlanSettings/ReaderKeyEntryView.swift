// SPDX-License-Identifier: MIT
import AppKit

/// The small "enter a key" fix action for one key-only provider: a secure field, a Global/China
/// picker (GLM only), Test, Save and Remove, and one line of help. It is created once and reused, so
/// re-rendering the Subscriptions area never clears what the user is typing.
@MainActor final class ReaderKeyEntryView: NSStackView, NSTextFieldDelegate {
    let entry: ReaderKeyEntry
    private var language: SettingsLanguage
    private let title = NSTextField(labelWithString: "")
    private let field = NSSecureTextField()
    private let picker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let help = NSTextField(wrappingLabelWithString: "")
    private let result = NSTextField(wrappingLabelWithString: "")
    private var test: ConnectionButton!
    private var save: ConnectionButton!
    private var remove: ConnectionButton!
    var buttons: [ConnectionButton] { [test, save, remove] }

    init(entry: ReaderKeyEntry, language: SettingsLanguage) {
        self.entry = entry; self.language = language
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 6
        let id = "readerkey." + entry.provider.rawValue
        setAccessibilityIdentifier(id)
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        field.setAccessibilityIdentifier(id + ".field"); field.delegate = self
        field.setAccessibilityLabel("API key")
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
        picker.setAccessibilityIdentifier(id + ".region")
        for region in ReaderKeyRegion.allCases { picker.addItem(withTitle: ""); picker.lastItem?.representedObject = region.rawValue }
        picker.target = self; picker.action = #selector(regionChanged)
        help.font = .systemFont(ofSize: 11); help.textColor = .secondaryLabelColor
        result.font = .systemFont(ofSize: 12); result.setAccessibilityIdentifier(id + ".result")
        test = ConnectionButton(title: "", identifier: id + ".test") { [weak self] in
            guard let entry = self?.entry else { return }; Task { @MainActor in await entry.test() }
        }
        save = ConnectionButton(title: "", identifier: id + ".save") { [weak self] in
            guard let entry = self?.entry else { return }; Task { @MainActor in await entry.save() }
        }
        remove = ConnectionButton(title: "", identifier: id + ".remove") { [weak self] in
            guard let entry = self?.entry else { return }; Task { @MainActor in await entry.remove() }
        }
        addArrangedSubview(title)
        if entry.provider.hasRegion { addArrangedSubview(picker) }
        addArrangedSubview(field)
        addArrangedSubview(NSStackView(views: [test, save, remove]))
        addArrangedSubview(help)
        addArrangedSubview(result)
        entry.onChange = { [weak self] in self?.refresh() }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    func apply(language: SettingsLanguage) { self.language = language; refresh() }

    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as AnyObject? === field else { return }
        entry.setTyped(field.stringValue)
    }
    @objc private func regionChanged() {
        if let raw = picker.selectedItem?.representedObject as? String, let region = ReaderKeyRegion(rawValue: raw) { entry.region = region }
    }

    private func refresh() {
        title.stringValue = entry.provider.title.value(language)
        field.placeholderString = language == .english ? "Paste your API key" : "粘贴你的 API 密钥"
        if field.stringValue != entry.typed { field.stringValue = entry.typed }
        for (index, region) in ReaderKeyRegion.allCases.enumerated() {
            picker.item(at: index)?.title = region.title.value(language)
            if region == entry.region { picker.selectItem(at: index) }
        }
        test.title = language == .english ? "Test" : "测试"
        save.title = language == .english ? "Save" : "保存"
        remove.title = language == .english ? "Remove" : "移除"
        test.isEnabled = entry.canTest; save.isEnabled = entry.canSave; remove.isEnabled = entry.canRemove
        field.isEnabled = !entry.isBusy; picker.isEnabled = !entry.isBusy
        help.stringValue = entry.provider.help.value(language)
        result.stringValue = entry.isBusy ? (language == .english ? "Checking…" : "检查中…") : (entry.message?.value(language) ?? "")
        result.isHidden = result.stringValue.isEmpty
    }
}

/// The whole optional "add a key" area: a heading, one sentence, and one entry per key-only provider.
/// Created once per host and reused, so re-rendering the host never clears what is being typed.
@MainActor final class ReaderKeySection: NSStackView {
    private let entries: [ReaderKeyEntryView]
    private let heading = NSTextField(wrappingLabelWithString: "")
    private let note = NSTextField(wrappingLabelWithString: "")
    private var language: SettingsLanguage

    init(backend: ReaderKeyBackend, language: SettingsLanguage) {
        self.language = language
        entries = ReaderKeyProvider.allCases.map { ReaderKeyEntryView(entry: .init(provider: $0, backend: backend), language: language) }
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 8
        setAccessibilityIdentifier("readerkey.section")
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        note.font = .systemFont(ofSize: 12); note.textColor = .secondaryLabelColor
        addArrangedSubview(heading); addArrangedSubview(note)
        for entry in entries { addArrangedSubview(entry) }
        refresh()
        for entry in entries { let model = entry.entry; Task { @MainActor in await model.load() } }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    func apply(language: SettingsLanguage) {
        self.language = language; for entry in entries { entry.apply(language: language) }; refresh()
    }
    func dismiss() { for entry in entries { entry.entry.dismiss() } }
    private func refresh() {
        heading.stringValue = language == .english ? "Add a key (optional)" : "添加密钥（可选）"
        note.stringValue = language == .english
            ? "Sign-ins found on this Mac are used first. Enter a key only when none is found."
            : "会先使用本机上已找到的登录；没有可用登录时再输入密钥。"
    }
}
