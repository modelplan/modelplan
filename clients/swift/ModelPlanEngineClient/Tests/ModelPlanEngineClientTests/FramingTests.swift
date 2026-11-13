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
        for index in 0..<4 { XCTAssertEqual(budget.recordCrash(at: Double(index)), Double(1 << index)) }
        XCTAssertNil(budget.recordCrash(at: 4))
        var expired = RestartBudget()
        XCTAssertNotNil(expired.recordCrash(at: 0))
        XCTAssertEqual(expired.recordCrash(at: 601), 1)
    }
}
