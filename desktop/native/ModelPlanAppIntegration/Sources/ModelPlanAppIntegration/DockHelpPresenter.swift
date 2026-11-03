// SPDX-License-Identifier: MIT
import AppKit
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
    private let layer: HelpUILayerView
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var currentOffer: HintOffer?
    private var currentSurfaceValue: DockHelpSurface?
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
         recipe: HelpUIRecipeProvider? = nil) {
        self.currentSurface = currentSurface; self.isCurrent = isCurrent
        self.blockers = blockers; self.windowPolicy = windowPolicy
        self.language = language; self.accessibility = accessibility
        self.copy = copy; self.dismiss = dismiss
        self.layer = HelpUILayerView(recipeProvider: recipe)
    }

    func placeableKinds(context: HintContext, trial: InstrumentHintSourceSnapshot?) -> Set<FirstUseHintKind> {
        guard !retired, let surface = currentSurface(), surface.visible, !surface.dragging,
              context.dockReveal == surface.revealID, isCurrent(surface) else { return [] }
        let lang = language()
        return Set([FirstUseHintKind.ignition, .drag, .pinned].filter {
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
        currentOffer = nil; currentSurfaceValue = nil; panel?.orderOut(nil)
        // Detach before the new input: viewWillMove(toWindow:nil) suspends the
        // old layer, and must not invalidate the replacement after it is drawn.
        layer.removeFromSuperview()
        guard let surface = currentSurface(), surface.visible, !surface.dragging,
              isCurrent(surface), let anchor = surface.anchors[offer.kind],
              let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(anchor) }),
              let policy = windowPolicy(surface),
              let words = copy(offer.kind, language()) else { return false }
        let viewport = screen.visibleFrame
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
        window.sharingType = policy.0; window.collectionBehavior = policy.1
        let container = ClipView(frame: CGRect(origin: .zero, size: rect.size))
        container.wantsLayer = true; container.layer?.masksToBounds = true
        layer.frame = CGRect(x: -rect.minX, y: -rect.minY, width: viewport.width, height: viewport.height)
        container.addSubview(layer); window.contentView = container
        currentOffer = offer; currentSurfaceValue = surface
        layer.onAction = { [weak self] action in
            guard let self, !self.retired, self.generation == token,
                  self.currentOffer == offer, self.currentSurfaceValue == surface, self.isCurrent(surface) else { return }
            if case .dismissHint(let id, _) = action, id == offer.id { self.dismiss(id) }
        }
        window.setFrame(screenRect, display: true); window.orderFrontRegardless()
        guard !retired, generation == token, currentOffer == offer, currentSurfaceValue == surface,
              isCurrent(surface), window.isVisible, !window.isMiniaturized, window.alphaValue > 0,
              window.sharingType == policy.0, window.collectionBehavior == policy.1,
              window.occlusionState.contains(.visible),
              layer.visibleRect.contains(rect), layer.presentation?.card == placement else {
            window.orderOut(nil); currentOffer = nil; currentSurfaceValue = nil; return false
        }
        // Observe only this app's events; no global input monitor or new system permission.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self, weak window] event in
            guard let self, let window, !self.retired, self.generation == token,
                  self.currentOffer == offer, self.currentSurfaceValue == surface,
                  self.isCurrent(surface), window.isVisible else { return event }
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
        return show(presentation.offer, motionOverride: presentation.reducedMotion)
    }

    func hide(offerID: UUID) {
        guard currentOffer?.id == offerID else { return }
        generation &+= 1; currentOffer = nil; currentSurfaceValue = nil
        removeEventMonitor()
        panel?.orderOut(nil); layer.suspend()
    }

    func dispose() {
        guard !retired else { return }
        retired = true; generation &+= 1; currentOffer = nil; currentSurfaceValue = nil
        removeEventMonitor()
        panel?.orderOut(nil); panel?.close(); panel = nil; layer.dispose()
    }

    private func removeEventMonitor() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor); self.eventMonitor = nil }
    }

    private func makePanel() -> NSPanel {
        let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isFloatingPanel = true; window.level = .floating; window.isOpaque = false
        window.backgroundColor = .clear; window.hasShadow = false; window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        return window
    }
}
