// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanSettings
import ModelPlanAppIntegration

@MainActor final class ProductionSettingsFactoryTests: XCTestCase {
    private actor Desktop: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { throw TransportError.launchFailed }
    }
    private final class CommandPort: CommunityConsentCommandPort {
        func readCanonicalConsent() async throws -> ConsentPreview { XCTFail("Construction must not read accounts"); throw SettingsConnectionFailure.unavailable }
        func applyConsentJSON(_ payload: Data) async throws { XCTFail("Construction must not grant") }
    }
    func testActualFactoryInstallsSameBackendIntoSameApplicationAndRefusesDisconnectedEntry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let desktop = Desktop()
        let backend = CommunityConnectionBackend(port: CommandPort(), desktop: .init(readOnly: desktop, normal: desktop))
        XCTAssertThrowsError(try CommunityConnectionWiring.requireInstalled(base, application: app, backend: backend))
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        try CommunityConnectionWiring.requireInstalled(entry, application: app, backend: backend)
        XCTAssertTrue(entry.flow.application === app)
        entry.flow.dispose()
    }
}
