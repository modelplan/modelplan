// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

private actor CardDismissalClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool {
        context.sessionID == "synthetic-entry" && context.floor.storeEpoch == "synthetic-entry" &&
            context.floor.generation == 1 && context.revision == 1
    }
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "synthetic-entry", floor: .init(storeEpoch: "synthetic-entry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-refresh")) }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class CardMemberRefresh: DockMemberRefreshAdapting {
    var current: DockMemberRefreshAdmission = .ready
    var requests: [String] = []
    func admission(for member: EngineAccountMember, delivery: EngineDeliveryContext, now: Date) -> DockMemberRefreshAdmission { current }
    func request(member: EngineAccountMember, delivery: EngineDeliveryContext) async throws { requests.append(member.id) }
}

@MainActor final class DockCardDismissalJourneyTests: XCTestCase {
    func testD16StaleCloseAndRetiredMenuCannotHoldOrReleaseCurrentTracking() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "test", allowedEnvironment: [:]), settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.autoHide(true))
        app.allowDockPresentation()
        let dock = app.composition.dock
        defer { dock.close() }
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        let strip = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let sliver = try dock.prepareSliver(size: strip.size)
        XCTAssertTrue(sliver.accessibilityPerformPress())
        XCTAssertEqual(dock.edgePresentation?.state, .expanded)
        let old = dock.menu(), current = dock.menu()
        let oldDelegate = try XCTUnwrap(old.delegate as? DockSliverMenu)
        let currentDelegate = try XCTUnwrap(current.delegate as? DockSliverMenu)
        oldDelegate.menuWillOpen(old)
        currentDelegate.menuWillOpen(current)
        oldDelegate.menuDidClose(old)
        XCTAssertTrue(dock.interactionEnvironment().menuActuallyOpen, "A stale close must not release the current menu")
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(dock.edgePresentation?.state, .expanded, "Tracking protects the widget past the leave deadline")
        currentDelegate.menuDidClose(current)
        for _ in 0..<100 where dock.edgePresentation?.state != .sliver {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(dock.edgePresentation?.state, .sliver, "The real close releases auto-hide")
        currentDelegate.menuWillOpen(current)
        dock.setPresentationAllowed(false)
        XCTAssertFalse(dock.interactionEnvironment().menuActuallyOpen, "Withdrawal retires the tracking owner")
        currentDelegate.menuWillOpen(current)
        XCTAssertFalse(dock.interactionEnvironment().menuActuallyOpen, "A retired surface cannot acquire a menu lock")
        dock.setPresentationAllowed(true)
        currentDelegate.menuDidClose(current)
        currentDelegate.menuWillOpen(current)
        XCTAssertFalse(dock.interactionEnvironment().menuActuallyOpen, "A menu from the old surface cannot reacquire tracking after restoration")
        let restored = dock.menu(), restoredDelegate = try XCTUnwrap(restored.delegate as? DockSliverMenu)
        restoredDelegate.menuWillOpen(restored)
        XCTAssertTrue(dock.interactionEnvironment().menuActuallyOpen)
        restoredDelegate.menuDidClose(restored)
    }

    func testNormalEntryStartsAfterPresentationAndOfficialCardCloses() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("card-dismissal-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["state"] = "fresh"; rows[0]["expiresAt"] = "2099-01-01T00:00:00Z"
        var accounts = try XCTUnwrap(rows[0]["accounts"] as? [[String: Any]])
        accounts[0]["valueState"] = "current"; accounts[0]["freshUntil"] = "2099-01-01T00:00:00Z"
        var windows = try XCTUnwrap(accounts[0]["windows"] as? [[String: Any]])
        windows[0]["current"] = true; windows[0]["validUntil"] = "2099-01-01T00:00:00Z"
        windows[0]["resetsAt"] = "2099-01-01T00:00:00Z"; windows[0]["limitKey"] = "main"; windows[0]["poolKey"] = "main"
        windows[0].removeValue(forKey: "modelScope")
        accounts[0]["windows"] = windows; rows[0]["accounts"] = accounts
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-05T12:00:00Z"))
        var pointer = CGPoint(x: 1430, y: 475)
        var cardFrame: CGRect?
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, cockpitEntryEnabled: true, dockEnvironment: {
                var env = normalEntryTestEnvironment()
                env.pointer = pointer
                env.cardFrame = cardFrame
                return env
            }, deadlineNow: { now }, makeClient: { _, store in CardDismissalClient(store: store, rows: fixture) }, activateSettings: {})
        await app.prepare()
        let refresh = CardMemberRefresh(); app.memberRefreshAdapter = refresh
        let dock = app.composition.dock
        XCTAssertTrue(dock.interactionBindingInstalled)
        XCTAssertFalse(dock.interactionControllerRunning, "The interaction controller must not start before presentation is allowed")
        // Exercise the real official controller with its parent surface expanded.
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.autoHide(false))
        _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.motion(.on))
        app.allowDockPresentation()
        XCTAssertTrue(dock.interactionControllerRunning)
        await app.composition.start()
        defer { dock.close() }
        XCTAssertTrue(dock.interactionEnvironment().active, "The official appearance must activate the real interaction projection")
        XCTAssertNotNil(dock.dockView.registeredHullPath)
        XCTAssertTrue(dock.interactionEnvironment().parentExpanded)
        func button(_ view: NSView, id: String) -> NSButton? {
            if let value = view as? NSButton, value.accessibilityIdentifier() == id { return value }
            for child in view.subviews { if let found = button(child, id: id) { return found } }
            return nil
        }
        // A drag release must not become a click.
        let memberID = "0123456789abcdef"
        let view = dock.dockView
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let anchor = try XCTUnwrap(view.interactionAnchor(memberID))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
            y: placement.frame.maxY - anchor.midY + view.bounds.minY)
        XCTAssertNotNil(view.presentedReadingsForChecks[memberID]?.remainingPercent)
        let nozzle = try XCTUnwrap(view.nozzleEventDelegate)
        let target = try XCTUnwrap(dock.interactionEnvironment().targets.first { $0.id == memberID })
        let start = CGPoint(x: target.along, y: target.along)
        XCTAssertTrue(nozzle.beginNozzle(id: memberID, local: start))
        nozzle.moveNozzle(local: CGPoint(x: target.along + 10, y: target.along + 10))
        nozzle.endNozzle(global: .zero, currentID: memberID)
        XCTAssertTrue(dock.card.isHidden, "Dragging must not open a card")
        XCTAssertTrue(refresh.requests.isEmpty, "Dragging must not request refresh")
        let count = dock.dockView.refreshSweepCountForChecks
        let observed = app.composition.presentedContent.snapshot.presentationRows[memberID]?.originalObservedAt
        XCTAssertTrue(nozzle.beginNozzle(id: memberID, local: start))
        nozzle.endNozzle(global: .zero, currentID: memberID)
        for _ in 0..<100 { if !refresh.requests.isEmpty { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(refresh.requests, [memberID], "A click requests only the admitted member")
        XCTAssertEqual(dock.dockView.refreshSweepCountForChecks, count + 1)
        XCTAssertFalse(dock.dockView.refreshSweepAnimatingForChecks, "Reduce Motion keeps the sweep static")
        refresh.current = .deferred
        XCTAssertTrue(nozzle.beginNozzle(id: memberID, local: start))
        nozzle.endNozzle(global: .zero, currentID: memberID)
        XCTAssertEqual(refresh.requests, [memberID], "A floor-deferred click must not send a request")
        XCTAssertEqual(dock.dockView.refreshSweepCountForChecks, count + 2, "A deferred click still sweeps")
        XCTAssertEqual(app.composition.presentedContent.snapshot.presentationRows[memberID]?.originalObservedAt, observed)
        // Hover opens a card without pinning; the next user action reaches the card.
        nozzle.hoverNozzle(memberID)
        for _ in 0..<100 { if !dock.card.isHidden { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(dock.card.isHidden)
        let frame = try XCTUnwrap(dock.edgePresentation?.placement?.frame)
        let cardTarget = CGRect(x: frame.minX - 312, y: frame.midY - 100, width: 300, height: 200)
        cardFrame = cardTarget
        pointer = CGPoint(x: frame.minX - 6, y: frame.midY)
        nozzle.hoverNozzle(nil)
        XCTAssertEqual(dock.interactionEnvironment().insideShared, true)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(dock.card.isHidden, "The transfer corridor retains the card")
        pointer = CGPoint(x: cardTarget.midX, y: cardTarget.midY)
        dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(dock.card.isHidden)
        pointer = CGPoint(x: 100, y: 100)
        dock.interactionControllerForChecks?.refresh()
        for _ in 0..<100 where !dock.card.isHidden { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(dock.card.isHidden, "Leaving both surfaces closes the card after its grace")
        cardFrame = nil
        pointer = CGPoint(x: frame.midX, y: frame.midY)
        nozzle.hoverNozzle(memberID)
        for _ in 0..<100 { if !dock.card.isHidden { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(dock.card.isHidden)
        // D37 (11-06): the production card is the prototype card: no Settings or Close buttons.
        XCTAssertNil(button(dock.card, id: "dock.card.enter"), "The card has no Settings button")
        XCTAssertNil(button(dock.card, id: "dock.card.close"), "The card has no Close button")
        nozzle.hoverNozzle(nil)
        let focused = try XCTUnwrap((dock.dockView.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            .first { $0.accessibilityIdentifier() == "dock.subscription." + memberID })
        focused.setAccessibilityFocused(true)
        for _ in 0..<100 { if !dock.card.isHidden { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(dock.card.isHidden, "Focusing the ring opens the card")
        let beforeAccessiblePress = dock.dockView.refreshSweepCountForChecks
        XCTAssertTrue(focused.accessibilityPerformPress(), "VoiceOver activation reaches the ring action")
        XCTAssertEqual(dock.dockView.refreshSweepCountForChecks, beforeAccessiblePress + 1)
        XCTAssertEqual(refresh.requests, [memberID], "The deferred floor applies to VoiceOver too")
        // D37: Esc closes the keyboard-held card; the ring keeps keyboard focus and the card stays closed.
        XCTAssertFalse(dock.card.isHidden)
        XCTAssertEqual(dock.dockView.keyboardTargetID, memberID)
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        dock.dockView.keyDown(with: escape)
        XCTAssertTrue(dock.card.isHidden, "Esc closes the card held by keyboard focus")
        XCTAssertEqual(dock.dockView.keyboardTargetID, memberID, "Esc keeps the ring's focus")
        dock.interactionControllerForChecks?.refresh()
        try await Task.sleep(for: .milliseconds(350))
        dock.interactionControllerForChecks?.refresh()
        XCTAssertTrue(dock.card.isHidden, "The closed card does not reopen while focus stays on the same ring")
        focused.setAccessibilityFocused(false)
        var navigations = 0
        dock.showSettings = { navigations += 1 }; dock.showConsole = { navigations += 1 }
        // Member identity rule: the same verified member ID reopens the card.
        nozzle.hoverNozzle(nil); nozzle.hoverNozzle(memberID)
        for _ in 0..<100 { if !dock.card.isHidden { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(dock.card.isHidden, "The same member reopens its card")

        for (language, settings, close) in [(SettingsLanguage.english, "Settings", "Close"), (.chinese, "设置", "关闭")] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(language))
            nozzle.hoverNozzle(nil); nozzle.hoverNozzle(memberID)
            for _ in 0..<100 { if !dock.card.isHidden { break }; try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertNil(button(dock.card, id: "dock.card.enter"))
            XCTAssertNil(button(dock.card, id: "dock.card.close"))
            // Owner HIG decision 11-06: the widget menu has Settings… (no Close; a menu closes itself).
            let menu = dock.menu()
            let menuSettings = settings + "…"
            let actions = menu.items.filter { $0.title == menuSettings || $0.title == close }
            XCTAssertEqual(actions.map(\.title), [menuSettings])
            let settingsItem = try XCTUnwrap(actions.first { $0.title == menuSettings })
            let beforeSettings = navigations
            _ = try XCTUnwrap(settingsItem.target as? NSObject).perform(try XCTUnwrap(settingsItem.action), with: settingsItem)
            XCTAssertEqual(navigations, beforeSettings + 1)
            XCTAssertTrue(dock.card.isHidden)
            nozzle.hoverNozzle(nil); nozzle.hoverNozzle(memberID)
            for _ in 0..<100 { if !dock.card.isHidden { break }; try await Task.sleep(for: .milliseconds(10)) }
            if let closeItem = actions.last, closeItem.title == close,
               let target = closeItem.target as? NSObject, let action = closeItem.action {
                _ = target.perform(action, with: closeItem)
                XCTAssertTrue(dock.card.isHidden)
                XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.showDock, true)
            }
        }
        await app.composition.stop()
    }
}
