// SPDX-License-Identifier: MIT
import XCTest
import Foundation
import ModelPlanWire
@testable import ModelPlanEngineClient

final class FramingTests: XCTestCase {
    func testIncrementalUTF8AndSeveralLines() throws {
        var reader = LineFramer()
        let bytes = Array("{\"x\":\"界\"}\n{}\n".utf8)
        var frames: [Data] = []
        for byte in bytes { frames += try reader.append(Data([byte])) }
        XCTAssertEqual(frames.map { String(data: $0, encoding: .utf8)! }, ["{\"x\":\"界\"}", "{}"])
        XCTAssertNoThrow(try reader.finish())
    }
    func testFrameCapIncludesTerminatorAndRejectsUnterminatedAtCap() throws {
        var exact = LineFramer()
        let frames = try exact.append(Data(repeating: 0x20, count: 8_388_607) + Data([10]))
        XCTAssertEqual(frames.first?.count, 8_388_607)
        var excessive = LineFramer()
        XCTAssertThrowsError(try excessive.append(Data(repeating: 0x20, count: 8_388_608)))
        XCTAssertLessThanOrEqual(excessive.bufferedBytes, 8_388_608)
    }
    func testPartialEOFAndInvalidUTF8AreProtocolFaults() throws {
        var partial = LineFramer()
        _ = try partial.append(Data("{}".utf8))
        XCTAssertThrowsError(try partial.finish())
        var utf8 = LineFramer()
        XCTAssertThrowsError(try utf8.append(Data([0xff, 10])))
    }
    func testExactIntegerIDAndAmbiguousEnvelopeRejection() throws {
        let bytes = Data("{\"jsonrpc\":\"2.0\",\"id\":18446744073709551615,\"result\":{\"sessionId\":\"s\",\"storeEpoch\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"consentGeneration\":0,\"data\":{}}}".utf8)
        guard case .success(let id, _) = try IncomingFrame(bytes) else { return XCTFail("missing success") }
        XCTAssertEqual(requestKey(id), "n:18446744073709551615")
        XCTAssertNotEqual(requestKey(id), requestKey(.string("18446744073709551615")))
        let ambiguous = Data("{\"jsonrpc\":\"2.0\",\"method\":\"rows/changed\",\"result\":{},\"error\":{}}".utf8)
        XCTAssertThrowsError(try IncomingFrame(ambiguous))
    }
    func testCrashWindowAndBackoff() {
        var budget = RestartBudget()
        for index in 0..<4 { XCTAssertEqual(budget.recordCrash(at: Double(index)), .restart(after: Double(1 << index))) }
        XCTAssertEqual(budget.recordCrash(at: 4), .cooldown(after: RestartBudget.cooldown), "the fifth crash in 600 s cools down")
        var expired = RestartBudget()
        XCTAssertEqual(expired.recordCrash(at: 0), .restart(after: 1))
        XCTAssertEqual(expired.recordCrash(at: 601), .restart(after: 1))
    }
    /// Recovery contract (step 5): a busy initial rows subscription is not given up after four retries.
    func testBusyRowsBootstrapKeepsRetryingWithACappedBackoff() {
        XCTAssertEqual((1...4).map { ProcessEngineClient.rowsBootstrapRetryDelay(attempt: $0) }, Array(repeating: .milliseconds(250), count: 4))
        XCTAssertEqual((5...11).map { ProcessEngineClient.rowsBootstrapRetryDelay(attempt: $0) },
                       [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(16), .seconds(30), .seconds(30)])
        XCTAssertEqual(ProcessEngineClient.rowsBootstrapRetryDelay(attempt: 1_000), .seconds(30))
    }
    /// Recovery contract (step 5): past the crash limit nothing is sticky. Each cooldown ends in one half-open attempt;
    /// a crash of that attempt inside the window cools down again; once the window has passed, backoff starts over.
    func testCrashLimitCoolsDownAndRecoversByItself() {
        var budget = RestartBudget()
        for index in 0..<4 { _ = budget.recordCrash(at: Double(index)) }
        XCTAssertEqual(budget.recordCrash(at: 10), .cooldown(after: 120))
        XCTAssertEqual(budget.recordCrash(at: 131), .cooldown(after: 120), "the half-open attempt crashed inside the window")
        XCTAssertEqual(budget.recordCrash(at: 600), .cooldown(after: 120), "only the crash at 0 has left the window")
        XCTAssertEqual(budget.recordCrash(at: 1_300), .restart(after: 1), "a quiet window: the backoff starts over")
        var capped = RestartBudget()
        for index in 0..<4 { _ = capped.recordCrash(at: Double(index) * 700) }
        XCTAssertEqual(capped.recordCrash(at: 4 * 700), .restart(after: 1))
        XCTAssertLessThanOrEqual(RestartBudget.cap, 30)
    }
}
