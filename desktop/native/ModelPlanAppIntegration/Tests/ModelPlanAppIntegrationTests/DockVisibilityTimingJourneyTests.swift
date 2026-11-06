// SPDX-License-Identifier: MIT
#if DEBUG
import AppKit
import ModelPlanDock
import ModelPlanSettings
import XCTest
@testable import ModelPlanAppIntegration

@MainActor final class DockVisibilityTestClock: DockEdgeScheduling {
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

    func advance(by duration: TimeInterval) {
        let end = now + duration
        while let deadline, deadline <= end {
            advance(to: deadline)
        }
        advance(to: end)
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
}
#endif
