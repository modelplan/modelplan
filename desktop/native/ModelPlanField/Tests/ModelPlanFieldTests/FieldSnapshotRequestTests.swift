// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanField

actor DelayedFieldStage<Value: Sendable> {
    let value: Value
    private var result: CheckedContinuation<Value, Never>?
    private var started: [CheckedContinuation<Void, Never>] = []
    private(set) var active = 0
    private(set) var cancelledOnExit = false
    init(value: Value) { self.value = value }
    func run() async -> Value {
        active += 1
        let waiters = started; started.removeAll()
        for waiter in waiters { waiter.resume() }
        let value = await withCheckedContinuation { result = $0 }
        active -= 1; cancelledOnExit = Task.isCancelled
        return value
    }
    func waitForStart() async {
        if active > 0 { return }
        await withCheckedContinuation { started.append($0) }
    }
    func finish() { result?.resume(returning: value); result = nil }
}

final class FieldSnapshotRequestTests: XCTestCase {
    @MainActor func testNativeEncoderCancellationWaitsForActualExitAndCompletesExactlyOnce() async {
        let gate = DelayedFieldStage(value: Data([1, 2, 3]))
        var completions = 0
        let retired = expectation(description: "Owned encoder actually exited")
        let request = FieldSnapshotRequest { data in
            XCTAssertNil(data); completions += 1; retired.fulfill()
        }
        XCTAssertTrue(request.startEncoding({ XCTAssertFalse(Thread.isMainThread); return await gate.run() }) { request.finish($0) })
        await gate.waitForStart()
        request.cancel()
        XCTAssertEqual(completions, 0)
        XCTAssertNotNil(request.encoder)
        XCTAssertFalse(request.startEncoding({ Data([4]) }) { _ in XCTFail("Second encoder admitted") })
        await gate.finish()
        await fulfillment(of: [retired], timeout: 2)
        let wasCancelled = await gate.cancelledOnExit
        XCTAssertTrue(wasCancelled)
        XCTAssertNil(request.encoder)
        request.finish(Data([5]))
        XCTAssertEqual(completions, 1)
    }
}
