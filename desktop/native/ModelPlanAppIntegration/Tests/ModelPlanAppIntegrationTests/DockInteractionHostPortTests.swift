// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor private final class HostPortScheduler: DockEdgeScheduling {
    var armed = 0
    func arm(at: TimeInterval, _ action: @escaping @MainActor () -> Void) { armed += 1 }
    func cancel() {}
}

@MainActor final class DockInteractionHostPortTests: XCTestCase {
    private func host() -> StaticDockPreviewHost {
        StaticDockPreviewHost(currentDate: { Date(timeIntervalSince1970: 1_000) }, createsNativePanels: false,
            nativeEnvironment: { DockEdgeEnvironment(displays: [], layouts: []) },
            elapsedClock: { 0 }, edgeScheduling: HostPortScheduler())
    }
    func testInstallPreservesConsumerLifecycleAndOrderCallback() async {
        let host = host(); defer { host.close() }
        let scheduler = HostPortScheduler()
        var reads = 0, requests = 0
        let controller = DockInteractionController(clock: { 0 }, scheduler: scheduler, read: {
            reads += 1
            return DockInteractionEnvironment(catalogue: ["synthetic-a", "synthetic-b"],
                preferences: DockSubscriptionPreferences(), targets: [])
        })
        controller.onOrderRequest = { _ in requests += 1 }
        let port: any DockInteractionHostPort = host
        port.installInteraction(controller)
        XCTAssertEqual(reads, 0, "Installing the host port must not start the consumer's controller")
        XCTAssertEqual(scheduler.armed, 0)
        XCTAssertNil(host.dockView.nozzleEventDelegate, "Unsupported fallback must not acquire nozzle input")
        XCTAssertNotNil(controller.onPresent)
        controller.start()
        controller.moveByKeyboard(id: "synthetic-a", delta: 1)
        XCTAssertEqual(requests, 1, "Host installation must preserve the canonical order callback")
        port.uninstallInteraction(controller)
        controller.moveByKeyboard(id: "synthetic-a", delta: 1)
        XCTAssertEqual(requests, 2, "Retirement detaches the host; the consumer still owns stop")
        controller.stop()
        XCTAssertNil(host.dockView.nozzleEventDelegate)
    }
    func testUninstallChecksIdentityAndRestoresLegacyInput() async {
        let host = host(); defer { host.close() }
        var legacy = 0
        host.dockView.onAction = { _ in legacy += 1 }
        func controller() -> DockInteractionController {
            DockInteractionController(clock: { 0 }, scheduler: HostPortScheduler(), read: {
                DockInteractionEnvironment(catalogue: [], preferences: DockSubscriptionPreferences(), targets: [], active: false)
            })
        }
        let installed = controller(), other = controller()
        host.installInteraction(installed)
        let delegate = host.dockView.nozzleEventDelegate
        host.uninstallInteraction(other)
        XCTAssertTrue(host.dockView.nozzleEventDelegate === delegate)
        XCTAssertNotNil(installed.onPresent)
        host.dockView.onAction?(.overflow)
        XCTAssertEqual(legacy, 1, "Until the real projection exists, preserve the functional legacy route")
        host.uninstallInteraction(installed)
        XCTAssertNil(installed.onPresent)
        host.dockView.onAction?(.overflow)
        XCTAssertEqual(legacy, 2)
        XCTAssertFalse(host.dockView.keyboardNavigationEnabled)
        XCTAssertFalse(host.interactionEnvironment().active, "Missing production projection remains unavailable")
    }
}
