// SPDX-License-Identifier: MIT
import AppKit

/// D56 Find Quota Widget (owner 2026-11-08). The widget slides out if it is collapsed; the rest of
/// its display, menu bar included, dims to about 60 % within 0.2 s with a soft bright ring around
/// the widget; it holds about 1.5 s, then fades. Any click or key ends it at once. The overlay
/// never takes mouse events. With Reduce Motion there is no slide or fade: dim, then restore.
struct QuotaWidgetSpotlightTarget: Equatable {
    /// The widget's painted hull on screen, in global AppKit coordinates.
    let widget: CGRect
    /// The whole display the widget is on, menu bar included.
    let display: CGRect
    let displayID: String
}

struct QuotaWidgetSpotlightTiming: Equatable {
    var fadeIn: TimeInterval = 0.2
    var hold: TimeInterval = 1.5
    var fadeOut: TimeInterval = 0.3
    /// How long a request waits for the widget to be expanded on screen before it gives up.
    var revealTimeout: TimeInterval = 2
    /// The withdrawn-widget check while the spotlight holds; a sleep, never a spin.
    var tick: TimeInterval = 0.1
}

enum QuotaWidgetSpotlightStyle {
    /// Black at 0.4 leaves the rest of the display at about 60 % brightness.
    static let dimAlpha: CGFloat = 0.4
    static let holePadding: CGFloat = 8
    static let holeCornerRadius: CGFloat = 12
    static let ringWidth: CGFloat = 2
    static let ringAlpha: CGFloat = 0.9
    static let ringGlowRadius: CGFloat = 10
    /// The undimmed hole: the widget plus padding, kept on its display.
    static func hole(for target: QuotaWidgetSpotlightTarget) -> CGRect {
        target.widget.insetBy(dx: -holePadding, dy: -holePadding).intersection(target.display)
    }
    /// Above the menu bar and its status items, so the whole display dims.
    static var level: NSWindow.Level { NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1) }
    /// The current Space only, full-screen Spaces included; never in the window cycle.
    static let collectionBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
}

enum QuotaWidgetSpotlightEnd: Equatable { case timeout, input, withdrawn, unavailable, cancelled }

/// The drawing boundary. Durations of zero mean at once (Reduce Motion, or an input ending it).
@MainActor protocol QuotaWidgetSpotlightSurface: AnyObject {
    func show(_ target: QuotaWidgetSpotlightTarget, fadeIn: TimeInterval)
    func hide(fadeOut: TimeInterval)
}

/// Any click or key ends the spotlight. The native monitor observes; it never consumes the event.
@MainActor protocol QuotaWidgetSpotlightInput: AnyObject {
    func start(_ onInput: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor final class QuotaWidgetSpotlight {
    enum Phase: Equatable { case idle, revealing, shown }
    private(set) var phase: Phase = .idle
    private(set) var lastTarget: QuotaWidgetSpotlightTarget?
    private(set) var lastEnd: QuotaWidgetSpotlightEnd?
    private(set) var shownCount = 0
    private(set) var lastFadeIn: TimeInterval?, lastFadeOut: TimeInterval?
    var timing = QuotaWidgetSpotlightTiming()
    var makeSurface: @MainActor () -> any QuotaWidgetSpotlightSurface
    var makeInput: @MainActor () -> any QuotaWidgetSpotlightInput
    /// True from the request until it ends: the host keeps the widget expanded and holds hints back.
    var onActiveChange: (@MainActor (Bool) -> Void)?
    private var surface: (any QuotaWidgetSpotlightSurface)?
    private var input: (any QuotaWidgetSpotlightInput)?
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var reduceMotion: () -> Bool = { true }
    var isActive: Bool { phase != .idle }
    var surfaceForChecks: (any QuotaWidgetSpotlightSurface)? { surface }
    var inputForChecks: (any QuotaWidgetSpotlightInput)? { input }

    init(makeSurface: @escaping @MainActor () -> any QuotaWidgetSpotlightSurface = { QuotaWidgetSpotlightWindowSurface() },
         makeInput: @escaping @MainActor () -> any QuotaWidgetSpotlightInput = { QuotaWidgetSpotlightEventMonitor() }) {
        self.makeSurface = makeSurface; self.makeInput = makeInput
    }

    /// `prepare` makes the widget visible and expanded (it may save Show); `target` reads where it
    /// is now, nil while it is not expanded on screen. A new request replaces a running one.
    func run(reduceMotion: @escaping () -> Bool, prepare: @escaping @MainActor () async -> Bool,
             target: @escaping @MainActor () -> QuotaWidgetSpotlightTarget?) {
        if isActive { finish(.cancelled) }
        generation &+= 1
        let current = generation
        self.reduceMotion = reduceMotion
        phase = .revealing; lastEnd = nil
        onActiveChange?(true)
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await prepare(), self.generation == current, !Task.isCancelled else {
                if self.generation == current { self.finish(.unavailable) }
                return
            }
            let deadline = ContinuousClock.now + .seconds(self.timing.revealTimeout)
            var found = target()
            while found == nil, ContinuousClock.now < deadline, !Task.isCancelled, self.generation == current {
                try? await Task.sleep(for: .seconds(self.timing.tick / 2))
                found = target()
            }
            guard self.generation == current, !Task.isCancelled else { return }
            guard let found else { self.finish(.unavailable); return }
            self.present(found)
            let end = ContinuousClock.now + .seconds(self.timing.hold)
            while ContinuousClock.now < end, !Task.isCancelled, self.generation == current {
                try? await Task.sleep(for: .seconds(min(self.timing.tick, self.timing.hold)))
                guard self.generation == current, !Task.isCancelled else { return }
                // The widget went away (turned off, cockpit, lifecycle): never dim around nothing.
                if target()?.displayID != found.displayID { self.finish(.withdrawn); return }
            }
            guard self.generation == current, !Task.isCancelled else { return }
            self.finish(.timeout)
        }
    }

    private func present(_ target: QuotaWidgetSpotlightTarget) {
        let surface = self.surface ?? makeSurface()
        self.surface = surface
        let fade = reduceMotion() ? 0 : timing.fadeIn
        lastTarget = target; lastFadeIn = fade; shownCount += 1
        phase = .shown
        surface.show(target, fadeIn: fade)
        let input = self.input ?? makeInput()
        self.input = input
        let current = generation
        input.start { [weak self] in
            guard let self, self.generation == current, self.phase == .shown else { return }
            self.finish(.input)
        }
    }

    /// Ends at once for input, withdrawal and cancellation; the timeout fades unless Reduce Motion.
    func finish(_ reason: QuotaWidgetSpotlightEnd) {
        guard isActive else { return }
        generation &+= 1
        task?.cancel(); task = nil
        input?.stop()
        let fade = reason == .timeout && !reduceMotion() ? timing.fadeOut : 0
        if phase == .shown { lastFadeOut = fade; surface?.hide(fadeOut: fade) }
        phase = .idle; lastEnd = reason
        onActiveChange?(false)
    }
}

/// One borderless, click-through window over the widget's whole display.
@MainActor final class QuotaWidgetSpotlightWindowSurface: QuotaWidgetSpotlightSurface {
    private(set) var window: NSPanel?
    private let view = QuotaWidgetSpotlightView(frame: .zero)
    private var hideGeneration: UInt64 = 0

    func show(_ target: QuotaWidgetSpotlightTarget, fadeIn: TimeInterval) {
        hideGeneration &+= 1
        let panel = window ?? makeWindow()
        window = panel
        panel.setFrame(target.display, display: false)
        view.frame = CGRect(origin: .zero, size: target.display.size)
        let hole = QuotaWidgetSpotlightStyle.hole(for: target)
        view.hole = hole.offsetBy(dx: -target.display.minX, dy: -target.display.minY)
        panel.alphaValue = fadeIn > 0 ? 0 : 1
        panel.orderFrontRegardless()
        guard fadeIn > 0 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeIn
            panel.animator().alphaValue = 1
        }
    }

    func hide(fadeOut: TimeInterval) {
        guard let panel = window else { return }
        hideGeneration &+= 1
        let current = hideGeneration
        guard fadeOut > 0 else { panel.alphaValue = 0; panel.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeOut
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.hideGeneration == current else { return }
                self.window?.orderOut(nil)
            }
        })
    }

    private func makeWindow() -> NSPanel {
        let panel = QuotaWidgetSpotlightPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                              backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = QuotaWidgetSpotlightStyle.level
        panel.collectionBehavior = QuotaWidgetSpotlightStyle.collectionBehavior
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.setAccessibilityElement(false)
        panel.contentView = view
        return panel
    }
}

/// Never key or main: the person's app keeps focus and keyboard input.
private final class QuotaWidgetSpotlightPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class QuotaWidgetSpotlightView: NSView {
    private let dim = CAShapeLayer(), ring = CAShapeLayer()
    var hole: CGRect = .zero { didSet { layoutLayers() } }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        dim.fillRule = .evenOdd
        dim.fillColor = NSColor.black.withAlphaComponent(QuotaWidgetSpotlightStyle.dimAlpha).cgColor
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = NSColor.white.withAlphaComponent(QuotaWidgetSpotlightStyle.ringAlpha).cgColor
        ring.lineWidth = QuotaWidgetSpotlightStyle.ringWidth
        ring.shadowColor = NSColor.white.cgColor; ring.shadowOpacity = 0.9
        ring.shadowRadius = QuotaWidgetSpotlightStyle.ringGlowRadius; ring.shadowOffset = .zero
        layer?.addSublayer(dim); layer?.addSublayer(ring)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() { super.layout(); layoutLayers() }
    override var frame: NSRect { didSet { layoutLayers() } }
    var dimAlphaForChecks: CGFloat { dim.fillColor.flatMap { NSColor(cgColor: $0)?.alphaComponent } ?? 0 }
    private func layoutLayers() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        dim.frame = bounds; ring.frame = bounds
        // CGPath requires a corner no larger than half the side.
        let radius = max(0, min(QuotaWidgetSpotlightStyle.holeCornerRadius, hole.width / 2, hole.height / 2))
        let rounded = CGPath(roundedRect: hole, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let path = CGMutablePath(); path.addRect(bounds)
        if !hole.isEmpty { path.addPath(rounded) }
        dim.path = path
        ring.path = hole.isEmpty ? nil : rounded
        CATransaction.commit()
    }
}

/// Global monitors see clicks in other apps without any permission. macOS delivers other apps'
/// key presses to a global monitor only with Accessibility access; without it a key ends the
/// spotlight only while ModelPlan is active, and the 1.5 s hold ends it otherwise.
@MainActor final class QuotaWidgetSpotlightEventMonitor: QuotaWidgetSpotlightInput {
    static let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
    private var global: Any?, local: Any?
    func start(_ onInput: @escaping @MainActor () -> Void) {
        stop()
        global = NSEvent.addGlobalMonitorForEvents(matching: Self.events) { _ in
            MainActor.assumeIsolated { onInput() }
        }
        local = NSEvent.addLocalMonitorForEvents(matching: Self.events) { event in
            MainActor.assumeIsolated { onInput() }
            return event
        }
    }
    func stop() {
        if let global { NSEvent.removeMonitor(global) }
        if let local { NSEvent.removeMonitor(local) }
        global = nil; local = nil
    }
}

/// Window-free composition (no native panels): records what would be drawn.
@MainActor final class DetachedQuotaWidgetSpotlightSurface: QuotaWidgetSpotlightSurface {
    private(set) var shown: QuotaWidgetSpotlightTarget?
    private(set) var fadeIns: [TimeInterval] = [], fadeOuts: [TimeInterval] = []
    func show(_ target: QuotaWidgetSpotlightTarget, fadeIn: TimeInterval) { shown = target; fadeIns.append(fadeIn) }
    func hide(fadeOut: TimeInterval) { shown = nil; fadeOuts.append(fadeOut) }
}

/// Window-free composition: no event monitor; `send()` stands in for a click or key.
@MainActor final class DetachedQuotaWidgetSpotlightInput: QuotaWidgetSpotlightInput {
    private var onInput: (@MainActor () -> Void)?
    private(set) var listening = false
    func start(_ onInput: @escaping @MainActor () -> Void) { self.onInput = onInput; listening = true }
    func stop() { onInput = nil; listening = false }
    func send() { onInput?() }
}
