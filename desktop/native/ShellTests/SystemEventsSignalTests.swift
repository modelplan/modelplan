// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
@testable import ModelPlanShell

@MainActor private final class RecordingStore: LifecycleStore {
    var log: [String] = []
    func suspend() { log.append("suspend") }
    func resume() { log.append("resume") }
    func stopAndWait() async {}
    func clockOrTimeZoneChanged() { log.append("clock") }
}

/// Native-shell spec item 2.6: one typed fan-out of the OS edges, gate first, and a trailing 750 ms display settle.
@MainActor final class SystemEventsSignalTests: XCTestCase {
    private final class FakeTimers {
        var now: UInt64 = 0
        var pending: [(id: Int, at: UInt64, fire: @MainActor () -> Void)] = []
        private var next = 0
        @MainActor func schedule(_ delay: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
            next += 1; let id = next
            pending.append((id, now + delay, fire))
            return { [weak self] in self?.pending.removeAll { $0.id == id } }
        }
        @MainActor func advance(to time: UInt64) {
            while let due = pending.filter({ $0.at <= time }).min(by: { $0.at < $1.at }) {
                pending.removeAll { $0.id == due.id }; now = due.at; due.fire()
            }
            now = time
        }
    }
    private struct Fixture {
        let events: SystemEvents, store: RecordingStore, workspace: NotificationCenter, local: NotificationCenter,
            distributed: NotificationCenter, timers: FakeTimers
    }
    private func make() -> Fixture {
        let store = RecordingStore(), timers = FakeTimers()
        let workspace = NotificationCenter(), local = NotificationCenter(), distributed = NotificationCenter()
        let events = SystemEvents(gate: LifecycleCoordinator(store: store), workspace: workspace, local: local, distributed: distributed,
            displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false }, schedule: timers.schedule)
        events.start()
        addTeardownBlock { @MainActor in events.stop() }
        return Fixture(events: events, store: store, workspace: workspace, local: local, distributed: distributed, timers: timers)
    }

    func testEachEdgeIsDeliveredOnceAfterTheGate() {
        let f = make()
        var seen: [SystemSignal] = [], storeAtSignal: [[String]] = []
        let cancel = f.events.subscribe { seen.append($0); storeAtSignal.append(f.store.log) }
        f.workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        f.workspace.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        f.distributed.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        f.local.post(name: .NSSystemClockDidChange, object: nil)
        f.local.post(name: .NSSystemTimeZoneDidChange, object: nil)
        f.workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        f.distributed.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        XCTAssertEqual(seen, [.wake, .screensWake, .unlock, .clockChanged, .timeZoneChanged], "pauses are gate-only; edges once each")
        XCTAssertTrue(storeAtSignal[3].last == "clock", "the gate saw the clock change before the subscriber")
        cancel()
        f.workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertEqual(seen.count, 5, "unsubscribed")
    }

    /// The gate can stay closed for another reason (activity, sleep); the cockpit still gets the raw edge.
    func testWakeReachesSubscribersWhileTheGateStaysClosedForAnotherReason() {
        let f = make()
        var seen: [SystemSignal] = []
        _ = f.events.subscribe { seen.append($0) }
        f.workspace.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        f.workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        f.workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertEqual(seen, [.wake])
    }

    func testDisplaysSettleOnceAfterTheLastChangeOfABurst() {
        let f = make()
        var seen: [SystemSignal] = []
        _ = f.events.subscribe { seen.append($0) }
        for step in 0..<5 {
            f.timers.advance(to: UInt64(step) * 100)
            f.local.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        }
        XCTAssertEqual(seen, Array(repeating: .displaysChanged, count: 5), "every notification at once")
        f.timers.advance(to: 400 + 700)
        f.local.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)  // resets the settle
        f.timers.advance(to: 1_100 + 749)
        XCTAssertFalse(seen.contains(.displaysSettled))
        f.timers.advance(to: 1_100 + 750)
        XCTAssertEqual(seen.filter { $0 == .displaysSettled }.count, 1)
        f.timers.advance(to: 100_000)
        XCTAssertEqual(seen.filter { $0 == .displaysSettled }.count, 1, "single shot")
    }

    func testSubscribersRunInOrderAndStopCancelsThePendingSettle() {
        let f = make()
        var order: [String] = []
        _ = f.events.subscribe { _ in order.append("first") }
        _ = f.events.subscribe { _ in order.append("second") }
        f.local.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(order, ["first", "second"])
        f.events.stop()
        f.timers.advance(to: 10_000)
        XCTAssertEqual(order, ["first", "second"], "no settle after stop, and no subscribers left")
        XCTAssertTrue(f.timers.pending.isEmpty)
    }
}
