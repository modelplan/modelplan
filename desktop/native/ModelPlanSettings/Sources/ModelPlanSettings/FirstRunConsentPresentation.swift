// SPDX-License-Identifier: MIT
import AppKit

@MainActor private final class FirstRunScopeContainer: NSStackView {
    var widthDidChange: (() -> Void)?
    private var previousWidth: CGFloat = -1
    override func layout() {
        super.layout()
        guard abs(bounds.width - previousWidth) > 0.5 else { return }
        previousWidth = bounds.width; widthDidChange?()
    }
}

/// Owns the first-run view only; the entry retains the shared accepted-facts controller.
@MainActor public final class FirstRunConsentPresentation {
    public let container: NSStackView = FirstRunScopeContainer()
    private weak var followingControl: NSView?
    public private(set) var view: SettingsScopeConsentView?
    private let entry: ScopeConsentEntry
    public init(entry: ScopeConsentEntry) {
        self.entry = entry
        container.orientation = .vertical; container.alignment = .leading; container.spacing = 8
        (container as? FirstRunScopeContainer)?.widthDidChange = { [weak self] in
            guard let self, let following = self.followingControl else { return }
            self.refreshLayoutAndFocus(followedBy: following)
        }
    }
    public func prepare(language: SettingsLanguage) throws {
        if let view { view.apply(language: language); return }
        let next = try entry.makeFirstRunView(language: language)
        next.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(next); view = next
        next.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
    }
    /// Reapply first-run-only width and keyboard links after the scope view rerenders.
    func refreshLayoutAndFocus(followedBy: NSView) {
        guard let view else { return }
        followingControl = followedBy
        for child in view.arrangedSubviews {
            if !view.constraints.contains(where: { $0.identifier == "firstRun.scope.width" && $0.firstItem as AnyObject? === child }) {
                let constraint: NSLayoutConstraint
                if child is NSTextField { constraint = child.widthAnchor.constraint(equalTo: view.widthAnchor) }
                else { constraint = child.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor) }
                constraint.identifier = "firstRun.scope.width"; constraint.isActive = true
            }
            guard let button = child as? NSButton else { continue }
            button.cell?.wraps = true; button.cell?.isScrollable = false
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            guard view.bounds.width > 1, let cell = button.cell else { continue }
            let height = ceil(cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: view.bounds.width, height: 10_000)).height)
            if let existing = button.constraints.first(where: { $0.identifier == "firstRun.scope.height" }) {
                existing.constant = height
            } else {
                let constraint = button.heightAnchor.constraint(greaterThanOrEqualToConstant: height)
                constraint.identifier = "firstRun.scope.height"; constraint.isActive = true
            }
        }
        let controls = view.arrangedSubviews.compactMap { $0 as? NSButton }
        for (first, second) in zip(controls, controls.dropFirst()) { first.nextKeyView = second }
        controls.last?.nextKeyView = followedBy
    }
    var firstEnabledControl: NSView? { view?.arrangedSubviews.compactMap { $0 as? NSButton }.first { $0.isEnabled && !$0.isHidden } }
    public func apply(language: SettingsLanguage) { view?.apply(language: language) }
    public func suspend() {
        followingControl = nil
        entry.endFirstRunPresentation()
        if let view { container.removeArrangedSubview(view); view.removeFromSuperview(); self.view = nil }
    }
}
