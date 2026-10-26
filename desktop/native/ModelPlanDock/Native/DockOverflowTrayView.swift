// SPDX-License-Identifier: MIT
import AppKit
public struct DockOverflowEntry:Equatable,Sendable {
    public let id:String,label:String,value:String,dragHelp:String
    public init(id:String,label:String,value:String,dragHelp:String){self.id=id;self.label=label;self.value=value;self.dragHelp=dragHelp}
}
@MainActor private final class OverflowEntryView:NSView {
    var activate:((DockActionSource)->Bool)?,hover:((Bool)->Void)?,help:(()->Void)?
    private var pressed=false,dragged=false,start=CGPoint.zero,tracking:NSTrackingArea?
    init(entry:DockOverflowEntry){super.init(frame:CGRect(x:0,y:0,width:160,height:40));let text=NSTextField(labelWithString:entry.label+" · "+entry.value);text.frame=bounds.insetBy(dx:8,dy:10);text.autoresizingMask=[.width];addSubview(text);setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityLabel(text.stringValue);setAccessibilityHelp(entry.dragHelp);toolTip=nil}
    required init?(coder:NSCoder){fatalError()}
    override var intrinsicContentSize:NSSize{NSSize(width:160,height:40)}
    override func updateTrackingAreas(){if let tracking{removeTrackingArea(tracking)};let next=NSTrackingArea(rect:.zero,options:[.inVisibleRect,.mouseEnteredAndExited,.activeAlways],owner:self,userInfo:nil);tracking=next;addTrackingArea(next);super.updateTrackingAreas()}
    override func mouseEntered(with event:NSEvent){hover?(true)}
    override func mouseExited(with event:NSEvent){hover?(false)}
    override func mouseDown(with event:NSEvent){pressed=true;dragged=false;start=convert(event.locationInWindow,from:nil)}
    override func mouseDragged(with event:NSEvent){let p=convert(event.locationInWindow,from:nil);if pressed,!dragged,hypot(p.x-start.x,p.y-start.y)>5{dragged=true;help?()}}
    override func mouseUp(with event:NSEvent){let p=convert(event.locationInWindow,from:nil),activate=pressed && !dragged && bounds.contains(p);pressed=false;if activate{_ = self.activate?(.pointer)}}
    override func accessibilityPerformPress()->Bool{guard !isHiddenOrHasHiddenAncestor,let activate else{return false};return activate(.accessibility)}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
}
/// Complete neutral tray; the official nozzle grid may be provided by the same host/controller contract.
@MainActor public final class DockOverflowTrayView:NSView {
    public var permitsAction:((String,DockActionSource)->Bool)?
    public var onClick:((String)->Void)?,onHover:((String?)->Void)?,onDragHelp:((String)->Void)?
    private let stack=NSStackView();private var generation:UInt64=0
    public override init(frame:NSRect){super.init(frame:frame);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=4;stack.frame=bounds;stack.autoresizingMask=[.width,.height];addSubview(stack)}
    required init?(coder:NSCoder){fatalError()}
    public func apply(_ entries:[DockOverflowEntry])throws{
        generation &+= 1;let token=generation
        for v in stack.arrangedSubviews{stack.removeArrangedSubview(v);v.removeFromSuperview()}
        guard entries.count<=128,Set(entries.map(\.id)).count==entries.count,entries.allSatisfy({!$0.id.isEmpty && [$0.id,$0.label,$0.value,$0.dragHelp].allSatisfy{$0.utf8.count<=2048}}) else{throw DockLogicError.invalidCatalogue}
        for entry in entries{
            let v=OverflowEntryView(entry:entry)
            v.activate={[weak self] source in guard let self,self.generation==token,self.permitsAction?(entry.id,source) ?? true else{return false};guard self.generation==token,let onClick=self.onClick else{return false};onClick(entry.id);return true}
            v.hover={[weak self] inside in guard let self,self.generation==token else{return};self.onHover?(inside ? entry.id:nil)}
            v.help={[weak self] in guard let self,self.generation==token else{return};self.onDragHelp?(entry.id)}
            stack.addArrangedSubview(v)
        };frame.size=stack.fittingSize
    }
    public func dispose(){generation &+= 1;onClick=nil;onHover=nil;onDragHelp=nil;for v in stack.arrangedSubviews{stack.removeArrangedSubview(v);v.removeFromSuperview()}}
}
