// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import CoreImage
import ModelPlanPrimitives

/// Opt-in candidate only: no runtime performance/appearance acceptance is implied by constructing it.
public enum DockEffectSampling: Equatable, Sendable { case stepped, interpolatedCandidate }

/// Owns the same SteppedImageEffect lease until all child references have been cleared.
/// Only nine existing frames are borrowed with the public seek interface; no second atlas is decoded.
@MainActor final class DockInterpolatedFrames {
    private let effect: SteppedImageEffect
    private var layers = [CALayer]()
    private static let key = "dock-frame-interpolation"
    var isAnimating: Bool { layers.contains { $0.animation(forKey: Self.key) != nil } }
    var layerCount: Int { layers.count }
    init?(effect: SteppedImageEffect, epoch: CFTimeInterval) {
        guard effect.isAvailable, effect.frameCount == EffectResourcePool.poses, epoch.isFinite,
              CIFilter(name: "CIAdditionCompositing") != nil else { return nil }
        self.effect = effect
        var frames = [CGImage]()
        for index in 0..<effect.frameCount {
            // Mid-interval avoids floating-point floor ambiguity in the existing discrete seek seam.
            effect.seekForCapture((Double(index) + 0.5) / Double(effect.frameCount))
            guard let contents = effect.layer.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID else { return nil }
            frames.append(contents as! CGImage)
        }
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        effect.layer.contents = nil
        for (index, image) in frames.enumerated() {
            let layer = CALayer(); layer.frame = effect.layer.bounds; layer.contents = image
            layer.contentsScale = effect.layer.contentsScale; layer.contentsGravity = .resize
            // Add weighted premultiplied frames instead of source-over dimming in overlap regions.
            layer.compositingFilter = CIFilter(name: "CIAdditionCompositing")
            layer.opacity = index == 0 ? 1 : 0
            effect.layer.addSublayer(layer)
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            let count = frames.count
            animation.values = (0...count).map { NSNumber(value: $0 % count == index ? 1.0 : 0.0) }
            animation.keyTimes = (0...count).map { NSNumber(value: Double($0) / Double(count)) }
            animation.calculationMode = .linear; animation.duration = 1; animation.repeatCount = .infinity
            animation.beginTime = layer.convertTime(epoch, from: nil)
            layer.add(animation, forKey: Self.key); layers.append(layer)
        }
    }
    func seek(_ seconds: Double) {
        guard let sample = DockTemporalSample.at(seconds: seconds, count: layers.count) else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        for (index, layer) in layers.enumerated() {
            layer.removeAnimation(forKey: Self.key)
            layer.opacity = Float(index == sample.lower ? 1 - sample.fraction : index == sample.upper ? sample.fraction : 0)
        }
    }
    deinit {
        let retainedLayers = layers, retainedEffect = effect
        Task { @MainActor in
            for layer in retainedLayers { layer.removeAllAnimations(); layer.contents = nil; layer.compositingFilter = nil; layer.removeFromSuperlayer() }
            retainedEffect.stop(); retainedEffect.layer.removeFromSuperlayer()
        }
    }
    func stop() {
        // Layer contents must be cleared before the effect owner releases its counted atlas lease.
        for layer in layers { layer.removeAllAnimations(); layer.contents = nil; layer.compositingFilter = nil; layer.removeFromSuperlayer() }
        layers = []
    }
}
