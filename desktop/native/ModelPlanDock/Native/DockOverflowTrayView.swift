// SPDX-License-Identifier: MIT
import AppKit
public struct DockOverflowEntry:Equatable,Sendable {
    public let id:String,label:String,value:String,dragHelp:String
    public init(id:String,label:String,value:String,dragHelp:String){self.id=id;self.label=label;self.value=value;self.dragHelp=dragHelp}
}
@MainActor private final class OverflowEntryView:NSView {
    var activate:((DockActionSource)->Bool)?,hover:((Bool)->Void)?,help:(()->Void)?
    var canFocus:(()->Bool)?,focus:(()->Void)?,navigate:((NSEvent)->Bool)?
    private var pressed=false,dragged=false,start=CGPoint.zero,tracking:NSTrackingArea?
    private let text=NSTextField(labelWithString:"")
    init(entry:DockOverflowEntry){super.init(frame:CGRect(x:0,y:0,width:160,height:40));text.frame=bounds.insetBy(dx:8,dy:10);text.autoresizingMask=[.width];text.setAccessibilityElement(false);addSubview(text);configure(entry)}
    func configure(_ entry:DockOverflowEntry){text.stringValue=entry.label+" · "+entry.value;setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityIdentifier("dock.overflow."+entry.id);setAccessibilityLabel(text.stringValue);setAccessibilityHelp(entry.dragHelp);toolTip=nil}
    func retire(){activate=nil;hover=nil;help=nil;canFocus=nil;focus=nil;navigate=nil;nextKeyView=nil;pressed=false;setAccessibilityElement(false);setAccessibilityEnabled(false)}
    override var acceptsFirstResponder:Bool{canFocus?() == true}
    override var canBecomeKeyView:Bool{acceptsFirstResponder && !isHiddenOrHasHiddenAncestor}
    override func becomeFirstResponder()->Bool{guard acceptsFirstResponder else{return false};focus?();return true}
    required init?(coder:NSCoder){fatalError()}
    override var intrinsicContentSize:NSSize{NSSize(width:160,height:40)}
    override func updateTrackingAreas(){if let tracking{removeTrackingArea(tracking)};let next=NSTrackingArea(rect:.zero,options:[.inVisibleRect,.mouseEnteredAndExited,.activeAlways],owner:self,userInfo:nil);tracking=next;addTrackingArea(next);super.updateTrackingAreas()}
    override func mouseEntered(with event:NSEvent){hover?(true)}
    override func mouseExited(with event:NSEvent){hover?(false)}
    override func mouseDown(with event:NSEvent){pressed=true;dragged=false;start=convert(event.locationInWindow,from:nil)}
    override func mouseDragged(with event:NSEvent){let p=convert(event.locationInWindow,from:nil);if pressed,!dragged,hypot(p.x-start.x,p.y-start.y)>5{dragged=true;help?()}}
    override func mouseUp(with event:NSEvent){let p=convert(event.locationInWindow,from:nil),activate=pressed && !dragged && bounds.contains(p);pressed=false;if activate{_ = self.activate?(.pointer)}}
    override func accessibilityPerformPress()->Bool{guard !isHiddenOrHasHiddenAncestor,let activate else{return false};return activate(.accessibility)}
    override func keyDown(with event:NSEvent){
        guard acceptsFirstResponder else{super.keyDown(with:event);return}
        if event.keyCode==48{event.modifierFlags.contains(.shift) ? window?.selectPreviousKeyView(self):window?.selectNextKeyView(self);return}
        if navigate?(event)==true{return}
        if event.modifierFlags.intersection([.option,.control,.command]).isEmpty,(event.keyCode==36 || event.charactersIgnoringModifiers==" "){_ = activate?(.accessibility)}
        else{super.keyDown(with:event)}
    }
    override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
}
/// Complete neutral tray; the official nozzle grid may be provided by the same host/controller contract.
@MainActor public final class DockOverflowTrayView:NSView {
    public var permitsAction:((String,DockActionSource)->Bool)?
    public var onClick:((String)->Void)?{didSet{for row in rows.values{row.setAccessibilityEnabled(onClick != nil)}}}
    public var onHover:((String?)->Void)?,onDragHelp:((String)->Void)?
    public var keyboardNavigationEnabled=false,edge:DockEdge = .right
    public var keyboardTargetID:String?,onOptionMove:((String,Int)->Void)?
    private var ids=Set<String>()
    public override var acceptsFirstResponder:Bool{keyboardNavigationEnabled}
    private let stack=NSStackView();private var generation:UInt64=0
    private var rows=[String:OverflowEntryView](),order=[String]()
    public override init(frame:NSRect){super.init(frame:frame);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=4;stack.frame=bounds;stack.autoresizingMask=[.width,.height];addSubview(stack)}
    required init?(coder:NSCoder){fatalError()}
    public func apply(_ entries:[DockOverflowEntry])throws{
        generation &+= 1;let token=generation
        guard entries.count<=128,Set(entries.map(\.id)).count==entries.count,entries.allSatisfy({!$0.id.isEmpty && [$0.id,$0.label,$0.value,$0.dragHelp].allSatisfy{$0.utf8.count<=2048}}) else{clear();throw DockLogicError.invalidCatalogue}
        let previousOrder=order,focusedID=rows.first(where:{$0.value === window?.firstResponder})?.key
        let previousTarget=focusedID ?? keyboardTargetID
        ids=Set(entries.map(\.id))
        order=entries.map(\.id)
        for id in Array(rows.keys) where !ids.contains(id){if let row=rows.removeValue(forKey:id){row.retire();stack.removeArrangedSubview(row);row.removeFromSuperview()}}
        if let id=previousTarget,!ids.contains(id){
            if keyboardNavigationEnabled,let index=previousOrder.firstIndex(of:id),!order.isEmpty{keyboardTargetID=order[min(index,order.count-1)]}
            else{keyboardTargetID=nil}
        }
        for (index,entry) in entries.enumerated(){
            let v=rows[entry.id] ?? OverflowEntryView(entry:entry);rows[entry.id]=v;v.configure(entry)
            v.setAccessibilityEnabled(onClick != nil)
            v.activate={[weak self] source in guard let self,self.generation==token,self.permitsAction?(entry.id,source) ?? true else{return false};guard self.generation==token,let onClick=self.onClick else{return false};onClick(entry.id);return true}
            v.hover={[weak self] inside in guard let self,self.generation==token else{return};self.onHover?(inside ? entry.id:nil)}
            v.help={[weak self] in guard let self,self.generation==token else{return};self.onDragHelp?(entry.id)}
            v.canFocus={[weak self,weak v] in guard let self,let v else{return false};return self.keyboardNavigationEnabled && self.rows[entry.id] === v && self.onClick != nil}
            v.focus={[weak self] in self?.keyboardTargetID=entry.id}
            v.navigate={[weak self] event in self?.navigate(entry.id,event:event) ?? false}
            if let old=stack.arrangedSubviews.firstIndex(where:{$0 === v}){if old != index{stack.removeArrangedSubview(v);stack.insertArrangedSubview(v,at:index)}}else{stack.insertArrangedSubview(v,at:index)}
        };frame.size=stack.fittingSize
        let ordered=order.compactMap{rows[$0]}
        for (index,row) in ordered.enumerated(){row.nextKeyView=index+1<ordered.count ? ordered[index+1]:nil}
        // Only an already-focused row in this key window may transfer actual keyboard focus.
        // Passive refresh never activates a window or selects a subscription.
        if let focusedID,!ids.contains(focusedID),keyboardNavigationEnabled,window?.isKeyWindow==true{
            window?.makeFirstResponder(keyboardTargetID.flatMap{rows[$0]} ?? self)
        }
    }
    private func navigate(_ id:String,event:NSEvent)->Bool{
        let modifiers=event.modifierFlags.intersection([.option,.control,.command])
        let keys:[UInt16]=edge == .bottom ? [123,124]:[126,125]
        guard let direction=keys.firstIndex(of:event.keyCode) else{return false}
        if modifiers == .option{onOptionMove?(id,direction==0 ? -1:1);return true}
        guard modifiers.isEmpty,let index=order.firstIndex(of:id),!order.isEmpty else{return false}
        let next=order[max(0,min(order.count-1,index+(direction==0 ? -1:1)))];keyboardTargetID=next
        if let view=rows[next]{window?.makeFirstResponder(view)};return true
    }
    public override func keyDown(with event:NSEvent){
        let keys:[UInt16]=edge == .bottom ? [123,124]:[126,125]
        if event.modifierFlags.intersection([.option,.control,.command]) == .option,let id=keyboardTargetID,ids.contains(id),let index=keys.firstIndex(of:event.keyCode){onOptionMove?(id,index==0 ? -1:1);return}
        super.keyDown(with:event)
    }
    private func clear(){ids=[];order=[];keyboardTargetID=nil;for row in rows.values{row.retire();stack.removeArrangedSubview(row);row.removeFromSuperview()};rows.removeAll()}
    public func dispose(){clear();onOptionMove=nil;permitsAction=nil;generation &+= 1;onClick=nil;onHover=nil;onDragHelp=nil}
}
