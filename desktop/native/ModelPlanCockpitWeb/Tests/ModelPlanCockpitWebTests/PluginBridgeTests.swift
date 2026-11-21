// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

/// macrevc-844-1: plugin columns over the native bridge (desktop/cockpit/src/bridge.ts, plugin-state.ts):
/// host -> page `plugins` and `pluginData`; page -> host actions `pluginsRunning` and `pluginsEdit`.
extension BridgeTests {
  private var pluginsBody: Data {
    Data(#"{"entries":[{"enabled":true,"id":"calendar","pinned":true},{"enabled":false,"id":"placeholder","pinned":false}],"settings":{"placeholder":{"intervalSeconds":10}},"version":1}"#.utf8)
  }
  private var editBody: [String: Any] {
    ["version": 1, "entries": [["id": "calendar", "enabled": false, "pinned": false]], "settings": [String: Any]()]
  }

  func testPluginsEnvelopeCarriesTheCanonicalStateToAReadyPage() throws {
    let state = CockpitBridgeState(context: try context())
    XCTAssertThrowsError(try state.setPlugins(pluginsBody), "nothing before the page is ready")
    _ = try ready(state)
    XCTAssertFalse(state.pluginsSent)
    let sent = try object(state.setPlugins(pluginsBody))
    XCTAssertTrue(state.pluginsSent)
    XCTAssertEqual(sent["type"] as? String, "plugins")
    let body = try XCTUnwrap(sent["plugins"] as? [String: Any])
    XCTAssertEqual(Set(body.keys), ["version", "entries", "settings"])
    let entries = try XCTUnwrap(body["entries"] as? [[String: Any]])
    XCTAssertEqual(entries.map { $0["id"] as? String }, ["calendar", "placeholder"], "user order is kept")
    XCTAssertEqual(CockpitPluginWire.bool(entries[0]["pinned"]), true, "a real JSON boolean, as the page's parser requires")
    for bad in [#"{"version":2,"entries":[],"settings":{}}"#,
                #"{"version":1,"entries":[{"id":"calendar","enabled":false,"pinned":true}],"settings":{}}"#,
                #"{"version":1,"entries":[{"id":"calendar","enabled":1,"pinned":false}],"settings":{}}"#,
                #"{"version":1,"entries":[{"id":"Calendar","enabled":true,"pinned":false}],"settings":{}}"#,
                #"{"version":1,"entries":[],"settings":{"calendar":{"intervalSeconds":1.5}}}"#,
                #"{"version":1,"entries":[],"settings":{"calendar":{"intervalSeconds":90000}}}"#,
                #"{"version":1,"entries":[],"settings":{},"extra":true}"#] {
      XCTAssertThrowsError(try state.setPlugins(Data(bad.utf8)), bad)
    }
  }

  /// #1096 card action: open a plugin's big screen. Only after `plugins`, with a valid id.
  func testPluginScreenEnvelopeNeedsSentStateAndAValidID() throws {
    let state = CockpitBridgeState(context: try context())
    XCTAssertThrowsError(try state.openPluginScreen(id: "placeholder"), "not before ready")
    _ = try ready(state)
    XCTAssertThrowsError(try state.openPluginScreen(id: "placeholder"), "not before the plugin state")
    _ = try state.setPlugins(pluginsBody)
    let sent = try object(state.openPluginScreen(id: "placeholder"))
    XCTAssertEqual(sent["type"] as? String, "pluginScreen")
    XCTAssertEqual(sent["id"] as? String, "placeholder")
    XCTAssertThrowsError(try state.openPluginScreen(id: "Bad id"))
  }

  func testPluginDataNeedsSentStateAVisiblePageAndAValidID() throws {
    let state = CockpitBridgeState(context: try context())
    _ = try ready(state)
    XCTAssertThrowsError(try state.pluginData(id: "placeholder", data: ["value": 42]), "no plugin state sent yet")
    _ = try state.setPlugins(pluginsBody)
    XCTAssertThrowsError(try state.pluginData(id: "placeholder", data: ["value": 42]), "a hidden page gets no readings")
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: false))
    let reading = try object(state.pluginData(id: "placeholder", data: ["value": 42]))
    XCTAssertEqual(reading["type"] as? String, "pluginData")
    XCTAssertEqual(reading["id"] as? String, "placeholder")
    XCTAssertEqual((reading["data"] as? [String: Any])?["value"] as? Int, 42)
    XCTAssertThrowsError(try state.pluginData(id: "Bad id", data: [:]))
    _ = try state.setVisibility(.init(visible: true, occluded: true, key: false))
    XCTAssertThrowsError(try state.pluginData(id: "placeholder", data: ["value": 42]), "an occluded page gets no readings")
  }

  func testPluginsRunningIsAcceptedWithoutFocusOnlyAfterPlugins() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    let running = try reply(load, "action", 2, extra: ["action": "pluginsRunning", "ids": ["calendar"]])
    XCTAssertThrowsError(try state.accept(running, source: source), "an older host never sees a plugin action")
    _ = try state.setPlugins(pluginsBody)
    // D124 (macrevb-1104-4): a start is taken only from a shown page (key or not); a stop always.
    XCTAssertThrowsError(try state.accept(running, source: source), "a hidden page cannot start sampling")
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: false))
    XCTAssertEqual(try state.accept(running, source: source), .action(.pluginsRunning(["calendar"])))
    _ = try state.setVisibility(.init(visible: true, occluded: true, key: false))
    // A hiding page reports that it stopped its plugins; that must reach the host or it keeps sampling.
    XCTAssertEqual(try state.accept(reply(load, "action", 3, extra: ["action": "pluginsRunning", "ids": [String]()]), source: source),
                   .action(.pluginsRunning([])))
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: false))
    XCTAssertThrowsError(try state.accept(reply(load, "action", 4, extra: ["action": "pluginsRunning", "ids": ["a", "a"]]), source: source))
    XCTAssertThrowsError(try state.accept(reply(load, "action", 5, extra: ["action": "pluginsRunning", "ids": ["Bad"]]), source: source))
    let seventeen = (0..<17).map { "p\($0)" }
    XCTAssertThrowsError(try state.accept(reply(load, "action", 6, extra: ["action": "pluginsRunning", "ids": seventeen]), source: source))
  }

  func testPluginsEditNeedsFocusAndArrivesCanonical() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: true))
    XCTAssertThrowsError(try state.accept(reply(load, "action", 2, extra: ["action": "pluginsEdit", "plugins": editBody]), source: source),
                         "not before the host sent its plugin state")
    _ = try state.setPlugins(pluginsBody)
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: false))
    XCTAssertThrowsError(try state.accept(reply(load, "action", 3, extra: ["action": "pluginsEdit", "plugins": editBody]), source: source),
                         "an edit needs the focused page")
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: true))
    let accepted = try state.accept(reply(load, "action", 4, extra: ["action": "pluginsEdit", "plugins": editBody]), source: source)
    guard case .action(.pluginsEdit(let data)) = accepted else { return XCTFail("\(accepted)") }
    XCTAssertEqual(data, CockpitPluginWire.canonical(editBody))
    var numeric = editBody; numeric["entries"] = [["id": "calendar", "enabled": 0, "pinned": false]]
    XCTAssertThrowsError(try state.accept(reply(load, "action", 5, extra: ["action": "pluginsEdit", "plugins": numeric]), source: source),
                         "0 is not false")
  }

  /// The one nested reply value is scanned with bounds before JSONSerialization can collapse duplicate keys.
  func testNestedPluginsReplyIsBounded() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    _ = try state.setPlugins(pluginsBody)
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: true))
    // macrevb-1104-5: every refusal below reuses sequence 2, and the valid edit at the end uses it too, so a refusal
    // that consumed its sequence would make that last edit fail.
    let sequence = 2
    func edit(_ plugins: Any, rewrite: ((String) -> String)? = nil) throws -> String {
      let raw = try reply(load, "action", sequence, extra: ["action": "pluginsEdit", "plugins": plugins])
      return rewrite?(raw) ?? raw
    }
    let duplicate = try edit(editBody) { $0.replacingOccurrences(of: #""pinned":false"#, with: #""pinned":false,"pinned":true"#) }
    XCTAssertTrue(duplicate.contains(#""pinned":false,"pinned":true"#))
    XCTAssertThrowsError(try state.accept(duplicate, source: source), "a duplicate key inside the nested body")
    let deep: [String: Any] = ["version": 1, "entries": [], "settings": ["calendar": ["a": ["b": ["c": 1]]]]]
    XCTAssertThrowsError(try state.accept(try edit(deep), source: source), "deeper than the plugin state")
    let many: [String: Any] = ["version": 1, "entries": (0..<33).map { ["id": "p\($0)", "enabled": false, "pinned": false] }, "settings": [String: Any]()]
    XCTAssertThrowsError(try state.accept(try edit(many), source: source), "more than 32 entries")
    XCTAssertThrowsError(try state.accept(try edit(["calendar"]), source: source), "the body is an object")
    let other = try reply(load, "action", sequence, extra: ["action": "openSettings", "tool": ["nested": true]])
    XCTAssertThrowsError(try state.accept(other, source: source), "no other key may nest")
    // Accepted at the same sequence after the refusals: none of them advanced the page's sequence.
    guard case .action(.pluginsEdit) = try state.accept(try edit(editBody), source: source) else { return XCTFail() }
  }
}
