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
    for key in ["data", "appearance", "shell", "visible", "occluded", "key", "nowUnixMs", "reason", "theme", "locale", "reduceMotion", "reduceTransparency"] { value[key] = nil }
    if type == "ready" {
      value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
    }
    value["type"] = type
    value["sequence"] = String(sequence)
    for (key, item) in extra { value[key] = item }
    return try encode(value)
  }
  func ready(_ state: CockpitBridgeState) throws -> String {
    let load = try state.load(.init(theme: .night, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
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
    let load = try state.load(.init(theme: .day, locale: .zhCN, profile: .compact), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .compact))
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
    let load = try state.load(.init(theme: .day, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
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
    XCTAssertThrowsError(try state.load(.init(theme: .day, locale: .en, profile: .full), shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall)))
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
  func testMemberScopeSelectRequiresCurrentRenderedMembership() throws {
    let state = CockpitBridgeState(context:try context())
    let load = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let action = try reply(load,"action",3,extra:["action":"scopeSelect","key":"0123456789abcdef"])
    XCTAssertThrowsError(try state.accept(action,source:source))
    let display = try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    _ = try state.accept(reply(display,"rendered",2),source:source)
    XCTAssertNoThrow(try state.accept(action,source:source),"Frozen scopeSelect key must reach native only after its current display is acknowledged")
  }

  func testScopeKeysUseVerifiedReferenceOrExactRowRouteFallback() throws {
    let data=try fixture()
    XCTAssertEqual(CockpitMemberScopes.keys(data),["all","0123456789abcdef"])
    let fallback=try WireCockpitData(projection:data.projection,subscriptions:[])
    XCTAssertEqual(CockpitMemberScopes.keys(fallback),["all","codex#saved_login_api"])
    XCTAssertFalse(CockpitMemberScopes.isValidKey("../unlisted"))
    XCTAssertFalse(CockpitMemberScopes.isValidKey("tool#not_a_route"))
  }
  func testUnverifiedCollisionsReceiveDistinctSessionScopeKeys() throws {
    let url = try XCTUnwrap(Bundle.module.url(forResource:"cockpit",withExtension:"json",subdirectory:"Fixtures"))
    var root = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any])
    var projection = try XCTUnwrap(root["projection"] as? [String:Any])
    var rows = try XCTUnwrap(projection["rows"] as? [[String:Any]])
    var account = try XCTUnwrap((rows[0]["accounts"] as? [[String:Any]])?.first)
    account.removeValue(forKey:"subscriptionRef")
    rows[0]["accounts"] = [account,account]; projection["rows"] = rows
    root["projection"] = projection; root["subscriptions"] = []
    let data = try JSONDecoder().decode(WireCockpitData.self,from:JSONSerialization.data(withJSONObject:root))
    XCTAssertEqual(CockpitMemberScopes.keys(data),["all","codex#saved_login_api#1","codex#saved_login_api#2"])
    for key in ["codex#saved_login_api#0","codex#saved_login_api#01","codex#saved_login_api#-1"] {
      XCTAssertFalse(CockpitMemberScopes.isValidKey(key))
    }
  }
  func testDeadlineReportsRequireRenderedReceiptAndCurrentVisibleContext() throws {
    let state=CockpitBridgeState(context:try context()),load=try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:false))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    let displayID=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(display)["requestId"] as? String)))
    XCTAssertTrue(state.awaitsDeadlineReceipt(displayID),"The acknowledgement wait starts at display registration")
    let report=try reply(display,"nextDeadline",3,extra:["deadlineUnixMs":"1234"])
    let requestID=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(display)["requestId"] as? String)))
    XCTAssertEqual(try state.accept(report,source:source),.deadlinePending(requestID))
    XCTAssertThrowsError(try state.accept(report,source:source),"Only one early report is buffered")
    _ = try state.accept(reply(display,"rendered",2),source:source)
    XCTAssertEqual(state.takeBufferedDeadline()?.value,1234)
    XCTAssertNil(state.takeBufferedDeadline())
    XCTAssertThrowsError(try state.accept(report,source:source),"A deadline receipt is single-use")
    let tick=try state.tick(nowUnixMs:1234,reason:.deadline)
    let clearReport=try reply(tick,"nextDeadline",4,extra:["deadlineUnixMs":NSNull()])
    XCTAssertEqual(try state.accept(clearReport,source:source),.nextDeadline(nil))
    let hiddenTick=try state.tick(nowUnixMs:1234,reason:.clockChange)
    _ = try state.setVisibility(.init(visible:false,occluded:true,key:false))
    XCTAssertThrowsError(try state.accept(reply(hiddenTick,"nextDeadline",5,extra:["deadlineUnixMs":"1235"]),source:source))
    XCTAssertThrowsError(try state.tick(nowUnixMs:1234,reason:.wake))
    _ = load
  }
  func testOlderRenderedReceiptCannotReplaceNewerTickAuthority() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    let tick=try state.tick(nowUnixMs:500,reason:.clockChange)
    _ = try state.accept(reply(display,"rendered",2),source:source)
    XCTAssertThrowsError(try state.accept(reply(display,"nextDeadline",3,extra:["deadlineUnixMs":"600"]),source:source))
    XCTAssertEqual(try state.accept(reply(tick,"nextDeadline",3,extra:["deadlineUnixMs":"700"]),source:source),.nextDeadline(700))
  }
  func testDeadlineRejectsUntrustedSourceAndUncorrelatedRequest() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    _ = try state.accept(reply(display,"rendered",2),source:source)
    let report=try reply(display,"nextDeadline",3,extra:["deadlineUnixMs":"1234"])
    XCTAssertThrowsError(try state.accept(report,source:.init(mainFrame:false,origin:source.origin)))
    XCTAssertThrowsError(try state.accept(report,source:.init(mainFrame:true,origin:"https://example.invalid")))
    var uncorrelated=try object(report);uncorrelated["requestId"]=UUID().uuidString
    XCTAssertThrowsError(try state.accept(encode(uncorrelated),source:source))
    XCTAssertEqual(try state.accept(report,source:source),.nextDeadline(1234))
  }
  func testNewTickSupersedesEarlyDisplayReport() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:false))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    let early=try reply(display,"nextDeadline",3,extra:["deadlineUnixMs":"600"])
    guard case .deadlinePending = try state.accept(early,source:source) else { return XCTFail("Expected bounded pending report") }
    let tick=try state.tick(nowUnixMs:500,reason:.wake)
    _ = try state.accept(reply(display,"rendered",2),source:source)
    XCTAssertNil(state.takeBufferedDeadline(),"A late rendered receipt cannot restore the old deadline")
    XCTAssertThrowsError(try state.accept(early,source:source))
    XCTAssertEqual(try state.accept(reply(tick,"nextDeadline",3,extra:["deadlineUnixMs":NSNull()]),source:source),.nextDeadline(nil))
  }
  func testUnrelatedRenderedReceiptCannotResolveOrReplaceEarlyDeadline() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:false))
    let ticket=try XCTUnwrap(state.queryTicket)
    let old=try state.display(fixture(),ticket:ticket), current=try state.display(fixture(),ticket:ticket)
    let id=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(current)["requestId"] as? String)))
    XCTAssertEqual(try state.accept(reply(current,"nextDeadline",4,extra:["deadlineUnixMs":"750"]),source:source),.deadlinePending(id))
    XCTAssertThrowsError(try state.accept(reply(old,"rendered",2),source:source))
    XCTAssertTrue(state.awaitsDeadlineReceipt(id));XCTAssertNil(state.takeBufferedDeadline())
    _ = try state.accept(reply(current,"rendered",3),source:source)
    XCTAssertFalse(state.awaitsDeadlineReceipt(id));XCTAssertEqual(state.takeBufferedDeadline()?.value,750)
  }
  func testEarlyDeadlineWaitIsBoundedAndInvalidatedOnHide() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:false))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    let requestID=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(display)["requestId"] as? String)))
    let report=try reply(display,"nextDeadline",3,extra:["deadlineUnixMs":NSNull()])
    XCTAssertEqual(try state.accept(report,source:source),.deadlinePending(requestID))
    XCTAssertTrue(state.awaitsDeadlineReceipt(requestID))
    _ = try state.setVisibility(.init(visible:false,occluded:true,key:false))
    XCTAssertFalse(state.awaitsDeadlineReceipt(requestID))
    _ = try state.accept(reply(display,"rendered",2),source:source)
    XCTAssertNil(state.takeBufferedDeadline())
  }
  func testVisibleAppearanceSupersedesDisplayAndBuffersEarlyDeadline() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:false))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    _ = try state.accept(reply(display,"rendered",2),source:source)
    let appearance=try state.setAppearance(.init(theme:.night,locale:.en,profile:.full), deadlineEligible:true)
    let id=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(appearance)["requestId"] as? String)))
    let old=try reply(display,"nextDeadline",3,extra:["deadlineUnixMs":"1000"])
    XCTAssertThrowsError(try state.accept(old,source:source))
    let report=try reply(appearance,"nextDeadline",3,extra:["deadlineUnixMs":"1000"])
    XCTAssertEqual(try state.accept(report,source:source),.deadlinePending(id))
    XCTAssertTrue(state.awaitsDeadlineReceipt(id))
    XCTAssertTrue(state.acknowledgeAppearance(id))
    XCTAssertEqual(state.takeBufferedDeadline()?.value,1000)
    XCTAssertThrowsError(try state.accept(report,source:source))
  }
  @MainActor func testAppearanceAtWindowAndResetDeadlinesSchedulesImmediateTick() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:false))
    var now:UInt64=1_000, callbacks:[@MainActor () -> Void]=[], reasons:[CockpitDeadlineReason]=[]
    let driver=CockpitDeadlineDriver(now:{ now },arm:{ _, fire in callbacks.append(fire);return {} },onExhausted:{ XCTFail("Unexpected deadline convergence failure") },tick:{ reasons.append($0) })
    driver.show()
    for (sequence,deadline) in [(2,UInt64(1_000)),(3,UInt64(2_000))] {
      now=deadline; driver.invalidate()
      let appearance=try state.setAppearance(.init(theme:.night,locale:.en,profile:.full),deadlineEligible:true)
      let id=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(appearance)["requestId"] as? String)))
      XCTAssertTrue(state.acknowledgeAppearance(id))
      guard case .nextDeadline(let value)=try state.accept(reply(appearance,"nextDeadline",sequence,extra:["deadlineUnixMs":String(deadline)]),source:source) else { return XCTFail("Expected correlated report") }
      driver.accept(deadline:value);try XCTUnwrap(callbacks.last)()
    }
    XCTAssertEqual(reasons,[.show,.deadline,.deadline])
  }
  func testAppearanceReportAfterAckAndHideOrGenerationChange() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:false))
    let appearance=try state.setAppearance(.init(theme:.night,locale:.en,profile:.full),deadlineEligible:true)
    let id=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(appearance)["requestId"] as? String)))
    XCTAssertTrue(state.acknowledgeAppearance(id))
    XCTAssertTrue(state.awaitsDeadlineReceipt(id),"An accepted appearance awaits exactly one deadline report")
    XCTAssertEqual(try state.accept(reply(appearance,"nextDeadline",2,extra:["deadlineUnixMs":NSNull()]),source:source),.nextDeadline(nil))
    XCTAssertFalse(state.awaitsDeadlineReceipt(id))
    let newer=try state.setAppearance(.init(theme:.night,locale:.zhCN,profile:.full),deadlineEligible:true)
    let newerID=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(newer)["requestId"] as? String)))
    _ = try state.setVisibility(.init(visible:false,occluded:true,key:false))
    XCTAssertFalse(state.acknowledgeAppearance(newerID))
    XCTAssertThrowsError(try state.accept(reply(newer,"nextDeadline",3,extra:["deadlineUnixMs":"2000"]),source:source))
    let clear=try state.clear(adopting:state.context)
    _ = try state.accept(reply(clear,"cleared",3),source:source)
    XCTAssertThrowsError(try state.accept(reply(newer,"nextDeadline",4,extra:["deadlineUnixMs":"2000"]),source:source))
  }
  func testEarlyAppearanceReportSurvivesLaterValidActionBeforeAck() throws {
    let state=CockpitBridgeState(context:try context()),load=try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    _ = try state.accept(reply(display,"rendered",2),source:source)
    let appearance=try state.setAppearance(.init(theme:.night,locale:.en,profile:.full),deadlineEligible:true)
    let id=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(appearance)["requestId"] as? String)))
    XCTAssertEqual(try state.accept(reply(appearance,"nextDeadline",3,extra:["deadlineUnixMs":"1000"]),source:source),.deadlinePending(id))
    XCTAssertEqual(try state.accept(reply(load,"action",4,extra:["action":"scopeSelect","key":"all"]),source:source),.action(.scopeSelect("all")))
    XCTAssertTrue(state.acknowledgeAppearance(id))
    XCTAssertEqual(state.takeBufferedDeadline()?.value,1000)
  }
  func testSupersededRenderedCannotRestoreOldAccountMembership() throws {
    let state=CockpitBridgeState(context:try context()),load=try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let data=try fixture(), ticket=try XCTUnwrap(state.queryTicket)
    let old=try state.display(data,ticket:ticket)
    let current=try state.display(WireCockpitData(projection:data.projection,subscriptions:[]),ticket:ticket)
    XCTAssertThrowsError(try state.accept(reply(old,"rendered",2),source:source))
    _ = try state.accept(reply(current,"rendered",3),source:source)
    XCTAssertThrowsError(try state.accept(reply(load,"action",4,extra:["action":"scopeSelect","key":"0123456789abcdef"]),source:source))
    XCTAssertEqual(try state.accept(reply(load,"action",4,extra:["action":"scopeSelect","key":"codex#saved_login_api"]),source:source),.action(.scopeSelect("codex#saved_login_api")))
  }
  func testEarlyDisplayDeadlineThenNewerActionStillAdmitsDelayedRendered() throws {
    let state=CockpitBridgeState(context:try context()),load=try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let ticket=try XCTUnwrap(state.queryTicket)
    let previous=try state.display(fixture(),ticket:ticket)
    _ = try state.accept(reply(previous,"rendered",2),source:source)
    let current=try state.display(fixture(),ticket:ticket)
    let requestID=try XCTUnwrap(UUID(uuidString:try XCTUnwrap(try object(current)["requestId"] as? String)))
    XCTAssertEqual(try state.accept(reply(current,"nextDeadline",4,extra:["deadlineUnixMs":"1500"]),source:source),.deadlinePending(requestID))
    XCTAssertEqual(try state.accept(reply(load,"action",5,extra:["action":"scopeSelect","key":"all"]),source:source),.action(.scopeSelect("all")))
    XCTAssertEqual(try state.accept(reply(current,"rendered",3),source:source),.rendered)
    XCTAssertEqual(state.takeBufferedDeadline()?.value,1500)
    XCTAssertThrowsError(try state.accept(reply(current,"rendered",3),source:source))
    let clear=try state.clear(adopting:state.context)
    _ = try state.accept(reply(clear,"cleared",6),source:source)
    XCTAssertThrowsError(try state.accept(reply(current,"rendered",7),source:source),"A previous generation cannot revive")
  }
  func testEarlyReportDoesNotAuthorizePreviousAccountDuringNewDisplay() throws {
    let state=CockpitBridgeState(context:try context()),load=try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let data=try fixture(),ticket=try XCTUnwrap(state.queryTicket)
    let previous=try state.display(data,ticket:ticket)
    _ = try state.accept(reply(previous,"rendered",2),source:source)
    let replacement=try WireCockpitData(projection:data.projection,subscriptions:[])
    let current=try state.display(replacement,ticket:ticket)
    guard case .deadlinePending = try state.accept(reply(current,"nextDeadline",4,extra:["deadlineUnixMs":"1500"]),source:source) else { return XCTFail("Expected early deadline") }
    let stale=try reply(load,"action",5,extra:["action":"scopeSelect","key":"0123456789abcdef"])
    XCTAssertThrowsError(try state.accept(stale,source:source),"Old membership cannot authorize an action for the new display")
    _ = try state.accept(reply(current,"rendered",3),source:source)
    XCTAssertEqual(try state.accept(reply(load,"action",5,extra:["action":"scopeSelect","key":"codex#saved_login_api"]),source:source),.action(.scopeSelect("codex#saved_login_api")))
  }
  func testDeadlineReportRejectsMalformedAndStaleValues() throws {
    let state=CockpitBridgeState(context:try context());_ = try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    _ = try state.accept(reply(display,"rendered",2),source:source)
    for invalid:Any in ["01","-1","8640000000000001",1,true] {
      XCTAssertThrowsError(try state.accept(reply(display,"nextDeadline",3,extra:["deadlineUnixMs":invalid]),source:source))
    }
    let clear=try state.clear(adopting:state.context)
    _ = try state.accept(reply(clear,"cleared",3),source:source)
    XCTAssertThrowsError(try state.accept(reply(display,"nextDeadline",4,extra:["deadlineUnixMs":"1234"]),source:source))
    state.dispose()
  }
  func testScopeRejectsUnknownKeysWrongFieldAndClearedMembership() throws {
    let state=CockpitBridgeState(context:try context()),load=try ready(state)
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    let display=try state.display(fixture(),ticket:XCTUnwrap(state.queryTicket))
    _ = try state.accept(reply(display,"rendered",2),source:source)
    func action(_ key:String,_ sequence:Int=3) throws -> String {
      var body=try object(reply(load,"action",sequence,extra:["action":"scopeSelect","key":key]))
      body["requestId"]=UUID().uuidString; return try encode(body)
    }
    for key in ["unknown","https://example.test/command","codex#manual",""] {
      XCTAssertThrowsError(try state.accept(action(key),source:source))
    }
    var wrong=try object(action("all"));wrong["scope"]=wrong.removeValue(forKey:"key")
    XCTAssertThrowsError(try state.accept(encode(wrong),source:source))
    _ = try state.setVisibility(.init(visible:true,occluded:true,key:true))
    XCTAssertThrowsError(try state.accept(action("all"),source:source))
    _ = try state.setVisibility(.init(visible:true,occluded:false,key:true))
    XCTAssertEqual(try state.accept(action("all"),source:source),.action(.scopeSelect("all")))
    let clear=try state.clear(adopting:state.context)
    _ = try state.accept(reply(clear,"cleared",4),source:source)
    let freshAction=try reply(clear,"action",5,extra:["action":"scopeSelect","key":"0123456789abcdef"])
    XCTAssertThrowsError(try state.accept(freshAction,source:source),"A valid new revision cannot revive retired display membership")
    state.dispose()
    XCTAssertThrowsError(try state.accept(action("all",6),source:source))
  }

}
