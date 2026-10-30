// SPDX-License-Identifier: MIT
import XCTest
import CryptoKit
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanCredentialAgent

final class HelperProcessTests: XCTestCase {
    private func artifact() throws -> (URL, CredentialHelperPin) {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["U7_TEST_HELPER_BINARY"], "Build the real helper before this suite")
        let url = URL(fileURLWithPath: path), data = try Data(contentsOf: url)
        return (url, .init(sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), bytes: data.count, inputSHA256: String(repeating: "0", count: 64)))
    }
    private func operation(interactive: Bool = false, action: Bool = false, seconds: Double = 2) throws -> EngineCredentialOperation {
        .init(request: try .init(operationId: UUID().uuidString, provider: "claude", scope: "claude.account_usage.saved_login", interactive: interactive),
              delivery: .init(sessionID: "session", floor: .init(storeEpoch: "epoch", generation: 1), revision: 1),
              deadline: .now.advanced(by: .seconds(seconds)), userAction: action ? .init(id: UUID()) : nil)
    }
    func testRealPinnedHelperDeniesBothModesWithoutToken() async throws {
        let (url, pin) = try artifact()
        for interactive in [false, true] {
            let agent = FixedHelperCredentialAgent(executable: url, pin: pin, isCurrent: { _ in true })
            let op = try operation(interactive: interactive, action: interactive)
            let result = await agent.handle(op)
            XCTAssertEqual(result.operationId, op.request.operationId)
            XCTAssertEqual(result.outcome, .denied)
            XCTAssertNil(result.accessToken); XCTAssertNil(result.expiresAt)
        }
    }
    func testWrongPinCannotLaunchAndNeverReturnsMaterial() async throws {
        let (url, pin) = try artifact()
        let wrong = CredentialHelperPin(sha256: String(repeating: "0", count: 64), bytes: pin.bytes, inputSHA256: pin.inputSHA256)
        let result = await FixedHelperCredentialAgent(executable: url, pin: wrong, isCurrent: { _ in true }).handle(try operation())
        XCTAssertEqual(result.outcome, .denied); XCTAssertNil(result.accessToken)
    }
    func testAuthorityAndExpiryVetoBeforeHelperBoundary() async throws {
        let (url, pin) = try artifact()
        let stale = await FixedHelperCredentialAgent(executable: url, pin: pin, isCurrent: { _ in false }).handle(try operation())
        XCTAssertEqual(stale.outcome, .canceled)
        let expired = await FixedHelperCredentialAgent(executable: url, pin: pin, isCurrent: { _ in true }).handle(try operation(seconds: -1))
        XCTAssertEqual(expired.outcome, .timeout)
    }
    func testInteractiveWithoutActionDenies() async throws {
        let (url, pin) = try artifact()
        let result = await FixedHelperCredentialAgent(executable: url, pin: pin, isCurrent: { _ in true }).handle(try operation(interactive: true))
        XCTAssertEqual(result.outcome, .denied)
    }
    func testCancellationIsTerminal() async throws {
        let (url, pin) = try artifact(), op = try operation()
        let task = Task { await FixedHelperCredentialAgent(executable: url, pin: pin, isCurrent: { _ in true }).handle(op) }
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.outcome, .canceled); XCTAssertNil(result.accessToken)
    }
    func testUnboundProductionAuthorityIsClosed() throws {
        XCTAssertFalse(CredentialAgentAuthority().isCurrent(try operation().delivery))
    }
}
