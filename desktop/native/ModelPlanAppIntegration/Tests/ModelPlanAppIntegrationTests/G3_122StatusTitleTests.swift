// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// G3-122 (owner build 14f): the menu-bar percentage appeared and disappeared faster than once a second.
@MainActor final class G3_122StatusTitleTests: XCTestCase {
    private let base = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testKeeperShowsValuesAndDefinitiveIconOnly() {
        var keeper = StatusTitleKeeper()
        XCTAssertEqual(keeper.resolve(.unavailable, now: base), "", "nothing known yet: icon only")
        XCTAssertEqual(keeper.resolve(.value("13%"), now: base), "13%")
        XCTAssertEqual(keeper.resolve(.value("12%"), now: base), "12%")
        XCTAssertEqual(keeper.resolve(.none, now: base), "", "icon mode, a privacy clear or no rows take the number away")
        XCTAssertEqual(keeper.resolve(.unavailable, now: base), "", "a gap after a definitive icon-only stays icon only")
    }

    func testKeeperHoldsTheLastNumberAcrossGapsAndNeverToggles() {
        var keeper = StatusTitleKeeper()
        var shown: [String] = []
        // An engine delivery every 400 ms, each a clear then an install, plus re-verifies in between.
        for step in 0..<50 {
            let now = base.addingTimeInterval(Double(step) * 0.2)
            shown.append(keeper.resolve(step % 2 == 0 ? .value("13%") : .unavailable, now: now))
            shown.append(keeper.resolve(.unavailable, now: now.addingTimeInterval(0.05)))
        }
        XCTAssertEqual(Set(shown), ["13%"], "the title never leaves the number during replacement gaps")
    }

    func testKeeperGivesUpOnlyAfterTheHoldLimit() {
        var keeper = StatusTitleKeeper()
        _ = keeper.resolve(.value("13%"), now: base)
        XCTAssertEqual(keeper.resolve(.unavailable, now: base.addingTimeInterval(1)), "13%")
        XCTAssertEqual(keeper.resolve(.unavailable, now: base.addingTimeInterval(StatusTitleKeeper.holdLimit)), "13%",
                       "the hold is measured from the start of the gap")
        XCTAssertEqual(keeper.resolve(.unavailable, now: base.addingTimeInterval(StatusTitleKeeper.holdLimit + 1)), "")
        XCTAssertEqual(keeper.resolve(.value("14%"), now: base.addingTimeInterval(StatusTitleKeeper.holdLimit + 2)), "14%")
        // A clock that goes back does not end a hold.
        XCTAssertEqual(keeper.resolve(.unavailable, now: base), "14%")
    }

    /// Spec 5.3 A: the preflight runs first, the item is created at zero length, named, then given its variable length.
    func testStatusItemIsCreatedAtZeroLengthNamedThenVariable() {
        final class Item { var length: CGFloat; init(_ length: CGFloat) { self.length = length } }
        var log: [String] = []
        let steps = EngineDockMenuApplication.StatusItemVendingSteps<Item>(
            preflight: { log.append("preflight:\($0)") },
            create: { log.append("create:\($0)"); return Item($0) },
            name: { _, name in log.append("name:\(name)") },
            length: { $0.length }, setLength: { item, length in log.append("length:\(length)"); item.length = length })
        let item = EngineDockMenuApplication.vendStatusItem(autosaveName: "modelplan.test", steps: steps)
        XCTAssertEqual(log, ["preflight:modelplan.test", "create:0.0", "name:modelplan.test", "length:\(NSStatusItem.variableLength)"])
        XCTAssertEqual(item.length, NSStatusItem.variableLength)
        log = []
        _ = EngineDockMenuApplication.vendStatusItem(autosaveName: nil, steps: steps)
        XCTAssertEqual(log, ["create:0.0", "length:\(NSStatusItem.variableLength)"], "a temporary item has no preflight and no name")
    }

    /// The real cause, through the real entry: every engine rows delivery replaces the admitted projection in two
    /// synchronous steps, and the clear step re-rendered the status item from an empty cache ("" and the square length).
    /// Deliveries, forced G3-57 rewrites, display re-verifies and Settings-change renders are driven back to back;
    /// the title seen after every single render must stay "15%".
    func testRapidDeliveriesAndRewritesNeverClearThePercentage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-122-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let fixture = try HostPairedProjectionTests.rows(weekly: 15)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: fixture) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.menuDisplay(.tightest))
        var recheckArmed = 0
        app.displayRecheckSchedule = { _, _ in recheckArmed += 1; return {} }

        let button = NSButton(frame: .zero)
        EngineDockMenuApplication.configureStatusButton(button, image: NSImage(size: .init(width: 16, height: 16)), barThickness: 22)
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "15%")
        var seen: [String] = [], positions: [NSControl.ImagePosition] = []
        func record() {
            app.applyStatusContent(to: button, detail: "")
            seen.append(button.title); positions.append(button.imagePosition)
        }
        let original = app.composition.menuDidChange
        app.composition.menuDidChange = { original?(); record() }
        // The fixture's own delivery context.
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        for step in 0..<6 {
            let next = try HostPairedProjectionTests.rows(weekly: 15, sequence: 8 + step)
            let reply = try EngineReply(envelope: .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
                consentGeneration: 1, data: next), delivery: context)
            await app.composition.store.consume(.rowsChanged(reply, invalidRowCount: next.projection.invalidRowCount))
            app.rewriteStatusContent(now: wall.addingTimeInterval(Double(step) * 2.5))
            app.displayParametersChanged()
            app.renderMenu(); record()
        }
        XCTAssertGreaterThan(seen.count, 6, "the deliveries re-rendered the item")
        XCTAssertEqual(Set(seen), ["15%"], "the percentage never left the item: \(seen)")
        XCTAssertEqual(Set(positions), [.imageLeading])
        XCTAssertEqual(recheckArmed, 6, "each display change re-arms the settled re-verify (no immediate rewrite)")
        app.composition.menuDidChange = original
        // A privacy clear still takes the number away at once.
        let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)
        await app.composition.store.consume(.clearPrivateViews(.init(revision: delivery.revision + 1,
            reason: .generationAdvanced, previous: delivery, nextFloor: nil)))
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "")
    }

    /// Spec 5.3 C: while the status menu is open neither its items nor the item's title change; one render runs after
    /// it closes.
    func testRenderIsHeldWhileTheStatusMenuIsOpen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-122-menu-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let fixture = try HostPairedProjectionTests.rows(weekly: 15)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: fixture) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        app.renderMenu()
        let menu = try XCTUnwrap(app.liveStatusMenu)
        let component = try XCTUnwrap(menu.delegate as? NSMenuDelegate)
        component.menuWillOpen?(menu)
        let before = menu.items.map(\.title)
        menu.addItem(withTitle: "marker", action: nil, keyEquivalent: "")
        app.renderMenu(); app.renderMenu()
        XCTAssertTrue(app.statusRenderHeld)
        XCTAssertEqual(menu.items.last?.title, "marker", "the open menu is not rebuilt")
        component.menuDidClose?(menu)
        XCTAssertTrue(app.statusRenderHeld, "the held render waits for the next turn, outside the tracking teardown")
        for _ in 0..<50 where app.statusRenderHeld { await Task.yield() }
        XCTAssertFalse(app.statusRenderHeld)
        XCTAssertEqual(menu.items.map(\.title), before, "one render after close rebuilt the menu")
    }
}
