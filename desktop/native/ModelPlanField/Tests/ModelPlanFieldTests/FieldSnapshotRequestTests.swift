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
