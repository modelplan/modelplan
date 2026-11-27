// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

/// D466 (#1289, cockpit README "news clock"): host -> page `news {items:[{id,status,untilUnixMs}]}` and page -> host
/// action `newsLook {events:[{id,status}]}`.
extension BridgeTests {
  func testNewsEnvelopeCarriesTheClockAnswers() throws {
    let state = CockpitBridgeState(context: try context())
    XCTAssertThrowsError(try state.news([]), "nothing before the page is ready")
    _ = try ready(state)
    XCTAssertFalse(state.newsSent)
    let until = Date(timeIntervalSince1970: 1_795_000_000.5)
    let sent = try object(state.news([
      .init(id: "banked-1", status: .confirmed, until: until),
      .init(id: "limit-2", status: .announced, until: nil)]))
    XCTAssertTrue(state.newsSent)
    XCTAssertEqual(sent["type"] as? String, "news")
    let items = try XCTUnwrap(sent["items"] as? [[String: Any]])
    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(Set(items[0].keys), ["id", "status", "untilUnixMs"])
    XCTAssertEqual(items[0]["id"] as? String, "banked-1")
    XCTAssertEqual(items[0]["status"] as? String, "confirmed")
    XCTAssertEqual(items[0]["untilUnixMs"] as? String, "1795000000500", "a decimal string of whole milliseconds")
    XCTAssertEqual(items[1]["status"] as? String, "announced")
    XCTAssertTrue(items[1]["untilUnixMs"] is NSNull, "null = no longer news")
  }

  func testNewsEnvelopeIsBoundedAtSixtyFourItemsWithValidIDs() throws {
    let state = CockpitBridgeState(context: try context())
    _ = try ready(state)
    let many = (0..<64).map { CockpitNewsItem(id: "e\($0)", status: .announced, until: nil) }
    XCTAssertEqual(try (object(state.news(many))["items"] as? [Any])?.count, 64)
    XCTAssertThrowsError(try state.news(many + [.init(id: "e64", status: .announced, until: nil)]))
    XCTAssertThrowsError(try state.news([.init(id: "", status: .announced, until: nil)]))
    XCTAssertThrowsError(try state.news([.init(id: "bad\u{7}id", status: .announced, until: nil)]))
  }

  func testNewsLookNeedsANegotiatedHostAndAValidShape() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: true))
    let look: [String: Any] = ["action": "newsLook", "events": [["id": "banked-1", "status": "confirmed"]]]
    XCTAssertThrowsError(try state.accept(reply(load, "action", 2, extra: look), source: source), "an older host never sees newsLook")
    _ = try state.news([])
    XCTAssertEqual(try state.accept(reply(load, "action", 3, extra: look), source: source),
                   .action(.newsLook([CockpitNewsLookEvent(id: "banked-1", status: .confirmed)])))
    for bad: [String: Any] in [
      ["action": "newsLook", "events": [[String: Any]]()],
      ["action": "newsLook", "events": [["id": "x", "status": "pending"]]],
      ["action": "newsLook", "events": [["id": "x"]]],
      ["action": "newsLook", "events": [["id": "x", "status": "announced", "extra": 1]]],
      ["action": "newsLook", "events": "x"],
      ["action": "newsLook"]] {
      XCTAssertThrowsError(try state.accept(reply(load, "action", 4, extra: bad), source: source), "\(bad)")
    }
    let sixtyFive = (0..<65).map { ["id": "e\($0)", "status": "announced"] }
    XCTAssertThrowsError(try state.accept(reply(load, "action", 4, extra: ["action": "newsLook", "events": sixtyFive]), source: source))
  }

  /// D466 (#1290): the page sends `nextDeadline` with a fresh request id when the user's own input records a news look.
  /// A host that sent `news` takes it (and moves its timing); any other host still refuses an uncorrelated report.
  func testUnsolicitedDeadlineFromANewsLookIsAccepted() throws {
    let state = CockpitBridgeState(context: try context())
    let load = try ready(state)
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: true))
    func fresh(_ sequence: Int, _ deadline: Any) throws -> String {
      try reply(load, "nextDeadline", sequence, extra: ["requestId": UUID().uuidString, "deadlineUnixMs": deadline])
    }
    XCTAssertThrowsError(try state.accept(fresh(2, "5000"), source: source), "an older host never sees an unsolicited report")
    _ = try state.news([])
    XCTAssertEqual(try state.accept(fresh(3, "5000"), source: source), .unsolicitedDeadline(5000))
    XCTAssertEqual(try state.accept(fresh(4, NSNull()), source: source), .unsolicitedDeadline(nil), "null: nothing pending")
    XCTAssertThrowsError(try state.accept(fresh(4, "6000"), source: source), "a replayed sequence is refused")
    XCTAssertThrowsError(try state.accept(fresh(5, "-1"), source: source), "a malformed deadline is refused")
    XCTAssertThrowsError(try state.accept(fresh(5, "99999999999999999999"), source: source))
    _ = try state.setVisibility(.init(visible: true, occluded: true, key: false))
    XCTAssertThrowsError(try state.accept(fresh(5, "7000"), source: source), "a hidden page reports nothing")
  }

  /// A display receipt's own deadline still goes through the receipt path, not the unsolicited one.
  func testDisplayReceiptDeadlineIsNotTakenAsUnsolicited() throws {
    let state = CockpitBridgeState(context: try context())
    _ = try ready(state)
    _ = try state.setVisibility(.init(visible: true, occluded: false, key: false))
    _ = try state.news([])
    let display = try state.display(fixture(), ticket: XCTUnwrap(state.queryTicket))
    let early = try reply(display, "nextDeadline", 3, extra: ["deadlineUnixMs": "600"])
    guard case .deadlinePending = try state.accept(early, source: source) else { return XCTFail("expected the early-report path") }
  }
}
