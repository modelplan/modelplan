// SPDX-License-Identifier: MIT
import AppKit

/// The appearance owner supplies its painted body/grips and explicitly excludes every control/ignition.
@MainActor public struct DockBackgroundDragRegions {
    public let body:CGPath,grips:[CGPath],excludedControls:[CGRect]
    private let bodyHitTest: ((CGPoint) -> Bool)?
    public init(body:CGPath,grips:[CGPath]=[],excludedControls:[CGRect]){
        self.init(body:body,grips:grips,excludedControls:excludedControls,bodyHitTest:nil)
    }
    /// A raster body qualifies its bounding path with its live alpha hit-test.
    init(body:CGPath,grips:[CGPath]=[],excludedControls:[CGRect],bodyHitTest:((CGPoint)->Bool)?){
        self.body=body;self.grips=grips;self.excludedControls=excludedControls;self.bodyHitTest=bodyHitTest
    }
    public func contains(_ local:CGPoint)->Bool{
        guard local.x.isFinite,local.y.isFinite,!excludedControls.contains(where:{$0.contains(local)}) else{return false}
        return (body.contains(local) && (bodyHitTest?(local) ?? true)) || grips.contains{$0.contains(local)}
    }
}
@MainActor public protocol DockBackgroundDragHandling:AnyObject {
    var isBackgroundMoving:Bool{get}
    func backgroundCanDrag(local:CGPoint)->Bool
    func beginBackgroundMove(local:CGPoint,global:CGPoint)->Bool
    func updateBackgroundMove(global:CGPoint)
    func endBackgroundMove(global:CGPoint)
    func cancelBackgroundMove()
}
public enum DockActionSource:Sendable {case pointer,accessibility}
/// Sampling only: no display identity is persisted, NSScreen.main is not used as a preference.
@MainActor public enum DockNativeInputs {
    public static func displays()->[DockDisplayArea]{NSScreen.screens.compactMap{screen in
        guard let number=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else{return nil}
        return DockDisplayArea(id:number.stringValue,frame:screen.frame,visibleFrame:screen.visibleFrame)
    }}
    public static var pointer:CGPoint{NSEvent.mouseLocation}
    public static var mouseButtonDown:Bool{NSEvent.pressedMouseButtons != 0}
}
