// SPDX-License-Identifier: MIT
import AppKit

@MainActor private final class HelpUIActionButton: NSButton {
    private(set) var retired=false
    var invoke:((HelpUIActionButton)->Void)?
    override init(frame:NSRect) { super.init(frame:frame);target=self;action=#selector(pressed);isBordered=false;alignment = .right }
    required init?(coder:NSCoder) { fatalError("init(coder:) is unsupported") }
    @objc private func pressed() { guard !retired,isEnabled else { return };invoke?(self) }
    override func sendAction(_ action:Selector?,to target:Any?)->Bool { !retired && isEnabled && super.sendAction(action,to:target) }
    override func accessibilityPerformPress()->Bool { !retired && isEnabled && super.accessibilityPerformPress() }
    func retire() { retired=true;isEnabled=false;target=nil;action=nil;invoke=nil }
}

@MainActor private final class HelpUICardView:NSView {
    let identity:HelpUICardIdentity,anchorID:String
    let title=NSTextField(wrappingLabelWithString:""),body=NSTextField(wrappingLabelWithString:"")
    let button=HelpUIActionButton(frame:.zero)
    var retired=false
    var onHover:((Bool)->Void)?
    var tracking:NSTrackingArea?
    let provider:HelpUIRecipeProvider
    override var isFlipped:Bool { true }
    init(identity:HelpUICardIdentity,anchorID:String,provider:HelpUIRecipeProvider) {
        self.identity=identity;self.anchorID=anchorID;self.provider=provider
        super.init(frame:.zero);wantsLayer=true;setAccessibilityElement(false)
        addSubview(title);addSubview(body);addSubview(button)
        for label in [title,body] { label.maximumNumberOfLines=0;label.lineBreakMode = .byWordWrapping }
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) is unsupported") }
    func configure(title text:String?,body bodyText:String,buttonTitle:String?,bound:Bool,isCurrent:()->Bool) {
        let titleFont=provider.font(for:.contextTitle);guard isCurrent() else { return }
        let bodyFont=provider.font(for:.contextBody);guard isCurrent() else { return }
        let buttonFont=provider.font(for:.button);guard isCurrent() else { return }
        let ink=provider.primaryInk;guard isCurrent() else { return }
        let width=max(1,bounds.width-22)
        var titleHeight:CGFloat=0
        if let text { titleHeight=provider.measure(text,width:width,role:.contextTitle).height;guard isCurrent() else { return } }
        let height=provider.measure(bodyText,width:width,role:text==nil ? .hintBody:.contextBody).height
        guard isCurrent() else { return }
        title.stringValue=text ?? "";title.isHidden=text==nil;title.font=titleFont;title.textColor=ink
        body.stringValue=bodyText;body.font=bodyFont;body.textColor=ink
        var y:CGFloat=8
        if text != nil { title.frame = .init(x:11,y:y,width:width,height:titleHeight);y+=titleHeight+3 }
        body.frame = .init(x:11,y:y,width:width,height:height);y+=height+5
        button.title=buttonTitle ?? "";button.isHidden=buttonTitle==nil;button.isEnabled=bound && buttonTitle != nil
        button.font=buttonFont;button.frame = .init(x:11,y:y,width:width,height:22)
        button.setAccessibilityLabel(buttonTitle)
        setAccessibilityIdentifier("help.card."+anchorID)
        needsDisplay=true
    }
    override func draw(_ dirtyRect:NSRect) {
        provider.panelColor.setFill();let path=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:4,yRadius:4);path.fill()
        provider.borderColor.setStroke();path.lineWidth=1;path.stroke()
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas();if let tracking { removeTrackingArea(tracking) }
        let next=NSTrackingArea(rect:.zero,options:[.mouseEnteredAndExited,.activeInKeyWindow,.inVisibleRect],owner:self)
        addTrackingArea(next);tracking=next
    }
    override func mouseEntered(with event:NSEvent) { if !retired { onHover?(true) } }
    override func mouseExited(with event:NSEvent) { if !retired { onHover?(false) } }
    func retire() { retired=true;button.retire();onHover=nil;setAccessibilityHidden(true) }
}

/// Presentation-only overlay. No timer, ledger, hint admission, network action or focus activation.
/// Bind existing sources' onHelpChange plus the sole upper arbiter's current offer. Never bind the legacy queue.
@MainActor public final class HelpUILayerView:NSView {
    public let recipeProvider:HelpUIRecipeProvider
    public var onAction:((HelpUIAction)->Void)? { didSet {
        card?.button.isEnabled=onAction != nil && card?.button.isHidden==false
        mapSource?.isEnabled=onAction != nil
        secondaryMapSource?.isEnabled=onAction != nil
    } }
    public var onHintInput:((InstrumentHintInput)->Void)?
    /// A changed geometry result; upper composition alone checks actual visibility and confirms an offer.
    public var onPresentation:((HelpUIPresentation)->Void)? { didSet { if let presentation { onPresentation?(presentation) } } }
    public private(set) var input:HelpUIRenderInput?
    public private(set) var presentation:HelpUIPresentation?
    public private(set) var layoutCount=0
    private var generation:UInt64=0
    private var disposed=false
    private let elapsed:(()->Double)?
    private var header=NSTextField(wrappingLabelWithString:"")
    private var labels=[String:NSTextField]()
    private var card:HelpUICardView?,retiringCard:HelpUICardView?
    private var mapSource:HelpUIActionButton?
    private var mapSourceID:String?
    private var secondaryMapSource:HelpUIActionButton?
    private var secondaryMapSourceID:String?
    public override var isFlipped:Bool { true }
    public override var acceptsFirstResponder:Bool { onAction != nil && (presentation?.mapHeader != nil || presentation?.card != nil) }
    public init(recipeProvider:HelpUIRecipeProvider?=nil,elapsed:(()->Double)?=nil) {
        self.recipeProvider=recipeProvider ?? NeutralHelpUIRecipeProvider();self.elapsed=elapsed
        super.init(frame:.zero);wantsLayer=true;setAccessibilityElement(false)
        addSubview(header);header.isHidden=true;header.maximumNumberOfLines=0
        header.setAccessibilityIdentifier("help.map.header")
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) is unsupported") }
    public func update(_ next:HelpUIRenderInput) {
        guard !disposed,input != next else { return }
        generation &+= 1;let token=generation
        // Host/recipe callouts may synchronously update or dispose; their newer generation wins.
        let old=input;input=next
        if old?.sessionID != next.sessionID { retireCard(animated:false);retireMapSource() }
        if old?.sessionID != next.sessionID || old?.viewport != next.viewport || old?.anchors != next.anchors || old?.profile != next.profile {
            cancelRest(.layoutChange)
            guard isCurrent(token) else { return }
        }
        if old?.map.mode == .hidden && next.map.mode != .hidden {
            cancelRest(.keyboard);guard isCurrent(token) else { return }
        }
        if next.viewport.width.isFinite,next.viewport.height.isFinite,next.viewport.width>16,next.viewport.height>38,
           next.viewport.width<=16_384,next.viewport.height<=16_384 { setFrameSize(next.viewport) }
        layoutCount+=1
        let candidate=recipeProvider.presentation(for:next)
        guard isCurrent(token) else { return }
        let result=validate(candidate,input:next),changed=presentation != result
        presentation=result
        applyMap(result,input:next,token:token)
        guard isCurrent(token) else { return }
        applyCard(result,input:next,token:token)
        guard isCurrent(token) else { return }
        if next.reduceMotion { removeRetiringCard() }
        needsDisplay=true
        if changed { onPresentation?(result) }
    }
    private func isCurrent(_ token:UInt64)->Bool { !disposed && generation==token }
    private func validate(_ candidate:HelpUIPresentation,input:HelpUIRenderInput)->HelpUIPresentation {
        guard input.active else { return .init(sessionID:input.sessionID) }
        if candidate.mapHeader != nil && input.map.mode == .hidden { return .init(sessionID:input.sessionID,unresolvedMapIDs:["invalidRecipe"]) }
        if let card=candidate.card {
            let matches:Bool
            switch card.identity {
            case .firstUse(let id):matches=input.firstUse?.offerID==id && input.firstUse?.anchorID==card.anchorID
            case .context(let id):matches=input.firstUse==nil && input.contextual?.id==id && input.contextual?.anchorID==card.anchorID
            }
            guard matches,input.map.mode == .hidden else { return .init(sessionID:input.sessionID,unresolvedMapIDs:["invalidRecipe"]) }
        }
        var frames:[CGRect] = candidate.mapLabels.map(\.frame)
        if let header=candidate.mapHeader { frames.append(header) }
        if let source=candidate.mapSourceFrame { frames.append(source) }
        if let source=candidate.secondaryMapSourceFrame {
            guard input.map.mode != .hidden,candidate.mapSourceFrame != nil,
                  input.map.secondarySourceFrame==source,input.map.secondarySourceActionID != nil,
                  input.map.secondarySourceActionTitle != nil,
                  HelpUIGeometry.free(source,from:candidate.mapLabels.map(\.frame)+(candidate.mapHeader.map { [$0] } ?? [])+(candidate.mapSourceFrame.map { [$0] } ?? [])) else { return .init(sessionID:input.sessionID,unresolvedMapIDs:["invalidRecipe"]) }
            frames.append(source)
        }
        if let card=candidate.card { frames.append(card.frame) }
        let safe=HelpUIGeometry.safe(input.viewport)
        guard candidate.sessionID==input.sessionID,candidate.mapLabels.count<=32,
              !(candidate.mapHeader != nil && candidate.card != nil),
              frames.allSatisfy({HelpUIGeometry.valid($0) && safe.contains($0) && HelpUIGeometry.free($0,from:input.liveReadings)}),
              candidate.mapLabels.allSatisfy({ label in
                  label.leader.allSatisfy({$0.x.isFinite && $0.y.isFinite}) && zip(label.leader,label.leader.dropFirst()).allSatisfy {
                      HelpUIGeometry.segmentIsClear($0.0,$0.1,blocks:input.liveReadings+frames)
                  }
              }) else { return .init(sessionID:input.sessionID,unresolvedMapIDs:["invalidRecipe"]) }
        return candidate
    }
    private func applyMap(_ result:HelpUIPresentation,input:HelpUIRenderInput,token:UInt64) {
        guard result.mapHeader != nil else { clearMap();return }
        let headerFont=recipeProvider.font(for:.header);guard isCurrent(token) else { return }
        let captionFont=recipeProvider.font(for:.caption);guard isCurrent(token) else { return }
        let buttonFont=recipeProvider.font(for:.button);guard isCurrent(token) else { return }
        let ink=recipeProvider.primaryInk;guard isCurrent(token) else { return }
        let catalog=HelpMapCatalog(input.language)
        header.isHidden=result.mapHeader==nil;header.stringValue=catalog.metaphor+"\n"+catalog.dismissal
        header.font=headerFont;header.textColor=ink
        if let frame=result.mapHeader { header.frame=frame.insetBy(dx:8,dy:5) }
        let visible=Set(result.mapLabels.map(\.id))
        for id in Array(labels.keys) where !visible.contains(id) { labels.removeValue(forKey:id)?.removeFromSuperview() }
        for item in result.mapLabels {
            let label=labels[item.id] ?? NSTextField(wrappingLabelWithString:"")
            if labels[item.id]==nil { labels[item.id]=label;addSubview(label) }
            label.stringValue=item.text;label.maximumNumberOfLines=0
            label.font=captionFont;label.textColor=ink
            label.frame=item.frame.insetBy(dx:8,dy:5);label.setAccessibilityLabel(item.text)
            label.setAccessibilityIdentifier("help.map."+item.id)
        }
        if let frame=result.mapSourceFrame,let id=input.map.sourceActionID,let text=input.map.sourceActionTitle {
            if mapSourceID != id {
                retireMapSource();let button=HelpUIActionButton(frame:frame);mapSource=button;mapSourceID=id;addSubview(button)
                button.invoke={ [weak self,weak button] sender in
                    guard let self,let button,self.mapSource === button,sender === button,
                          self.input?.active==true,self.input?.map.sourceActionID==id,self.presentation?.mapSourceFrame != nil else { return }
                    self.onAction?(.mapSourceAction(actionID:id))
                }
            }
            mapSource?.title=text;mapSource?.frame=frame;mapSource?.font=buttonFont;mapSource?.isEnabled=onAction != nil
        } else { retireMapSource() }
        if let frame=result.secondaryMapSourceFrame,let id=input.map.secondarySourceActionID,let text=input.map.secondarySourceActionTitle {
            if secondaryMapSourceID != id {
                retireSecondaryMapSource();let button=HelpUIActionButton(frame:frame)
                secondaryMapSource=button;secondaryMapSourceID=id;addSubview(button)
                button.invoke={ [weak self,weak button] sender in
                    guard let self,let button,self.secondaryMapSource === button,sender === button,
                          self.input?.active==true,self.input?.map.secondarySourceActionID==id,self.presentation?.secondaryMapSourceFrame != nil else { return }
                    self.onAction?(.mapSourceAction(actionID:id))
                }
            }
            secondaryMapSource?.title=text;secondaryMapSource?.frame=frame;secondaryMapSource?.font=buttonFont;secondaryMapSource?.isEnabled=onAction != nil
        } else { retireSecondaryMapSource() }
        setAccessibilityLabel(catalog.title)
    }
    private func applyCard(_ result:HelpUIPresentation,input:HelpUIRenderInput,token:UInt64) {
        guard let placement=result.card else { retireCard(animated:input.active && !input.reduceMotion && input.map.mode == .hidden);return }
        if card?.identity != placement.identity || card?.anchorID != placement.anchorID {
            retireCard(animated:false)
            let view=HelpUICardView(identity:placement.identity,anchorID:placement.anchorID,provider:recipeProvider)
            card=view;addSubview(view)
            view.button.invoke={ [weak self,weak view] sender in
                guard let self,let view,self.card === view,!view.retired,view.button === sender,self.onAction != nil else { return }
                switch placement.identity {
                case .firstUse(let offer):
                    guard self.input?.firstUse?.offerID==offer else { return };self.onAction?(.dismissHint(offerID:offer,reason:.explicitButton))
                case .context(let id):
                    guard let context=self.input?.contextual,context.id==id,let action=context.actionID else { return }
                    self.onAction?(.contextualAction(id:id,actionID:action))
                }
            }
            view.onHover={ [weak self,weak view] inside in
                guard let self,let view,self.card === view,!view.retired,case .context(let id)=view.identity else { return }
                self.onAction?(.contextualHover(id:id,inside:inside))
            }
        }
        guard let card else { return };card.frame=placement.frame
        switch placement.identity {
        case .firstUse:
            if let hint=input.firstUse { card.configure(title:nil,body:hint.text,buttonTitle:hint.dismissTitle,bound:onAction != nil,isCurrent:{self.isCurrent(token)}) }
        case .context:
            if let context=input.contextual { card.configure(title:context.explanation.title,body:context.explanation.body,
                buttonTitle:context.actionID == nil ? nil:context.actionTitle,bound:onAction != nil,isCurrent:{self.isCurrent(token)}) }
        }
    }
    private func retireCard(animated:Bool) {
        guard let old=card else { return };card=nil;old.retire();removeRetiringCard()
        guard animated,window != nil,case .firstUse=old.identity else { old.removeFromSuperview();return }
        retiringCard=old
        NSAnimationContext.runAnimationGroup { context in context.duration=0.18;old.animator().alphaValue=0 } completionHandler: { [weak old] in
            Task { @MainActor in old?.removeFromSuperview() }
        }
    }
    private func removeRetiringCard() { retiringCard?.layer?.removeAllAnimations();retiringCard?.removeFromSuperview();retiringCard=nil }
    private func retireSecondaryMapSource() { secondaryMapSource?.retire();secondaryMapSource?.removeFromSuperview();secondaryMapSource=nil;secondaryMapSourceID=nil }
    private func retireMapSource() { mapSource?.retire();mapSource?.removeFromSuperview();mapSource=nil;mapSourceID=nil;retireSecondaryMapSource() }
    private func clearMap() {
        header.isHidden=true
        for label in labels.values { label.removeFromSuperview() };labels.removeAll();retireMapSource()
    }
    public func suspend() {
        guard !disposed else { return }
        generation &+= 1;let token=generation
        removeRetiringCard()
        cancelRest(.focusLoss)
        guard isCurrent(token),let old=input else { return };var next=old;next.active=false;update(next)
    }
    /// Terminal teardown; create a fresh layer when the host needs another presentation session.
    public func dispose() {
        guard !disposed else { return }
        // Publish terminal state before calling the host; teardown callbacks cannot revive this view.
        disposed=true;generation &+= 1
        input=nil;presentation=nil;retireCard(animated:false);removeRetiringCard();clearMap();needsDisplay=true
        cancelRest(.focusLoss);cancelRest(.teardown)
        onAction=nil;onHintInput=nil;onPresentation=nil
    }
    public override func viewWillMove(toWindow newWindow:NSWindow?) { if newWindow==nil { suspend() };super.viewWillMove(toWindow:newWindow) }
    private func cancelRest(_ reason:InstrumentHintCancellation) {
        let token=generation
        guard let at=elapsed?(),at.isFinite,at>=0,generation==token else { return };onHintInput?(.cancelFaderRest(reason,at:at))
    }
    @discardableResult public func handleEscape()->Bool {
        guard onAction != nil,let input,input.active else { return false }
        let consumes=input.map.mode != .hidden || presentation?.card != nil
        let token=generation
        cancelRest(.keyboard)
        guard isCurrent(token) else { return consumes }
        if input.map.mode != .hidden { onAction?(.dismissMap(reason:.escape,returnFocusID:input.map.returnFocusID));return true }
        if let card=presentation?.card {
            switch card.identity {
            case .firstUse(let id):onAction?(.dismissHint(offerID:id,reason:.escape))
            case .context(let id):onAction?(.dismissContext(id:id,returnFocusID:card.anchorID))
            };return true
        }
        return false
    }
    /// True consumes a latched-map press. False preserves the original underlying click after hint dismissal.
    @discardableResult public func outsidePointerDown()->Bool {
        guard onAction != nil,input?.active==true else { return false }
        let consumes=input?.map.mode == .latched
        let token=generation
        cancelRest(.pointerDown)
        guard isCurrent(token) else { return consumes }
        if input?.map.mode == .latched {
            onAction?(.dismissMap(reason:.pointer,returnFocusID:input?.map.returnFocusID));return true
        }
        if let card=presentation?.card {
            switch card.identity {
            case .firstUse(let id):onAction?(.dismissHint(offerID:id,reason:.pointer))
            case .context(let id):onAction?(.dismissContext(id:id,returnFocusID:nil))
            }
        }
        return false
    }
    public override func keyDown(with event:NSEvent) { if event.keyCode != 53 || !handleEscape() { super.keyDown(with:event) } }
    public override func mouseDown(with event:NSEvent) {
        guard onAction != nil,input?.active==true else { return }
        let token=generation
        cancelRest(.pointerDown)
        guard isCurrent(token) else { return }
        if presentation?.mapHeader != nil,input?.map.mode == .latched { onAction?(.dismissMap(reason:.pointer,returnFocusID:input?.map.returnFocusID)) }
        else if let placement=presentation?.card,case .firstUse(let id)=placement.identity { onAction?(.dismissHint(offerID:id,reason:.pointer)) }
    }
    public override func hitTest(_ point:NSPoint)->NSView? {
        guard onAction != nil,input?.active==true,!isHiddenOrHasHiddenAncestor else { return nil }
        let local=convert(point,from:superview)
        if presentation?.mapHeader != nil {
            if let button=mapSource,button.frame.contains(local),button.isEnabled { return button }
            if let button=secondaryMapSource,button.frame.contains(local),button.isEnabled { return button }
            return input?.map.mode == .latched && bounds.contains(local) ? self:nil
        }
        guard let card,!card.retired,card.frame.contains(local) else { return nil }
        // Plain explanations stay pointer-transparent; only an explicit hint/link button accepts input.
        guard !card.button.isHidden,card.button.isEnabled else { return nil }
        let inCard=convert(local,to:card)
        return card.button.frame.contains(inCard) ? card.button:self
    }
    public override func draw(_ dirtyRect:NSRect) {
        guard let presentation else { return }
        if let frame=presentation.mapHeader { panel(frame) }
        for label in presentation.mapLabels {
            panel(label.frame)
            guard let first=label.leader.first else { continue }
            let path=NSBezierPath();path.move(to:first);for point in label.leader.dropFirst() { path.line(to:point) }
            recipeProvider.secondaryInk.setStroke();path.lineWidth=1;path.stroke()
            if let end=label.leader.last { recipeProvider.primaryInk.setFill();NSBezierPath(ovalIn:.init(x:end.x-2,y:end.y-2,width:4,height:4)).fill() }
        }
    }
    private func panel(_ frame:CGRect) {
        recipeProvider.panelColor.setFill();let path=NSBezierPath(roundedRect:frame,xRadius:4,yRadius:4);path.fill()
        recipeProvider.borderColor.setStroke();path.lineWidth=1;path.stroke()
    }
    public override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance();needsDisplay=true;card?.needsDisplay=true }
    public override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties();needsDisplay=true;card?.needsDisplay=true }
    // Test/host introspection does not imply a visible-display acknowledgment.
    var currentActionButton:NSButton? { card?.button }
    var sourceActionButton:NSButton? { mapSource }
}
