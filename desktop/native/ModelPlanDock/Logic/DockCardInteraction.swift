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
/// The card keeps its own bounded leave grace while sharing the widget/card corridor.
public struct DockCardInteraction:Sendable {
    public static let entryDwell:TimeInterval=0.250,independentLeaveGrace:TimeInterval=0.250
    public private(set) var visibility:DockCardVisibility = .hidden
    public private(set) var nextDeadline:TimeInterval?
    private var hovered:String?,pending:String?,enterAt:TimeInterval?,leaveAt:TimeInterval?,lastTime:TimeInterval?
    private var catalogue=Set<String>()
    public init(){}
    public mutating func step(catalogue:[String],hoveredID:String?,insideShared:Bool?,parentOwnsHide:Bool,parentExpanded:Bool,menuActuallyOpen:Bool,at now:TimeInterval)throws{
        try time(now)
        guard !catalogue.contains(""),Set(catalogue).count==catalogue.count else{throw DockLogicError.invalidCatalogue}
        self.catalogue=Set(catalogue)
        if let current=visibility.subscriptionID,!self.catalogue.contains(current){dismiss()}
        let hover=parentExpanded ? hoveredID.flatMap{self.catalogue.contains($0) ? $0:nil}:nil
        if hover != hovered{
            hovered=hover;pending=nil;enterAt=nil
            if let hover,parentExpanded{
                if visibility.subscriptionID != nil{visibility = .hover(hover)}
                else{pending=hover;enterAt=now+Self.entryDwell}
            }
        }
        if !parentExpanded{pending=nil;enterAt=nil;visibility = .hidden}
        if let pending,let enterAt,now>=enterAt,parentExpanded{
            visibility = .hover(pending);self.pending=nil;self.enterAt=nil
        }
        // A single outside sample starts the leave grace; renewed inside evidence cancels it.
        if visibility == .hidden || insideShared != false || menuActuallyOpen{leaveAt=nil}
        else{
            if leaveAt==nil{leaveAt=now+Self.independentLeaveGrace}
            if now>=leaveAt!{visibility = .hidden;leaveAt=nil;hovered=nil}
        }
        nextDeadline=[enterAt,leaveAt].compactMap{$0}.min()
    }
    public mutating func dismiss(){visibility = .hidden;pending=nil;enterAt=nil;leaveAt=nil;nextDeadline=nil}
    public mutating func suspend(){
        visibility = .hidden
        pending=nil;enterAt=nil;leaveAt=nil;nextDeadline=nil;hovered=nil
    }
    private mutating func time(_ now:TimeInterval)throws{
        guard now.isFinite,now>=0,lastTime.map({now >= $0}) ?? true else{throw DockLogicError.invalidTime};lastTime=now
    }
}
public enum DockCardPlacement {
    public static func frame(anchor:CGRect,size:CGSize,edge:DockEdge,usable:CGRect,gap:CGFloat)throws->CGRect?{
        guard [anchor.minX,anchor.minY,anchor.width,anchor.height,size.width,size.height,usable.minX,usable.minY,usable.width,usable.height,gap].allSatisfy({$0.isFinite}),size.width>0,size.height>0,gap>=0 else{throw DockEdgeError.invalidGeometry}
        guard edge != .top,size.width<=usable.width,size.height<=usable.height else{return nil}
        let x:CGFloat,y:CGFloat
        switch edge{
        case .left:x=anchor.maxX+gap;y=anchor.midY-size.height/2
        case .right:x=anchor.minX-gap-size.width;y=anchor.midY-size.height/2
        case .bottom:x=anchor.midX-size.width/2;y=anchor.maxY+gap
        case .top:return nil
        }
        return CGRect(x:max(usable.minX,min(usable.maxX-size.width,x)),y:max(usable.minY,min(usable.maxY-size.height,y)),width:size.width,height:size.height)
    }
}
