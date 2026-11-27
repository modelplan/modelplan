// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

/// D474 decision 3 (C13, C45): host -> page `seen {ids:[≤64 member keys]}`, against the shared contract
/// `desktop/tests/shared/seen-subscriptions.json` (the page's bridge tests read the same file).
extension BridgeTests {
  private struct SeenFixture: Decodable {
    struct Message: Decodable {
      let name: String; let ids: [String]?; let count: Int?; let valid: Bool
      enum CodingKeys: String, CodingKey { case name, ids, count, valid }
      init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name); valid = try c.decode(Bool.self, forKey: .valid)
        count = try c.decodeIfPresent(Int.self, forKey: .count)
        ids = try? c.decode([String].self, forKey: .ids) // a non-list or non-string case is not representable here
      }
    }
    let messages: [Message]
  }

  func testSeenMessageFollowsTheSharedContract() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("../../../../tests/shared/seen-subscriptions.json").standardizedFileURL
    let fixture = try JSONDecoder().decode(SeenFixture.self, from: Data(contentsOf: url))
    var checked = 0
    for message in fixture.messages {
      let ids: [String]
      if let count = message.count { ids = (1...count).map { String(format: "%016x", $0) } }
      else if let list = message.ids { ids = list }
      else { continue }
      let state = CockpitBridgeState(context: try context())
      _ = try ready(state)
      if message.valid {
        let sent = try object(state.seen(ids))
        XCTAssertEqual(sent["type"] as? String, "seen", message.name)
        XCTAssertEqual(sent["ids"] as? [String], ids, message.name)
        XCTAssertTrue(state.seenSent)
      } else {
        XCTAssertThrowsError(try state.seen(ids), message.name)
      }
      checked += 1
    }
    XCTAssertGreaterThanOrEqual(checked, 9)
  }

  func testSeenNeedsAReadyPage() throws {
    let state = CockpitBridgeState(context: try context())
    XCTAssertThrowsError(try state.seen([]), "nothing before the page is ready")
    _ = try ready(state)
    XCTAssertFalse(state.seenSent)
    XCTAssertNoThrow(try state.seen([]))
  }
}
