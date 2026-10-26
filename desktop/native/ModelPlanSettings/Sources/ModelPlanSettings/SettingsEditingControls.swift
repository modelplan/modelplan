// SPDX-License-Identifier: MIT
import AppKit

@MainActor protocol SettingsOwnedControl: AnyObject {
    var settingKey: SettingKey { get }
    var subscriptionID: String? { get }
    var isEnabled: Bool { get set }
    var isRetired: Bool { get }
    func retire()
}

@MainActor final class SettingsActionControl: NSButton, SettingsOwnedControl {
    let settingKey: SettingKey
    let subscriptionID: String? = nil
    private(set) var isRetired = false
    var onInvoke: ((SettingsActionControl) -> Void)?
    init(key: SettingKey) {
        settingKey = key; super.init(frame: .zero); bezelStyle = .rounded
        target = self; action = #selector(invoke)
        setAccessibilityIdentifier("settings." + key.rawValue)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    @objc private func invoke() { guard isEnabled, !isRetired else { return }; onInvoke?(self) }
    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        guard isEnabled, !isRetired else { return false }; return super.sendAction(action, to: target)
    }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled, !isRetired else { return false }; return super.accessibilityPerformPress()
    }
    func retire() { isRetired = true; isEnabled = false; target = nil; action = nil; onInvoke = nil }
}

@MainActor final class SettingsAliasControl: NSTextField, NSTextFieldDelegate, SettingsOwnedControl {
    let settingKey: SettingKey = .alias
    let subscriptionID: String?
    private(set) var isRetired = false
    private(set) var editing = false
    private var committed = "", cancelled = false
    private var unconfirmedText: String?
    var hasUnsavedDraft: Bool { unconfirmedText != nil }
    private var language: SettingsLanguage = .chinese
    var onFinish: ((SettingsAliasControl, AliasDraft) -> Void)?
    var onDraftCleared: ((SettingsAliasControl) -> Void)?
    init(subscriptionID: String) {
        self.subscriptionID = subscriptionID
        super.init(frame: .zero); delegate = self; isEditable = true; isSelectable = true
        setAccessibilityIdentifier("settings.alias." + subscriptionID)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func configure(committed: String, language: SettingsLanguage) {
        self.committed = committed; self.language = language
        refreshDraft()
    }
    private func refreshDraft() {
        if !editing { stringValue = unconfirmedText ?? committed }
        setAccessibilityHelp(unconfirmedText == nil ? nil : language == .english
            ? "Not saved. Finish editing again to retry, or press Escape to cancel."
            : "尚未保存。重新结束编辑以重试，或按 Escape 取消。")
    }
    func resolveSave(submittedText: String, saved: Bool) {
        guard !isRetired, unconfirmedText == submittedText else { return }
        if saved { clearDraft() } else { refreshDraft() }
    }
    private func clearDraft() {
        let hadDraft = unconfirmedText != nil
        unconfirmedText = nil; refreshDraft()
        if hadDraft { onDraftCleared?(self) }
    }
    var draft: AliasDraft {
        var draft = AliasDraft(subscriptionID: subscriptionID!, committed: committed)
        draft.input(stringValue, composing: (currentEditor() as? NSTextView)?.hasMarkedText() == true)
        return draft
    }
    func controlTextDidBeginEditing(_ obj: Notification) { guard !isRetired else { return }; editing = true; cancelled = false }
    func controlTextDidEndEditing(_ obj: Notification) {
        guard !isRetired, !cancelled, isEnabled else { editing = false; return }
        let value = draft
        guard !value.composing else { return }
        editing = false
        guard value.text != committed else { clearDraft(); return }
        // End-editing is not a save receipt. Retain the completed text through busy/failed refreshes.
        unconfirmedText = value.text; refreshDraft()
        onFinish?(self, value)
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard !isRetired else { return true }
        // Let the input method finish/cancel marked text before interpreting Return/Escape as a form command.
        guard !textView.hasMarkedText() else { return false }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelled = true; textView.string = committed; stringValue = committed; clearDraft()
            window?.makeFirstResponder(nil); return true
        }
        return false
    }
    override func becomeFirstResponder() -> Bool { !isRetired && super.becomeFirstResponder() }
    func retire() {
        isRetired = true; cancelled = true; unconfirmedText = nil; isEnabled = false; isEditable = false; isSelectable = false
        onFinish = nil; onDraftCleared = nil; target = nil; action = nil; delegate = nil
    }
}

@MainActor final class SettingsShortcutControl: NSButton, SettingsOwnedControl {
    let settingKey: SettingKey
    let subscriptionID: String? = nil
    private(set) var isRetired = false
    private(set) var recording = false
    private var chord: ShortcutChord
    private var language: SettingsLanguage = .chinese
    var onRecord: ((SettingsShortcutControl, ShortcutChord) -> Void)?
    override var acceptsFirstResponder: Bool { !isRetired && isEnabled }
    init(key: SettingKey, chord: ShortcutChord) {
        settingKey = key; self.chord = chord
        super.init(frame: .zero); bezelStyle = .rounded; target = self; action = #selector(beginRecording)
        setAccessibilityIdentifier("settings." + key.rawValue)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func configure(chord: ShortcutChord, language: SettingsLanguage) {
        self.chord = chord; self.language = language
        if !recording { title = Self.label(chord) }
        setAccessibilityLabel(settingKey == .openShortcut
            ? (language == .english ? "Open cockpit shortcut" : "开舱快捷键")
            : (language == .english ? "Toggle dock shortcut" : "显示隐藏挂件快捷键"))
        setAccessibilityValueDescription(Self.label(chord))
        setAccessibilityHelp(language == .english ? "Press to record a shortcut. Escape cancels." : "按下以录制快捷键；Escape 取消。")
    }
    static func label(_ chord: ShortcutChord) -> String {
        let symbols: [(ShortcutChord.Modifier, String)] = [(.control,"⌃"),(.option,"⌥"),(.shift,"⇧"),(.command,"⌘")]
        return symbols.filter { chord.modifiers.contains($0.0) }.map(\.1).joined() + chord.key
    }
    @objc func beginRecording() {
        guard !isRetired, isEnabled else { return }
        window?.makeFirstResponder(self); recording = true
        title = language == .english ? "Type shortcut…" : "输入快捷键…"
    }
    @discardableResult func record(key: String, modifiers: Set<ShortcutChord.Modifier>, repeated: Bool = false) -> Bool {
        guard recording, isEnabled, !isRetired, !repeated else { return false }
        let candidate = ShortcutChord(key.uppercased(), modifiers: modifiers)
        guard candidate.isValid else { return false }
        recording = false; title = Self.label(chord); onRecord?(self, candidate); return true
    }
    private func handle(_ event: NSEvent) -> Bool {
        guard recording, !isRetired else { return false }
        if event.keyCode == 53 { cancelRecording(); return true }
        var modifiers = Set<ShortcutChord.Modifier>()
        for (flag, value) in [(NSEvent.ModifierFlags.command, ShortcutChord.Modifier.command),(.control,.control),(.option,.option),(.shift,.shift)] {
            if event.modifierFlags.contains(flag) { modifiers.insert(value) }
        }
        _ = record(key: event.charactersIgnoringModifiers ?? "", modifiers: modifiers, repeated: event.isARepeat)
        return true
    }
    override func keyDown(with event: NSEvent) { if !handle(event) { super.keyDown(with: event) } }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self, recording else { return super.performKeyEquivalent(with: event) }
        return handle(event)
    }
    private func cancelRecording() { recording = false; title = Self.label(chord) }
    override func resignFirstResponder() -> Bool { cancelRecording(); return super.resignFirstResponder() }
    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        guard !isRetired, isEnabled else { return false }; return super.sendAction(action, to: target)
    }
    override func accessibilityPerformPress() -> Bool {
        guard !isRetired, isEnabled else { return false }; return super.accessibilityPerformPress()
    }
    func retire() { isRetired = true; isEnabled = false; cancelRecording(); target = nil; action = nil; onRecord = nil }
}
