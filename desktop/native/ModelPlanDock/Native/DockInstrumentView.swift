// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

public enum DockInstrumentAction: Equatable, Sendable {case subscription(String),notice(String),overflow}
@MainActor private final class DockInstrumentAXNode:NSAccessibilityElement {
    var press:(()->Bool)?
    override func accessibilityPerformPress()->Bool {press?() ?? false}
}

/// B06 instrument surface only. Window dispatch, menus/cards, autohide and movement belong to later owners.
/// Its local alpha hit-test is NOT proof that a transparent NSWindow forwards the original cross-app click.
@MainActor public final class DockInstrumentView:NSView {
    public var requestedNozzleDiameter: CGFloat?
    public private(set) var appliedGeometryScale: CGFloat = 1
    private var communityRowHeight: CGFloat = 44
    @_spi(DockResourceChecks) public var presentedNozzleDiameters: [CGFloat] { skin?.stations.map(\.diameter) ?? [] }
    /// The host resolves the destination screen even while this view is detached/collapsed.
    public var presentationBackingScale: Int?
    @_spi(DockResourceChecks) public var renderedPixelSize: CGSize? {
        image.map { CGSize(width: $0.width, height: $0.height) }
    }
    public var onAction:((DockInstrumentAction)->Void)? {didSet{refreshNodes()}}
    public var permitsAction:((DockInstrumentAction,DockActionSource)->Bool)?
    public weak var backgroundDragDelegate:(any DockBackgroundDragHandling)?
    public weak var nozzleEventDelegate:(any DockNozzleEventHandling)?
    public var keyboardNavigationEnabled=false
    public var keyboardTargetID:String?
    private var edgeTracking:NSTrackingArea?
    /// The pooled-effect adapter stops/releases its old leases before a profile/identity transaction.
    public var onVisualReset:(()->Void)?
    public private(set) var workingLayerParents=[String:CALayer]()
    private var image:CGImage?,backgroundImage:CGImage?,skin:DockInstrumentSkin?,readings=[String:DockInstrumentReading](),notices=[String:DockNotice]()
    private var orderedIDs=[String](),nodes=[String:DockInstrumentAXNode](),alphaData:CFData?
    /// Registered hull extent excludes raster padding, separate controls and shadows.
    public var registeredHullBounds: CGRect? {
        guard let path = registeredHullPath else { return nil }
        let rect = path.boundingBoxOfPath
        return rect.isNull || rect.isEmpty ? nil : rect
    }
    /// Existing material pixels for a destination ghost when the supplier has no vector hull.
    public var registeredMovePreviewImage: CGImage? {
        guard !community, !failed else { return nil }
        return backgroundImage
    }
    public var registeredHullPath: CGPath? {
        guard !failed else { return nil }
        guard let skin, skin.bodyPolygon.count >= 3 else { return nil }
        let path = CGMutablePath()
        path.addLines(between: skin.bodyPolygon.map { CGPoint(x: $0.x - skin.bounds.minX, y: $0.y - skin.bounds.minY) })
        path.closeSubpath(); return path
    }
    /// Movement may outline the neutral rectangle; supplier hull/sliver registration stays independent.
    public var registeredMoveOutlinePath: CGPath? {
        guard !failed else { return nil }
        if community { return bounds.isEmpty ? nil : CGPath(rect: bounds, transform: nil) }
        return registeredHullPath
    }
    public func registeredDragRegions(excluding controls: [CGRect]) -> DockBackgroundDragRegions? {
        if community {
            guard !failed, let body = registeredMoveOutlinePath else { return nil }
            let rows = orderedIDs.compactMap { stationRect($0) }
            return DockBackgroundDragRegions(body: body, excludedControls: controls + rows,
                bodyHitTest: { [weak self] point in
                    guard let self, self.community else { return false }
                    return self.isPainted(atLocal: point)
                })
        }
        guard let skin else { return nil }
        let path: CGPath
        let bodyHitTest: ((CGPoint) -> Bool)?
        if let hull = registeredHullPath {
            path = hull; bodyHitTest = nil
        } else {
            // Precomposited skins deliberately omit a vector body. Register the
            // rendered pixels, not transparent padding or an invented silhouette.
            guard skin.bodyPolygon.isEmpty, !community, !failed, image != nil, alphaData != nil else { return nil }
            path = CGPath(rect: bounds, transform: nil)
            bodyHitTest = { [weak self] point in self?.isPainted(atLocal: point) ?? false }
        }
        var excluded = controls
        for station in skin.stations {
            excluded.append(CGRect(x: station.centre.x - station.diameter / 2 - skin.bounds.minX,
                y: station.centre.y - station.diameter / 2 - skin.bounds.minY, width: station.diameter, height: station.diameter))
            excluded.append(station.readout.offsetBy(dx: -skin.bounds.minX, dy: -skin.bounds.minY))
            excluded.append(station.eventRect.offsetBy(dx: -skin.bounds.minX, dy: -skin.bounds.minY))
            if let alias = station.aliasRect { excluded.append(alias.offsetBy(dx: -skin.bounds.minX, dy: -skin.bounds.minY)) }
        }
        return DockBackgroundDragRegions(body: path, excludedControls: excluded, bodyHitTest: bodyHitTest)
    }
    public var onNeedsFreshPresentation:(()->Void)?
    private var windowObservers=[NSObjectProtocol]()
    private var workspaceObserver:NSObjectProtocol?
    private var scale=1,locale="en",community=true,failed=false
    public override var isFlipped:Bool{true}
    public override var acceptsFirstResponder:Bool{keyboardNavigationEnabled}
    public override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.isGeometryFlipped=true;setAccessibilityElement(false);setAccessibilityRole(.group)}
    deinit {for token in windowObservers{NotificationCenter.default.removeObserver(token)};if let workspaceObserver{NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)}}
    required init?(coder:NSCoder){fatalError("init(coder:) is unsupported")}
    public func applyCommunity(_ rows:[DockInstrumentReading],locale:String="en") throws {
        guard Set(rows.map(\.subscriptionID)).count==rows.count else{throw DockLogicError.invalidCatalogue}
        resetVisuals();self.locale=locale;community=true;failed=false;skin=nil;image=nil;backgroundImage=nil;alphaData=nil
        orderedIDs=rows.map(\.subscriptionID);readings=Dictionary(uniqueKeysWithValues:rows.map{($0.subscriptionID,$0)})
        communityRowHeight = requestedNozzleDiameter ?? 44
        guard communityRowHeight.isFinite, (8...256).contains(communityRowHeight) else { throw DockArtworkError.invalidManifest }
        appliedGeometryScale = 1
        frame.size=CGSize(width:240 * communityRowHeight / 44,height:max(communityRowHeight,CGFloat(rows.count)*communityRowHeight));refreshNodes();needsDisplay=true
    }
    public func applyOfficial(skin:DockInstrumentSkin,rows:[DockInstrumentReading],notices:[String:DockNotice]=[:],renderer:DockInstrumentRenderer,scale:Int,locale:String) throws {
        guard Set(rows.map(\.subscriptionID)).count==rows.count else{throw DockLogicError.invalidCatalogue}
        let renderScale = presentationBackingScale ?? window.map { Int($0.backingScaleFactor) } ?? scale
        guard (1...2).contains(scale), (1...2).contains(renderScale) else{throw DockArtworkError.invalidManifest}
        resetVisuals()
        do {
            let factor: CGFloat
            if let target = requestedNozzleDiameter, let station = skin.stations.first {
                let source = station.logicalPoints.map { CGFloat($0) } ?? station.diameter
                guard target.isFinite, (8...256).contains(target), source.isFinite, source > 0 else { throw DockArtworkError.invalidManifest }
                factor = target / source
            } else { factor = 1 }
            let skin = try skin.scaled(by: factor)
            appliedGeometryScale = factor
            let values=Dictionary(uniqueKeysWithValues:rows.map{($0.subscriptionID,$0)}),result=try renderer.render(skin:skin,readings:values,notices:notices,scale:renderScale)
            community=false;failed=false;self.skin=skin;self.scale=renderScale;self.locale=locale;self.notices=notices
            orderedIDs=rows.map(\.subscriptionID);readings=values;image=result.image;backgroundImage=result.backgroundImage;alphaData=result.image.dataProvider?.data
            frame.size=skin.bounds.size
            CATransaction.begin();CATransaction.setDisableActions(true);layer?.contentsScale=CGFloat(renderScale)
            let visible=Set(skin.stations.compactMap(\.subscriptionID))
            for id in Array(workingLayerParents.keys) where !visible.contains(id){workingLayerParents[id]?.removeFromSuperlayer();workingLayerParents.removeValue(forKey:id)}
            for station in skin.stations {guard let id=station.subscriptionID,values[id] != nil else{continue}
                let parent=workingLayerParents[id] ?? CALayer();parent.isGeometryFlipped=true;parent.contentsScale=CGFloat(renderScale)
                parent.frame=CGRect(x:station.centre.x-station.diameter/2-skin.bounds.minX,y:station.centre.y-station.diameter/2-skin.bounds.minY,width:station.diameter,height:station.diameter)
                if parent.superlayer == nil{layer?.addSublayer(parent)};workingLayerParents[id]=parent
            }
            CATransaction.commit();refreshNodes();needsDisplay=true
        } catch {
            retireOfficialPresentation()
            throw error
        }
    }
    /// A failed refresh keeps only the last supplied material. Old data and all instrument actions retire.
    public func retireOfficialPresentation() {
        resetVisuals(); community = false; failed = true
        image = backgroundImage; alphaData = backgroundImage?.dataProvider?.data
        readings = [:]; orderedIDs = []; notices = [:]; nodes = [:]; setAccessibilityChildren([])
        workingLayerParents.values.forEach { $0.removeFromSuperlayer() }; workingLayerParents = [:]
        needsDisplay = true
    }
    public func dispose(){nozzleEventDelegate?.cancelNozzle();nozzleEventDelegate=nil;keyboardTargetID=nil;backgroundDragDelegate?.cancelBackgroundMove();backgroundDragDelegate=nil;permitsAction=nil;if let edgeTracking{removeTrackingArea(edgeTracking);self.edgeTracking=nil};clearObservers();resetVisuals();failed=true;workingLayerParents.values.forEach{$0.removeFromSuperlayer()};workingLayerParents=[:];nodes=[:];readings=[:];orderedIDs=[];image=nil;backgroundImage=nil;alphaData=nil;setAccessibilityChildren([]);onAction=nil;onVisualReset=nil}
    private func resetVisuals(){onVisualReset?();for parent in workingLayerParents.values{parent.sublayers?.forEach{$0.removeFromSuperlayer()}}}
    public override func viewWillMove(toWindow newWindow:NSWindow?){if newWindow==nil{resetVisuals()};super.viewWillMove(toWindow:newWindow)}
    public override func viewDidHide(){resetVisuals();super.viewDidHide()}
    private func clearObservers(){
        windowObservers.forEach{NotificationCenter.default.removeObserver($0)};windowObservers=[]
        if let workspaceObserver{NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver);self.workspaceObserver=nil}
    }
    public override func viewDidMoveToWindow(){
        super.viewDidMoveToWindow();clearObservers()
        if let window {
            windowObservers.append(NotificationCenter.default.addObserver(forName:NSWindow.didChangeOcclusionStateNotification,object:window,queue:.main){[weak self] _ in
                MainActor.assumeIsolated {guard let self else{return};if self.window?.occlusionState.contains(.visible)==true{self.onNeedsFreshPresentation?()}else{self.resetVisuals()}}
            })
            for name in [NSWindow.didChangeScreenNotification,NSWindow.didChangeBackingPropertiesNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(forName:name,object:window,queue:.main){[weak self] _ in
                    MainActor.assumeIsolated {self?.invalidatePresentation()}
                })
            }
            workspaceObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main){[weak self] _ in
                MainActor.assumeIsolated {self?.invalidatePresentation()}
            }
        }
        if window != nil{onNeedsFreshPresentation?()}
    }
    private func invalidatePresentation(){resetVisuals();onNeedsFreshPresentation?()}
    public override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();invalidatePresentation()}
    public override func draw(_ dirtyRect:NSRect){
        if let image {NSImage(cgImage:image,size:bounds.size).draw(in:bounds,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil);return}
        // Official rasters include transparent/grain pixels: replace the backing contents,
        // rather than accumulating alpha over the previous appearance on each redraw.
        if !community { NSColor.clear.setFill(); bounds.fill(using: .copy); return }
        NSColor.windowBackgroundColor.setFill();bounds.fill()
        if failed {let label=locale.hasPrefix("zh") ? "仪表暂不可用":"Instruments unavailable";(label as NSString).draw(at:CGPoint(x:12,y:12),withAttributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.secondaryLabelColor]);return}
        for (index,id) in orderedIDs.enumerated(){guard let r=readings[id] else{continue}
            let value=[r.alias ?? r.name,r.readout].joined(separator:"  ")
            let context = NSGraphicsContext.current?.cgContext
            context?.saveGState()
            if let control = stationRect(id) { context?.clip(to: control) }
            (value as NSString).draw(at:CGPoint(x:12 * communityRowHeight / 44,y:CGFloat(index)*communityRowHeight+14 * communityRowHeight / 44),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:12 * communityRowHeight / 44,weight:.regular),.foregroundColor:NSColor.labelColor])
            context?.restoreGState()
        }
    }
    private func stationRect(_ id:String)->CGRect? {
        if community {
            guard let i=orderedIDs.firstIndex(of:id) else{return nil}
            let inset = 8 * communityRowHeight / 44
            return CGRect(x:0,y:CGFloat(i)*communityRowHeight,width:bounds.width,height:communityRowHeight).insetBy(dx:inset,dy:inset)
        }
        guard let s=skin?.stations.first(where:{$0.subscriptionID==id}),let origin=skin?.bounds.origin else{return nil}
        return CGRect(x:s.centre.x-s.diameter/2-origin.x,y:s.centre.y-s.diameter/2-origin.y,width:s.diameter,height:s.diameter)
    }
    private func refreshNodes(){
        var children=[DockInstrumentAXNode](),used=Set<String>()
        func append(_ key:String,_ label:String,_ value:String?,_ help:String,_ rect:CGRect,_ action:DockInstrumentAction) {
            let node=nodes[key] ?? DockInstrumentAXNode(),oldValue=node.accessibilityValue() as? String
            node.setAccessibilityRole(.button);node.setAccessibilityParent(self);node.setAccessibilityEnabled(onAction != nil)
            node.setAccessibilityIdentifier("dock."+key);node.setAccessibilityLabel(label);node.setAccessibilityValue(value);node.setAccessibilityHelp(help)
            node.setAccessibilityFrameInParentSpace(rect);node.press={[weak self,weak node] in
                guard let self,let node,self.nodes[key] === node,self.permitsAction?(action,.accessibility) ?? true else{return false}
                // A gate may synchronously refresh the snapshot; recheck this stable AX node afterward.
                guard self.nodes[key] === node,let onAction=self.onAction else{return false};onAction(action);return true
            }
            nodes[key]=node;children.append(node);used.insert(key)
            if oldValue != value {NSAccessibility.post(element:node,notification:.valueChanged)}
        }
        for id in orderedIDs {guard let reading=readings[id],let rect=stationRect(id) else{continue}
            append("subscription."+id,reading.alias ?? reading.name,reading.readout,[reading.selectedWindowLabel,reading.readout].compactMap{$0}.joined(separator:" · "),rect,.subscription(id))
            if !community,let notice=notices[id],let station=skin?.stations.first(where:{$0.subscriptionID==id}),let origin=skin?.bounds.origin {
                let zh=locale.hasPrefix("zh"),label:String
                switch notice.key.kind {
                case .forecast:label=zh ? "可能提前耗尽":"May run out before reset"
                case .resetAnnounced:label=zh ? "已公告额外重置":"Extra reset announced"
                case .resetConfirmed:label=zh ? "额外重置已确认，等待读数":"Extra reset confirmed; awaiting a reading"
                case .cardsExpiring:label=zh ? "重置卡即将过期":"Reset card expiring"
                case .credits:label=zh ? "正在使用余额":"Using credits"
                }
                append("notice."+id,label,nil,label,station.eventRect.offsetBy(dx:-origin.x,dy:-origin.y),.notice(id))
            }
        }
        if !community,let more=skin?.stations.first(where:{$0.overflowCount != nil}),let origin=skin?.bounds.origin {
            let label=locale.hasPrefix("zh") ? "更多订阅":"More subscriptions"
            append("overflow",label,String(more.overflowCount ?? 0),label,CGRect(x:more.centre.x-more.diameter/2-origin.x,y:more.centre.y-more.diameter/2-origin.y,width:more.diameter,height:more.diameter),.overflow)
        }
        nodes=nodes.filter{used.contains($0.key)};setAccessibilityChildren(children)
    }
    public func isPainted(atLocal local:NSPoint)->Bool {
        guard !isHiddenOrHasHiddenAncestor,bounds.contains(local),!failed else{return false}
        if community{return true}
        // This tests only this view's painted raster. The containing window's native route is a separate gate.
        guard let image,let bytes=alphaData,CFDataGetLength(bytes)>=image.bytesPerRow*image.height,image.bitsPerPixel==32,image.bitsPerComponent==8 else{return false}
        let x=min(image.width-1,max(0,Int(local.x*CGFloat(scale)))),y=min(image.height-1,max(0,Int(local.y*CGFloat(scale))))
        let alphaIndex=(image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first) ? 0:3
        guard CFDataGetBytePtr(bytes)![y*image.bytesPerRow+x*4+alphaIndex]>0 else{return false};return true
    }
    public override func hitTest(_ point:NSPoint)->NSView? {isPainted(atLocal:convert(point,from:superview)) ? self:nil}
    public override func updateTrackingAreas(){
        if let edgeTracking{removeTrackingArea(edgeTracking)}
        let next=NSTrackingArea(rect:.zero,options:[.inVisibleRect,.cursorUpdate,.mouseMoved,.mouseEnteredAndExited,.activeAlways],owner:self,userInfo:nil)
        edgeTracking=next;addTrackingArea(next);super.updateTrackingAreas()
    }
    public override func cursorUpdate(with event:NSEvent){
        if backgroundDragDelegate?.isBackgroundMoving == true{NSCursor.closedHand.set()}
        else if backgroundDragDelegate?.backgroundCanDrag(local:convert(event.locationInWindow,from:nil)) == true{NSCursor.openHand.set()}
        else{NSCursor.arrow.set()}
    }
    public override func mouseMoved(with event:NSEvent){
        let p=convert(event.locationInWindow,from:nil)
        if case .subscription(let id)?=pointerAction(atLocal:p),isPainted(atLocal:p){nozzleEventDelegate?.hoverNozzle(id)}else{nozzleEventDelegate?.hoverNozzle(nil)}
    }
    public override func mouseEntered(with event:NSEvent){mouseMoved(with:event)}
    public override func mouseExited(with event:NSEvent){nozzleEventDelegate?.hoverNozzle(nil)}
    public override func mouseDragged(with event:NSEvent){
        if nozzleEventDelegate?.hasCapture == true{nozzleEventDelegate?.moveNozzle(local:convert(event.locationInWindow,from:nil));return}
        guard let window,let handler=backgroundDragDelegate else{super.mouseDragged(with:event);return}
        handler.updateBackgroundMove(global:window.convertPoint(toScreen:event.locationInWindow))
        if handler.isBackgroundMoving{NSCursor.closedHand.set()}
    }
    public override func mouseUp(with event:NSEvent){
        if let handler=nozzleEventDelegate,handler.hasCapture,let window{
            let p=convert(event.locationInWindow,from:nil),id:String?
            if case .subscription(let current)?=pointerAction(atLocal:p),isPainted(atLocal:p){id=current}else{id=nil}
            handler.endNozzle(global:window.convertPoint(toScreen:event.locationInWindow),currentID:id);return
        }
        if let window{backgroundDragDelegate?.endBackgroundMove(global:window.convertPoint(toScreen:event.locationInWindow))}
        NSCursor.arrow.set()
    }
    public override func cancelOperation(_ sender:Any?){nozzleEventDelegate?.cancelNozzle();backgroundDragDelegate?.cancelBackgroundMove();NSCursor.arrow.set()}
    public override func keyDown(with event:NSEvent){
        let modifiers=event.modifierFlags.intersection([.option,.control,.command])
        if modifiers == .option,let id=keyboardTargetID,nozzleEventDelegate?.optionArrow(id:id,keyCode:event.keyCode)==true{return}
        super.keyDown(with:event)
    }
    private func pointerAction(atLocal p:NSPoint)->DockInstrumentAction?{
        if let skin,!community {
            let global=CGPoint(x:p.x+skin.bounds.minX,y:p.y+skin.bounds.minY)
            for s in skin.stations.reversed(){
                if let id=s.subscriptionID,notices[id] != nil,s.eventRect.contains(global){return .notice(id)}
                if let id=s.subscriptionID,let r=stationRect(id),r.contains(p) || (s.showsReadout != false && s.readout.contains(global)) || s.aliasRect?.contains(global)==true{return .subscription(id)}
                if s.overflowCount != nil,CGRect(x:s.centre.x-s.diameter/2,y:s.centre.y-s.diameter/2,width:s.diameter,height:s.diameter).contains(global){return .overflow}
            }
        } else if let id=orderedIDs.first(where:{stationRect($0)?.contains(p)==true}){return .subscription(id)}
        return nil
    }
    @discardableResult private func dispatchPointer(currentPoint:()->NSPoint?,nozzleGlobal:CGPoint?=nil)->Bool{
        guard let initial=currentPoint(),isPainted(atLocal:initial),let action=pointerAction(atLocal:initial),permitsAction?(action,.pointer) ?? true else{return false}
        // A gate can replace/reorder stations without removing their readings. Re-hit-test the
        // original physical pointer against the current presentation, rather than validating only ID existence.
        guard let current=currentPoint(),isPainted(atLocal:current),pointerAction(atLocal:current)==action else{return false}
        if nozzleGlobal != nil,case .subscription(let id)=action,let handler=nozzleEventDelegate{return handler.beginNozzle(id:id,local:current)}
        guard let onAction else{return false};onAction(action);return true
    }
    /// Neutral checks exercise the same dispatcher without creating a native window/event source.
    @_spi(DockResourceChecks) @discardableResult public func performPointerPress(atLocal point:NSPoint)->Bool{
        dispatchPointer(currentPoint:{point})
    }
    public override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    public override func mouseDown(with event:NSEvent){
        guard !failed else{return}
        let eventWindow=window,screenPoint=window?.convertPoint(toScreen:event.locationInWindow)
        func currentPoint()->NSPoint?{
            if let eventWindow,let screenPoint{
                guard window === eventWindow else{return nil}
                return convert(eventWindow.convertPoint(fromScreen:screenPoint),from:nil)
            }
            guard window==nil else{return nil};return convert(event.locationInWindow,from:nil)
        }
        guard let p=currentPoint() else{return}
        if let screenPoint,backgroundDragDelegate?.beginBackgroundMove(local:p,global:screenPoint) == true{return}
        dispatchPointer(currentPoint:currentPoint,nozzleGlobal:screenPoint)
    }
}
