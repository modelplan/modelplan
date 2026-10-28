// SPDX-License-Identifier: MIT
import Foundation
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
