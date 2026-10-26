// SPDX-License-Identifier: MIT
import AppKit

public struct DockInteractionEnvironment:Sendable {
    public var catalogue:[String],preferences:DockSubscriptionPreferences,targets:[DockReorderTarget],overflowIDs:Set<String>,bindingRevision:UInt64
    public var hoveredID:String?,insideShared:Bool?,parentOwnsHide:Bool,parentExpanded:Bool,menuActuallyOpen:Bool,active:Bool,reducedMotion:Bool
    public var edge:DockEdge,contents:[String:DockCardContent]
    public init(catalogue:[String],preferences:DockSubscriptionPreferences,targets:[DockReorderTarget],overflowIDs:Set<String>=[],bindingRevision:UInt64=0,hoveredID:String?=nil,insideShared:Bool?=nil,parentOwnsHide:Bool=true,parentExpanded:Bool=true,menuActuallyOpen:Bool=false,active:Bool=true,reducedMotion:Bool=false,edge:DockEdge = .right,contents:[String:DockCardContent]=[:]){
        self.catalogue=catalogue;self.preferences=preferences;self.targets=targets;self.overflowIDs=overflowIDs;self.bindingRevision=bindingRevision
        self.hoveredID=hoveredID;self.insideShared=insideShared;self.parentOwnsHide=parentOwnsHide;self.parentExpanded=parentExpanded;self.menuActuallyOpen=menuActuallyOpen;self.active=active;self.reducedMotion=reducedMotion;self.edge=edge;self.contents=contents
    }
}
public struct DockInteractionPresentation:Equatable,Sendable {
    public let card:DockCardVisibility,content:DockCardContent?,reorder:DockReorderPreview?,overflowIDs:[String]
}
@MainActor public final class DockInteractionController {
    public private(set) var presentation:DockInteractionPresentation?
    public var onPresent:((DockInteractionPresentation)->Void)?,onOrderRequest:((DockOrderRequest)->Void)?,onOrderAnnouncement:((String,Int,Int)->Void)?
    public var onOverflowDragHelp:((String)->Void)?,onFailure:((Error)->Void)?
    public var canPreviewOrder:([String])->Bool={_ in true}
    private var cards=DockCardInteraction(),gesture=DockNozzleInteraction(),overflowOpen=false,gestureRevision:UInt64?
    private let clock:()->TimeInterval,read:()->DockInteractionEnvironment,scheduler:any DockEdgeScheduling
    private var running=false,refreshing=false,generation:UInt64=0
    private var pendingOrders=[UUID:(DockOrderRequest,Bool)]()
    public init(clock:@escaping ()->TimeInterval,scheduler:any DockEdgeScheduling,read:@escaping ()->DockInteractionEnvironment){self.clock=clock;self.scheduler=scheduler;self.read=read}
    public var cardPinned:Bool{cards.visibility.isPinned}
    public var hasCapture:Bool{gesture.source != nil}
    public func start(){guard !running else{return};running=true;refresh()}
    public func stop(preservingPin:Bool=true){
        running=false;generation &+= 1;scheduler.cancel();gesture.cancel();gestureRevision=nil;cards.suspend(preservingPin:preservingPin);overflowOpen=false;pendingOrders=[:]
        publish(.init(card:.hidden,content:nil,reorder:nil,overflowIDs:[]))
    }
    public func refresh(){
        guard running,!refreshing else{return};refreshing=true;defer{refreshing=false}
        generation &+= 1;let token=generation;scheduler.cancel()
        do{
            let env=read();guard running,generation==token else{return}
            guard env.active else{stop();return}
            if let revision=gestureRevision,revision != env.bindingRevision || !gesture.matches(catalogue:env.catalogue,preferences:env.preferences){gesture.cancel();gestureRevision=nil}
            try cards.step(catalogue:env.catalogue,hoveredID:gesture.preview == nil ? env.hoveredID:nil,insideShared:env.insideShared,parentOwnsHide:env.parentOwnsHide,parentExpanded:env.parentExpanded,menuActuallyOpen:env.menuActuallyOpen,at:clock())
            if !env.parentExpanded{gesture.cancel();gestureRevision=nil;overflowOpen=false}
            let id=cards.visibility.subscriptionID,content=id.flatMap{env.contents[$0]}
            if let content{guard content.subscriptionID==id else{throw DockLogicError.invalidCatalogue};try content.validate()}
            publish(.init(card:cards.visibility,content:content,reorder:gesture.preview,overflowIDs:overflowOpen ? try env.preferences.orderedIDs(in:env.catalogue).filter{env.overflowIDs.contains($0)}:[]))
            guard running,generation==token else{return}
            if let due=cards.nextDeadline{scheduler.arm(at:due){[weak self] in guard let self,self.running,self.generation==token else{return};self.refresh()}}
        }catch{stop();onFailure?(error)}
    }
    public func click(_ id:String){
        guard running else{return}
        do{let token=generation,env=read();guard running,generation==token,env.active,env.parentExpanded,env.catalogue.contains(id) else{return};try cards.step(catalogue:env.catalogue,hoveredID:env.hoveredID,insideShared:env.insideShared,parentOwnsHide:env.parentOwnsHide,parentExpanded:env.parentExpanded,menuActuallyOpen:env.menuActuallyOpen,at:clock());try cards.click(id,at:clock());refresh()}catch{stop();onFailure?(error)}
    }
    public func dismissCard(){cards.dismiss();refresh()}
    public func toggleOverflow(){overflowOpen.toggle();refresh()}
    public func beginNozzle(id:String,along:Double)->Bool{
        guard running else{return false}
        do{let token=generation,env=read();guard running,generation==token,env.active,env.parentExpanded else{return false};try gesture.begin(id:id,along:along,overflow:env.overflowIDs.contains(id),targets:env.targets,catalogue:env.catalogue,preferences:env.preferences);gestureRevision=env.bindingRevision;return true}catch{gesture.cancel();onFailure?(error);return false}
    }
    public func moveNozzle(along:Double){
        guard running,hasCapture else{return}
        do{
            let token=generation,env=read();guard running,generation==token,env.active,env.parentExpanded,gestureRevision==env.bindingRevision else{cancelNozzle();return}
            let hadHelp=gesture.overflowHelpNeeded
            var next=gesture;try next.move(along:along,reducedMotion:env.reducedMotion,canPreview:canPreviewOrder)
            guard running,generation==token else{return};gesture=next
            if gesture.preview != nil{cards.dismiss()}
            if !hadHelp,gesture.overflowHelpNeeded,let source=gesture.source{onOverflowDragHelp?(source)}
            guard running,generation==token else{return};refresh()
        }catch{cancelNozzle();onFailure?(error)}
    }
    public func endNozzle(insideMain:Bool,overSameSource:Bool){
        guard running,hasCapture else{return}
        do{
            let token=generation,env=read();guard running,generation==token,env.active,env.parentExpanded,gestureRevision==env.bindingRevision else{cancelNozzle();return}
            let result=try gesture.release(insideMain:insideMain,overSameSource:overSameSource,catalogue:env.catalogue,preferences:env.preferences);gestureRevision=nil
            switch result{
            case .none:refresh()
            case .click(let id):click(id)
            case .order(let request):
                if let current=presentation{publish(.init(card:current.card,content:current.content,reorder:nil,overflowIDs:current.overflowIDs))}
                guard running,generation==token else{return};submit(request,keyboard:false)
            }
        }catch{cancelNozzle();onFailure?(error)}
    }
    public func cancelNozzle(){gesture.cancel();gestureRevision=nil;refresh()}
    public func moveByKeyboard(id:String,delta:Int){
        guard running else{return}
        do{
            let token=generation,env=read();guard running,generation==token,env.active,env.parentExpanded,
                let request=try DockNozzleInteraction.keyboardMove(id:id,delta:delta,catalogue:env.catalogue,preferences:env.preferences) else{return}
            cards.dismiss();gesture.cancel()
            if let current=presentation{publish(.init(card:.hidden,content:nil,reorder:nil,overflowIDs:current.overflowIDs))}
            guard running,generation==token else{return};submit(request,keyboard:true)
        }catch{onFailure?(error)}
    }
    private func submit(_ request:DockOrderRequest,keyboard:Bool){
        guard pendingOrders.count<32 else{return};pendingOrders[request.id]=(request,keyboard);onOrderRequest?(request)
    }
    /// The shared preference owner calls this only after accepting the canonical order; no speculative announcement.
    public func orderAccepted(_ id:UUID,preferences:DockSubscriptionPreferences,catalogue:[String]){
        guard running,let (request,keyboard)=pendingOrders.removeValue(forKey:id),request.catalogue==catalogue,request.proposed==preferences else{return}
        if keyboard{onOrderAnnouncement?(request.movedID,request.position,catalogue.count)}
        refresh()
    }
    public func orderRejected(_ id:UUID){pendingOrders.removeValue(forKey:id);refresh()}
    private func publish(_ value:DockInteractionPresentation){if value != presentation{presentation=value;onPresent?(value)}}
}
