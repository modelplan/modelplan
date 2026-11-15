// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire
import XCTest
@testable import ModelPlanCockpitWeb

/// Post-merge sample 11-11 (#847 finding 2): the native scope catalogue follows the page's members, which are the
/// widget's (rows on the Dock surface only). A saved scope for a row kept only for the menu and Settings is no member.
final class CockpitMemberScopeSurfaceTests: XCTestCase {
  func testARowWithoutTheDockSurfaceIsNoScope() throws {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures"))
    var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    var projection = try XCTUnwrap(root["projection"] as? [String: Any])
    var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
    // An unreadable tool: the producer keeps it on the menu and Settings, not on the Dock, with no verified account.
    var hidden = rows[0]
    hidden["id"] = "zai"; hidden["order"] = ((rows[0]["order"] as? Int) ?? 0) + 1; hidden["surfaces"] = ["menu", "settings"]
    var account = try XCTUnwrap((hidden["accounts"] as? [[String: Any]])?.first)
    account.removeValue(forKey: "subscriptionRef")
    hidden["accounts"] = [account]
    rows.append(hidden); projection["rows"] = rows; root["projection"] = projection
    let data = try JSONDecoder().decode(WireCockpitData.self, from: JSONSerialization.data(withJSONObject: root))
    let route = try XCTUnwrap(account["route"] as? String)
    XCTAssertTrue(CockpitMemberScopes.isValidKey("zai#" + route), "the saved key is well formed")
    XCTAssertEqual(CockpitMemberScopes.keys(data), ["all", "0123456789abcdef"], "only the widget's member is a scope")
  }
}
