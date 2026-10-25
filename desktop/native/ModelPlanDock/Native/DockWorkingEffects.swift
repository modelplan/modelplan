// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import CoreImage
import ModelPlanPrimitives

public enum DockEffectCompositing: Sendable {case sourceOver, screen}

/// One injected shared pool, no private atlas. The provider owns encoded/procedural source only.
@MainActor public final class DockWorkingEffects {
    public let pool:EffectResourcePool
    private var consumers=[String:SteppedImageEffect]()
    public private(set) var unavailableIDs=Set<String>()
    public var activeIDs:Set<String>{Set(consumers.filter{$0.value.isAvailable}.map(\.key))}
    public var animatingIDs:Set<String>{Set(consumers.filter{$0.value.isAnimating}.map(\.key))}
    public var frameCounts:[String:Int]{consumers.mapValues(\.frameCount)}
    public init(pool:EffectResourcePool){self.pool=pool}
    public func configure(view:DockInstrumentView,skin:DockInstrumentSkin,readings:[DockInstrumentReading],profile:RenderProfile,
                          magnification:[String:Double]=[:],compositing:DockEffectCompositing = .sourceOver,provider:(DockInstrumentReading)->(any EffectFrameProvider)?) throws {
        guard Set(readings.map(\.subscriptionID)).count==readings.count else{throw DockLogicError.invalidCatalogue}
        stop();pool.purgeUnleased();unavailableIDs=[]
        view.onVisualReset={[weak self] in self?.stop()}
        let rows=Dictionary(uniqueKeysWithValues:readings.map{($0.subscriptionID,$0)})
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        for station in skin.stations {
            guard let id=station.subscriptionID,let reading=rows[id],reading.jetEligible else{continue}
            guard let parent=view.workingLayerParents[id],let source=provider(reading) else{unavailableIDs.insert(id);continue}
            guard station.diameter.isFinite,(8...256).contains(station.diameter) else{unavailableIDs.insert(id);continue}
            let points=station.logicalPoints ?? Int(station.diameter.rounded())
            let request=EffectFrameRequest(profile:profile,points:points,magnification:magnification[id] ?? 1,variant:reading.status.rawValue)
            let effect=SteppedImageEffect(pool:pool);effect.configure(request:request,provider:source,working:true)
            guard effect.isAvailable else{unavailableIDs.insert(id);effect.stop();continue}
            effect.layer.frame=parent.bounds
            if compositing == .screen {
                // macOS public Core Image compositing API; no undocumented CAFilter name.
                guard let filter=CIFilter(name:"CIScreenBlendMode") else{effect.stop();unavailableIDs.insert(id);continue}
                view.layerUsesCoreImageFilters=true;effect.layer.compositingFilter=filter
            }
            parent.addSublayer(effect.layer);consumers[id]=effect
        }
    }
    public func seekForCapture(_ phase:Double){guard phase.isFinite else{return};for effect in consumers.values{effect.seekForCapture(phase)}}
    public func stop(){for effect in consumers.values{effect.stop();effect.layer.removeFromSuperlayer()};consumers=[:];unavailableIDs=[]}
}
