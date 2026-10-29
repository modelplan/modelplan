// SPDX-License-Identifier: MIT
import AppKit

public enum FieldPickerChangeKind: Equatable, Sendable { case selection, focus, presentation }
public struct FieldPickerChange: Sendable {
    public let kind: FieldPickerChangeKind
    public let projection: FieldPublicProjection
    public let focusedPublicID: String?
    public let expanded: Bool
    /// Existing owner persists this value only for a selection action.
    public let savedValue: Data?
}

/// Neutral native controls only. The existing owner supplies the A surface/comparison view,
/// persistence and FieldCoordinator. Construction never mounts a field or creates WebGL.
@MainActor public final class FieldFleetPickerView: NSView {
    public private(set) var state: FieldFleetPicker?
    public private(set) var presentation: FieldPickerPresentation?
    public private(set) var isPresented = false
    public var onChange: ((FieldPickerChange) -> Void)?
    private var catalogue: FieldPickerCatalogue?, locale: FieldLocale = .english
    private let stack = NSStackView(), body = NSStackView(), rows = NSStackView()
    private let title = NSButton(), search = NSSearchField(), makers = NSPopUpButton()
    private let count = NSTextField(labelWithString: ""), status = NSTextField(wrappingLabelWithString: "")
    private var controls: [NSButton] = [], rowIDs: [ObjectIdentifier: String] = [:]
    private var presetButtons: [NSButton] = [], makerIDs: [String?] = []
    private var disposed = false
    public override var isFlipped: Bool { true }
    public init(frame: CGRect = .zero, comparisonContent: NSView? = nil) {
        super.init(frame: frame)
        stack.orientation = .vertical; stack.alignment = .leading
        body.orientation = .vertical; body.alignment = .leading
        rows.orientation = .vertical; rows.alignment = .leading
        title.target = self; title.action = #selector(togglePanel)
        search.target = self; search.action = #selector(filterChanged)
        makers.target = self; makers.action = #selector(filterChanged)
        let presets = NSStackView()
        for i in 0..<3 {
            let button = NSButton(); button.tag = i; button.target = self; button.action = #selector(presetPressed(_:))
            presetButtons.append(button); presets.addArrangedSubview(button)
        }
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = rows
        rows.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([rows.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)])
        body.addArrangedSubview(presets); body.addArrangedSubview(search); body.addArrangedSubview(makers)
        if let comparisonContent { body.addArrangedSubview(comparisonContent) }
        body.addArrangedSubview(count); body.addArrangedSubview(scroll); body.addArrangedSubview(status)
        let reset = NSButton(); reset.target = self; reset.action = #selector(resetPressed); reset.identifier = .init("field.picker.reset")
        body.addArrangedSubview(reset)
        stack.addArrangedSubview(title); stack.addArrangedSubview(body); addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor), scroll.widthAnchor.constraint(equalTo: body.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)])
        isHidden = true
    }
    public required init?(coder: NSCoder) { nil }
    public func update(catalogue: FieldPickerCatalogue, locale: FieldLocale, restoring state: FieldFleetPicker? = nil) {
        guard !disposed else { return }
        self.catalogue = catalogue; self.locale = locale
        self.state = state ?? self.state ?? FieldFleetPicker(catalogue: catalogue)
        self.state?.reconcile(with: catalogue)
        if isPresented { render() }
    }
    public func setPresentationAllowed(_ allowed: Bool) {
        guard !disposed else { return }; isPresented = allowed; isHidden = !allowed
        if allowed { render() } else { retireRows() }
    }
    public func setLaunched(_ enabled: Bool, publicID: String) { change(.selection) { $0.setLaunched(enabled, publicID: publicID, in: $1) } }
    public func focus(_ publicID: String) { change(.focus) { $0.focus(publicID, in: $1) } }
    public func selectPreset(_ preset: FieldPickerPreset) { change(.selection) { $0.selectPreset(preset, in: $1); return preset != .custom } }
    public func reset() { change(.selection) { $0.reset(in: $1); return true } }
    public func setExpanded(_ expanded: Bool) { change(.presentation) { state, _ in state.setExpanded(expanded); return true } }
    public func filter(maker: String?, query: String) { change(.presentation) { state, _ in state.filter(maker: maker, query: query); return true } }
    private func change(_ kind: FieldPickerChangeKind, _ apply: (inout FieldFleetPicker, FieldPickerCatalogue) -> Bool) {
        guard !disposed, isPresented, let catalogue, var state else { return }
        let previousIDs = state.selectedIDs(in: catalogue)
        guard apply(&state, catalogue) else { return }; self.state = state; render()
        guard !disposed, isPresented, let projection = try? catalogue.projection.selecting(publicIDs: state.selectedIDs(in: catalogue)) else { return }
        onChange?(.init(kind: kind, projection: projection, focusedPublicID: state.effectiveFocus(in: catalogue), expanded: state.expanded,
                        savedValue: kind == .selection || previousIDs != state.selectedIDs(in: catalogue) ? try? state.savedValue(in: catalogue) : nil))
    }
    private func retireRows() {
        for control in controls { control.target = nil; control.action = nil }
        controls = []; rowIDs = [:]
        for row in rows.arrangedSubviews { rows.removeArrangedSubview(row); row.removeFromSuperview() }
    }
    private func render() {
        guard !disposed, isPresented, let catalogue, let state else { return }
        let p = FieldPickerPresentation(catalogue: catalogue, state: state, locale: locale); presentation = p
        retireRows(); title.title = p.title + " \(p.selectedIDs.count)/10"; body.isHidden = !p.expanded
        search.placeholderString = p.searchTitle; search.stringValue = state.query
        count.stringValue = "\(p.selectedIDs.count)/10"; status.stringValue = p.atCapacity ? p.capacityTitle : (p.rows.isEmpty ? p.emptyTitle : "")
        for (i, button) in presetButtons.enumerated() { button.title = p.presets[i]; button.state = [FieldPickerPreset.mine,.site,.all][i] == state.preset ? .on : .off }
        (body.arrangedSubviews.last as? NSButton)?.title = p.resetTitle
        makerIDs = [nil] + Array(Set(catalogue.projection.models.compactMap(\.developerId))).sorted().map(Optional.some)
        makers.removeAllItems(); makers.addItems(withTitles: makerIDs.map { $0.flatMap { catalogue.developerNames[$0] ?? $0 } ?? (locale == .english ? "All makers" : "全部厂商") })
        makers.selectItem(at: makerIDs.firstIndex(where: { $0 == state.maker }) ?? 0)
        for row in p.rows {
            let line = NSStackView(), label = NSButton(title: row.name, target: self, action: #selector(focusPressed(_:)))
            let lamp = NSButton(checkboxWithTitle: row.launched ? "✓" : "+", target: self, action: #selector(launchPressed(_:)))
            label.isEnabled = row.focusEnabled; lamp.isEnabled = row.launchEnabled; lamp.state = row.launched ? .on : .off
            let tags = NSTextField(labelWithString: row.tags.map(\.label).joined(separator: " · "))
            line.addArrangedSubview(label); line.addArrangedSubview(lamp); line.addArrangedSubview(tags); rows.addArrangedSubview(line)
            controls += [label,lamp]; rowIDs[ObjectIdentifier(label)] = row.publicID; rowIDs[ObjectIdentifier(lamp)] = row.publicID
        }
    }
    @objc private func togglePanel() { setExpanded(!(state?.expanded ?? true)) }
    @objc private func resetPressed() { reset() }
    @objc private func presetPressed(_ sender: NSButton) {
        let values = [FieldPickerPreset.mine,.site,.all]
        guard presetButtons.contains(where: { $0 === sender }), values.indices.contains(sender.tag) else { return }
        selectPreset(values[sender.tag])
    }
    @objc private func launchPressed(_ sender: NSButton) { guard sender.isEnabled, let id = rowIDs[ObjectIdentifier(sender)] else { return }; setLaunched(sender.state == .on, publicID: id) }
    @objc private func focusPressed(_ sender: NSButton) { guard sender.isEnabled, let id = rowIDs[ObjectIdentifier(sender)] else { return }; focus(id) }
    @objc private func filterChanged() { filter(maker: makerIDs.indices.contains(makers.indexOfSelectedItem) ? makerIDs[makers.indexOfSelectedItem] : nil, query: search.stringValue) }
    public func dispose() {
        guard !disposed else { return }; disposed = true; isPresented = false; isHidden = true; retireRows()
        for control in presetButtons + [title] { control.target = nil; control.action = nil }
        search.target = nil; makers.target = nil; onChange = nil; state = nil; catalogue = nil
    }
}
