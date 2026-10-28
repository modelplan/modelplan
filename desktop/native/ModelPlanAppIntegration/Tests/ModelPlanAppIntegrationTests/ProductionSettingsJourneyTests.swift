// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class ProductionSettingsJourneyTests: XCTestCase {
    private actor Desktop: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { throw TransportError.launchFailed }
    }
    private final class Port: CommunityConsentCommandPort {
        var availability: SettingsConnectionAvailability = .unverified
        var reads = 0, grants = 0, granted = false
        func readCanonicalConsent() async throws -> ConsentPreview {
            reads += 1
            return try FeedDecoder.consentPreview(Data("""
            {"generation":\(granted ? 2 : 1),"consentTextVersion":2,"mode":"automatic","consentText":{"en":"Synthetic consent","zh":"合成授权"},"tools":[{"id":"codex","displayName":"Codex","accessClass":"standard","detected":true,"allowed":\(granted),"backend":"native","readerId":"native:codex","keychain":"unset","hosts":["example.test"]}]}
            """.utf8))
        }
        func applyConsentJSON(_ payload: Data) async throws {
            let value = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
            XCTAssertEqual(value["allow"] as? [String], ["codex"])
            XCTAssertEqual(value["deny"] as? [String], [])
            XCTAssertEqual((value["keychain"] as? [String: String])?.count, 0)
            grants += 1; granted = true
        }
    }
    private final class Placement: CommunityPlacementProducing {
        var onPlacementObserved: ((DockEdgePlacement?, Bool) -> Void)?
    }
    private final class Surface: SettingsWindowSurface {
        var panes: [String?] = []
        func prepare() async {}
        func show(paneID: String?) { panes.append(paneID) }
        func hide() {}
    }
    private final class Scheduler: DockEdgeScheduling {
        func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
        func cancel() {}
    }
    private func store() throws -> SettingsStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("production-settings-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try SettingsStore(url: root.appendingPathComponent("settings.json"))
    }
    private func backend(_ port: Port) -> CommunityConnectionBackend {
        let transport = Desktop()
        return .init(port: port, desktop: .init(readOnly: transport, normal: transport))
    }
    func testFactoryRestoresSameEditorAndOnlyExplicitConfirmationGrantsOnce() async throws {
        let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
        let port = Port(); port.availability = .init(canInspect: true, canGrant: true, canForget: true)
        let backend = backend(port), firstRun = Surface()
        let base = CommunitySettingsSession(application: app, canPresent: { true }, activate: {}, makeSurface: { _ in XCTFail("Unexpected settings surface"); return Surface() })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend,
            placementSource: Placement(), canPresent: { true }, makeFirstRun: { editor in
                XCTAssertTrue(editor === app.editor); return firstRun
            })
        var canonicalDeliveries = 0
        backend.onCanonicalReadback = { _ in canonicalDeliveries += 1 }
        await entry.restorePreferences()
        XCTAssertEqual(firstRun.panes.count, 1); XCTAssertEqual(port.reads, 1); XCTAssertEqual(port.grants, 0)
        let snapshot = try XCTUnwrap(app.editor.connections.snapshot)
        let intent = SettingsConnectionIntent(snapshot: snapshot)
        XCTAssertEqual(intent.orderedTools, [.codex]); XCTAssertEqual(port.grants, 0)
        let confirmation = try XCTUnwrap(app.editor.connections.requestAllow(intent))
        XCTAssertEqual(port.grants, 0)
        await app.editor.connections.confirm(confirmation.id)
        await app.editor.connections.confirm(confirmation.id)
        XCTAssertEqual(port.grants, 1); XCTAssertEqual(port.reads, 3)
        XCTAssertEqual(canonicalDeliveries, 2, "Only inspected and committed canonical readback reach the refresh hook")
        XCTAssertEqual(app.editor.connections.snapshot?.consentGeneration, 2)
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.authorization, .allowed)
        entry.flow.dispose()
    }
    func testUnavailableRealBackendMenuHasHumanReasonAndReachesSameLocalAbout() async throws {
        let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
        let port = Port(), surface = Surface(), firstRun = Surface()
        let base = CommunitySettingsSession(application: app, canPresent: { true }, activate: {}, makeSurface: { editor in
            XCTAssertTrue(editor === app.editor); return surface
        })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(port),
            placementSource: Placement(), canPresent: { true }, makeFirstRun: { _ in firstRun })
        await entry.restorePreferences()
        entry.updateUsageState(snapshot: nil, diagnostics: .init(), now: Date())
        XCTAssertEqual(entry.currentUsageNextStep?.destination, .about)
        XCTAssertTrue(entry.currentUsageMessage.chinese.contains("关于"))
        XCTAssertFalse(entry.usageAccessMenuItem.title.contains("Request unavailable"))
        let target = try XCTUnwrap(entry.usageAccessMenuItem.target as? NSObject)
        let action = try XCTUnwrap(entry.usageAccessMenuItem.action)
        _ = target.perform(action, with: entry.usageAccessMenuItem)
        for _ in 0..<1000 where surface.panes.isEmpty { await Task.yield() }
        XCTAssertEqual(surface.panes.count, 1); XCTAssertEqual(surface.panes.first ?? nil, "about")
        XCTAssertEqual(port.reads, 0); XCTAssertEqual(port.grants, 0)
        XCTAssertEqual(firstRun.panes.count, 1)
        entry.flow.dispose()
    }
    func testActualHostThroughSameFactoryKeepsObservedPlacementSynchronizedWithoutPersistingRecovery() async throws {
        let store = try store()
        try await store.update { $0.dockDisplayID = "missing"; $0.dockEdge = .right; $0.dockAlongFraction = 0.75 }
        let before = await store.snapshot()
        let screen = DockDisplayArea(id: "fixture", frame: .init(x: 0, y: 0, width: 1200, height: 900), visibleFrame: .init(x: 0, y: 0, width: 1200, height: 900))
        let host = StaticDockPreviewHost(appearance: { view, rows, _ in
            try view.applyCommunity(rows); view.setFrameSize(.init(width: 80, height: 180))
            return .init(hoverRects: [view.bounds])
        }, currentDate: { Date(timeIntervalSince1970: 1_800_000_000) }, createsNativePanels: false,
        nativeEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "fixture") }, elapsedClock: { 0 }, edgeScheduling: Scheduler(), purpose: .production)
        defer { host.close() }
        XCTAssertEqual(host.purpose, .production)
        let app = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(Port()), placementSource: host, canPresent: { false })
        await entry.restorePreferences(); host.setPresentationAllowed(true)
        let placement = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertNoThrow(try CommunityDockPlacementFacts.requireSynchronized(placement, recovering: true, application: app))
        XCTAssertEqual(app.editor.context.dockPlacementObservation?.displayID, "fixture")
        host.setPresentationAllowed(false)
        XCTAssertNil(app.editor.context.dockPlacementObservation)
        let after = await store.snapshot()
        XCTAssertEqual(after.revision, before.revision)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(after.preferences), try encoder.encode(before.preferences), "Observed recovery must never rewrite the saved preferred display/edge/fraction")
        XCTAssertNil(host.nativePanel)
        entry.flow.dispose()
    }
}
