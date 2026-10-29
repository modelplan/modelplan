// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanAssembly
import ModelPlanInstruments
import ModelPlanCockpitShell
import ModelPlanField

@MainActor public protocol CommunityFieldWindow: AnyObject {
    func show(content: NSView, onClose: @escaping () -> Void)
    func hide()
}

/// Created only after an explicit enlarge action. Never used by factory construction or normal stills.
@MainActor final class CommunityFieldPanel: NSObject, CommunityFieldWindow, NSWindowDelegate {
    private var panel: NSPanel?
    private var onClose: (() -> Void)?
    func show(content: NSView, onClose: @escaping () -> Void) {
        self.onClose = onClose
        if panel == nil {
            let p = NSPanel(contentRect: .init(x: 0, y: 0, width: 760, height: 620),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            p.title = "ModelPlan"; p.isReleasedWhenClosed = false; p.delegate = self; panel = p
        }
        panel?.contentView = content; panel?.center(); panel?.makeKeyAndOrderFront(nil)
    }
    func hide() { panel?.orderOut(nil); onClose = nil }
    func windowShouldClose(_ sender: NSWindow) -> Bool { onClose?(); return false }
}

/// Neutral comparison of already published values. No scores, recommendations, private art or WebGL.
@MainActor private final class CommunityFieldComparison: NSStackView {
    private(set) var focusedID: String?
    override init(frame: NSRect) { super.init(frame: frame); orientation = .vertical; alignment = .leading }
    required init?(coder: NSCoder) { nil }
    func apply(_ projection: FieldPublicProjection, focus: String?, locale: FieldLocale) throws {
        guard focus.map({ id in projection.models.contains { $0.id == id } }) ?? true else { throw FieldPickerConnectionError.disconnected }
        for v in arrangedSubviews { removeArrangedSubview(v); v.removeFromSuperview() }
        for model in projection.models {
            let effort = model.efforts.first { $0.effort == model.recommended }
            let values = [effort?.ability, effort?.cost, effort?.time].map { $0.map { String(format: "%.2f", $0) } ?? "--" }.joined(separator: " / ")
            let label = NSTextField(labelWithString: (focus == model.id ? "▸ " : "") + (model.name ?? model.id) + "  " + values)
            label.setAccessibilityIdentifier("field.public." + model.id); addArrangedSubview(label)
        }
        setAccessibilityLabel(locale == .english ? "Published ability / cost / task time" : "已发布能力 / 成本 / 任务耗时")
        focusedID = focus
    }
}

/// The normal leaf applies the same supplier aperture to every pointer hit, including children.
@MainActor private final class CommunityFieldNormalView: NSStackView {
    var containsFieldPoint: (CGPoint, CGSize) -> Bool = { _, _ in false }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard !isHiddenOrHasHiddenAncestor, local.x.isFinite, local.y.isFinite,
              bounds.contains(local), containsFieldPoint(local, bounds.size) else { return nil }
        return super.hitTest(point)
    }
}

/// Required production host, retained by the real cockpit composition. One existing PreferenceFile.
@MainActor public final class CommunityCockpitField: NSObject, FieldPickerProductionHost {
    public let picker: FieldFleetPickerView
    public private(set) var binding: FieldPickerProductionBinding!
    public private(set) var currentScope: CommunityFieldScope?
    public private(set) var focusedPublicID: String?
    public private(set) var enlargedProjection: FieldPublicProjection?
    public private(set) var lastError: Error?
    private let shell: CockpitShellSurface
    private let supply: CommunityCockpitSupply
    private let preferences: PreferenceFile?
    private let window: any CommunityFieldWindow
    private let normal = CommunityFieldNormalView(), comparison = CommunityFieldComparison(frame: .zero)
    public var normalFieldView: NSView { normal }
    private let enlarge = NSButton(), closeButton = NSButton()
    private let status = NSTextField(wrappingLabelWithString: "")
    private let fieldStatus = NSTextField(wrappingLabelWithString: "")
    private let enlarged = NSStackView()
    private var catalogue: FieldPickerCatalogue?
    private var reduceMotion = true, reduceTransparency = true
    private var disposed = false, presented = false, closing = false
    init(shell: CockpitShellSurface, supply: CommunityCockpitSupply, preferences: PreferenceFile?, window: any CommunityFieldWindow) {
        self.shell = shell; self.supply = supply; self.preferences = preferences; self.window = window
        picker = FieldFleetPickerView(comparisonContent: comparison)
        super.init()
        binding = FieldPickerProductionBinding(view: picker, host: self, locale: .english)
        binding.onFailure = { [weak self] error in self?.showFailure(error) }
        normal.containsFieldPoint = { [weak self] point, _ in
            guard let scope = self?.currentScope else { return false }
            return supply.containsFieldPoint(point, scope)
        }
        normal.orientation = .vertical; normal.alignment = .leading
        enlarge.title = "Enlarge / 放大"; enlarge.target = self; enlarge.action = #selector(openAction); enlarge.isEnabled = false
        enlarge.setAccessibilityIdentifier("cockpit.field.enlarge")
        normal.addArrangedSubview(enlarge); normal.addArrangedSubview(status)
        shell.setContent(normal, for: .window)
        enlarged.orientation = .vertical; enlarged.alignment = .leading
        closeButton.title = "Close / 关闭"; closeButton.target = self; closeButton.action = #selector(closeAction)
        enlarged.addArrangedSubview(closeButton); enlarged.addArrangedSubview(fieldStatus); enlarged.addArrangedSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.widthAnchor.constraint(equalTo: enlarged.widthAnchor).isActive = true
    }
    public func update(publication: PublicPublication?, selection: AssembledModelSelection, appearance: FieldAppearance,
                       reduceMotion: Bool = true, reduceTransparency: Bool = true) throws {
        guard !disposed else { return }
        self.reduceMotion = reduceMotion; self.reduceTransparency = reduceTransparency
        guard let publication else {
            try closeIfNeeded(); catalogue = nil; currentScope = nil; enlarge.isEnabled = false
            status.stringValue = appearance.locale == .english ? "Public catalogue unavailable" : "公开目录暂不可用"; return
        }
        let projection = try FieldPublicProjection(publication: publication)
        let ids = selection.shared.orderedIDs
        guard let state = shell.state, let slot = shell.surfaceLayout?.slots[.window] else { throw FieldPickerConnectionError.disconnected }
        let viewport = try FieldViewport(width: Int(slot.width), height: Int(slot.height),
            scale: min(2, max(1, shell.window.map { Double($0.backingScaleFactor) } ?? Double(state.appearance.scale))), profile: state.profile == .full ? .tall : .short)
        let configs = Dictionary(uniqueKeysWithValues: selection.models.compactMap { model in
            model.current.map { (model.id, $0) }
        })
        let scope = CommunityFieldScope(projection: projection, admittedPublicIDs: ids,
            configurations: configs, appearance: appearance, viewport: viewport)
        let next = try FieldPickerCatalogue(projection: projection, scopeModelIDs: ids,
            siteModelIDs: publication.models.filter { $0.defaultSelected == true }.map(\.id),
            scopeFocusID: selection.instruments?.selectedModelID, verdictRevision: projection.revision,
            verdicts: publication.lineups.flatMap { $0.members ?? [] }.map {
                .init(publicModelID: $0.id, tags: ($0.tags ?? []).compactMap(FieldPickerTag.init(rawValue:)))
            })
        currentScope = scope; catalogue = next; binding.setLocale(appearance.locale)
        enlarge.isEnabled = presented && preferences != nil
        if binding.view.isPresented {
            picker.update(catalogue: next, locale: appearance.locale)
            if let value = picker.state {
                try applyEnlargedField(next.projection.selecting(publicIDs: value.selectedIDs(in: next)),
                    focusedPublicID: value.effectiveFocus(in: next))
            }
        } else { try restoreScope() }
    }
    public func setPresented(_ allowed: Bool) {
        guard !disposed, allowed != presented else { return }
        presented = allowed; enlarge.isEnabled = allowed && catalogue != nil && preferences != nil
        if !allowed {
            // OS/owner suspension hides the owned panel even if still recovery fails.
            // The binding retains its error/retry state for the next explicit visible entry.
            defer { window.hide() }
            if !binding.isProcessing { do { try closeIfNeeded() } catch { showFailure(error) } }
        }
    }
    public func open() throws {
        guard presented, !disposed, preferences != nil else { throw FieldPickerConnectionError.disconnected }
        try binding.open(); fieldStatus.stringValue = ""
        window.show(content: enlarged, onClose: { [weak self] in try? self?.close() })
    }
    public func close() throws {
        guard !closing else { return }; closing = true; defer { closing = false }
        try binding.close(); window.hide()
    }
    private func closeIfNeeded() throws { if binding.view.isPresented || enlargedProjection != nil { try close() } }
    @objc private func openAction() { do { try open() } catch { showFailure(error) } }
    @objc private func closeAction() { do { try close() } catch { showFailure(error) } }
    private func showFailure(_ error: Error) {
        lastError = error
        status.stringValue = "Field unavailable; close and retry. / 比较视野暂不可用，请关闭后重试。"
        fieldStatus.stringValue = status.stringValue
    }
    public func fieldPickerInput() throws -> FieldPickerHostInput {
        guard !disposed, let catalogue else { throw FieldPickerConnectionError.disconnected }
        return .init(catalogue: catalogue, savedValue: try preferences?.load().fieldPickerValue)
    }
    public func applyEnlargedField(_ projection: FieldPublicProjection, focusedPublicID: String?) throws {
        guard !disposed, let scope = currentScope, projection.revision == scope.projection.revision,
              let catalogue, projection == (try catalogue.projection.selecting(publicIDs: projection.models.map(\.id))) else {
            throw FieldPickerConnectionError.disconnected
        }
        try comparison.apply(projection, focus: focusedPublicID, locale: scope.appearance.locale)
        enlargedProjection = projection; self.focusedPublicID = comparison.focusedID; lastError = nil
    }
    public func setFieldPickerExpanded(_ expanded: Bool) throws {
        guard !disposed else { throw FieldPickerConnectionError.disconnected }
        // Field-local panel state; never reconfigures the normal shell/HUD/scope.
        enlarged.setAccessibilityValue(expanded ? "expanded" : "collapsed")
    }
    public func saveFieldPickerValue(_ value: Data) throws {
        guard let preferences, let catalogue, value.count <= 16 * 1024 else { throw FieldPickerConnectionError.disconnected }
        let canonical = try FieldFleetPicker(catalogue: catalogue, savedValue: value).savedValue(in: catalogue)
        var saved = try preferences.load(); saved.fieldPickerValue = canonical; try preferences.save(saved)
    }
    public func closeEnlargedFieldAndRestoreCurrentScopeStill() throws {
        try restoreScope(); enlargedProjection = nil; focusedPublicID = nil; window.hide()
    }
    private func restoreScope() throws {
        guard !disposed, let scope = currentScope, let state = shell.state else { throw FieldPickerConnectionError.disconnected }
        let still = try supply.still(scope)
        var profile = state.appearance
        profile.dark = scope.appearance.theme == .night; profile.locale = scope.appearance.locale.rawValue
        profile.scale = Int(scope.viewport.scale); profile.reduceMotion = reduceMotion; profile.reduceTransparency = reduceTransparency
        try shell.configure(.init(profile: state.profile, closed: state.closed, appearance: profile,
            stations: state.stations, still: still, effectPhase: state.effectPhase))
        status.stringValue = scope.admittedPublicIDs.joined(separator: " · ")
    }
    public func dispose() {
        guard !disposed else { return }
        // Revoke before external window/slot callbacks can attempt a scope restore or reopen.
        disposed = true; presented = false; binding.dispose()
        enlarge.target = nil; enlarge.action = nil; closeButton.target = nil; closeButton.action = nil
        currentScope = nil; catalogue = nil; enlargedProjection = nil; focusedPublicID = nil
        if normal.superview === shell { shell.setContent(nil, for: .window) }
        window.hide()
    }
}
