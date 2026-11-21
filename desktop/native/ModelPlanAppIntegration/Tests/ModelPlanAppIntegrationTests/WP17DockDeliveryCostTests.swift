// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// WP-17 (cold start): the engine client delivers events one at a time and waits for each consume. Every event used to
/// clear and redraw the Dock (four official-face passes on the main actor, about 0.6 s each on a hosted Mac, run
/// 44899281511), so the start handshake, every reply and the cockpit's own reply queued behind Dock redraws that
/// changed nothing. Invariant kept: a clear still withdraws the Dock at once; rows reach it only after an admitted
/// delivery; only events that change nothing the Dock projects skip the redraw.
@MainActor final class WP17DockDeliveryCostTests: XCTestCase {
    private func makeEntry(rows: WireRowsSnapshot) async throws -> EngineDockMenuApplication {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("wp17-dock-cost-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation()
        addTeardownBlock { @MainActor in await app.composition.stop() }
        return app
    }
    private let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)

    /// A delivery that changes nothing the Dock shows (a repeated ready or context, another feature's failure) does not
    /// redraw it; the menu still hears about it, and the admitted rings stay.
    func testADeliveryThatChangesNothingTheDockShowsDoesNotRedrawIt() async throws {
        let app = try await makeEntry(rows: try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 12))
        await app.composition.start()
        let composition = app.composition, dock = composition.dock
        XCTAssertFalse(composition.presentedContent.snapshot.inputs.isEmpty, "the admitted rows are on the widget")
        var menuChanges = 0
        let menu = composition.menuDidChange
        composition.menuDidChange = { menuChanges += 1; menu?() }
        let passes = dock.fullRebuildPassesForChecks
        await composition.store.consume(.connection(.ready(context)))
        await composition.store.consume(.context(context))
        await composition.store.consume(.featureFailure(.history, .featureDecode(.history)))
        XCTAssertEqual(dock.fullRebuildPassesForChecks, passes, "WP-17: an event that changes no Dock input redraws nothing")
        XCTAssertEqual(menuChanges, 3, "the menu (it also shows other replies) still refreshes once per event")
        XCTAssertFalse(composition.presentedContent.snapshot.inputs.isEmpty, "the admitted rings stay admitted")
    }

    /// A rows change still redraws, and a clear still withdraws everything at once (the privacy fence).
    func testRowsChangeStillRedrawsAndAClearStillWithdraws() async throws {
        let app = try await makeEntry(rows: try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 12))
        await app.composition.start()
        let composition = app.composition, dock = composition.dock
        await composition.store.consume(.featureFailure(.history, .featureDecode(.history)))
        let passes = dock.fullRebuildPassesForChecks
        let next = try HostPairedProjectionTests.rows(weekly: 40, secondWeekly: 12, sequence: 8)
        await composition.store.consume(.rowsChanged(try EngineReply(envelope: .init(sessionId: context.sessionID,
            storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: next), delivery: context), invalidRowCount: 0))
        XCTAssertGreaterThan(dock.fullRebuildPassesForChecks, passes, "new rows are drawn")
        XCTAssertFalse(composition.presentedContent.snapshot.inputs.isEmpty)
        let beforeClear = dock.fullRebuildPassesForChecks
        await composition.store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertGreaterThan(dock.fullRebuildPassesForChecks, beforeClear, "a clear redraws the withdrawn widget")
        XCTAssertTrue(composition.presentedContent.snapshot.inputs.isEmpty, "nothing private stays after a clear")
        XCTAssertEqual(composition.provider.dockContent.status, .cleared)
        // The skip never carries over a clear: no event other than an admitted rows delivery brings rows back.
        await composition.store.consume(.featureFailure(.history, .featureDecode(.history)))
        XCTAssertTrue(composition.presentedContent.snapshot.inputs.isEmpty)
    }

    /// Before the first rows (the cold start), a delivery that changes the Dock's inputs draws the empty widget once,
    /// not four times: the fence's second withdrawal of the same empty state and the repeated empty catalogue report
    /// each redrew every official face again.
    func testWithoutRowsADeliveryDrawsTheEmptyWidgetOnce() async throws {
        let app = try await makeEntry(rows: try HostPairedProjectionTests.rows(weekly: 75))
        let composition = app.composition, dock = composition.dock
        await composition.store.consume(.connection(.starting))
        let catalogueReports = dock.catalogueReportsForChecks
        let passes = dock.fullRebuildPassesForChecks
        await composition.store.consume(.context(context))
        XCTAssertLessThanOrEqual(dock.fullRebuildPassesForChecks - passes, 1, "WP-17: one empty redraw per changed delivery")
        XCTAssertEqual(dock.catalogueReportsForChecks, catalogueReports, "an empty catalogue is not reported again")
        XCTAssertTrue(composition.presentedContent.snapshot.inputs.isEmpty, "no rows before an admitted delivery")
    }

    /// The empty catalogue is still reported after a non-empty one (subscription names leave Settings on a withdrawal).
    func testAWithdrawalAfterSubscriptionsStillReportsTheEmptyCatalogue() async throws {
        let app = try await makeEntry(rows: try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 12))
        await app.composition.start()
        let composition = app.composition, dock = composition.dock
        XCTAssertFalse(dock.catalogueReportedEmpty, "the admitted subscriptions were reported")
        var reported: [[SettingsSubscription]] = []
        let original = dock.catalogueChanged
        dock.catalogueChanged = { reported.append($0); original?($0) }
        await composition.store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertEqual(reported.last?.isEmpty, true, "a withdrawal tells Settings there are no subscriptions")
    }
}
