// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics

public enum DockEdgeError: Error, Equatable { case invalidGeometry, duplicateLayout }
/// Session-resolved identity only; the shared display owner persists durable identity.
public struct DockDisplayArea: Equatable, Sendable {
    public let id:String, frame:CGRect, visibleFrame:CGRect, usableFrame:CGRect
    public init(id:String,frame:CGRect,visibleFrame:CGRect,safeFrame:CGRect? = nil){
        self.id=id;self.frame=frame;self.visibleFrame=visibleFrame
        usableFrame=frame.intersection(visibleFrame).intersection(safeFrame ?? frame)
    }
}
/// Already-scaled registered geometry. Drawing/scale recipes are injected, never inferred from a label.
public struct DockEdgeLayout: Equatable, Sendable {
    public let displayID:String,edge:DockEdge,expandedSize:CGSize,sliverLength:CGFloat,sliverThickness:CGFloat
    /// Registered sliver centre measured from the expanded frame's global minimum along axis.
    public let alongAnchor:CGFloat
    public let hoverRects:[CGRect]
    public let flipped:Bool
    public init(displayID:String,edge:DockEdge,expandedSize:CGSize,sliverLength:CGFloat,sliverThickness:CGFloat,hoverRects:[CGRect],flipped:Bool=true,alongAnchor:CGFloat?=nil){
        self.displayID=displayID;self.edge=edge;self.expandedSize=expandedSize;self.sliverLength=sliverLength
        self.sliverThickness=sliverThickness;self.alongAnchor=alongAnchor ?? (edge == .bottom ? expandedSize.width:expandedSize.height)/2;self.hoverRects=hoverRects;self.flipped=flipped
    }
}
public struct DockEdgePreference: Equatable, Sendable {
    public var displayID:String?,edge:DockEdge,alongFraction:Double
    /// Vertical alongFraction uses global bottom-to-top; horizontal uses left-to-right.
    public init(displayID:String?=nil,edge:DockEdge = .right,alongFraction:Double=0.5){self.displayID=displayID;self.edge=edge;self.alongFraction=alongFraction}
}
public struct DockEdgePlacement: Equatable, Sendable {
    public let displayID:String,edge:DockEdge,alongFraction:Double,frame:CGRect,sliverFrame:CGRect,wakeFrame:CGRect
    public let layout:DockEdgeLayout
    public var preference:DockEdgePreference{.init(displayID:displayID,edge:edge,alongFraction:alongFraction)}
    public var globalHoverRects:[CGRect]{layout.hoverRects.map{Self.globalRect($0,in:frame,flipped:layout.flipped)}}
    public static func globalRect(_ local:CGRect,in frame:CGRect,flipped:Bool)->CGRect{
        CGRect(x:frame.minX+local.minX,y:flipped ? frame.maxY-local.maxY:frame.minY+local.minY,width:local.width,height:local.height)
    }
}
/// One geometry path for normal placement, migration and drag/drop. Never returns a floating/top state.
public enum DockEdgeGeometry {
    public static let allowedEdges:[DockEdge]=[.right,.left,.bottom]
    private static func finite(_ r:CGRect)->Bool{
        [r.minX,r.minY,r.width,r.height].allSatisfy{$0.isFinite} && r.width>0 && r.height>0 && r.width<=100_000 && r.height<=100_000 && abs(r.minX)<=1_000_000 && abs(r.minY)<=1_000_000
    }
    public static func validate(displays:[DockDisplayArea],layouts:[DockEdgeLayout])throws{
        guard displays.count<=256, layouts.count<=768, Set(displays.map(\.id)).count==displays.count,displays.allSatisfy({!$0.id.isEmpty && finite($0.frame) && finite($0.visibleFrame) && finite($0.usableFrame)}) else{throw DockEdgeError.invalidGeometry}
        var keys=Set<String>()
        for p in layouts{
            guard p.edge != .top,!p.displayID.isEmpty,p.expandedSize.width.isFinite,p.expandedSize.height.isFinite,
                p.expandedSize.width>0,p.expandedSize.height>0,p.expandedSize.width<=4096,p.expandedSize.height<=4096,
                p.sliverLength.isFinite,p.sliverLength>0,p.sliverLength<=4096,p.sliverThickness.isFinite,p.sliverThickness>0,p.sliverThickness<=256,
                p.alongAnchor.isFinite,p.alongAnchor>=0,p.alongAnchor<=(p.edge == .bottom ? p.expandedSize.width:p.expandedSize.height),
                p.hoverRects.count<=4096,p.hoverRects.allSatisfy(finite) else{throw DockEdgeError.invalidGeometry}
            guard keys.insert(p.displayID+"/"+String(describing:p.edge)).inserted else{throw DockEdgeError.duplicateLayout}
        }
    }
    /// Exposed usable along-intervals, subtracting every adjoining/overlapping display at the physical edge.
    public static func exposedIntervals(on display:DockDisplayArea,edge:DockEdge,displays:[DockDisplayArea],cornerClearance:CGFloat=24)->[ClosedRange<CGFloat>]{
        guard edge != .top,cornerClearance.isFinite,cornerClearance>=0,finite(display.frame),finite(display.usableFrame),displays.allSatisfy({finite($0.frame)}) else{return []}
        let u=display.usableFrame,f=display.frame,vertical=edge != .bottom
        let lower=(vertical ? u.minY:u.minX)+cornerClearance,upper=(vertical ? u.maxY:u.maxX)-cornerClearance
        guard lower<upper else{return []};var intervals=[lower...upper]
        for other in displays where other.id != display.id{
            let n=other.frame,shared:Bool
            switch edge{
            case .left:shared=n.minX<f.minX && n.maxX>=f.minX
            case .right:shared=n.maxX>f.maxX && n.minX<=f.maxX
            case .bottom:shared=n.minY<f.minY && n.maxY>=f.minY
            case .top:shared=false
            }
            guard shared else{continue}
            let a=vertical ? n.minY:n.minX,b=vertical ? n.maxY:n.maxX
            intervals=intervals.flatMap{r->[ClosedRange<CGFloat>] in
                if b<=r.lowerBound || a>=r.upperBound{return [r]}
                var next=[ClosedRange<CGFloat>]()
                if a>r.lowerBound{next.append(r.lowerBound...min(a,r.upperBound))}
                if b<r.upperBound{next.append(max(b,r.lowerBound)...r.upperBound)}
                return next
            }
        };return intervals
    }
    private static func reserved(_ edge:DockEdge,on d:DockDisplayArea)->Bool{
        switch edge{
        case .left:return d.visibleFrame.minX>d.frame.minX
        case .right:return d.visibleFrame.maxX<d.frame.maxX
        case .bottom:return d.visibleFrame.minY>d.frame.minY
        case .top:return true
        }
    }
    private static func candidate(_ p:DockEdgeLayout,on d:DockDisplayArea,displays:[DockDisplayArea],fraction:Double,point:CGPoint?,corner:CGFloat,wake:CGFloat)->DockEdgePlacement?{
        let u=d.usableFrame,vertical=p.edge != .bottom
        let along=vertical ? p.expandedSize.height:p.expandedSize.width
        let cross=vertical ? p.expandedSize.width:p.expandedSize.height
        let before=max(p.alongAnchor,p.sliverLength/2),after=max(along-p.alongAnchor,p.sliverLength/2)
        let total=before+after,span=vertical ? u.height:u.width
        guard cross<=(vertical ? u.width:u.height),p.sliverThickness<=cross,wake<=(vertical ? u.width:u.height),p.sliverLength<=span else{return nil}
        let intervals=exposedIntervals(on:d,edge:p.edge,displays:displays,cornerClearance:corner).filter{$0.upperBound-$0.lowerBound>=total}
        guard !intervals.isEmpty else{return nil}
        let desired=point.map{vertical ? $0.y:$0.x} ?? ((vertical ? u.minY:u.minX)+CGFloat(max(0,min(1,fraction)))*span)
        let centres=intervals.map{r in max(r.lowerBound+before,min(r.upperBound-after,desired))}
        let centre=centres.min{abs($0-desired)<abs($1-desired)}!
        let frame:CGRect,sliver:CGRect,wakeRect:CGRect
        switch p.edge{
        case .left:
            frame=CGRect(x:u.minX,y:centre-p.alongAnchor,width:cross,height:along)
            sliver=CGRect(x:u.minX,y:centre-p.sliverLength/2,width:p.sliverThickness,height:p.sliverLength)
            wakeRect=CGRect(x:u.minX,y:sliver.minY,width:wake,height:sliver.height)
        case .right:
            frame=CGRect(x:u.maxX-cross,y:centre-p.alongAnchor,width:cross,height:along)
            sliver=CGRect(x:u.maxX-p.sliverThickness,y:centre-p.sliverLength/2,width:p.sliverThickness,height:p.sliverLength)
            wakeRect=CGRect(x:u.maxX-wake,y:sliver.minY,width:wake,height:sliver.height)
        case .bottom:
            frame=CGRect(x:centre-p.alongAnchor,y:u.minY,width:along,height:cross)
            sliver=CGRect(x:centre-p.sliverLength/2,y:u.minY,width:p.sliverLength,height:p.sliverThickness)
            wakeRect=CGRect(x:sliver.minX,y:u.minY,width:sliver.width,height:wake)
        case .top:return nil
        }
        let actual=Double((centre-(vertical ? u.minY:u.minX))/span)
        return .init(displayID:d.id,edge:p.edge,alongFraction:actual,frame:frame,sliverFrame:sliver,wakeFrame:wakeRect,layout:p)
    }
    /// Retention rectangles include boundaries, but an exact adjoining-display endpoint must not wake.
    public static func canWake(at point:CGPoint,placement:DockEdgePlacement,displays:[DockDisplayArea])->Bool{
        let r=placement.wakeFrame
        guard point.x.isFinite,point.y.isFinite,point.x>=r.minX,point.x<=r.maxX,point.y>=r.minY,point.y<=r.maxY,
              let d=displays.first(where:{$0.id==placement.displayID}) else{return false}
        for other in displays where other.id != d.id{
            let f=d.frame,n=other.frame
            switch placement.edge{
            case .left:if n.minX<f.minX && n.maxX>=f.minX && point.y>=n.minY && point.y<=n.maxY{return false}
            case .right:if n.maxX>f.maxX && n.minX<=f.maxX && point.y>=n.minY && point.y<=n.maxY{return false}
            case .bottom:if n.minY<f.minY && n.maxY>=f.minY && point.x>=n.minX && point.x<=n.maxX{return false}
            case .top:return false
            }
        };return true
    }
    public static func resolve(preference:DockEdgePreference,displays:[DockDisplayArea],layouts:[DockEdgeLayout],pointer:CGPoint?,primaryID:String?,nearest:Bool=false,cornerClearance:CGFloat=24,wakeDepth:CGFloat=16)throws->DockEdgePlacement?{
        try validate(displays:displays,layouts:layouts)
        guard preference.alongFraction.isFinite,cornerClearance.isFinite,cornerClearance>=0,wakeDepth.isFinite,wakeDepth>0,
              pointer.map({$0.x.isFinite && $0.y.isFinite}) ?? true else{throw DockEdgeError.invalidGeometry}
        let sorted=displays.sorted{$0.id<$1.id}
        let preferred=sorted.first{$0.id==preference.displayID}
        let chosen=preferred ?? pointer.flatMap{p in sorted.first{$0.usableFrame.contains(p)}} ?? sorted.first{$0.id==primaryID} ?? sorted.first
        var candidates=[DockEdgePlacement]()
        for d in sorted where nearest || d.id==chosen?.id{
            for edge in allowedEdges{
                let migrationPoint=preference.edge == .top ? CGPoint(x:d.usableFrame.minX+CGFloat(max(0,min(1,preference.alongFraction)))*d.usableFrame.width,y:d.usableFrame.maxY):nil
                guard let layout=layouts.first(where:{$0.displayID==d.id && $0.edge==edge}),let c=candidate(layout,on:d,displays:sorted,fraction:preference.alongFraction,point:nearest ? pointer:migrationPoint,corner:cornerClearance,wake:wakeDepth) else{continue}
                candidates.append(c)
            }
        }
        // If the preferred display has no usable exposed/registered edge, safely fall back to another display.
        if candidates.isEmpty && !nearest,chosen != nil{
            return try resolve(preference:.init(displayID:nil,edge:preference.edge,alongFraction:preference.alongFraction),displays:sorted,layouts:layouts,pointer:pointer,primaryID:primaryID,nearest:true,cornerClearance:cornerClearance,wakeDepth:wakeDepth)
        }
        let alternatives=candidates.filter{c in !reserved(c.edge,on:sorted.first{$0.id==c.displayID}!)}
        if !alternatives.isEmpty{candidates=alternatives}
        if !nearest,let exact=candidates.first(where:{$0.edge==preference.edge}){return exact}
        guard let target=pointer ?? chosen.map({CGPoint(x:$0.usableFrame.midX,y:preference.edge == .top ? $0.usableFrame.maxY:$0.usableFrame.midY)}) else{return candidates.first}
        func distance(_ c:DockEdgePlacement)->CGFloat{
            let x=max(c.sliverFrame.minX,min(c.sliverFrame.maxX,target.x)),y=max(c.sliverFrame.minY,min(c.sliverFrame.maxY,target.y))
            return hypot(target.x-x,target.y-y)
        }
        return candidates.enumerated().min{a,b in let x=distance(a.element),y=distance(b.element);return x==y ? a.offset<b.offset:x<y}?.element
    }
}
