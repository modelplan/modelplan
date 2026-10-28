// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class PlacementProducerScheduler: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class DockPlacementProducerTests: XCTestCase {
    private func temporaryURL() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("placement-producer-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("settings.json")
    }
    func testInMemoryHostPublishesCurrentFactsDeduplicatesAndClearsRetirement() async throws {
        let url = temporaryURL(), store = try SettingsStore(url: url)
        try await store.update { $0.dockEdge = .right; $0.dockDisplayID = "main" }
        let persisted = try Data(contentsOf: url)
        var screens = [DockDisplayArea(id: "main", frame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                                      visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))]
        var now: TimeInterval = 0
        let host = StaticDockPreviewHost(appearance: { view, rows, _ in
            try view.applyCommunity(rows); view.setFrameSize(CGSize(width: 80, height: 180))
            return .init(hoverRects: [view.bounds])
        }, currentDate: { Date(timeIntervalSince1970: 1_800_000_000) }, createsNativePanels: false,
        nativeEnvironment: { .init(displays: screens, layouts: [], primaryDisplayID: "main", pointer: CGPoint(x: 500, y: 400)) },
        elapsedClock: { now }, edgeScheduling: PlacementProducerScheduler())
        defer { host.close() }
        let app = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        var facts: [(DockEdgePlacement?, Bool)] = []
        host.onPlacementObserved = { facts.append(($0, $1)) }
        XCTAssertEqual(facts.count, 1, "new observer must immediately receive unknown before a presentation")
        XCTAssertNil(facts.last?.0); XCTAssertFalse(try XCTUnwrap(facts.last?.1))
        await app.reload(); let before = try XCTUnwrap(app.latest).snapshot
        host.setPresentationAllowed(true)
        let current = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertEqual(try XCTUnwrap(facts.last).0, current)
        XCTAssertEqual(current.edge, .right); XCTAssertFalse(try XCTUnwrap(facts.last?.1))
        let stable = facts.count
        for _ in 0..<8 { now += 0.15; host.refreshPresence() }
        host.render(snapshot: nil, diagnostics: .init())
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(facts.count, stable, "same facts from samples, rerender and topology notifications are deduplicated")
        var late: [(DockEdgePlacement?, Bool)] = []
        host.onPlacementObserved = { late.append(($0, $1)) }
        XCTAssertEqual(late.count, 1); XCTAssertEqual(late.last?.0, current)
        screens = []
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(late.count, 2); XCTAssertNil(late.last?.0); XCTAssertEqual(late.last?.1, false)
        host.refreshPresence(); XCTAssertEqual(late.count, 2)
        screens = [.init(id: "main", frame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                         visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(late.last?.0, current)
        host.setPresentationAllowed(false)
        XCTAssertNil(late.last?.0); XCTAssertEqual(late.last?.1, false)
        host.setPresentationAllowed(true); XCTAssertEqual(late.last?.0, current)
        host.close(); XCTAssertNil(late.last?.0); XCTAssertEqual(late.last?.1, false)
        let closed = late.count
        host.refreshPresence(); host.render(snapshot: nil, diagnostics: .init())
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(late.count, closed)
        XCTAssertEqual(try XCTUnwrap(app.latest).snapshot.revision, before.revision)
        XCTAssertEqual(try Data(contentsOf: url), persisted, "observations never write durable preferences")
        XCTAssertNil(host.nativePanel)
    }

    func testMissingPreferredDisplayReportsRecoveryWithoutChangingIntent() async throws {
        let url = temporaryURL(), store = try SettingsStore(url: url)
        try await store.update { $0.dockDisplayID = "disconnected"; $0.dockEdge = .right; $0.dockAlongFraction = 0.75 }
        let persisted = try Data(contentsOf: url)
        let display = DockDisplayArea(id: "main", frame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                                      visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))
        let host = StaticDockPreviewHost(appearance: { view, rows, _ in
            try view.applyCommunity(rows); view.setFrameSize(CGSize(width: 80, height: 180))
            return .init(hoverRects: [view.bounds])
        }, currentDate: { Date() }, createsNativePanels: false,
        nativeEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "main") },
        elapsedClock: { 0 }, edgeScheduling: PlacementProducerScheduler())
        defer { host.close() }
        let app = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        var observed: DockEdgePlacement?, recovering = false
        host.onPlacementObserved = { observed = $0; recovering = $1 }
        await app.reload(); host.setPresentationAllowed(true)
        XCTAssertEqual(observed, host.edgePresentation?.placement)
        XCTAssertEqual(observed?.displayID, "main"); XCTAssertTrue(recovering)
        XCTAssertEqual(app.latest?.snapshot.preferences.dockDisplayID, "disconnected")
        XCTAssertEqual(app.latest?.snapshot.preferences.dockAlongFraction, 0.75)
        XCTAssertEqual(try Data(contentsOf: url), persisted)
    }
    func testFollowedDisplaySwitchIsNotRecoveryAndClampingIsReported() async throws {
        for fraction in [0.5, 0.99] {
            let url = temporaryURL(), store = try SettingsStore(url: url)
            try await store.update { $0.followActiveDisplay = true; $0.dockEdge = .bottom; $0.dockAlongFraction = fraction }
            let persisted = try Data(contentsOf: url)
            let screens = [DockDisplayArea(id: "main", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)),
                           DockDisplayArea(id: "next", frame: CGRect(x: 1200, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900))]
            var pointer = CGPoint(x: 500, y: 400)
            let host = StaticDockPreviewHost(appearance: { view, rows, _ in
                try view.applyCommunity(rows); view.setFrameSize(CGSize(width: 180, height: 80))
                return .init(hoverRects: [view.bounds])
            }, currentDate: { Date() }, createsNativePanels: false,
            nativeEnvironment: { .init(displays: screens, layouts: [], primaryDisplayID: "main", pointer: pointer) },
            elapsedClock: { 0 }, edgeScheduling: PlacementProducerScheduler())
            defer { host.close() }
            let app = SettingsApplicationCoordinator(store: store) { host.apply($0) }
            var facts: [(DockEdgePlacement?, Bool)] = []
            host.onPlacementObserved = { placement, recovering in
                facts.append((placement, recovering))
                // A consumer can synchronously cause a presentation/context refresh.
                if placement != nil { host.render(snapshot: nil, diagnostics: .init()) }
            }
            await app.reload(); host.setPresentationAllowed(true)
            XCTAssertEqual(facts.count, 2, "reentrant consumer must not redeliver the same fact")
            XCTAssertEqual(facts.last?.0?.displayID, "main"); XCTAssertEqual(facts.last?.1, fraction != 0.5)
            pointer = CGPoint(x: 1700, y: 400); host.refreshPresence()
            XCTAssertEqual(facts.count, 3); XCTAssertEqual(facts.last?.0?.displayID, "next")
            XCTAssertEqual(facts.last?.1, fraction != 0.5, "ordinary follow-mode display switches are not recovery")
            XCTAssertEqual(try Data(contentsOf: url), persisted)
        }
    }

}
