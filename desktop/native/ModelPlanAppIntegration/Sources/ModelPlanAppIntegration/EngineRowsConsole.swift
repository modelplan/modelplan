// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanDock
import ModelPlanSettings

@MainActor public protocol EngineRowsConsoleSurface: AnyObject {
    func show()
    func render()
    func hide()
    func applySettings(_ value: SettingsApplication)
    /// True from the moment an open is requested until the surface has closed.
    var isShowing: Bool { get }
    /// A user close: keeps the surface's transition and saved state, unlike `hide()`.
    func requestClose()
    /// Called when `isShowing` may have changed without a call from the owner, such as the page's own close.
    var onShowingChanged: (() -> Void)? { get set }
}
public extension EngineRowsConsoleSurface {
    func applySettings(_ value: SettingsApplication) {}
    var isShowing: Bool { false }
    func requestClose() { hide() }
    var onShowingChanged: (() -> Void)? { get { nil } set {} }
}
/// Read-only native Dock-reading status; no private cockpit or producer is constructed.
@MainActor final class EngineRowsConsole: NSWindowController, EngineRowsConsoleSurface {
    private let composition: EngineDockMenuComposition
    private let content = NSStackView()
    init(composition: EngineDockMenuComposition) {
        self.composition = composition
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 420, height: 300), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = EngineRowsText.readingsTitle.value(composition.latestSettings?.effective.language ?? .english); window.isReleasedWhenClosed = false
        super.init(window: window)
        content.orientation = .vertical; content.alignment = .leading; content.spacing = 10
        content.edgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
        window.contentView = content
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func show() { render(); showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApplication.shared.activate() }
    func render() {
        let language = composition.latestSettings?.effective.language ?? .english
        window?.title = EngineRowsText.readingsTitle.value(language)
        for view in content.arrangedSubviews { content.removeArrangedSubview(view); view.removeFromSuperview() }
        let value = composition.presentedContent
        if value.snapshot.inputs.isEmpty { content.addArrangedSubview(NSTextField(wrappingLabelWithString: value.emptyText ?? EngineRowsText.waiting.value(language))) }
        for input in value.snapshot.inputs {
            let number = (try? DockInstrumentProjection.evaluate(input, now: Date()))?.readout ?? "--"
            let reason = value.snapshot.presentationRows[input.id]
            content.addArrangedSubview(NSTextField(wrappingLabelWithString: [input.name, number, reason?.reason, reason?.nextStep].compactMap { $0 }.joined(separator: " · ")))
        }
    }
    func applySettings(_ value: SettingsApplication) { render() }
    func hide() { window?.orderOut(nil) }
}
