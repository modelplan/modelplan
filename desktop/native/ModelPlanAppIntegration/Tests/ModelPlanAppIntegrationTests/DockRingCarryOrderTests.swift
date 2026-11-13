// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

/// G3-111 / D244 (owner 2026-11-13): a press-drag on a quota ring moves the whole widget, as in Pulse; rings no
/// longer reorder. The saved subscription order (Settings › Subscriptions) survives refresh ticks and a relaunch.
@MainActor final class DockRingCarryOrderTests: XCTestCase {
    private let first = "aaaaaaaaaaaaaaaa", second = "bbbbbbbbbbbbbbbb"

    private func launch(_ root: URL, store: SettingsStore? = nil) async throws -> (EngineDockMenuApplication, SettingsStore) {
        let settings: SettingsStore
        if let store { settings = store } else { settings = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"]) }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 55)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        return (app, settings)
    }
    /// The rings as painted, first to last along the widget.
    private func shown(_ app: EngineDockMenuApplication) -> [String] {
        let targets = app.composition.dock.interactionEnvironment().targets
        XCTAssertEqual(targets.map(\.along), targets.map(\.along).sorted(), "targets are listed in painted order")
        return targets.map(\.id)
    }

    func testG3111RingPressDragMovesTheWidgetAndKeepsTheSavedOrderThroughRefreshAndRelaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-ring-carry-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        // The order the user set in Settings › Subscriptions, saved before this launch.
        let seeded = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await seeded.update { $0.subscriptions = .init(order: [self.second, self.first]) }

        let (app, _) = try await launch(root, store: seeded)
        let dock = app.composition.dock, view = dock.dockView, editor = app.settingsHost.application.editor
        XCTAssertTrue(dock.interactionEnvironment().active)
        XCTAssertEqual(shown(app), [second, first], "the widget follows the saved order")

        // Press the first ring and drag it 150 pt along the rail, past the 5 pt click threshold.
        let start = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let anchor = try XCTUnwrap(view.interactionAnchor(second))
        let local = CGPoint(x: anchor.midX, y: anchor.midY)
        func global(_ p: CGPoint, from frame: CGRect) -> CGPoint {
            CGPoint(x: frame.minX + p.x - view.bounds.minX, y: frame.maxY - p.y + view.bounds.minY)
        }
        let down = global(local, from: start)
        let revision = try XCTUnwrap(editor.snapshot?.revision)
        // As in the other windowless press journeys, a press is accepted once the reveal has settled.
        let arrival = ContinuousClock.now + .seconds(1)
        while !view.performPointerDown(atLocal: local, global: down) {
            guard ContinuousClock.now < arrival else { return XCTFail("a press on a ring is taken") }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(dock.interactionControllerForChecks?.hasCapture, true, "the ring takes the press (a click if it does not move)")
        let pulled = CGPoint(x: down.x, y: down.y - 150)
        view.performPointerDrag(atLocal: CGPoint(x: local.x, y: local.y + 150), global: pulled)
        XCTAssertNil(dock.interactionControllerForChecks?.presentation?.reorder, "D244: a ring drag previews no order")
        XCTAssertNotEqual(dock.edgePresentation?.paintedFrame, start, "D244: the whole widget follows the ring drag")
        view.performPointerUp(atLocal: CGPoint(x: local.x, y: local.y + 150), global: pulled)
        try await waitForSettings(editor) { (editor.snapshot?.revision ?? 0) > revision && !editor.isSaving }
        let moved = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        XCTAssertLessThan(moved.midY, start.midY - 100, "the drop saved the new widget position")
        XCTAssertEqual(editor.snapshot?.preferences.subscriptions.order, [second, first], "a ring drag never writes the order")
        XCTAssertEqual(shown(app), [second, first])

        // Refresh ticks (deliveries, the presentation tick, context updates) never re-sort the members.
        dock.refreshDockContent()
        app.settingsHost.application.update(context: editor.context)
        dock.refreshDockContent()
        XCTAssertEqual(shown(app), [second, first], "a refresh keeps the saved order")

        // Keyboard reorder (Option-arrow) is kept and saves the shared order.
        let children = (view.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
        try XCTUnwrap(children.first { $0.accessibilityIdentifier() == "dock.subscription." + second }).setAccessibilityFocused(true)
        view.keyDown(with: try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.option],
            timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 125)))
        try await waitForSettings(editor) { editor.snapshot?.preferences.subscriptions.order == [self.first, self.second] && !editor.isSaving }
        dock.refreshDockContent()
        XCTAssertEqual(shown(app), [first, second])

        // Relaunch on the same profile: the saved order comes back.
        await app.composition.stop()
        let (again, reopened) = try await launch(root)
        addTeardownBlock { @MainActor in await again.composition.stop() }
        let saved = await reopened.snapshot()
        XCTAssertEqual(saved.preferences.subscriptions.order, [first, second])
        XCTAssertEqual(shown(again), [first, second], "the widget shows the saved order after a relaunch")
    }
}

/// D244: the cockpit reads the same saved order through the console owner's adopted settings, so its tabs and
/// columns follow Settings › Subscriptions; with none saved it sends none and keeps the engine order.
final class CockpitSavedOrderTests: XCTestCase {
    @MainActor func testConsoleOwnerCarriesTheSavedSubscriptionOrderToTheCockpit() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-order-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root)
        let owner = CockpitConsoleOwner(bundle: root, settingsStore: store)
        owner.adoptAppearance(await store.snapshot(), applied: nil)
        XCTAssertEqual(owner.appearance.memberOrder, [], "no saved order: the engine order")
        let saved = ["bbbbbbbbbbbbbbbb", "aaaaaaaaaaaaaaaa"]
        _ = try await store.update { $0.subscriptions = .init(order: saved) }
        owner.adoptAppearance(await store.snapshot(), applied: nil)
        XCTAssertEqual(owner.appearance.memberOrder, saved)
    }
}
