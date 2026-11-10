// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// v1.1 cockpit plugin columns (D121, D124, D126, D127): the Settings side of the plugin framework.
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
        XCTAssertEqual(empty.enabledIDs(), [], "the framework placeholder is registered but off")
        XCTAssertEqual(empty.materialized().entries, [.init(id: "placeholder", enabled: false, pinned: false)])
        XCTAssertEqual(empty.enabledIDs(two), ["a", "c"])
        XCTAssertEqual(empty.value("placeholder", "intervalSeconds"), 10)
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
        XCTAssertEqual(decoded.enabledIDs(), ["placeholder"])
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
        let fromPage = await model.acceptPageEdit(["version": 1, "entries": [["id": "placeholder", "enabled": false, "pinned": false]], "settings": [:] as [String: Any]] as [String: Any])
        XCTAssertTrue(fromPage)
        XCTAssertEqual(model.preferences.enabledIDs(), [])
        XCTAssertEqual(sent.count, 2)
    }

    @MainActor func testSettingsSectionShowsOnTheCockpitPaneAndEditsThroughTheModel() async throws {
        let model = CockpitPluginSettingsModel(store: CockpitPluginStore(directory: try directory()))
        let view = SettingsCockpitPluginsView(model: model, language: .english)
        XCTAssertTrue(view.isHidden, "hidden until the window places it")
        view.apply(language: .english, paneID: "cockpit", query: "")
        XCTAssertFalse(view.isHidden)
        view.apply(language: .english, paneID: "general", query: "")
        XCTAssertTrue(view.isHidden)
        view.apply(language: .chinese, paneID: "general", query: "插件")
        XCTAssertFalse(view.isHidden)
        func find<T: NSView>(_ id: String, _ type: T.Type) -> T? {
            var queue: [NSView] = [view]
            while let next = queue.first { queue.removeFirst(); if next.accessibilityIdentifier() == id, let hit = next as? T { return hit }; queue += next.subviews }
            return nil
        }
        let enabled = try XCTUnwrap(find("settings.cockpitPlugins.placeholder.enabled", NSButton.self))
        let pin = try XCTUnwrap(find("settings.cockpitPlugins.placeholder.pinned", NSButton.self))
        let stepper = try XCTUnwrap(find("settings.cockpitPlugins.placeholder.intervalSeconds", NSStepper.self))
        XCTAssertEqual(enabled.state, .off); XCTAssertFalse(pin.isEnabled, "an off plugin cannot be pinned"); XCTAssertFalse(stepper.isEnabled)
        let changed = expectation(description: "model change")
        model.onChange = { _ in changed.fulfill() }
        enabled.state = .on
        XCTAssertTrue(enabled.sendAction(enabled.action, to: enabled.target))
        await fulfillment(of: [changed], timeout: 3)
        XCTAssertEqual(model.preferences.enabledIDs(), ["placeholder"])
        // The section rebuilds after the save; the new pin box is enabled now.
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(try XCTUnwrap(find("settings.cockpitPlugins.placeholder.pinned", NSButton.self)).isEnabled)
    }

    @MainActor func testWindowAttachesTheSectionToTheCockpitPane() async throws {
        let dir = try directory()
        let editor = SettingsEditor(store: try SettingsStore(url: dir.appendingPathComponent("preferences.json")))
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        controller.attachCockpitPlugins(CockpitPluginSettingsModel(store: CockpitPluginStore(directory: dir)))
        let section = try XCTUnwrap(controller.cockpitPluginsView)
        controller.selectPane("cockpit"); XCTAssertFalse(section.isHidden)
        controller.selectPane("appearance"); XCTAssertTrue(section.isHidden)
        controller.close()
    }
}
