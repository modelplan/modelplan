import ModelPlanEngineClient
import ModelPlanWire
// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

final class BridgeTests: XCTestCase {
  let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
  func context(_ generation: UInt64 = 1) throws -> CockpitEngineContext {
    try .init(sessionID: UUID(), storeEpoch: "fixture-epoch", generation: generation)
  }
  func object(_ raw: String) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
  }
  func encode(_ object: [String: Any]) throws -> String {
    String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
  }
  func reply(_ outgoing: String, _ type: String, _ sequence: Int, extra: [String: Any] = [:]) throws
    -> String
  {
    var value = try object(outgoing)
    for key in ["data", "appearance", "visible", "occluded", "key"] { value[key] = nil }
    value["type"] = type
    value["sequence"] = String(sequence)
    for (key, item) in extra { value[key] = item }
    return try encode(value)
  }
  func ready(_ state: CockpitBridgeState) throws -> String {
    let load = try state.load(.init(theme: .night, locale: .en, profile: .full))
    XCTAssertEqual(try state.accept(reply(load, "ready", 1), source: source), .ready)
    return load
  }
  func fixture() throws -> WireCockpitData {
    try JSONDecoder().decode(
      WireCockpitData.self,
      from: Data(
        contentsOf: XCTUnwrap(
          Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures")
        )))
  }
  func testLosslessUInt64AndRejectDuplicateNestedAndNoncanonical() throws {
    let state = CockpitBridgeState(context: try context(UInt64.max))
    let load = try state.load(.init(theme: .day, locale: .zhCN, profile: .compact))
    XCTAssertEqual(try object(load)["generation"] as? String, "18446744073709551615")
    var valid = try object(reply(load, "ready", 1))
    for invalid: Any in ["01", "18446744073709551616", 1, "-1"] {
      valid["sequence"] = invalid
      XCTAssertThrowsError(try state.accept(encode(valid), source: source))
    }
    let raw = try reply(load, "ready", 1)
    XCTAssertThrowsError(try state.accept("{\"version\":1," + raw.dropFirst(), source: source))
    XCTAssertThrowsError(try FlatReply.parse("{\"value\":{\"nested\":1}}"))
    XCTAssertEqual(try state.accept(raw, source: source), .ready)
    XCTAssertThrowsError(try state.accept(raw, source: source))
  }
  func testActualSourceAndContextAreRequired() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try state.load(.init(theme: .day, locale: .en, profile: .full))
    let raw = try reply(load, "ready", 1)
    XCTAssertThrowsError(
      try state.accept(raw, source: .init(mainFrame: false, origin: source.origin)))
    XCTAssertThrowsError(
      try state.accept(raw, source: .init(mainFrame: true, origin: "https://example.invalid")))
    for key in ["pageId", "sessionId", "requestId", "storeEpoch", "viewRevision"] {
      var value = try object(raw)
      value[key] = key == "viewRevision" ? "9" : UUID().uuidString
      XCTAssertThrowsError(try state.accept(encode(value), source: source))
    }
    _ = try state.accept(raw, source: source)
  }
  func testClearBarrierUnknownFloorAndStaleQueryCannotBeRetagged() throws {
    let state = CockpitBridgeState(context: try context())
    _ = try ready(state)
    let old = try XCTUnwrap(state.queryTicket)
    let clear = try state.clear()
    XCTAssertNil(state.queryTicket)
    XCTAssertThrowsError(try state.display(fixture(), ticket: old))
    _ = try state.accept(reply(clear, "cleared", 2), source: source)
    XCTAssertNil(
      state.queryTicket, "Unknown authoritative floor stays blocked even after DOM clear")
    let adopt = try state.clear(adopting: state.context)
    _ = try state.accept(reply(adopt, "cleared", 3), source: source)
    XCTAssertNotNil(state.queryTicket)
    XCTAssertThrowsError(try state.display(fixture(), ticket: old))
    XCTAssertNoThrow(try state.display(fixture(), ticket: XCTUnwrap(state.queryTicket)))
  }
  func testRetiredEpochAndSessionCannotReturnAndUnloadIsTerminal() throws {
    let first = try context(20)
    let state = CockpitBridgeState(context: first)
    _ = try ready(state)
    let next = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "new-epoch", generation: 0)
    let clear = try state.clear(adopting: next)
    _ = try state.accept(reply(clear, "cleared", 2), source: source)
    XCTAssertThrowsError(try state.clear(adopting: first))
    XCTAssertNotNil(state.unload())
    XCTAssertNil(state.queryTicket)
    XCTAssertThrowsError(try state.load(.init(theme: .day, locale: .en, profile: .full)))
  }
  func testActionRequiresVisibleAndCurrentRenderedMembership() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    let action = try reply(load, "action", 3, extra: ["action": "openHistory", "tool": "codex"])
    XCTAssertThrowsError(try state.accept(action, source: source))
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: true))
    XCTAssertThrowsError(try state.accept(action, source: source))
    let display = try state.display(fixture(), ticket: XCTUnwrap(state.queryTicket))
    _ = try state.accept(reply(display, "rendered", 2), source: source)
    XCTAssertEqual(try state.accept(action, source: source), .action(.openHistory("codex")))
    XCTAssertThrowsError(try state.accept(action, source: source))
    _ = try state.setVisibility(.init(visible: true, occluded: true, key: true))
    XCTAssertThrowsError(
      try state.accept(reply(load, "action", 4, extra: ["action": "openSettings"]), source: source))
    _ = try state.clear(adopting: state.context)
    XCTAssertNil(state.queryTicket)
  }
  func testLongLivedPageAcceptsMoreThan1024ActionsAndStillRejectsReplays() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: true))
    let display = try state.display(fixture(), ticket: XCTUnwrap(state.queryTicket))
    _ = try state.accept(reply(display, "rendered", 2), source: source)
    var first = ""
    var last = ""
    for index in 0..<2048 {
      let name = ["openSettings", "chooseSetup", "openHistory"][index % 3]
      var extra: [String: Any] = ["requestId": UUID().uuidString, "action": name]
      if name == "openHistory" { extra["tool"] = "codex" }
      let raw = try reply(load, "action", index + 3, extra: extra)
      let expected: CockpitIntent =
        name == "openSettings"
        ? .openSettings : name == "chooseSetup" ? .chooseSetup : .openHistory("codex")
      XCTAssertEqual(try state.accept(raw, source: source), .action(expected))
      if index == 0 { first = raw }
      last = raw
    }
    XCTAssertThrowsError(try state.accept(first, source: source))
    XCTAssertThrowsError(try state.accept(last, source: source))
  }

  @MainActor func testContextMapsActualEngineSessionWithoutInventingOne() throws {
    let id = UUID()
    let delivery = EngineDeliveryContext(
      sessionID: "s-" + id.uuidString.lowercased(), floor: .init(storeEpoch: "e", generation: 4),
      revision: 2)
    XCTAssertEqual(try EngineCockpitCoordinator.bridgeContext(delivery).sessionID, id)
    XCTAssertThrowsError(
      try CockpitEngineContext(sessionID: id, storeEpoch: "legacy", generation: 0))
    XCTAssertThrowsError(
      try EngineCockpitCoordinator.bridgeContext(
        .init(sessionID: "not-a-session", floor: delivery.floor, revision: 2)))
  }
}
