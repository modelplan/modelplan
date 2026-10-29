// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient

private let credentialScope = "claude.account_usage.saved_login"
private let tokenCanary = "U4B-SYNTHETIC-TOKEN-CANARY"

actor SyntheticAgent: CredentialAgent {
    enum Mode { case success, wrongOperation, blocked, expired, oversized }
    let mode: Mode
    var calls: [EngineCredentialOperation] = []
    var wait: CheckedContinuation<Void, Never>?
    var sawCancellation = false
    init(_ mode: Mode) { self.mode = mode }
    func handle(_ operation: EngineCredentialOperation) async -> WireCredentialResult {
        calls.append(operation)
        if mode == .blocked {
            await withCheckedContinuation { wait = $0 }
            sawCancellation = Task.isCancelled
        }
        return try! WireCredentialResult(operationId: mode == .wrongOperation ? "mismatch" : operation.request.operationId,
            outcome: WireCredentialOutcome(rawValue: "ok"), accessToken: mode == .oversized ? String(repeating: "x", count: 65_537) : tokenCanary,
            expiresAt: mode == .expired ? try! WireTimestamp("2000-01-01T00:00:00Z") : nil)
    }
    func release() { wait?.resume(); wait = nil }
    func count() -> Int { calls.count }
    func latest() -> EngineCredentialOperation? { calls.last }
}

extension RealBinaryTests {
    func credentialHome() throws -> URL {
        let root = try home()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        return root
    }
    func assertNoCanary(_ home: URL, probe: EventProbe) async throws {
        let eventStrings = await probe.events.map { String(describing: $0) }
        XCTAssertFalse(eventStrings.contains { $0.contains(tokenCanary) }, "token reached UI event path")
        let enumeration = FileManager.default.enumerator(at: home, includingPropertiesForKeys: nil)!
        for case let file as URL in enumeration {
            if let data = try? Data(contentsOf: file) {
                XCTAssertFalse(data.range(of: Data(tokenCanary.utf8)) != nil, "token persisted in synthetic home")
            }
        }
    }
    func testRealCredentialBeforeReceiptDoesNotPromptUntilMatch() async throws {
        let binary = try binary(); let home = try credentialHome(); let probe = EventProbe(); let agent = SyntheticAgent(.success)
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "credential-first"), home: home), credentialAgent: agent, consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let action = EngineUserAction(id: UUID())
        let params = try grantParams(initial.floor, allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
        let request = Task { try await client.grant(params, userAction: action) }
        try await eventually { await client.credentialRequests["claude"] != nil }
        try await Task.sleep(for: .milliseconds(100))
        let before = await agent.count(); XCTAssertEqual(before, 0)
        try Data().write(to: home.appendingPathComponent("release-receipt"))
        _ = try await request.value
        try await eventually { await agent.count() == 1 }
        try await eventually { self.traceContains(home, method: "credentials/result") }
        let latestOperation = await agent.latest()
        let operation = try XCTUnwrap(latestOperation)
        let latestGrant = await probe.grants().last
        let grant = try XCTUnwrap(latestGrant)
        XCTAssertEqual(operation.userAction?.id, action.id)
        XCTAssertEqual(operation.delivery.floor, grant.committedAt)
        XCTAssertEqual(operation.request.interactive, true)
        try await assertNoCanary(home, probe: probe)
    }
    func testRealReceiptBeforeCredentialAndWrongAgentResultFailClosed() async throws {
        let binary = try binary(); let home = try credentialHome(); let probe = EventProbe(); let agent = SyntheticAgent(.wrongOperation)
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "receipt-first"), home: home), credentialAgent: agent, consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let params = try grantParams(initial.floor, allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
        _ = try await client.grant(params, userAction: EngineUserAction(id: UUID()))
        let before = await agent.count(); XCTAssertEqual(before, 0)
        try Data().write(to: home.appendingPathComponent("release-credential"))
        try await eventually { self.traceContains(home, method: "credentials/result") }
        let agentCalls = await agent.count(); XCTAssertEqual(agentCalls, 1)
        let trace = try String(contentsOf: home.appendingPathComponent("proxy.trace"), encoding: .utf8)
        XCTAssertFalse(trace.contains("\"tokenInCredentialResult\":true"), "mismatched operation token was forwarded")
        try await assertNoCanary(home, probe: probe)
    }
    func testRealHistoricReceiptIsMetadataAndCannotPrompt() async throws {
        let binary = try binary(); let home = try credentialHome(); let probe = EventProbe(); let agent = SyntheticAgent(.success)
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "historic"), home: home), credentialAgent: agent, consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let params = try grantParams(initial.floor, allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
        _ = try await client.grant(params, userAction: EngineUserAction(id: UUID()))
        let latestReceipt = await probe.grants().last
        let receipt = try XCTUnwrap(latestReceipt)
        XCTAssertTrue(receipt.supersededByLaterConsent)
        XCTAssertEqual(receipt.committedAt?.generation, initial.floor.generation + 1)
        XCTAssertGreaterThan(receipt.delivery.floor.generation, receipt.committedAt!.generation)
        let count = await agent.count(); XCTAssertEqual(count, 0)
        try await assertNoCanary(home, probe: probe)
    }
    func testRealMissingCommitMetadataIsUnknownNotSuccess() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "receipt-malformed"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let params = try grantParams(initial.floor, deny: ["codex.local_history"])
        do { _ = try await client.grant(params); XCTFail("missing commit metadata became successful receipt") }
        catch EngineClientError.mutationOutcomeUnknown(let requestID, _) { XCTAssertEqual(requestID, params.requestId) }
        let grants = await probe.grants(); XCTAssertTrue(grants.isEmpty)
        XCTAssertGreaterThan(try state(home).generation, initial.floor.generation)
    }
    func testRealOldEpochReceiptRequiresReconciliation() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "receipt-old-epoch"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let params = try grantParams(initial.floor, deny: ["codex.local_history"])
        do { _ = try await client.grant(params); XCTFail("old epoch receipt became success") }
        catch EngineClientError.supersededEpoch(let requestID) { XCTAssertEqual(requestID, params.requestId) }
        let real = try state(home)
        try await eventually { await client.hasOpenFloor(real) }
        let grants = await probe.grants(); XCTAssertTrue(grants.isEmpty)
    }
    func testRealConcurrentActionsAndLateWorkerAreBounded() async throws {
        let binary = try binary(); let home = try credentialHome(); let probe = EventProbe(); let agent = SyntheticAgent(.blocked)
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "receipt-first"), home: home), credentialAgent: agent, consumer: probe)
        addTeardownBlock { await agent.release(); await client.stop() }
        let initial = try await client.start()
        let params = try grantParams(initial.floor, allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
        _ = try await client.grant(params, userAction: EngineUserAction(id: UUID()))
        try Data().write(to: home.appendingPathComponent("release-credential"))
        try await eventually { await agent.count() == 1 }
        let next = try grantParams(state(home), allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
        do { _ = try await client.grant(next, userAction: EngineUserAction(id: UUID())); XCTFail("ambiguous concurrent action admitted") }
        catch EngineClientError.localBusy {}
        try externalGrant(binary, home: home, deny: [credentialScope])
        let revoked = try state(home)
        try await eventually { await client.floor == revoked }
        await agent.release()
        try await eventually { await agent.sawCancellation }
        let calls = await agent.count(); XCTAssertEqual(calls, 1)
        let trace = try String(contentsOf: home.appendingPathComponent("proxy.trace"), encoding: .utf8)
        XCTAssertFalse(trace.contains("\"tokenInCredentialResult\":true"), "late revoked token reached writer")
        try await assertNoCanary(home, probe: probe)
    }
}

extension RealBinaryTests {
    func resultCount(_ home: URL) -> Int {
        guard let trace = try? String(contentsOf: home.appendingPathComponent("proxy.trace"), encoding: .utf8) else { return 0 }
        return trace.split(separator: "\n").filter { $0.contains("\"method\":\"credentials/result\"") }.count
    }
    func testRealDuplicateCredentialRequestCannotUseOperationTwice() async throws {
        let binary = try binary(); let home = try credentialHome(); let probe = EventProbe(); let agent = SyntheticAgent(.success)
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "duplicate-credential"), home: home), credentialAgent: agent, consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let params = try grantParams(initial.floor, allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
        _ = try await client.grant(params, userAction: EngineUserAction(id: UUID()))
        try await eventually { self.resultCount(home) > 0 }
        try await Task.sleep(for: .milliseconds(100))
        let count = await agent.count(); XCTAssertEqual(count, 1)
        XCTAssertEqual(resultCount(home), 1, "duplicate operation displaced or repeated the valid result")
        try await assertNoCanary(home, probe: probe)
    }
    func testRealBackgroundAgentHasNoActionAndNoPromptAdmission() async throws {
        let binary = try binary(); let home = try credentialHome(); let probe = EventProbe(); let agent = SyntheticAgent(.success)
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "observe"), home: home), credentialAgent: agent, consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let params = try grantParams(initial.floor, allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
        _ = try await client.grant(params) // no local action; interactive request must fail closed
        try await eventually { self.resultCount(home) == 1 }
        let before = await agent.count(); XCTAssertEqual(before, 0)
        _ = try await client.refresh(try WireRefreshRequestParams(scopes: [credentialScope]))
        try await eventually { await agent.count() == 1 }
        let last = await agent.latest()
        XCTAssertEqual(last?.request.interactive, false)
        XCTAssertNil(last?.userAction)
        try await assertNoCanary(home, probe: probe)
    }
    func testRealMissingAgentSendsTypedNonSuccess() async throws {
        let binary = try binary(); let home = try credentialHome(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "no-agent"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let params = try grantParams(initial.floor, allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
        _ = try await client.grant(params, userAction: EngineUserAction(id: UUID()))
        try await eventually { self.resultCount(home) == 1 }
        let trace = try String(contentsOf: home.appendingPathComponent("proxy.trace"), encoding: .utf8)
        XCTAssertFalse(trace.contains("\"tokenInCredentialResult\":true"))
        try await assertNoCanary(home, probe: probe)
    }
}

extension RealBinaryTests {
    func testRealInvalidAgentTokenBoundsBecomeTypedFailure() async throws {
        for mode in [SyntheticAgent.Mode.expired, .oversized] {
            let binary = try binary(); let home = try credentialHome(); let probe = EventProbe(); let agent = SyntheticAgent(mode)
            try cli(binary, home: home, arguments: ["consent", "init", "--json"])
            let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "observe"), home: home), credentialAgent: agent, consumer: probe)
            addTeardownBlock { await client.stop() }
            let initial = try await client.start()
            let params = try grantParams(initial.floor, allow: [credentialScope], keychain: [credentialScope: WireKeychainChoice(rawValue: "allow")])
            _ = try await client.grant(params, userAction: EngineUserAction(id: UUID()))
            try await eventually { self.resultCount(home) == 1 }
            let trace = try String(contentsOf: home.appendingPathComponent("proxy.trace"), encoding: .utf8)
            XCTAssertFalse(trace.contains("\"tokenInCredentialResult\":true"))
            await client.stop()
        }
    }
}
