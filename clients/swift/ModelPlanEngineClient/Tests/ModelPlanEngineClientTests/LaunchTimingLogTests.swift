// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanEngineClient

/// WP-17 (G3-123): cold-start stages are monotonic, once per process, and carry no account text.
final class LaunchTimingLogTests: XCTestCase {
    func testStagesCountFromProcessStartOnceEach() {
        var clock = 100.0
        var lines: [String] = []
        let log = LaunchTimingLog(now: { clock }, processStart: { 99.75 }, sink: { lines.append($0) })
        XCTAssertEqual(log.mark("main"), "timing launch stage=main uptimeMs=100000 sinceStartMs=250")
        clock = 100.5
        XCTAssertEqual(log.mark("engine-spawn", detail: "n=1"), "timing launch stage=engine-spawn uptimeMs=100500 sinceStartMs=750 n=1")
        XCTAssertNil(log.mark("main"), "a stage is recorded the first time only")
        clock = 101.0
        XCTAssertEqual(log.mark("first-reading", tool: "Codex"), "timing launch stage=first-reading.codex uptimeMs=101000 sinceStartMs=1250")
        XCTAssertEqual(log.mark("first-reading", tool: "someone@example.com"), "timing launch stage=first-reading.other uptimeMs=101000 sinceStartMs=1250")
        XCTAssertEqual(lines.count, 4)
    }

    func testUnknownOrFutureProcessStartCountsFromFirstStage() {
        var clock = 10.0
        let unknown = LaunchTimingLog(now: { clock }, processStart: { nil }, sink: { _ in })
        XCTAssertEqual(unknown.mark("main"), "timing launch stage=main uptimeMs=10000 sinceStartMs=0")
        clock = 10.2
        XCTAssertEqual(unknown.mark("did-finish-launching"), "timing launch stage=did-finish-launching uptimeMs=10200 sinceStartMs=200")
        let future = LaunchTimingLog(now: { 5 }, processStart: { 6 }, sink: { _ in })
        XCTAssertEqual(future.mark("main"), "timing launch stage=main uptimeMs=5000 sinceStartMs=0")
    }

    func testLinesPassTheDiagnosticsBundleGrammar() {
        let log = LaunchTimingLog(now: { 1 }, processStart: { 0.5 }, sink: { _ in })
        let line = log.mark("bundle-verified", detail: "ms=12 files=1046 bytes=9200000") ?? ""
        // Every token is a known word or a bounded key=value: nothing the bundle filter would turn into `·`.
        let words = line.split(separator: " ").map(String.init).filter { !$0.contains(Character("=")) }
        XCTAssertEqual(words, ["timing", "launch"])
    }
}
