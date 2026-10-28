// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import ModelPlanDock
import ModelPlanShell
import XCTest
import ModelPlanCore
import ModelPlanCommunityHost
import ModelPlanAppIntegration
import ModelPlanSettings

@MainActor final class ProductionApplicationFactoryTests: XCTestCase {
    private final class Companion: CommunityCompanionSurface {
        var showConsole: (() -> Void)?, showSettings: (() -> Void)?
        func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {}
        func setPresentationAllowed(_ allowed: Bool) {}
        func close() {}
    }
    private actor Desktop: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { XCTFail("Construction must not execute helper"); throw TransportError.launchFailed }
    }
    private final class ConsentPort: CommunityConsentCommandPort {
        func readCanonicalConsent() async throws -> ConsentPreview { XCTFail("Construction must not inspect consent"); throw SettingsConnectionFailure.unavailable }
        func applyConsentJSON(_ payload: Data) async throws { XCTFail("Construction must not grant") }
    }
    private final class Placement: CommunityPlacementProducing {
        var onPlacementObserved: ((DockEdgePlacement?, Bool) -> Void)?
    }
    func testRetainedSettingsInspectionUsesTheActualFactoryBackendAndUnavailableCapability() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("retained-settings-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let desktop = Desktop(), companion = Companion()
        let backend = CommunityConnectionBackend(port: ConsentPort(), desktop: .init(readOnly: desktop, normal: desktop))
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend,
            placementSource: Placement(), canPresent: { false })
        defer { entry.flow.dispose() }
        var constructions = 0
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: CommunityInstrumentSurfaceProvider(), companion: companion,
            consentBackend: backend) { _ in constructions += 1; return entry }
        XCTAssertNil(delegate.settingsIntegration)
        let lifecycle = LifecycleCoordinator(store: SnapshotStore(transport: desktop))
        XCTAssertNotNil(delegate.configureSettings(lifecycle))
        let retained = try XCTUnwrap(delegate.settingsIntegration as? CommunityConnectionIntegration)
        XCTAssertTrue(retained === entry)
        XCTAssertTrue(retained.flow.application === app)
        try CommunityConnectionWiring.requireInstalled(retained, application: app, backend: backend)
        let connections = retained.flow.application.editor.connections
        XCTAssertTrue(connections.hasAllowanceBackend)
        XCTAssertTrue(connections.isBound(to: backend))
        XCTAssertEqual(connections.availability, .unverified)
        XCTAssertEqual(backend.settingsConnectionAvailability, .unverified)
        XCTAssertFalse(connections.availability.canInspect)
        XCTAssertFalse(connections.availability.canGrant)
        XCTAssertFalse(connections.availability.canForget)
        XCTAssertTrue(try XCTUnwrap(delegate.companionSurface) === companion)
        delegate.configureSettings(lifecycle)
        XCTAssertEqual(constructions, 1, "Inspection must not construct a parallel editor/backend or invoke the factory twice")
        await retained.restorePreferences()
    }
    func testRetainedInspectionDoesNotInventAMissingCompanionOrFailedSettingsService() {
        let desktop = Desktop()
        let delegate = CommunityDelegate(surfaces: CommunityInstrumentSurfaceProvider(), transport: desktop) { _ in
            throw SettingsConnectionFailure.unavailable
        }
        XCTAssertNil(delegate.companionSurface)
        XCTAssertNil(delegate.settingsIntegration)
        let item = delegate.configureSettings(LifecycleCoordinator(store: SnapshotStore(transport: desktop)))
        XCTAssertEqual(item?.isEnabled, false)
        XCTAssertTrue(item?.title.contains("quit and reopen ModelPlan") == true)
        XCTAssertFalse(item?.title.contains("unavailable") == true)
        XCTAssertNil(delegate.settingsIntegration)
    }
    func testNormalEntryFactoryRetainsItsRequiredCompanionWithoutLaunching() {
        let companion = Companion()
        let desktop = Desktop()
        let backend = CommunityConnectionBackend(port: ConsentPort(), desktop: .init(readOnly: desktop, normal: desktop))
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: CommunityInstrumentSurfaceProvider(), companion: companion, consentBackend: backend) { _ in
            XCTFail("Construction must not open Settings")
            throw TransportError.launchFailed
        }
        // Inspect the actual delegate returned by the production factory, not a parallel fixture.
        let stored = Mirror(reflecting: delegate).children.first { $0.label == "companion" }?.value
        let unwrapped = stored.flatMap { Mirror(reflecting: $0).children.first?.value }
        XCTAssertTrue((unwrapped as AnyObject?) === companion, "Removing companion forwarding must fail this wiring check")
        XCTAssertNotNil(backend.onCanonicalReadback, "Production composition must route readback to the existing delegate")
    }
}
