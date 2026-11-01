// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanCockpitWeb
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

@MainActor private final class JourneyConsole: EngineRowsConsoleSurface {
    var opens = 0
    func show() { opens += 1 }
    func render() {}
    func hide() {}
}

@MainActor final class CockpitEntryJourneyTests: XCTestCase {
    func testV1KeepsLegacyOpeningPreferencesButHidesHoldAndCountdownRows() {
        XCTAssertFalse(SettingsCatalogue.visibleInV1(.opening))
        XCTAssertFalse(SettingsCatalogue.visibleInV1(.countdown))
        XCTAssertTrue(SettingsCatalogue.visibleInV1(.motion))
        XCTAssertTrue(SettingsCatalogue.visibleInV1(.language))
    }
    func testNormalEntryMenuAndDockOpenTheSameCockpit() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("s6-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let surface = JourneyConsole()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try SettingsStore(url: root.appendingPathComponent("settings.json")), createsNativePanels: false,
            makeConsole: { _ in surface }, activateSettings: {})
        await app.prepare()
        let menu = try XCTUnwrap(app.liveStatusMenu)
        let open = try XCTUnwrap(menu.items.firstIndex { $0.title == "Open Cockpit / 打开驾驶舱" })
        menu.performActionForItem(at: open)
        XCTAssertEqual(surface.opens, 1)
        app.composition.dock.setPresentationAllowed(true)
        let dockMenu = app.composition.dock.menu()
        let dockOpen = try XCTUnwrap(dockMenu.items.firstIndex { $0.title == "Open Cockpit / 打开驾驶舱" })
        dockMenu.performActionForItem(at: dockOpen)
        XCTAssertEqual(surface.opens, 2)
        app.composition.dock.setPresentationAllowed(false)
    }
}

private actor JourneyEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { false }
    let consumer: any EngineClientEventConsumer
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-0000-0000-000000000001", floor: .init(storeEpoch: "synthetic-s6", generation: 1), revision: 1)
    init(_ consumer: any EngineClientEventConsumer) { self.consumer = consumer }
    func start() async throws -> EngineDeliveryContext { await consumer.consume(.connection(.ready(context))); return context }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic")) }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class JourneyPage: CockpitPageSurface {
    var queryTicket: CockpitQueryTicket? { nil }
    var onReady: (() -> Void)?, onIntent: ((CockpitIntent) -> Void)?, onClosed: (() -> Void)?
    var opened: (() -> Void)?
    var appearances: [CockpitAppearance] = []
    func open() { opened?(); onReady?() }
    func updateAppearance(_ value: CockpitAppearance) { appearances.append(value) }
    func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) { XCTFail("Unexpected data") }
    func clearPrivateViews(adopting: CockpitEngineContext?) async {}
    func discard() { onClosed?() }
}
extension CockpitEntryJourneyTests {
    func testNormalCompositionOpensFromMenuDockAndHeldIgnitionAndForwardsSettingsLive() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("s6-composition-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var pages: [JourneyPage] = [], clients = 0
        var nextOpen: XCTestExpectation?
        let runtime = CockpitRuntimeFactory(client: { _, consumer in clients += 1; return JourneyEngine(consumer) }, page: { _, appearance in
            let page = JourneyPage(); page.appearances.append(appearance)
            page.opened = { nextOpen?.fulfill() }; pages.append(page); return page
        })
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try SettingsStore(url: root.appendingPathComponent("settings.json")), createsNativePanels: false,
            cockpitRuntime: runtime, activateSettings: {})
        await app.prepare(); await app.composition.start()
        XCTAssertEqual(clients, 1); XCTAssertTrue(pages.isEmpty, "No page or prewarm on construction/start")
        app.composition.dock.setPresentationAllowed(true)
        for entry in ["menu", "dock", "held-ignition"] {
            let opened = expectation(description: entry); nextOpen = opened
            if entry == "menu" {
                let menu = try XCTUnwrap(app.liveStatusMenu)
                menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Open Cockpit / 打开驾驶舱" }))
            } else if entry == "dock" {
                let menu = app.composition.dock.menu()
                menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Open Cockpit / 打开驾驶舱" }))
            } else {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
                // One press-down without a release simulates a held ignition: it opens now.
                app.composition.dock.consoleButton.mouseDown(with: event)
            }
            await fulfillment(of: [opened], timeout: 3)
            let page = try XCTUnwrap(pages.last)
            XCTAssertFalse(app.composition.dock.isPresentationAllowed)
            let count = pages.count
            app.composition.dock.consoleButton.performClick(nil)
            XCTAssertEqual(pages.count, count, "Dock is suppressed while cockpit is open")
            _ = try await app.settingsHost.application.commit(.theme(.day))
            _ = try await app.settingsHost.application.commit(.motion(.on))
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
            XCTAssertEqual(page.appearances.last?.theme, .night)
            XCTAssertEqual(page.appearances.last?.locale, .zhCN)
            XCTAssertEqual(page.appearances.last?.reduceMotion, true)
            page.discard()
            XCTAssertTrue(app.composition.dock.isPresentationAllowed, "Close restores the original Dock lifecycle gate")
        }
        XCTAssertEqual(pages.count, 3, "Close discards the page; each entry opens a fresh page")
        let iconOpened = expectation(description: "status icon toggle"); nextOpen = iconOpened
        app.toggleCockpit(); await fulfillment(of: [iconOpened], timeout: 3)
        XCTAssertFalse(app.composition.dock.isPresentationAllowed)
        app.toggleCockpit()
        XCTAssertTrue(app.composition.dock.isPresentationAllowed)
        XCTAssertEqual(clients, 1, "Dock/Settings and cockpit share one engine client")
        app.composition.dock.setPresentationAllowed(false); await app.composition.stop()
    }
}
