// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import WebKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanResources
import ModelPlanSettings
@testable import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// macrevb-1096-7 (R2/R3): the resource plugin through the normal entry (`EngineRowsEntry.make` with
/// `cockpitEntryEnabled: true`, the production factory, the real CLI on synthetic data and the real cockpit page),
/// with a synthetic resource reader in place of this Mac's. One journey: the widget ring and its hover card, the
/// cockpit column and its big screen, then Settings › Plugins Off clears both surfaces and stops sampling.
/// It needs the canonical official cockpit and the synthetic-test CLI (as the G3-42 tests) and skips without them.
extension CommunityCockpitEntryTests {
    private final class JourneyReader: ResourceReader {
        private(set) var reads = 0
        func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? {
            reads += 1
            let g: UInt64 = 1 << 30
            return ResourceSample(unixMs: unixMs, uptime: uptime, cpuUser: 16.5, cpuSystem: 5.5, load: 2.4,
                                  memTotal: 32 * g, memApp: 9 * g, memWired: 4 * g, memCompressed: g, memCached: 12 * g, memFree: 6 * g,
                                  swapUsed: 0, pressure: .normal, diskTotal: 494 * g, diskFree: 120 * g)
        }
    }
    private final class ResourcePageProbe { var made: [CockpitWindowController] = [] }

    @MainActor private func waitFor(_ what: String, seconds: Double = 10, _ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .milliseconds(Int(seconds * 1000))
        while ContinuousClock.now < deadline { if await condition() { return }; try await Task.sleep(for: .milliseconds(20)) }
        let met = await condition()
        XCTAssertTrue(met, what)
    }
    @MainActor private func js(_ web: WKWebView, _ script: String) async -> String {
        ((try? await web.evaluateJavaScript(script)) as? String) ?? "error"
    }

    @MainActor func testResourcePluginInstalledJourneyWidgetCardColumnScreenAndSettingsOff() async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("resource-journey-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try Self.ownerTestShapedApp(at: root.appendingPathComponent("package"), helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        let environment = try await Self.syntheticHome(root, helper: helper)
        // The resource column sits beside a subscription column; with none the page shows the CKP-ENG-57 empty engine.
        try Self.seedCodexSubscription(root)

        let reader = JourneyReader()
        let probe = ResourcePageProbe()
        let savedPage = CommunityCockpitApplicationFactory.verificationPage
        let savedPlugin = CommunityCockpitApplicationFactory.verificationResourcePlugin
        let savedReader = CommunityCockpitApplicationFactory.verificationResourceReader
        CommunityCockpitApplicationFactory.verificationPage = { [weak probe] page in probe?.made.append(page) }
        CommunityCockpitApplicationFactory.verificationResourcePlugin = true
        CommunityCockpitApplicationFactory.verificationResourceReader = { reader }
        defer {
            CommunityCockpitApplicationFactory.verificationPage = savedPage
            CommunityCockpitApplicationFactory.verificationResourcePlugin = savedPlugin
            CommunityCockpitApplicationFactory.verificationResourceReader = savedReader
        }
        let settings = try await completedOnboarding(try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"]))
        _ = try await settings.update { $0.showDock = true; $0.autoHide = false; $0.language = .english }
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-resource-journey",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: app, cockpitEntryEnabled: true)
        await entry.prepare()
        await entry.composition.start()
        defer { Task { @MainActor in await entry.composition.stop() } }
        entry.composition.dock.setPresentationAllowed(true)
        for _ in 0..<1500 where entry.composition.store.snapshot.delivery == nil { try await Task.sleep(for: .milliseconds(10)) }

        // The installed sampler and the plugin choices Settings edits.
        try await waitFor("the resource plugin is installed") { entry.resourcePlugin != nil && entry.cockpitPluginModel != nil }
        let host = try XCTUnwrap(entry.resourcePlugin), model = try XCTUnwrap(entry.cockpitPluginModel)
        let interval = await model.perform(.setSetting("resources", "intervalSeconds", 2))
        XCTAssertTrue(interval)
        _ = await model.perform(.setPinned("resources", true))

        // Widget: the ring is drawn and its hover card has the variant A rows, the footer and the screen action.
        let dock = entry.composition.dock, id = ResourceDockBridge.subscriptionID
        try await waitFor("the resource ring is on the widget") { dock.dockView.presentedReadingsForChecks[id]?.pluginRing != nil }
        XCTAssertTrue(dock.isWidgetShown, "the expanded widget counts as shown (D324: 10 s)")
        // B4 (owner 11-21): the widget order is the cockpit's, subscriptions first and the plugin ring after them.
        // Fails before: the resource ring was painted in front of the Codex ring.
        let painted = dock.dockView.presentedOrderForChecks
        XCTAssertGreaterThanOrEqual(painted.count, 2, "the seeded Codex ring and the resource ring")
        XCTAssertEqual(painted.last, id, "the plugin ring comes after every subscription ring")
        // B4f (owner 11-21): the ring draws the percentage alone; VoiceOver still names what it measures.
        let reading = try XCTUnwrap(dock.dockView.presentedReadingsForChecks[id])
        XCTAssertTrue(reading.readout.range(of: "^[0-9]+%$", options: .regularExpression) != nil, "percentage only: \(reading.readout)")
        let node = (dock.dockView.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            .first { $0.accessibilityIdentifier() == "dock.subscription." + id }
        XCTAssertEqual(node?.accessibilityValue() as? String, "Memory " + reading.readout, "the spoken readout keeps its label")
        let card = try XCTUnwrap(dock.cardContent(for: id))
        XCTAssertEqual(card.rows.filter { $0.kind == .quota }.map(\.label), ["CPU", "Memory", "Disk"])
        XCTAssertEqual(card.actionLabel, "Cockpit screen ›")
        XCTAssertTrue(card.rows.last?.value.hasPrefix("Memory pressure Normal") == true)
        // macrevb-1096-8: the ring is hoverable but stays out of the subscription order Settings commits.
        let interaction = dock.interactionEnvironment()
        XCTAssertTrue(interaction.catalogue.contains(id))
        XCTAssertFalse(interaction.reorderCatalogue.contains(id))

        // Cockpit: the column runs on the shown page and its key opens the resource big screen.
        entry.showConsole()
        func shown() -> CockpitWindowController? {
            guard let page = probe.made.last, page.bridge.ready, page.window?.isVisible == true else { return nil }
            return page
        }
        try await waitFor("the click shows the real cockpit page", seconds: 30) { shown() != nil }
        let page = try XCTUnwrap(shown()), web = try XCTUnwrap(page.verificationWebView)
        try await waitFor("the synthetic Codex subscription draws the engine table") { await self.js(web, "String(\(Self.engineDrawnScript))") == "true" }
        try await waitFor("the page runs the resource column") { host.visibility.columnShown }
        XCTAssertEqual(ResourceCadence.interval(host.visibility), 2, "column shown: the column setting")
        let key = ".eng-keys .pl-key[data-plugin=\"resources\"]"
        try await waitFor("the resource key is on the page") { await self.js(web, "String(document.querySelectorAll('\(key)').length)") == "1" }
        // The key answers only a trusted click (plugin-host.ts; the real click is CKP-PLG-53 in
        // testPluginKeyRemoveOnTheNormalEntryPageIsSaved, GUI Mac): a script click leaves the screen closed.
        let screenOpen = "String(document.querySelectorAll('.dk-mfd .pl-screen[data-plugin=\"resources\"]').length>0)"
        _ = await js(web, "(()=>{document.querySelector('\(key)')?.click();return 'ok'})()")
        try await Task.sleep(for: .milliseconds(300))
        let scriptClick = await js(web, screenOpen)
        XCTAssertEqual(scriptClick, "false", "an untrusted script click does not open the screen")
        // macrevb-1096-6 / sample S17: the widget card's "Cockpit screen ›" action (card.onAction, the same closure for a
        // pointer click, Return/Space and a VoiceOver press) passes the ring's Dock ID, "plugin:resources", not the
        // plugin ID; the installed callback must still open the screen on the shown page.
        let open = try XCTUnwrap(dock.pluginScreenRequested, "the installed plugin wires the card action")
        XCTAssertEqual(id, "plugin:resources")
        open(id)
        try await waitFor("the card action opens the resource big screen") {
            await self.js(web, "String(document.querySelectorAll('.dk-mfd .mfd-screen .pl-draw-chart').length>0)") == "true"
        }
        XCTAssertGreaterThan(reader.reads, 0)

        // Settings › Plugins Off: both surfaces clear and sampling stops.
        let off = await model.perform(.setEnabled("resources", false))
        XCTAssertTrue(off, "the same model the Settings switch edits")
        try await waitFor("the ring leaves the widget") { dock.dockView.presentedReadingsForChecks[id] == nil }
        XCTAssertNil(try dock.cardContent(for: id))
        try await waitFor("the column and its key leave the page") {
            await self.js(web, "String(document.querySelectorAll('\(key)').length)") == "0"
        }
        XCTAssertFalse(host.visibility.pluginEnabled)
        XCTAssertTrue(host.sampler.history.samples.isEmpty, "the ten-minute history is dropped")
        let reads = reader.reads
        try await Task.sleep(for: .seconds(5))
        XCTAssertEqual(reader.reads, reads, "no sampling while off (the column interval was 2 s)")
    }
}
#endif
