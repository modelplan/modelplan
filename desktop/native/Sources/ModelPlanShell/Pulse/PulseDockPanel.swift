// Copyright (c) 2026 qunqin24. Licensed under the Apache License, Version 2.0.
// ModelPlan adaptation of FloatingPanel event routing at Pulse 7668384cbcf357bba7dee4af85b4052a59c6e35d.
// ModelPlan adaptation: reuse Pulse display identity and restore the requested frame after initial order-in.
// ModelPlan adaptation: use the live pointer for carry and borrow keyboard focus only during a background drag.
// No upstream private appearance selector, visual tether or provider logic is used.
import AppKit

@MainActor public protocol PulsePanelMouseHandling: AnyObject {
    func beginPanelMove(windowPoint: CGPoint, globalPoint: CGPoint) -> Bool
    func continuePanelMove(globalPoint: CGPoint)
    func finishPanelMove(globalPoint: CGPoint)
    var hasPanelControlCapture: Bool { get }
    func cancelPanelMove()
}

public extension PulsePanelMouseHandling {
    var hasPanelControlCapture: Bool { false }
}

/// Input capture only; the host's controller owns placement and hide state.
@MainActor final class PulsePanelInputRoute {
    weak var handler: (any PulsePanelMouseHandling)?
    private(set) var captured = false
    var canCancel: Bool { captured || handler?.hasPanelControlCapture == true }
    func begin(windowPoint: CGPoint, globalPoint: CGPoint, controlClick: Bool) -> Bool {
        cancel()
        guard !controlClick, let handler else { return false }
        captured = handler.beginPanelMove(windowPoint: windowPoint, globalPoint: globalPoint)
        return captured
    }
    func drag(globalPoint: CGPoint) -> Bool {
        guard captured else { return false }
        guard let handler else { captured = false; return false }
        handler.continuePanelMove(globalPoint: globalPoint)
        return true
    }
    func end(globalPoint: CGPoint) -> Bool {
        guard captured else { return false }
        captured = false
        handler?.finishPanelMove(globalPoint: globalPoint)
        return true
    }
    func cancel() {
        let held = canCancel; captured = false
        if held { handler?.cancelPanelMove() }
    }
}

/// A nonactivating keyboard target can be ordered out to release key focus
/// without withdrawing the visible Dock. It cannot receive pointer input.
@MainActor private final class PulseDragKeyPanel: NSPanel {
    var lostKey: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        lostKey?()
    }
}

/// Pulse's non-key panel and window-level drag transaction, with a scoped,
/// numeric-only arrival observer for later real-input evidence. Construction is
/// deferred to the production host; importing this type creates no window.
@MainActor public final class PulseDockPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public static func displayIdentifier(for screen: NSScreen) -> String? {
        PanelScreen.identifier(of: screen)
    }

    /// The caller places the frame before installing the content. AppKit may
    /// adjust the frame on first order-in, so restore the requested placement.
    public func orderInAtPlacement(_ replace: (CGRect) -> CGRect?) {
        orderFrontRegardless()
        if let target = replace(frame) { setFrame(target, display: true) }
        else { orderOut(nil) }
    }
    private let input = PulsePanelInputRoute()
    private var escapeMonitor: Any?
    private var dragKeyPanel: PulseDragKeyPanel?
    private func stopEscapeMonitor() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor); self.escapeMonitor = nil }
        if let target = dragKeyPanel {
            dragKeyPanel = nil
            target.lostKey = nil
            target.orderOut(nil)
        }
    }

    private func borrowKeyboardForBackgroundDrag() {
        guard escapeMonitor != nil, dragKeyPanel == nil, isVisible, !NSApplication.shared.isActive else { return }
        let target = PulseDragKeyPanel(
            contentRect: CGRect(x: frame.midX, y: frame.midY, width: 1, height: 1),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        target.titleVisibility = .hidden
        target.titlebarAppearsTransparent = true
        target.titlebarSeparatorStyle = .none
        target.isOpaque = false
        target.backgroundColor = .clear
        target.hasShadow = false
        target.ignoresMouseEvents = true
        target.isExcludedFromWindowsMenu = true
        target.hidesOnDeactivate = false
        target.animationBehavior = .none
        target.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle, .fullScreenAuxiliary]
        target.lostKey = { [weak self] in
            guard let self else { return }
            self.stopEscapeMonitor()
            self.input.cancel()
        }
        dragKeyPanel = target
        target.orderFrontRegardless()
        target.makeKey()
    }
    private func monitorEscape() {
        stopEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.input.canCancel, event.keyCode == 53 else { return event }
                self.input.cancel()
                self.stopEscapeMonitor()
                return nil
            }
        }
    }

    public var mouseHandler: (any PulsePanelMouseHandling)? {
        get { input.handler }
        set { stopEscapeMonitor(); input.cancel(); input.handler = newValue }
    }
    public var pointerLocation: (() -> CGPoint?)?
    public var receivedInput: ((NSEvent.EventType, TimeInterval) -> Void)?

    public override func sendEvent(_ event: NSEvent) {
        let global = pointerLocation?() ?? NSEvent.mouseLocation
        let handled: Bool
        switch event.type {
        case .keyDown where event.keyCode == 53 && input.canCancel:
            input.cancel()
            stopEscapeMonitor()
            handled = true
        case .leftMouseDown:
            receivedInput?(event.type, event.timestamp)
            if !input.begin(windowPoint: event.locationInWindow, globalPoint: global,
                            controlClick: event.modifierFlags.contains(.control)) {
                super.sendEvent(event)
            }
            // The instrument may capture a nozzle during AppKit's dispatch.
            if input.canCancel { monitorEscape() } else { stopEscapeMonitor() }
            return
        case .leftMouseDragged:
            receivedInput?(event.type, event.timestamp)
            if !input.drag(globalPoint: global) { super.sendEvent(event) }
            if input.canCancel { borrowKeyboardForBackgroundDrag() }
            else { stopEscapeMonitor() }
            return
        case .leftMouseUp:
            receivedInput?(event.type, event.timestamp)
            handled = input.end(globalPoint: global)
            stopEscapeMonitor()
        case .mouseMoved, .mouseEntered, .mouseExited:
            receivedInput?(event.type, event.timestamp)
            handled = false
        default: handled = false
        }
        if !handled { super.sendEvent(event) }
    }
    public override func orderOut(_ sender: Any?) {
        stopEscapeMonitor()
        input.cancel()
        super.orderOut(sender)
    }
}
