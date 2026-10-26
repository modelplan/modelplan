// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanShell
@testable import ModelPlanCommunityHost

private struct NeverCLI: CLITransport {
    func execute(_ command: CLICommand) async throws -> CommandResult { throw CancellationError() }
}
@MainActor private final class FakeSettingsIntegration: CommunitySettingsIntegration {
    let settingsMenuItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: ",")
    var restores = 0, suspensions = 0
    var restored: (() -> Void)?
    func restorePreferences() async { restores += 1; restored?() }
    func suspend() { suspensions += 1 }
}
@MainActor final class CommunityHostTests: XCTestCase {
    private func gate() -> LifecycleCoordinator {
        LifecycleCoordinator(store: SnapshotStore(transport: NeverCLI(), automaticTimers: false))
    }
    func testLegacyHostDoesNotCreateASettingsIntegration() async {
        let host = CommunityDelegate(surfaces: NeutralSurfaceProvider())
        XCTAssertNil(host.configureSettings(gate()))
    }
    func testFactoryIsRetainedAndInstalledOnceAndSuspensionIsForwarded() async {
        let settings = FakeSettingsIntegration(), expected = expectation(description: "restore delivered")
        settings.restored = { expected.fulfill() }
        var creates = 0
        let lifecycle = gate()
        let host = CommunityDelegate(surfaces: NeutralSurfaceProvider()) { supplied in
            XCTAssertTrue(supplied === lifecycle); creates += 1; return settings
        }
        let first = host.configureSettings(lifecycle)
        XCTAssertTrue(first === host.configureSettings(lifecycle))
        await fulfillment(of: [expected], timeout: 2)
        host.suspendSettings()
        XCTAssertEqual(creates, 1); XCTAssertEqual(settings.restores, 1); XCTAssertEqual(settings.suspensions, 1)
    }
    func testUnavailablePreferencesFailClosedWithoutRetryOrExposingTheError() async {
        struct Unavailable: Error {}
        var creates = 0
        let host = CommunityDelegate(surfaces: NeutralSurfaceProvider()) { _ in creates += 1; throw Unavailable() }
        let first = host.configureSettings(gate())
        XCTAssertFalse(first?.isEnabled ?? true)
        XCTAssertEqual(first?.title, "Settings unavailable / 设置不可用")
        XCTAssertTrue(first === host.configureSettings(gate())); XCTAssertEqual(creates, 1)
    }
}
