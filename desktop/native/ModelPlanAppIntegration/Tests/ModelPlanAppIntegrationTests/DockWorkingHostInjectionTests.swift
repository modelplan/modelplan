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
}
