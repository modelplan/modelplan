// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// G3-126: accepted menu-bar readings stay stable through refresh gaps and display/wake item reconstruction.
@MainActor final class G3_126StatusStabilityTests: XCTestCase {
    func testPercentageDoesNotBlinkAcrossOutOfOrderDuplicatesGapsAndStatusItemRecreation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-126-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let initialRows = try HostPairedProjectionTests.rows(weekly: 15, sequence: 7)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: initialRows) }, activateSettings: {})
        addTeardownBlock { @MainActor in app.removeStatusItem(); await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.menuDisplay(.tightest))

        var scheduled: [(milliseconds: UInt64, fire: @MainActor () -> Void)] = []
        app.displayRecheckSchedule = { milliseconds, fire in
            scheduled.append((milliseconds, fire)); return {}
        }
        app.installStatusItem()
        app.renderMenu()
        let firstButton = try XCTUnwrap(app.statusButtonForTesting)
        XCTAssertEqual(firstButton.title, "15%")
        var seen = [firstButton.title]
        func sampleCurrentItem() {
            app.renderMenu()
            if let button = app.statusButtonForTesting {
                app.applyStatusContent(to: button, detail: "")
                seen.append(button.title)
            }
        }
        let previousMenuChange = app.composition.menuDidChange
        app.composition.menuDidChange = { previousMenuChange?(); sampleCurrentItem() }

        // Use the production client's sequence admission: older and duplicate rows are not published to the store.
        let admission = ProcessEngineClient(configuration: .init(
            executableURL: root.appendingPathComponent("sequence-gate-not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), consumer: app.composition.store)
        let admittedSeed = await admission.acceptSequence(7)
        XCTAssertTrue(admittedSeed)
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        func deliver(weekly: Double, sequence: UInt64) async throws {
            let rows = try HostPairedProjectionTests.rows(weekly: weekly, sequence: Int(sequence))
            if await admission.acceptSequence(sequence) {
                let reply = try EngineReply(envelope: .init(sessionId: context.sessionID,
                    storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context)
                await app.composition.store.consume(.rowsChanged(reply, invalidRowCount: rows.projection.invalidRowCount))
            }
            sampleCurrentItem()
        }
        try await deliver(weekly: 15, sequence: 8)
        try await deliver(weekly: 88, sequence: 7) // delayed older reading
        try await deliver(weekly: 88, sequence: 8) // duplicate sequence
        try await deliver(weekly: 15, sequence: 9)
        try await deliver(weekly: 88, sequence: 9) // duplicate refresh with a conflicting stale payload

        // A temporarily withdrawn admitted projection is an unavailable gap, not an instruction to clear the title.
        app.composition.suspendDeadlines()
        sampleCurrentItem()
        app.composition.resumeDeadlines()
        sampleCurrentItem()

        // Simulate the display-settle and wake re-verification around rebuilding the native status item.
        app.displayParametersChanged()
        XCTAssertEqual(scheduled.last?.milliseconds, 750)
        let settle = try XCTUnwrap(scheduled.popLast()).fire
        app.removeStatusItem()
        app.installStatusItem()
        let rebuiltButton = try XCTUnwrap(app.statusButtonForTesting)
        app.applyStatusContent(to: rebuiltButton, detail: "")
        seen.append(rebuiltButton.title)
        sampleCurrentItem()
        settle()
        XCTAssertEqual(scheduled.last?.milliseconds, 2_000)
        try XCTUnwrap(scheduled.popLast()).fire()
        sampleCurrentItem()

        app.composition.menuDidChange = previousMenuChange
        XCTAssertGreaterThan(seen.count, 8, "refresh, gap and display events all re-rendered the item")
        XCTAssertEqual(Set(seen), ["15%"], "stale, duplicate, unavailable and rebuilt-item renders never blank or flicker: \(seen)")
    }
}
