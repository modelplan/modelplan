// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanCockpitWeb
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class PointerObservationScheduler: DockEdgeScheduling {
    var action: (@MainActor () -> Void)?
    var deadline: TimeInterval?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        self.deadline = deadline
        self.action = action
    }
    func cancel() { action = nil; deadline = nil }
    func fire() { let value = action; cancel(); value?() }
}
@MainActor final class DockPointerObservationTests: XCTestCase {
    func testNormalHostConsumesSamplerAndEntryWithoutBypassingDwellAndStopsOnClose() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pointer-observation-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = true }
        let screen = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))
        var elapsed: TimeInterval = 0, local: CGPoint?
        var pointer = CGPoint(x: 500, y: 400), sampleReads = 0
        let scheduler = PointerObservationScheduler()
        let host = StaticDockPreviewHost(appearance: { view, rows, _ in
            try view.applyCommunity(rows); view.setFrameSize(CGSize(width: 80, height: 180))
            return .init(hoverRects: [view.bounds])
        }, currentDate: { Date(timeIntervalSince1970: 1_800_000_000) }, createsNativePanels: false,
            nativeEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id, pointer: pointer) },
            elapsedClock: { elapsed }, edgeScheduling: scheduler,
            pointerSampleSource: { sampleReads += 1; return local })
        defer { host.close() }
        let app = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await app.reload(); host.setPresentationAllowed(true)
        let bytes = try Data(contentsOf: root.appendingPathComponent("settings.json"))
        let surface = host.pointerInputView
        XCTAssertTrue(surface.isActive); XCTAssertNil(host.nativePanel)
        surface.sampleNow(); XCTAssertEqual(host.edgePresentation?.state, .sliver)
        let place = try XCTUnwrap(host.edgePresentation?.placement)
        pointer = CGPoint(x: place.wakeFrame.midX, y: place.wakeFrame.midY)
        // local remains nil, simulating entry arriving after an absent sample.
        let entry = try XCTUnwrap(surface.subviews.first { !$0.trackingAreas.isEmpty })
        let event = try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseEntered, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 1, trackingNumber: 0, userData: nil))
        entry.mouseEntered(with: event)
        XCTAssertEqual(host.edgePresentation?.state, .sliver, "entry must not bypass the controller's dwell")
        elapsed = 0.15; scheduler.fire()
        XCTAssertEqual(host.edgePresentation?.state, .expanded)
        XCTAssertTrue(surface.isActive)
        local = CGPoint(x: 1, y: 1); surface.sampleNow()
        pointer = CGPoint(x: 500, y: 400); local = nil; surface.sampleNow()
        elapsed = 0.65; scheduler.fire()
        XCTAssertEqual(host.edgePresentation?.state, .sliver)
        host.setPresentationAllowed(false); XCTAssertFalse(surface.isActive)
        host.setPresentationAllowed(true); XCTAssertTrue(surface.isActive)
        host.close(); let stoppedReads = sampleReads
        entry.mouseEntered(with: event); surface.sampleNow()
        XCTAssertEqual(sampleReads, stoppedReads); XCTAssertFalse(surface.isActive)
        XCTAssertNil(host.nativePanel)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("settings.json")), bytes)
    }

    func testWakeStripBeyondPaintStartsDwellWithoutNativeEntry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = true; $0.dockEdge = .right; $0.revealMilliseconds = 150 }
        let frame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let screen = DockDisplayArea(id: "wake", frame: frame, visibleFrame: frame)
        let scheduler = PointerObservationScheduler()
        var elapsed: TimeInterval = 0
        var pointer = CGPoint(x: frame.midX, y: frame.midY)
        let host = StaticDockPreviewHost(currentDate: { Date() }, createsNativePanels: false,
            nativeEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id, pointer: pointer) },
            elapsedClock: { elapsed }, edgeScheduling: scheduler, pointerSampleSource: { nil })
        defer { host.close() }
        let settings = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await settings.reload()
        host.setPresentationAllowed(true)
        let placement = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertEqual(host.edgePresentation?.state, .sliver)

        // A hover begins just after the previous sample, 12 points inward.
        // No AppKit entry is sent because the pointer misses the painted view.
        pointer = CGPoint(x: frame.maxX - 12, y: placement.wakeFrame.midY)
        XCTAssertTrue(placement.wakeFrame.contains(pointer))
        XCTAssertFalse(placement.sliverFrame.contains(pointer))
        elapsed = try XCTUnwrap(scheduler.deadline)
        XCTAssertEqual(elapsed, 0.15, accuracy: 0.001)
        scheduler.fire()
        XCTAssertEqual(host.edgePresentation?.state, .sliver, "dwell starts at the first sample")
        elapsed = try XCTUnwrap(scheduler.deadline)
        XCTAssertEqual(elapsed, 0.30, accuracy: 0.001)
        scheduler.fire()
        XCTAssertEqual(host.edgePresentation?.state, .expanded)
    }

    func testIdleVisibleWidgetUsesOneSamplePerSecond() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = false; $0.followActiveDisplay = true }
        let frame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let screen = DockDisplayArea(id: "idle", frame: frame, visibleFrame: frame)
        var elapsed: TimeInterval = 0
        var auxiliarySamples = 0
        let scheduler = PointerObservationScheduler()
        let host = StaticDockPreviewHost(currentDate: { Date() }, createsNativePanels: false,
            nativeEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id,
                                       pointer: CGPoint(x: frame.midX, y: frame.midY)) },
            elapsedClock: { elapsed }, edgeScheduling: scheduler,
            pointerSampleSource: { auxiliarySamples += 1; return nil })
        defer { host.close() }
        let settings = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await settings.reload()
        host.setPresentationAllowed(true)
        XCTAssertEqual(host.edgePresentation?.state, .expanded)
        XCTAssertEqual(scheduler.deadline, 1)
        let startingSamples = auxiliarySamples
        // The placement clock is synthetic. A second production timer would
        // still have read the pointer during these 450 ms of the real run loop.
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(auxiliarySamples, startingSamples)
        for second in 1...3 {
            elapsed = TimeInterval(second)
            scheduler.fire()
            XCTAssertEqual(scheduler.deadline, elapsed + 1)
            XCTAssertEqual(auxiliarySamples, startingSamples + second)
        }
        host.setPresentationAllowed(false)
        XCTAssertNil(scheduler.deadline)
    }

    func testPreparingTheProductionCockpitWaitsForAnAdmittedSession() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .chinese; $0.theme = .night }
        let owner = CockpitConsoleOwner(bundle: root, settingsStore: store)
        let coordinator = EngineCockpitCoordinator { _ in
            XCTFail("Bundle preparation without an admitted engine session cannot build a WebView")
            throw CocoaError(.fileNoSuchFile)
        }
        owner.coordinator = coordinator
        owner.startPrewarm(applied: { nil })
        owner.releasePrewarm()
        for _ in 0..<100 where owner.appearance.locale != .zhCN {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(owner.appearance.locale, .zhCN)
        await owner.awaitPreparedBundle()
        for _ in 0..<100 where !coordinator.prewarmEnabled {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(coordinator.prewarmEnabled)
    }
}
