// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

public struct RenderProfile: Hashable, Sendable {
    public var dark: Bool, highContrast: Bool, reduceMotion: Bool, reduceTransparency: Bool
    public var scale: Int
    public var locale: String, fontKey: String, colorSpace: String, viewport: String
    public init(dark: Bool = false, scale: Int = 2, locale: String = "en", highContrast: Bool = false,
                reduceMotion: Bool = false, reduceTransparency: Bool = false,
                fontKey: String = "system-12", colorSpace: String = "sRGB", viewport: String = "calibration") {
        self.dark = dark; self.scale = scale; self.locale = locale; self.highContrast = highContrast
        self.reduceMotion = reduceMotion; self.reduceTransparency = reduceTransparency
        self.fontKey = fontKey; self.colorSpace = colorSpace; self.viewport = viewport
    }
}

/// Immutable raster request. Magnification changes sampling density, not the host's geometry transform.
public struct EffectFrameRequest: Hashable, Sendable {
    public let profile: RenderProfile
    public let points: Int
    public let magnification: Double
    public let variant: String
    public init(profile: RenderProfile, points: Int, magnification: Double = 1, variant: String) {
        self.profile = profile; self.points = points; self.magnification = magnification; self.variant = variant
    }
    public var pixelSide: Int? {
        guard (1...2).contains(profile.scale), (1...2048).contains(points),
              magnification.isFinite, (1...4).contains(magnification), !variant.isEmpty else { return nil }
        let pixels = ceil(Double(points) * Double(profile.scale) * magnification)
        guard pixels <= 4096 else { return nil }
        return Int(pixels)
    }
}
/// Draw nine frames synchronously into pool-owned aligned RGBA8/sRGB contexts.
/// Keep only encoded resources/paths in providers, never decoded image arrays or retained contexts.
/// Identity/revision and each variant must completely identify immutable visual bytes.
@MainActor public protocol EffectFrameProvider: AnyObject {
    var identifier: String { get }
    var revision: String { get }
    func draw(pose: Int, request: EffectFrameRequest, in context: CGContext) throws
}

/// Pool admission counts all host-decoded image bytes, including atlases leased by live CA layers.
/// Active leases cannot be evicted. Refusal produces a static vector fallback, never an unbounded atlas.
@MainActor public final class EffectResourcePool {
    public static let maximumBytes = 4_000_000
    public static let poses = 9
    struct Key: Hashable, Sendable {
        let profile: RenderProfile, points: Int, magnification: Double
        let providerID: String, revision: String, variant: String
        let isRGBA: Bool
        init(profile: RenderProfile, points: Int, magnification: Double = 1,
             providerID: String = "org.modelplan.neutral-mask", revision: String = "1", variant: String = "mask", isRGBA: Bool = false) {
            self.profile = profile; self.points = points; self.magnification = magnification
            self.providerID = providerID; self.revision = revision; self.variant = variant; self.isRGBA = isRGBA
        }
        var request: EffectFrameRequest { EffectFrameRequest(profile: profile, points: points, magnification: magnification, variant: variant) }
    }
    final class Entry {
        let images: [CGImage], bytes: Int
        var leases = 0, age: UInt64 = 0
        init(_ images: [CGImage]) { self.images = images; bytes = images.reduce(0) { $0 + $1.bytesPerRow * $1.height } }
    }
    private var entries: [Key: Entry] = [:], age: UInt64 = 0
    private var inFlight: Set<Key> = []
    public private(set) var decodedBytes = 0
    public private(set) var peakDecodedBytes = 0
    public private(set) var refusals = 0
    public init() {}
    public var atlasCount: Int { entries.count }
    public var activeLeaseCount: Int { entries.values.reduce(0) { $0 + $1.leases } }
    func acquire(_ key: Key, provider: (any EffectFrameProvider)? = nil) -> Entry? {
        age &+= 1
        if let entry = entries[key] { entry.leases += 1; entry.age = age; return entry }
        guard !inFlight.contains(key), !key.providerID.isEmpty, !key.revision.isEmpty,
              let pixels = key.request.pixelSide else { refusals += 1; return nil }
        let rowBytes = ((pixels * 4 + 63) / 64) * 64
        let requested = rowBytes * pixels * Self.poses
        guard requested <= Self.maximumBytes else { refusals += 1; return nil }
        while decodedBytes + requested > Self.maximumBytes {
            guard let victim = entries.filter({ $0.value.leases == 0 }).min(by: { $0.value.age < $1.value.age }) else { refusals += 1; return nil }
            decodedBytes -= victim.value.bytes; entries.removeValue(forKey: victim.key)
        }
        // Reserve before invoking a provider, including synchronous reentrant draws. Never over-admit.
        decodedBytes += requested; peakDecodedBytes = max(peakDecodedBytes, decodedBytes)
        inFlight.insert(key); var committed = false
        defer {
            inFlight.remove(key)
            if !committed { decodedBytes -= requested; refusals += 1 }
        }
        var images: [CGImage] = []
        for pose in 0..<Self.poses {
            guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                bytesPerRow: rowBytes, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            if let provider {
                do { try provider.draw(pose: pose, request: key.request, in: context) }
                catch { return nil }
            } else {
                context.scaleBy(x: CGFloat(pixels), y: CGFloat(pixels))
                // Neutral calibration only; never substituted for private official jet artwork.
                let length = 0.68 + Double(pose % 3) * 0.07
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                context.move(to: CGPoint(x: 0.28, y: 0.96)); context.addLine(to: CGPoint(x: 0.72, y: 0.96))
                context.addQuadCurve(to: CGPoint(x: 0.5, y: 1 - length), control: CGPoint(x: 0.68 + Double(pose % 2) * 0.05, y: 0.47))
                context.addQuadCurve(to: CGPoint(x: 0.28, y: 0.96), control: CGPoint(x: 0.28, y: 0.47))
                context.fillPath()
            }
            guard let image = context.makeImage() else { return nil }; images.append(image)
        }
        if let provider {
            guard provider.identifier == key.providerID, provider.revision == key.revision else { return nil }
        }
        let entry = Entry(images)
        guard entry.bytes <= requested else { return nil }
        entry.leases = 1; entry.age = age
        entries[key] = entry; decodedBytes -= requested - entry.bytes; committed = true
        return entry
    }
    func release(_ key: Key) { if let entry = entries[key] { precondition(entry.leases > 0); entry.leases -= 1 } }
    /// Stop consumers before invalidation so old animation values do not outlive their counted lease.
    public func purgeUnleased() {
        for (key, entry) in entries where entry.leases == 0 { decodedBytes -= entry.bytes; entries.removeValue(forKey: key) }
    }
}

@MainActor public final class SteppedEffect {
    public let layer = CAGradientLayer()
    private let mask = CALayer(), pool: EffectResourcePool
    private var key: EffectResourcePool.Key?
    public private(set) var isAnimating = false
    public init(pool: EffectResourcePool) {
        self.pool = pool; layer.mask = mask
        layer.colors = [NSColor.white.cgColor, NSColor.systemBlue.cgColor, NSColor.clear.cgColor]
        layer.startPoint = CGPoint(x: 0.5, y: 1); layer.endPoint = CGPoint(x: 0.5, y: 0)
    }
    public func configure(profile: RenderProfile, points: Int = 52, working: Bool, color: NSColor = .systemBlue) {
        stop()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.frame.size = CGSize(width: points, height: points); mask.frame = layer.bounds
        layer.contentsScale = CGFloat(profile.scale); mask.contentsScale = CGFloat(profile.scale)
        layer.colors = [NSColor.white.cgColor, color.cgColor, NSColor.clear.cgColor]
        layer.isHidden = !working
        if working {
            let k = EffectResourcePool.Key(profile: profile, points: points)
            if let entry = pool.acquire(k) {
                key = k; mask.contents = entry.images[0]
                if !profile.reduceMotion {
                    let animation = CAKeyframeAnimation(keyPath: "contents")
                    animation.values = entry.images
                    // Discrete timing has one boundary per interval plus its final endpoint.
                    animation.keyTimes = (0...EffectResourcePool.poses).map { NSNumber(value: Double($0) / 9) }
                    animation.calculationMode = .discrete; animation.duration = 1; animation.repeatCount = .infinity
                    mask.add(animation, forKey: "stepped-mask"); isAnimating = true
                }
            } else {
                // Vector fallback has no decoded-image allocation; the refused animation stays off.
                mask.backgroundColor = NSColor.white.cgColor; mask.cornerRadius = 8
            }
        }
        CATransaction.commit()
    }
    public func stop() {
        mask.removeAllAnimations(); mask.contents = nil; mask.backgroundColor = nil
        if let key { pool.release(key); self.key = nil }
        layer.isHidden = true; isAnimating = false
    }
    public var discretePoseCount: Int { (mask.animation(forKey: "stepped-mask") as? CAKeyframeAnimation)?.values?.count ?? 0 }
    public func seekForCapture(_ phase: Double) {
        guard let key else { return }
        mask.removeAllAnimations(); isAnimating = false
        // Keep the same counted lease. A capture never allocates a second frame sequence.
        if let entry = pool.acquire(key) {
            mask.contents = entry.images[max(0, min(8, Int(phase * 9) % 9))]; pool.release(key)
        }
    }
}


/// Untinted RGBA consumer for externally supplied frames. No second cache and no synthetic artwork fallback.
@MainActor public final class SteppedImageEffect {
    public let layer = CALayer()
    private let pool: EffectResourcePool
    private var key: EffectResourcePool.Key?
    private var entry: EffectResourcePool.Entry?
    public private(set) var isAnimating = false
    public var isAvailable: Bool { entry != nil }
    public var frameCount: Int { entry?.images.count ?? 0 }
    public init(pool: EffectResourcePool) { self.pool = pool; layer.isHidden = true }
    public func configure(request: EffectFrameRequest, provider: any EffectFrameProvider, working: Bool) {
        stop()
        guard working else { return }
        let k = EffectResourcePool.Key(profile: request.profile, points: request.points, magnification: request.magnification,
                                      providerID: provider.identifier, revision: provider.revision, variant: request.variant, isRGBA: true)
        guard let atlas = pool.acquire(k, provider: provider) else { return }
        key = k; entry = atlas
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.bounds.size = CGSize(width: request.points, height: request.points)
        layer.contentsScale = CGFloat(request.profile.scale) * request.magnification
        layer.contentsGravity = .resize; layer.contents = atlas.images[0]; layer.isHidden = false
        if !request.profile.reduceMotion {
            let animation = CAKeyframeAnimation(keyPath: "contents")
            animation.values = atlas.images
            animation.keyTimes = (0...EffectResourcePool.poses).map { NSNumber(value: Double($0) / Double(EffectResourcePool.poses)) }
            animation.calculationMode = .discrete; animation.duration = 1; animation.repeatCount = .infinity
            layer.add(animation, forKey: "stepped-images"); isAnimating = true
        }
        CATransaction.commit()
    }
    public func seekForCapture(_ phase: Double) {
        guard phase.isFinite, let entry else { return }
        let value = max(0, phase.truncatingRemainder(dividingBy: 1))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: "stepped-images"); isAnimating = false
        layer.contents = entry.images[min(EffectResourcePool.poses - 1, Int(value * Double(EffectResourcePool.poses)))]
        CATransaction.commit()
    }
    public func stop() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.removeAllAnimations(); layer.contents = nil; layer.isHidden = true; isAnimating = false
        CATransaction.commit()
        entry = nil
        if let key { pool.release(key); self.key = nil }
    }
    deinit {
        if let key {
            let pool = pool, layer = layer
            // Keep the counted lease until MainActor has cleared the last CA references.
            Task { @MainActor in
                layer.removeAllAnimations(); layer.contents = nil; layer.isHidden = true
                pool.release(key)
            }
        }
    }
}
