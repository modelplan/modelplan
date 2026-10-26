// SPDX-License-Identifier: MIT
import AppKit

@MainActor public final class MainScreenView: NSView {
    public let recipeProvider: any MainScreenRecipeProvider
    public private(set) var controller = MainScreenController()
    public private(set) var presentation: MainScreenPresentation?
    public private(set) var recipe: MainScreenRecipe?
    public private(set) var renderError: String?
    public private(set) var displayRequests = 0, surfaceRenders = 0
    public var onIntent: ((MainScreenIntent) -> Void)?
    public var onIntents: (([MainScreenIntent]) -> Void)?
    public var onHelpChange: ((HelpExplanation?, CGRect?) -> Void)?
    public var onHintInput: ((InstrumentHintInput) -> Void)?
    private var language: InstrumentLanguage = .chinese, compact = false
    private var bitmap: CGImage?, bitmapScale: Int?
    private var controls: [String: MainScreenRegionControl] = [:]
    private var listScroll:NSScrollView?,listObserver:MainScreenListObservation?
    private lazy var listDocument=MainScreenListDocument(owner:self)
    public var listScrollView:NSScrollView? {listScroll}
    private var focusedID: String?, keyboard = true
    private let focus = CAShapeLayer()
    private var dwell = HelpDwell(), timer: Timer?, tracking: NSTrackingArea?, popover: NSPopover?
    private let elapsed: () -> Double
    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    private var scale: Int { (window?.backingScaleFactor ?? 2) >= 2 ? 2 : 1 }
    public override var intrinsicContentSize: NSSize { presentation.map { recipeProvider.minimumSize(for: $0) } ?? CGSize(width: 600, height: 340) }
    public init(frame: CGRect = CGRect(x: 0, y: 0, width: 600, height: 340), recipeProvider: (any MainScreenRecipeProvider)? = nil,
                elapsed: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.recipeProvider = recipeProvider ?? NeutralMainScreenRecipe(); self.elapsed = elapsed
        super.init(frame: frame); appearance = NSAppearance(named: .darkAqua); wantsLayer = true
        focus.fillColor = nil; focus.zPosition = 10; layer?.addSublayer(focus)
        setAccessibilityElement(false); setAccessibilityIdentifier("main.screen")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    public func update(inputs: [FaderChannelInput], selection: InjectedModelSelection?, publication: SelectionPublication?,
            publicationUsable: Bool, language: InstrumentLanguage, compact: Bool, scope: InstrumentScope? = nil,
            pages: [MainScreenPageContent] = [], sourcedBodies: [MainScreenSourcedBody] = []) throws {
        guard pages.allSatisfy({($0.subscription.map{$0.language == language} ?? true) && ($0.history.map{$0.language == language} ?? true)}) else{throw MainScreenError.invalidContent}
        var next = controller
        let effects = try next.update(inputs: inputs, selection: selection, publication: publication, publicationUsable: publicationUsable,
            scope: scope, pages: pages, sourcedBodies: sourcedBodies)
        try publish(next, language: language, compact: compact); emit(effects)
    }
    private func publish(_ state: MainScreenController, language: InstrumentLanguage, compact: Bool, force: Bool = false) throws {
        let p = MainScreenPresentation(controller: state, language: language, compact: compact)
        if !force, p == presentation, recipe?.size == bounds.size, bitmapScale == scale {
            controller = state; return
        }
        var next: MainScreenRecipe!, failure: Error?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            do { next = try recipeProvider.recipe(for: p, size: bounds.size); try next.validate() }
            catch { failure = error }
        }
        if let failure { throw failure }
        if let list=next.list,list != recipe?.list || force {
            let context=CGContext(data:nil,width:1,height:1,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.clip(to:.zero)
            // Preflight every row, including offscreen fonts/images, before committing state.
            try EngineRecipeDrawing.draw(.init(size:next.size,commands:next.commands+list.rows.flatMap(\.commands),regions:[]),in:context,provider:recipeProvider)
        }
        let listChanged=force || next.list != recipe?.list
        let changed = force || next.commands != recipe?.commands || next.size != recipe?.size || bitmapScale != scale
        let pixels: CGImage
        if !changed, let bitmap { pixels = bitmap }
        else {
            pixels = try EngineRecipeDrawing.raster(.init(size: next.size, commands: next.commands, regions: []), provider: recipeProvider, scale: scale).0
        }
        let oldOrder = keyboardOrder
        controller = state; presentation = p; recipe = next; self.language = language; self.compact = compact
        bitmap = pixels; bitmapScale = scale; renderError = nil
        configureList(next.list)
        synchronizeRegions(next.regions, oldOrder: oldOrder); updateFocus()
        if changed { surfaceRenders += 1 }; if changed || listChanged {displayRequests += 1; needsDisplay = true}
        if let id = dwell.sourceID, !allRegions.contains(where: { $0.id == id }) { leaveHelp() }
        else if dwell.visibleSourceID != nil { showHelp() }
        invalidateIntrinsicContentSize()
    }
    private func emit(_ effects: [MainScreenIntent]) {
        guard !effects.isEmpty else { return }
        if let onIntents { onIntents(effects) }
        else { effects.forEach { onIntent?($0) } }
    }
    @discardableResult private func mutate(_ apply: (inout MainScreenController) -> [MainScreenIntent]) -> Bool {
        var next = controller; let effects = apply(&next)
        do { try publish(next, language: language, compact: compact); emit(effects); return true }
        catch { renderError = String(describing: error); return false }
    }
    public func openComparison(modelID: String, configuration: EffortConfiguration? = nil, from source: MainScreenSource, toggle: Bool = true) {
        mutate { $0.openComparison(modelID: modelID, configuration: configuration, from: source, toggle: toggle) }
    }
    public func open(_ content: MainScreenContent, from source: MainScreenSource) { mutate { $0.open(content, from: source) } }
    public func receiveFaderIntent(_ intent: FaderIntent) { mutate { $0.receiveFaderIntent(intent) } }
    public func selectPage(_ location: MainScreenLocation) { mutate { $0.selectPage(location) } }
    public func selectScope(_ scope: InstrumentScope) { mutate { $0.selectScope(scope) } }
    public func selectModel(_ id: String) { mutate { $0.selectModel(id) } }
    public func back() { mutate { $0.back() } }
    @discardableResult public func handleEscape() -> Bool {
        guard controller.navigation.sourced != nil else { return false }
        mutate { $0.back() }
        return true
    }
    /// Called by the cockpit owner for an actual close, not merely app blur/occlusion.
    public func closeForCockpit() {
        // Actual teardown cannot depend on rendering the page underneath.
        let effects = controller.back()
        retireControls(); presentation = nil; recipe = nil; bitmap = nil; bitmapScale = nil
        emit(effects); suspend(); needsDisplay = true
    }
    @discardableResult fileprivate func activate(_ action: MainScreenAction) -> Bool {
        switch action {
        case .subscriptionScope(let id):
            guard let display=presentation?.subscription,display.snapshot.scope == .all,
                display.snapshot.accounts.contains(where:{$0.id == id}) else{return false}
            emit([.subscriptionScopeSelected(id)]);return true
        case .overviewAlerts:
            guard presentation?.overview != nil else { return false }
            return mutate { $0.open(.alerts, from: .noticeOverflow) }
        case .overviewInformation(let id):
            guard presentation?.overview?.snapshot.information?.id == id else { return false }
            emit([.overviewInformationSelected(id)]); return true
        case .page(let page): return mutate { $0.pressPageKey(page) }
        case .back: return mutate { $0.back() }
        case .option(let page, let id, let value):
            guard controller.navigation.location.page == page, controller.trial == nil else { return false }
            return mutate { $0.chooseOption(id: id, value: value) }
        case .effort(let id, let key):
            guard controller.trial?.modelID == id else { return false }
            return mutate { $0.tryEffort(key) }
        case .fast(let id):
            guard controller.trial?.modelID == id else { return false }
            return mutate { $0.toggleFast() }
        }
    }
    @discardableResult fileprivate func activate(at point: CGPoint) -> Bool {
        guard let region = region(at:point),region.role != .readout,
              region.enabled, let action = region.action else { return false }
        return activate(action)
    }
    public override func draw(_ dirtyRect: NSRect) {
        guard let bitmap, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState(); context.translateBy(x: 0, y: bounds.height); context.scaleBy(x: 1, y: -1)
        context.draw(bitmap, in: bounds); context.restoreGState()
    }
    public func rasterImage(scale: Int) throws -> CGImage {
        guard let recipe else { throw EngineTableError.invalidRecipe }
        if recipe.list == nil,scale == bitmapScale, let bitmap { return bitmap }
        guard let list=recipe.list else {return try EngineRecipeDrawing.raster(.init(size: recipe.size, commands: recipe.commands, regions: []), provider: recipeProvider, scale: scale).0}
        guard (1...2).contains(scale),let context=CGContext(data:nil,width:Int(ceil(recipe.size.width))*scale,height:Int(ceil(recipe.size.height))*scale,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{throw EngineTableError.invalidScale}
        context.translateBy(x:0,y:Double(context.height));context.scaleBy(x:Double(scale),y:-Double(scale))
        try EngineRecipeDrawing.draw(.init(size:recipe.size,commands:recipe.commands,regions:[]),in:context,provider:recipeProvider)
        context.clip(to:list.viewport);context.translateBy(x:list.viewport.minX,y:list.viewport.minY)
        let offset=listScroll?.contentView.bounds.minY ?? 0
        try listDocument.drawRows(list,in:context,offset:offset,visible:CGRect(x:0,y:offset,width:list.viewport.width,height:list.viewport.height),provider:recipeProvider)
        guard let image=context.makeImage() else{throw EngineTableError.invalidRecipe};return image
    }
    private var allRegions:[MainScreenHitRegion] {
        guard let recipe else{return []}
        guard let list=recipe.list else{return recipe.regions}
        return recipe.regions.filter{!$0.id.hasPrefix("screen.footer.")}+list.positionedRegions+recipe.regions.filter{$0.id.hasPrefix("screen.footer.")}
    }
    public var keyboardOrder: [String] {allRegions.filter{$0.tabStop && $0.enabled}.map(\.id)}
    public func control(for id: String) -> NSControl? { controls[id] }
    private func synchronizeRegions(_ regions: [MainScreenHitRegion], oldOrder: [String]) {
        let oldFocus = controls.first { $0.value === window?.firstResponder }?.key ?? focusedID
        let oldAction = oldFocus.flatMap { controls[$0]?.region.action }
        let oldFrame = oldFocus.flatMap { controls[$0]?.frame }
        let nativeRegions = allRegions.filter { $0.role != .choice }, ids = Set(nativeRegions.map(\.id))
        for id in Array(controls.keys) where !ids.contains(id) {
            let control = controls.removeValue(forKey: id); control?.retire(); control?.removeFromSuperview()
        }
        for r in nativeRegions {
            if let previous = controls[r.id], previous.region.action != r.action {
                controls.removeValue(forKey: r.id); previous.retire(); previous.removeFromSuperview()
            }
            let control = controls[r.id] ?? MainScreenRegionControl(owner: self, region: r)
            let inList=recipe?.list?.rows.contains(where:{$0.region.id == r.id}) == true
            let host:NSView=inList ? listDocument:self
            if controls[r.id] == nil {controls[r.id]=control}
            if control.superview !== host {control.removeFromSuperview();host.addSubview(control)}
            control.configure(r)
        }
        let ordered = keyboardOrder.compactMap { controls[$0] }
        for (i, c) in ordered.enumerated() { c.nextKeyView = ordered[(i + 1) % ordered.count] }
        listDocument.setAccessibilityChildren(recipe?.list?.positionedRegions.compactMap{controls[$0.id]} ?? [])
        if let listScroll {
            let native=regions.filter{$0.role != .choice}
            setAccessibilityChildren(native.filter{!$0.id.hasPrefix("screen.footer.")}.compactMap{controls[$0.id]}+[listScroll]+native.filter{$0.id.hasPrefix("screen.footer.")}.compactMap{controls[$0.id]})
        } else {setAccessibilityChildren(nativeRegions.compactMap { controls[$0.id] })}
        if let oldFocus, controls[oldFocus] == nil || oldAction != controls[oldFocus]?.region.action, !ordered.isEmpty {
            let back = nativeRegions.first { $0.action == .back }.flatMap { controls[$0.id] }
            let active = presentation?.pageKeys.first(where: \.lit)?.page
            let page = active.flatMap { selected in nativeRegions.first { $0.action == .page(selected) } }.flatMap { controls[$0.id] }
            let target = back ?? page ?? ordered[min(oldOrder.firstIndex(of: oldFocus) ?? 0, ordered.count - 1)]
            window?.makeFirstResponder(target)
        } else if keyboard,let id=oldFocus,let previous=oldFrame,let control=controls[id],window?.firstResponder === control,control.frame != previous {
            reveal(id);focusChanged(id)
        }
    }
    fileprivate func owns(_ view:NSView)->Bool {
        view.superview === self || (view.superview === listDocument && recipe?.list != nil)
    }
    fileprivate func reveal(_ id:String) {
        guard let control=controls[id],control.superview === listDocument else{return}
        listDocument.scrollToVisible(control.frame)
    }
    private func visibleRect(for control:NSView)->CGRect {
        let rect=convert(control.bounds,from:control)
        if control.superview === listDocument {return recipe?.list.map{rect.intersection($0.viewport)} ?? .zero}
        return rect
    }
    private func region(at point:CGPoint)->MainScreenHitRegion? {
        if let list=recipe?.list,list.viewport.contains(point) {
            let p=listDocument.convert(point,from:self)
            return list.positionedRegions.first{$0.rect.contains(p)}
        }
        return recipe?.regions.reversed().first{$0.rect.contains(point)}
    }
    private func configureList(_ list:MainScreenListRecipe?) {
        guard let list else {
            listObserver=nil
            listScroll?.removeFromSuperview();listScroll?.documentView=nil;listScroll=nil;listDocument.list=nil;listDocument.setAccessibilityChildren([]);return
        }
        let changed=listDocument.list != list,reset=listDocument.list?.identity != list.identity
        let scroll=listScroll ?? NSScrollView(frame:list.viewport)
        if listScroll == nil {
            scroll.drawsBackground=false;scroll.contentView.drawsBackground=false;scroll.borderType = .noBorder
            scroll.hasVerticalScroller=true;scroll.hasHorizontalScroller=false;scroll.autohidesScrollers=true;scroll.scrollerStyle = .overlay
            scroll.documentView=listDocument;scroll.contentView.postsBoundsChangedNotifications=true
            listScroll=scroll;addSubview(scroll)
            listObserver=MainScreenListObservation(NotificationCenter.default.addObserver(forName:NSView.boundsDidChangeNotification,object:scroll.contentView,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated {guard let self else{return};self.cancelHintRest(.movement);self.leaveHelp();self.updateFocus()}
            })
        }
        if scroll.frame != list.viewport {scroll.frame=list.viewport}
        let size=CGSize(width:list.viewport.width,height:max(list.contentHeight,list.viewport.height))
        if listDocument.frame.size != size {listDocument.setFrameSize(size)}
        listDocument.list=list
        let y=reset ? 0:min(scroll.contentView.bounds.minY,max(0,size.height-list.viewport.height))
        let origin=CGPoint(x:0,y:y)
        if scroll.contentView.bounds.origin != origin {scroll.contentView.scroll(to:origin);scroll.reflectScrolledClipView(scroll.contentView)}
        if changed {listDocument.needsDisplay=true}
    }
    func listDrawingFailed(_ error:Error) {renderError=String(describing:error)}
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { cancelHintRest(.keyboard) }
        if event.keyCode == 48, let id = event.modifierFlags.contains(.shift) ? keyboardOrder.last : keyboardOrder.first { window?.makeFirstResponder(controls[id]) }
        else if !key(event) { super.keyDown(with: event) }
    }
    fileprivate func key(_ event: NSEvent) -> Bool {
        cancelHintRest(.keyboard)
        keyboard = true; updateFocus()
        guard event.keyCode == 53 else { return false }
        return handleEscape()
    }
    fileprivate func navigateGroup(from id: String, event: NSEvent) -> Bool {
        guard let region = controls[id]?.region, let group = region.focusGroup,
              [123,124,125,126,115,119].contains(event.keyCode) else { return false }
        let items = allRegions.filter { $0.enabled && $0.tabStop && $0.focusGroup == group }
        guard let index = items.firstIndex(where:{$0.id == id}), !items.isEmpty else { return false }
        let code=event.keyCode
        if region.gridPosition == nil && group != "subscription.rows" && (code==125 || code==126) { return false }
        cancelHintRest(.keyboard); keyboard = true
        let next: MainScreenHitRegion?
        if code==115 { next=items.first }
        else if code==119 { next=items.last }
        else if let position=region.gridPosition {
            let horizontal=code==123 || code==124,forward=code==124 || code==125
            let origin=horizontal ? position.column:position.row
            next=items.filter { item in
                guard let p=item.gridPosition else{return false}
                let value=horizontal ? p.column:p.row
                return (horizontal ? p.row==position.row:p.column==position.column) && (forward ? value>origin:value<origin)
            }.min { a,b in
                let ap=a.gridPosition!,bp=b.gridPosition!
                return abs((horizontal ? ap.column:ap.row)-origin)<abs((horizontal ? bp.column:bp.row)-origin)
            }
        } else { next=items[min(items.count-1,max(0,index+((code==124 || code==125) ? 1:-1)))] }
        if let next,let control=controls[next.id] { window?.makeFirstResponder(control) }
        return true
    }
    fileprivate func pointerMode() { cancelHintRest(.pointerDown); keyboard = false; updateFocus(); leaveHelp() }
    public override func mouseDown(with event: NSEvent) { pointerMode(); super.mouseDown(with: event) }
    public override func rightMouseDown(with event: NSEvent) { pointerMode(); super.rightMouseDown(with: event) }
    public override func otherMouseDown(with event: NSEvent) { pointerMode(); super.otherMouseDown(with: event) }
    fileprivate func focusChanged(_ id: String?) {
        if id == nil { cancelHintRest(.focusLoss) }
        focusedID = id; updateFocus()
        if keyboard, let id { dwell.enter(id, keyboardFocus: true, at: elapsed()); showHelp() } else { leaveHelp() }
    }
    private func updateFocus() {
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        focus.frame = bounds
        guard keyboard, let id = focusedID, let control = controls[id], let ink = recipe?.focusInk else { focus.path = nil; return }
        let rect=visibleRect(for:control);guard !rect.isEmpty,!rect.isNull else{focus.path=nil;return}
        focus.strokeColor = ink.cgColor; focus.lineWidth = 1; focus.path = CGPath(rect: rect.insetBy(dx: -1, dy: -1), transform: nil)
    }
    public override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let tracking = NSTrackingArea(rect: bounds, options: [.inVisibleRect, .mouseMoved, .mouseEnteredAndExited, .activeInActiveApp], owner: self)
        self.tracking = tracking; addTrackingArea(tracking); super.updateTrackingAreas()
    }
    public override func mouseMoved(with event: NSEvent) {
        cancelHintRest(.movement)
        keyboard = false; updateFocus()
        let point = convert(event.locationInWindow, from: nil)
        guard let region = region(at:point) else { leaveHelp(); return }
        dwell.enter(region.id, keyboardFocus: false, at: elapsed()); timer?.invalidate(); timer = nil
        if let due = dwell.nextDeadline {
            let timer = Timer(timeInterval: max(0, due - elapsed()), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }; self.dwell.advance(at: self.elapsed()); self.showHelp() }
            }
            self.timer = timer; RunLoop.main.add(timer, forMode: .common)
        }
    }
    public override func mouseExited(with event: NSEvent) { leaveHelp() }
    private func showHelp() {
        guard let id = dwell.visibleSourceID, let r = allRegions.first(where: { $0.id == id }) else { return }
        let rect=controls[id].map{visibleRect(for:$0)} ?? r.rect
        guard !rect.isEmpty else{return}
        if let onHelpChange { onHelpChange(r.help, rect); return }
        guard window?.isVisible == true else { return }
        let controller = NSViewController(), text = NSTextField(wrappingLabelWithString: r.help.accessibleDescription)
        text.font = .systemFont(ofSize: 11); text.preferredMaxLayoutWidth = 260
        text.frame = CGRect(x: 10, y: 8, width: 260, height: max(60, text.fittingSize.height))
        let host = NSView(frame: CGRect(x: 0, y: 0, width: 280, height: text.frame.height + 16)); host.addSubview(text); controller.view = host
        let popover = popover ?? NSPopover(); popover.animates = false; popover.behavior = .transient; popover.contentViewController = controller; self.popover = popover
        popover.show(relativeTo: rect, of: self, preferredEdge: .maxX)
    }
    public func leaveHelp() { timer?.invalidate(); timer = nil; dwell.leave(); popover?.close(); onHelpChange?(nil, nil) }
    public func cancelHintRest(_ reason: InstrumentHintCancellation) {
        let at = elapsed(); if at.isFinite { onHintInput?(.cancelFaderRest(reason, at: at)) }
    }
    public override func flagsChanged(with event: NSEvent) { cancelHintRest(.keyboard); super.flagsChanged(with: event) }
    public func suspend() { cancelHintRest(.focusLoss); leaveHelp() }
    private func retireControls() {
        for c in controls.values { c.retire(); c.removeFromSuperview() }
        controls.removeAll(); configureList(nil); setAccessibilityChildren([]); focusedID = nil; focus.path = nil
    }
    public func dispose() {
        closeForCockpit(); onIntent = nil; onIntents = nil; onHelpChange = nil; onHintInput = nil
    }
    public override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { suspend() }; refresh() }
    public override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); refresh() }
    public override func setFrameSize(_ newSize: NSSize) { super.setFrameSize(newSize); refresh() }
    private func refresh() {
        guard presentation != nil else { return }
        do { try publish(controller, language: language, compact: compact, force: true) }
        catch { renderError = String(describing: error) }
    }
}

@MainActor private final class MainScreenRegionControl: NSControl {
    weak var owner: MainScreenView?
    var region: MainScreenHitRegion
    private var pointerAction: MainScreenAction?
    private var currentOwner: MainScreenView? { guard let owner, owner.control(for: region.id) === self, owner.owns(self) else { return nil }; return owner }
    init(owner: MainScreenView, region: MainScreenHitRegion) { self.owner = owner; self.region = region; super.init(frame: region.rect); focusRingType = .none; configure(region) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { currentOwner != nil && region.tabStop && region.enabled }
    override var canBecomeKeyView: Bool { acceptsFirstResponder && !isHidden }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { currentOwner != nil && region.enabled }
    override func draw(_ dirtyRect: NSRect) {}
    func configure(_ r: MainScreenHitRegion) {
        region = r; frame = r.rect; isEnabled = r.enabled
        setAccessibilityElement(true); setAccessibilityIdentifier(r.id); setAccessibilityRole(r.role == .button ? .button : .image)
        setAccessibilityLabel(r.label); setAccessibilityHelp(r.help.accessibleDescription); setAccessibilityEnabled(r.enabled); setAccessibilityValue(r.value)
        toolTip = nil
    }
    func retire() { owner = nil; pointerAction = nil; isEnabled = false; nextKeyView = nil; setAccessibilityEnabled(false); setAccessibilityElement(false) }
    override func becomeFirstResponder() -> Bool { guard acceptsFirstResponder, let owner = currentOwner else { return false }; owner.reveal(region.id); owner.focusChanged(region.id); return true }
    override func resignFirstResponder() -> Bool { currentOwner?.focusChanged(nil); return true }
    override func mouseDown(with event: NSEvent) { guard region.enabled, let owner = currentOwner else { return }; pointerAction = region.action; owner.pointerMode(); if acceptsFirstResponder { window?.makeFirstResponder(self) } }
    override func rightMouseDown(with event: NSEvent) { currentOwner?.pointerMode(); super.rightMouseDown(with: event) }
    override func otherMouseDown(with event: NSEvent) { currentOwner?.pointerMode(); super.otherMouseDown(with: event) }
    override func mouseUp(with event: NSEvent) { let action = pointerAction; pointerAction = nil; guard action != nil, action == region.action, let owner = currentOwner, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }; _ = owner.activate(at: owner.convert(event.locationInWindow, from: nil)) }
    override func keyDown(with event: NSEvent) {
        guard region.enabled, let owner = currentOwner else { return }
        if event.keyCode == 48 { owner.cancelHintRest(.keyboard); event.modifierFlags.contains(.shift) ? window?.selectPreviousKeyView(self) : window?.selectNextKeyView(self); return }
        if owner.navigateGroup(from: region.id, event: event) || owner.key(event) { return }
        if event.keyCode == 36 || event.charactersIgnoringModifiers == " " { _ = accessibilityPerformPress() }
        else { super.keyDown(with: event) }
    }
    override func accessibilityPerformPress() -> Bool { guard region.enabled, let owner = currentOwner, let action = region.action else { return false }; return owner.activate(action) }
}

private final class MainScreenListObservation {
    let token:NSObjectProtocol
    init(_ token:NSObjectProtocol) {self.token=token}
    deinit {NotificationCenter.default.removeObserver(token)}
}
