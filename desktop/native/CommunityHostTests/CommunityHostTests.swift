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
@MainActor private final class FakeCompanionSurface: CommunityCompanionSurface {
    var showConsole: (() -> Void)?
    var showSettings: (() -> Void)?
    var permissions: [Bool] = []
    var renders = 0, closes = 0
    func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) { renders += 1 }
    func setPresentationAllowed(_ allowed: Bool) { permissions.append(allowed) }
    func close() { closes += 1 }
}
@MainActor private final class MenuActionTarget: NSObject {
    var calls = 0
    @objc func open(_ sender: Any?) { calls += 1 }
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
        XCTAssertEqual(first?.title, "Settings could not open — quit and reopen ModelPlan / 设置未能打开，请退出并重新打开 ModelPlan")
        XCTAssertTrue(first === host.configureSettings(gate())); XCTAssertEqual(creates, 1)
    }
    func testCompanionInitializationDoesNotInstallCallbacksOrTouchItsPresentation() async {
        let companion = FakeCompanionSurface()
        let host = CommunityDelegate(surfaces: NeutralSurfaceProvider(), companion: companion)
        withExtendedLifetime(host) {
            XCTAssertNil(companion.showConsole); XCTAssertNil(companion.showSettings)
            XCTAssertTrue(companion.permissions.isEmpty)
            XCTAssertEqual(companion.renders, 0); XCTAssertEqual(companion.closes, 0)
        }
    }
    func testCompanionSettingsUsesTheConfiguredMenuActionAndCurrentLifecyclePermission() async {
        let companion = FakeCompanionSurface(), settings = FakeSettingsIntegration(), target = MenuActionTarget()
        settings.settingsMenuItem.target = target
        settings.settingsMenuItem.action = #selector(MenuActionTarget.open(_:))
        let lifecycle = gate()
        let host = CommunityDelegate(surfaces: NeutralSurfaceProvider(), companion: companion) { _ in settings }
        _ = host.configureSettings(lifecycle)
        host.configureCompanion(lifecycle)
        XCTAssertEqual(companion.permissions, [false])
        companion.showSettings?(); XCTAssertEqual(target.calls, 0)
        lifecycle.start()
        companion.showSettings?(); XCTAssertEqual(target.calls, 1)
        settings.settingsMenuItem.isEnabled = false
        companion.showSettings?(); XCTAssertEqual(target.calls, 1)
        settings.settingsMenuItem.isEnabled = true
        lifecycle.set(.userDisabled, blocked: true)
        companion.showSettings?(); XCTAssertEqual(target.calls, 1)
        await lifecycle.stop()
    }
    func testCommandCommaApplicationMenuSharesTheStatusActionWithoutReparentingIt() async throws {
        let host = CommunityDelegate(surfaces: NeutralSurfaceProvider()), target = MenuActionTarget()
        let statusMenu = NSMenu()
        let item = NSMenuItem(title: "Settings", action: #selector(MenuActionTarget.open(_:)), keyEquivalent: ",")
        item.target = target; item.keyEquivalentModifierMask = .command; statusMenu.addItem(item)
        let menu = host.applicationMenu(settingsItem: item)
        let applicationItem = try XCTUnwrap(menu.items.first?.submenu?.items.first)
        XCTAssertFalse(applicationItem === item)
        XCTAssertTrue(item.menu === statusMenu)
        XCTAssertTrue(applicationItem.target === target)
        XCTAssertEqual(applicationItem.keyEquivalent, ",")
        XCTAssertEqual(applicationItem.keyEquivalentModifierMask, .command)
        _ = target.perform(try XCTUnwrap(applicationItem.action), with: applicationItem)
        XCTAssertEqual(target.calls, 1)
    }

}
