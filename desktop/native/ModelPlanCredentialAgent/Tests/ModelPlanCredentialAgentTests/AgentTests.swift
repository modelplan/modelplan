// SPDX-License-Identifier: MIT
import XCTest
import Security
import LocalAuthentication
import ModelPlanWire
import ModelPlanEngineClient
@testable import ModelPlanCredentialAgent

private func queryStatus(_ attributes: [String: Any]) -> Int32 {
    if attributes[kSecClass as String] as? String == kSecClassGenericPassword as String,
       attributes[kSecReturnData as String] as? Bool == true,
       attributes[kSecMatchLimit as String] as? String == kSecMatchLimitAll as String { return errSecParam }
    return errSecSuccess
}
private final class FakeMatcher: ItemMatching, @unchecked Sendable {
    var queries: [[String: Any]] = []
    var replies: [ItemMatch]
    init(_ replies: [ItemMatch]) { self.replies = replies }
    func copyMatching(_ attributes: [String: Any]) -> ItemMatch {
        queries.append(attributes)
        let status = queryStatus(attributes)
        guard status == errSecSuccess else { return .init(status: status) }
        guard !replies.isEmpty else { return .init(status: errSecParam) }
        return replies.removeFirst()
    }
}
private final class FakeReader: FixedItemReading, @unchecked Sendable {
    let started = DispatchSemaphore(value: 0), unblock = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var queries: [Bool] = []
    let result: ItemRead
    let blocked: Bool
    init(_ status: Int32 = errSecSuccess, data: Data? = nil, blocked: Bool = false) {
        result = .init(status: status, data: data); self.blocked = blocked
    }
    func waitUntilStarted() { XCTAssertEqual(started.wait(timeout: .now() + 1), .success) }
    var calls: [Bool] { lock.lock(); defer { lock.unlock() }; return queries }
    func read(_ query: FixedItemQuery, authorize: @Sendable () -> ItemReadTermination?) -> ItemRead {
        lock.lock(); queries.append(query.interactive); lock.unlock()
        XCTAssertFalse(Thread.isMainThread)
        started.signal()
        if blocked { _ = unblock.wait(timeout: .now() + 3) }
        return result
    }
}
private final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var valid = true
    func current(_ context: EngineDeliveryContext) -> Bool { lock.lock(); defer { lock.unlock() }; return valid && context.sessionID == "session" }
    func revoke() { lock.lock(); valid = false; lock.unlock() }
}
final class AgentTests: XCTestCase {
    private func operation(interactive: Bool = false, action: Bool = false, seconds: Double = 1) throws -> EngineCredentialOperation {
        .init(request: try .init(operationId: UUID().uuidString, provider: "claude", scope: "claude.account_usage.saved_login", interactive: interactive),
              delivery: .init(sessionID: "session", floor: .init(storeEpoch: "epoch", generation: 1), revision: 1),
              deadline: .now.advanced(by: .seconds(seconds)), userAction: action ? .init(id: UUID()) : nil)
    }
    private let tokenData = Data(#"{"claudeAiOauth":{"accessToken":"U7_FAKE_CANARY","refreshToken":"NEVER_FORWARD"}}"#.utf8)
    func testSystemTokenBackendIsPermanentlyDeniedWithoutAnOSLookup() {
        let result = SecurityItemReader().read(.init(interactive: true), authorize: { nil })
        XCTAssertEqual(result.status, errSecUnimplemented)
        XCTAssertNil(result.data)
    }
    func testActualEnumerationDictionaryIsSupportedByTheFakeOS() {
        XCTAssertEqual(queryStatus(FixedItemQuery(interactive: false).attributes), errSecSuccess)
    }
    func testFixedQueryBackgroundCannotPrompt() {
        let q = FixedItemQuery(interactive: false).attributes
        XCTAssertEqual(q[kSecAttrService as String] as? String, "Claude Code-credentials")
        XCTAssertEqual((q[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed, true)
        XCTAssertEqual(q[kSecMatchLimit as String] as? String, kSecMatchLimitAll as String)
        XCTAssertNil(q[kSecAttrAccount as String])
        XCTAssertNil(q[kSecReturnData as String])
        XCTAssertEqual(q[kSecReturnAttributes as String] as? Bool, true)
        XCTAssertEqual(q[kSecReturnPersistentRef as String] as? Bool, true)
        XCTAssertEqual((FixedItemQuery(interactive: true).attributes[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed, false)
    }
    private var item: [String: Any] { [kSecAttrService as String: "Claude Code-credentials", kSecValuePersistentRef as String: Data([1, 2, 3])] }
    func testTerminalCheckpointBeforeEnumerationMakesNoOSCall() {
        for reason in [ItemReadTermination.canceled, .timeout] {
            let matcher = FakeMatcher([])
            let read = SecurityItemReader(matcher: matcher).read(.init(interactive: true), authorize: { reason })
            XCTAssertEqual(read.termination?.outcome, reason.outcome)
            XCTAssertNil(read.status); XCTAssertNil(read.data); XCTAssertTrue(matcher.queries.isEmpty)
        }
    }
    func testRealReaderEnumeratesThenReadsExactlyOnePersistentReference() {
        let matcher = FakeMatcher([.init(status: errSecSuccess, value: [item]), .init(status: errSecSuccess, value: tokenData as CFData)])
        let read = SecurityItemReader(matcher: matcher).read(.init(interactive: false), authorize: { nil })
        XCTAssertEqual(read.status, errSecSuccess); XCTAssertEqual(read.data, tokenData)
        XCTAssertEqual(matcher.queries.count, 2)
        let second = matcher.queries[1]
        XCTAssertEqual(second[kSecValuePersistentRef as String] as? Data, Data([1, 2, 3]))
        XCTAssertEqual(second[kSecMatchLimit as String] as? String, kSecMatchLimitOne as String)
        XCTAssertEqual(second[kSecReturnData as String] as? Bool, true)
        XCTAssertNil(second[kSecReturnAttributes as String])
        for q in matcher.queries { XCTAssertEqual((q[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed, true) }
    }
    func testRealReaderNotFoundAndEmptyEnumerationNeverReadData() {
        for first in [ItemMatch(status: errSecItemNotFound), .init(status: errSecSuccess, value: [[String: Any]]())] {
            let matcher = FakeMatcher([first]), read = SecurityItemReader(matcher: matcher).read(.init(interactive: false), authorize: { nil })
            XCTAssertEqual(read.status, errSecItemNotFound); XCTAssertNil(read.data); XCTAssertEqual(matcher.queries.count, 1)
        }
    }
    func testRealReaderRejectsAmbiguityWithoutReadingAnyPassword() {
        let matcher = FakeMatcher([.init(status: errSecSuccess, value: [item, item])])
        let read = SecurityItemReader(matcher: matcher).read(.init(interactive: false), authorize: { nil })
        XCTAssertEqual(read.status, errSecDuplicateItem); XCTAssertNil(read.data); XCTAssertEqual(matcher.queries.count, 1)
    }
    func testRealReaderRejectsMalformedOrWrongServiceReference() {
        for value in [[kSecAttrService as String: "other"], [kSecAttrService as String: "Claude Code-credentials"], [kSecAttrService as String: "Claude Code-credentials", kSecValuePersistentRef as String: Data()]] {
            let matcher = FakeMatcher([.init(status: errSecSuccess, value: [value])])
            let read = SecurityItemReader(matcher: matcher).read(.init(interactive: false), authorize: { nil })
            XCTAssertEqual(read.status, errSecDecode); XCTAssertNil(read.data); XCTAssertEqual(matcher.queries.count, 1)
        }
    }
    func testRealReaderItemCanDisappearBetweenEnumerationAndRead() {
        let matcher = FakeMatcher([.init(status: errSecSuccess, value: [item]), .init(status: errSecItemNotFound)])
        let read = SecurityItemReader(matcher: matcher).read(.init(interactive: true), authorize: { nil })
        XCTAssertEqual(read.status, errSecItemNotFound); XCTAssertNil(read.data); XCTAssertEqual(matcher.queries.count, 2)
    }
    func testEverySecurityFailureHasNoToken() async throws {
        for (status, expected) in [(errSecUserCanceled, WireCredentialOutcome.canceled), (errSecAuthFailed, .denied), (errSecItemNotFound, .notFound), (errSecInteractionNotAllowed, .interactionRequired), (errSecDecode, .error)] {
            let reader = FakeReader(status, data: tokenData)
            let result = await NativeCredentialAgent(reader: reader, isCurrent: { _ in true }).handle(try operation())
            XCTAssertEqual(result.outcome, expected); XCTAssertNil(result.accessToken)
        }
    }
    func testSuccessReturnsOnlyAccessTokenThroughGeneratedResult() async throws {
        let reader = FakeReader(data: tokenData)
        let result = await NativeCredentialAgent(reader: reader, isCurrent: { _ in true }).handle(try operation())
        XCTAssertEqual(result.outcome, .ok); XCTAssertEqual(reader.calls, [false])
        XCTAssertEqual(result.accessToken, "U7_FAKE_CANARY")
        let encoded = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        XCTAssertFalse(encoded.contains("NEVER_FORWARD"))
        XCTAssertFalse(String(describing: result).contains("U7_FAKE_CANARY"))
        XCTAssertNil(result.expiresAt)
    }
    func testInteractiveRequiresExplicitAction() async throws {
        let reader = FakeReader(data: tokenData), agent = NativeCredentialAgent(reader: reader, isCurrent: { _ in true })
        let denied = await agent.handle(try operation(interactive: true))
        XCTAssertEqual(denied.outcome, .denied); XCTAssertTrue(reader.calls.isEmpty)
        let allowed = await agent.handle(try operation(interactive: true, action: true))
        XCTAssertEqual(allowed.outcome, .ok); XCTAssertEqual(reader.calls, [true])
    }
    func testExpiredAndStaleRequestsDoNotRead() async throws {
        let reader = FakeReader(data: tokenData)
        let expired = await NativeCredentialAgent(reader: reader, isCurrent: { _ in true }).handle(try operation(seconds: -1))
        let stale = await NativeCredentialAgent(reader: reader, isCurrent: { _ in false }).handle(try operation())
        XCTAssertEqual(expired.outcome, .timeout); XCTAssertEqual(stale.outcome, .error); XCTAssertTrue(reader.calls.isEmpty)
    }
    func testMalformedOrOversizedSuccessIsError() async throws {
        for data in [Data("bad".utf8), Data(#"{"claudeAiOauth":{"refreshToken":"NEVER_FORWARD"}}"#.utf8), Data(repeating: 65, count: 65537)] {
            let result = await NativeCredentialAgent(reader: FakeReader(data: data), isCurrent: { _ in true }).handle(try operation())
            XCTAssertEqual(result.outcome, .error); XCTAssertNil(result.accessToken)
        }
    }
    func testTimeoutRetainsWorkerSlotAndDropsLateToken() async throws {
        let reader = FakeReader(data: tokenData, blocked: true), agent = NativeCredentialAgent(reader: reader, isCurrent: { _ in true })
        let result = await agent.handle(try operation(seconds: 0.05))
        XCTAssertEqual(result.outcome, .timeout); XCTAssertNil(result.accessToken)
        let second = await agent.handle(try operation())
        XCTAssertEqual(second.outcome, .error); XCTAssertEqual(reader.calls.count, 1)
        reader.unblock.signal()
    }
    func testRevokeDuringReadDropsToken() async throws {
        let reader = FakeReader(data: tokenData, blocked: true), gate = Gate()
        let agent = NativeCredentialAgent(reader: reader, isCurrent: { gate.current($0) })
        let op = try operation(), task = Task { await agent.handle(op) }
        await Task.detached { reader.waitUntilStarted() }.value
        gate.revoke(); reader.unblock.signal()
        let result = await task.value
        XCTAssertEqual(result.outcome, .canceled); XCTAssertNil(result.accessToken)
    }
    func testCancellationReturnsBeforeBlockedReadAndRejectsLateToken() async throws {
        let reader = FakeReader(data: tokenData, blocked: true), agent = NativeCredentialAgent(reader: reader, isCurrent: { _ in true })
        let op = try operation(), task = Task { await agent.handle(op) }
        await Task.detached { reader.waitUntilStarted() }.value
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.outcome, .canceled); XCTAssertNil(result.accessToken)
        let second = await agent.handle(try operation())
        XCTAssertEqual(second.outcome, .error)
        reader.unblock.signal()
    }
}
