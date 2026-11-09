// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient

extension EventProbe {
    func historyImports() -> [WireHistoryImportStatus] { events.compactMap {
        if case .response(_, .historyImport(let reply)) = $0 { return reply.envelope.data }; return nil
    } }
}

/// HIST-IMP-01: the engine's history/import_* methods through the real binary and the real client.
extension RealBinaryTests {
    func testRealHistoryImportStartStatusRemoveKeepsPromptTextOut() async throws {
        let binary = try binary(); let root = try home(); let probe = EventProbe()
        try cli(binary, home: root, arguments: ["consent", "init", "--json"])
        let project = root.appendingPathComponent(".claude/projects/CANARY-PROJECT-DIR")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter.string(from: Date().addingTimeInterval(-48 * 3600), timeZone: TimeZone(identifier: "UTC")!, formatOptions: [.withInternetDateTime, .withFractionalSeconds])
        let reply = ISO8601DateFormatter.string(from: Date().addingTimeInterval(-48 * 3600 + 3), timeZone: TimeZone(identifier: "UTC")!, formatOptions: [.withInternetDateTime, .withFractionalSeconds])
        let lines = [
            #"{"type":"user","message":{"role":"user","content":"CANARY-PROMPT-TEXT"},"timestamp":"\#(stamp)"}"#,
            #"{"type":"assistant","requestId":"CANARY-ID","effort":"high","message":{"model":"fixture-model","content":[{"type":"text","text":"CANARY-REPLY"}],"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":200}},"timestamp":"\#(reply)"}"#,
        ].joined(separator: "\n") + "\n"
        try lines.write(to: project.appendingPathComponent("CANARY-SESSION.jsonl"), atomically: true, encoding: .utf8)
        let grant = try grantParams(state(root), allow: ["claude.local_history"])
        try cli(binary, home: root, arguments: ["consent", "grant", "--json"], input: JSONEncoder().encode(grant))
        let client = ProcessEngineClient(configuration: configuration(binary, home: root), consumer: probe)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
        // Read-only status first: nothing imported, nothing running.
        _ = try await client.historyImportStatus()
        try await eventually { await probe.historyImports().last != nil }
        let idleLast = await probe.historyImports().last
        let idle = try XCTUnwrap(idleLast)
        XCTAssertEqual(idle.phase, .idle); XCTAssertEqual(idle.importedRows, 0); XCTAssertFalse(idle.firstRunDone)

        _ = try await client.historyImportStart(try WireHistoryImportStartParams(days: 30, firstRun: true))
        try await eventually { _ = try? await client.historyImportStatus(); return await probe.historyImports().last?.phase == .done }
        let doneLast = await probe.historyImports().last
        let done = try XCTUnwrap(doneLast)
        XCTAssertEqual(done.sources.first?.source, "claude-code")
        XCTAssertEqual(done.sources.first?.status, .imported)
        XCTAssertEqual(done.sources.first?.turns, 1)
        XCTAssertEqual(done.sources.last?.status, .skippedNoConsent) // codex has no grant: skipped, not asked again
        _ = try await client.historyImportStatus()
        try await eventually { (await probe.historyImports().last?.importedRows ?? 0) > 0 }
        let statusLast = await probe.historyImports().last
        let status = try XCTUnwrap(statusLast)
        XCTAssertTrue(status.firstRunDone); XCTAssertEqual(status.coverage.first?.source, "claude-code")

        let found = try importedLedgerText(root)
        XCTAssertTrue(found.contains(#""origin":"import""#))
        for canary in ["CANARY-PROMPT-TEXT", "CANARY-REPLY", "CANARY-SESSION", "CANARY-PROJECT-DIR", "CANARY-ID"] {
            XCTAssertFalse(found.contains(canary), "imported ledger holds \(canary)")
        }
        _ = try await client.historyImportRemove()
        try await eventually { let last = await probe.historyImports().last; return last?.importedRows == 0 && last?.phase == .idle }
        XCTAssertFalse(try importedLedgerText(root).contains(#""origin":"import""#))
        // Re-arming the first-run import must not happen: the marker survives remove.
        let finalLast = await probe.historyImports().last
        XCTAssertTrue(try XCTUnwrap(finalLast).firstRunDone)
    }

    func importedLedgerText(_ root: URL) throws -> String {
        let all = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        guard let url = all.first(where: { $0.lastPathComponent == "imported.json" }) else { return "" }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
