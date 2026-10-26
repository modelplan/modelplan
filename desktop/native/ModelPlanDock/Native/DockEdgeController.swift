// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore

@MainActor public protocol DockEdgeScheduling:AnyObject {
    func arm(at deadline:TimeInterval,_ action:@escaping @MainActor ()->Void)
    func cancel()
}
/// One-shot deadlines in common modes; never a repeating drawing timer or global input hook.
@MainActor public final class DockCommonModeScheduler:DockEdgeScheduling {
    private var timer:Timer?
    private let clock:()->TimeInterval
    public init(clock:@escaping ()->TimeInterval){self.clock=clock}
    public func arm(at deadline:TimeInterval,_ action:@escaping @MainActor ()->Void){
        cancel();guard deadline.isFinite else{return}
        let value=Timer(timeInterval:max(0.001,deadline-clock()),repeats:false){_ in MainActor.assumeIsolated{action()}}
        timer=value;RunLoop.main.add(value,forMode:.common)
    }
    public func cancel(){timer?.invalidate();timer=nil}
    deinit{timer?.invalidate()}
}
/// The host resolves durable displays, fullscreen/cockpit policy and actual native protection truth.
public struct DockEdgeEnvironment:Sendable {
    public var displays:[DockDisplayArea],layouts:[DockEdgeLayout],primaryDisplayID:String?,pointer:CGPoint?,presence:DockPresence,cardFrame:CGRect?
    public init(displays:[DockDisplayArea],layouts:[DockEdgeLayout],primaryDisplayID:String?=nil,pointer:CGPoint?=nil,presence:DockPresence = .init(),cardFrame:CGRect?=nil){
        self.displays=displays;self.layouts=layouts;self.primaryDisplayID=primaryDisplayID;self.pointer=pointer;self.presence=presence;self.cardFrame=cardFrame
    }
}
public struct DockEdgePresentation:Equatable,Sendable {
    public let state:DockSurfaceState,placement:DockEdgePlacement?,snapPreview:DockEdgePlacement?,moving:Bool
    /// Only this painted frame becomes an input surface. Wake/slack/corridors are read-only retention geometry.
    public var paintedFrame:CGRect?{
        switch state{case .sliver:return placement?.sliverFrame;case .expanded:return placement?.frame;case .suppressed:return nil}
    }
}
@MainActor public final class DockEdgeController:DockBackgroundDragHandling {
    public private(set) var preference:DockEdgePreference
    public private(set) var presentation:DockEdgePresentation?
    public var onPresent:((DockEdgePresentation)->Void)?
    public var onReveal:(()->Void)?,onCommittedPlacement:((DockEdgePreference)->Void)?,onClearRecordedLocks:((DockRecordedLocks)->Void)?
    public var onFailure:((Error)->Void)?
    public var dragRegions:DockBackgroundDragRegions?
    private let read:()->DockEdgeEnvironment,clock:()->TimeInterval,scheduler:any DockEdgeScheduling
    private var visibility:DockVisibilityState
    private var running=false,sampling=false,timerGeneration:UInt=0
    private var geometry:[DockDisplayArea]=[],layouts:[DockEdgeLayout]=[]
    private var dragOrigin:CGPoint?,preview:DockEdgePlacement?
    private var dragStarted=false
    public var isBackgroundMoving:Bool{dragStarted}
    public init(preference:DockEdgePreference = .init(),policy:DockVisibilityPolicy = .init(),clock:@escaping ()->TimeInterval,scheduler:any DockEdgeScheduling,read:@escaping ()->DockEdgeEnvironment){
        self.preference=preference;visibility = .init(policy:policy);self.clock=clock;self.scheduler=scheduler;self.read=read
    }
    public convenience init(preference:DockEdgePreference = .init(),policy:DockVisibilityPolicy = .init(),read:@escaping ()->DockEdgeEnvironment){
        let time=SystemRefreshTime();let clock={time.elapsed}
        self.init(preference:preference,policy:policy,clock:clock,scheduler:DockCommonModeScheduler(clock:clock),read:read)
    }
    /// No window, Settings write, status menu or global keyboard/mouse monitor is created here.
    public func start(){guard !running else{return};running=true;refresh()}
    public func stop(){
        running=false;timerGeneration &+= 1;scheduler.cancel();clearMove()
        visibility = .init(policy:visibility.policy)
        publish(.init(state:.suppressed(.lifecycle),placement:nil,snapPreview:nil,moving:false))
    }
    public func resume(){stop();running=true;refresh()}
    public func setPreference(_ value:DockEdgePreference){cancelBackgroundMove();preference=value;refresh()}
    public func restoreAfterCockpitClose(){refresh(intent:.restoreFromCockpit)}
    public func reveal(){refresh(intent:.reveal)}
    public func refresh(){refresh(intent:.sample)}
    public func acceptsPress(keyboardOrAccessibility:Bool=false)->Bool{
        refresh();return running && visibility.acceptsPress(at:clock(),keyboardOrAccessibility:keyboardOrAccessibility)
    }
    public func install(on view:DockInstrumentView,regions:DockBackgroundDragRegions){
        dragRegions=regions;view.backgroundDragDelegate=self
        view.permitsAction={[weak self] _,source in self?.acceptsPress(keyboardOrAccessibility:source == .accessibility) ?? false}
    }
    private func refresh(intent:DockVisibilityIntent,duringDragEvent:Bool=false){
        guard running,!sampling else{return};sampling=true;defer{sampling=false}
        timerGeneration &+= 1;let token=timerGeneration;scheduler.cancel()
        do{
            let env=read(),now=clock();var input=env.presence
            let changed=geometry != env.displays || layouts != env.layouts
            if changed{if dragOrigin != nil{onClearRecordedLocks?(.drag)};clearMove();geometry=env.displays;layouts=env.layouts}
            let place=try DockEdgeGeometry.resolve(preference:preference,displays:env.displays,layouts:env.layouts,pointer:env.pointer,primaryID:env.primaryDisplayID,wakeDepth:visibility.policy.wakeDepth)
            input.outerEdge=place != nil
            if let p=place,let d=env.displays.first(where:{$0.id==p.displayID}),let pointer=env.pointer{
                input.pointer=DockPresenceArea(painted:p.globalHoverRects,wake:p.wakeFrame,card:env.cardFrame,display:d.usableFrame,edge:p.edge,outerEdge:DockEdgeGeometry.canWake(at:pointer,placement:p,displays:env.displays)).region(at:pointer,policy:visibility.policy)
            }else{input.pointer = .unknown}
            if dragOrigin != nil{input.recordedLocks.insert(.drag);if duringDragEvent{input.mouseButtonDown=true}}
            var reset:DockVisibilityChange?
            if changed && intent == .sample{reset=try visibility.step(input,at:now,intent:.lifecycleCancel)}
            let result=try visibility.step(input,at:now,intent:intent)
            if !input.lifecycleActive || result.state != .expanded{clearMove()}
            let cleared=result.clearRecordedLocks.union(reset?.clearRecordedLocks ?? [])
            if !cleared.isEmpty{onClearRecordedLocks?(cleared)}
            publish(.init(state:result.state,placement:place,snapPreview:preview,moving:dragStarted))
            if result.didReveal || reset?.didReveal == true{onReveal?()}
            guard input.lifecycleActive else{return}
            let due=min(result.nextDeadline ?? .infinity,now+visibility.policy.sampleInterval)
            scheduler.arm(at:due){[weak self] in guard let self,self.running,self.timerGeneration==token else{return};self.refresh()}
        }catch{
            clearMove();running=false;visibility = .init(policy:visibility.policy)
            publish(.init(state:.suppressed(.lifecycle),placement:nil,snapPreview:nil,moving:false));onFailure?(error)
        }
    }
    private func publish(_ next:DockEdgePresentation){if next != presentation{presentation=next;onPresent?(next)}}
    private func clearMove(){dragOrigin=nil;dragStarted=false;preview=nil}
    public func backgroundCanDrag(local:CGPoint)->Bool{dragRegions?.contains(local) ?? false}
    public func beginBackgroundMove(local:CGPoint,global:CGPoint)->Bool{
        guard acceptsPress(),backgroundCanDrag(local:local),global.x.isFinite,global.y.isFinite,presentation?.state == .expanded else{return false}
        dragOrigin=global;dragStarted=false;preview=nil;refresh(intent:.sample,duringDragEvent:true);return true
    }
    public func updateBackgroundMove(global:CGPoint){
        guard let origin=dragOrigin else{return}
        refresh(intent:.sample,duringDragEvent:true);guard dragOrigin != nil,running,global.x.isFinite,global.y.isFinite else{return}
        guard dragStarted || hypot(global.x-origin.x,global.y-origin.y)>5 else{return}
        do{
            let env=read()
            guard let next=try DockEdgeGeometry.resolve(preference:preference,displays:env.displays,layouts:env.layouts,pointer:global,primaryID:env.primaryDisplayID,nearest:true,wakeDepth:visibility.policy.wakeDepth) else{cancelBackgroundMove();return}
            dragStarted=true;preview=next
            if let current=presentation{publish(.init(state:current.state,placement:current.placement,snapPreview:next,moving:true))}
        }catch{cancelBackgroundMove();onFailure?(error)}
    }
    public func endBackgroundMove(global:CGPoint){
        guard dragOrigin != nil else{return};updateBackgroundMove(global:global)
        let destination=dragStarted ? preview:nil;clearMove();onClearRecordedLocks?(.drag)
        if let destination{preference=destination.preference;onCommittedPlacement?(preference)}
        refresh()
    }
    public func cancelBackgroundMove(){
        let hadMove=dragOrigin != nil;clearMove()
        if hadMove{onClearRecordedLocks?(.drag)}
        if let current=presentation{publish(.init(state:current.state,placement:current.placement,snapPreview:nil,moving:false))}
    }
}
