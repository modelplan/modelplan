// SPDX-License-Identifier: MIT
import AppKit

/// D56 Find Quota Widget (owner 2026-11-08). The widget slides out if it is collapsed; the rest of
/// its display, menu bar included, dims to about 60 % within 0.2 s with a soft feathered clearing
/// around the widget (no ring, no stroke); it holds about 1.5 s, then fades. Any click or key ends it at once. The overlay
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
    /// The clearing's edge is not a line: dimming rises smoothly from none at the hole's edge to
    /// `dimAlpha` this many points further out.
    static let featherRadius: CGFloat = 24
    /// Dim alpha at `distance` points outside the hole's edge (zero or less: inside, undimmed).
    static func dimAlpha(atDistance distance: CGFloat) -> CGFloat {
        let t = min(1, max(0, distance / featherRadius))
        return dimAlpha * t * t * (3 - 2 * t)
    }
    /// A soft accent-coloured glow that follows the hole: full strength at the hole's edge, gone `haloRadius`
    /// points out, and a few points inside so there is no hard edge. A glow, never a stroke or ring.
    static let haloRadius: CGFloat = 20
    static let haloInnerFade: CGFloat = 6
    static let haloPulse: TimeInterval = 0.6
    /// Peak alpha: stronger on a dark desktop (dimming it changes little), weaker on a light one; Increase Contrast adds a bit.
    static func haloPeak(dark: Bool, increaseContrast: Bool) -> CGFloat {
        let base: CGFloat = dark ? 0.35 : 0.22
        return increaseContrast ? min(0.45, base * 1.3) : base
    }
    /// Halo alpha at `distance` points outside the hole's edge (negative: inside).
    static func haloAlpha(atDistance d: CGFloat, peak: CGFloat) -> CGFloat {
        func smooth(_ t: CGFloat) -> CGFloat { let c = min(1, max(0, t)); return c * c * (3 - 2 * c) }
        if d < 0 { return peak * smooth((d + haloInnerFade) / haloInnerFade) }
        return peak * smooth(1 - d / haloRadius)
    }
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
        view.pulseHalo(duration: fadeIn > 0 ? QuotaWidgetSpotlightStyle.haloPulse : 0)
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
    /// Flat dim everywhere beyond the feather; the feather layer carries the soft edge.
    private let dim = CAShapeLayer(), feather = CALayer(), halo = CALayer()
    var hole: CGRect = .zero { didSet { layoutLayers() } }
    /// Whether the desktop under the widget is dark. nil: follow the effective appearance (the window server's
    /// pixels need Screen Recording permission, which a find command must not ask for).
    var backdropIsDark: Bool? { didSet { layoutLayers() } }
    var increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast { didSet { layoutLayers() } }
    private var isDark: Bool {
        backdropIsDark ?? (effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    }
    /// One gentle fade-in of the glow; none under Reduce Motion (duration 0).
    func pulseHalo(duration: TimeInterval) {
        halo.removeAllAnimations()
        guard duration > 0 else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0; fade.toValue = 1; fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        halo.add(fade, forKey: "haloPulse")
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        dim.fillRule = .evenOdd
        dim.fillColor = NSColor.black.withAlphaComponent(QuotaWidgetSpotlightStyle.dimAlpha).cgColor
        dim.strokeColor = nil; dim.lineWidth = 0
        feather.magnificationFilter = .linear
        halo.magnificationFilter = .linear
        layer?.addSublayer(dim); layer?.addSublayer(feather); layer?.addSublayer(halo)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() { super.layout(); layoutLayers() }
    override var frame: NSRect { didSet { layoutLayers() } }
    var dimAlphaForChecks: CGFloat { dim.fillColor.flatMap { NSColor(cgColor: $0)?.alphaComponent } ?? 0 }
    /// What is drawn, for checks: no stroke or border anywhere, and the feathered edge.
    struct DrawnForChecks {
        let dimAlpha: CGFloat, featherRadius: CGFloat
        let hasStrokeOrBorder: Bool, hasShadow: Bool
        let featherFrame: CGRect?, featherHasImage: Bool
        let dimContainsHoleCentre: Bool, dimContainsCorner: Bool
        /// Dim alpha at a point in view coordinates, from the image actually drawn (nil outside it).
        let alphaAt: (CGPoint) -> CGFloat?
    }
    var drawnForChecks: DrawnForChecks {
        let centre = CGPoint(x: hole.midX, y: hole.midY)
        let layers: [CALayer] = [dim, feather, halo, layer].compactMap { $0 }
        let stroked = layers.contains { l in
            l.borderWidth > 0 || ((l as? CAShapeLayer).map { $0.strokeColor != nil && $0.lineWidth > 0 } ?? false)
        }
        let image = feather.contents.map { $0 as! CGImage }
        let frame = feather.frame
        return .init(dimAlpha: dimAlphaForChecks, featherRadius: QuotaWidgetSpotlightStyle.featherRadius,
                     hasStrokeOrBorder: stroked, hasShadow: layers.contains { $0.shadowOpacity > 0 },
                     featherFrame: image == nil ? nil : frame, featherHasImage: image != nil,
                     dimContainsHoleCentre: dim.path?.contains(centre, using: .evenOdd) ?? false,
                     dimContainsCorner: dim.path?.contains(CGPoint(x: 1, y: 1), using: .evenOdd) ?? false,
                     alphaAt: { point in
                         guard let image, frame.contains(point) else { return nil }
                         return Self.alpha(of: image, atFraction: CGPoint(x: (point.x - frame.minX) / frame.width,
                                                                          y: (point.y - frame.minY) / frame.height))
                     })
    }

    private func layoutLayers() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        dim.frame = bounds
        guard !hole.isEmpty else {
            let path = CGMutablePath(); path.addRect(bounds)
            dim.path = path; feather.contents = nil; feather.frame = .zero; halo.contents = nil; halo.frame = .zero
            imageKey = nil
            return
        }
        // The flat dim stops where the feather has reached full strength, so the two meet unseen.
        let reach = QuotaWidgetSpotlightStyle.featherRadius
        let outer = hole.insetBy(dx: -reach, dy: -reach)
        let path = CGMutablePath(); path.addRect(bounds)
        path.addRect(outer.intersection(bounds))
        dim.path = path
        let region = outer.intersection(bounds)
        let scale = max(1, window?.backingScaleFactor ?? 2)
        feather.contentsScale = scale; halo.contentsScale = scale
        feather.frame = region; halo.frame = region
        // The pixel loops are not cheap: draw once per geometry and tint, never again for a repeated layout.
        let peak = QuotaWidgetSpotlightStyle.haloPeak(dark: isDark, increaseContrast: increaseContrast)
        let key = ImageKey(region: region, hole: hole, scale: scale, peak: peak)
        if key != imageKey {
            let images = Self.overlayImages(region: region, hole: hole, scale: scale, peak: peak)
            feather.contents = images.feather; halo.contents = images.halo
            imageKey = key
        }
    }
    private struct ImageKey: Equatable { let region: CGRect, hole: CGRect, scale: CGFloat, peak: CGFloat }
    private var imageKey: ImageKey?

    /// The dim feather and the accent halo from one pass over the pixels (one distance per pixel).
    static func overlayImages(region: CGRect, hole: CGRect, scale: CGFloat, peak: CGFloat) -> (feather: CGImage?, halo: CGImage?) {
        let w = max(1, Int((region.width * scale).rounded())), h = max(1, Int((region.height * scale).rounded()))
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? NSColor.systemBlue.usingColorSpace(.sRGB)!
        let rgb = [accent.redComponent, accent.greenComponent, accent.blueComponent]
        var dimBytes = [UInt8](repeating: 0, count: w * h * 4), haloBytes = dimBytes
        let radius = QuotaWidgetSpotlightStyle.holeCornerRadius
        for row in 0..<h {
            let y = region.maxY - (CGFloat(row) + 0.5) / scale
            for column in 0..<w {
                let x = region.minX + (CGFloat(column) + 0.5) / scale
                let d = distance(from: CGPoint(x: x, y: y), toRounded: hole, radius: radius)
                let i = (row * w + column) * 4
                dimBytes[i + 3] = UInt8((QuotaWidgetSpotlightStyle.dimAlpha(atDistance: d) * 255).rounded())
                let a = QuotaWidgetSpotlightStyle.haloAlpha(atDistance: d, peak: peak)
                if a > 0 {
                    for c in 0..<3 { haloBytes[i + c] = UInt8((rgb[c] * a * 255).rounded()) }
                    haloBytes[i + 3] = UInt8((a * 255).rounded())
                }
            }
        }
        func image(_ bytes: [UInt8], _ space: CGColorSpace) -> CGImage? {
            guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
            return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                           provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }
        return (image(dimBytes, CGColorSpaceCreateDeviceRGB()), image(haloBytes, CGColorSpace(name: CGColorSpace.sRGB)!))
    }

    /// Distance from `point` to the rounded rectangle's edge; negative inside.
    static func distance(from point: CGPoint, toRounded rect: CGRect, radius: CGFloat) -> CGFloat {
        let r = max(0, min(radius, rect.width / 2, rect.height / 2))
        let dx = abs(point.x - rect.midX) - (rect.width / 2 - r)
        let dy = abs(point.y - rect.midY) - (rect.height / 2 - r)
        return hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - r
    }

    /// Black with the feathered alpha, premultiplied, covering `region` (view points, y up).
    static func featherImage(region: CGRect, hole: CGRect, scale: CGFloat) -> CGImage? {
        let w = max(1, Int((region.width * scale).rounded())), h = max(1, Int((region.height * scale).rounded()))
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let radius = QuotaWidgetSpotlightStyle.holeCornerRadius
        for row in 0..<h {
            // Image row 0 is the top; view y grows upward.
            let y = region.maxY - (CGFloat(row) + 0.5) / scale
            for column in 0..<w {
                let x = region.minX + (CGFloat(column) + 0.5) / scale
                let d = distance(from: CGPoint(x: x, y: y), toRounded: hole, radius: radius)
                let alpha = QuotaWidgetSpotlightStyle.dimAlpha(atDistance: d)
                bytes[(row * w + column) * 4 + 3] = UInt8((alpha * 255).rounded())
            }
        }
        let space = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Alpha of the image at a fractional position (0...1, y up in view terms).
    static func alpha(of image: CGImage, atFraction f: CGPoint) -> CGFloat? {
        guard let data = image.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return nil }
        let column = min(image.width - 1, max(0, Int(f.x * CGFloat(image.width))))
        let row = min(image.height - 1, max(0, Int((1 - f.y) * CGFloat(image.height))))
        return CGFloat(ptr[row * image.bytesPerRow + column * 4 + 3]) / 255
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
