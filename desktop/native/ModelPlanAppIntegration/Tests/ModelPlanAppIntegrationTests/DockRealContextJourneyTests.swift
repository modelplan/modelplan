// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_CONTEXT_JOURNEY
import AppKit
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import XCTest
@testable import ModelPlanAppIntegration

@MainActor final class DockRealContextJourneyTests: XCTestCase {
    func testD13BilingualCardAndMenuUseTheRealServerDelivery() async throws {
        let helper = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d13-real-context-" + UUID().uuidString)
        let config = root.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        let initConsent = Process()
        initConsent.executableURL = helper; initConsent.arguments = ["consent", "init", "--json"]
        initConsent.environment = environment
        initConsent.standardInput = FileHandle.nullDevice
        initConsent.standardOutput = FileHandle.nullDevice
        initConsent.standardError = FileHandle.nullDevice
        try initConsent.run()
        let seedDeadline = ContinuousClock.now + .seconds(5)
        while initConsent.isRunning && ContinuousClock.now < seedDeadline { try await Task.sleep(for: .milliseconds(10)) }
        if initConsent.isRunning { initConsent.terminate(); return XCTFail("Synthetic consent initialization timed out") }
        XCTAssertEqual(initConsent.terminationStatus, 0)

        let now = Date(), iso = ISO8601DateFormatter(), plan = "synthetic-d13"
        let fixture: [String: Any] = ["schemaVersion": 1, "plans": [["planId": plan]], "windows": [[
            "planId": plan, "kind": "five_hour", "remainingPercent": 57, "resetMode": "rolling",
            "observedAt": iso.string(from: now.addingTimeInterval(-20)),
            "resetAt": iso.string(from: now.addingTimeInterval(7_200))
        ]]]
        try JSONSerialization.data(withJSONObject: fixture).write(to: config.appendingPathComponent("local.json"), options: .atomic)

        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.autoHide = false; $0.motion = .on }
        let settingsSurface = TestSettingsSurface()
        var builds = 0
        var pointer = CGPoint(x: 1430, y: 475), cardFrame: CGRect?
        var elapsed = 0.0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-d13",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"), dockEnvironment: {
                var facts = normalEntryTestEnvironment()
                facts.pointer = pointer
                facts.cardFrame = cardFrame
                return facts
            }, deadlineElapsed: { elapsed }, makeSettingsSurface: { _ in builds += 1; return settingsSurface },
            activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        let wire = try XCTUnwrap(app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "declared:" + plan })
        XCTAssertEqual(wire.accounts.first?.windows.first?.remainingPercent, 57)
        let dock = app.composition.dock, view = dock.dockView
        let member = try XCTUnwrap(app.composition.presentedContent.snapshot.inputs.first?.id)
        XCTAssertEqual(view.presentedReadingsForChecks[member]?.readout, "57%")
        let nozzle = try XCTUnwrap(view.nozzleEventDelegate)
        let controller = try XCTUnwrap(dock.interactionControllerForChecks)
        let frame = try XCTUnwrap(dock.edgePresentation?.placement?.frame)
        let anchor = try XCTUnwrap(view.interactionAnchor(member))
        let ring = CGPoint(x: frame.minX + anchor.midX - view.bounds.minX, y: frame.maxY - anchor.midY + view.bounds.minY)
        func openCard() {
            pointer = ring
            nozzle.hoverNozzle(nil)
            nozzle.hoverNozzle(member)
            elapsed += 0.251
            controller.refresh()
            XCTAssertFalse(dock.card.isHidden)
        }
        func button(_ id: String, in view: NSView) -> NSButton? {
            if let control = view as? NSButton, control.accessibilityIdentifier() == id { return control }
            return view.subviews.lazy.compactMap { button(id, in: $0) }.first
        }
        let editor = app.settingsHost.application.editor
        for (language, settingsTitle, closeTitle) in [(SettingsLanguage.english, "Settings", "Close"), (.chinese, "设置", "关闭")] {
            _ = try await editor.commit(SettingsB21Edit.language(language))
            openCard()
            let target = CGRect(x: frame.minX - 312, y: frame.midY - 100, width: 300, height: 200)
            cardFrame = target
            pointer = CGPoint(x: frame.minX - 6, y: frame.midY)
            nozzle.hoverNozzle(nil)
            elapsed += 0.3
            controller.refresh()
            XCTAssertTrue(dock.interactionEnvironment().insideShared == true)
            XCTAssertFalse(dock.card.isHidden, "The card remains visible across the transfer corridor")
            pointer = CGPoint(x: target.midX, y: target.midY)
            controller.refresh()
            XCTAssertFalse(dock.card.isHidden)
            pointer = CGPoint(x: 100, y: 100)
            controller.refresh()
            elapsed += 0.249
            controller.refresh()
            XCTAssertFalse(dock.card.isHidden)
            elapsed += 0.002
            controller.refresh()
            XCTAssertTrue(dock.card.isHidden, "Leaving both surfaces closes the card after the grace")
            cardFrame = nil

            openCard()
            let menu = dock.menu()
            let actions = menu.items.filter { $0.title == settingsTitle || $0.title == closeTitle }
            XCTAssertEqual(actions.map(\.title), [settingsTitle, closeTitle])
            let settingsButton = try XCTUnwrap(button("dock.card.enter", in: dock.card))
            XCTAssertEqual(settingsButton.title, settingsTitle)
            let closeButton = try XCTUnwrap(button("dock.card.close", in: dock.card))
            XCTAssertEqual(closeButton.accessibilityLabel(), closeTitle)
            let footer = try XCTUnwrap(settingsButton.superview as? NSStackView)
            XCTAssertEqual(footer.arrangedSubviews.map { $0.accessibilityIdentifier() },
                           ["dock.card.enter", "dock.card.close"])

            let cardSettings = expectation(description: "Card opens the shared Settings host")
            settingsSurface.onShow = { cardSettings.fulfill() }
            settingsButton.performClick(nil)
            await fulfillment(of: [cardSettings], timeout: 2)
            XCTAssertTrue(dock.card.isHidden)

            openCard()
            let menuSettings = expectation(description: "Menu opens the same Settings host")
            settingsSurface.onShow = { menuSettings.fulfill() }
            let settingsIndex = try XCTUnwrap(menu.items.firstIndex { $0.title == settingsTitle })
            menu.performActionForItem(at: settingsIndex)
            await fulfillment(of: [menuSettings], timeout: 2)
            XCTAssertTrue(dock.card.isHidden)

            openCard()
            try XCTUnwrap(button("dock.card.close", in: dock.card)).performClick(nil)
            XCTAssertTrue(dock.card.isHidden)
            openCard()
            let closeIndex = try XCTUnwrap(menu.items.firstIndex { $0.title == closeTitle })
            menu.performActionForItem(at: closeIndex)
            XCTAssertTrue(dock.card.isHidden)
        }
        XCTAssertEqual(builds, 1)
        XCTAssertEqual(settingsSurface.shown.count, 4)
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)

        let sweeps = view.refreshSweepCountForChecks
        let before = app.composition.presentedContent.snapshot.presentationRows[member]?.originalObservedAt
        pointer = ring
        XCTAssertTrue(nozzle.beginNozzle(id: member, local: CGPoint(x: anchor.midX, y: anchor.midY)))
        nozzle.endNozzle(global: ring, currentID: member)
        XCTAssertEqual(view.refreshSweepCountForChecks, sweeps + 1)
        XCTAssertFalse(view.refreshSweepAnimatingForChecks)
        XCTAssertTrue(dock.card.isHidden, "Clicking a nozzle must not pin a card")
        XCTAssertEqual(app.composition.presentedContent.snapshot.presentationRows[member]?.originalObservedAt, before)
    }
}
#endif
