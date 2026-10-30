// Copyright (c) 2026 qunqin24. Licensed under the Apache License, Version 2.0.
// ModelPlan adaptation of FloatingPanel event routing at Pulse 7668384cbcf357bba7dee4af85b4052a59c6e35d.
// No upstream private appearance selector, visual tether or provider logic is used.
import AppKit

@MainActor public protocol PulsePanelMouseHandling: AnyObject {
    func beginPanelMove(windowPoint: CGPoint, globalPoint: CGPoint) -> Bool
    func continuePanelMove(globalPoint: CGPoint)
    func finishPanelMove(globalPoint: CGPoint)
    func cancelPanelMove()
}

/// Input capture only; the host's controller owns placement and hide state.
@MainActor final class PulsePanelInputRoute {
    weak var handler: (any PulsePanelMouseHandling)?
    private(set) var captured = false
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
        let held = captured; captured = false
        if held { handler?.cancelPanelMove() }
    }
}

/// Pulse's non-key panel and window-level drag transaction, with a scoped,
/// numeric-only arrival observer for later real-input evidence. Construction is
/// deferred to the production host; importing this type creates no window.
@MainActor public final class PulseDockPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
    private let input = PulsePanelInputRoute()
    public var mouseHandler: (any PulsePanelMouseHandling)? {
        get { input.handler }
        set { input.cancel(); input.handler = newValue }
    }
    public var receivedInput: ((NSEvent.EventType, TimeInterval) -> Void)?

    public override func sendEvent(_ event: NSEvent) {
        let global = convertPoint(toScreen: event.locationInWindow)
        let handled: Bool
        switch event.type {
        case .leftMouseDown:
            receivedInput?(event.type, event.timestamp)
            handled = input.begin(windowPoint: event.locationInWindow, globalPoint: global,
                                  controlClick: event.modifierFlags.contains(.control))
        case .leftMouseDragged:
            receivedInput?(event.type, event.timestamp)
            handled = input.drag(globalPoint: global)
        case .leftMouseUp:
            receivedInput?(event.type, event.timestamp)
            handled = input.end(globalPoint: global)
        default: handled = false
        }
        if !handled { super.sendEvent(event) }
    }
    public override func orderOut(_ sender: Any?) {
        input.cancel()
        super.orderOut(sender)
    }
}
