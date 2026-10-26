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
    public var onAction:((DockInstrumentAction)->Void)? {didSet{refreshNodes()}}
    /// The pooled-effect adapter stops/releases its old leases before a profile/identity transaction.
    public var onVisualReset:(()->Void)?
    public private(set) var workingLayerParents=[String:CALayer]()
    private var image:CGImage?,skin:DockInstrumentSkin?,readings=[String:DockInstrumentReading](),notices=[String:DockNotice]()
    private var orderedIDs=[String](),nodes=[String:DockInstrumentAXNode](),alphaData:CFData?
    public var onNeedsFreshPresentation:(()->Void)?
    private var windowObservers=[NSObjectProtocol]()
    private var workspaceObserver:NSObjectProtocol?
    private var scale=1,locale="en",community=true,failed=false
    public override var isFlipped:Bool{true}
    public override var acceptsFirstResponder:Bool{false}
    public override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.isGeometryFlipped=true;setAccessibilityElement(false);setAccessibilityRole(.group)}
    deinit {for token in windowObservers{NotificationCenter.default.removeObserver(token)};if let workspaceObserver{NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)}}
    required init?(coder:NSCoder){fatalError("init(coder:) is unsupported")}
    public func applyCommunity(_ rows:[DockInstrumentReading],locale:String="en") throws {
        guard Set(rows.map(\.subscriptionID)).count==rows.count else{throw DockLogicError.invalidCatalogue}
        resetVisuals();self.locale=locale;community=true;failed=false;skin=nil;image=nil;alphaData=nil
        orderedIDs=rows.map(\.subscriptionID);readings=Dictionary(uniqueKeysWithValues:rows.map{($0.subscriptionID,$0)})
        frame.size=CGSize(width:240,height:max(44,CGFloat(rows.count)*44));refreshNodes();needsDisplay=true
    }
    public func applyOfficial(skin:DockInstrumentSkin,rows:[DockInstrumentReading],notices:[String:DockNotice]=[:],renderer:DockInstrumentRenderer,scale:Int,locale:String) throws {
        guard Set(rows.map(\.subscriptionID)).count==rows.count else{throw DockLogicError.invalidCatalogue}
        guard (1...2).contains(scale) else{throw DockArtworkError.invalidManifest}
        resetVisuals()
        do {
            let values=Dictionary(uniqueKeysWithValues:rows.map{($0.subscriptionID,$0)}),result=try renderer.render(skin:skin,readings:values,notices:notices,scale:scale)
            community=false;failed=false;self.skin=skin;self.scale=scale;self.locale=locale;self.notices=notices
            orderedIDs=rows.map(\.subscriptionID);readings=values;image=result.image;alphaData=result.image.dataProvider?.data
            frame.size=skin.bounds.size
            CATransaction.begin();CATransaction.setDisableActions(true);layer?.contentsScale=CGFloat(scale)
            let visible=Set(skin.stations.compactMap(\.subscriptionID))
            for id in Array(workingLayerParents.keys) where !visible.contains(id){workingLayerParents[id]?.removeFromSuperlayer();workingLayerParents.removeValue(forKey:id)}
            for station in skin.stations {guard let id=station.subscriptionID,values[id] != nil else{continue}
                let parent=workingLayerParents[id] ?? CALayer();parent.isGeometryFlipped=true;parent.contentsScale=CGFloat(scale)
                parent.frame=CGRect(x:station.centre.x-station.diameter/2-skin.bounds.minX,y:station.centre.y-station.diameter/2-skin.bounds.minY,width:station.diameter,height:station.diameter)
                if parent.superlayer == nil{layer?.addSublayer(parent)};workingLayerParents[id]=parent
            }
            CATransaction.commit();refreshNodes();needsDisplay=true
        } catch {
            failed=true;image=nil;alphaData=nil;readings=[:];orderedIDs=[];nodes=[:];setAccessibilityChildren([])
            workingLayerParents.values.forEach{$0.removeFromSuperlayer()};workingLayerParents=[:];needsDisplay=true
            throw error
        }
    }
    public func dispose(){clearObservers();resetVisuals();workingLayerParents.values.forEach{$0.removeFromSuperlayer()};workingLayerParents=[:];nodes=[:];readings=[:];orderedIDs=[];image=nil;alphaData=nil;setAccessibilityChildren([]);onAction=nil;onVisualReset=nil}
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
    }
    private func invalidatePresentation(){resetVisuals();onNeedsFreshPresentation?()}
    public override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();invalidatePresentation()}
    public override func draw(_ dirtyRect:NSRect){
        if let image {NSImage(cgImage:image,size:bounds.size).draw(in:bounds,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil);return}
        NSColor.windowBackgroundColor.setFill();bounds.fill()
        if failed {let label=locale.hasPrefix("zh") ? "仪表暂不可用":"Instruments unavailable";(label as NSString).draw(at:CGPoint(x:12,y:12),withAttributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.secondaryLabelColor]);return}
        for (index,id) in orderedIDs.enumerated(){guard let r=readings[id] else{continue}
            let value=[r.alias ?? r.name,r.readout].joined(separator:"  ")
            (value as NSString).draw(at:CGPoint(x:12,y:CGFloat(index)*44+14),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:12,weight:.regular),.foregroundColor:NSColor.labelColor])
        }
    }
    private func stationRect(_ id:String)->CGRect? {
        if community {guard let i=orderedIDs.firstIndex(of:id) else{return nil};return CGRect(x:0,y:CGFloat(i)*44,width:bounds.width,height:44)}
        guard let s=skin?.stations.first(where:{$0.subscriptionID==id}),let origin=skin?.bounds.origin else{return nil}
        return CGRect(x:s.centre.x-s.diameter/2-origin.x,y:s.centre.y-s.diameter/2-origin.y,width:s.diameter,height:s.diameter)
    }
    private func refreshNodes(){
        var children=[DockInstrumentAXNode](),used=Set<String>()
        func append(_ key:String,_ label:String,_ value:String?,_ help:String,_ rect:CGRect,_ action:DockInstrumentAction) {
            let node=nodes[key] ?? DockInstrumentAXNode(),oldValue=node.accessibilityValue() as? String
            node.setAccessibilityRole(.button);node.setAccessibilityParent(self);node.setAccessibilityEnabled(onAction != nil)
            node.setAccessibilityIdentifier("dock."+key);node.setAccessibilityLabel(label);node.setAccessibilityValue(value);node.setAccessibilityHelp(help)
            node.setAccessibilityFrameInParentSpace(rect);node.press={[weak self,weak node] in guard let self,let node,self.nodes[key] === node,let onAction=self.onAction else{return false};onAction(action);return true}
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
    public override func hitTest(_ point:NSPoint)->NSView? {
        let local=convert(point,from:superview)
        guard !isHidden,bounds.contains(local),!failed else{return nil}
        if community{return self}
        // This tests only this view's painted raster. The containing window's native route is a separate gate.
        guard let image,let bytes=alphaData,CFDataGetLength(bytes)>=image.bytesPerRow*image.height,image.bitsPerPixel==32,image.bitsPerComponent==8 else{return nil}
        let x=min(image.width-1,max(0,Int(local.x*CGFloat(scale)))),y=min(image.height-1,max(0,Int(local.y*CGFloat(scale))))
        let alphaIndex=(image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first) ? 0:3
        guard CFDataGetBytePtr(bytes)![y*image.bytesPerRow+x*4+alphaIndex]>0 else{return nil};return self
    }
    public override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    public override func mouseDown(with event:NSEvent){
        guard !failed else{return}
        let p=convert(event.locationInWindow,from:nil)
        if let skin,!community {
            let global=CGPoint(x:p.x+skin.bounds.minX,y:p.y+skin.bounds.minY)
            for s in skin.stations.reversed(){
                if let id=s.subscriptionID,notices[id] != nil,s.eventRect.contains(global){onAction?(.notice(id));return}
                if let id=s.subscriptionID,let r=stationRect(id),r.contains(p) || (s.showsReadout != false && s.readout.contains(global)) || s.aliasRect?.contains(global)==true{onAction?(.subscription(id));return}
                if s.overflowCount != nil,CGRect(x:s.centre.x-s.diameter/2,y:s.centre.y-s.diameter/2,width:s.diameter,height:s.diameter).contains(global){onAction?(.overflow);return}
            }
        } else if let id=orderedIDs.first(where:{stationRect($0)?.contains(p)==true}){onAction?(.subscription(id))}
    }
}
