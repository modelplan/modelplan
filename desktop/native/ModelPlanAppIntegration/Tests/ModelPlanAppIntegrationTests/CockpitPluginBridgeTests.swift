// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanCockpitWeb
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// macrevc-844-1: the app side of the plugin columns: the sampler follows the page's running set and the saved
/// choices, and page edits are saved to the same file Settings uses.
final class CockpitPluginBridgeTests: XCTestCase {
    @MainActor private final class FakeSchedule {
        var pending: [(delay: TimeInterval, fire: @MainActor () -> Void, cancelled: Bool)] = []
        var schedule: CockpitPluginSampler.Schedule {
            { [unowned self] delay, fire in
                self.pending.append((delay, fire, false)); let i = self.pending.count - 1
                return { [weak self] in self?.pending[i].cancelled = true }
            }
        }
        var live: [TimeInterval] { pending.filter { !$0.cancelled }.map(\.delay) }
        /// Fires every live timer once (each schedules its successor).
        func fireAll() { let due = pending.indices.filter { !pending[$0].cancelled }; for i in due { pending[i].cancelled = true; pending[i].fire() } }
    }
    private func preferences(_ on: Bool, interval: Int? = nil) -> CockpitPluginPreferences {
        var p = CockpitPluginPreferences()
        p.apply(.setEnabled("placeholder", on))
        if let interval { p.apply(.setSetting("placeholder", "intervalSeconds", interval)) }
        return p
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plugin-bridge-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    @MainActor func testSamplerReadsOnlyRunningEnabledRegisteredPluginsAtTheirInterval() {
        let clock = FakeSchedule()
        let sampler = CockpitPluginSampler(schedule: clock.schedule)
        var sent: [(String, Int)] = [], value = 0
        sampler.send = { id, data in sent.append((id, data["value"] as? Int ?? -1)) }
        sampler.register("placeholder") { value += 1; return ["value": value] }
        sampler.setRunning(["placeholder"])
        XCTAssertTrue(sent.isEmpty, "off by default: never sampled")
        sampler.apply(preferences(true))
        XCTAssertEqual(sent.map(\.1), [1], "the first reading is taken at once")
        XCTAssertEqual(clock.live, [10], "then at the default interval")
        clock.fireAll()
        XCTAssertEqual(sent.map(\.1), [1, 2]); XCTAssertEqual(clock.live, [10])
        sampler.apply(preferences(true, interval: 3))
        XCTAssertEqual(clock.live, [3], "a new interval replaces the timer")
        sampler.setRunning([])
        XCTAssertEqual(clock.live, [], "a plugin the page stopped is not sampled")
        XCTAssertEqual(sampler.sampling, [])
        sampler.setRunning(["placeholder", "calendar"])
        XCTAssertEqual(sampler.sampling, ["placeholder"], "a plugin without a reader (calendar) is never sampled")
        sampler.apply(preferences(false))
        XCTAssertEqual(clock.live, []); XCTAssertEqual(sampler.sampling, [])
        let count = sent.count
        clock.fireAll()
        XCTAssertEqual(sent.count, count, "nothing after the plugin is turned off")
    }

    @MainActor func testPageEditsAreSavedAndSettingsEditsReachTheCoordinator() async throws {
        let dir = try directory()
        let coordinator = EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        let bridge = await CockpitPluginBridge.load(directory: dir, coordinator: coordinator)
        let initial = try XCTUnwrap(coordinator.pluginsJSON)
        XCTAssertEqual(CockpitPluginWire.canonical(json: initial), CockpitPluginWire.canonical(json: try CockpitPluginPreferences().bridgeJSON()),
                       "a fresh profile sends the empty state; the page fills in each plugin's default")
        // Settings: pin needs the plugin on; both reach the coordinator.
        let enabled = await bridge.model.perform(.setEnabled("placeholder", true))
        let pinnedOK = await bridge.model.perform(.setPinned("placeholder", true))
        XCTAssertTrue(enabled); XCTAssertTrue(pinnedOK)
        let pinned = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(coordinator.pluginsJSON)) as? [String: Any])
        XCTAssertEqual((pinned["entries"] as? [[String: Any]])?.first?["pinned"] as? Bool, true)
        // The page removes it: the edit arrives as canonical JSON and is saved to cockpit-plugins.json.
        let edit = try XCTUnwrap(CockpitPluginWire.canonical(["version": 1, "entries": [["id": "placeholder", "enabled": false, "pinned": false]], "settings": [String: Any]()]))
        coordinator.onPluginsEdit?(edit)
        for _ in 0..<200 where bridge.model.preferences.enabledIDs().contains("placeholder") { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(bridge.model.preferences.enabledIDs().contains("placeholder"))
        XCTAssertEqual(CockpitPluginWire.canonical(json: try XCTUnwrap(coordinator.pluginsJSON)), edit)
        let reopened = await CockpitPluginStore(directory: dir).snapshot()
        XCTAssertEqual(reopened.entries, [.init(id: "placeholder", enabled: false, pinned: false)], "the edit survives a restart")
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(CockpitPluginStore.fileName).path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        // A malformed edit changes nothing.
        coordinator.onPluginsEdit?(Data("[1]".utf8))
        try await Task.sleep(for: .milliseconds(50))
        let after = await CockpitPluginStore(directory: dir).snapshot()
        XCTAssertEqual(after, reopened)
    }

    /// macrevb-1104-3 / macrevd-1104-2 / macrev2-1104-4: a page edit that cannot be saved sends the committed choice to
    /// the page again (the page already removed the key), and the sampler keeps following the committed choice.
    @MainActor func testAFailedPageEditSaveRestoresTheCommittedChoice() async throws {
        let dir = try directory()
        let coordinator = EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        let bridge = await CockpitPluginBridge.load(directory: dir, coordinator: coordinator)
        let enabled = await bridge.model.perform(.setEnabled("placeholder", true))
        XCTAssertTrue(enabled)
        let committed = try XCTUnwrap(coordinator.pluginsJSON)
        // The store cannot be written any more.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path)
        addTeardownBlock { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path) }
        let edit = try XCTUnwrap(CockpitPluginWire.canonical(["version": 1, "entries": [["id": "placeholder", "enabled": false, "pinned": false]], "settings": [String: Any]()]))
        // Stand-in for the page having shown its own edit: the coordinator last held the edit.
        coordinator.pluginsJSON = edit
        coordinator.onPluginsEdit?(edit)
        for _ in 0..<200 where coordinator.pluginsJSON == edit { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(CockpitPluginWire.canonical(json: try XCTUnwrap(coordinator.pluginsJSON)), CockpitPluginWire.canonical(json: committed),
                       "the committed choice goes back to the page")
        XCTAssertTrue(bridge.model.preferences.enabledIDs().contains("placeholder"), "nothing was committed")
        let disk = await CockpitPluginStore(directory: dir).snapshot()
        XCTAssertEqual(disk.entries.first { $0.id == "placeholder" }?.enabled, true, "reopen shows what the page shows again")
        // Writable again: the same edit is saved and survives a restart.
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        coordinator.onPluginsEdit?(edit)
        for _ in 0..<200 where bridge.model.preferences.enabledIDs().contains("placeholder") { try await Task.sleep(for: .milliseconds(5)) }
        let saved = await CockpitPluginStore(directory: dir).snapshot()
        XCTAssertEqual(saved.entries.first { $0.id == "placeholder" }?.enabled, false)
    }

    /// #1096 moved here: the bridge owns the coordinator's and model's single callbacks and fans out to every observer
    /// (the resource plugin host among them); the sampler keeps working beside them.
    @MainActor func testRunningAndChoicesFanOutToEveryObserver() async throws {
        let coordinator = EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        let bridge = await CockpitPluginBridge.load(directory: try directory(), coordinator: coordinator)
        var first: [[String]] = [], second: [[String]] = [], choices: [[String]] = [], reads = 0
        bridge.observeRunning { first.append($0) }
        bridge.observeRunning { second.append($0) }
        bridge.observeChoices { choices.append($0.enabledIDs()) }
        bridge.sampler.register("placeholder") { reads += 1; return ["value": 1] }
        XCTAssertEqual(first, [[]]); XCTAssertEqual(second, [[]]); XCTAssertEqual(choices, [[]], "observers start from the current values")
        let enabled = await bridge.model.perform(.setEnabled("placeholder", true))
        XCTAssertTrue(enabled)
        XCTAssertEqual(choices.last, ["placeholder"])
        coordinator.onPluginsRunning?(["placeholder"])
        XCTAssertEqual(first.last, ["placeholder"]); XCTAssertEqual(second.last, ["placeholder"])
        XCTAssertEqual(reads, 1, "the sampler still follows the running set")
    }

    /// #1096 card action (moved here): open the plugin's big screen and show the cockpit.
    @MainActor func testOpenScreenAsksTheCockpitAndShowsIt() async throws {
        let coordinator = EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        let bridge = await CockpitPluginBridge.load(directory: try directory(), coordinator: coordinator)
        var shown = 0
        bridge.showCockpit = { shown += 1 }
        bridge.openScreen("placeholder")
        XCTAssertEqual(shown, 1)
        XCTAssertEqual(coordinator.pluginScreenRequest, "placeholder", "held for the page the show makes")
    }
}
