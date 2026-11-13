// SPDX-License-Identifier: MIT
import XCTest
import Security
import LocalAuthentication
import ModelPlanWire
import ModelPlanEngineClient
@testable import ModelPlanCredentialAgent

private final class BoundaryMatcher: ItemMatching, @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0), releaseEnumeration = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    func waitForEnumeration() { XCTAssertEqual(entered.wait(timeout: .now() + 2), .success) }
    func copyMatching(_ attributes: [String: Any]) -> ItemMatch {
        XCTAssertEqual((attributes[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed, false)
        lock.lock(); count += 1; let n = count; lock.unlock()
        if n == 1 {
            entered.signal(); _ = releaseEnumeration.wait(timeout: .now() + 3)
            return .init(status: errSecSuccess, value: [[kSecAttrService as String: "Claude Code-credentials", kSecValuePersistentRef as String: Data([1])]])
        }
        XCTAssertEqual(attributes[kSecReturnData as String] as? Bool, true)
        return .init(status: errSecSuccess, value: Data(#"{"claudeAiOauth":{"accessToken":"BOUNDARY_FAKE_CANARY"}}"#.utf8))
    }
}
private final class BoundaryReader: FixedItemReading, @unchecked Sendable {
    let backend: SecurityItemReader
    let finished = DispatchSemaphore(value: 0)
    init(_ matcher: BoundaryMatcher) { backend = .init(matcher: matcher) }
    func read(_ query: FixedItemQuery, authorize: @Sendable () -> ItemReadTermination?) -> ItemRead {
        defer { finished.signal() }
        return backend.read(query, authorize: authorize)
    }
    func waitForFinish() { XCTAssertEqual(finished.wait(timeout: .now() + 2), .success) }
}
private final class BoundaryAuthority: @unchecked Sendable {
    let lock = NSLock()
    private var valid = true
    func current() -> Bool { lock.lock(); defer { lock.unlock() }; return valid }
    func revoke() { lock.lock(); valid = false; lock.unlock() }
}
final class QueryBoundaryTests: XCTestCase {
    private func reproduce(_ stop: String) async throws {
        let matcher = BoundaryMatcher(), authority = BoundaryAuthority(), reader = BoundaryReader(matcher)
        let agent = NativeCredentialAgent(reader: reader, isCurrent: { _ in authority.current() })
        let operation = EngineCredentialOperation(request: try .init(operationId: UUID().uuidString, provider: "claude", scope: "claude.account_usage.saved_login", interactive: true),
            delivery: .init(sessionID: "session", floor: .init(storeEpoch: "epoch", generation: 1), revision: 1),
            deadline: .now.advanced(by: .seconds(stop == "timeout" ? 0.15 : 2)), userAction: .init(id: UUID()))
        let task = Task { await agent.handle(operation) }
        await Task.detached { matcher.waitForEnumeration() }.value
        let result: WireCredentialResult
        if stop == "cancel" {
            task.cancel(); result = await task.value; matcher.releaseEnumeration.signal()
        } else if stop == "timeout" {
            result = await task.value; matcher.releaseEnumeration.signal()
        } else {
            if stop == "revoke" { authority.revoke() }
            matcher.releaseEnumeration.signal(); result = await task.value
        }
        await Task.detached { reader.waitForFinish() }.value
        XCTAssertEqual(matcher.calls, stop == "none" ? 2 : 1, "A terminal operation must never start the second interactive OS query")
        XCTAssertEqual(result.outcome, stop == "none" ? .ok : stop == "timeout" ? .timeout : .canceled)
        if stop != "none" { XCTAssertNil(result.accessToken) }
    }
    func testCancelWhileEnumerationBlockedSuppressesSecretQuery() async throws { try await reproduce("cancel") }
    func testExpiryWhileEnumerationBlockedSuppressesSecretQuery() async throws { try await reproduce("timeout") }
    func testRevokeWhileEnumerationBlockedSuppressesSecretQuery() async throws { try await reproduce("revoke") }
    func testActiveInteractiveOperationStillReadsAfterEnumeration() async throws { try await reproduce("none") }
}
