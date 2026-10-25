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
        print("5 primitive contract groups passed; injected actions are not physical keyboard/VoiceOver proof")
    }
}

/// Diagnostic polling exists only in this test executable, never in the product animation path.
@MainActor private func liveCadenceCheck() throws {
    NSApplication.shared.setActivationPolicy(.accessory); NSApplication.shared.finishLaunching()
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 140, height: 120)); view.wantsLayer = true
    let window = NSWindow(contentRect: NSRect(x: 20, y: 20, width: 140, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view; window.level = .floating; window.orderFront(nil)
    let pool = EffectResourcePool(), effect = SteppedEffect(pool: pool)
    effect.configure(profile: RenderProfile(), working: true); view.layer?.addSublayer(effect.layer); CATransaction.flush()
    defer { effect.stop(); pool.purgeUnleased(); window.orderOut(nil) }
    let start = ContinuousClock.now
    var fingerprints: [String] = [], transitions = 0, samples = 0
    while start.duration(to: .now) < .seconds(5) {
        CFRunLoopRunInMode(.defaultMode, 0.025, false)
        if let value = effect.layer.mask?.presentation()?.contents,
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
        "scope": "live CA presentation-layer content hashes in a visible owned window; diagnostic polling excluded from CPU acceptance"]
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
