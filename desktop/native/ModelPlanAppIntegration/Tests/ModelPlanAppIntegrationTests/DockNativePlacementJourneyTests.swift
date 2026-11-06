// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// Run on an admitted GUI session with a reviewed real CLI and isolated home.
@MainActor final class DockNativePlacementJourneyTests: XCTestCase {
    private final class Topology {
        var main = DockDisplayArea(id: "A", frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 0, y: 70, width: 1470, height: 860))
        var adjoining = false
        func read() -> DockEdgeEnvironment {
            let neighbour = DockDisplayArea(id: "B", frame: CGRect(x: 1470, y: -300, width: 2560, height: 1440),
                visibleFrame: CGRect(x: 1470, y: -300, width: 2560, height: 1415))
            return .init(displays: adjoining ? [main, neighbour] : [main], layouts: [], primaryDisplayID: "A")
        }
    }
    private final class Replies: EngineStoreEventSink {
        var count = 0
        func acceptedEvent(_ event: EngineClientEvent) {
            switch event {
            case .rowsChanged, .response(_, .rows): count += 1
            default: break
            }
        }
        func apply(_ snapshot: EngineStoreSnapshot) {}
        func clearPrivateViews(_ invalidation: EngineInvalidation) {}
    }
    private func make(_ root: URL, _ topology: Topology, edit: ((inout SettingsPreferences) -> Void)? = nil)
        async throws -> EngineDockMenuApplication {
        let binary = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary))
        _ = NSApplication.shared
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        if let edit { _ = try await store.update { edit(&$0) } }
        EngineRowsEntry.nativeJourneyProfile = root
        return EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: binary),
            applicationVersion: "dock-native-journey", allowedEnvironment: ["HOME": root.path, "TMPDIR": root.path],
            offline: true, readOnly: true), settingsStore: store, createsNativePanels: true,
            dockEnvironment: topology.read, activateSettings: {})
    }
    private func wait(_ seconds: Double, _ predicate: () -> Bool) async throws -> Bool {
        let end = ContinuousClock.now + .seconds(seconds)
        while !predicate(), ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(5)) }
        return predicate()
    }
    private func launch(_ app: EngineDockMenuApplication) {
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    }
    private func checkEngine(_ app: EngineDockMenuApplication) async throws {
        let ready = try await wait(5) {
            if case .ready = app.composition.store.snapshot.connection { return true }
            return false
        }
        XCTAssertTrue(ready, "The real app-server must handshake")
    }
    private func firstShow(disabled: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let topology = Topology()
        let app = try await make(root, topology)
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
            try FileManager.default.removeItem(at: root)
        }
        let replies = Replies()
        let token = app.composition.store.attach(replies)
        defer { app.composition.store.detach(token) }
        app.composition.dock.suppressJourneyOrderIn = disabled
        launch(app)
        let statusVisible = try await wait(2) { app.nativeJourneyStatusVisible }
        XCTAssertTrue(statusVisible)
        let visible = try await wait(2) { app.composition.dock.nativePanel?.isVisible == true }
        XCTAssertEqual(visible, !disabled, "The first-show predicate must reject the disabled order-in control")
        if visible {
            let panel = try XCTUnwrap(app.composition.dock.nativePanel)
            XCTAssertEqual(panel.frame.maxX, topology.main.visibleFrame.maxX, accuracy: 1)
            XCTAssertEqual(replies.count, 0)
            XCTAssertNotNil(app.composition.dock.dockView.emptyStationRectForChecks)
        }
        try await checkEngine(app)
    }
    func testD01VisibleStatusToRealPanelBeforeRowsReplies() async throws { try await firstShow(disabled: false) }
    func testD01OrderInControlRejectsFirstShow() async throws { try await firstShow(disabled: true) }

    func testD02AndD03NativePanelTracksReservationsAndKeepsEdge() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let topology = Topology()
        topology.adjoining = true
        let app = try await make(root, topology) { $0.dockEdge = .right }
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
            try FileManager.default.removeItem(at: root)
        }
        launch(app)
        try await checkEngine(app)
        let panel = try XCTUnwrap(app.composition.dock.nativePanel)
        let editor = app.settingsHost.application.editor
        for edge in [SettingsDockEdge.right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            for floor in [70.0, 4.0, 70.0] {
                topology.main = .init(id: "A", frame: topology.main.frame,
                    visibleFrame: CGRect(x: 0, y: floor, width: 1470, height: 930 - floor))
                NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
                XCTAssertTrue(panel.isVisible)
                if edge == .right { XCTAssertEqual(panel.frame.maxX, topology.main.visibleFrame.maxX, accuracy: 1) }
                else { XCTAssertEqual(panel.frame.minY, floor, accuracy: 1) }
            }
        }
    }

    func testD14NativeHideRelaunchAndShow() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let topology = Topology()
        let first = try await make(root, topology)
        addTeardownBlock { @MainActor in
            await first.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
            try FileManager.default.removeItem(at: root)
        }
        launch(first)
        try await checkEngine(first)
        let original = try XCTUnwrap(first.composition.dock.nativePanel?.frame)
        try await chooseShowQuotaWidget(first, checked: true)
        await first.stopNativeDockJourney()
        let second = try await make(root, topology)
        addTeardownBlock { @MainActor in await second.stopNativeDockJourney() }
        launch(second)
        try await checkEngine(second)
        XCTAssertFalse(second.composition.dock.nativePanel?.isVisible == true)
        let show = try XCTUnwrap(second.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" })
        _ = try XCTUnwrap(show.target as? NSObject).perform(try XCTUnwrap(show.action), with: show)
        let visible = try await wait(2) { second.composition.dock.nativePanel?.isVisible == true }
        XCTAssertTrue(visible)
        XCTAssertEqual(second.composition.dock.nativePanel?.frame, original)
        XCTAssertEqual(second.settingsHost.application.editor.snapshot?.preferences.showDock, true)
    }
}
#endif
