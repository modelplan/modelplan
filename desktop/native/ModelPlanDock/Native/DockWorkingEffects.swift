// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import CoreImage
import IOKit.ps
import ModelPlanPrimitives

/// MOT-2.3-10: whether the Mac is running on battery. A Mac without one reports AC.
public enum DockPowerSource {
    public static func onBattery()->Bool {
        guard let info=IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type=IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else{return false}
        return (type as String) == kIOPSBatteryPowerValue
    }
}

public enum DockEffectCompositing: Sendable {case sourceOver, screen}

/// An optional host-supplied motion recipe. It rotates only the independent effect bitmap.
public struct DockEffectRotation: Equatable, Sendable {
    public enum Direction: Equatable, Sendable {case clockwise, counterclockwise}
    public let period:Double
    public let direction:Direction
    public init(period:Double,direction:Direction = .clockwise){self.period=period;self.direction=direction}
    /// D171 / DOCK-3.8-23: the working-ring spin is one fixed turn every 2 s. No data drives it.
    public static let working=DockEffectRotation(period:2)
    var valid:Bool {period.isFinite && (0.01...86_400).contains(period)}
    /// The spin's phase is a function of host time only: the origin is the last whole-period
    /// boundary, so every reconfigure resumes at the angle it already showed instead of 0.
    public func phaseOrigin(hostTime:CFTimeInterval)->CFTimeInterval {
        guard hostTime.isFinite,valid else{return hostTime}
        return (hostTime/period).rounded(.down)*period
    }
    public func angle(hostTime:CFTimeInterval)->Double {angle(elapsed:hostTime-phaseOrigin(hostTime:hostTime))}
    // The nested flipped parents reverse the final NSView basis; negative CA Z is visual clockwise.
    public func angle(elapsed:Double)->Double {
        let turns=max(0,elapsed).truncatingRemainder(dividingBy:period)/period
        return turns*2*Double.pi*(direction == .clockwise ? -1:1)
    }
}

/// One injected shared pool, no private atlas. The provider owns encoded/procedural source only.
@MainActor public final class DockWorkingEffects {
    public let pool:EffectResourcePool
    private var consumers=[String:SteppedImageEffect]()
    private var interpolations=[String:DockInterpolatedFrames]()
    private let hostTime:()->CFTimeInterval
    public private(set) var unavailableIDs=Set<String>()
    public var activeIDs:Set<String>{Set(consumers.filter{$0.value.isAvailable}.map(\.key))}
    public var animatingIDs:Set<String>{Set(consumers.filter{$0.value.isAnimating}.map(\.key)).union(interpolations.filter{$0.value.isAnimating}.map(\.key))}
    public var interpolatedIDs:Set<String>{Set(interpolations.keys)}
    public var interpolationLayerCount:Int{interpolations.values.reduce(0){$0+$1.layerCount}}
    public var frameCounts:[String:Int]{consumers.mapValues(\.frameCount)}
    public var cycleSeconds:[String:Double]{consumers.mapValues(\.cycleSeconds)}
    private let systemReduceMotion:()->Bool
    private let onBattery:()->Bool
    /// On battery the flames step at half rate, ~4.5 fps, without the blended frames. Power
    /// is read each time effects are configured, so a change applies at the next data change.
    public private(set) var isThrottled=false
    private static let batteryCycleSeconds=2.0
    private var motionByID=[String:DockEffectRotation]()
    private var staticIDs=Set<String>()
    private static let rotationKey="dock-effect-rotation"
    public var rotatingIDs:Set<String>{Set(consumers.filter{$0.value.layer.animation(forKey:Self.rotationKey) != nil}.map(\.key))}
    public var rotationPeriods:[String:Double] {
        consumers.reduce(into:[:]) { result,item in
            if let animation=item.value.layer.animation(forKey:Self.rotationKey) { result[item.key]=animation.duration }
        }
    }
    /// Layer-time start of each running spin; equal across reconfigures within one host timeline.
    public var rotationBeginTimes:[String:CFTimeInterval] {
        consumers.reduce(into:[:]) { result,item in
            if let animation=item.value.layer.animation(forKey:Self.rotationKey) { result[item.key]=animation.beginTime }
        }
    }
    public init(pool:EffectResourcePool,systemReduceMotion:@escaping ()->Bool = {NSWorkspace.shared.accessibilityDisplayShouldReduceMotion},onBattery:@escaping ()->Bool = DockPowerSource.onBattery,hostTime:@escaping ()->CFTimeInterval = {CACurrentMediaTime()}){
        self.pool=pool;self.systemReduceMotion=systemReduceMotion;self.onBattery=onBattery;self.hostTime=hostTime
    }
    /// What one ring's installed effect was built from. An equal spec on the next configure keeps the installed
    /// layer and its animations untouched (G3-91): a model refresh neither re-adds the spin nor restarts the flames.
    private struct Installed: Equatable {
        let request:EffectFrameRequest
        let providerID:String, revision:String
        let parent:ObjectIdentifier, bounds:CGRect
        let screen:Bool, interpolated:Bool, still:Bool, throttled:Bool
        let rotation:DockEffectRotation?
    }
    private var installed=[String:Installed]()
    /// The running spin animation of each ring, for identity checks (same object across refreshes).
    public var rotationAnimations:[String:CAAnimation] {
        consumers.reduce(into:[:]) { result,item in
            if let animation=item.value.layer.animation(forKey:Self.rotationKey) { result[item.key]=animation }
        }
    }
    public func configure(view:DockInstrumentView,skin:DockInstrumentSkin,readings:[DockInstrumentReading],profile:RenderProfile,
                          magnification:[String:Double]=[:],compositing:DockEffectCompositing = .sourceOver,rotation:DockEffectRotation? = nil,quietIDs:Set<String> = [],sampling:DockEffectSampling = .stepped,provider:(DockInstrumentReading)->(any EffectFrameProvider)?) throws {
        guard Set(readings.map(\.subscriptionID)).count==readings.count else{stop();pool.purgeUnleased();throw DockLogicError.invalidCatalogue}
        guard rotation?.valid ?? true else{stop();pool.purgeUnleased();throw DockArtworkError.invalidManifest}
        var effectiveProfile=profile
        effectiveProfile.reduceMotion = profile.reduceMotion || systemReduceMotion()
        isThrottled=onBattery()
        view.onVisualReset={[weak self] in self?.stop()}
        if (compositing == .screen || sampling == .interpolatedCandidate) && !view.layerUsesCoreImageFilters {view.layerUsesCoreImageFilters=true}
        let rows=Dictionary(uniqueKeysWithValues:readings.map{($0.subscriptionID,$0)})
        let epoch=hostTime();guard epoch.isFinite else{stop();pool.purgeUnleased();throw DockArtworkError.invalidManifest}
        unavailableIDs=[]
        var kept=Set<String>()
        CATransaction.begin();CATransaction.setDisableActions(true)
        defer{
            // Only rings that stopped working (or changed spec) retire; their released atlases are purged after
            // any rebuilt ring re-acquired the same decoded frames.
            for id in Array(consumers.keys) where !kept.contains(id) {retire(id)}
            CATransaction.commit();pool.purgeUnleased()
        }
        for station in skin.stations {
            guard let id=station.subscriptionID,let reading=rows[id],reading.jetEligible else{continue}
            guard let parent=view.workingLayerParents[id],let source=provider(reading) else{unavailableIDs.insert(id);continue}
            guard station.diameter.isFinite,(8...256).contains(station.diameter) else{unavailableIDs.insert(id);continue}
            let points=station.logicalPoints ?? Int(station.diameter.rounded())
            let request=EffectFrameRequest(profile:effectiveProfile,points:points,magnification:magnification[id] ?? 1,variant:reading.status.rawValue)
            let still=quietIDs.contains(id) || effectiveProfile.reduceMotion
            let spec=Installed(request:request,providerID:source.identifier,revision:source.revision,parent:ObjectIdentifier(parent),
                               bounds:parent.bounds,screen:compositing == .screen,
                               interpolated:sampling == .interpolatedCandidate && !isThrottled && !still,still:still,throttled:isThrottled,
                               rotation:still ? nil:rotation)
            // D171 continuity: the same ring with the same recipe keeps its running layer, spin and flame clock.
            if let current=consumers[id],current.isAvailable,current.layer.superlayer === parent,installed[id] == spec {kept.insert(id);continue}
            retire(id)
            let effect=SteppedImageEffect(pool:pool);if isThrottled {effect.cycleSeconds=Self.batteryCycleSeconds}
            effect.configure(request:request,provider:source,working:true)
            guard effect.isAvailable else{unavailableIDs.insert(id);effect.stop();continue}
            effect.layer.frame=parent.bounds
            if compositing == .screen {
                // macOS public Core Image compositing API; no undocumented CAFilter name.
                guard let filter=CIFilter(name:"CIScreenBlendMode") else{effect.stop();unavailableIDs.insert(id);continue}
                effect.layer.compositingFilter=filter
            }
            // Quiet uses the existing atlas and static frame zero, without a second profile/cache.
            if still {staticIDs.insert(id);effect.seekForCapture(0)}
            parent.addSublayer(effect.layer)
            if spec.interpolated {
                guard let interpolation=DockInterpolatedFrames(effect:effect,epoch:epoch) else{effect.stop();effect.layer.removeFromSuperlayer();unavailableIDs.insert(id);continue}
                interpolations[id]=interpolation
            }
            if let rotation=spec.rotation {
                // One render-server animation: no timer and no per-frame main-thread work.
                let spin=CABasicAnimation(keyPath:"transform.rotation.z")
                spin.fromValue=0;spin.toValue=rotation.direction == .clockwise ? -2*Double.pi:2*Double.pi
                spin.duration=rotation.period;spin.timingFunction=CAMediaTimingFunction(name:.linear)
                spin.repeatCount = .infinity;spin.beginTime=effect.layer.convertTime(rotation.phaseOrigin(hostTime:epoch),from:nil)
                spin.isRemovedOnCompletion=false
                effect.layer.add(spin,forKey:Self.rotationKey);motionByID[id]=rotation
            }
            consumers[id]=effect;installed[id]=spec;kept.insert(id)
        }
    }
    private func retire(_ id:String) {
        interpolations.removeValue(forKey:id)?.stop()
        if let effect=consumers.removeValue(forKey:id) {effect.stop();effect.layer.removeFromSuperlayer()}
        motionByID[id]=nil;staticIDs.remove(id);installed[id]=nil
    }
    /// Reuse the actual admitted view skin; an absent/failed appearance retires effects.
    public func configure(view: DockInstrumentView, readings: [DockInstrumentReading], profile: RenderProfile,
                          rotation: DockEffectRotation? = nil,
                          provider: (DockInstrumentReading) -> (any EffectFrameProvider)?) throws {
        guard let skin = view.workingEffectSkin else { stop(); return }
        try configure(view: view, skin: skin, readings: readings, profile: profile,
                      compositing: .screen, rotation: rotation, provider: provider)
    }

    /// Freeze both timelines at elapsed seconds; the nine-pose contents clock remains unchanged.
    public func seekForCapture(_ phase:Double){
        guard phase.isFinite else{return}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        // A frozen capture is not a running effect: the next configure rebuilds it.
        installed=[:]
        for (id,effect) in consumers {
            if let interpolation=interpolations[id]{interpolation.seek(phase)}else{effect.seekForCapture(staticIDs.contains(id) ? 0:phase)}
            effect.layer.removeAnimation(forKey:Self.rotationKey)
            if let motion=motionByID[id]{effect.layer.transform=CATransform3DMakeRotation(motion.angle(elapsed:phase),0,0,1)}
        }
    }
    public func stop(){for interpolation in interpolations.values{interpolation.stop()};interpolations=[:];for effect in consumers.values{effect.stop();effect.layer.removeFromSuperlayer()};consumers=[:];motionByID=[:];staticIDs=[];unavailableIDs=[];installed=[:]}
}
