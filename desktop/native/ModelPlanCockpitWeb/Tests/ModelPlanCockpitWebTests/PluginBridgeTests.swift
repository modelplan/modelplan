// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

/// Plugin columns over the bridge (desktop/cockpit/README.md "Plugin columns", src/bridge.ts):
/// host -> page `plugins` and `pluginData`; page -> host actions `pluginsRunning` and `pluginsEdit`.
extension BridgeTests {
  private var pluginsBody: Data {
    Data(#"{"entries":[{"enabled":true,"id":"resources","pinned":false}],"settings":{"resources":{"intervalSeconds":5}},"version":1}"#.utf8)
  }

  func testPluginStateAndReadingsHaveThePageShape() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    XCTAssertThrowsError(try state.pluginData(id: "resources", data: ["samples": []]), "no plugin state sent yet")
    let plugins = try object(state.setPlugins(pluginsBody))
    XCTAssertEqual(plugins["type"] as? String, "plugins")
    let body = try XCTUnwrap(plugins["plugins"] as? [String: Any])
    XCTAssertEqual(Set(body.keys), ["version", "entries", "settings"])
    XCTAssertEqual((body["entries"] as? [[String: Any]])?.first?["id"] as? String, "resources")
    XCTAssertThrowsError(try state.setPlugins(Data(#"{"version":2,"entries":[],"settings":{}}"#.utf8)))
    XCTAssertThrowsError(try state.pluginData(id: "resources", data: ["samples": []]), "hidden page: no readings")
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: false))
    let sample: [String: Any] = ["t": 1_795_000_000_000, "cpuUser": 16.5, "cpuSystem": 5.5, "load": 2.4, "memTotal": 34_359_738_368,
                                 "memApp": 9_663_676_416, "memWired": 4_294_967_296, "memCompressed": 1_073_741_824,
                                 "memCached": 12_884_901_888, "memFree": 6_442_450_944, "swapUsed": 0, "pressure": "normal",
                                 "diskTotal": 530_428_461_056, "diskFree": 128_849_018_880]
    let reading = try object(state.pluginData(id: "resources", data: ["samples": [sample]]))
    XCTAssertEqual(reading["type"] as? String, "pluginData")
    XCTAssertEqual(reading["id"] as? String, "resources")
    let samples = try XCTUnwrap((reading["data"] as? [String: Any])?["samples"] as? [[String: Any]])
    XCTAssertEqual(Set(samples[0].keys), Set(sample.keys))
    XCTAssertEqual(samples[0]["memTotal"] as? Int, 34_359_738_368, "byte counts stay integers")
    XCTAssertThrowsError(try state.pluginData(id: "Bad id", data: [:]))
    _ = load
  }

  func testPluginsRunningIsAcceptedWithoutFocusAndPluginsEditNeedsIt() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    let running = try reply(load, "action", 2, extra: ["action": "pluginsRunning", "ids": ["resources"]])
    XCTAssertThrowsError(try state.accept(running, source: source), "not before the host sent its plugin state")
    _ = try state.setPlugins(pluginsBody)
    // A hidden page reports that it stopped its plugins; that must reach the host or it keeps sampling at 5 s.
    XCTAssertEqual(try state.accept(running, source: source), .action(.pluginsRunning(["resources"])))
    XCTAssertEqual(try state.accept(reply(load, "action", 3, extra: ["action": "pluginsRunning", "ids": [String]()]), source: source),
                   .action(.pluginsRunning([])))
    XCTAssertThrowsError(try state.accept(reply(load, "action", 4, extra: ["action": "pluginsRunning", "ids": ["a", "a"]]), source: source))
    XCTAssertThrowsError(try state.accept(reply(load, "action", 5, extra: ["action": "pluginsRunning", "ids": ["Bad"]]), source: source))
    let edit: [String: Any] = ["version": 1, "entries": [["id": "resources", "enabled": false, "pinned": false]], "settings": [String: Any]()]
    let editRaw = try reply(load, "action", 6, extra: ["action": "pluginsEdit", "plugins": edit])
    XCTAssertThrowsError(try state.accept(editRaw, source: source), "an edit needs the focused page")
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: true))
    let accepted = try state.accept(reply(load, "action", 7, extra: ["action": "pluginsEdit", "plugins": edit]), source: source)
    guard case .action(.pluginsEdit(let data)) = accepted else { return XCTFail("\(accepted)") }
    let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual((parsed["entries"] as? [[String: Any]])?.first?["enabled"] as? Bool, false)
  }
}
