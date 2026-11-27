// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

/// Master spec decision 3 / C13 / C45 (D474): a ring and a cockpit column only after the first good reading on this Mac,
/// remembered in `seen-subscriptions.json` (member keys only, 0600) and cleared with Forget / a privacy clear. The
/// column rule is the shared contract `desktop/tests/shared/seen-subscriptions.json` (the page tests the same file).
final class SeenSubscriptionsTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Columns: Decodable { let cases: [Case] }
        struct Case: Decodable { let name: String; let seen: [String]?; let members: [Member]; let shown: [String] }
        struct Member: Decodable { let key: String; let valueState: String }
        let columns: Columns
    }
    private func fixture() throws -> Fixture {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../tests/shared/seen-subscriptions.json").standardizedFileURL
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    func testColumnRuleMatchesTheSharedFixture() throws {
        for c in try fixture().columns.cases {
            let good: (Fixture.Member) -> Bool = { $0.valueState == "current" || $0.valueState == "retained" }
            let shown: [String]
            if let seen = c.seen {
                let set = DockSeenSubscriptions(ids: seen)
                shown = c.members.filter { set.shows($0.key, goodNow: good($0)) }.map(\.key)
            } else {
                shown = c.members.map(\.key) // no store (older host, tests): every member, as before
            }
            XCTAssertEqual(shown, c.shown, c.name)
        }
    }

    func testFirstGoodReadingIsRememberedAcrossARestartWithOwnerOnlyPermissions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("seen-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("seen-subscriptions.json")
        let store = DockSeenSubscriptionsStore(url: url)
        var changes = 0
        store.onChange = { changes += 1 }
        XCTAssertFalse(store.shows("0000000000000001", goodNow: false), "never read: no ring")
        store.record([("0000000000000001", true), ("codex#local_log#2", false)])
        XCTAssertEqual(changes, 1)
        store.record([("0000000000000001", true)])
        XCTAssertEqual(changes, 1, "a known key changes nothing")
        XCTAssertTrue(store.shows("0000000000000001", goodNow: false), "read before, failing now: the ring stays")
        XCTAssertTrue(store.shows("codex#local_log#2", goodNow: false), "a numbered fallback is kept for the session")
        XCTAssertEqual(store.ids, ["0000000000000001", "codex#local_log#2"])

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let saved = try XCTUnwrap(String(data: Data(contentsOf: url), encoding: .utf8))
        XCTAssertTrue(saved.contains("0000000000000001"))
        XCTAssertFalse(saved.contains("codex#local_log#2"), "G3-135: a numbered fallback is never written to disk")

        let reopened = DockSeenSubscriptionsStore(url: url)
        XCTAssertEqual(reopened.ids, ["0000000000000001"])
        XCTAssertTrue(reopened.shows("0000000000000001", goodNow: false))
    }

    func testForgetClearsTheMemory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("seen-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("seen-subscriptions.json")
        let store = DockSeenSubscriptionsStore(url: url)
        store.record([("0000000000000001", true)])
        var changes = 0
        store.onChange = { changes += 1 }
        store.clear()
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(store.ids.isEmpty)
        XCTAssertFalse(store.shows("0000000000000001", goodNow: false), "forgotten and failing: the ring goes")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(DockSeenSubscriptionsStore(url: url).ids.isEmpty)
    }

    func testKeysAreMemberKeysOnlyAndBounded() {
        var set = DockSeenSubscriptions()
        XCTAssertFalse(set.insert("all"), "a scope, never a member")
        XCTAssertFalse(set.insert("alice@example.com"), "never an account name or email")
        XCTAssertFalse(set.insert("codex#local_log#0"))
        XCTAssertTrue(set.insert("codex#local_log"))
        for n in 0..<80 { _ = set.insert(String(format: "%016x", n + 1)) }
        XCTAssertEqual(set.ids.count, DockSeenSubscriptions.maxIDs)
    }
}
