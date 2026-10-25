// SPDX-License-Identifier: MIT
import AppKit
import CoreText

@MainActor public final class EngineTableView: NSView {
    public let recipeProvider: any EngineTableRecipeProvider
    public private(set) var presentation: EngineTablePresentation?
    public private(set) var recipe: EngineTableRecipe?
    public private(set) var renderError: String?
    public private(set) var glyphMetrics: [EngineGlyphMetric] = []
    public private(set) var displayRequests = 0
    public private(set) var drawCount = 0
    public var onIntent: ((EngineTableIntent) -> Void)?
    public var onHelpChange: ((HelpExplanation?, CGRect?) -> Void)?
    public var reducedMotion = false
    private var input: [EngineColumn] = [], identities: [String: EngineTableIdentity] = [:]
    private var language: InstrumentLanguage = .chinese, clock = Date(timeIntervalSince1970: 0)
    private var page = 0, scope: InstrumentScope = .all
    private var controls: [String: EngineRegionControl] = [:], focusID: String?
    private var dwell = HelpDwell(), dwellTimer: Timer?, helpPopover: NSPopover?
    private var tracking: NSTrackingArea?
    private var textLayers: [String: CALayer] = [:], previousText: [String: EngineTextCommand] = [:]
    private let focusLayer = CAShapeLayer()
    private let elapsed: () -> Double
    fileprivate var keyboardModality = true
    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    public override var intrinsicContentSize: NSSize { NSSize(width: 640, height: 300) }

    public init(frame: NSRect = NSRect(x: 0, y: 0, width: 640, height: 300),
                recipeProvider: (any EngineTableRecipeProvider)? = nil,
                elapsed: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.recipeProvider = recipeProvider ?? NeutralEngineTableRecipe(); self.elapsed = elapsed
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua); wantsLayer = true
        layer?.masksToBounds = false
        focusLayer.fillColor = nil; focusLayer.zPosition = 1
        layer?.addSublayer(focusLayer)
        setAccessibilityElement(false); setAccessibilityIdentifier("engine.table")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    public func update(columns: [EngineColumn], identities: [String: EngineTableIdentity] = [:], language: InstrumentLanguage,
                       now: Date, page: Int? = nil, scope: InstrumentScope? = nil) throws {
        let candidate = EngineTablePresentation(columns: columns, identities: identities, requestedPage: page ?? self.page,
                                                scope: scope ?? self.scope, language: language, now: now)
        if candidate == presentation && recipe?.size == bounds.size {
            input = columns; self.identities = identities; self.language = language; clock = now
            self.page = candidate.page; self.scope = candidate.scope
            return
        }
        var next: EngineTableRecipe!
        var failure: Error?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            do { next = try recipeProvider.recipe(for: candidate, size: bounds.size); try next.validate() }
            catch { failure = error }
        }
        if let failure { throw failure }
        // Validate fonts/images before publishing the new view state. No private-file fallback is selected here.
        _ = try EngineRecipeDrawing.raster(next, provider: recipeProvider, scale: 1)
        let old = presentation
        let oldOrder = keyboardOrder
        input = columns; self.identities = identities; self.language = language; clock = now
        self.page = candidate.page; self.scope = candidate.scope
        presentation = candidate; recipe = next; renderError = nil
        synchronizeRegions(next.regions, previousOrder: oldOrder)
        try synchronizeTextLayers(next, initial: old == nil)
        synchronizeFocusLayer()
        if let source = dwell.sourceID, !next.regions.contains(where: { $0.id == source }) { leaveHelp() }
        else if dwell.visibleSourceID != nil { showHelp() }
        displayRequests += 1; needsDisplay = true
    }
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard presentation != nil else { return }
        do { try update(columns: input, identities: identities, language: language, now: clock) }
        catch { renderError = String(describing: error) }
    }
    public override func draw(_ dirtyRect: NSRect) {
        guard let recipe, let c = NSGraphicsContext.current?.cgContext else { return }
        do {
            drawCount += 1
            glyphMetrics = try EngineRecipeDrawing.draw(recipe, in: c, provider: recipeProvider, includeTransitionText: false)
        } catch { renderError = String(describing: error) }
    }
    public func rasterImage(scale: Int) throws -> CGImage {
        guard let recipe else { throw EngineTableError.invalidRecipe }
        let (image, metrics) = try EngineRecipeDrawing.raster(recipe, provider: recipeProvider, scale: scale)
        glyphMetrics = metrics; return image
    }
    public var regionIDs: [String] { recipe?.regions.map(\.id) ?? [] }
    public var keyboardOrder: [String] { recipe?.regions.filter(\.tabStop).map(\.id) ?? [] }
    public func control(for id: String) -> NSControl? { controls[id] }
    public func activate(_ intent: EngineTableIntent) {
        do {
            switch intent {
            case .changePage(let p):
                guard p >= 0, p < (presentation?.pageCount ?? 0) else { return }
                try update(columns: input, identities: identities, language: language, now: clock, page: p)
            case .selectScope(let scope): try update(columns: input, identities: identities, language: language, now: clock, scope: scope)
            case .openSubscriptionsSettings: break
            }
            onIntent?(intent)
        } catch { renderError = String(describing: error) }
    }
    fileprivate func shortcut(_ event: NSEvent) -> Bool {
        guard let key = event.charactersIgnoringModifiers, let n = Int(key), (0...6).contains(n) else { return false }
        if n == 0 { activate(.selectScope(.all)); return true }
        guard let p = presentation, n <= p.columns.count, let col = p.columns[n - 1] else { return false }
        activate(.selectScope(.subscription(col.id))); return true
    }
    public override func keyDown(with event: NSEvent) {
        keyboardModality = true
        synchronizeFocusLayer()
        if event.keyCode == 48, let id = event.modifierFlags.contains(.shift) ? keyboardOrder.last : keyboardOrder.first {
            window?.makeFirstResponder(controls[id]); return
        }
        if !shortcut(event) { super.keyDown(with: event) }
    }
    private func synchronizeRegions(_ regions: [EngineHitRegion], previousOrder: [String]) {
        let wanted = Set(regions.map(\.id))
        let oldFocused = controls.first { $0.value === window?.firstResponder }?.key
        for id in Array(controls.keys) where !wanted.contains(id) { controls.removeValue(forKey: id)?.removeFromSuperview() }
        for region in regions {
            let control = controls[region.id] ?? EngineRegionControl(owner: self, region: region)
            if controls[region.id] == nil { controls[region.id] = control; addSubview(control) }
            control.configure(region)
        }
        let ordered = regions.filter(\.tabStop).compactMap { controls[$0.id] }
        for (index, control) in ordered.enumerated() { control.nextKeyView = ordered[(index + 1) % ordered.count] }
        setAccessibilityChildren(regions.compactMap { controls[$0.id] })
        if let oldFocused, controls[oldFocused] == nil, !ordered.isEmpty {
            let index = previousOrder.firstIndex(of: oldFocused) ?? 0
            window?.makeFirstResponder(ordered[min(index, ordered.count - 1)])
        }
    }
    private func synchronizeTextLayers(_ recipe: EngineTableRecipe, initial: Bool) throws {
        let commands = recipe.commands.compactMap { command -> EngineTextCommand? in
            if case .text(let text) = command, text.transitionDuration > 0 { return text }; return nil
        }
        let ids = Set(commands.map(\.id))
        for id in Array(textLayers.keys) where !ids.contains(id) {
            textLayers.removeValue(forKey: id)?.removeFromSuperlayer(); previousText.removeValue(forKey: id)
        }
        let scale = (window?.backingScaleFactor ?? 2) >= 2 ? 2 : 1
        for command in commands {
            if previousText[command.id] == command { continue }
            var local = command
            local.rect.origin = .zero; local.baseline = command.baseline.map { $0 - command.rect.minY }
            let single = EngineTableRecipe(size: command.rect.size, commands: [.text(local)], regions: [])
            let (image, _) = try EngineRecipeDrawing.raster(single, provider: recipeProvider, scale: scale)
            let textLayer = textLayers[command.id] ?? CALayer()
            if textLayers[command.id] == nil { textLayers[command.id] = textLayer; layer?.addSublayer(textLayer) }
            CATransaction.begin(); CATransaction.setDisableActions(true)
            textLayer.frame = command.rect; textLayer.contentsScale = CGFloat(scale); textLayer.contents = image
            textLayer.opacity = 1; textLayer.removeAllAnimations(); CATransaction.commit()
            if !initial, !reducedMotion, window?.isVisible == true, previousText[command.id]?.variants != command.variants {
                let animation = CABasicAnimation(keyPath: "opacity"); animation.fromValue = 0; animation.toValue = 1
                animation.duration = command.transitionDuration; animation.isRemovedOnCompletion = true
                textLayer.add(animation, forKey: "reading")
            }
            previousText[command.id] = command
        }
    }
    private func synchronizeFocusLayer() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        focusLayer.frame = bounds
        guard keyboardModality, let focusID, let control = controls[focusID],
              let style = control.region.focus ?? recipe?.focusInk.map({ EngineFocusStyle(ink: $0, width: 1, outset: -1, radius: 0) }) else {
            focusLayer.path = nil; return
        }
        let rect = control.frame.insetBy(dx: -style.outset, dy: -style.outset)
        focusLayer.strokeColor = style.ink.cgColor; focusLayer.lineWidth = style.width
        focusLayer.path = CGPath(roundedRect: rect, cornerWidth: style.radius, cornerHeight: style.radius, transform: nil)
    }
    fileprivate func pointerModality() { keyboardModality = false; synchronizeFocusLayer() }
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        previousText.removeAll()
        if let recipe { try? synchronizeTextLayers(recipe, initial: true) }
    }
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        previousText.removeAll()
        if let recipe { try? synchronizeTextLayers(recipe, initial: true) }
        if window == nil { suspend() }
    }
    public override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let tracking = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        self.tracking = tracking; addTrackingArea(tracking); super.updateTrackingAreas()
    }
    public override func mouseMoved(with event: NSEvent) {
        pointerModality()
        let point = convert(event.locationInWindow, from: nil)
        // Specific readouts/keys precede whole empty-bay regions in a provider's ordered list.
        guard let region = recipe?.regions.first(where: { $0.rect.contains(point) }) else { leaveHelp(); return }
        dwell.enter(region.id, keyboardFocus: false, at: elapsed()); scheduleHelp()
    }
    public override func mouseExited(with event: NSEvent) { leaveHelp() }
    fileprivate func focused(_ id: String?) {
        focusID = id
        synchronizeFocusLayer()
        guard keyboardModality, let id else { leaveHelp(); return }
        dwell.enter(id, keyboardFocus: true, at: elapsed()); showHelp(); needsDisplay = true
    }
    private func scheduleHelp() {
        dwellTimer?.invalidate(); dwellTimer = nil
        if let deadline = dwell.nextDeadline {
            let timer = Timer(timeInterval: max(0, deadline - elapsed()), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }; self.dwellTimer = nil; self.dwell.advance(at: self.elapsed()); self.showHelp() }
            }
            RunLoop.main.add(timer, forMode: .common); dwellTimer = timer
        }
    }
    private func showHelp() {
        guard let id = dwell.visibleSourceID, let region = recipe?.regions.first(where: { $0.id == id }) else { return }
        if let onHelpChange { onHelpChange(region.help, region.rect); return }
        guard window?.isVisible == true else { return }
        let controller = NSViewController()
        let title = NSTextField(labelWithString: region.help.title), body = NSTextField(wrappingLabelWithString: region.help.body)
        title.font = .boldSystemFont(ofSize: 11); body.font = .systemFont(ofSize: 11)
        let stack = NSStackView(views: [title, body]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        body.preferredMaxLayoutWidth = 260
        stack.widthAnchor.constraint(equalToConstant: 280).isActive = true
        stack.setFrameSize(NSSize(width: 280, height: max(74, stack.fittingSize.height))); controller.view = stack
        let popover = helpPopover ?? NSPopover(); popover.animates = false; popover.behavior = .transient; popover.contentViewController = controller
        helpPopover = popover; popover.show(relativeTo: bounds, of: self, preferredEdge: .minX)
    }
    public func leaveHelp() {
        dwellTimer?.invalidate(); dwellTimer = nil; dwell.leave(); helpPopover?.close(); onHelpChange?(nil, nil)
    }
    public func suspend() { leaveHelp(); textLayers.values.forEach { $0.removeAllAnimations() } }
    public func dispose() { suspend(); onIntent = nil; onHelpChange = nil }
}

@MainActor private final class EngineRegionControl: NSControl {
    weak var owner: EngineTableView?
    var region: EngineHitRegion
    init(owner: EngineTableView, region: EngineHitRegion) {
        self.owner = owner; self.region = region
        super.init(frame: region.rect); focusRingType = .none; configure(region)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { region.tabStop }
    override var canBecomeKeyView: Bool { region.tabStop && !isHidden }
    override func draw(_ dirtyRect: NSRect) {} // Never paints a separate empty-bay surface.
    func configure(_ region: EngineHitRegion) {
        self.region = region; frame = region.rect; isEnabled = region.enabled
        setAccessibilityElement(true); setAccessibilityIdentifier(region.id)
        setAccessibilityRole(region.role == .button ? .button : region.role == .image ? .image : .group)
        setAccessibilityLabel(region.label); setAccessibilityHelp(region.help.accessibleDescription)
        setAccessibilityEnabled(region.enabled)
        if let intent = region.intent, case .selectScope = intent { setAccessibilityValue(region.selected ? 1 : 0) }
        else { setAccessibilityValue(nil) }
    }
    override func becomeFirstResponder() -> Bool { owner?.focused(region.id); return true }
    override func resignFirstResponder() -> Bool { owner?.focused(nil); return true }
    override func mouseDown(with event: NSEvent) {
        owner?.pointerModality()
        if acceptsFirstResponder { window?.makeFirstResponder(self) }
        guard region.enabled, let intent = region.intent else { return }
        while let next = NSApp.nextEvent(matching: [.leftMouseUp, .leftMouseDragged], until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            if next.type == .leftMouseUp {
                if bounds.contains(convert(next.locationInWindow, from: nil)) { owner?.activate(intent) }
                break
            }
        }
    }
    override func keyDown(with event: NSEvent) {
        owner?.keyboardModality = true
        if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) { window?.selectPreviousKeyView(self) } else { window?.selectNextKeyView(self) }
        } else if event.keyCode == 36 || event.keyCode == 76 || event.charactersIgnoringModifiers == " " {
            _ = accessibilityPerformPress()
        } else if owner?.shortcut(event) != true { super.keyDown(with: event) }
    }
    override func accessibilityPerformPress() -> Bool {
        guard region.enabled, let intent = region.intent else { return false }
        owner?.activate(intent); return true
    }
}
