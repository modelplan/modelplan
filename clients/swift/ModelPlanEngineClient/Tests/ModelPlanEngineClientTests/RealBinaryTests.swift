// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

enum TestFailure: Error { case timeout, childFailed }

actor EventProbe: EngineClientEventConsumer {
    var events: [EngineClientEvent] = []
    var pauseClear = false
    var clearWaiter: CheckedContinuation<Void, Never>?
    var timeline: [String] = []
    func consume(_ event: EngineClientEvent) async {
        events.append(event)
        let dataRevision: UInt64?
        switch event {
        case .rowsChanged(let value, _): dataRevision = value.delivery.revision
        case .response(_, .rows(let value, _)): dataRevision = value.delivery.revision
        case .response(_, .history(let value)): dataRevision = value.delivery.revision
        default: dataRevision = nil
        }
        if let dataRevision { timeline.append("data:" + String(dataRevision)) }
        if case .clearPrivateViews(let value) = event { timeline.append("clear-start:" + String(value.revision)) }
        if case .clearPrivateViews = event, pauseClear {
            pauseClear = false
            await withCheckedContinuation { clearWaiter = $0 }
        }
        if case .clearPrivateViews(let value) = event { timeline.append("clear-ack:" + String(value.revision)) }
    }
    func suspendNextClear() { pauseClear = true }
    func resumeClear() { clearWaiter?.resume(); clearWaiter = nil }
    func clearIsPaused() -> Bool { clearWaiter != nil }
    func orderedClears() -> Bool {
        for (index, item) in timeline.enumerated() where item.hasPrefix("data:") {
            let revision = item.dropFirst(5)
            guard let clear = timeline.firstIndex(of: "clear-ack:" + revision), clear < index else { return false }
        }
        return true
    }
    func grants() -> [EngineGrantResult] { events.compactMap { if case .response(_, .grant(let value)) = $0 { return value }; return nil } }
    func rowCount() -> Int { events.filter { event in
        if case .rowsChanged = event { return true }
        if case .response(_, .rows) = event { return true }
        return false
    }.count }
    func readyContexts() -> [EngineDeliveryContext] { events.compactMap { if case .connection(.ready(let value)) = $0 { return value }; return nil } }
    func clearCount() -> Int { events.filter { if case .clearPrivateViews = $0 { return true }; return false }.count }
    func consentReplies() -> [WireEnvelope<WireConsentFacts>] { events.compactMap { event in
        if case .response(_, .consent(let reply)) = event { return reply.envelope }
        if case .consentChanged(let reply) = event { return reply.envelope }
        return nil
    } }
    func crashDelays() -> [Double] { events.compactMap { if case .connection(.restarting(_, let delay)) = $0 { return durationSeconds(delay) }; return nil } }
    func stopped(_ reason: EngineStopReason) -> Bool { events.contains { if case .connection(.stopped(let value)) = $0 { return value == reason }; return false } }
}

func eventually(_ check: @escaping @Sendable () async -> Bool, timeout: Double = 5, file: StaticString = #filePath, line: UInt = #line) async throws {
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    while !(await check()) {
        guard ProcessInfo.processInfo.systemUptime < deadline else { XCTFail("timed out waiting for observed protocol state", file: file, line: line); throw TestFailure.timeout }
        try await Task.sleep(for: .milliseconds(10))
    }
}

final class RealBinaryTests: XCTestCase {
    func binary() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_ENGINE_TEST_BINARY"] else {
            throw XCTSkip("Build the real Go CLI and set MODELPLAN_ENGINE_TEST_BINARY")
        }
        return URL(fileURLWithPath: path)
    }
    func home() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("engine-client-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func environment(_ home: URL) -> [String: String] { ["HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"] }
    @discardableResult
    func cli(_ binary: URL, home: URL, arguments: [String], input: Data? = nil) throws -> Data {
        let process = Process(); let output = Pipe(); let errors = Pipe(); let stdin = Pipe()
        process.executableURL = binary; process.arguments = arguments; process.environment = environment(home)
        process.standardOutput = output; process.standardError = errors; process.standardInput = stdin
        try process.run()
        if let input { try stdin.fileHandleForWriting.write(contentsOf: input) }
        try stdin.fileHandleForWriting.close()
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        let errorBytes = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, errorBytes.isEmpty else { throw TestFailure.childFailed }
        return bytes
    }
    func configuration(_ binary: URL, home: URL) -> EngineClientConfiguration {
        EngineClientConfiguration(executableURL: binary, applicationVersion: "synthetic-u4b", allowedEnvironment: environment(home))
    }
    func testRealHandshakeSubscriptionAndStdinClose() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let context = try await client.start()
        XCTAssertFalse(context.sessionID.isEmpty)
        try await eventually { await probe.rowCount() > 0 }
        let before = await probe.rowCount()
        _ = try await client.subscribeRows()
        let after = await probe.rowCount()
        XCTAssertEqual(before, after, "duplicate subscribe sequence must not redeliver a snapshot")
        await client.stop()
        try await eventually { await probe.stopped(.requested) }
        let child = Process(); let input = Pipe(); let output = Pipe(); let errors = Pipe()
        child.executableURL = binary; child.arguments = ["app-server"]; child.environment = environment(home)
        child.standardInput = input; child.standardOutput = output; child.standardError = errors
        try child.run(); try input.fileHandleForWriting.close()
        try await eventually { !child.isRunning }
        XCTAssertEqual(child.terminationStatus, 0)
    }
}


actor CompletionFlag {
    private var finished = false
    func complete() { finished = true }
    func value() -> Bool { finished }
}

extension RealBinaryTests {
    func proxy(_ home: URL, binary: URL, mode: String) throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_ENGINE_TEST_PROXY"] else { throw XCTSkip("Build FrameProxy and set MODELPLAN_ENGINE_TEST_PROXY") }
        let plan = try JSONSerialization.data(withJSONObject: ["binary": binary.path, "mode": mode])
        try plan.write(to: home.appendingPathComponent(".engine-client-proxy.json"))
        return URL(fileURLWithPath: path)
    }
    func state(_ home: URL) throws -> EngineConsentFloor {
        let data = try Data(contentsOf: home.appendingPathComponent(".config/modelplan/consent.json"))
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return EngineConsentFloor(storeEpoch: try XCTUnwrap(value["storeEpoch"] as? String), generation: try XCTUnwrap(value["generation"] as? UInt64))
    }
    func grantParams(_ floor: EngineConsentFloor, allow: [String] = [], deny: [String] = [], keychain: [String: WireKeychainChoice]? = nil, id: String = UUID().uuidString) throws -> WireConsentGrantParams {
        try WireConsentGrantParams(requestId: id, expectStoreEpoch: floor.storeEpoch, expectGeneration: floor.generation, consentTextVersion: 2, allow: allow, deny: deny, keychain: keychain)
    }
    func externalGrant(_ binary: URL, home: URL, deny: [String]) throws {
        let params = try grantParams(state(home), deny: deny)
        try cli(binary, home: home, arguments: ["consent", "grant", "--json"], input: JSONEncoder().encode(params))
    }
    func traceContains(_ home: URL, method: String) -> Bool {
        let data = (try? Data(contentsOf: home.appendingPathComponent("proxy.trace"))) ?? Data()
        return String(decoding: data, as: UTF8.self).contains("\"method\":\"" + method + "\"")
    }
    func testRealExternalEpochResetUsesEqualityAndLowerGeneration() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let file = home.appendingPathComponent(".config/modelplan/consent.json")
        var seed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        seed["storeEpoch"] = String(repeating: "f", count: 32); seed["generation"] = 41
        try JSONSerialization.data(withJSONObject: seed).write(to: file)
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let first = try await client.start()
        try cli(binary, home: home, arguments: ["consent", "reset", "confirmed", "--json"])
        try await eventually { await probe.readyContexts().contains { $0.floor.storeEpoch != first.floor.storeEpoch } }
        let latestContext = await probe.readyContexts().last
        let latest = try XCTUnwrap(latestContext)
        XCTAssertEqual(latest.floor.generation, 1)
        XCTAssertNotEqual(latest.floor.storeEpoch, first.floor.storeEpoch)
        XCTAssertEqual(latest.sessionID, first.sessionID, "epoch confirmation should not need a new child")
        let observed1 = await probe.orderedClears()
        XCTAssertTrue(observed1)
        let observed2 = await client.retiredEpochs.count
        XCTAssertEqual(observed2, 1)
    }
    func testRealWrongSessionAndSequenceAreDiscarded() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "wrong-session-sequence"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let context = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        _ = try await client.diagnostics()
        let observed3 = await probe.rowCount()
        XCTAssertEqual(observed3, 1)
        let observed4 = await client.floor
        XCTAssertEqual(observed4, context.floor)
        let observed5 = await probe.orderedClears()
        XCTAssertTrue(observed5)
    }
    func testRealHigherErrorWaitsForClearAcknowledgment() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "higher-error"), home: home), consumer: probe)
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        _ = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        await probe.suspendNextClear()
        let flag = CompletionFlag()
        let request = Task { () -> Bool in
            do { _ = try await client.diagnostics(); await flag.complete(); return true }
            catch { await flag.complete(); return false }
        }
        try await eventually { await probe.clearIsPaused() }
        try await Task.sleep(for: .milliseconds(100))
        let observed6 = await flag.value()
        XCTAssertFalse(observed6, "higher-context RPC error must not bypass the clear barrier")
        await probe.resumeClear()
        let observed7 = await request.value
        XCTAssertFalse(observed7)
        let observed8 = await probe.orderedClears()
        XCTAssertTrue(observed8)
    }
    func testRealUnconfirmedEpochRemainsCleared() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        var runtime = ClientRuntime(); runtime.requestTimeout = .seconds(2)
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "probe-fails"), home: home), consumer: probe, runtime: runtime)
        addTeardownBlock { await client.stop() }
        let original = try await client.start()
        do { _ = try await client.diagnostics(); XCTFail("unconfirmed epoch was delivered") } catch {}
        try await eventually { await client.confirmationIsPendingOrFailed() }
        let observed9 = await client.floor
        XCTAssertEqual(observed9, original.floor)
        let observed10 = await client.gateClosed
        XCTAssertTrue(observed10)
        do { _ = try await client.subscribeRows(); XCTFail("private request admitted while epoch was uncertain") } catch {}
    }
    func testRealFiveCrashesStopAndUseFreshSessions() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
        let began = ProcessInfo.processInfo.systemUptime
        for index in 0..<5 {
            let ownedPID = await client.processIdentifier
            let pid = try XCTUnwrap(ownedPID)
            XCTAssertEqual(kill(pid, SIGKILL), 0)
            if index < 4 { try await eventually({ await probe.readyContexts().count >= index + 2 }, timeout: Double(1 << index) + 5) }
        }
        try await eventually { await probe.stopped(.crashLimit) }
        let observed11 = await probe.crashDelays()
        XCTAssertEqual(observed11, [1, 2, 4, 8])
        let sessions = await probe.readyContexts().map(\.sessionID)
        XCTAssertEqual(Set(sessions).count, 5)
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - began, 15)
        do { _ = try await client.start(); XCTFail("crash limit was bypassed") } catch {}
    }
    func testRealMismatchDoesNotRestart() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "major-mismatch"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        do { _ = try await client.start(); XCTFail("major mismatch accepted") } catch {}
        try await eventually { await probe.stopped(.protocolMismatch) }
        let observed12 = await probe.crashDelays().isEmpty
        XCTAssertTrue(observed12)
        do { _ = try await client.retry(); XCTFail("major mismatch restarted") } catch {}
    }
}


extension RealBinaryTests {
    func testRealRevokeKeepsDrainingDuringDelayedClear() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        _ = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        let originalCount = await probe.rowCount()
        await probe.suspendNextClear()
        try externalGrant(binary, home: home, deny: ["codex.local_history"])
        try await eventually { await probe.clearIsPaused() }
        let request = Task { () -> Bool in
            do { _ = try await client.diagnostics(); return true } catch { return false }
        }
        try externalGrant(binary, home: home, deny: ["claude.local_history"])
        let latest = try state(home)
        try await eventually { await client.floor == latest }
        let countWhilePaused = await probe.rowCount()
        XCTAssertEqual(countWhilePaused, originalCount)
        await probe.resumeClear()
        _ = await request.value
        try await eventually { await probe.readyContexts().last?.floor == latest }
        try await eventually { await probe.rowCount() > originalCount }
        let ordered = await probe.orderedClears()
        XCTAssertTrue(ordered)
    }
    func testRealRestartTerminatesEveryOldWaiterAndPreservesUncertainty() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "hold"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        let read = Task { () -> EngineClientError? in
            do { _ = try await client.diagnostics(); return nil } catch { return error as? EngineClientError }
        }
        try await eventually { self.traceContains(home, method: "diagnostics/get") }
        let refresh = Task { () -> EngineClientError? in
            do { _ = try await client.refresh(try WireRefreshRequestParams(scopes: [])); return nil } catch { return error as? EngineClientError }
        }
        let params = try grantParams(initial.floor, deny: ["codex.local_history"], id: "uncertain-grant")
        let grant = Task { () -> EngineClientError? in
            do { _ = try await client.grant(params); return nil } catch { return error as? EngineClientError }
        }
        try await eventually { (try? self.state(home).generation) == initial.floor.generation + 1 }
        let ownedPID = await client.processIdentifier
        XCTAssertEqual(kill(try XCTUnwrap(ownedPID), SIGKILL), 0)
        guard case .interrupted(.connectionLost)? = await read.value else { return XCTFail("old read reported success/unknown outcome") }
        guard case .interrupted(.connectionLost)? = await refresh.value else { return XCTFail("old refresh did not terminate on restart") }
        guard case .mutationOutcomeUnknown(let requestID, let expected)? = await grant.value else { return XCTFail("sent grant without receipt reported success") }
        XCTAssertEqual(requestID, params.requestId); XCTAssertEqual(expected, initial.floor)
        let readyBeforeRestart = await probe.readyContexts().count
        XCTAssertEqual(readyBeforeRestart, 1, "old waiters must finish before a new handshake")
        try await eventually { await probe.readyContexts().count == 2 }
        // Explicit identical replay, no automatic mutation replay by the client.
        _ = try await client.grant(params)
        let replay = await probe.grants().last
        XCTAssertEqual(replay?.committedAt?.generation, initial.floor.generation + 1)
    }
    func testRealLateCancelledQueryStillRaisesFloor() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "late-error"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let initial = try await client.start()
        let query = try WireHistoryQueryParams(kind: WireHistoryKind(rawValue: "tokens"), tool: "codex", limit: 10)
        do { _ = try await client.history(query, timeout: .milliseconds(100)); XCTFail("held query succeeded") }
        catch EngineClientError.deadlineExceeded { } catch { XCTFail("wrong terminal disposition") }
        try await eventually { await client.floor?.generation == initial.floor.generation + 1 }
        XCTAssertTrue(traceContains(home, method: "$/cancel"))
        let ordered = await probe.orderedClears(); XCTAssertTrue(ordered)
    }
    func testRealOversizedUnterminatedOutputIsFatalWithoutWaitingForLF() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "oversized"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let began = ProcessInfo.processInfo.systemUptime
        do { _ = try await client.start(); XCTFail("oversized frame was accepted") } catch {}
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - began, 3)
        let rows = await probe.rowCount(); XCTAssertEqual(rows, 0)
    }
    func testRealStalledConsumerIsBoundedAndCannotRestartItself() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        var runtime = ClientRuntime(); runtime.consumerTimeout = .milliseconds(200)
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe, runtime: runtime)
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        _ = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        await probe.suspendNextClear()
        try externalGrant(binary, home: home, deny: ["codex.local_history"])
        try await eventually { await probe.clearIsPaused() }
        try await eventually { await client.consumerHasStopped() }
        let pid = await client.processIdentifier; XCTAssertNil(pid)
        do { _ = try await client.retry(); XCTFail("stalled consumer admitted another session") } catch {}
        await probe.resumeClear()
        try await eventually { await probe.stopped(.consumerUnavailable) }
    }
}


extension RealBinaryTests {
    func testRealQueuedReceiptBecomesHistoricalBeforeDispatch() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        let initial = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        await probe.suspendNextClear()
        let params = try grantParams(initial.floor, deny: ["codex.local_history"])
        let request = Task { try await client.grant(params) }
        try await eventually { await probe.clearIsPaused() }
        try await eventually { await client.hasValidatedReceipt() }
        try externalGrant(binary, home: home, deny: ["claude.local_history"])
        let latest = try state(home)
        try await eventually { await client.floor == latest }
        await probe.resumeClear()
        _ = try await request.value
        let value = await probe.grants().last
        XCTAssertEqual(value?.committedAt?.generation, initial.floor.generation + 1)
        XCTAssertEqual(value?.delivery.floor, latest)
        XCTAssertEqual(value?.supersededByLaterConsent, true)
    }
    func testRealCancelledStartCannotReturnSuccess() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        await probe.suspendNextClear()
        let flag = CompletionFlag()
        let request = Task { () -> Bool in
            do { _ = try await client.start(); await flag.complete(); return true }
            catch { await flag.complete(); return false }
        }
        try await eventually { await probe.clearIsPaused() }
        request.cancel()
        try await Task.sleep(for: .milliseconds(100))
        let completed = await flag.value()
        XCTAssertTrue(completed, "start cancellation must have a terminal outcome without a consumer acknowledgment")
        await probe.resumeClear()
        let succeeded = await request.value
        XCTAssertFalse(succeeded, "cancelled start was reported as success")
    }
}

extension ProcessEngineClient {
    func hasValidatedReceipt() -> Bool { pending.values.contains { $0.receiptKnown } }
}


extension RealBinaryTests {
    func testRealValidatedReceiptDoesNotBecomeUnknownOnRestart() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        let initial = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        await probe.suspendNextClear()
        let params = try grantParams(initial.floor, deny: ["codex.local_history"])
        let request = Task { () -> EngineClientError? in
            do { _ = try await client.grant(params); return nil } catch { return error as? EngineClientError }
        }
        try await eventually { await client.hasValidatedReceipt() }
        let ownedPID = await client.processIdentifier
        XCTAssertEqual(kill(try XCTUnwrap(ownedPID), SIGKILL), 0)
        guard case .receiptDeliveryInterrupted(let id, let committed)? = await request.value else { return XCTFail("validated commit was lost or became successful cancellation") }
        XCTAssertEqual(id, params.requestId)
        XCTAssertEqual(committed.generation, initial.floor.generation + 1)
        await probe.resumeClear()
        try await eventually { await probe.readyContexts().count == 2 }
        try await eventually { await probe.grants().contains { $0.receipt.requestId == params.requestId } }
    }
}

actor ReentrantConsumer: EngineClientEventConsumer {
    var client: ProcessEngineClient?
    var armed = false
    var nestedFailed = false
    func attach(_ client: ProcessEngineClient) { self.client = client; armed = true }
    func consume(_ event: EngineClientEvent) async {
        if case .response(_, .diagnostics) = event, armed, let client {
            armed = false
            do { _ = try await client.consent() } catch { nestedFailed = true }
        }
    }
}

extension RealBinaryTests {
    func testRealReentrantConsumerIsTerminatedWithoutDeadlock() async throws {
        let binary = try binary(); let home = try home(); let consumer = ReentrantConsumer()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        var runtime = ClientRuntime(); runtime.consumerTimeout = .milliseconds(200)
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: consumer, runtime: runtime)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
        await consumer.attach(client)
        do { _ = try await client.diagnostics(); XCTFail("stalled delivery returned success") } catch {}
        try await eventually { await consumer.nestedFailed }
        let pid = await client.processIdentifier; XCTAssertNil(pid)
    }
    func testRealStopDuringBackoffCannotLaunchAnotherChild() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let original = try await client.start()
        let ownedPID = await client.processIdentifier
        XCTAssertEqual(kill(try XCTUnwrap(ownedPID), SIGKILL), 0)
        try await eventually { await client.restartTask != nil }
        await client.stop()
        try await Task.sleep(for: .milliseconds(1200))
        let pid = await client.processIdentifier; XCTAssertNil(pid)
        let contexts = await probe.readyContexts(); XCTAssertEqual(contexts.count, 1)
        let retried = try await client.retry()
        XCTAssertNotEqual(original.sessionID, retried.sessionID)
    }
    func testRealMalformedHistoryPreservesHealthyRows() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(try proxy(home, binary: binary, mode: "history-malformed"), home: home), consumer: probe)
        addTeardownBlock { await client.stop() }
        let original = try await client.start()
        try await eventually { await probe.rowCount() > 0 }
        let before = await probe.rowCount()
        let query = try WireHistoryQueryParams(kind: WireHistoryKind(rawValue: "tokens"), tool: "codex", limit: 10)
        do { _ = try await client.history(query); XCTFail("malformed history became success") }
        catch EngineClientError.featureDecode(.history) {}
        _ = try await client.subscribeRows()
        let context = try await client.start(); XCTAssertEqual(context, original)
        let after = await probe.rowCount(); XCTAssertEqual(after, before)
        do { _ = try await client.pluginInstall(try WirePluginInstallParams(tool: WirePluginTool(rawValue: "codex"))); XCTFail("unvalidated install was executed") } catch {}
        XCTAssertFalse(traceContains(home, method: "plugin/install"))
    }
    func testRealBrokenStdinWriteDoesNotRaiseHostSIGPIPE() async throws {
        let binary = try binary(); let home = try home()
        let process = try EngineProcess(id: UUID(), configuration: configuration(binary, home: home), writeTimeout: 1,
            frame: { _, _ in }, ended: { _, _ in })
        XCTAssertEqual(kill(process.process.processIdentifier, SIGKILL), 0)
        try await eventually { !process.process.isRunning }
        do { try await process.send(Data("{}\n".utf8)); XCTFail("broken pipe accepted a frame") } catch {}
        let reaped = await process.finish(); XCTAssertTrue(reaped)
    }
}
