// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics

public enum DockCardVisibility:Equatable,Sendable {
    case hidden,hover(String)
    public var subscriptionID:String?{switch self{case .hidden:return nil;case .hover(let id):return id}}
}
/// Only a key window with a real descendant control focused protects a card.
public enum DockCardFocus {
    public static func protectsCard(isKeyWindow:Bool,isDescendant:Bool,isFocusableControl:Bool,isCurrent:Bool = true)->Bool {
        isKeyWindow && isDescendant && isFocusableControl && isCurrent
    }
}
/// G3-120 / G3-114: the ring card's timing model, Pulse behaviour in our own code (qunqin24/Pulse 7668384
/// `FloatingUsagePanelContent.select/pointerMoved/deselect` and `.onChange(of: placement.isDragging)`,
/// `PanelPointerWatcher.interval`).
/// - Open: the pointer arriving on a ring opens its card at once. There is no ring dwell in Pulse (its 250 ms
///   `PanelIntent.notchDwell` is the collapsed notch housing's, not a ring's). The host names the ring from the
///   pointer sample, so an arrival whose pointer has already gone opens nothing (Pulse `select`: pointer read now).
/// - Switch: with a card open, reaching another ring shows that ring's card at once. One card at a time.
/// - Hold: the card's own ring, the card, and the band between them (`insideShared`). The rest of the
///   widget body does not hold a card open.
/// - Close: the first pointer sample off the hold arms `leaveSample` (150 ms, Pulse's sampler period); if no
///   sample in that window is back on the hold, the card closes. A press outside the hold closes at once.
/// - Carry: a widget carry (ring or body) closes the card on its first moved frame and nothing opens while it
///   is held (Pulse FUC:204-206, `select` refuses while dragging). The ring under the carried pointer is
///   remembered, so the drop alone reopens nothing; arriving on a ring afterwards opens as usual.
/// - Never closed by the leave sample: an open widget menu.
public struct DockCardInteraction:Sendable {
    public static let leaveSample:TimeInterval=0.150
    public private(set) var visibility:DockCardVisibility = .hidden
    public private(set) var nextDeadline:TimeInterval?
    private var hovered:String?,leaveAt:TimeInterval?,lastTime:TimeInterval?
    private var catalogue=Set<String>()
    public init(){}
    public mutating func step(catalogue:[String],hoveredID:String?,insideShared:Bool?,parentOwnsHide:Bool,parentExpanded:Bool,menuActuallyOpen:Bool,pressedOutside:Bool=false,carrying:Bool=false,at now:TimeInterval)throws{
        try time(now)
        guard !catalogue.contains(""),Set(catalogue).count==catalogue.count else{throw DockLogicError.invalidCatalogue}
        self.catalogue=Set(catalogue)
        if let current=visibility.subscriptionID,!self.catalogue.contains(current){dismiss()}
        let hover=parentExpanded ? hoveredID.flatMap{self.catalogue.contains($0) ? $0:nil}:nil
        if carrying{
            // Pulse: a drag start deselects, and nothing selects while dragging.
            hovered=hover;visibility = .hidden;leaveAt=nil;nextDeadline=nil;return
        }
        if hover != hovered{
            hovered=hover
            if let hover{visibility = .hover(hover);leaveAt=nil}
        }
        if !parentExpanded{visibility = .hidden}
        // A press outside the hold is an outside click: close now (G3-120).
        if pressedOutside,insideShared == false,!menuActuallyOpen,visibility != .hidden{
            visibility = .hidden;leaveAt=nil;hovered=nil
        }
        // The first outside sample arms the leave sample; renewed inside evidence cancels it.
        if visibility == .hidden || insideShared != false || menuActuallyOpen{leaveAt=nil}
        else{
            if leaveAt==nil{leaveAt=now+Self.leaveSample}
            if now>=leaveAt!{visibility = .hidden;leaveAt=nil;hovered=nil}
        }
        nextDeadline=leaveAt
    }
    public mutating func dismiss(){visibility = .hidden;leaveAt=nil;nextDeadline=nil}
    public mutating func suspend(){
        visibility = .hidden
        leaveAt=nil;nextDeadline=nil;hovered=nil
    }
    private mutating func time(_ now:TimeInterval)throws{
        guard now.isFinite,now>=0,lastTime.map({now >= $0}) ?? true else{throw DockLogicError.invalidTime};lastTime=now
    }
}
public enum DockCardPlacement {
    public static func frame(anchor:CGRect,size:CGSize,edge:DockEdge,usable:CGRect,gap:CGFloat)throws->CGRect?{
        guard [anchor.minX,anchor.minY,anchor.width,anchor.height,size.width,size.height,usable.minX,usable.minY,usable.width,usable.height,gap].allSatisfy({$0.isFinite}),size.width>0,size.height>0,gap>=0 else{throw DockEdgeError.invalidGeometry}
        guard size.width<=usable.width,size.height<=usable.height else{return nil}
        let x:CGFloat,y:CGFloat
        switch edge{
        case .left:x=anchor.maxX+gap;y=anchor.midY-size.height/2
        case .right:x=anchor.minX-gap-size.width;y=anchor.midY-size.height/2
        case .bottom:x=anchor.midX-size.width/2;y=anchor.maxY+gap
        case .top:x=anchor.midX-size.width/2;y=anchor.minY-gap-size.height
        }
        return CGRect(x:max(usable.minX,min(usable.maxX-size.width,x)),y:max(usable.minY,min(usable.maxY-size.height,y)),width:size.width,height:size.height)
    }
}
