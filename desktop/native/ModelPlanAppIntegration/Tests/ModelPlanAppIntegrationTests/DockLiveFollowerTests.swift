// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class LiveFollowerInputs {
    let screens = [DockDisplayArea(id: "main", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)),
                   DockDisplayArea(id: "next", frame: CGRect(x: 1200, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900))]
    var pointer = CGPoint(x: 500, y: 400), elapsed: TimeInterval = 0
}
@MainActor private final class LiveFollowerScheduler: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}
@MainActor final class DockLiveFollowerTests: XCTestCase {
    private func fixture() async throws -> (StaticDockPreviewHost, SettingsApplicationCoordinator, SettingsStore, LiveFollowerInputs, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("live-follower-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("settings.json"), store = try SettingsStore(url: url)
        try await store.update { $0.followActiveDisplay = true; $0.autoHide = false; $0.dockEdge = .bottom }
        let inputs = LiveFollowerInputs()
        let host = StaticDockPreviewHost(appearance: { view, rows, preferences in
            try view.applyCommunity(rows)
            view.setFrameSize(preferences.dockEdge == .bottom ? CGSize(width: 180, height: 80) : CGSize(width: 80, height: 180))
            return .init(hoverRects: [view.bounds], dragRegions: .init(body: CGPath(rect: view.bounds, transform: nil), excludedControls: []))
        }, currentDate: { Date(timeIntervalSince1970: 1_800_000_000) }, createsNativePanels: false,
            nativeEnvironment: { .init(displays: inputs.screens, layouts: [], primaryDisplayID: "main", pointer: inputs.pointer) },
            elapsedClock: { inputs.elapsed }, edgeScheduling: LiveFollowerScheduler())
        let app = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await app.reload(); host.setPresentationAllowed(true)
        return (host, app, store, inputs, url)
    }
    func testNormalHostStartsFollowsWithoutWritingAndStopsOnHideOrRetirement() async throws {
        let (host, app, _, inputs, url) = try await fixture(); defer { host.close() }
        let persisted = try Data(contentsOf: url), revision = app.latest?.snapshot.revision
        XCTAssertTrue(host.isFollowingDisplay); XCTAssertEqual(host.edgePresentation?.placement?.displayID, "main")
        inputs.pointer = CGPoint(x: 1700, y: 400); host.refreshPresence()
        XCTAssertEqual(host.edgePresentation?.placement?.displayID, "next")
        XCTAssertEqual(try Data(contentsOf: url), persisted); XCTAssertEqual(app.latest?.snapshot.revision, revision)
        host.setPresentationAllowed(false); XCTAssertFalse(host.isFollowingDisplay)
        inputs.pointer = CGPoint(x: 500, y: 400); host.refreshPresence()
        XCTAssertEqual(host.edgePresentation?.state, .suppressed(.lifecycle))
        host.setPresentationAllowed(true); XCTAssertTrue(host.isFollowingDisplay)
        XCTAssertEqual(host.edgePresentation?.placement?.displayID, "main")
        host.close(); XCTAssertFalse(host.isFollowingDisplay)
        inputs.pointer = CGPoint(x: 1700, y: 400); host.refreshPresence()
        XCTAssertEqual(host.edgePresentation?.state, .suppressed(.lifecycle)); XCTAssertNil(host.nativePanel)
        XCTAssertEqual(try Data(contentsOf: url), persisted)
    }
    func testHeldPressRefusesFollowThenRetriesAfterCancelAndFixedModeStopsFollower() async throws {
        let (host, app, store, inputs, url) = try await fixture(); defer { host.close() }
        inputs.elapsed = 1
        let persisted = try Data(contentsOf: url), initial = try XCTUnwrap(host.edgePresentation?.placement)
        let drag = try XCTUnwrap(host.dockView.backgroundDragDelegate)
        XCTAssertTrue(drag.beginBackgroundMove(local: CGPoint(x: 20, y: 20), global: CGPoint(x: initial.frame.midX, y: initial.frame.midY)))
        inputs.pointer = CGPoint(x: 1700, y: 400); host.refreshPresence()
        XCTAssertEqual(host.edgePresentation?.placement?.displayID, "main", "a held press must preserve the grab coordinate before any movement")
        drag.cancelBackgroundMove(); host.refreshPresence()
        XCTAssertEqual(host.edgePresentation?.placement?.displayID, "next", "refused follower input must be retried after cancellation")
        XCTAssertEqual(try Data(contentsOf: url), persisted, "following and cancellation are not placement commits")
        try await store.update { $0.followActiveDisplay = false; $0.dockDisplayID = "main" }
        await app.reload(); XCTAssertFalse(host.isFollowingDisplay)
        host.refreshPresence(); XCTAssertEqual(host.edgePresentation?.placement?.displayID, "main")
        XCTAssertNil(host.nativePanel)
    }
}
