// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanSettings
import ModelPlanDock
import ModelPlanCore
import ModelPlanCommunityHost
@testable import ModelPlanAppIntegration

@MainActor final class ProductionApplicationFactoryTests: XCTestCase {
    private actor NoConsentTransport: CLITransport, ConsentJSONTransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { throw TransportError.launchFailed }
        func readConsentJSON() async throws -> CommandResult { throw TransportError.launchFailed }
        func grantConsentJSON(_ payload: Data) async throws -> CommandResult { throw TransportError.launchFailed }
    }
    private final class Companion: CommunityCompanionSurface {
        var showConsole: (() -> Void)?, showSettings: (() -> Void)?
        func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {}
        func setPresentationAllowed(_ allowed: Bool) {}
        func close() {}
    }
    func testNormalEntryFactoryRetainsItsRequiredCompanionWithoutLaunching() {
        let companion = Companion()
        let port = CommunityCLIConsentPort(transport: NoConsentTransport())
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: NoConsentTransport(), normal: NoConsentTransport()))
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: CommunityInstrumentSurfaceProvider(), companion: companion, consentBackend: backend) { _ in
            XCTFail("Construction must not open Settings")
            throw TransportError.launchFailed
        }
        // Inspect the actual delegate returned by the production factory, not a parallel fixture.
        let stored = Mirror(reflecting: delegate).children.first { $0.label == "companion" }?.value
        let unwrapped = stored.flatMap { Mirror(reflecting: $0).children.first?.value }
        XCTAssertTrue((unwrapped as AnyObject?) === companion, "Removing companion forwarding must fail this wiring check")
    }
    func testActualProductionDockAndSettingsFactoriesInstallSamePlacementSubscriber() async throws {
        let dock = ProductionDockFactory.community()
        defer { dock.close() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("production-placement-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let application = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { dock.apply($0) }
        let base = CommunitySettingsSession(application: application, canPresent: { false })
        let transport = NoConsentTransport()
        let backend = CommunityConnectionBackend(port: CommunityCLIConsentPort(transport: transport), desktop: .init(readOnly: transport, normal: transport))
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: application, backend: backend,
            placementSource: dock, canPresent: { false })
        defer { entry.flow.dispose() }
        XCTAssertEqual(dock.purpose, .production)
        XCTAssertNotNil(dock.onPlacementObserved, "the actual production factory must install the callback")
        XCTAssertTrue(entry.flow.application === application)
        await application.reload()
        let before = try XCTUnwrap(application.latest).snapshot
        try CommunityDockPlacementFacts.requireSynchronized(nil, recovering: false, application: application)
        let area = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let layout = DockEdgeLayout(displayID: "fixture", edge: .left, expandedSize: CGSize(width: 60, height: 200),
            sliverLength: 100, sliverThickness: 4, hoverRects: [CGRect(x: 0, y: 0, width: 60, height: 200)])
        let fact = try XCTUnwrap(DockEdgeGeometry.resolve(preference: .init(displayID: "fixture", edge: .left),
            displays: [.init(id: "fixture", frame: area, visibleFrame: area)], layouts: [layout], pointer: nil, primaryID: "fixture"))
        dock.onPlacementObserved?(fact, true)
        try CommunityDockPlacementFacts.requireSynchronized(fact, recovering: true, application: application)
        XCTAssertEqual(application.editor.context.dockPlacementObservation?.edge, .left)
        XCTAssertEqual(application.latest?.snapshot.revision, before.revision)
        XCTAssertEqual(application.latest?.snapshot.preferences.dockEdge, before.preferences.dockEdge)
        dock.onPlacementObserved?(nil, false)
        XCTAssertNil(application.editor.context.dockPlacementObservation)
        dock.close()
        XCTAssertNil(dock.nativePanel, "construction must not open a panel or read an account")
    }

}
