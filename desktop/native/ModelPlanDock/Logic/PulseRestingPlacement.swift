// Copyright (c) 2026 qunqin24. Licensed under the Apache License, Version 2.0.
// ModelPlan adaptation: port saved-display and visible-frame placement from Pulse
// FloatingPanelController and PanelPlacement. Use registered rail and strip geometry
// with ModelPlan's edge-only and corner-clearance decisions.
import Foundation
import CoreGraphics

public enum PulseRestingPlacement {
    public static func display(preference: DockEdgePreference, displays: [DockDisplayArea],
                               pointer: CGPoint?, primaryID: String?) -> DockDisplayArea? {
        if let id = preference.displayID, let display = displays.first(where: { $0.id == id }) { return display }
        if preference.displayID == nil, let pointer, let display = displays.first(where: { $0.frame.contains(pointer) }) {
            return display
        }
        return displays.first { $0.id == primaryID } ?? displays.first
    }

    public static func frameRoom(_ available: CGRect, edge: DockEdge, corner: CGFloat = 24) -> CGRect {
        edge.isHorizontal ? available.insetBy(dx: corner, dy: 0) : available.insetBy(dx: 0, dy: corner)
    }

    static func resolve(preference: DockEdgePreference, display: DockDisplayArea?, layouts: [DockEdgeLayout],
                        corner: CGFloat, wake: CGFloat) -> DockEdgePlacement? {
        guard let display else { return nil }
        let visible = display.usableFrame
        let fraction = max(0, min(1, preference.alongFraction))
        let edge = preference.edge
        let room = frameRoom(visible, edge: edge, corner: corner)
        guard !room.isEmpty,
              let layout = layouts.first(where: { $0.displayID == display.id && $0.edge == edge }) else { return nil }
        let interval = edge.isHorizontal ? room.minX...room.maxX : room.minY...room.maxY
        return candidate(layout, on: display, fraction: fraction, point: nil, wake: wake, intervals: [interval])
    }

    /// AppKit can constrain the first order-in. Keep the granted size and reapply
    /// the edge and rail anchor within the same available rectangle.
    public static func replaceGranted(_ granted: CGRect, requested: CGRect, edge: DockEdge,
                                      visible: CGRect) -> CGRect? {
        let room = frameRoom(visible, edge: edge)
        guard !room.isEmpty, !granted.isEmpty, granted.width <= room.width, granted.height <= room.height else { return nil }
        let x = max(room.minX, min(room.maxX - granted.width, requested.midX - granted.width / 2))
        let y = max(room.minY, min(room.maxY - granted.height, requested.midY - granted.height / 2))
        let origin: CGPoint
        switch edge {
        case .left: origin = .init(x: room.minX, y: y)
        case .right: origin = .init(x: room.maxX - granted.width, y: y)
        case .bottom: origin = .init(x: x, y: room.minY)
        case .top: origin = .init(x: x, y: room.maxY - granted.height)
        }
        return CGRect(origin: origin, size: granted.size)
    }

    private static func candidate(_ p:DockEdgeLayout,on d:DockDisplayArea,fraction:Double,point:CGPoint?,wake:CGFloat,intervals:[ClosedRange<CGFloat>])->DockEdgePlacement?{
        let u=d.usableFrame,vertical = !p.edge.isHorizontal
        let along=vertical ? p.expandedSize.height:p.expandedSize.width
        let cross=vertical ? p.expandedSize.width:p.expandedSize.height
        let before=max(p.alongAnchor,p.sliverLength/2),after=max(along-p.alongAnchor,p.sliverLength/2)
        let total=before+after,span=vertical ? u.height:u.width
        guard cross<=(vertical ? u.width:u.height),p.sliverThickness<=cross,wake<=(vertical ? u.width:u.height),p.sliverLength<=span else{return nil}
        let intervals = intervals.filter { $0.upperBound - $0.lowerBound >= total }
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
        case .top:
            frame=CGRect(x:centre-p.alongAnchor,y:u.maxY-cross,width:along,height:cross)
            sliver=CGRect(x:centre-p.sliverLength/2,y:u.maxY-p.sliverThickness,width:p.sliverLength,height:p.sliverThickness)
            wakeRect=CGRect(x:sliver.minX,y:u.maxY-wake,width:sliver.width,height:wake)
        }
        let actual=Double((centre-(vertical ? u.minY:u.minX))/span)
        return .init(displayID:d.id,edge:p.edge,alongFraction:actual,frame:frame,sliverFrame:sliver,wakeFrame:wakeRect,layout:p)
    }
}
