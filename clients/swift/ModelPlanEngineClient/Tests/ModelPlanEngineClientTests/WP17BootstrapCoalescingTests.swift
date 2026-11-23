// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient

/// WP-17 (cold start): `EngineDockMenuComposition.start()` asks for the rows and the consent facts right after
/// `start()`, while the session's own bootstrap has already asked for both. Each duplicate was a second request and a
/// second ordered delivery to wait for. Now a caller with no deadline of its own is answered by the bootstrap request.
extension RealBinaryTests {
    func testWP17StartCallersAreAnsweredByTheBootstrapRequests() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await probe.resumeBootstrapReply(); await client.stop() }
        await probe.suspendNextBootstrapReply()
        _ = try await client.start()
        // The first bootstrap reply is held in the consumer, so neither bootstrap request has completed.
        try await eventually { await probe.bootstrapReplyIsPaused() }
        let sent = await client.requestCounter
        let rows = Task { try await client.subscribeRows(timeout: nil) }
        let consent = Task { try await client.consent(timeout: nil) }
        try await eventually { await client.coalescedRequests == 2 }
        let after = await client.requestCounter
        XCTAssertEqual(after, sent, "no second rows/subscribe or consent/get is sent")
        await probe.resumeBootstrapReply()
        _ = try await rows.value
        _ = try await consent.value
        let rowReplies = await probe.rowCount()
        XCTAssertEqual(rowReplies, 1, "one rows delivery answers both the bootstrap and the caller")
        // A caller with its own deadline still sends its own request.
        _ = try await client.consent(timeout: .seconds(5))
        let later = await client.requestCounter
        XCTAssertEqual(later, sent + 1)
    }

    /// A cancelled caller only detaches: the bootstrap subscription still delivers the rows.
    func testWP17ACancelledCallerLeavesTheBootstrapSubscription() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await probe.resumeBootstrapReply(); await client.stop() }
        await probe.suspendNextBootstrapReply()
        _ = try await client.start()
        try await eventually { await probe.bootstrapReplyIsPaused() }
        let rows = Task { try await client.subscribeRows(timeout: nil) }
        try await eventually { await client.coalescedRequests >= 1 }
        rows.cancel()
        do { _ = try await rows.value; XCTFail("a cancelled caller is told so") } catch {}
        await probe.resumeBootstrapReply()
        try await eventually { await probe.rowCount() == 1 }
    }

    func testBusyCoalescedRowsCallerRetriesOnTheSameSession() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "rows-busy-held"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let context = try await client.start()
        let held = home.appendingPathComponent("rows-busy-held")
        try await eventually { FileManager.default.fileExists(atPath: held.path) }
        let rows = Task { try await client.subscribeRows(timeout: nil) }
        try await eventually { await client.coalescedRequests >= 1 }
        try Data().write(to: home.appendingPathComponent("rows-busy-release"))
        _ = try await rows.value
        try await eventually { await probe.rowCount() > 0 }
        XCTAssertTrue(client.isCurrent(context), "the retry succeeds on the original session")
    }
}
