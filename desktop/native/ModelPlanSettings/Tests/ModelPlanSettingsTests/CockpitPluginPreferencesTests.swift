// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// Cockpit plugin columns (D121, D124, D293): the Settings side of the plugin framework.
final class CockpitPluginPreferencesTests: XCTestCase {
    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-plugins-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }
    private let two = [
        CockpitPluginDefinition(id: "a", title: .init("A", "甲"), defaultEnabled: true, settings: [
            CockpitPluginSettingSpec(key: "intervalSeconds", minimum: 3, maximum: 30, defaultValue: 10, title: .init("Interval", "间隔")),
        ]),
        CockpitPluginDefinition(id: "b", title: .init("B", "乙"), defaultEnabled: false, settings: []),
        CockpitPluginDefinition(id: "c", title: .init("C", "丙"), defaultEnabled: true, settings: []),
    ]

    func testDefaultsComeFromTheCatalogueAndThePlaceholderIsOff() {
        let empty = CockpitPluginPreferences()
        XCTAssertEqual(empty.enabledIDs(), ["calendar", "resources"], "the framework placeholder is registered but off; the calendar (D121) and the resource plugin (D324) are on")
        XCTAssertEqual(empty.materialized().entries, [.init(id: "placeholder", enabled: false, pinned: false),
                                                      .init(id: "calendar", enabled: true, pinned: false),
                                                      .init(id: "resources", enabled: true, pinned: false)])
        XCTAssertEqual(empty.enabledIDs(two), ["a", "c"])
        XCTAssertEqual(empty.value("placeholder", "intervalSeconds"), 10)
        // D324: the resource column samples every 2, 5 or 10 s; 5 by default.
        XCTAssertEqual(empty.value("resources", "intervalSeconds"), 5)
        var p = empty
        XCTAssertFalse(p.apply(.setSetting("resources", "intervalSeconds", 1)))
        XCTAssertFalse(p.apply(.setSetting("resources", "intervalSeconds", 11)))
        XCTAssertTrue(p.apply(.setSetting("resources", "intervalSeconds", 2)))
        // Only the three choices: 3 s is in range but not offered (a saved 3 reads back as the default).
        XCTAssertFalse(p.apply(.setSetting("resources", "intervalSeconds", 3)))
        XCTAssertTrue(p.apply(.setSetting("resources", "intervalSeconds", 10)))
        var saved = empty; saved.settings = ["resources": ["intervalSeconds": 7]]
        XCTAssertEqual(saved.value("resources", "intervalSeconds"), 5)
    }

    /// D324 Settings row: switch, interval (2 / 5 / 10 s as one segmented control) and pin to page 1.
    @MainActor func testResourceRowHasSwitchIntervalChoicesAndPin() async throws {
        let model = CockpitPluginSettingsModel(store: CockpitPluginStore(directory: try directory()))
        let view = SettingsCockpitPluginsView(model: model, language: .chinese)
        view.apply(language: .chinese, paneID: "subscriptions", query: "")
        func find<T: NSView>(_ id: String, _ type: T.Type) -> T? {
            var queue: [NSView] = [view]
            while let next = queue.first { queue.removeFirst(); if next.accessibilityIdentifier() == id, let hit = next as? T { return hit }; queue += next.subviews }
            return nil
        }
        let enabled = try XCTUnwrap(find("settings.cockpitPlugins.resources.enabled", NSButton.self))
        XCTAssertEqual(enabled.state, .on, "default on (D324)")
        let pin = try XCTUnwrap(find("settings.cockpitPlugins.resources.pinned", NSButton.self))
        XCTAssertEqual(pin.title, "固定到驾驶舱第 1 页"); XCTAssertTrue(pin.isEnabled); XCTAssertEqual(pin.state, .off, "off by default (D371)")
        XCTAssertNil(find("settings.cockpitPlugins.resources.intervalSeconds", NSStepper.self), "choices, not a stepper")
        let choices = try XCTUnwrap(find("settings.cockpitPlugins.resources.intervalSeconds", NSSegmentedControl.self))
        XCTAssertEqual((0..<choices.segmentCount).map { choices.label(forSegment: $0) }, ["2 秒", "5 秒", "10 秒"])
        XCTAssertEqual(choices.selectedSegment, 1, "5 s by default")
        let changed = expectation(description: "model change")
        model.onChange = { _ in changed.fulfill() }
        choices.selectedSegment = 2
        XCTAssertTrue(choices.sendAction(choices.action, to: choices.target))
        await fulfillment(of: [changed], timeout: 3)
        XCTAssertEqual(model.preferences.value("resources", "intervalSeconds"), 10)
        try await Task.sleep(nanoseconds: 50_000_000)
        let pinNow = try XCTUnwrap(find("settings.cockpitPlugins.resources.pinned", NSButton.self))
        let pinned = expectation(description: "pinned")
        model.onChange = { _ in pinned.fulfill() }
        pinNow.state = .on
        XCTAssertTrue(pinNow.sendAction(pinNow.action, to: pinNow.target))
        await fulfillment(of: [pinned], timeout: 3)
        XCTAssertEqual(model.preferences.entries.first { $0.id == "resources" }?.pinned, true)
    }

    func testEditsFollowThePageRules() {
        var p = CockpitPluginPreferences()
        XCTAssertFalse(p.apply(.setPinned("b", true), two), "an off plugin cannot be pinned")
        XCTAssertTrue(p.apply(.setEnabled("b", true), two))
        XCTAssertTrue(p.apply(.setPinned("a", true), two))
        XCTAssertTrue(p.apply(.setPinned("b", true), two))
        let before = p
        XCTAssertFalse(p.apply(.setPinned("c", true), two), "at most two pinned")
        XCTAssertEqual(p, before, "a refused edit changes nothing")
        XCTAssertFalse(p.canPin("c", two))
        XCTAssertTrue(p.apply(.setEnabled("a", false), two))
        XCTAssertEqual(p.entries.first { $0.id == "a" }, .init(id: "a", enabled: false, pinned: false), "removing also unpins")
        XCTAssertTrue(p.canPin("c", two))
        XCTAssertTrue(p.apply(.move("c", -1), two))
        XCTAssertEqual(p.entries.map(\.id), ["a", "c", "b"])
        XCTAssertFalse(p.apply(.move("a", -1), two))
        XCTAssertFalse(p.apply(.move("a", 2), two))
        XCTAssertFalse(p.apply(.setEnabled("unknown", true), two))
        // D124: sampling interval 3–30 s.
        XCTAssertFalse(p.apply(.setSetting("a", "intervalSeconds", 2), two))
        XCTAssertFalse(p.apply(.setSetting("a", "intervalSeconds", 31), two))
        XCTAssertFalse(p.apply(.setSetting("a", "other", 5), two))
        XCTAssertTrue(p.apply(.setSetting("a", "intervalSeconds", 3), two))
        XCTAssertEqual(p.value("a", "intervalSeconds", two), 3)
        p.settings["a"]?["intervalSeconds"] = 99
        XCTAssertEqual(p.value("a", "intervalSeconds", two), 10, "an out-of-range saved value reads as the default")
    }

    func testDecodingFailsClosedAndKeepsUnknownPlugins() throws {
        let good = #"{"version":1,"entries":[{"id":"future-plugin","enabled":true,"pinned":true},{"id":"placeholder","enabled":true,"pinned":false}],"settings":{"placeholder":{"intervalSeconds":5}}}"#
        let decoded = try JSONDecoder().decode(CockpitPluginPreferences.self, from: Data(good.utf8))
        XCTAssertEqual(decoded.entries.map(\.id), ["future-plugin", "placeholder"])
        XCTAssertEqual(decoded.enabledIDs(), ["placeholder", "calendar", "resources"])
        let round = try JSONDecoder().decode(CockpitPluginPreferences.self, from: try decoded.bridgeJSON())
        XCTAssertEqual(round, decoded)
        for bad in [
            #"{"version":2,"entries":[],"settings":{}}"#,
            #"{"version":1,"entries":[{"id":"Bad","enabled":true,"pinned":false}],"settings":{}}"#,
            #"{"version":1,"entries":[{"id":"a","enabled":false,"pinned":true}],"settings":{}}"#,
            #"{"version":1,"entries":[{"id":"a","enabled":true,"pinned":true},{"id":"b","enabled":true,"pinned":true},{"id":"c","enabled":true,"pinned":true}],"settings":{}}"#,
            #"{"version":1,"entries":[{"id":"a","enabled":true,"pinned":false},{"id":"a","enabled":true,"pinned":false}],"settings":{}}"#,
            #"{"version":1,"entries":[],"settings":{"a":{"intervalSeconds":2.5}}}"#,
            #"{"version":1,"entries":[],"settings":{"a":{"bad-key":3}}}"#,
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(CockpitPluginPreferences.self, from: Data(bad.utf8)), bad)
        }
    }

    func testPageEditsAreCheckedForExactKeys() throws {
        let page: [String: Any] = ["version": 1, "entries": [["id": "placeholder", "enabled": true, "pinned": true]], "settings": [:] as [String: Any]]
        XCTAssertEqual(try CockpitPluginPreferences.fromPage(page).entries, [.init(id: "placeholder", enabled: true, pinned: true)])
        var extra = page; extra["more"] = true
        XCTAssertThrowsError(try CockpitPluginPreferences.fromPage(extra))
        let entryExtra: [String: Any] = ["version": 1, "entries": [["id": "placeholder", "enabled": true, "pinned": false, "x": 1]], "settings": [:] as [String: Any]]
        XCTAssertThrowsError(try CockpitPluginPreferences.fromPage(entryExtra))
        XCTAssertThrowsError(try CockpitPluginPreferences.fromPage("not an object"))
    }

    func testStorePersistsBesideSettingsAndIgnoresAnUnreadableFile() async throws {
        let dir = try directory()
        let store = CockpitPluginStore(directory: dir)
        let fresh = await store.snapshot()
        XCTAssertEqual(fresh, CockpitPluginPreferences())
        var p = fresh; XCTAssertTrue(p.apply(.setEnabled("placeholder", true))); XCTAssertTrue(p.apply(.setPinned("placeholder", true)))
        try await store.save(p)
        let reopened = await CockpitPluginStore(directory: dir).snapshot()
        XCTAssertEqual(reopened, p)
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(CockpitPluginStore.fileName).path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        try Data("{not json".utf8).write(to: dir.appendingPathComponent(CockpitPluginStore.fileName))
        let corrupt = await CockpitPluginStore(directory: dir).snapshot()
        XCTAssertEqual(corrupt, CockpitPluginPreferences(), "an unreadable file reads as defaults")
    }

    @MainActor func testModelSavesNotifiesAndRefusesWithoutChange() async throws {
        let store = CockpitPluginStore(directory: try directory())
        let model = await CockpitPluginSettingsModel.load(from: store)
        var sent: [CockpitPluginPreferences] = []
        model.onChange = { sent.append($0) }
        let enabled = await model.perform(.setEnabled("placeholder", true))
        XCTAssertTrue(enabled)
        let refused = await model.perform(.setSetting("placeholder", "intervalSeconds", 1))
        XCTAssertFalse(refused)
        XCTAssertEqual(sent.count, 1)
        let saved = await store.snapshot()
        XCTAssertEqual(saved, model.preferences)
        let fromPage = await model.acceptPageEdit(["version": 1, "entries": [["id": "placeholder", "enabled": false, "pinned": false], ["id": "resources", "enabled": false, "pinned": false]], "settings": [:] as [String: Any]] as [String: Any])
        XCTAssertTrue(fromPage)
        XCTAssertEqual(model.preferences.enabledIDs(), ["calendar"])
        XCTAssertEqual(sent.count, 2)
    }

    /// CKP-PLG-54: the "Plugins" section of Settings › Subscriptions: icon, one sentence, toggle, options, pin to page 1.
    @MainActor func testSettingsSectionShowsOnTheSubscriptionsPaneAndEditsThroughTheModel() async throws {
        // A listed off-by-default plugin with a stepper (the shape the framework placeholder had; owner 11-21 took the
        // placeholder itself out of Settings).
        let trial = CockpitPluginDefinition(id: "placeholder", title: .init("Placeholder", "占位插件"),
            summary: .init("Shows the last number the app sent; for trying plugins.", "显示应用推来的最后一个数，用来试插件框架。"),
            symbol: "dot.square", defaultEnabled: false, settings: [
                CockpitPluginSettingSpec(key: "intervalSeconds", minimum: 3, maximum: 30, defaultValue: 10, title: .init("Update interval", "更新间隔")),
            ])
        let catalogue = [trial] + CockpitPluginCatalogue.builtIn.filter { $0.id != "placeholder" }
        let model = CockpitPluginSettingsModel(store: CockpitPluginStore(directory: try directory()), catalogue: catalogue)
        let view = SettingsCockpitPluginsView(model: model, language: .english)
        XCTAssertTrue(view.isHidden, "hidden until the window places it")
        view.apply(language: .english, paneID: "subscriptions", query: "")
        XCTAssertFalse(view.isHidden)
        view.apply(language: .english, paneID: "cockpit", query: "")
        XCTAssertTrue(view.isHidden, "no longer a separate section on the Cockpit pane")
        view.apply(language: .english, paneID: "general", query: "")
        XCTAssertTrue(view.isHidden)
        view.apply(language: .chinese, paneID: "general", query: "插件")
        XCTAssertFalse(view.isHidden)
        func find<T: NSView>(_ id: String, _ type: T.Type) -> T? {
            var queue: [NSView] = [view]
            while let next = queue.first { queue.removeFirst(); if next.accessibilityIdentifier() == id, let hit = next as? T { return hit }; queue += next.subviews }
            return nil
        }
        view.apply(language: .english, paneID: "subscriptions", query: "")
        XCTAssertNotNil(find("settings.cockpitPlugins.placeholder.icon", NSImageView.self)?.image, "the plugin's line icon")
        XCTAssertEqual(find("settings.cockpitPlugins.placeholder.summary", NSTextField.self)?.stringValue,
                       "Shows the last number the app sent; for trying plugins.")
        XCTAssertEqual(find("settings.cockpitPlugins.placeholder.pinned", NSButton.self)?.title, "Pin to cockpit page 1")
        let enabled = try XCTUnwrap(find("settings.cockpitPlugins.placeholder.enabled", NSButton.self))
        let pin = try XCTUnwrap(find("settings.cockpitPlugins.placeholder.pinned", NSButton.self))
        let stepper = try XCTUnwrap(find("settings.cockpitPlugins.placeholder.intervalSeconds", NSStepper.self))
        XCTAssertEqual(enabled.state, .off); XCTAssertFalse(pin.isEnabled, "an off plugin cannot be pinned"); XCTAssertFalse(stepper.isEnabled)
        let changed = expectation(description: "model change")
        model.onChange = { _ in changed.fulfill() }
        enabled.state = .on
        XCTAssertTrue(enabled.sendAction(enabled.action, to: enabled.target))
        await fulfillment(of: [changed], timeout: 3)
        XCTAssertEqual(model.preferences.enabledIDs(catalogue), ["placeholder", "calendar", "resources"])
        // The section rebuilds after the save; the new pin box is enabled now.
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(try XCTUnwrap(find("settings.cockpitPlugins.placeholder.pinned", NSButton.self)).isEnabled)
    }

    /// Owner 11-21: the framework placeholder is a test plugin and must not ship to users. Fails before: Settings ›
    /// Subscriptions › Plugins listed "占位插件" first, with its switch, pin and interval.
    @MainActor func testReleaseSettingsNeverListsThePlaceholder() async throws {
        let dir = try directory()
        let editor = SettingsEditor(store: try SettingsStore(url: dir.appendingPathComponent("preferences.json")))
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        // A saved state that has the placeholder on still never lists it.
        var saved = CockpitPluginPreferences()
        XCTAssertTrue(saved.apply(.setEnabled("placeholder", true)))
        controller.attachCockpitPlugins(CockpitPluginSettingsModel(preferences: saved, store: CockpitPluginStore(directory: dir)))
        controller.selectPane("subscriptions")
        let section = try XCTUnwrap(controller.cockpitPluginsView)
        XCTAssertFalse(section.isHidden)
        var ids: [String] = [], queue: [NSView] = [section]
        while let next = queue.first { queue.removeFirst(); ids.append(next.accessibilityIdentifier()); queue += next.subviews }
        XCTAssertFalse(ids.contains { $0.hasPrefix("settings.cockpitPlugins.placeholder") }, "no placeholder row: \(ids.filter { $0.hasPrefix("settings.cockpitPlugins.") })")
        let rows = ids.filter { $0.hasPrefix("settings.cockpitPlugins.") && $0.hasSuffix(".enabled") }
        XCTAssertEqual(rows, ["settings.cockpitPlugins.calendar.enabled", "settings.cockpitPlugins.resources.enabled"])
        XCTAssertEqual(CockpitPluginCatalogue.listed().map(\.id), ["calendar", "resources"])
        XCTAssertTrue(CockpitPluginCatalogue.builtIn.contains { $0.id == "placeholder" && $0.frameworkOnly }, "still there for tests and fixtures")
        controller.close()
    }

    /// Owner 11-21: a listed plugin's arrows step over the unlisted placeholder, so one press is one visible move.
    func testMovingStepsOverTheUnlistedPlaceholder() {
        var p = CockpitPluginPreferences()
        // Materialized order: placeholder, calendar, resources. Calendar has no listed plugin before it.
        XCTAssertFalse(p.apply(.move("calendar", -1)), "the first listed plugin cannot move earlier")
        XCTAssertTrue(p.apply(.move("resources", -1)))
        XCTAssertEqual(p.entries.map(\.id), ["placeholder", "resources", "calendar"])
        var q = CockpitPluginPreferences()
        q.entries = [.init(id: "calendar", enabled: true, pinned: false), .init(id: "placeholder", enabled: false, pinned: false),
                     .init(id: "resources", enabled: true, pinned: false)]
        XCTAssertTrue(q.apply(.move("calendar", 1)))
        XCTAssertEqual(q.entries.map(\.id), ["placeholder", "resources", "calendar"], "one press passes the hidden entry and the next listed one")
    }

    /// Owner 11-21: no plugin is pinned to page 1 by default; a new or re-enabled plugin is unpinned, and a pin the user
    /// set is never changed by defaults.
    func testPluginsStartUnpinnedAndUserPinsStay() {
        XCTAssertTrue(CockpitPluginPreferences().materialized().entries.allSatisfy { !$0.pinned })
        var p = CockpitPluginPreferences()
        XCTAssertTrue(p.apply(.setEnabled("resources", false)))
        XCTAssertTrue(p.apply(.setEnabled("resources", true)))
        XCTAssertEqual(p.entries.first { $0.id == "resources" }?.pinned, false, "re-enabled: unpinned")
        XCTAssertTrue(p.apply(.setPinned("calendar", true)))
        let saved = p.materialized()
        XCTAssertEqual(saved.entries.first { $0.id == "calendar" }?.pinned, true, "a user pin survives materializing")
        XCTAssertTrue(p.apply(.setEnabled("resources", true)))
        XCTAssertEqual(p.entries.first { $0.id == "calendar" }?.pinned, true)
    }

    @MainActor func testWindowAttachesTheSectionToTheSubscriptionsPane() async throws {
        let dir = try directory()
        let editor = SettingsEditor(store: try SettingsStore(url: dir.appendingPathComponent("preferences.json")))
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        controller.attachCockpitPlugins(CockpitPluginSettingsModel(store: CockpitPluginStore(directory: dir)))
        let section = try XCTUnwrap(controller.cockpitPluginsView)
        controller.selectPane("subscriptions"); XCTAssertFalse(section.isHidden)
        controller.selectPane("cockpit"); XCTAssertTrue(section.isHidden)
        controller.selectPane("appearance"); XCTAssertTrue(section.isHidden)
        controller.close()
    }
}
