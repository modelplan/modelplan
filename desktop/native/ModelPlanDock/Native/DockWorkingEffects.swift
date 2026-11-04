// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import CoreImage
import ModelPlanPrimitives

public enum DockEffectCompositing: Sendable {case sourceOver, screen}

/// An optional host-supplied motion recipe. It rotates only the independent effect bitmap.
public struct DockEffectRotation: Equatable, Sendable {
    public enum Direction: Equatable, Sendable {case clockwise, counterclockwise}
    public let period:Double
    public let direction:Direction
    public init(period:Double,direction:Direction = .clockwise){self.period=period;self.direction=direction}
    var valid:Bool {period.isFinite && (0.01...86_400).contains(period)}
    // The nested flipped parents reverse the final NSView basis; negative CA Z is visual clockwise.
    func angle(elapsed:Double)->Double {
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
    /// Sampled CA contents matched against the active stepped atlas. Unobservable IDs are omitted.
    public var frameIndicesForChecks: [String: Int] {
        var result: [String: Int] = [:]
        for (id, effect) in consumers {
            guard let frames = (effect.layer.animation(forKey: "stepped-images") as? CAKeyframeAnimation)?.values,
                  let raw = effect.layer.presentation()?.contents ?? effect.layer.contents,
                  CFGetTypeID(raw as CFTypeRef) == CGImage.typeID else { continue }
            let image = raw as! CGImage
            if let index = frames.firstIndex(where: { CFGetTypeID($0 as CFTypeRef) == CGImage.typeID && ($0 as! CGImage) === image }) { result[id] = index }
        }
        return result
    }
    public var rotationRecipesForChecks: [String: DockEffectRotation] { motionByID }
    /// Current attachment state, not a historical event log. Retired IDs are absent.
    public var animationLifecycleForChecks: [String: Bool] { consumers.mapValues { $0.layer.superlayer != nil } }
    /// Actual stepped sample interval. Static/interpolated consumers have no stepped cadence.
    public var cadenceForChecks: Double? {
        let intervals = consumers.values.compactMap { effect -> Double? in
            guard let animation = effect.layer.animation(forKey: "stepped-images") as? CAKeyframeAnimation,
                  let values = animation.values, !values.isEmpty else { return nil }
            return animation.duration / Double(values.count)
        }
        guard let first = intervals.first, intervals.allSatisfy({ $0 == first }) else { return nil }
        return first
    }
    private let systemReduceMotion:()->Bool
    private var motionByID=[String:DockEffectRotation]()
    private var staticIDs=Set<String>()
    private static let rotationKey="dock-effect-rotation"
    public var rotatingIDs:Set<String>{Set(consumers.filter{$0.value.layer.animation(forKey:Self.rotationKey) != nil}.map(\.key))}
    public init(pool:EffectResourcePool,systemReduceMotion:@escaping ()->Bool = {NSWorkspace.shared.accessibilityDisplayShouldReduceMotion},hostTime:@escaping ()->CFTimeInterval = {CACurrentMediaTime()}){
        self.pool=pool;self.systemReduceMotion=systemReduceMotion;self.hostTime=hostTime
    }
    public func configure(view:DockInstrumentView,skin:DockInstrumentSkin,readings:[DockInstrumentReading],profile:RenderProfile,
                          magnification:[String:Double]=[:],compositing:DockEffectCompositing = .sourceOver,rotation:DockEffectRotation? = nil,quietIDs:Set<String> = [],sampling:DockEffectSampling = .stepped,provider:(DockInstrumentReading)->(any EffectFrameProvider)?) throws {
        stop();pool.purgeUnleased();unavailableIDs=[]
        guard Set(readings.map(\.subscriptionID)).count==readings.count else{throw DockLogicError.invalidCatalogue}
        guard rotation?.valid ?? true else{throw DockArtworkError.invalidManifest}
        var effectiveProfile=profile
        effectiveProfile.reduceMotion = profile.reduceMotion || systemReduceMotion()
        view.onVisualReset={[weak self] in self?.stop()}
        if (compositing == .screen || sampling == .interpolatedCandidate) && !view.layerUsesCoreImageFilters {view.layerUsesCoreImageFilters=true}
        let rows=Dictionary(uniqueKeysWithValues:readings.map{($0.subscriptionID,$0)})
        let epoch=hostTime();guard epoch.isFinite else{throw DockArtworkError.invalidManifest}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        for station in skin.stations {
            guard let id=station.subscriptionID,let reading=rows[id],reading.jetEligible else{continue}
            guard let parent=view.workingLayerParents[id],let source=provider(reading) else{unavailableIDs.insert(id);continue}
            guard station.diameter.isFinite,(8...256).contains(station.diameter) else{unavailableIDs.insert(id);continue}
            let points=station.logicalPoints ?? Int(station.diameter.rounded())
            let request=EffectFrameRequest(profile:effectiveProfile,points:points,magnification:magnification[id] ?? 1,variant:reading.status.rawValue)
            let effect=SteppedImageEffect(pool:pool);effect.configure(request:request,provider:source,working:true)
            guard effect.isAvailable else{unavailableIDs.insert(id);effect.stop();continue}
            effect.layer.frame=parent.bounds
            if compositing == .screen {
                // macOS public Core Image compositing API; no undocumented CAFilter name.
                guard let filter=CIFilter(name:"CIScreenBlendMode") else{effect.stop();unavailableIDs.insert(id);continue}
                effect.layer.compositingFilter=filter
            }
            // Quiet uses the existing atlas and static frame zero, without a second profile/cache.
            if quietIDs.contains(id) || effectiveProfile.reduceMotion {staticIDs.insert(id);effect.seekForCapture(0)}
            parent.addSublayer(effect.layer)
            if sampling == .interpolatedCandidate,!effectiveProfile.reduceMotion,!quietIDs.contains(id) {
                guard let interpolation=DockInterpolatedFrames(effect:effect,epoch:epoch) else{effect.stop();effect.layer.removeFromSuperlayer();unavailableIDs.insert(id);continue}
                interpolations[id]=interpolation
            }
            if let rotation,!effectiveProfile.reduceMotion,!quietIDs.contains(id) {
                let spin=CABasicAnimation(keyPath:"transform.rotation.z")
                spin.fromValue=0;spin.toValue=rotation.direction == .clockwise ? -2*Double.pi:2*Double.pi
                spin.duration=rotation.period;spin.timingFunction=CAMediaTimingFunction(name:.linear)
                spin.repeatCount = .infinity;spin.beginTime=effect.layer.convertTime(epoch,from:nil)
                effect.layer.add(spin,forKey:Self.rotationKey);motionByID[id]=rotation
            }
            consumers[id]=effect
        }
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
        for (id,effect) in consumers {
            if let interpolation=interpolations[id]{interpolation.seek(phase)}else{effect.seekForCapture(staticIDs.contains(id) ? 0:phase)}
            effect.layer.removeAnimation(forKey:Self.rotationKey)
            if let motion=motionByID[id]{effect.layer.transform=CATransform3DMakeRotation(motion.angle(elapsed:phase),0,0,1)}
        }
    }
    public func stop(){for interpolation in interpolations.values{interpolation.stop()};interpolations=[:];for effect in consumers.values{effect.stop();effect.layer.removeFromSuperlayer()};consumers=[:];motionByID=[:];staticIDs=[];unavailableIDs=[]}
}
