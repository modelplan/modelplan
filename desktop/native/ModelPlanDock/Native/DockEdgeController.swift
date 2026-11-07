// SPDX-License-Identifier: MIT
import AppKit
import OSLog
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
/// Value-only positioning request. The native composition may supply a borrowed
/// window positioner while this controller remains the sole visibility/drag owner.
public struct DockPlacementRequest: Sendable {
    public let preference: DockEdgePreference
    public let environment: DockEdgeEnvironment
    public let nearest: Bool
    public let wakeDepth: CGFloat
    public init(preference: DockEdgePreference, environment: DockEdgeEnvironment,
                nearest: Bool = false, wakeDepth: CGFloat = 20) {
        self.preference = preference; self.environment = environment
        self.nearest = nearest; self.wakeDepth = wakeDepth
    }
    public func resolveEligibleEdge() throws -> DockEdgePlacement? {
        try DockEdgeGeometry.resolve(preference: preference, displays: environment.displays,
            layouts: environment.layouts, pointer: environment.pointer,
            primaryID: environment.primaryDisplayID, nearest: nearest, wakeDepth: wakeDepth)
    }
}
public struct DockEdgePresentation:Equatable,Sendable {
    public let state:DockSurfaceState,placement:DockEdgePlacement?,carriedFrame:CGRect?,moving:Bool
    /// Only this painted frame becomes an input surface. Wake/slack/corridors are read-only retention geometry.
    public var paintedFrame:CGRect?{
        switch state{case .sliver:return placement?.sliverFrame;case .expanded:return carriedFrame ?? placement?.frame;case .suppressed:return nil}
    }
}
@MainActor public final class DockEdgeController:DockBackgroundDragHandling {
    public private(set) var preference:DockEdgePreference
    public private(set) var presentation:DockEdgePresentation?
    public var onPresent:((DockEdgePresentation)->Void)?
    public var onReveal:(()->Void)?,onCommittedPlacement:((DockEdgePreference)->Void)?,onClearRecordedLocks:((DockRecordedLocks)->Void)?
    public var onFailure:((Error)->Void)?
    /// DOCK-3.6-10: a stale lock was overridden to hide the widget. Logged, and counted for checks.
    public private(set) var forcedHideCount=0
    private func noteForcedHide(){forcedHideCount += 1;Logger(subsystem:"org.modelplan.community",category:"dock").notice("forcedHide: stale locks recovered after continuous outside time")}
    public var dragRegions:DockBackgroundDragRegions?{didSet{dragLayout=presentation?.placement?.layout}}
    private var dragLayout:DockEdgeLayout?
    private let read:()->DockEdgeEnvironment,clock:()->TimeInterval,scheduler:any DockEdgeScheduling
    private let position: (DockPlacementRequest) throws -> DockEdgePlacement?
    private var visibility:DockVisibilityState
    private var running=false,sampling=false,timerGeneration:UInt=0
    private var geometry:[DockDisplayArea]=[],layouts:[DockEdgeLayout]=[]
    private var primaryID:String?
    private var drag: PulsePanelDrag?
    private var dragStart: DockEdgePresentation?
    public var prepareDragDisplay: ((DockDisplayArea) -> Void)?
    public var onDragCancelled: (() -> Void)?
    public var isBackgroundMoving: Bool { presentation?.moving == true }
    public var isBackgroundPressed: Bool { drag != nil }
    public private(set) var isPublishingRelease = false
    public init(preference:DockEdgePreference = .init(),policy:DockVisibilityPolicy = .init(),clock:@escaping ()->TimeInterval,scheduler:any DockEdgeScheduling,read:@escaping ()->DockEdgeEnvironment,position:@escaping (DockPlacementRequest)throws->DockEdgePlacement? = {try $0.resolveEligibleEdge()}){
        self.preference=preference;visibility = .init(policy:policy);self.clock=clock;self.scheduler=scheduler;self.read=read;self.position=position
    }
    public convenience init(preference:DockEdgePreference = .init(),policy:DockVisibilityPolicy = .init(),read:@escaping ()->DockEdgeEnvironment,position:@escaping (DockPlacementRequest)throws->DockEdgePlacement? = {try $0.resolveEligibleEdge()}){
        let time=SystemRefreshTime();let clock={time.elapsed}
        self.init(preference:preference,policy:policy,clock:clock,scheduler:DockCommonModeScheduler(clock:clock),read:read,position:position)
    }
    /// No window, Settings write, status menu or global keyboard/mouse monitor is created here.
    public func start(){guard !running else{return};running=true;refresh()}
    public func stop(){
        running=false;timerGeneration &+= 1;let token=timerGeneration;scheduler.cancel()
        let hadMove=drag != nil;clearMove();visibility = .init(policy:visibility.policy)
        if hadMove{onClearRecordedLocks?(.drag)}
        guard !running,timerGeneration==token else{return}
        publish(.init(state:.suppressed(.lifecycle),placement:nil,carriedFrame:nil,moving:false))
    }
    public func resume(){stop();running=true;refresh()}
    public func setPreference(_ value:DockEdgePreference){
        guard drag == nil else { return }
        preference=value;refresh()
    }
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
    private func environment()->DockEdgeEnvironment{
        var value=read()
        value.displays.sort{$0.id<$1.id}
        value.layouts.sort{a,b in
            if a.displayID != b.displayID{return a.displayID<b.displayID}
            return (DockEdgeGeometry.allowedEdges.firstIndex(of:a.edge) ?? 3)<(DockEdgeGeometry.allowedEdges.firstIndex(of:b.edge) ?? 3)
        }
        return value
    }
    private func refresh(intent:DockVisibilityIntent){
        guard running,!sampling else{return};sampling=true;defer{sampling=false}
        timerGeneration &+= 1;let token=timerGeneration;scheduler.cancel()
        let env=environment(),now=clock()
        do{
            var input=env.presence
            guard visibility.policy.sampleInterval>0 else{throw DockLogicError.invalidTime}
            if drag != nil, allowsDrag(input) {
                return
            }
            let changed=geometry != env.displays || layouts != env.layouts || primaryID != env.primaryDisplayID
            let extraClear: DockRecordedLocks = drag == nil ? [] : .drag
            if drag != nil { clearMove() }
            if changed { geometry=env.displays;layouts=env.layouts;primaryID=env.primaryDisplayID }
            let place=try resolve(preference:preference,environment:env,pointer:env.pointer)
            input.outerEdge=place != nil
            if let p=place,let d=env.displays.first(where:{$0.id==p.displayID}),let pointer=env.pointer{
                input.pointer=DockPresenceArea(painted:p.globalHoverRects,wake:p.wakeFrame,card:env.cardFrame,display:d.usableFrame,edge:p.edge,outerEdge:DockEdgeGeometry.canWake(at:pointer,placement:p,displays:env.displays)).region(at:pointer,policy:visibility.policy)
            }else{input.pointer = .unknown}
            var reset:DockVisibilityChange?
            if changed && intent == .sample{reset=try visibility.step(input,at:now,intent:.lifecycleCancel)}
            let result=try visibility.step(input,at:now,intent:intent)
            if result.forcedHide { noteForcedHide() }
            let cleared=result.clearRecordedLocks.union(reset?.clearRecordedLocks ?? []).union(extraClear)
            if !cleared.isEmpty{onClearRecordedLocks?(cleared)}
            guard running,timerGeneration==token else{return}
            publish(.init(state:result.state,placement:place,carriedFrame:nil,moving:false))
            guard running,timerGeneration==token else{return}
            if result.didReveal || reset?.didReveal == true{onReveal?()}
            guard running,timerGeneration==token else{return}
            guard input.lifecycleActive, input.enabled else{return}
            let due=min(result.nextDeadline ?? .infinity,now+visibility.policy.sampleInterval)
            guard due.isFinite,due>now else{throw DockLogicError.invalidTime}
            scheduler.arm(at:due){[weak self] in guard let self,self.running,self.timerGeneration==token else{return};self.refresh()}
        }catch{
            clearMove();visibility = .init(policy:visibility.policy)
            publish(.init(state:.suppressed(.lifecycle),placement:nil,carriedFrame:nil,moving:false))
            onFailure?(error)
            let retry = now + visibility.policy.sampleInterval
            guard running, timerGeneration == token, env.presence.lifecycleActive, env.presence.enabled,
                  retry.isFinite, retry > now else { return }
            scheduler.arm(at: retry) { [weak self] in
                guard let self, self.running, self.timerGeneration == token else { return }
                self.refresh()
            }
        }
    }
    private func publish(_ next:DockEdgePresentation){if next != presentation{presentation=next;onPresent?(next)}}
    private func clearMove() { drag = nil; dragStart = nil }
    public func backgroundCanDrag(local:CGPoint)->Bool {
        guard dragLayout == presentation?.placement?.layout else { return false }
        return dragRegions?.contains(local) ?? false
    }
    public func beginBackgroundMove(local: CGPoint, global: CGPoint) -> Bool {
        guard drag == nil, acceptsPress(), backgroundCanDrag(local: local), global.x.isFinite, global.y.isFinite,
              let current = presentation, current.state == .expanded, let placement = current.placement else { return false }
        dragStart = current
        drag = PulsePanelDrag(press: global, placement: placement)
        return true
    }
    private func allowsDrag(_ presence: DockPresence) -> Bool {
        presence.lifecycleActive && presence.enabled && presence.cockpitClosed && presence.allowedOverFullscreen
    }

    public func updateBackgroundMove(global: CGPoint) {
        guard running, var transaction = drag, transaction.beginMovement(at: global) else { return }
        drag = transaction
        let before = environment()
        guard allowsDrag(before.presence) else { refresh(); return }
        guard let display = PulsePanelDrag.display(at: global, in: before.displays) else { return }
        prepareDragDisplay?(display)
        guard drag != nil, running else { return }
        let env = environment()
        guard allowsDrag(env.presence) else { refresh(); return }
        // Topology can change while the destination artwork is prepared. Keep
        // the verified carry until the next pointer event has a current target.
        guard PulsePanelDrag.display(at: global, in: env.displays) == display else { return }
        let carried = transaction.carry(pointer: global, display: display, layouts: env.layouts)
        do {
            guard let placement = try resolve(preference: carried.0, environment: env, pointer: global) else { return }
            drag = transaction
            let frame = carried.attached ? placement.frame :
                transaction.floatingFrame(pointer: global, size: placement.frame.size, visible: display.usableFrame)
            publish(.init(state: .expanded, placement: placement, carriedFrame: frame, moving: true))
        } catch {
            onFailure?(error)
        }
    }

    private func resolve(preference: DockEdgePreference, environment: DockEdgeEnvironment,
                         pointer: CGPoint?) throws -> DockEdgePlacement? {
        var input = environment
        input.pointer = pointer
        return try position(.init(preference: preference, environment: input, wakeDepth: visibility.policy.wakeDepth))
    }

    public func endBackgroundMove(global: CGPoint) {
        guard running, let transaction = drag else { return }
        let before = environment()
        guard allowsDrag(before.presence) else { refresh(); return }
        guard transaction.moved, let display = PulsePanelDrag.display(at: global, in: before.displays) else {
            cancelBackgroundMove(); return
        }
        prepareDragDisplay?(display)
        guard drag != nil, running else { return }
        do {
            let env = environment()
            guard allowsDrag(env.presence) else { refresh(); return }
            guard PulsePanelDrag.display(at: global, in: env.displays) == display else {
                cancelBackgroundMove()
                return
            }
            let intent = transaction.release(pointer: global, display: display, layouts: env.layouts)
            guard let destination = try resolve(preference: intent, environment: env, pointer: global) else {
                cancelBackgroundMove(); return
            }
            let token = timerGeneration
            clearMove()
            onClearRecordedLocks?(.drag)
            guard running, timerGeneration == token else { return }
            preference = destination.preference
            isPublishingRelease = true
            defer { isPublishingRelease = false }
            refresh(intent: .reveal)
            guard running, preference == destination.preference else { return }
            onCommittedPlacement?(destination.preference)
        } catch {
            cancelBackgroundMove()
            onFailure?(error)
        }
    }

    public func cancelBackgroundMove() {
        guard drag != nil else { return }
        let previous = dragStart
        clearMove()
        onClearRecordedLocks?(.drag)
        guard running else { return }
        if let onDragCancelled {
            onDragCancelled()
        } else if let previous {
            publish(previous)
        }
        refresh()
    }
}
