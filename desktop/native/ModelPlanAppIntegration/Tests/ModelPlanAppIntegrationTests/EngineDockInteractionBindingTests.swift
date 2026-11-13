// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class InteractionHost: DockInteractionHostPort {
    var environment = DockInteractionEnvironment(catalogue: ["a", "b"], preferences: .init(), targets: [])
    var controller: DockInteractionController?
    func interactionEnvironment() -> DockInteractionEnvironment { environment }
    func installInteraction(_ controller: DockInteractionController) { self.controller = controller }
    func uninstallInteraction(_ controller: DockInteractionController) { if self.controller === controller { self.controller = nil } }
}
@MainActor private final class InteractionScheduler: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}
@MainActor final class EngineDockInteractionBindingTests: XCTestCase {
    func testActivationForwardsOnlyWhileBindingIsActive() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let host = InteractionHost()
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: url)) { _ in }
        await app.reload()
        let binding = EngineDockInteractionBinding(host: host, application: app, scheduler: InteractionScheduler(), clock: { 0 })
        var activated: [String] = []
        binding.onActivate = { activated.append($0) }
        binding.start()
        let controller = try XCTUnwrap(host.controller)
        controller.click("a")
        controller.click("unknown")
        XCTAssertEqual(activated, ["a"])
        binding.stop()
        controller.click("a")
        XCTAssertEqual(activated, ["a"])
    }
    func testKeyboardOrderPersistsAndRetiredControllerCannotWrite() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let host = InteractionHost()
        var context = SettingsPageContext()
        context.subscriptions = [SettingsSubscription(id: "a", name: .init("A", "A")), SettingsSubscription(id: "b", name: .init("B", "B"))]
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: url), context: context) { value in
            host.environment.preferences = value.snapshot.preferences.subscriptions
            host.environment.bindingRevision = value.snapshot.revision
        }
        await app.reload()
        let binding = EngineDockInteractionBinding(host: host, application: app, scheduler: InteractionScheduler(), clock: { 0 })
        binding.start()
        let controller = try XCTUnwrap(host.controller)
        controller.moveByKeyboard(id: "a", delta: 1)
        for _ in 0..<100 where app.editor.snapshot?.preferences.subscriptions.order != ["b", "a"] { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(app.editor.snapshot?.preferences.subscriptions.order, ["b", "a"])
        binding.stop()
        XCTAssertNil(host.controller)
        controller.moveByKeyboard(id: "a", delta: -1)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(app.editor.snapshot?.preferences.subscriptions.order, ["b", "a"])
    }
    func testStaleHostPreferencesCannotCommitOrder() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let host = InteractionHost()
        var context = SettingsPageContext()
        context.subscriptions = [SettingsSubscription(id: "a", name: .init("A", "A")), SettingsSubscription(id: "b", name: .init("B", "B"))]
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: url), context: context) { _ in }
        await app.reload()
        host.environment.preferences = .init(hiddenIDs: ["b"])
        let binding = EngineDockInteractionBinding(host: host, application: app, scheduler: InteractionScheduler(), clock: { 0 })
        binding.start()
        let controller = try XCTUnwrap(host.controller)
        controller.moveByKeyboard(id: "a", delta: 1)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(app.editor.snapshot?.preferences.subscriptions.order, [])
        binding.stop()
    }

    func testBindingStartsBeforeHostIsActiveAndRecoversWhenItBecomesActive() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let host = InteractionHost(); host.environment.active = false
        var context = SettingsPageContext()
        context.subscriptions = [SettingsSubscription(id: "a", name: .init("A", "A")), SettingsSubscription(id: "b", name: .init("B", "B"))]
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: url), context: context) { value in
            host.environment.preferences = value.snapshot.preferences.subscriptions
        }
        await app.reload()
        let binding = EngineDockInteractionBinding(host: host, application: app, scheduler: InteractionScheduler(), clock: { 0 })
        binding.start()
        let controller = try XCTUnwrap(host.controller)
        XCTAssertFalse(controller.isActive)
        controller.moveByKeyboard(id: "a", delta: 1)
        XCTAssertEqual(app.editor.snapshot?.preferences.subscriptions.order, [])
        host.environment.active = true
        controller.refresh(); XCTAssertTrue(controller.isActive)
        controller.moveByKeyboard(id: "a", delta: 1)
        for _ in 0..<100 where app.editor.snapshot?.preferences.subscriptions.order != ["b", "a"] { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(app.editor.snapshot?.preferences.subscriptions.order, ["b", "a"], "A later active host must accept input without restarting the app")
        host.environment.active = false
        controller.refresh(); XCTAssertFalse(controller.isActive)
        controller.moveByKeyboard(id: "b", delta: 1)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(app.editor.snapshot?.preferences.subscriptions.order, ["b", "a"], "Inactive input must not write")
        host.environment.active = true
        controller.refresh(); XCTAssertTrue(controller.isActive)
        controller.moveByKeyboard(id: "b", delta: 1)
        for _ in 0..<100 where app.editor.snapshot?.preferences.subscriptions.order != ["a", "b"] { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(app.editor.snapshot?.preferences.subscriptions.order, ["a", "b"], "Reactivation must restore input")
        binding.stop()
        XCTAssertFalse(controller.isRunning)
    }

}
