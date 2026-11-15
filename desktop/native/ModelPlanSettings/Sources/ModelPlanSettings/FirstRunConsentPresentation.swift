// SPDX-License-Identifier: MIT
import AppKit

/// Owns the first-run view only; the entry retains the shared accepted-facts controller.
@MainActor public final class FirstRunConsentPresentation {
    public let container = NSStackView()
    public private(set) var view: SettingsScopeConsentView?
    private let entry: ScopeConsentEntry
    public init(entry: ScopeConsentEntry) {
        self.entry = entry
        container.orientation = .vertical; container.alignment = .leading; container.spacing = 8
    }
    public func prepare(language: SettingsLanguage) throws {
        if let view { view.apply(language: language); return }
        let next = try entry.makeFirstRunView(language: language)
        container.addArrangedSubview(next); view = next
        // G3-25: the permissions column takes the page width, so its copy wraps inside it.
        next.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
    }
    public func apply(language: SettingsLanguage) { view?.apply(language: language) }
    public func suspend() {
        entry.endFirstRunPresentation()
        if let view { container.removeArrangedSubview(view); view.removeFromSuperview(); self.view = nil }
    }
}
