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
}
