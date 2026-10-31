// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanDock

@MainActor public protocol EngineRowsConsoleSurface: AnyObject {
    func show()
    func render()
    func hide()
}
/// Read-only native Dock-reading status; no private cockpit or producer is constructed.
@MainActor final class EngineRowsConsole: NSWindowController, EngineRowsConsoleSurface {
    private let composition: EngineDockMenuComposition
    private let content = NSStackView()
    init(composition: EngineDockMenuComposition) {
        self.composition = composition
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 420, height: 300), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Dock readings / Dock 读数"; window.isReleasedWhenClosed = false
        super.init(window: window)
        content.orientation = .vertical; content.alignment = .leading; content.spacing = 10
        content.edgeInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
        window.contentView = content
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func show() { render(); showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApplication.shared.activate() }
    func render() {
        for view in content.arrangedSubviews { content.removeArrangedSubview(view); view.removeFromSuperview() }
        let value = composition.presentedContent
        if value.snapshot.inputs.isEmpty { content.addArrangedSubview(NSTextField(wrappingLabelWithString: value.emptyText ?? "Waiting for readings / 等待读数")) }
        for input in value.snapshot.inputs {
            let number = (try? DockInstrumentProjection.evaluate(input, now: Date()))?.readout ?? "—"
            let reason = value.snapshot.presentationRows[input.id]
            content.addArrangedSubview(NSTextField(wrappingLabelWithString: [input.name, number, reason?.reason, reason?.nextStep].compactMap { $0 }.joined(separator: " · ")))
        }
    }
    func hide() { window?.orderOut(nil) }
}
