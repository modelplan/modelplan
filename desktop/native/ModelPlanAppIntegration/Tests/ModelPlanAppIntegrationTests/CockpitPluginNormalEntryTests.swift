// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest
@testable import ModelPlanCockpitWeb
import ModelPlanSettings
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// macrevc-844-1 at the normal entry: `EngineRowsEntry.make` with `cockpitEntryEnabled: true`, the production factory,
/// the real CLI on synthetic data and the real cockpit page and window. The saved plugin choices reach the page, the
/// page's running plugins drive the sampler, Settings-side pin / move / disable reach the open page, a page Remove is
/// saved, and a reopened page starts from the saved choices. They need the canonical official cockpit and the
/// synthetic-test CLI (as the CKP-SHELL-28 tests) and skip without them.
extension CommunityCockpitEntryTests {
    private final class PluginPageProbe { var made: [CockpitWindowController] = [] }

    @MainActor private func withPluginCockpit(
        _ body: (_ entry: EngineDockMenuApplication, _ plugins: CockpitPluginBridge, _ probe: PluginPageProbe, _ support: URL) async throws -> Void
    ) async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-plugins-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try Self.ownerTestShapedApp(at: root.appendingPathComponent("package"), helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        let environment = try await Self.syntheticHome(root, helper: helper)
        // Plugin columns sit beside subscription columns; with none the page shows the CKP-ENG-57 empty engine.
        try Self.seedCodexSubscription(root)
        let probe = PluginPageProbe()
        let saved = CommunityCockpitApplicationFactory.verificationPage
        CommunityCockpitApplicationFactory.verificationPage = { [weak probe] page in probe?.made.append(page) }
        defer { CommunityCockpitApplicationFactory.verificationPage = saved }
        let support = root.appendingPathComponent("support")
        let settings = try await completedOnboarding(try EngineRowsEntry.makeSettingsStore(applicationSupport: support, preferredLanguages: ["en"]))
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-cockpit-plugins",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: app, cockpitEntryEnabled: true)
        await entry.prepare()
        await entry.composition.start()
        entry.composition.dock.setPresentationAllowed(true)
        for _ in 0..<1500 where entry.composition.store.snapshot.delivery == nil || entry.cockpitPlugins == nil { try await Task.sleep(for: .milliseconds(10)) }
        let plugins = try XCTUnwrap(entry.cockpitPlugins, "the app attaches the saved plugin choices at launch")
        do { try await body(entry, plugins, probe, settings.directory) }
        catch { await entry.composition.stop(); throw error }
        await entry.composition.stop()
    }
    @MainActor private func shownPage(_ probe: PluginPageProbe, other: CockpitWindowController? = nil) async throws -> CockpitWindowController {
        func shown() -> CockpitWindowController? {
            guard let page = probe.made.last, page !== other, page.bridge.ready, page.window?.isVisible == true else { return nil }
            return page
        }
        for _ in 0..<3000 where shown() == nil { try await Task.sleep(for: .milliseconds(10)) }
        let page = try XCTUnwrap(shown(), "the click shows the real cockpit page")
        try await eventually("the synthetic Codex subscription draws the engine table") { await self.js(page, Self.engineDrawnScript) as? Bool == true }
        return page
    }
    @MainActor private func eventually(_ what: String, seconds: Int = 15, _ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while ContinuousClock.now < deadline { if await condition() { return }; try await Task.sleep(for: .milliseconds(50)) }
        let met = await condition()
        XCTAssertTrue(met, what)
    }
    @MainActor private func js(_ page: CockpitWindowController, _ script: String) async -> Any? {
        try? await page.verificationWebView?.evaluateJavaScript(script)
    }
    /// macrevb-1104-5: the state the real page confirmed (its bridge `receive` returned true for that `plugins` message,
    /// which happens only once `applyHostState` took it), never one merely queued.
    @MainActor private func onPage(_ page: CockpitWindowController) -> [[String: Any]] {
        guard let data = page.pluginsAccepted, let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return body["entries"] as? [[String: Any]] ?? []
    }
    private var keyScript: String { "document.querySelector('.eng-keys .pl-key[data-plugin=\"placeholder\"]')!==null" }
    private var valueScript: String { "(()=>{const v=document.querySelector('.pl-col[data-plugin=\"placeholder\"] .qvalue');return v?v.textContent:null})()" }
    private var screenScript: String { "document.querySelector('.dk-mfd .pl-screen[data-plugin=\"placeholder\"]')!==null" }
    /// Pinned plugins sit right after the subscriptions on page 1; the shown page's plugin keys in order.
    private var keyOrderScript: String { "[...document.querySelectorAll('.eng-keys .pl-key')].map(k=>k.dataset.plugin).join(',')" }

    /// The bridge journey that needs no real click: state in, running out, readings in, Settings edits live, reopen.
    @MainActor func testPluginChoicesReachTheNormalEntryPageAndDriveItsColumn() async throws {
        try await withPluginCockpit { entry, plugins, probe, _ in
            // The calendar (default on since #844) and the resource plugin (default on since #1096) are turned off, so
            // the placeholder's key and order are its own.
            let calendarOff = await plugins.model.perform(.setEnabled("calendar", false))
            let resourcesOff = await plugins.model.perform(.setEnabled("resources", false))
            XCTAssertTrue(calendarOff); XCTAssertTrue(resourcesOff)
            // Pinned, so the column is on page 1 whatever the synthetic subscriptions fill (plugin-layout.ts).
            let enabled = await plugins.model.perform(.setEnabled("placeholder", true))
            let pinnedFirst = await plugins.model.perform(.setPinned("placeholder", true))
            XCTAssertTrue(enabled); XCTAssertTrue(pinnedFirst)
            var reads = 0
            plugins.sampler.register("placeholder") { reads += 1; return ["value": 42] }
            entry.showConsole()
            let page = try await shownPage(probe)
            XCTAssertTrue(page.bridge.pluginsSent, "the native window sends `plugins` to the page it opened")
            try await eventually("the enabled plugin's key is on the real page") { await self.js(page, self.keyScript) as? Bool == true }
            // The page reports the running column; the sampler reads it and the reading reaches the column.
            try await eventually("the page runs the shown plugin") { entry.cockpitPlugins?.sampler.sampling == ["placeholder"] }
            try await eventually("the host reading is drawn in the column") { await self.js(page, self.valueScript) as? String == "42" }
            XCTAssertGreaterThan(reads, 0)
            // Settings-side unpin, pin and move reach the open page (a plugin from a newer build keeps its place).
            let future: [String: Any] = ["version": 1, "settings": [String: Any](), "entries": [
                ["id": "placeholder", "enabled": true, "pinned": false], ["id": "zz-newer-build", "enabled": false, "pinned": false],
                ["id": "calendar", "enabled": false, "pinned": false], ["id": "resources", "enabled": false, "pinned": false]]]
            let accepted = await plugins.model.acceptPageEdit(future)
            XCTAssertTrue(accepted)
            try await eventually("an unpin reaches the page") { self.onPage(page).first?["pinned"] as? Bool == false }
            let pinned = await plugins.model.perform(.setPinned("placeholder", true))
            let moved = await plugins.model.perform(.move("placeholder", 1))
            XCTAssertTrue(pinned); XCTAssertTrue(moved)
            try await eventually("pin and move reach the page") {
                let entries = self.onPage(page)
                return entries.map { $0["id"] as? String } == ["zz-newer-build", "placeholder", "calendar", "resources"]
                    && entries.first { $0["id"] as? String == "placeholder" }?["pinned"] as? Bool == true
            }
            try await eventually("the pinned plugin is drawn on page 1") { await self.js(page, self.keyOrderScript) as? String == "placeholder" }
            // Disable in Settings: the key leaves the open page and sampling stops.
            let disabled = await plugins.model.perform(.setEnabled("placeholder", false))
            XCTAssertTrue(disabled)
            try await eventually("a disabled plugin leaves the page") { await self.js(page, self.keyScript) as? Bool == false }
            try await eventually("a disabled plugin is not sampled") { plugins.sampler.sampling.isEmpty }
            // Reopen: the next page starts from the saved choices.
            let again = await plugins.model.perform(.setEnabled("placeholder", true))
            let repinned = await plugins.model.perform(.setPinned("placeholder", true))
            XCTAssertTrue(again); XCTAssertTrue(repinned)
            entry.toggleConsole()
            try await eventually("the cockpit closes") { page.window?.isVisible != true }
            try await eventually("nothing runs without a shown page") { plugins.sampler.sampling.isEmpty }
            entry.showConsole()
            let reopened = try await shownPage(probe, other: page)
            try await eventually("the reopened page shows the saved plugin") { await self.js(reopened, self.keyScript) as? Bool == true }
            XCTAssertEqual(onPage(reopened).map { $0["id"] as? String }, ["zz-newer-build", "placeholder", "calendar", "resources"])
            // #1096 card action: the app opens the plugin's big screen; asked again, it stays open.
            plugins.openScreen("placeholder")
            try await eventually("the app opens the plugin screen in the MFD") { await self.js(reopened, self.screenScript) as? Bool == true }
            plugins.openScreen("placeholder")
            try await Task.sleep(for: .milliseconds(300))
            let stillOpen = await js(reopened, screenScript) as? Bool
            XCTAssertEqual(stillOpen, true, "a second request does not toggle it closed")
        }
    }

    /// A real right-click Remove on the plugin key is saved through `pluginsEdit` and the next launch reads it.
    @MainActor func testPluginKeyRemoveOnTheNormalEntryPageIsSaved() async throws {
        try await withPluginCockpit { entry, plugins, probe, support in
            let enabled = await plugins.model.perform(.setEnabled("placeholder", true))
            let pinnedFirst = await plugins.model.perform(.setPinned("placeholder", true))
            XCTAssertTrue(enabled); XCTAssertTrue(pinnedFirst)
            NSApp.activate(ignoringOtherApps: true)
            entry.showConsole()
            let page = try await shownPage(probe)
            let window = try XCTUnwrap(page.window), web = try XCTUnwrap(page.verificationWebView)
            window.makeKeyAndOrderFront(nil)
            try await eventually("the enabled plugin's key is on the real page") { await self.js(page, self.keyScript) as? Bool == true }
            // A real click needs an active app with the cockpit as key window; hosted runners cannot activate an app.
            guard NSApp.isActive, window.isKeyWindow else {
                throw XCTSkip("The plugin key menu needs an active app and key cockpit window (GUI Mac); app active \(NSApp.isActive), key \(window.isKeyWindow)")
            }
            try await eventually("the key cockpit is active") { await self.js(page, "document.getElementById('cockpit').dataset.active") as? String == "true" }
            let scale = page.verificationLayout?.scale ?? 1
            var modifiers: NSEvent.ModifierFlags = []
            func click(_ selector: String, _ down: NSEvent.EventType, _ up: NSEvent.EventType) async throws {
                let script = "(()=>{const e=document.querySelector('\(selector)');if(!e)return null;const r=e.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()"
                let box = await js(page, script) as? [String: Double]
                let at = try XCTUnwrap(box, "\(selector) is on the page")
                let content = try XCTUnwrap(window.contentView), h = web.frame.maxY
                let p = content.convert(CGPoint(x: at["x"]! * scale, y: h - at["y"]! * scale), to: nil)
                for type in [down, up] {
                    window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: p, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: type == down ? 1 : 0)))
                }
            }
            func clickControl(_ selector: String) async throws {
                modifiers = [.control]; defer { modifiers = [] }
                try await click(selector, .leftMouseDown, .leftMouseUp)
            }
            let keySelector = ".eng-keys .pl-key[data-plugin=\"placeholder\"]", removeOpen = "document.querySelector('[data-pm-remove=\"placeholder\"]')!==null"
            // CKP-PLG-53: a real click on the key opens its big screen in the MFD; its Close button closes it.
            try await click(keySelector, .leftMouseDown, .leftMouseUp)
            try await eventually("the key opens the plugin screen") { await self.js(page, self.screenScript) as? Bool == true }
            try await click(".pl-screen .pl-screen-x", .leftMouseDown, .leftMouseUp)
            try await eventually("Close closes the plugin screen") { await self.js(page, self.screenScript) as? Bool == false }
            // macrev2-1104-3: a secondary click on the key reaches the page (its Remove menu), not the app's menu.
            try await click(keySelector, .rightMouseDown, .rightMouseUp)
            try await eventually("a right-click on the key opens its menu") { await self.js(page, removeOpen) as? Bool == true }
            _ = await js(page, "document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));true")
            try await eventually("Escape closes it") { await self.js(page, removeOpen) as? Bool == false }
            try await clickControl(keySelector)
            try await eventually("a Control-click on the key opens its menu") { await self.js(page, removeOpen) as? Bool == true }
            try await click("[data-pm-remove=\"placeholder\"]", .leftMouseDown, .leftMouseUp)
            try await eventually("the page edit is saved") { !plugins.model.preferences.enabledIDs().contains("placeholder") }
            try await eventually("the key leaves the page") { await self.js(page, self.keyScript) as? Bool == false }
            let saved = await CockpitPluginStore(directory: support).snapshot()
            XCTAssertEqual(saved.entries.first { $0.id == "placeholder" }?.enabled, false, "the next launch reads the removal")
        }
    }
}
#endif
