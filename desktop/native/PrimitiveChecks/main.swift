// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import CoreFoundation
import CryptoKit
import ModelPlanCore
import ModelPlanPrimitives

struct Failure: Error { let message: String }
func check(_ value: Bool, _ message: String) throws { if !value { throw Failure(message: message) } }
@MainActor func drainUntil(_ predicate: () -> Bool, _ message: String) throws {
    let end = ContinuousClock.now.advanced(by: .seconds(2))
    while !predicate(), ContinuousClock.now < end { CFRunLoopRunInMode(.defaultMode, 0.02, false) }
    try check(predicate(), message)
}
@main struct PrimitiveChecks {
    @MainActor static func main() throws {
        if CommandLine.arguments.contains("--native-menu") { try nativeMenuCheck(); return }
        if CommandLine.arguments.contains("--live-image-cadence") { try liveCadenceCheck(imageFrames: true); return }
        if CommandLine.arguments.contains("--live-cadence") { try liveCadenceCheck(); return }
        NSApplication.shared.setActivationPolicy(.prohibited)
        let amber = CautionCondition(id: "a", severity: .amber), red = CautionCondition(id: "a", severity: .red)
        var state = CautionState(); state.update([amber], now: 0, reduceMotion: false)
        try check(state.deadline == 10 && state.mode == .blinking, "new episode")
        state.update([amber], now: 2, reduceMotion: false); try check(state.deadline == 10, "snapshot reset blink")
        state.press(); try check(state.mode == .acknowledged, "press")
        state.update([red], now: 6, reduceMotion: false); try check(state.deadline == 16, "worsening")
        state.validate(now: 16, reduceMotion: false); try check(state.mode == .steadyUnacknowledged, "timeout must not acknowledge")
        state.update([], now: 20, reduceMotion: false); try check(state.mode == .off, "clear")
        state.update([amber], now: 24, reduceMotion: false); try check(state.deadline == 34, "recurrence")
        state.validate(now: 25, reduceMotion: true); try check(state.mode == .steadyUnacknowledged && state.deadline == nil, "reduce motion")
        print("PASS F16 caution stable identities, press/worsening/timeout/clear/recurrence/reduced motion")

        try pooledImageChecks()
        let pool = EffectResourcePool(); var effects: [SteppedEffect] = []
        for n in 0..<14 {
            let effect = SteppedEffect(pool: pool)
            effect.configure(profile: RenderProfile(locale: "synthetic-\(n)"), working: true)
            effects.append(effect); try check(pool.decodedBytes <= EffectResourcePool.maximumBytes, "cache ceiling")
            if effect.isAnimating, let animation = effect.layer.mask?.animation(forKey: "stepped-mask") as? CAKeyframeAnimation {
                try check(animation.keyTimes?.count == (animation.values?.count ?? 0) + 1 && animation.keyTimes?.last == 1,
                    "discrete atlas timing boundaries")
            }
        }
        try check(pool.refusals > 0 && pool.activeLeaseCount < effects.count, "pinned atlas admission must fail closed")
        pool.purgeUnleased(); try check(pool.decodedBytes > 0, "purge evicted active leases")
        effects.forEach { $0.stop() }; pool.purgeUnleased(); try check(pool.decodedBytes == 0 && pool.activeLeaseCount == 0, "lease teardown")
        print("PASS decoded cache <=4,000,000 bytes including live leases; bounded refusal and pressure purge")
        let opacityLayer = CALayer(); BoundedOpacity.apply(to: opacityLayer, remaining: 0.17, phase: 0.9, key: "test")
        let opacity = opacityLayer.animation(forKey: "test") as! CAKeyframeAnimation
        try check(opacity.keyTimes?.count == (opacity.values?.count ?? 0) + 1 && opacity.keyTimes?.last == 1 && opacityLayer.opacity == 1,
            "finite opacity uses discrete interval boundaries and steady model value")

        var time = 0.0
        let row = CalibrationRow(elapsed: { time })
        for count in [0, 1, 2, 6] {
            let ids = Set((0..<count).map { "synthetic-sub-\($0)" })
            row.configure(profile: RenderProfile(), workingIDs: ids)
            try check(row.workingIDs == ids && row.animatingCount == count, "distinct working identities")
            if count > 0 { try check(row.minimumPoseCount == 9, "nine shared stepped poses") }
            try check(row.pool.atlasCount <= 1, "same mask duplicated across subscriptions")
        }
        let fader = row.fader; let identity = ObjectIdentifier(fader)
        _ = fader.accessibilityPerformIncrement()
        try check(fader.current == 1 && fader.trial == 2 && fader.recommended == 3, "local trial changed real/current/star")
        fader.clearTrial(); try check(fader.current == 1 && fader.trial == nil, "escape return")
        let unknownFader = EffortControl(id: "unknown", efforts: ["low", "high"], current: nil, recommended: nil)
        try check(unknownFader.accessibilityValue() == nil, "unknown AX value must not be -1 or invented zero")
        _ = unknownFader.accessibilityPerformIncrement(); try check(unknownFader.current == nil && unknownFader.trial == 0, "unknown current trial")
        unknownFader.clearTrial(); try check(unknownFader.accessibilityValue() == nil, "unknown current return")
        var selected = 0; row.onSelectSubscription = { _ in selected += 1 }
        (row.subviews.first { $0.accessibilityIdentifier() == "synthetic-sub-0" } as? NSButton)?.performClick(nil)
        try check(selected == 1 && row.selectedSubscriptionID == "synthetic-sub-0", "subscription action must fire exactly once")
        for dark in [false, true] { for scale in [1, 2] { for locale in ["en", "zh-Hans"] {
            let profile = RenderProfile(dark: dark, scale: scale, locale: locale, reduceMotion: true, reduceTransparency: true)
            row.configure(profile: profile, workingIDs: ["synthetic-sub-0"])
            try check(ObjectIdentifier(row.fader) == identity && row.animatingCount == 0, "redraw lost identity or reduced-motion animation survived")
            try check(row.fader.accessibilityRole() == .slider && row.help.accessibilityIdentifier() == "calibration.help", "AX roles/IDs")
        } } }
        print("PASS F01/F20 0/1/2/6 IDs, 9 discrete steps, shared masks, stable AX/fader and local-only trial")

        let profile = RenderProfile()
        time = 0; row.caution.update([amber], profile: profile)
        time = 9.9; row.caution.validate()
        try check((row.caution.animationDuration ?? 99) < 0.11, "animation did not use remaining interval")
        time = 10.2
        let mode = CFRunLoopMode(rawValue: "NSEventTrackingRunLoopMode" as CFString)
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), mode)
        CFRunLoopRunInMode(mode, 0.25, false)
        try check(row.caution.cautionState.mode == .steadyUnacknowledged && row.caution.animationDuration == nil, "caution deadline deferred over tracking mode")
        row.caution.update([red], profile: profile); let deadline = row.caution.cautionState.deadline
        row.caution.suspend(); time += 2; row.caution.validate()
        try check(row.caution.cautionState.deadline == deadline, "hide/show restarted episode")
        row.caution.acknowledge(); try check(row.caution.animationDuration == nil, "ack animation remains")
        row.startTyping(seconds: 1); row.finishTyping(); try check(row.cursor.animationKeys()?.isEmpty != false && row.cursor.opacity == 0, "cursor survives typing completion")
        row.dispose(); try check(row.pool.decodedBytes == 0, "row teardown")
        print("PASS bounded CA deadline in common tracking mode, hide/show phase, acknowledgement and typing cleanup")
        let anchor = NSWindow(contentRect: row.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        anchor.contentView = row
        try check(anchor.makeFirstResponder(row.fader), "native first responder setup")
        row.configure(profile: RenderProfile(locale: "zh-Hans", reduceMotion: true), workingIDs: [])
        try check(anchor.firstResponder === row.fader, "profile transaction changed native first responder")
        let resolver = AppearanceResolver(view: row)
        var profiles: [RenderProfile] = []; resolver.onChange = { profiles.append($0) }; resolver.start()
        try drainUntil({ profiles.last?.locale == "en" }, "initial profile did not resolve")
        CFRunLoopRunInMode(.defaultMode, 0.1, false) // Let the newly-created window finish its backing transaction.
        let beforeLocale = profiles.count
        resolver.locale = "zh-Hans"; resolver.invalidate(); resolver.invalidate(); resolver.invalidate()
        try drainUntil({ profiles.last?.locale == "zh-Hans" }, "locale profile did not resolve")
        try check(profiles.count == beforeLocale + 1, "profile changes were not coalesced")
        resolver.locale = "en"
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        try drainUntil({ profiles.last?.locale == "en" }, "AX options observed on wrong notification center")
        let beforeStop = profiles.count
        resolver.stop(); resolver.locale = "zh-Hans"; resolver.invalidate()
        CFRunLoopRunInMode(.defaultMode, 0.05, false)
        try check(profiles.count == beforeStop, "profile callback survived teardown")
        row.dispose(); anchor.contentView = nil
        print("PASS per-view profile coalescing, correct workspace AX center, native first-responder preservation and teardown")
        print("8 primitive/provider contract groups passed; injected actions are not physical keyboard/VoiceOver proof")
    }
}

/// Diagnostic polling exists only in this test executable, never in the product animation path.
@MainActor private func liveCadenceCheck(imageFrames: Bool = false) throws {
    NSApplication.shared.setActivationPolicy(.accessory); NSApplication.shared.finishLaunching()
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 140, height: 120)); view.wantsLayer = true
    let window = NSWindow(contentRect: NSRect(x: 20, y: 20, width: 140, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view; window.level = .floating; window.orderFront(nil)
    let pool = EffectResourcePool(), effect = SteppedEffect(pool: pool)
    let imageEffect = SteppedImageEffect(pool: pool), provider = SyntheticFrames()
    if imageFrames {
        imageEffect.configure(request: EffectFrameRequest(profile: RenderProfile(), points: 64, magnification: 1.5, variant: "red"), provider: provider, working: true)
        view.layer?.addSublayer(imageEffect.layer)
    } else { effect.configure(profile: RenderProfile(), working: true); view.layer?.addSublayer(effect.layer) }
    CATransaction.flush()
    defer { effect.stop(); imageEffect.stop(); pool.purgeUnleased(); window.orderOut(nil) }
    let start = ContinuousClock.now
    var fingerprints: [String] = [], transitions = 0, samples = 0
    while start.duration(to: .now) < .seconds(5) {
        CFRunLoopRunInMode(.defaultMode, 0.025, false)
        let contents = imageFrames ? imageEffect.layer.presentation()?.contents : effect.layer.mask?.presentation()?.contents
        if let value = contents,
           CFGetTypeID(value as CFTypeRef) == CGImage.typeID {
            let image = value as! CGImage
            if let data = image.dataProvider?.data {
                let hash = SHA256.hash(data: data as Data).description
                if fingerprints.last != hash { if !fingerprints.isEmpty { transitions += 1 }; fingerprints.append(hash) }
                samples += 1
            }
        }
    }
    let duration = start.duration(to: .now).components
    let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    let result: [String: Any] = ["samples": samples, "transitions": transitions, "seconds": seconds,
        "transitionsPerSecond": Double(transitions) / seconds, "uniquePoses": Set(fingerprints).count,
        "scope": imageFrames ? "live untinted RGBA contents; diagnostic polling excluded from CPU acceptance" : "live mask contents; diagnostic polling excluded from CPU acceptance"]
    if let at = CommandLine.arguments.firstIndex(of: "--output"), CommandLine.arguments.count > at + 1 {
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: CommandLine.arguments[at + 1]))
    }
    print(result)
    try check(samples > 0 && Double(transitions) / seconds >= 8.4 && Double(transitions) / seconds <= 9.6, "live stepped cadence was not observable near 9/s")
    print("PASS live CA presentation-mask cadence near nine transitions per second")
}

@MainActor private final class MenuObservation: NSObject, NSMenuDelegate {
    weak var menu: NSMenu?
    weak var button: CautionControl?
    var opened = false, expiredWhileOpen = false
    func menuWillOpen(_ menu: NSMenu) { opened = true }
    func menuDidClose(_ menu: NSMenu) { opened = false }
}
@MainActor private func nativeMenuCheck() throws {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.finishLaunching()
    var clock = 0.0
    let button = CautionControl(elapsed: { clock })
    let window = NSWindow(contentRect: NSRect(x: 20, y: 20, width: 160, height: 70), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = button; window.level = .floating; window.orderFront(nil)
    defer { button.dispose(); window.orderOut(nil) }
    button.update([CautionCondition(id: "native-menu", severity: .amber)], profile: RenderProfile())
    clock = 9.9; button.validate(); clock = 10.2
    let menu = NSMenu(), observation = MenuObservation(); menu.delegate = observation; observation.menu = menu; observation.button = button
    menu.addItem(withTitle: "Synthetic deadline check", action: nil, keyEquivalent: "")
    let sample = Timer(timeInterval: 0.2, repeats: false) { _ in MainActor.assumeIsolated {
        observation.expiredWhileOpen = observation.opened && observation.button?.cautionState.mode == .steadyUnacknowledged && observation.button?.animationDuration == nil
    } }
    let close = Timer(timeInterval: 0.35, repeats: false) { _ in MainActor.assumeIsolated { observation.menu?.cancelTracking() } }
    RunLoop.main.add(sample, forMode: .common); RunLoop.main.add(close, forMode: .common)
    menu.popUp(positioning: nil, at: NSPoint(x: 10, y: 10), in: button)
    sample.invalidate(); close.invalidate()
    try check(observation.expiredWhileOpen, "deadline did not retire during native NSMenu tracking")
    print("PASS native NSMenu tracking delivered bounded caution expiry before the menu closed")
    print("Programmatic native menu; physical pointer/menu/VoiceOver entry remains a separate owner check")
}

@MainActor private final class SyntheticFrames: EffectFrameProvider {
    var identifier = "synthetic.rgba", revision = "1", calls = 0
    var failurePose: Int?
    var duringFirstDraw: (() -> Void)?
    func draw(pose: Int, request: EffectFrameRequest, in context: CGContext) throws {
        calls += 1
        if pose == 0 { duringFirstDraw?() }
        if failurePose == pose { throw Failure(message: "synthetic drawing failure") }
        let green = request.variant == "green" ? 0.8 : 0.1
        context.setFillColor(CGColor(red: 0.9, green: green, blue: Double(pose) / 16, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
    }
}
@MainActor private func assertImageAnimation(_ layer: CALayer) throws {
    guard let a = layer.animation(forKey: "stepped-images") as? CAKeyframeAnimation else { throw Failure(message: "RGBA animation absent") }
    try check(a.values?.count == 9 && a.keyTimes?.count == 10 && a.keyTimes?.last == 1 &&
              a.duration == 1 && a.calculationMode == .discrete && a.repeatCount.isInfinite, "RGBA nine-step CA contract")
}
@MainActor private func imageInfo(_ layer: CALayer) throws -> (Int, Int, Int, [UInt8]) {
    guard let value = layer.contents, CFGetTypeID(value as CFTypeRef) == CGImage.typeID else { throw Failure(message: "pooled RGBA image absent") }
    let image = value as! CGImage
    guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { throw Failure(message: "RGBA pixel data absent") }
    return (image.width, image.height, image.bytesPerRow, Array(UnsafeBufferPointer(start: bytes, count: 4)))
}
@MainActor private func pooledImageChecks() throws {
    let pool = EffectResourcePool(), source = SyntheticFrames()
    let request = EffectFrameRequest(profile: RenderProfile(scale: 2), points: 64, magnification: 1.5, variant: "red")
    var effects: [SteppedImageEffect] = []
    for i in 0..<6 {
        let effect = SteppedImageEffect(pool: pool)
        effect.configure(request: EffectFrameRequest(profile: request.profile, points: 64, magnification: 1.5,
                                                     variant: ["red","green","amber"][i % 3]), provider: source, working: true)
        try check(effect.isAvailable && effect.isAnimating, "L64 high-density colour admission")
        effects.append(effect)
    }
    try check(pool.activeLeaseCount == 6 && pool.atlasCount == 3 && source.calls == 27, "shared status atlases duplicated across six identities")
    try check(pool.decodedBytes == 3_981_312 && pool.peakDecodedBytes <= 4_000_000, "all active RGBA leases accounted")
    try assertImageAnimation(effects[0].layer)
    do {
        let info = try imageInfo(effects[0].layer)
        try check(info.0 == 192 && info.1 == 192 && info.2 == 768 && info.3[0] > 200 && info.3[2] == 0,
                  "RGBA pixel density or untinted source colour changed")
    }
    let refused = SteppedImageEffect(pool: pool), previousCalls = source.calls
    refused.configure(request: EffectFrameRequest(profile: request.profile, points: 64, magnification: 1.5, variant: "fourth"), provider: source, working: true)
    try check(!refused.isAvailable && refused.layer.isHidden && source.calls == previousCalls && pool.decodedBytes == 3_981_312,
              "refusal must happen before provider allocation, without fake official art")
    let mask = SteppedEffect(pool: pool); mask.configure(profile: RenderProfile(), working: true)
    try check(!mask.isAnimating && pool.decodedBytes == 3_981_312, "mask and RGBA pools were split or active atlases evicted")
    mask.stop(); effects.forEach { $0.stop() }; refused.stop(); pool.purgeUnleased()
    try check(pool.decodedBytes == 0 && pool.activeLeaseCount == 0, "RGBA stop/purge retained CA leases")
    print("PASS shared mask/RGBA budget, six identities/three variants, L64 2x 1.5 sampling, untinted frames and preallocation refusal")

    let one = SteppedImageEffect(pool: pool)
    one.configure(request: EffectFrameRequest(profile: RenderProfile(scale: 2, reduceMotion: true), points: 64, magnification: 1.15, variant: "red"), provider: source, working: true)
    try check(one.isAvailable && !one.isAnimating && one.frameCount == 9 && (try imageInfo(one.layer)).0 == 148, "reduced-motion L64 static source or ceil sampling")
    one.seekForCapture(.nan); one.seekForCapture(0.5)
    try check(!one.isAnimating && pool.activeLeaseCount == 1, "capture cloned/released an active atlas")
    one.stop(); pool.purgeUnleased()
    for bad in [EffectFrameRequest(profile: RenderProfile(), points: Int.max, variant: "red"),
                EffectFrameRequest(profile: RenderProfile(), points: 64, magnification: .nan, variant: "red"),
                EffectFrameRequest(profile: RenderProfile(scale: 3), points: 64, variant: "red")] {
        one.configure(request: bad, provider: source, working: true); try check(!one.isAvailable && pool.decodedBytes == 0, "invalid raster request did not fail closed")
    }
    source.failurePose = 3
    one.configure(request: request, provider: source, working: true)
    try check(!one.isAvailable && pool.decodedBytes == 0 && pool.activeLeaseCount == 0, "partial provider draw did not roll back")
    source.failurePose = nil
    one.configure(request: request, provider: source, working: true)
    let priorCalls = source.calls; source.revision = "2"
    let two = SteppedImageEffect(pool: pool); two.configure(request: request, provider: source, working: true)
    try check(source.calls == priorCalls + 9 && pool.atlasCount == 2, "revision reused stale images")
    one.stop(); two.stop(); pool.purgeUnleased()
    one.configure(request: request, provider: source, working: false)
    try check(!one.isAvailable && pool.decodedBytes == 0, "inactive effect allocated a frame atlas")
    for scale in [1, 2] { for points in [44, 52, 64] { for magnification in [1.0, 1.15, 1.5] {
        let r = EffectFrameRequest(profile: RenderProfile(scale: scale), points: points, magnification: magnification, variant: "red")
        one.configure(request: r, provider: source, working: true)
        try check(one.isAvailable && (try imageInfo(one.layer)).0 == Int(ceil(Double(points * scale) * magnification)), "S/M/L density matrix upscaled or refused")
        one.stop(); pool.purgeUnleased()
    } } }
    one.configure(request: EffectFrameRequest(profile: RenderProfile(dark: false, scale: 1), points: 16, variant: "red"), provider: source, working: true)
    let callsBeforeProfile = source.calls
    two.configure(request: EffectFrameRequest(profile: RenderProfile(dark: true, scale: 1), points: 16, variant: "red"), provider: source, working: true)
    try check(source.calls == callsBeforeProfile + 9 && pool.atlasCount == 2, "changed render profile reused stale source")
    one.stop(); two.stop(); pool.purgeUnleased()
    print("PASS revision/density/variant keys, static Reduce Motion, seek, invalid requests and provider failure rollback")

    let reentrant = SteppedImageEffect(pool: pool)
    var nestedRefused = false
    source.duringFirstDraw = {
        reentrant.configure(request: request, provider: source, working: true)
        nestedRefused = !reentrant.isAvailable
        precondition(pool.decodedBytes <= EffectResourcePool.maximumBytes)
    }
    one.configure(request: request, provider: source, working: true)
    try check(one.isAvailable && nestedRefused && pool.activeLeaseCount == 1, "reentrant reservation bypassed budget or duplicated source")
    source.duringFirstDraw = nil; one.stop(); pool.purgeUnleased()
    source.duringFirstDraw = {
        reentrant.configure(request: EffectFrameRequest(profile: request.profile, points: 96, magnification: 1.5, variant: "nested-budget"), provider: source, working: true)
        nestedRefused = !reentrant.isAvailable
    }
    one.configure(request: request, provider: source, working: true)
    try check(one.isAvailable && nestedRefused && pool.activeLeaseCount == 1, "in-flight reserved bytes were not budgeted for another source")
    source.duringFirstDraw = nil; one.stop(); pool.purgeUnleased()
    var orphan: SteppedImageEffect? = SteppedImageEffect(pool: pool)
    orphan!.configure(request: request, provider: source, working: true)
    let retainedLayer = orphan!.layer; orphan = nil
    try drainUntil({ pool.activeLeaseCount == 0 }, "deinit left a counted live lease")
    try check(retainedLayer.contents == nil && retainedLayer.animationKeys()?.isEmpty != false, "deinit released budget before CA references")
    pool.purgeUnleased(); try check(pool.decodedBytes == 0, "orphan atlas remained pinned")
    print("PASS reentrant source reservation and conservative MainActor teardown of surviving layers")
}
