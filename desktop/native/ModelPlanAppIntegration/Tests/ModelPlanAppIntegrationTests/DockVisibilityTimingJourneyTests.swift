// SPDX-License-Identifier: MIT
#if DEBUG
import AppKit
import ModelPlanDock
import ModelPlanSettings
import ModelPlanResources
import XCTest
@testable import ModelPlanAppIntegration

@MainActor private final class DockVisibilityTestClock: DockEdgeScheduling {
    private(set) var now: TimeInterval = 0
    private(set) var deadline: TimeInterval?
    private var action: (@MainActor () -> Void)?

    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        self.deadline = deadline
        self.action = action
    }

    func cancel() {
        deadline = nil
        action = nil
    }

    func advance(to time: TimeInterval) {
        now = time
        guard let deadline, deadline <= time else { return }
        let next = action
        cancel()
        next?()
    }
}

@MainActor final class DockVisibilityTimingJourneyTests: XCTestCase {
    func testDockVisibilityDwellAtTheNormalEntry() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("dock-visibility-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await settings.update { $0.autoHide = true; $0.revealMilliseconds = 150 }
        let display = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 805))
        var pointer = CGPoint(x: 720, y: 450)
        let clock = DockVisibilityTestClock()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings,
            createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            activateSettings: {})
        EngineRowsEntry.installDockVisibilityTimingForChecks(on: app, clock: { clock.now }, scheduler: clock)
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()

        let dock = app.composition.dock
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, placement.sliverFrame)
        pointer = CGPoint(x: placement.wakeFrame.midX, y: placement.wakeFrame.midY)
        dock.refreshPresence()
        XCTAssertEqual(try XCTUnwrap(clock.deadline), 0.15, accuracy: 0.0001)
        clock.advance(to: 0.149)
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        clock.advance(to: 0.151)
        XCTAssertEqual(dock.edgePresentation?.state, .expanded)
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, placement.frame)

        pointer = CGPoint(x: display.visibleFrame.midX, y: display.visibleFrame.midY)
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.reveal(300))
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        pointer = CGPoint(x: placement.wakeFrame.midX, y: placement.wakeFrame.midY)
        dock.refreshPresence()
        let nextSample = try XCTUnwrap(clock.deadline)
        XCTAssertEqual(nextSample, 0.301, accuracy: 0.0001)
        clock.advance(to: nextSample)
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        XCTAssertEqual(try XCTUnwrap(clock.deadline), 0.451, accuracy: 0.0001)
        clock.advance(to: 0.450)
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        clock.advance(to: 0.452)
        XCTAssertEqual(dock.edgePresentation?.state, .expanded)
    }

    /// macrevb-1096-3 (D324): the auto-hide sliver is ordered in but shows no ring, so the resource sampler treats the
    /// widget as hidden (60 s); only the expanded widget samples every 10 s.
    func testAutoHideSliverDoesNotCountAsAShownWidget() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("dock-resource-sliver-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await settings.update { $0.autoHide = true; $0.revealMilliseconds = 150 }
        let display = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 805))
        var pointer = CGPoint(x: 720, y: 450)
        let clock = DockVisibilityTestClock()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings,
            createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            activateSettings: {})
        EngineRowsEntry.installDockVisibilityTimingForChecks(on: app, clock: { clock.now }, scheduler: clock)
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()

        final class NoReader: ResourceReader { func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? { nil } }
        let host = ResourcePluginHost(sampler: ResourceSampler(reader: NoReader(), clock: { 0 }, scheduler: { _, _, _ in ResourceTimerHandle {} }))
        var plugins = CockpitPluginPreferences()
        XCTAssertTrue(plugins.apply(.setEnabled("resources", true)))
        host.apply(plugins)
        let dock = app.composition.dock
        var reported: [Bool] = []
        dock.widgetShownChanged = { shown in reported.append(shown); host.setWidgetShown(shown) }
        host.setWidgetShown(dock.isWidgetShown)
        app.allowDockPresentation()

        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        XCTAssertFalse(dock.isWidgetShown, "the sliver shows no ring")
        XCTAssertEqual(ResourceCadence.interval(host.visibility), ResourceCadence.hidden, "sliver with the cockpit closed: 60 s")

        pointer = CGPoint(x: placement.wakeFrame.midX, y: placement.wakeFrame.midY)
        dock.refreshPresence()
        clock.advance(to: 0.151)
        XCTAssertEqual(dock.edgePresentation?.state, .expanded)
        XCTAssertTrue(dock.isWidgetShown)
        XCTAssertEqual(ResourceCadence.interval(host.visibility), ResourceCadence.widget, "expanded: 10 s")

        pointer = CGPoint(x: display.visibleFrame.midX, y: display.visibleFrame.midY)
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.reveal(300))
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        XCTAssertFalse(dock.isWidgetShown, "collapsed again to the sliver")
        XCTAssertEqual(ResourceCadence.interval(host.visibility), ResourceCadence.hidden)
        XCTAssertEqual(reported, [true, false])
    }
}
#endif
