// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

@MainActor final class NativeAccountProjectionTests: XCTestCase {
    private final class Clock: RefreshTimeSource {
        var wall = try! WireInstant("2026-10-29T00:00:30Z").date
        var elapsed: TimeInterval = 0
    }
    private actor Feed: CLITransport {
        let data: Data
        init(_ data: Data) { self.data = data }
        func execute(_ command: CLICommand) async throws -> CommandResult {
            if command == .desktop { return .init(exitCode: 0, stdout: data) }
            // Public publication is not needed to establish a personal quota reading.
            return .init(exitCode: 1, stdout: Data())
        }
    }
    private func payload(sources: [[String: Any]], via: String? = "native", stale: Bool = false,
                         observed: Bool = true, expiry: String = "2026-10-29T00:10:00Z",
                         reset: String = "2026-10-29T01:00:00Z", source: String = "claude-code") throws -> Data {
        var account: [String: Any] = ["source": source, "stale": stale,
            "windows": [["kind": "weekly", "remainingPercent": 75.0, "resetsAt": reset]]]
        if let via { account["via"] = via }
        if observed { account["observedAt"] = "2026-10-29T00:00:00Z" }
        return try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": "2026-10-29T00:00:00Z", "validUntil": expiry, "accounts": [account], "sources": sources])
    }
    private func project(_ data: Data) throws -> QuotaReading {
        let snapshot = try FeedDecoder.personal(data)
        var ledger = ExpiryLedger()
        return try XCTUnwrap(PersonalProjection.evaluate(snapshot, now: Clock().wall, ledger: &ledger).quotas.first)
    }
    func testActualStorePublishesNativeClaudeReadingWhenStatusLineIsMissing() async throws {
        let data = try payload(sources: [["source": "claude-code", "status": "missing"], ["source": "native:claude", "status": "ok"]])
        let store = SnapshotStore(transport: Feed(data), time: Clock(), automaticTimers: false)
        store.start()
        for _ in 0..<500 where !store.idle { try await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertTrue(store.idle)
        let view = try XCTUnwrap(store.view()), quota = try XCTUnwrap(view.presentation.quotas.first)
        XCTAssertNil(store.diagnostics.personal)
        XCTAssertEqual(quota.remaining, 75)
        XCTAssertNil(quota.reason)
        XCTAssertEqual(quota.observedAt, try WireInstant("2026-10-29T00:00:00Z").date)
        XCTAssertNil(quota.subscription, "A native reading does not invent subscription ownership")
        await store.stopAndWait()
    }
    func testNativeStatusIsIndependentOfStatusLineOrder() throws {
        let entries: [[String: Any]] = [["source": "claude-code", "status": "missing"], ["source": "native:claude", "status": "ok"]]
        for sources in [entries, Array(entries.reversed())] {
            XCTAssertEqual(try project(payload(sources: sources)).remaining, 75)
        }
    }
    func testNativeFailureIsNotRescuedByHealthyStatusLine() throws {
        let quota = try project(payload(sources: [["source": "claude-code", "status": "ok"],
            ["source": "native:claude", "status": "unavailable", "reason": "consent_required"]]))
        XCTAssertNil(quota.remaining); XCTAssertEqual(quota.reason, "stale")
        XCTAssertEqual(quota.historicalRemaining, 75)
    }
    func testStatusLineAndLocalAccountsKeepTheirOwnSourceFailure() throws {
        for via in [nil, "local", "status-line"] {
            let quota = try project(payload(sources: [["source": "claude-code", "status": "missing"],
                ["source": "native:claude", "status": "ok"]], via: via))
            XCTAssertNil(quota.remaining); XCTAssertEqual(quota.reason, "stale")
        }
    }
    func testMissingNativeStatusDoesNotBorrowTheStatusLineFailure() throws {
        let quota = try project(payload(sources: [["source": "claude-code", "status": "missing"]]))
        XCTAssertEqual(quota.remaining, 75)
        XCTAssertNil(quota.reason)
    }
    func testNativeFreshnessDoesNotBypassExistingSafetyGates() throws {
        let sources: [[String: Any]] = [["source": "native:claude", "status": "ok"]]
        let cases: [(Data, String)] = [
            (try payload(sources: sources, stale: true), "stale"),
            (try payload(sources: sources, observed: false), "unknown-observation-time"),
            (try payload(sources: sources, expiry: "2026-10-29T00:00:00Z"), "snapshot-expired"),
            (try payload(sources: sources, reset: "2026-10-29T00:00:00Z"), "reset_passed"),
        ]
        for (data, reason) in cases {
            let quota = try project(data)
            XCTAssertNil(quota.remaining); XCTAssertEqual(quota.reason, reason)
            XCTAssertEqual(quota.historicalRemaining, 75)
        }
    }
    func testAlreadyNamespacedNativeSourcesKeepTheirOwnStatus() throws {
        let quota = try project(payload(sources: [["source": "native:gemini", "status": "unavailable"]], source: "native:gemini"))
        XCTAssertNil(quota.remaining); XCTAssertEqual(quota.reason, "stale")
    }
}
