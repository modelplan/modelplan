// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import ModelPlanDock
import ModelPlanPrimitives
import ModelPlanSettings
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration
import XCTest

@MainActor private final class WorkingFixture: DockContentProvider {
    let input: DockInstrumentInput
    init(now: Date) {
        var value = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [
            .init(id: "quota", period: .fiveHour, label: "5h", remainingPercent: 76,
                  resetsAt: now.addingTimeInterval(600), durationSeconds: 18000)])
        value.dataState = .fresh; input = value
    }
    func makeContent(_ context: DockContentContext) -> DockContent { .init(snapshot: .init(inputs: [input])) }
}

/// The admitted content itself says the ring is working (as the engine's activity rows do), so a plain content
/// refresh is a model refresh during a spin, not a withdrawal.
@MainActor private final class WorkingContentFixture: DockContentProvider {
    var input: DockInstrumentInput
    init(now: Date) {
        var value = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [
            .init(id: "quota", period: .fiveHour, label: "5h", remainingPercent: 76,
                  resetsAt: now.addingTimeInterval(600), durationSeconds: 18000)])
        value.dataState = .fresh
        value.working = .init(subscriptionID: "synthetic", bindingVerified: true, fresh: true, observedOutput: true)
        input = value
    }
    func makeContent(_ context: DockContentContext) -> DockContent { .init(snapshot: .init(inputs: [input])) }
}

/// Calibration frames exist only in this synthetic test, never as production art.
@MainActor private final class WorkingFixtureFrames: EffectFrameProvider {
    let identifier = "org.modelplan.synthetic-working-test", revision = "1"
    func draw(pose: Int, request: EffectFrameRequest, in context: CGContext) throws {
        context.setFillColor(CGColor(gray: CGFloat(pose + 1) / 10, alpha: 1))
        context.fillEllipse(in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
    }
}

@MainActor final class DockWorkingHostInjectionTests: XCTestCase {
    func testInjectedWorkingSpinsIdleAndReducedMotionDoNot() async throws {
        _ = NSApplication.shared
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "synthetic")
        let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
        defer { host.close() }
        host.setDockContentProvider(WorkingFixture(now: now))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("working-host-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = false }
        let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await coordinator.reload(); host.setPresentationAllowed(true)
        let pool = EffectResourcePool(), frames = WorkingFixtureFrames()
        var osReduced = false
        host.installWorkingEffectsForChecks(pool: pool, provider: frames, systemReduceMotion: { osReduced })
        func signal(_ output: Bool) -> DockWorkingSignal { .init(subscriptionID: "synthetic", bindingVerified: true, fresh: true, observedOutput: output) }
        try host.setWorkingSignals([signal(true)])
        XCTAssertNil(host.lastAppearanceError); XCTAssertNil(host.lastWorkingEffectError)
        XCTAssertEqual(host.activeWorkingEffectIDs, ["synthetic"])
        XCTAssertEqual(host.rotatingWorkingEffectIDs, ["synthetic"])
        XCTAssertLessThanOrEqual(pool.decodedBytes, EffectResourcePool.maximumBytes)
        try host.setWorkingSignals([signal(false)])
        XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty); XCTAssertTrue(host.rotatingWorkingEffectIDs.isEmpty)
        try host.setWorkingSignals([signal(true)])
        try await store.update { $0.motion = .on }
        await coordinator.reload()
        XCTAssertEqual(host.activeWorkingEffectIDs, ["synthetic"])
        XCTAssertTrue(host.rotatingWorkingEffectIDs.isEmpty); XCTAssertTrue(host.animatingWorkingEffectIDs.isEmpty)
        try await store.update { $0.motion = .system }
        osReduced = true; await coordinator.reload()
        XCTAssertEqual(host.activeWorkingEffectIDs, ["synthetic"])
        XCTAssertTrue(host.rotatingWorkingEffectIDs.isEmpty); XCTAssertTrue(host.animatingWorkingEffectIDs.isEmpty)
        host.setPresentationAllowed(false)
        XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty); XCTAssertEqual(pool.activeLeaseCount, 0)
    }

    /// MOT-2.3-10 through the production host: flames step at half rate on battery and return
    /// to normal on AC, at the next signal change.
    func testMOT_2_3_10FlamesThrottleOnBattery() async throws {
        _ = NSApplication.shared
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "synthetic")
        let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
        defer { host.close() }
        host.setDockContentProvider(WorkingFixture(now: now))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("working-battery-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = false }
        let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await coordinator.reload(); host.setPresentationAllowed(true)
        var battery = true
        host.installWorkingEffectsForChecks(pool: EffectResourcePool(), provider: WorkingFixtureFrames(), systemReduceMotion: { false }, onBattery: { battery })
        func signal(_ output: Bool) -> DockWorkingSignal { .init(subscriptionID: "synthetic", bindingVerified: true, fresh: true, observedOutput: output) }
        try host.setWorkingSignals([signal(true)])
        XCTAssertEqual(host.animatingWorkingEffectIDs, ["synthetic"], "throttled flames still move")
        XCTAssertEqual(host.workingEffectCycleSeconds["synthetic"], 2)
        battery = false
        try host.setWorkingSignals([signal(false)]); try host.setWorkingSignals([signal(true)])
        XCTAssertEqual(host.workingEffectCycleSeconds["synthetic"], 1)
    }

    /// G3-91 / D171 (owner report 2026-11-25: the working ring stutters while it turns): the spin is one Core Animation
    /// layer animation that a model refresh keeps (same object, same phase); hiding or occlusion removes it (D397).
    func testG3_91SpinIsOneLayerAnimationThatRefreshesKeepAndHidingRemoves() async throws {
        _ = NSApplication.shared
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "synthetic")
        let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
        defer { host.close() }
        let content = WorkingContentFixture(now: now)
        host.setDockContentProvider(content)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("working-spin-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = false }
        let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await coordinator.reload(); host.setPresentationAllowed(true)
        let pool = EffectResourcePool()
        host.installWorkingEffectsForChecks(pool: pool, provider: WorkingFixtureFrames(), systemReduceMotion: { false })
        XCTAssertNil(host.lastWorkingEffectError)
        XCTAssertTrue(host.isWidgetShown, "precondition: the expanded widget is shown")

        // One render-server animation: a linear 2 s turn repeating for ever, with no timer behind it.
        let spin = try XCTUnwrap(host.workingEffectRotationAnimationsForChecks["synthetic"] as? CABasicAnimation)
        XCTAssertEqual(host.workingEffectRotationAnimationsForChecks.count, 1)
        XCTAssertEqual(spin.keyPath, "transform.rotation.z")
        XCTAssertEqual(spin.duration, 2, "D171: one turn every 2 s")
        XCTAssertTrue(spin.repeatCount.isInfinite)
        XCTAssertEqual(spin.timingFunction, CAMediaTimingFunction(name: .linear))
        let begin = try XCTUnwrap(host.workingEffectRotationBeginTimesForChecks["synthetic"])

        // Model refreshes during the spin: the content refresh, an equal delivery and a changed reading.
        let bytes = pool.decodedBytes
        host.refreshDockContent()
        XCTAssertTrue(host.workingEffectRotationAnimationsForChecks["synthetic"] === spin, "a refresh keeps the running spin")
        content.input.windows[0].remainingPercent = 72
        host.refreshDockContent()
        XCTAssertTrue(host.workingEffectRotationAnimationsForChecks["synthetic"] === spin, "a changed reading keeps the running spin")
        XCTAssertEqual(host.workingEffectRotationBeginTimesForChecks["synthetic"], begin, "the phase is not reset")
        XCTAssertEqual(pool.decodedBytes, bytes, "no frames are decoded again")

        // Occluded or collapsed: nothing turns behind the window.
        host.reportWidgetShownForChecks(false)
        XCTAssertTrue(host.workingEffectRotationAnimationsForChecks.isEmpty)
        XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty); XCTAssertEqual(pool.activeLeaseCount, 0)
        host.reportWidgetShownForChecks(true)
        XCTAssertEqual(host.rotatingWorkingEffectIDs, ["synthetic"], "shown again with the activity still admitted")
        // The recreated spin takes its origin from the host clock's last whole-period boundary, so a hide/reveal that
        // straddles a turn boundary legitimately gets a later origin. The invariant is the global phase: the new origin
        // is a whole number of periods after the old one (the angle at any host time is unchanged), never a reset.
        let resumed = try XCTUnwrap(host.workingEffectRotationBeginTimesForChecks["synthetic"])
        let turns = (resumed - begin) / spin.duration
        XCTAssertGreaterThanOrEqual(turns, -1e-9, "the origin never moves back")
        XCTAssertEqual(turns, turns.rounded(), accuracy: 1e-6, "it resumes the same global phase, a whole number of turns later")

        // Work stops: the animation goes with it.
        content.input.working = nil
        host.refreshDockContent()
        XCTAssertTrue(host.workingEffectRotationAnimationsForChecks.isEmpty)
        XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty)

        // Hidden: no animation and no leased frames remain.
        content.input.working = .init(subscriptionID: "synthetic", bindingVerified: true, fresh: true, observedOutput: true)
        host.refreshDockContent()
        XCTAssertEqual(host.rotatingWorkingEffectIDs, ["synthetic"])
        host.setPresentationAllowed(false)
        XCTAssertTrue(host.workingEffectRotationAnimationsForChecks.isEmpty)
        XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty); XCTAssertEqual(pool.activeLeaseCount, 0)
    }

    /// Owner build-6 report 11-27 item +g (owner item 49 after #1241): the ring "hitches once per loop". The nine flame
    /// poses are a 1 s cut from an aperiodic Canvas, so stepping pose 8 -> pose 0 jumped. The loop must step only
    /// between captured neighbours (no seam jump, no repeated frame), the spin must be an exact linear 0 -> -2pi turn
    /// repeating for ever, and identical updates must not re-add or restart either animation.
    func testOwnerBuild6ItemGWorkingLoopHasNoSeamAndIsNeverRestarted() async throws {
        _ = NSApplication.shared
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "synthetic")
        let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
        defer { host.close() }
        let content = WorkingContentFixture(now: now)
        host.setDockContentProvider(content)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("working-seam-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = false }
        let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await coordinator.reload(); host.setPresentationAllowed(true)
        host.installWorkingEffectsForChecks(pool: EffectResourcePool(), provider: WorkingFixtureFrames(), systemReduceMotion: { false }, onBattery: { false })
        XCTAssertNil(host.lastWorkingEffectError)

        // The flame loop: forward and back through the nine poses, each step to a captured neighbour, wrap included.
        let order = try XCTUnwrap(host.workingEffectFramePoseOrdersForChecks["synthetic"])
        XCTAssertEqual(order, [0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1])
        for index in order.indices {
            let next = order[(index + 1) % order.count]
            XCTAssertEqual(abs(order[index] - next), 1, "step \(index): pose \(order[index]) -> \(next) is not a captured neighbour")
        }
        let flames = try XCTUnwrap(host.workingEffectFrameAnimationsForChecks["synthetic"])
        let values = try XCTUnwrap(flames.values).map { $0 as AnyObject }
        let keyTimes = try XCTUnwrap(flames.keyTimes).map(\.doubleValue)
        XCTAssertEqual(values.count, order.count)
        XCTAssertEqual(keyTimes.count, values.count + 1, "discrete: one boundary per frame plus the closing endpoint")
        for index in values.indices {
            XCTAssertFalse(values[index] === values[(index + 1) % values.count], "frame \(index) is drawn twice at a step or the seam")
        }
        XCTAssertEqual(keyTimes.first, 0); XCTAssertEqual(keyTimes.last, 1)
        for index in 1..<keyTimes.count {
            XCTAssertEqual(keyTimes[index] - keyTimes[index - 1], 1 / Double(values.count), accuracy: 1e-12, "even steps, no held frame")
        }
        XCTAssertEqual(flames.calculationMode, .discrete)
        XCTAssertEqual(flames.duration, Double(values.count) / 9, accuracy: 1e-12, "the same ~9 fps step as before")
        XCTAssertTrue(flames.repeatCount.isInfinite); XCTAssertFalse(flames.autoreverses)

        // The spin: exactly one linear turn per period, repeating for ever, no reversal and no extra endpoint.
        let spin = try XCTUnwrap(host.workingEffectRotationAnimationsForChecks["synthetic"] as? CABasicAnimation)
        XCTAssertEqual(spin.keyPath, "transform.rotation.z")
        XCTAssertEqual((spin.fromValue as? NSNumber)?.doubleValue, 0)
        XCTAssertEqual((spin.toValue as? NSNumber)?.doubleValue, -2 * Double.pi, "one whole clockwise turn, so the repeat lands on the start angle")
        XCTAssertEqual(spin.timingFunction, CAMediaTimingFunction(name: .linear))
        XCTAssertTrue(spin.repeatCount.isInfinite); XCTAssertFalse(spin.autoreverses)
        XCTAssertNil(spin.byValue)
        let begin = try XCTUnwrap(host.workingEffectRotationBeginTimesForChecks["synthetic"])

        // Identical activity updates, repeated: neither animation is re-added or restarted.
        for _ in 0..<5 { host.refreshDockContent() }
        XCTAssertTrue(host.workingEffectFrameAnimationsForChecks["synthetic"] === flames, "an identical update keeps the flame loop")
        XCTAssertTrue(host.workingEffectRotationAnimationsForChecks["synthetic"] === spin, "an identical update keeps the spin")
        XCTAssertEqual(host.workingEffectRotationBeginTimesForChecks["synthetic"], begin, "the spin phase is not reset")
        content.input.working = .init(subscriptionID: "synthetic", bindingVerified: true, fresh: true, observedOutput: true)
        host.refreshDockContent()
        XCTAssertTrue(host.workingEffectFrameAnimationsForChecks["synthetic"] === flames, "a re-published equal activity keeps the flame loop")
        XCTAssertTrue(host.workingEffectRotationAnimationsForChecks["synthetic"] === spin, "a re-published equal activity keeps the spin")

        // Energy rules unchanged: hidden means no animation at all.
        host.setPresentationAllowed(false)
        XCTAssertTrue(host.workingEffectFrameAnimationsForChecks.isEmpty)
        XCTAssertTrue(host.workingEffectRotationAnimationsForChecks.isEmpty)
    }

    /// The reflected order, and capture seeks that follow the same clock: one pose per 1/9 s, forward then back,
    /// across the wrap and over many repeats (the shown pose is a closed form of time, never a running count).
    func testReflectedFlameOrderAndSeekFollowTheAnimationAcrossTheWrap() throws {
        XCTAssertEqual(SteppedImageEffect.poseOrder(count: 9, playback: .reflect), [0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1])
        XCTAssertEqual(SteppedImageEffect.poseOrder(count: 9, playback: .loop), Array(0..<9))
        XCTAssertEqual(SteppedImageEffect.poseOrder(count: 2, playback: .reflect), [0, 1])
        XCTAssertEqual(SteppedImageEffect.poseOrder(count: 0, playback: .reflect), [])
        let pool = EffectResourcePool(), effect = SteppedImageEffect(pool: pool)
        defer { effect.stop() }
        effect.playback = .reflect
        effect.configure(request: .init(profile: .init(scale: 1), points: 36, variant: "normal"), provider: WorkingFixtureFrames(), working: true)
        let animation = try XCTUnwrap(effect.layer.animation(forKey: "stepped-images") as? CAKeyframeAnimation)
        let frames = try XCTUnwrap(animation.values).map { $0 as AnyObject }
        XCTAssertEqual(frames.count, 16)
        for step in 0..<48 {
            effect.seekForCapture((Double(step) + 0.5) / 9)
            XCTAssertTrue(try XCTUnwrap(effect.layer.contents) as AnyObject === frames[step % frames.count], "step \(step)")
        }
        effect.seekForCapture(16.0 / 9 * 1_000_000 + 0.5 / 9)
        XCTAssertTrue(try XCTUnwrap(effect.layer.contents) as AnyObject === frames[0], "a long-running clock lands on the same pose")
    }
}
