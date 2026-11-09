// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCockpitWeb
import ModelPlanInstruments
import ModelPlanSettings

/// Hosts the existing Help layer in a card-sized nonactivating panel. Hint
/// admission, dwell, persistence and the sole ledger remain with HintExecutionHost.
@MainActor final class DockHelpPresenter: HintOverlayPresenting {
    typealias Copy = (text: String, dismiss: String)
    private final class ClipView: NSView {
        override var isFlipped: Bool { true }
    }
    private let currentSurface: @MainActor () -> DockHelpSurface?
    private let isCurrent: @MainActor (DockHelpSurface) -> Bool
    private let blockers: @MainActor (DockHelpSurface) -> [CGRect]
    private let windowPolicy: @MainActor (DockHelpSurface) -> (NSWindow.SharingType, NSWindow.CollectionBehavior)?
    private let language: @MainActor () -> InstrumentLanguage
    private let accessibility: @MainActor () -> (motion: Bool, transparency: Bool)
    private let copy: @MainActor (FirstUseHintKind, InstrumentLanguage) -> Copy?
    private let dismiss: @MainActor (UUID) -> Void
    /// Brings this app forward when a requested map opens, so Esc and outside clicks reach the
    /// local monitor below (a nonactivating panel in an inactive app sees neither).
    private let activate: @MainActor () -> Void
    private let layer: HelpUILayerView
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var deactivateObserver: NSObjectProtocol?
    /// The app that was frontmost before a map activated this one; restored when the map closes.
    private var previousApp: NSRunningApplication?
    private var currentOffer: HintOffer?
    private var currentExplanationID: String?
    private var currentSurfaceValue: DockHelpSurface?
    private var currentReducedMotion: Bool?
    private var generation: UInt64 = 0
    private var retired = false

    init(currentSurface: @escaping @MainActor () -> DockHelpSurface?,
         isCurrent: @escaping @MainActor (DockHelpSurface) -> Bool,
         blockers: @escaping @MainActor (DockHelpSurface) -> [CGRect],
         windowPolicy: @escaping @MainActor (DockHelpSurface) -> (NSWindow.SharingType, NSWindow.CollectionBehavior)?,
         language: @escaping @MainActor () -> InstrumentLanguage,
         accessibility: @escaping @MainActor () -> (motion: Bool, transparency: Bool),
         copy: @escaping @MainActor (FirstUseHintKind, InstrumentLanguage) -> Copy?,
         dismiss: @escaping @MainActor (UUID) -> Void,
         activate: @escaping @MainActor () -> Void = { if !NSApp.isActive { NSApplication.shared.activate() } },
         layer: HelpUILayerView) {
        self.currentSurface = currentSurface; self.isCurrent = isCurrent
        self.blockers = blockers; self.windowPolicy = windowPolicy
        self.language = language; self.accessibility = accessibility
        self.copy = copy; self.dismiss = dismiss; self.activate = activate
        self.layer = layer
    }

    func placeableKinds(context: HintContext, trial: InstrumentHintSourceSnapshot?) -> Set<FirstUseHintKind> {
        guard !retired, let surface = currentSurface(), surface.visible, !surface.dragging,
              context.dockReveal == surface.revealID, isCurrent(surface) else { return [] }
        let lang = language()
        return Set([FirstUseHintKind.ignition, .drag, .pinned, .ringRefresh, .findWidget, .widgetOff, .detach, .putBack].filter {
            surface.anchors[$0] != nil && copy($0, lang) != nil
        })
    }

    func showAndVerify(_ offer: HintOffer, trial: InstrumentHintSourceSnapshot?) -> Bool {
        show(offer, motionOverride: nil)
    }

    private func show(_ offer: HintOffer, motionOverride: Bool?) -> Bool {
        guard !retired else { return false }
        generation &+= 1
        let token = generation
        removeEventMonitor()
        currentOffer = nil; currentSurfaceValue = nil; currentExplanationID = nil; panel?.orderOut(nil)
        // Detach before the new input: viewWillMove(toWindow:nil) suspends the
        // old layer, and must not invalidate the replacement after it is drawn.
        layer.removeFromSuperview()
        guard let surface = currentSurface(), surface.visible, !surface.dragging,
              isCurrent(surface), let anchor = surface.anchors[offer.kind],
              let screen = NSScreen.screens.first(where: { offer.kind == .findWidget || offer.kind == .widgetOff ? $0.frame.intersects(anchor) : $0.visibleFrame.contains(anchor) }),
              let policy = windowPolicy(surface),
              let words = copy(offer.kind, language()) else { return false }
        // The status item lies in the menu-bar area above visibleFrame; its real frame remains the anchor.
        let viewport = offer.kind == .findWidget || offer.kind == .widgetOff ? screen.frame : screen.visibleFrame
        func local(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX - viewport.minX, y: viewport.maxY - rect.maxY,
                   width: rect.width, height: rect.height)
        }
        let anchorID = "dock." + offer.kind.rawValue
        var input = HelpUIRenderInput(sessionID: surface.revealID, viewport: viewport.size,
            profile: .compact640, language: language(),
            anchors: [.init(id: anchorID, rect: local(anchor))],
            liveReadings: blockers(surface).map(local),
            firstUse: .init(offerID: offer.id, anchorID: anchorID, text: words.text, dismissTitle: words.dismiss))
        let effective = accessibility()
        input.reduceMotion = motionOverride ?? effective.motion
        input.reduceTransparency = effective.transparency
        currentReducedMotion = input.reduceMotion
        layer.update(input)
        guard !retired, generation == token, isCurrent(surface),
              let placement = layer.presentation?.card,
              placement.identity == .firstUse(offer.id), placement.anchorID == anchorID else { return false }
        let rect = placement.frame
        guard rect.width > 0, rect.height > 0, CGRect(origin: .zero, size: viewport.size).contains(rect) else { return false }
        let screenRect = CGRect(x: viewport.minX + rect.minX, y: viewport.maxY - rect.maxY,
                                width: rect.width, height: rect.height)
        guard viewport.contains(screenRect), !blockers(surface).contains(where: { $0.intersects(screenRect) }) else { return false }
        let window = panel ?? makePanel()
        panel = window
        window.ignoresMouseEvents = false
        window.sharingType = policy.0; window.collectionBehavior = policy.1
        let container = ClipView(frame: CGRect(origin: .zero, size: rect.size))
        container.wantsLayer = true; container.layer?.masksToBounds = true
        layer.frame = CGRect(x: -rect.minX, y: -rect.minY, width: viewport.width, height: viewport.height)
        container.addSubview(layer); window.contentView = container
        currentOffer = offer; currentSurfaceValue = surface
        layer.onAction = { [weak self] action in
            guard let self, !self.retired, self.generation == token, self.currentOffer == offer,
                  let current = self.currentSurfaceValue, self.isCurrent(current) else { return }
            if case .dismissHint(let id, _) = action, id == offer.id { self.dismiss(id) }
        }
        window.setFrame(screenRect, display: true); window.orderFrontRegardless()
        // Not this panel's occlusionState: AppKit updates it later, so a panel just ordered in never
        // reports .visible here. isCurrent carries the settled state of the window the hint belongs to.
        guard !retired, generation == token, currentOffer == offer, currentSurfaceValue == surface,
              isCurrent(surface), window.isVisible, !window.isMiniaturized, window.alphaValue > 0,
              window.sharingType == policy.0, window.collectionBehavior == policy.1,
              layer.visibleRect.contains(rect), layer.presentation?.card == placement else {
            window.orderOut(nil); currentOffer = nil; currentSurfaceValue = nil; return false
        }
        // Observe only this app's events; no global input monitor or new system permission.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self, weak window] event in
            guard let self, let window, !self.retired, self.generation == token, self.currentOffer == offer,
                  let current = self.currentSurfaceValue, self.isCurrent(current), window.isVisible else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.dismiss(offer.id)
                return nil
            }
            if event.type != .keyDown, event.window !== window { self.dismiss(offer.id) }
            return event
        }
        return true
    }

    func updateAndVerify(_ presentation: HintPresentation) -> Bool {
        guard currentOffer == presentation.offer else { return false }
        // The surface is republished on most refreshes; ordering the panel out and in each time flashes it.
        let kind = presentation.offer.kind
        if let surface = currentSurface(), let shown = currentSurfaceValue, surface.revealID == shown.revealID,
           surface.visible, !surface.dragging, surface.anchors[kind] == shown.anchors[kind],
           presentation.reducedMotion == currentReducedMotion, panel?.isVisible == true, isCurrent(surface) {
            currentSurfaceValue = surface
            return true
        }
        return show(presentation.offer, motionOverride: presentation.reducedMotion)
    }

    func hide(offerID: UUID) {
        guard currentOffer?.id == offerID else { return }
        generation &+= 1; currentOffer = nil; currentSurfaceValue = nil
        removeEventMonitor()
        panel?.orderOut(nil); layer.suspend()
    }

    /// Prepare the same transparent panel for a map without intercepting input outside the app.
    func prepareMap(surface: DockHelpSurface) -> CGRect? {
        guard !retired, isCurrent(surface), surface.visible, !surface.dragging,
              let anchor = surface.mapAnchors.first?.rect,
              let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(anchor) }),
              let policy = windowPolicy(surface) else { return nil }
        generation &+= 1; removeEventMonitor(); removeDeactivateObserver()
        currentOffer = nil; currentExplanationID = nil; currentSurfaceValue = surface
        panel?.orderOut(nil); layer.removeFromSuperview()
        let window = panel ?? makePanel(); panel = window
        window.sharingType = policy.0; window.collectionBehavior = policy.1
        window.ignoresMouseEvents = true
        // The menu-bar item may be a visible Help target on this same display.
        let viewport = screen.frame
        layer.frame = CGRect(origin: .zero, size: viewport.size)
        window.contentView = layer
        window.setFrame(viewport, display: false)
        return viewport
    }

    func showPreparedMap(surface: DockHelpSurface, dismissMap: @escaping @MainActor (HelpUIDismissReason?) -> Void) -> Bool {
        guard !retired, currentSurfaceValue == surface, isCurrent(surface), let window = panel,
              layer.presentation?.mapHeader != nil else { return false }
        let token = generation
        window.orderFrontRegardless()
        // As in show: occlusionState lags the order, and isCurrent has the settled state.
        guard window.isVisible, window.alphaValue > 0, isCurrent(surface) else {
            window.orderOut(nil); return false
        }
        // A second call replaces the first: one monitor and one observer at a time, never stacked.
        removeEventMonitor(); removeDeactivateObserver()
        var optionHeld = NSEvent.modifierFlags.contains(.option)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .flagsChanged]) { [weak self, weak window] event in
            guard let self, let window, window.isVisible, !self.retired, self.generation == token,
                  self.currentSurfaceValue == surface, self.isCurrent(surface) else { return event }
            if event.type == .keyDown && event.keyCode == 53 { dismissMap(.escape); return nil }
            if event.type == .flagsChanged {
                let held = event.modifierFlags.contains(.option)
                if optionHeld && !held { dismissMap(nil) }
                optionHeld = held
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown { dismissMap(.pointer) }
            return event
        }
        deactivateObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { dismissMap(nil) }
        }
        // After the observer exists: activating must not read as the app losing focus. Esc and a click
        // outside the map are local events only while the app is active.
        if !NSApp.isActive, previousApp == nil {
            let front = NSWorkspace.shared.frontmostApplication
            if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        }
        activate()
        return true
    }

    /// A first-use hint owns the panel while it is shown.
    var showsHint: Bool { currentOffer != nil }
    private(set) var shownExplanationForChecks: HelpExplanation?

    /// G3-10: the prototype explanation card next to the hovered or focused widget element.
    /// The panel ignores the pointer, so the hover that produced it stays on the widget.
    func showExplanation(_ explanation: HelpExplanation, id: String, anchor: CGRect, surface: DockHelpSurface) -> Bool {
        guard !retired, currentOffer == nil, surface.visible, !surface.dragging,
              let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(anchor) }),
              let policy = windowPolicy(surface) else { return false }
        generation &+= 1
        let token = generation
        removeEventMonitor(); removeDeactivateObserver()
        currentSurfaceValue = nil; currentExplanationID = nil; shownExplanationForChecks = nil
        panel?.orderOut(nil); layer.removeFromSuperview()
        let viewport = screen.visibleFrame
        func local(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX - viewport.minX, y: viewport.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        let anchorID = "dock.explanation"
        var input = HelpUIRenderInput(sessionID: surface.layoutID, viewport: viewport.size, profile: .compact640,
            language: language(), anchors: [.init(id: anchorID, rect: local(anchor))],
            liveReadings: blockers(surface).map(local),
            contextual: .init(id: id, anchorID: anchorID, explanation: explanation))
        let effective = accessibility()
        input.reduceMotion = effective.motion
        input.reduceTransparency = effective.transparency
        layer.update(input)
        guard !retired, generation == token, let placement = layer.presentation?.card,
              placement.identity == .context(id) else { return false }
        let rect = placement.frame
        guard rect.width > 0, rect.height > 0, CGRect(origin: .zero, size: viewport.size).contains(rect) else { return false }
        let screenRect = CGRect(x: viewport.minX + rect.minX, y: viewport.maxY - rect.maxY,
                                width: rect.width, height: rect.height)
        let window = panel ?? makePanel()
        panel = window
        window.ignoresMouseEvents = true
        window.sharingType = policy.0; window.collectionBehavior = policy.1
        let container = ClipView(frame: CGRect(origin: .zero, size: rect.size))
        container.wantsLayer = true; container.layer?.masksToBounds = true
        layer.frame = CGRect(x: -rect.minX, y: -rect.minY, width: viewport.width, height: viewport.height)
        container.addSubview(layer); window.contentView = container
        layer.onAction = { _ in }
        window.setFrame(screenRect, display: true); window.orderFrontRegardless()
        guard window.isVisible else { window.orderOut(nil); return false }
        currentExplanationID = id; shownExplanationForChecks = explanation
        return true
    }

    func hideExplanation() {
        guard currentExplanationID != nil else { return }
        currentExplanationID = nil; shownExplanationForChecks = nil; generation &+= 1
        panel?.orderOut(nil); layer.suspend()
    }

    func endMap() {
        generation &+= 1; currentSurfaceValue = nil
        removeEventMonitor(); removeDeactivateObserver()
        panel?.orderOut(nil); layer.removeFromSuperview()
        // Give focus back only if this app still holds it; a user who switched away keeps their choice.
        if let previousApp, NSApp.isActive { previousApp.activate() }
        previousApp = nil
    }

    func dispose() {
        guard !retired else { return }
        retired = true; generation &+= 1; currentOffer = nil; currentSurfaceValue = nil
        removeEventMonitor(); removeDeactivateObserver()
        panel?.orderOut(nil); panel?.close(); panel = nil; layer.dispose()
    }

    private func removeEventMonitor() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor); self.eventMonitor = nil }
    }
    private func removeDeactivateObserver() {
        if let deactivateObserver { NotificationCenter.default.removeObserver(deactivateObserver); self.deactivateObserver = nil }
    }

    static let overlayLevel = CockpitWindowController.aboveCockpitLevel
    private func makePanel() -> NSPanel {
        let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // D49: Help can be asked for while the cockpit is open, so it draws above it.
        window.isFloatingPanel = true; window.level = Self.overlayLevel; window.isOpaque = false
        window.backgroundColor = .clear; window.hasShadow = false; window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        // D88: a press on a hint over the attached cockpit is not an outside click that closes it.
        window.identifier = CockpitWindowController.helpOverlayIdentifier
        return window
    }
}
