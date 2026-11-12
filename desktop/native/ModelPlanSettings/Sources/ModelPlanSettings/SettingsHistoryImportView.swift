// SPDX-License-Identifier: MIT
import AppKit

/// Settings › Data & Privacy: "Import usage history" with the day count, progress, cancel and
/// remove. Constructing or re-rendering it sends nothing; only its buttons do.
@MainActor public final class SettingsHistoryImportView: NSStackView {
    private let model: HistoryImportModel
    private var language: SettingsLanguage
    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(wrappingLabelWithString: "")
    private let days = NSPopUpButton(frame: .zero, pullsDown: false)
    private let start = NSButton(), cancel = NSButton(), remove = NSButton()
    private let progress = NSProgressIndicator()
    private let line = NSTextField(wrappingLabelWithString: "")
    private var observer: UUID?

    public init(model: HistoryImportModel, language: SettingsLanguage) {
        self.model = model; self.language = language
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 8
        edgeInsets = .init(top: 14, left: 8, bottom: 14, right: 8)
        setAccessibilityIdentifier("settings.historyImport")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        subtitle.font = .systemFont(ofSize: 12); subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 0
        line.font = .systemFont(ofSize: 12); line.textColor = .secondaryLabelColor; line.maximumNumberOfLines = 0
        progress.style = .bar; progress.isIndeterminate = false; progress.minValue = 0; progress.maxValue = 1
        for (button, id) in [(start, "start"), (cancel, "cancel"), (remove, "remove")] {
            button.bezelStyle = .rounded; button.setAccessibilityIdentifier("settings.historyImport." + id)
            button.target = self
        }
        start.action = #selector(startTapped); cancel.action = #selector(cancelTapped); remove.action = #selector(removeTapped)
        days.setAccessibilityIdentifier("settings.historyImport.days"); days.target = self; days.action = #selector(daysChanged)
        let controls = NSStackView(views: [days, start, cancel, remove]); controls.orientation = .horizontal; controls.spacing = 8
        for view in [title, subtitle, controls, progress, line] { addArrangedSubview(view) }
        for view in [subtitle, line, progress] { view.widthAnchor.constraint(equalTo: widthAnchor, constant: -16).isActive = true }
        observer = model.observe { [weak self] in self?.render() }
        render()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    deinit { if let observer { let model = model; Task { @MainActor in model.removeObserver(observer) } } }

    public func apply(language: SettingsLanguage) { guard self.language != language else { return }; self.language = language; render() }
    public override func layout() {
        super.layout()
        for label in [subtitle, line] where label.bounds.width > 0 && abs(label.preferredMaxLayoutWidth - label.bounds.width) > 0.5 {
            label.preferredMaxLayoutWidth = label.bounds.width; label.invalidateIntrinsicContentSize()
        }
    }
    private func render() {
        title.stringValue = HistoryImportText.title.value(language)
        subtitle.stringValue = HistoryImportText.subtitle.value(language)
        days.removeAllItems()
        for choice in HistoryImportModel.dayChoices { days.addItem(withTitle: HistoryImportText.dayChoice(choice).value(language)); days.lastItem?.tag = choice }
        days.selectItem(withTag: model.days)
        days.setAccessibilityLabel(HistoryImportText.daysLabel.value(language))
        start.title = HistoryImportText.importButton.value(language); cancel.title = HistoryImportText.cancelButton.value(language)
        remove.title = HistoryImportText.removeButton.value(language)
        start.isEnabled = model.canStart; days.isEnabled = !model.isRunning
        cancel.isHidden = !model.isRunning; cancel.isEnabled = model.isRunning
        remove.isEnabled = model.canRemove
        progress.isHidden = !model.isRunning
        if let fraction = model.fraction { progress.isIndeterminate = false; progress.doubleValue = fraction }
        else if model.isRunning { progress.isIndeterminate = true; progress.startAnimation(nil) }
        line.stringValue = HistoryImportText.line(model).value(language)
        line.isHidden = line.stringValue.isEmpty
    }
    @objc private func startTapped() { Task { await model.start() } }
    @objc private func cancelTapped() { Task { await model.cancel() } }
    @objc private func removeTapped() { Task { await model.remove() } }
    @objc private func daysChanged() { if let tag = days.selectedItem?.tag { model.days = tag } }
    /// For the read-only seam: the visible texts, no events.
    public var visibleText: [String] { [title, subtitle, line].map(\.stringValue) }
}
