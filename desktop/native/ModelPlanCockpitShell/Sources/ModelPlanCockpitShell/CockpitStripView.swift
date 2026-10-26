// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import ModelPlanPrimitives

@MainActor public final class CockpitStripView: NSView, CockpitOverflowHitTesting, CockpitPresentationConsumer {
    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    public var onAction: ((CockpitControlAction) -> Void)?
    public var onHintInput: ((CockpitHintInput) -> Void)?
    public var onTitleDrag: ((CockpitTitleDragInput) -> Void)?
    public var onOptionHelp: ((Bool) -> Void)?
    public var onRenderingFailure: ((Error) -> Void)?
    public private(set) var stripState: CockpitStripState?
    public private(set) var stripLayout: CockpitStripLayout?
    private let decoration = CALayer()
    private let skin: any CockpitStripSkin
    private let now: () -> ContinuousClock.Instant
    private let elapsed: () -> Double
    private var caution: CautionLampModel
    private var controls: [CockpitControlID: CockpitPaintButton] = [:]
    private var timer: Timer?, workspaceToken: NSObjectProtocol?, focusToken: NSObjectProtocol?, occlusionToken: NSObjectProtocol?
    private var stopped = false
    private var allowed = false, titleDragging = false
    private var lastMode: CautionLampModel.Mode?, lastSeverity: CautionLampModel.Severity?
    public init(skin: any CockpitStripSkin, now: @escaping () -> ContinuousClock.Instant = { .now }, elapsed: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.skin = skin; self.now = now; self.elapsed = elapsed; caution = CautionLampModel(now:now())
        super.init(frame:.zero); wantsLayer = true; layer?.addSublayer(decoration)
        setAccessibilityElement(false)
        for id in CockpitControlID.allCases {
            let button: CockpitPaintButton = id == .shutter ? CockpitShutterButton(id:id):CockpitPaintButton(id:id)
            button.owner = self; controls[id] = button; addSubview(button)
        }
        workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main) { [weak self] _ in MainActor.assumeIsolated { self?.validateCaution() } }
    }
    public required init?(coder: NSCoder) { return nil }
    public override var intrinsicContentSize: NSSize { stripLayout?.size ?? .zero }
    public var interactionBounds: CGRect { (stripLayout?.controls.values ?? Dictionary<CockpitControlID,CGRect>().values).reduce(bounds) { $0.union($1) } }
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHiddenOrHasHiddenAncestor, alphaValue>0 else { return nil }
        let local = convert(point,from:superview)
        for button in controls.values where button.frame.contains(local) { return button.hitTest(local) }
        return bounds.contains(local) ? self:nil
    }
    public func control(_ id: CockpitControlID) -> NSControl? { controls[id] }
    public func configure(_ state: CockpitStripState) throws {
        guard (1...2).contains(state.appearance.scale) else { throw CockpitSurfaceError.invalidGeometry }
        let layout = try skin.layout(for:state)
        let root = CGRect(origin:.zero,size:layout.size)
        guard root.width.isFinite, root.height.isFinite, root.width>0, root.height>0, root.width<=2048,root.height<=512,
              layout.shutterTravel.isFinite,layout.shutterTravel>0,
              Set(layout.controls.keys)==Set(CockpitControlID.allCases) else { throw CockpitSurfaceError.invalidGeometry }
        for rect in layout.controls.values {
            guard !rect.isNull, !rect.isInfinite, rect.width>0,rect.height>0,
                  [rect.minX,rect.minY,rect.width,rect.height].allSatisfy(\.isFinite) else { throw CockpitSurfaceError.invalidGeometry }
        }
        if let previous = stripState, previous.windowClosed != state.windowClosed || previous.windowEnabled != state.windowEnabled {
            (controls[.shutter] as? CockpitShutterButton)?.cancelGesture()
        }
        stopped = false; stripState = state; stripLayout = layout; frame.size = layout.size
        let chinese = state.appearance.locale.hasPrefix("zh")
        for (id,button) in controls {
            button.frame = layout.controls[id]!
            button.isEnabled = id != .shutter || state.windowEnabled
            button.setAccessibilityLabel(CockpitControlWords.accessibility(id,chinese:chinese,detached:state.detached))
            button.toolTip = nil // H11: strip controls have AX/Option help, no native title tooltips.
            if id == .attachment { button.setAccessibilityValue(state.detached) }
            if id == .shutter { button.setAccessibilityValue(state.windowClosed ? 1:0); button.setAccessibilityMinValue(0); button.setAccessibilityMaxValue(1) }
        }
        if let art = try skin.decoration(for:state) {
            try controls[.settings]!.install(art,on:decoration,scale:state.appearance.scale)
        } else { decoration.contents = nil }
        validateCaution(); needsDisplay = true; invalidateIntrinsicContentSize()
    }
    public func updateCautions(_ conditions: [CautionLampModel.Condition]) {
        if let state = stripState { caution.setReduceMotion(effectiveReduced(state),now:now()) }
        caution.update(conditions,now:now()); validateCaution()
    }
    public var cautionPresentation: CautionLampModel.Presentation { caution.presentation(now:now()) }
    public var cautionAnimationDuration: CFTimeInterval? { controls[.alert]?.light.animation(forKey:"cockpit-alert")?.duration }
    public func validateCaution() {
        timer?.invalidate(); timer = nil
        if let state = stripState { caution.setReduceMotion(effectiveReduced(state),now:now()) }
        let presentation = caution.presentation(now:now())
        guard !stopped else { return }
        for button in controls.values { button.render() }
        guard let button = controls[.alert] else { return }
        let chinese = stripState?.appearance.locale.hasPrefix("zh") == true
        let mode: String
        switch presentation.mode {
        case .off: mode = chinese ? "无警报":"No active caution"
        case .blinking: mode = chinese ? "未确认，闪烁":"Unacknowledged, blinking"
        case .steadyUnacknowledged: mode = chinese ? "未确认，常亮":"Unacknowledged, steady"
        case .acknowledged: mode = chinese ? "已确认":"Acknowledged"
        }
        let severity = presentation.severity.map { $0 == .red ? (chinese ? "严重":"Critical"):(chinese ? "注意":"Caution") }
        button.setAccessibilityValueDescription(severity.map { $0+"; "+mode } ?? mode)
        if lastMode != presentation.mode || lastSeverity != presentation.severity {
            lastMode = presentation.mode; lastSeverity = presentation.severity
            NSAccessibility.post(element:button,notification:.valueChanged)
        }
        button.light.removeAnimation(forKey:"cockpit-alert"); button.light.opacity = 1
        guard allowed, !isHiddenOrHasHiddenAncestor, presentation.mode == .blinking, let deadline = presentation.deadline else { return }
        let instant = now(), remaining = seconds(instant.duration(to:deadline))
        let phase = presentation.blinkStartedAt.map { seconds($0.duration(to:instant)) } ?? 0
        BoundedOpacity.apply(to:button.light,remaining:remaining,phase:phase,key:"cockpit-alert")
        let timer = Timer(timeInterval:max(0,remaining),repeats:false) { [weak self] _ in MainActor.assumeIsolated { self?.validateCaution() } }
        RunLoop.main.add(timer,forMode:.common); self.timer = timer
    }
    public func setPresentationAllowed(_ allowed: Bool) {
        let changed = self.allowed != allowed; self.allowed = allowed
        if !allowed && changed { cancelInteractions(.focusLoss) }
        validateCaution()
    }
    public func helpTargets() -> [CockpitHelpTarget] {
        guard let state = stripState else { return [] }
        let chinese = state.appearance.locale.hasPrefix("zh")
        return CockpitControlID.allCases.compactMap { id in stripLayout?.controls[id].map {
            CockpitHelpTarget(id:id.rawValue,anchor:$0,label:CockpitControlWords.label(id,chinese:chinese,detached:state.detached),
                accessibilityLabel:CockpitControlWords.accessibility(id,chinese:chinese,detached:state.detached))
        } }
    }
    public func cancelInteractions(_ reason: CockpitInputCancellation) {
        (controls[.shutter] as? CockpitShutterButton)?.cancelGesture()
        if titleDragging { titleDragging = false; onTitleDrag?(.cancelled) }
        onHintInput?(.cancelled(reason,at:elapsed())); onOptionHelp?(false)
    }
    public func stop() {
        guard !stopped else { return }
        stopped = true; allowed = false; timer?.invalidate(); timer = nil; cancelInteractions(.teardown)
        for button in controls.values { button.stop() }; decoration.contents = nil
        skin.discardCachedArtwork(); stripState = nil; stripLayout = nil
    }
    public override func draw(_ dirtyRect: NSRect) {
        guard let state = stripState, let context = NSGraphicsContext.current?.cgContext else { return }
        skin.drawStrip(in:context,bounds:bounds,state:state)
    }
    public override func viewDidHide() { super.viewDidHide(); setPresentationAllowed(false) }
    public override func viewDidUnhide() { super.viewDidUnhide();setPresentationAllowed(window.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false) }
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let focusToken { NotificationCenter.default.removeObserver(focusToken) }; focusToken = nil
        if let occlusionToken { NotificationCenter.default.removeObserver(occlusionToken) }; occlusionToken = nil
        if let window {
            occlusionToken = NotificationCenter.default.addObserver(forName:NSWindow.didChangeOcclusionStateNotification,object:window,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }; self.setPresentationAllowed(self.window.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false) }
            }
            focusToken = NotificationCenter.default.addObserver(forName:NSWindow.didResignKeyNotification,object:window,queue:.main) { [weak self] _ in MainActor.assumeIsolated { self?.cancelInteractions(.focusLoss) } }
        }
        setPresentationAllowed(window.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false)
    }
    public override func flagsChanged(with event: NSEvent) { guard stripState != nil else { return }; onOptionHelp?(event.modifierFlags.contains(.option)) }
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancelInteractions(.keyboard) } else { super.keyDown(with:event) }
    }
    public override func mouseDown(with event: NSEvent) {
        guard event.buttonNumber == 0, stripState != nil else { return }
        cancelInteractions(.pointerDown); titleDragging = true; window?.makeFirstResponder(self)
        onTitleDrag?(.began(point:screenPoint(event),backingScale:window?.backingScaleFactor ?? 1))
    }
    public override func mouseDragged(with event: NSEvent) {
        guard titleDragging else { return }
        onTitleDrag?(.moved(point:screenPoint(event),backingScale:window?.backingScaleFactor ?? 1))
    }
    public override func mouseUp(with event: NSEvent) {
        guard titleDragging else { return }; titleDragging = false
        onTitleDrag?(.ended(point:screenPoint(event),backingScale:window?.backingScaleFactor ?? 1))
    }
    private func screenPoint(_ event: NSEvent) -> CGPoint { window?.convertPoint(toScreen:event.locationInWindow) ?? event.locationInWindow }
    @discardableResult fileprivate func activate(_ id: CockpitControlID) -> Bool {
        guard !stopped, allowed, stripState != nil else { return false }
        validateCaution(); onHintInput?(.cancelled(.pointerDown,at:elapsed()))
        switch id {
        case .alert: guard caution.press(now:now()) != nil else { return false }; validateCaution(); onAction?(.openAlerts)
        case .settings: onAction?(.openSettings)
        case .attachment: onAction?(.toggleAttachment)
        case .close: cancelInteractions(.removal); onAction?(.close)
        case .shutter: return requestShutter(!(stripState?.windowClosed ?? false))
        }
        return true
    }
    @discardableResult fileprivate func requestShutter(_ closed: Bool) -> Bool {
        guard !stopped, allowed, let state = stripState, state.windowEnabled, state.windowClosed != closed else { return false }
        onAction?(.setWindowClosed(closed)); return true
    }
    fileprivate func hint(_ id: CockpitControlID, entered: Bool, pointer: CGPoint) {
        guard !stopped else { return }
        if entered, let anchor = stripLayout?.controls[id] { onHintInput?(.entered(control:id,anchor:anchor,pointer:pointer,at:elapsed())) }
        else { onHintInput?(.cancelled(.leave,at:elapsed())) }
    }
    fileprivate func cancelHint(_ reason: CockpitInputCancellation) { onHintInput?(.cancelled(reason,at:elapsed())) }
    fileprivate func moved(_ id: CockpitControlID, point: CGPoint) { guard !stopped else { return }; onHintInput?(.moved(control:id,pointer:point,at:elapsed())) }
    fileprivate func artwork(_ button: CockpitPaintButton) throws -> CockpitControlArtwork? {
        guard !stopped, let state = stripState else { return nil }
        return try skin.artwork(for:button.id,state:state,button:.init(pressed:button.isHighlighted,hovered:button.hovered,
            focused:button.focused,shutterFraction:state.windowClosed ? 1:0,lampSeverity:caution.presentation(now:now()).severity))
    }
    fileprivate func shutterArtwork(focused:Bool) throws -> CockpitShutterArtwork? { guard !stopped else { return nil }; return try stripState.map { try skin.shutterArtwork(for:$0,focused:focused) } }
    fileprivate func failed(_ error: Error) { onRenderingFailure?(error) }
    fileprivate var reduced: Bool { stripState.map(effectiveReduced) ?? true }
    fileprivate var animateControls: Bool { allowed && !isHiddenOrHasHiddenAncestor && !reduced }
    private func effectiveReduced(_ state: CockpitStripState) -> Bool { state.appearance.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private func seconds(_ duration: Duration) -> Double { let c = duration.components; return Double(c.seconds)+Double(c.attoseconds)/1e18 }
    deinit {
        timer?.invalidate()
        if let workspaceToken { NSWorkspace.shared.notificationCenter.removeObserver(workspaceToken) }
        if let focusToken { NotificationCenter.default.removeObserver(focusToken) }
        if let occlusionToken { NotificationCenter.default.removeObserver(occlusionToken) }
    }
}

@MainActor fileprivate class CockpitPaintButton: NSButton {
    let id: CockpitControlID
    weak var owner: CockpitStripView?
    let base = CALayer(), light = CALayer()
    var hovered = false, focused = false
    private var pointerFocus = false
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(id: CockpitControlID) {
        self.id = id; super.init(frame:.zero); title = id == .alert ? "ALERT":""
        isBordered = false; wantsLayer = true; focusRingType = .none
        layer?.addSublayer(base); layer?.addSublayer(light)
        target = self; action = #selector(activate)
        setAccessibilityIdentifier("cockpit.\(id.rawValue)")
    }
    required init?(coder: NSCoder) { return nil }
    override func draw(_ dirtyRect: NSRect) {} // Registered pixels come from the injected skin.
    override func highlight(_ flag: Bool) { super.highlight(flag); render() }
    override func becomeFirstResponder() -> Bool { let result = super.becomeFirstResponder(); focused = result && !pointerFocus; render(); return result }
    override func resignFirstResponder() -> Bool { let result = super.resignFirstResponder(); focused = false; render(); return result }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect:.zero,options:[.mouseEnteredAndExited,.mouseMoved,.activeAlways,.inVisibleRect],owner:self,userInfo:nil)
        addTrackingArea(area); tracking = area; super.updateTrackingAreas()
    }
    override func mouseDown(with event: NSEvent) {
        pointerFocus = true; focused = false; super.mouseDown(with:event); pointerFocus = false; render()
    }
    func focusForPointer() { pointerFocus = true;window?.makeFirstResponder(self);pointerFocus = false;focused = false;render() }
    override func keyDown(with event: NSEvent) { focused = true;render();owner?.cancelHint(.keyboard);super.keyDown(with:event) }
    override func mouseEntered(with event: NSEvent) { hovered = true; render(); owner?.hint(id,entered:true,pointer:owner?.convert(event.locationInWindow,from:nil) ?? .zero) }
    override func mouseExited(with event: NSEvent) { hovered = false; render(); owner?.hint(id,entered:false,pointer:owner?.convert(event.locationInWindow,from:nil) ?? .zero) }
    override func mouseMoved(with event: NSEvent) { owner?.moved(id,point:owner?.convert(event.locationInWindow,from:nil) ?? .zero) }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }; return owner?.activate(id) ?? false
    }
    @objc private func activate() { owner?.activate(id) }
    func render() {
        do {
            guard let art = try owner?.artwork(self), let state = owner?.stripState else { return }
            try install(art,on:base,scale:state.appearance.scale)
            CATransaction.begin(); CATransaction.setDisableActions(true)
            light.frame = art.bounds; light.contents = art.light; light.contentsScale = CGFloat(state.appearance.scale)
            light.isHidden = art.light == nil; base.isHidden = art.light != nil; CATransaction.commit()
        } catch { stop(); owner?.failed(error) }
    }
    func install(_ art: CockpitControlArtwork,on layer: CALayer,scale: Int) throws {
        let b = art.bounds
        guard [b.minX,b.minY,b.width,b.height].allSatisfy(\.isFinite), b.width>0,b.height>0,b.width<=256,b.height<=256,
              art.base.width==Int(ceil(b.width*CGFloat(scale))),art.base.height==Int(ceil(b.height*CGFloat(scale))),
              art.light.map({$0.width==art.base.width && $0.height==art.base.height}) ?? true else { throw CockpitSurfaceError.invalidRaster }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.frame = b; layer.contents = art.base; layer.contentsScale = CGFloat(scale); layer.contentsGravity = .resize
        CATransaction.commit()
    }
    func stop() { base.contents = nil; light.contents = nil; light.removeAllAnimations() }
}

@MainActor fileprivate final class CockpitShutterButton: CockpitPaintButton {
    private var gesture: CockpitShutterGesture?
    private var lastFraction: CGFloat?
    private let thumb = CALayer(), blind = CALayer(), clip = CALayer()
    override init(id: CockpitControlID) {
        super.init(id:id); clip.masksToBounds = true; clip.anchorPoint = .zero
        clip.addSublayer(blind); layer?.addSublayer(clip); layer?.addSublayer(thumb)
        setAccessibilityRole(.slider)
    }
    required init?(coder: NSCoder) { return nil }
    override func render() {
        do {
            guard let parts = try owner?.shutterArtwork(focused:focused), let state = owner?.stripState, let travel = owner?.stripLayout?.shutterTravel else { return }
            let previous = thumb.presentation()?.position ?? thumb.position
            let previousWidth = clip.presentation()?.bounds.width ?? clip.bounds.width
            try install(parts.track,on:base,scale:state.appearance.scale)
            try install(parts.thumb,on:thumb,scale:state.appearance.scale)
            try install(parts.blind,on:blind,scale:state.appearance.scale)
            let fraction = gesture?.fraction ?? (state.windowClosed ? 1:0)
            let oldFraction = lastFraction; lastFraction = fraction
            CATransaction.begin(); CATransaction.setDisableActions(true)
            clip.position = parts.blind.bounds.origin
            clip.bounds = CGRect(x:0,y:0,width:parts.blind.bounds.width*fraction,height:parts.blind.bounds.height)
            blind.frame.origin = .zero; thumb.frame = parts.thumb.bounds.offsetBy(dx:travel*fraction,dy:0)
            CATransaction.commit()
            if gesture != nil || owner?.animateControls != true || oldFraction != fraction {
                thumb.removeAllAnimations(); clip.removeAllAnimations()
            }
            if gesture == nil, owner?.animateControls == true, oldFraction != nil, oldFraction != fraction, previous != thumb.position {
                let move = CABasicAnimation(keyPath:"position"); move.fromValue = NSValue(point:previous); move.toValue = NSValue(point:thumb.position)
                move.duration = 0.18; move.timingFunction = CAMediaTimingFunction(name:.easeOut); thumb.add(move,forKey:"shutter")
                let reveal = CABasicAnimation(keyPath:"bounds.size.width"); reveal.fromValue = previousWidth; reveal.toValue = clip.bounds.width
                reveal.duration = 0.18; reveal.timingFunction = move.timingFunction; clip.add(reveal,forKey:"shutter")
            }
        } catch { stop(); owner?.failed(error) }
    }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let state = owner?.stripState, let travel = owner?.stripLayout?.shutterTravel else { return }
        focusForPointer()
        owner?.cancelHint(.pointerDown)
        gesture = CockpitShutterGesture(x:convert(event.locationInWindow,from:nil).x,closed:state.windowClosed,travel:travel)
    }
    override func mouseDragged(with event: NSEvent) { gesture?.move(to:convert(event.locationInWindow,from:nil).x); render() }
    override func mouseUp(with event: NSEvent) {
        guard var own = gesture else { return }; gesture = nil
        if let closed = own.finish(at:convert(event.locationInWindow,from:nil).x,enabled:isEnabled) { owner?.requestShutter(closed) }
        render()
    }
    override func keyDown(with event: NSEvent) {
        focused = true;render();owner?.cancelHint(.keyboard)
        switch event.keyCode {
        case 123,115: if isEnabled { owner?.requestShutter(false) }
        case 124,119: if isEnabled { owner?.requestShutter(true) }
        case 53: cancelGesture()
        default: super.keyDown(with:event)
        }
    }
    override func accessibilityPerformIncrement() -> Bool { guard isEnabled else { return false }; return owner?.requestShutter(true) ?? false }
    override func accessibilityPerformDecrement() -> Bool { guard isEnabled else { return false }; return owner?.requestShutter(false) ?? false }
    func cancelGesture() { guard gesture != nil else { return }; gesture = nil; render() }
    override func stop() { super.stop(); gesture = nil; lastFraction = nil; thumb.removeAllAnimations(); clip.removeAllAnimations(); thumb.contents = nil; blind.contents = nil }
}
