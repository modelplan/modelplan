// SPDX-License-Identifier: MIT
import AppKit

@MainActor public protocol DockNozzleEventHandling:AnyObject {
    var hasCapture:Bool{get}
    func beginNozzle(id:String,local:CGPoint)->Bool
    func moveNozzle(local:CGPoint)
    func endNozzle(global:CGPoint,currentID:String?)
    func cancelNozzle()
    func hoverNozzle(_ id:String?)
    func optionArrow(id:String,keyCode:UInt16)->Bool
}
@MainActor public final class DockNozzleEvents:DockNozzleEventHandling {
    private let controller:DockInteractionController,edge:()->DockEdge
    public var onHover:((String?)->Void)?
    public var insideMainDrop:(CGPoint)->Bool={_ in false}
    public init(controller:DockInteractionController,edge:@escaping ()->DockEdge){self.controller=controller;self.edge=edge}
    public func install(on view:DockInstrumentView){
        view.nozzleEventDelegate=self
        view.onAction={[weak self] action in guard let self else{return};switch action{
            case .subscription(let id),.notice(let id):self.controller.click(id)
            case .overflow:self.controller.toggleOverflow()
        }}
    }
    public var hasCapture:Bool{controller.hasCapture}
    public func beginNozzle(id:String,local:CGPoint)->Bool{let ok=controller.beginNozzle(id:id,along:edge() == .bottom ? local.x:local.y);if ok{capturedID=id};return ok}
    public func moveNozzle(local:CGPoint){controller.moveNozzle(along:edge() == .bottom ? local.x:local.y)}
    public func endNozzle(global:CGPoint,currentID:String?){controller.endNozzle(insideMain:insideMainDrop(global),overSameSource:currentID != nil && currentID==capturedID);capturedID=nil}
    private var capturedID:String?
    public func cancelNozzle(){capturedID=nil;controller.cancelNozzle()}
    public func hoverNozzle(_ id:String?){onHover?(id);controller.refresh()}
    public func optionArrow(id:String,keyCode:UInt16)->Bool{
        let keys:[UInt16]=edge() == .bottom ? [123,124]:[126,125]
        guard let index=keys.firstIndex(of:keyCode) else{return false};controller.moveByKeyboard(id:id,delta:index==0 ? -1:1);return true
    }
}
