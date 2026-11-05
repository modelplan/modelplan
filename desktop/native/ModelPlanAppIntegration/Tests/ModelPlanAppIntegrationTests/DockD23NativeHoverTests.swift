// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY
import AppKit
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import XCTest
@testable import ModelPlanAppIntegration

/// Operator-driven native panel observation, for an admitted D-23 device session.
@MainActor final class DockD23NativeHoverTests: XCTestCase {
    func testD23PhysicalHoverUsesActualNativeWindowBounds() async throws {
        _ = NSApplication.shared
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return XCTFail("Start with macOS Reduce Motion off to verify the default subtle mode")
        }
        let environment = ProcessInfo.processInfo.environment
        let edge = try XCTUnwrap(SettingsDockEdge(rawValue: environment["MODELPLAN_DOCK_D23_EDGE"] ?? "right"))
        let size = try XCTUnwrap(SettingsSize(rawValue: environment["MODELPLAN_DOCK_D23_SIZE"] ?? "large"))
        let orientations: [SettingsDockEdge: DockEdge] = [.left: .left, .right: .right, .bottom: .bottom]
        let orientation = try XCTUnwrap(orientations[edge])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d23-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let defaults = await store.snapshot()
        XCTAssertTrue(defaults.preferences.showPercentages)
        XCTAssertEqual(defaults.preferences.magnification, .subtle)
        _ = try await store.update { $0.dockEdge = edge; $0.size = size; $0.autoHide = false }
        let rows = try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 55)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let previousIsolation = EngineRowsEntry.isolateNativeJourneyNotifications
        EngineRowsEntry.isolateNativeJourneyNotifications = true
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic-d23", allowedEnvironment: [:]), settingsStore: store,
            createsNativePanels: true, bundleURL: root.appendingPathComponent("Synthetic.app"), deadlineNow: { now },
            makeClient: { _, engine in EntrySyntheticClient(store: engine, rows: rows) }, activateSettings: {})
        EngineRowsEntry.isolateNativeJourneyNotifications = previousIsolation
        addTeardownBlock { @MainActor in
            await app.stopLifecycle()
            await app.composition.stop()
        }
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        await app.composition.start()

        let host = app.composition.dock
        let panel = try XCTUnwrap(host.nativePanel)
        let editor = app.settingsHost.application.editor
        let ids = ["aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb"]
        let ready = try await wait(.seconds(10)) {
            panel.isVisible && panel.occlusionState.contains(.visible) && host.edgePresentation?.placement?.edge == orientation &&
                ids.allSatisfy { host.dockView.helpReadoutAnchor($0) != nil }
        }
        guard ready else { return XCTFail("Requested edge must be available on the physical screen") }
        let container = try XCTUnwrap(panel.contentView)
        let view = try XCTUnwrap(container.subviews.compactMap { $0 as? DockInstrumentView }.first)
        let initialFrame = panel.frame
        let initialViewFrame = view.frame

        func screenRect(_ local: CGRect) -> CGRect { panel.convertToScreen(view.convert(local, to: nil)) }
        let restingReadouts = try ids.map { id in screenRect(try XCTUnwrap(view.helpReadoutAnchor(id))) }
        let restingNozzles = try ids.map { id in screenRect(try XCTUnwrap(view.interactionAnchor(id))) }
        XCTAssertTrue(restingReadouts.allSatisfy { !$0.isEmpty && panel.frame.contains($0) })
        let modes: [(String, HoverMagnification?, Bool, CGFloat?)] = [
            ("default subtle", nil, false, 1.15), ("none", HoverMagnification.none, false, nil),
            ("strong", .strong, false, 1.5), ("Reduce Motion", nil, true, nil),
        ]

        for (label, magnification, reduced, scale) in modes {
            if let magnification { _ = try await editor.commit(SettingsB21Edit.magnification(magnification)) }
            if reduced { _ = try await editor.commit(SettingsB20Edit.motion(.on)) }
            for (index, id) in ids.enumerated() {
                announce("\(label): move clear of the panel before hovering nozzle \(index + 1).")
                guard try await wait(.seconds(30), until: {
                    !panel.frame.contains(NSEvent.mouseLocation) && view.nozzlePosesForChecks.isEmpty
                }) else { return XCTFail("Pointer or previous nozzle pose did not clear") }
                announce("\(label): hover nozzle \(index + 1) at \(restingNozzles[index]); hold for the recording.")
                let entered = try await wait(.seconds(30)) {
                    restingNozzles[index].contains(NSEvent.mouseLocation) && (scale == nil ||
                        view.nozzlePosesForChecks[id]?.scale == scale)
                }
                guard entered else { return XCTFail("No real hover at \(label), nozzle \(index + 1)") }
                try await Task.sleep(for: .milliseconds(450))
                XCTAssertTrue(panel.isVisible && panel.occlusionState.contains(.visible))
                XCTAssertEqual(panel.frame, initialFrame)
                XCTAssertEqual(view.frame, initialViewFrame)
                XCTAssertEqual(try ids.map { screenRect(try XCTUnwrap(view.helpReadoutAnchor($0))) }, restingReadouts)
                XCTAssertEqual(try ids.map { screenRect(try XCTUnwrap(view.interactionAnchor($0))) }, restingNozzles)
                if let scale {
                    let pose = try XCTUnwrap(view.nozzlePosesForChecks[id])
                    XCTAssertEqual(pose.scale, scale)
                    if scale == 1.15 { XCTAssertEqual(hypot(pose.offset.x, pose.offset.y), 6, accuracy: 0.001) }
                    let visibleContent = panel.convertToScreen(container.convert(container.visibleRect, to: nil))
                    let visibleScreen = try XCTUnwrap(panel.screen?.visibleFrame)
                    for (posedID, transform) in view.nozzlePosesForChecks {
                        let anchor = try XCTUnwrap(view.interactionAnchor(posedID))
                        let width = anchor.width * transform.scale, height = anchor.height * transform.scale
                        let posed = CGRect(x: anchor.midX + transform.offset.x - width / 2,
                                           y: anchor.midY + transform.offset.y - height / 2, width: width, height: height)
                        XCTAssertTrue(view.visibleRect.contains(posed), "\(label): view clips \(posed)")
                        let presented = screenRect(posed)
                        XCTAssertTrue(visibleContent.contains(presented), "\(label): native content view clips \(presented)")
                        XCTAssertTrue(panel.frame.contains(presented), "\(label): native panel clips \(presented)")
                        XCTAssertTrue(visibleScreen.insetBy(dx: -1, dy: -1).contains(presented),
                                      "\(label): screen usable bounds clip \(presented)")
                    }
                } else {
                    XCTAssertTrue(view.nozzlePosesForChecks.isEmpty, label)
                }
                announce("\(label), nozzle \(index + 1): assertions complete. Hold for capture.")
                try await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func wait(_ duration: Duration, until condition: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + duration
        while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        return condition()
    }

    private func announce(_ instruction: String) {
        FileHandle.standardOutput.write(Data(("D-23: " + instruction + "\n").utf8))
    }
}
#endif
