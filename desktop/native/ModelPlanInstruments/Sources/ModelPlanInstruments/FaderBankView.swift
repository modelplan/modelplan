// SPDX-License-Identifier: MIT
import AppKit
import CoreText

@MainActor public final class FaderBankView: NSView {
    public let recipeProvider: any FaderBankRecipeProvider
    public private(set) var controller = FaderBankController()
    public private(set) var presentation: FaderBankPresentation?
    public private(set) var recipe: FaderBankRecipe?
    public private(set) var renderError: String?
    public private(set) var displayRequests = 0, drawCount = 0, surfaceRenders = 0
    public var onIntent: ((FaderIntent) -> Void)?
    public var onHelpChange: ((HelpExplanation?, CGRect?) -> Void)?
    public var onHintInput: ((InstrumentHintInput) -> Void)?
    public var reducedMotion = false { didSet { if reducedMotion { stopAnimations() } } }
    private var language: InstrumentLanguage = .chinese, compact = false, showProjectNames = true
    private var now = Date(timeIntervalSince1970: 0)
    private let elapsed: () -> Double
    private let hintPointerEligible: () -> Bool
    private var controls: [String: FaderRegionControl] = [:]
    private var surfaces: [String: CALayer] = [:], oldCaps: [String: FaderCapSurface] = [:], oldTexts: [String: EngineTextCommand] = [:]
    private var surfaceScale: Int?, tokens: [String: Int] = [:]
    private let focus = CAShapeLayer()
    private var focusedID: String?, keyboard = true
    private var timer: Timer?, dwellTimer: Timer?, dwell = HelpDwell(), tracking: NSTrackingArea?, popover: NSPopover?
    private var restAnchor: FaderRestAnchor?
    private var hintObservers: [NSObjectProtocol] = []
    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    private var scale: Int { (window?.backingScaleFactor ?? 2) >= 2 ? 2 : 1 }
    public override var intrinsicContentSize: NSSize { presentation.map { recipeProvider.minimumSize(for: $0) } ?? CGSize(width: 360, height: 320) }
    public init(frame: CGRect = CGRect(x: 0, y: 0, width: 360, height: 320), recipeProvider: (any FaderBankRecipeProvider)? = nil,
                elapsed: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
                hintPointerEligible: @escaping () -> Bool = { NSEvent.pressedMouseButtons == 0 }) {
        self.recipeProvider = recipeProvider ?? NeutralFaderBankRecipe(); self.elapsed = elapsed; self.hintPointerEligible = hintPointerEligible
        super.init(frame: frame); appearance = NSAppearance(named: .darkAqua); wantsLayer = true
        focus.fillColor = nil; focus.zPosition = 10; layer?.masksToBounds = false; layer?.addSublayer(focus)
        setAccessibilityElement(false); setAccessibilityIdentifier("fader.bank")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    deinit { hintObservers.forEach { NotificationCenter.default.removeObserver($0) } }

    public func update(inputs: [FaderChannelInput], publicationUsable: Bool, language: InstrumentLanguage, compact: Bool,
                       now: Date, favoriteIDs: [String]? = nil, selectedModelID: String? = nil,
                       trial: FaderTrial? = nil, showProjectNames: Bool = true, catalogueOnly: Bool = false) throws {
        var state = controller
        let changes = state.update(inputs: inputs, publicationUsable: publicationUsable, favoriteIDs: favoriteIDs,
                                   selectedModelID: selectedModelID, catalogueOnly: catalogueOnly)
        if publicationUsable, let trial, !state.setTrial(trial) { throw EngineTableError.invalidRecipe }
        try publish(state, language: language, compact: compact, now: now, showProjectNames: showProjectNames)
        changes.forEach { onIntent?($0) }
    }
    private struct Prepared {
        let caps: [(FaderCapSurface, CGImage)]
        let texts: [(EngineTextCommand, CGImage)]
    }
    private func publish(_ state: FaderBankController, language: InstrumentLanguage, compact: Bool, now: Date,
                         showProjectNames: Bool, force: Bool = false) throws {
        let p = FaderBankPresentation(inputs: state.inputs, requestedBank: state.bank, selectedModelID: state.selectedModelID,
            favoriteIDs: state.favoriteIDs, trial: state.trial, sourceModelID: state.sourceHighlightID, draggingModelID: state.draggingModelID, dragPosition: state.dragPosition,
            previewModelID: state.previewModelID, previewEffort: state.previewEffort,
            publicationUsable: state.publicationUsable, language: language, compact: compact, showProjectNames: showProjectNames,
            now: now, catalogueOnly: state.catalogueOnly)
        if !force, p == presentation, recipe?.size == bounds.size, surfaceScale == scale {
            controller = state; self.now = now; return
        }
        var next: FaderBankRecipe!, error: Error?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            do { next = try recipeProvider.recipe(for: p, size: bounds.size); try next.validate() } catch let e { error = e }
        }
        if let error { throw error }
        // Pointer-owned cap movement reuses the already prepared static recipe.
        if force || recipe?.commands != next.commands || recipe?.size != next.size || surfaceScale != scale {
            _ = try EngineRecipeDrawing.raster(.init(size: next.size, commands: next.commands, regions: []), provider: recipeProvider, scale: 1)
        }
        var capImages: [(FaderCapSurface, CGImage)] = [], textImages: [(EngineTextCommand, CGImage)] = []
        for cap in next.caps {
            if !force, surfaceScale == scale, let old = oldCaps[cap.id], old.commands == cap.commands, old.frame.size == cap.frame.size, surfaces[cap.id] != nil { continue }
            let image = try EngineRecipeDrawing.raster(.init(size: cap.frame.size, commands: cap.commands, regions: []), provider: recipeProvider, scale: scale).0
            capImages.append((cap, image))
        }
        for command in next.commands {
            guard case .text(let t) = command, t.transitionDuration > 0 else { continue }
            if !force, surfaceScale == scale, oldTexts[t.id] == t, surfaces["text." + t.id] != nil { continue }
            var local = t; local.rect.origin = .zero; local.baseline = t.baseline.map { $0 - t.rect.minY }
            let image = try EngineRecipeDrawing.raster(.init(size: t.rect.size, commands: [.text(local)], regions: []), provider: recipeProvider, scale: scale).0
            textImages.append((t, image))
        }
        let previous = recipe, initial = presentation == nil, oldOrder = keyboardOrder
        controller = state; presentation = p; recipe = next; self.language = language; self.compact = compact
        self.now = now; self.showProjectNames = showProjectNames; renderError = nil
        surfaceRenders += capImages.count + textImages.count
        commitSurfaces(next, prepared: Prepared(caps: capImages, texts: textImages), initial: initial)
        synchronizeRegions(next.regions, oldOrder: oldOrder); updateFocus()
        if let anchor = restAnchor {
            if !state.publicationUsable { cancelHintRest(.removal) }
            else if let region = next.regions.first(where: { $0.id == anchor.regionID && $0.modelID == anchor.modelID }) {
                if region.rect != anchor.travel { cancelHintRest(.layoutChange) }
            } else { cancelHintRest(.removal) }
        }
        if let id = dwell.sourceID, !next.regions.contains(where: { $0.id == id }) { leaveHelp() }
        else if dwell.visibleSourceID != nil { showHelp() }
        if previous?.commands != next.commands || previous?.size != next.size { displayRequests += 1; needsDisplay = true }
        invalidateIntrinsicContentSize()
    }
    private func imageLayer(_ id: String) -> CALayer {
        if let result = surfaces[id] { return result }
        let result = CALayer(); surfaces[id] = result; layer?.addSublayer(result); return result
    }
    private func commitSurfaces(_ next: FaderBankRecipe, prepared: Prepared, initial: Bool) {
        let capImages = Dictionary(uniqueKeysWithValues: prepared.caps.map { ($0.0.id, $0.1) })
        let wanted = Set(next.caps.map(\.id))
        for (id, old) in oldCaps where !wanted.contains(id) {
            guard !reducedMotion,old.kind == .ghost, let target = next.caps.first(where: { $0.kind == .real && $0.modelID == old.modelID }),
                  window?.isVisible == true, let image = surfaces[id] else {
                surfaces.removeValue(forKey: id)?.removeFromSuperlayer(); continue
            }
            let token = (tokens[id] ?? 0) + 1; tokens[id] = token
            let from = image.presentation()?.position ?? image.position
            let opacity = image.presentation()?.opacity ?? image.opacity
            CATransaction.begin(); CATransaction.setDisableActions(true)
            if !reducedMotion { image.frame = target.frame }
            image.opacity = 0; CATransaction.commit()
            if !reducedMotion {
                let move = CABasicAnimation(keyPath: "position"); move.fromValue = from; move.toValue = image.position; move.duration = FaderTiming.glide
                if let t = old.timingCurve { move.timingFunction = CAMediaTimingFunction(controlPoints: t[0], t[1], t[2], t[3]) }
                image.add(move, forKey: "return")
            }
            let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = opacity; fade.toValue = 0
            fade.duration = reducedMotion ? 0.12 : 0.1
            let delay = reducedMotion ? 0.0 : 0.2
            fade.beginTime = image.convertTime(CACurrentMediaTime(), from: nil) + delay; fade.fillMode = .backwards
            image.add(fade, forKey: "hide")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + fade.duration) { [weak self] in
                guard let self, self.tokens[id] == token else { return }
                self.surfaces.removeValue(forKey: id)?.removeFromSuperlayer()
            }
        }
        for cap in next.caps {
            let prior = oldCaps[cap.id], image = imageLayer(cap.id)
            if prior == cap, capImages[cap.id] == nil, surfaceScale == scale { continue }
            tokens[cap.id] = (tokens[cap.id] ?? 0) + 1
            let actual = image.presentation()?.position ?? image.position
            let real = next.caps.first { $0.kind == .real && $0.modelID == cap.modelID }
            let from = prior == nil && cap.kind == .ghost ? real.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? actual : actual
            CATransaction.begin(); CATransaction.setDisableActions(true)
            image.frame = cap.frame; image.contentsScale = CGFloat(scale); image.opacity = cap.opacity
            if let pixels = capImages[cap.id] { image.contents = pixels }
            image.removeAllAnimations(); CATransaction.commit()
            if !initial, !reducedMotion, !cap.pointerOwned, window?.isVisible == true, from != image.position {
                let animation = CABasicAnimation(keyPath: "position"); animation.fromValue = from; animation.toValue = image.position
                animation.duration = FaderTiming.glide
                if let t = cap.timingCurve { animation.timingFunction = CAMediaTimingFunction(controlPoints: t[0], t[1], t[2], t[3]) }
                image.add(animation, forKey: "glide")
            }
        }
        oldCaps = Dictionary(uniqueKeysWithValues: next.caps.map { ($0.id, $0) })
        let textIDs = Set(next.commands.compactMap { c -> String? in if case .text(let t) = c, t.transitionDuration > 0 { return t.id }; return nil })
        for id in Array(oldTexts.keys) where !textIDs.contains(id) { surfaces.removeValue(forKey: "text." + id)?.removeFromSuperlayer(); oldTexts.removeValue(forKey: id) }
        for (text, pixels) in prepared.texts {
            let image = imageLayer("text." + text.id)
            CATransaction.begin(); CATransaction.setDisableActions(true); image.frame = text.rect; image.contents = pixels
            image.contentsScale = CGFloat(scale); image.opacity = 1; image.removeAllAnimations(); CATransaction.commit()
            if !initial, !reducedMotion, window?.isVisible == true, oldTexts[text.id]?.variants != text.variants {
                let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 0; fade.toValue = 1; fade.duration = FaderTiming.readingFade
                image.add(fade, forKey: "reading")
            }
            oldTexts[text.id] = text
        }
        surfaceScale = scale
    }
    public override func draw(_ dirtyRect: NSRect) {
        guard let recipe, let context = NSGraphicsContext.current?.cgContext else { return }
        do { drawCount += 1; try EngineRecipeDrawing.draw(.init(size: recipe.size, commands: recipe.commands, regions: []), in: context, provider: recipeProvider, includeTransitionText: false) }
        catch { renderError = String(describing: error) }
    }
    public func rasterImage(scale: Int) throws -> CGImage {
        guard let recipe else { throw EngineTableError.invalidRecipe }
        let base = try EngineRecipeDrawing.raster(.init(size: recipe.size, commands: recipe.commands, regions: []), provider: recipeProvider, scale: scale).0
        return try compositeExport(base: base, caps: recipe.caps, scale: scale)
    }
    private func compositeExport(base: CGImage, caps: [FaderCapSurface], scale: Int) throws -> CGImage {
        let w = base.width, h = base.height
        guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw EngineTableError.resourceBudget }
        c.draw(base, in: CGRect(x: 0, y: 0, width: w, height: h)); c.translateBy(x: 0, y: Double(h)); c.scaleBy(x: Double(scale), y: -Double(scale))
        for cap in caps {
            let image = try EngineRecipeDrawing.raster(.init(size: cap.frame.size, commands: cap.commands, regions: []), provider: recipeProvider, scale: scale).0
            c.saveGState(); c.setAlpha(CGFloat(cap.opacity)); c.translateBy(x: cap.frame.minX, y: cap.frame.maxY); c.scaleBy(x: 1, y: -1)
            c.draw(image, in: CGRect(origin: .zero, size: cap.frame.size)); c.restoreGState()
        }
        return c.makeImage()!
    }
    public var keyboardOrder: [String] { recipe?.regions.filter(\.tabStop).map(\.id) ?? [] }
    public func control(for id: String) -> NSControl? { controls[id] }
    private func synchronizeRegions(_ regions: [FaderHitRegion], oldOrder: [String]) {
        let oldFocus = controls.first { $0.value === window?.firstResponder }?.key
        let oldRegion = oldFocus.flatMap { controls[$0]?.region }, ids = Set(regions.map(\.id))
        for id in Array(controls.keys) where !ids.contains(id) {
            let control = controls.removeValue(forKey: id); control?.retire(); control?.removeFromSuperview()
        }
        for region in regions {
            let control = controls[region.id] ?? FaderRegionControl(owner: self, region: region)
            if controls[region.id] == nil { controls[region.id] = control; addSubview(control) }; control.configure(region)
        }
        let ordered = regions.filter(\.tabStop).compactMap { controls[$0.id] }
        for (i, control) in ordered.enumerated() { control.nextKeyView = ordered[(i + 1) % ordered.count] }
        setAccessibilityChildren(regions.compactMap { controls[$0.id] })
        if let oldRegion, let modelID = oldRegion.modelID,
           let target = regions.first(where: { $0.modelID == modelID && $0.role == oldRegion.role && $0.tabStop }),
           target.id != oldFocus {
            window?.makeFirstResponder(controls[target.id])
        } else if let oldFocus, controls[oldFocus] == nil, !ordered.isEmpty {
            window?.makeFirstResponder(ordered[min(oldOrder.firstIndex(of: oldFocus) ?? 0, ordered.count - 1)])
        }
    }
    private func mutate(_ action: (inout FaderBankController) -> [FaderIntent]) {
        var next = controller; let intents = action(&next)
        do { try publish(next, language: language, compact: compact, now: now, showProjectNames: showProjectNames); intents.forEach { onIntent?($0) }; schedulePress() }
        catch { renderError = String(describing: error) }
    }
    fileprivate func activate(_ action: FaderRegionAction) {
        switch action {
        case .bank(let n): mutate { $0.changeBank(n) }
        case .effort(let id, let key): mutate { $0.tryEffort(modelID: id, key: key, toggle: true) }
        case .lcd(let id): mutate { state in state.beginLCDPress(modelID: id, at: elapsed()); return state.releaseLCD(inside: true, at: elapsed()) }
        case .travel: break
        }
    }
    fileprivate func down(_ region: FaderHitRegion, point: CGPoint) {
        cancelHintRest(.pointerDown)
        pointerMode()
        switch region.action {
        case .lcd(let id): mutate { $0.beginLCDPress(modelID: id, at: elapsed()); return [] }
        case .travel(let id): mutate { $0.beginDrag(modelID: id, position: fraction(region, point), key: nearestKey(region, point)) }
        default: break
        }
    }
    fileprivate func drag(_ region: FaderHitRegion, point: CGPoint) {
        cancelHintRest(.movement)
        if case .travel = region.action { mutate { $0.moveDrag(position: fraction(region, point), key: nearestKey(region, point)) } }
    }
    fileprivate func up(_ region: FaderHitRegion, inside: Bool, point: CGPoint? = nil) {
        switch region.action {
        case .lcd: mutate { $0.releaseLCD(inside: inside, at: elapsed()) }
        case .travel: mutate { $0.finishDrag(); return [] }
        case .some(let action): if inside { activate(action) }
        default: break
        }
        if inside, let point { beginFaderRest(at: point) }
    }
    private func fraction(_ region: FaderHitRegion, _ point: CGPoint) -> Double {
        guard let a = region.top, let b = region.bottom, b > a else { return 0.5 }; return min(1, max(0, (point.y - a) / (b - a)))
    }
    private func nearestKey(_ region: FaderHitRegion, _ point: CGPoint) -> String? {
        let k = fraction(region, point)
        return region.detents.min { abs($0.position - k) < abs($1.position - k) }?.key
    }
    fileprivate func step(_ id: String, up: Bool) { mutate { $0.step(modelID: id, upward: up) } }
    fileprivate func favorite(_ id: String) { mutate { $0.toggleFavorite(id) } }
    fileprivate var favoriteActionTitle: String { language == .chinese ? "切换钉住到第 1 组" : "Toggle pin to bank 1" }
    fileprivate func pointerMode() { keyboard = false; updateFocus(); leaveHelp() }
    public override func mouseDown(with event: NSEvent) { cancelHintRest(.pointerDown); super.mouseDown(with: event) }
    public override func rightMouseDown(with event: NSEvent) { cancelHintRest(.pointerDown); super.rightMouseDown(with: event) }
    public override func otherMouseDown(with event: NSEvent) { cancelHintRest(.pointerDown); super.otherMouseDown(with: event) }
    public func endTrial() { mutate { $0.endTrial() } }
    public func selectModel(_ id: String) { mutate { $0.selectModel(id) } }
    public func setTrial(_ trial: FaderTrial?) throws {
        var next = controller
        guard next.setTrial(trial) else { throw EngineTableError.invalidRecipe }
        try publish(next, language: language, compact: compact, now: now, showProjectNames: showProjectNames)
    }
    public func setSourceHighlight(_ id: String?) throws {
        var next = controller; next.setSourceHighlight(id)
        try publish(next, language: language, compact: compact, now: now, showProjectNames: showProjectNames)
    }
    private func schedulePress() {
        timer?.invalidate(); timer = nil
        guard let due = controller.nextDeadline else { return }
        let t = Timer(timeInterval: max(0, due - elapsed()), repeats: false) { [weak self] _ in MainActor.assumeIsolated { guard let self else { return }; self.timer = nil; self.mutate { $0.advance(at: self.elapsed()) } } }
        RunLoop.main.add(t, forMode: .common); timer = t
    }
    fileprivate func key(_ event: NSEvent) -> Bool {
        cancelHintRest(.keyboard)
        keyboard = true; updateFocus()
        if event.charactersIgnoringModifiers == "[" { mutate { $0.changeBank($0.bank - 1) }; return true }
        if event.charactersIgnoringModifiers == "]" { mutate { $0.changeBank($0.bank + 1) }; return true }
        if event.keyCode == 53 { endTrial(); return true }; return false
    }
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { cancelHintRest(.keyboard) }
        if event.keyCode == 48, let id = event.modifierFlags.contains(.shift) ? keyboardOrder.last : keyboardOrder.first { window?.makeFirstResponder(controls[id]) }
        else if !key(event) { super.keyDown(with: event) }
    }
    fileprivate func focusChanged(_ id: String?) {
        if id == nil { cancelHintRest(.focusLoss) }
        focusedID = id; updateFocus()
        if keyboard, let id { dwell.enter(id, keyboardFocus: true, at: elapsed()); showHelp() } else { leaveHelp() }
    }
    private func updateFocus() {
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        focus.frame = bounds
        guard keyboard, let focusedID, let control = controls[focusedID], let ink = recipe?.focusInk else { focus.path = nil; return }
        focus.strokeColor = ink.cgColor; focus.lineWidth = 1
        focus.path = CGPath(rect: control.frame.insetBy(dx: -2, dy: -2), transform: nil)
    }
    public override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self)
        tracking = t; addTrackingArea(t); super.updateTrackingAreas()
    }
    public override func mouseMoved(with event: NSEvent) {
        cancelHintRest(.movement)
        keyboard = false; updateFocus(); let point = convert(event.locationInWindow, from: nil)
        beginFaderRest(at: point)
        guard let region = recipe?.regions.first(where: { $0.rect.contains(point) }) else {
            if controller.draggingModelID == nil, controller.previewModelID != nil { mutate { $0.preview(modelID: nil, key: nil); return [] } }
            leaveHelp(); return
        }
        if controller.draggingModelID == nil {
            switch region.action {
            case .travel(let id): mutate { $0.preview(modelID: id, key: nearestKey(region, point)); return [] }
            case .effort(let id, let key): mutate { $0.preview(modelID: id, key: key); return [] }
            default: if controller.previewModelID != nil { mutate { $0.preview(modelID: nil, key: nil); return [] } }
            }
        }
        dwell.enter(region.id, keyboardFocus: false, at: elapsed()); dwellTimer?.invalidate()
        if let due = dwell.nextDeadline {
            let t = Timer(timeInterval: max(0, due - elapsed()), repeats: false) { [weak self] _ in MainActor.assumeIsolated { guard let self else { return }; self.dwell.advance(at: self.elapsed()); self.showHelp() } }
            dwellTimer = t; RunLoop.main.add(t, forMode: .common)
        }
    }
    public override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    public override func flagsChanged(with event: NSEvent) { cancelHintRest(.keyboard); super.flagsChanged(with: event) }
    public override func mouseExited(with event: NSEvent) { cancelHintRest(.leave); if controller.draggingModelID == nil { mutate { $0.preview(modelID: nil, key: nil); return [] } }; leaveHelp() }
    public func cancelHintRest(_ reason: InstrumentHintCancellation) {
        restAnchor = nil
        let at = elapsed(); if at.isFinite { onHintInput?(.cancelFaderRest(reason, at: at)) }
    }
    private func beginFaderRest(at point: CGPoint) {
        guard controller.publicationUsable, hintPointerEligible(), controller.draggingModelID == nil, point.x.isFinite, point.y.isFinite,
              let region = recipe?.regions.first(where: { $0.role == .slider && $0.enabled && $0.rect.contains(point) }),
              let id = region.modelID else { return }
        let at = elapsed(); guard at.isFinite else { return }
        let anchor = FaderRestAnchor(modelID: id, regionID: region.id, travel: region.rect); restAnchor = anchor
        onHintInput?(.faderRestCandidate(anchor: anchor, pointer: point, at: at))
    }
    private func showHelp() {
        guard let id = dwell.visibleSourceID, let r = recipe?.regions.first(where: { $0.id == id }) else { return }
        if let onHelpChange { onHelpChange(r.help, r.rect); return }
        guard window?.isVisible == true else { return }
        let controller = NSViewController(), text = NSTextField(wrappingLabelWithString: r.help.accessibleDescription)
        text.font = .systemFont(ofSize: 11); text.preferredMaxLayoutWidth = 260; text.frame = CGRect(x: 10, y: 8, width: 260, height: max(60, text.fittingSize.height))
        let host = NSView(frame: CGRect(x: 0, y: 0, width: 280, height: text.frame.height + 16)); host.addSubview(text); controller.view = host
        let p = popover ?? NSPopover(); p.animates = false; p.behavior = .transient; p.contentViewController = controller; popover = p
        p.show(relativeTo: bounds, of: self, preferredEdge: .maxX)
    }
    public func leaveHelp() { dwellTimer?.invalidate(); dwellTimer = nil; dwell.leave(); popover?.close(); onHelpChange?(nil, nil) }
    private func stopAnimations() { surfaces.values.forEach { $0.removeAllAnimations() } }
    public func suspend() { cancelHintRest(.focusLoss); timer?.invalidate(); timer = nil; controller.cancelGesture(); leaveHelp(); stopAnimations() }
    /// Actual cockpit close clears mirrored interaction without publishing a hidden raster.
    public func closeForCockpit() {
        suspend(); _ = controller.endTrial(); controller.setSourceHighlight(nil)
        presentation = nil; recipe = nil; oldCaps.removeAll(); oldTexts.removeAll()
        for control in controls.values { control.retire(); control.removeFromSuperview() }
        controls.removeAll(); setAccessibilityChildren([]); focusedID = nil; focus.path = nil
        for layer in surfaces.values { layer.removeFromSuperlayer() }; surfaces.removeAll()
    }
    public func dispose() {
        cancelHintRest(.teardown); suspend(); onIntent = nil; onHelpChange = nil; onHintInput = nil
        hintObservers.forEach { NotificationCenter.default.removeObserver($0) }; hintObservers = []
        for control in controls.values { control.retire(); control.removeFromSuperview() }
        controls.removeAll(); setAccessibilityChildren([]); focusedID = nil; focus.path = nil
        for layer in surfaces.values { layer.removeFromSuperlayer() }; surfaces.removeAll()
    }
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); hintObservers.forEach { NotificationCenter.default.removeObserver($0) }; hintObservers = []
        if let window {
            for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification, NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
                hintObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.cancelHintRest(name == NSWindow.didResignKeyNotification ? .focusLoss : .layoutChange) }
                })
            }
            hintObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cancelHintRest(.focusLoss) }
            })
        } else { suspend() }
        refreshSize()
    }
    public override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); refreshSize() }
    public override func setFrameSize(_ newSize: NSSize) { cancelHintRest(.layoutChange); super.setFrameSize(newSize); refreshSize() }
    private func refreshSize() {
        guard presentation != nil else { return }
        do { try publish(controller, language: language, compact: compact, now: now, showProjectNames: showProjectNames, force: true) }
        catch { renderError = String(describing: error) }
    }
}

@MainActor private final class FaderRegionControl: NSControl {
    weak var owner: FaderBankView?
    var region: FaderHitRegion
    private var currentOwner: FaderBankView? {
        guard let owner, owner.control(for: region.id) === self, superview === owner else { return nil }
        return owner
    }
    init(owner: FaderBankView, region: FaderHitRegion) { self.owner = owner; self.region = region; super.init(frame: region.rect); focusRingType = .none; configure(region) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { currentOwner != nil && region.tabStop && region.enabled }
    override var canBecomeKeyView: Bool { acceptsFirstResponder && !isHidden }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { currentOwner != nil && region.enabled }
    override func draw(_ dirtyRect: NSRect) {}
    func configure(_ r: FaderHitRegion) {
        region = r; frame = r.rect; isEnabled = r.enabled; setAccessibilityElement(true); setAccessibilityIdentifier(r.id)
        toolTip = nil
        setAccessibilityRole(r.role == .slider ? .slider : r.role == .button ? .button : .image)
        setAccessibilityLabel(r.label); setAccessibilityHelp(r.help.accessibleDescription); setAccessibilityEnabled(r.enabled)
        if r.role == .slider {
            setAccessibilityMinValue(0); setAccessibilityMaxValue(max(0, r.levelCount - 1)); setAccessibilityValue(r.shownIndex)
            setAccessibilityOrientation(.vertical)
        }
        if case .lcd(let id) = r.action {
            setAccessibilityCustomActions([NSAccessibilityCustomAction(name: owner?.favoriteActionTitle ?? "Favorite", handler: { [weak self] in
                guard let self, let owner = self.currentOwner, self.region.enabled, self.region.action == .lcd(id) else { return false }
                owner.favorite(id); return true
            })])
        } else { setAccessibilityCustomActions(nil) }
    }
    func retire() {
        owner = nil; isEnabled = false; nextKeyView = nil
        setAccessibilityElement(false); setAccessibilityEnabled(false); setAccessibilityCustomActions(nil)
    }
    override func becomeFirstResponder() -> Bool { guard acceptsFirstResponder, let owner = currentOwner else { return false }; owner.focusChanged(region.id); return true }
    override func resignFirstResponder() -> Bool { currentOwner?.focusChanged(nil); return true }
    override func mouseDown(with event: NSEvent) { guard region.enabled, let owner = currentOwner else { return }; owner.pointerMode(); if acceptsFirstResponder { window?.makeFirstResponder(self) }; owner.down(region, point: owner.convert(event.locationInWindow, from: nil)) }
    override func rightMouseDown(with event: NSEvent) { currentOwner?.cancelHintRest(.pointerDown); super.rightMouseDown(with: event) }
    override func otherMouseDown(with event: NSEvent) { currentOwner?.cancelHintRest(.pointerDown); super.otherMouseDown(with: event) }
    override func mouseDragged(with event: NSEvent) { guard region.enabled, let owner = currentOwner else { return }; owner.drag(region, point: owner.convert(event.locationInWindow, from: nil)) }
    override func mouseUp(with event: NSEvent) { guard region.enabled, let owner = currentOwner else { return }; owner.up(region, inside: bounds.contains(convert(event.locationInWindow, from: nil)), point: owner.convert(event.locationInWindow, from: nil)) }
    override func keyDown(with event: NSEvent) {
        guard region.enabled, let owner = currentOwner else { return }
        if event.keyCode == 48 { owner.cancelHintRest(.keyboard); event.modifierFlags.contains(.shift) ? window?.selectPreviousKeyView(self) : window?.selectNextKeyView(self); return }
        if owner.key(event) { return }
        if region.role == .slider, !event.modifierFlags.intersection([.option, .command, .control]).isEmpty { super.keyDown(with: event); return }
        if region.role == .slider, let id = region.modelID, [125, 126].contains(event.keyCode) { owner.step(id, up: event.keyCode == 126) }
        else if event.keyCode == 36 || event.charactersIgnoringModifiers == " " { _ = accessibilityPerformPress() }
        else { super.keyDown(with: event) }
    }
    override func accessibilityPerformPress() -> Bool { guard region.enabled, let owner = currentOwner, let action = region.action, region.role != .slider else { return false }; owner.activate(action); return true }
    override func accessibilityPerformIncrement() -> Bool { guard region.enabled, let owner = currentOwner, region.role == .slider, let id = region.modelID else { return false }; owner.step(id, up: true); return true }
    override func accessibilityPerformDecrement() -> Bool { guard region.enabled, let owner = currentOwner, region.role == .slider, let id = region.modelID else { return false }; owner.step(id, up: false); return true }
}

