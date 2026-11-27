// SPDX-License-Identifier: MIT
import XCTest
import Security
import LocalAuthentication
import CryptoKit
import ModelPlanWire
import ModelPlanEngineClient
@testable import ModelPlanCredentialAgent

// D380: ZCode 3.19+ keeps its credential-store key in the Keychain (zai-org/ZCode credential-security):
// service "ZCode Credential Encryption", account hex(sha256(~/.zcode/v2/credentials.json)). Fakes only;
// no test calls SecItemCopyMatching.
private final class ZCodeReader: FixedItemReading, @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [FixedItemQuery] = []
    let result: ItemRead
    init(_ status: Int32 = errSecSuccess, data: Data? = nil) { result = .init(status: status, data: data) }
    var queries: [FixedItemQuery] { lock.lock(); defer { lock.unlock() }; return seen }
    func read(_ query: FixedItemQuery, authorize: @Sendable () -> ItemReadTermination?) -> ItemRead {
        lock.lock(); seen.append(query); lock.unlock()
        return result
    }
}
private final class ZCodeMatcher: ItemMatching, @unchecked Sendable {
    var queries: [[String: Any]] = []
    var replies: [ItemMatch]
    init(_ replies: [ItemMatch]) { self.replies = replies }
    func copyMatching(_ attributes: [String: Any]) -> ItemMatch {
        queries.append(attributes)
        return replies.isEmpty ? .init(status: errSecParam) : replies.removeFirst()
    }
}

final class ZCodeKeychainTests: XCTestCase {
    private let home = "/Users/zcode-test"
    private let key = "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE"  // 43 base64url characters
    private var account: String {
        SHA256.hash(data: Data("/Users/zcode-test/.zcode/v2/credentials.json".utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func operation(provider: String = "zai", scope: String = "zai.account_usage.saved_login",
                           interactive: Bool = false, action: Bool = false) throws -> EngineCredentialOperation {
        .init(request: try .init(operationId: UUID().uuidString, provider: provider, scope: scope, interactive: interactive),
              delivery: .init(sessionID: "session", floor: .init(storeEpoch: "epoch", generation: 1), revision: 1),
              deadline: .now.advanced(by: .seconds(1)), userAction: action ? .init(id: UUID()) : nil)
    }

    func testZCodeQueryNamesOnlyZCodesOwnItemAndBackgroundCannotPrompt() {
        let q = FixedItemQuery(interactive: false, zcodeHome: home).attributes
        XCTAssertEqual(q[kSecAttrService as String] as? String, "ZCode Credential Encryption")
        XCTAssertEqual(q[kSecAttrAccount as String] as? String, account)
        XCTAssertEqual((q[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed, true)
        XCTAssertNil(q[kSecReturnData as String])
        XCTAssertEqual(q[kSecMatchLimit as String] as? String, kSecMatchLimitAll as String)
        XCTAssertEqual((FixedItemQuery(interactive: true, zcodeHome: home).attributes[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed, false)
    }
    func testReaderRefusesAnItemFiledUnderAnotherAccount() {
        let other: [String: Any] = [kSecAttrService as String: "ZCode Credential Encryption", kSecAttrAccount as String: "other", kSecValuePersistentRef as String: Data([1])]
        let matcher = ZCodeMatcher([.init(status: errSecSuccess, value: [other])])
        let read = SecurityItemReader(matcher: matcher).read(.init(interactive: false, zcodeHome: home), authorize: { nil })
        XCTAssertEqual(read.status, errSecDecode); XCTAssertNil(read.data); XCTAssertEqual(matcher.queries.count, 1)
    }
    func testKeyIsReturnedOnlyAfterTheScopeMatches() async throws {
        let reader = ZCodeReader(data: Data(key.utf8))
        let agent = NativeCredentialAgent(reader: reader, isCurrent: { _ in true }, home: home)
        let ok = await agent.handle(try operation())
        XCTAssertEqual(ok.outcome, .ok); XCTAssertEqual(ok.accessToken, key); XCTAssertNil(ok.expiresAt)
        XCTAssertEqual(reader.queries.map(\.item), [.zcode]); XCTAssertEqual(reader.queries.first?.account, account)
        XCTAssertFalse(String(describing: ok).contains(key))
        // A provider paired with another provider's scope names no item and reads nothing.
        for (provider, scope) in [("zai", "claude.account_usage.saved_login"), ("claude", "zai.account_usage.saved_login"), ("zai", "zai.account_usage.api_key")] {
            let refused = await agent.handle(try operation(provider: provider, scope: scope))
            XCTAssertEqual(refused.outcome, .error); XCTAssertNil(refused.accessToken)
        }
        XCTAssertEqual(reader.queries.count, 1)
    }
    func testPromptOnlyFromTheUsersOwnAction() async throws {
        let reader = ZCodeReader(data: Data(key.utf8))
        let agent = NativeCredentialAgent(reader: reader, isCurrent: { _ in true }, home: home)
        let denied = await agent.handle(try operation(interactive: true))
        XCTAssertEqual(denied.outcome, .denied); XCTAssertTrue(reader.queries.isEmpty)
        let allowed = await agent.handle(try operation(interactive: true, action: true))
        XCTAssertEqual(allowed.outcome, .ok); XCTAssertEqual(reader.queries.map(\.interactive), [true])
    }
    func testMalformedItemOrSecurityFailureCarriesNoValue() async throws {
        for data in [Data("short".utf8), Data((key + "=").utf8), Data(String(repeating: "+", count: 43).utf8)] {
            let result = await NativeCredentialAgent(reader: ZCodeReader(data: data), isCurrent: { _ in true }, home: home).handle(try operation())
            XCTAssertEqual(result.outcome, .error); XCTAssertNil(result.accessToken)
        }
        for (status, expected) in [(errSecAuthFailed, WireCredentialOutcome.denied), (errSecUserCanceled, .canceled), (errSecInteractionNotAllowed, .interactionRequired), (errSecItemNotFound, .notFound)] {
            let result = await NativeCredentialAgent(reader: ZCodeReader(status, data: Data(key.utf8)), isCurrent: { _ in true }, home: home).handle(try operation())
            XCTAssertEqual(result.outcome, expected); XCTAssertNil(result.accessToken)
        }
    }
}
