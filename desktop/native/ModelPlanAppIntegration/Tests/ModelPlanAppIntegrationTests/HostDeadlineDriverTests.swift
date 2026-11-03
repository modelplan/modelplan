// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor private final class HostDeadlineTestScheduler: DockEdgeScheduling {
    private(set) var due: TimeInterval?
    private(set) var saved: [@MainActor () -> Void] = []
    private var action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { due = deadline; self.action = action; saved.append(action) }
    func cancel() { due = nil; action = nil }
    func fire() { let pending = action; action = nil; due = nil; pending?() }
}

@MainActor final class HostDeadlineDriverTests: XCTestCase {
    func testExpiryClearsBeforeRecomputeWithoutNewRows() {
        var wall = Date(timeIntervalSince1970: 1_000), elapsed = 100.0, source: UInt64 = 1
        let expiry = wall.addingTimeInterval(10), scheduler = HostDeadlineTestScheduler()
        var events: [String] = []
        let driver = HostDeadlineDriver<String>(wallNow: { wall }, elapsed: { elapsed }, scheduler: scheduler,
            clear: { events.append("clear") }, recompute: { now in
                events.append("recompute")
                return .init(value: now < expiry ? "synthetic-balance" : "expired", sourceToken: source,
                             deadline: now < expiry ? .some(.scheduled(expiry, hasUnknownDeadline: false)) : .some(.none))
            }, install: { events.append("install:" + $0) }, sourceIsCurrent: { $0 == source })
        driver.invalidate()
        XCTAssertEqual(events, ["clear", "recompute", "install:synthetic-balance"])
        XCTAssertEqual(scheduler.due ?? -1, 110, accuracy: 0.001)
        wall = expiry; elapsed = 110; scheduler.fire()
        XCTAssertEqual(events, ["clear", "recompute", "install:synthetic-balance", "clear", "recompute", "install:expired"])
        XCTAssertEqual(source, 1, "No new source event is needed")
    }
    func testOldCallbackCannotClearReplacementOrReopenAfterWithdrawal() {
        var wall = Date(timeIntervalSince1970: 1_000), elapsed = 100.0, source: UInt64 = 1
        let scheduler = HostDeadlineTestScheduler(); var events: [String] = []
        let driver = HostDeadlineDriver<String>(wallNow: { wall }, elapsed: { elapsed }, scheduler: scheduler,
            clear: { events.append("clear") }, recompute: { now in
                .init(value: "v\(source)", sourceToken: source, deadline: .scheduled(now.addingTimeInterval(10), hasUnknownDeadline: false))
            }, install: { events.append($0) }, sourceIsCurrent: { $0 == source })
        driver.invalidate(); let old = scheduler.saved[0]
        source = 2; wall.addTimeInterval(1); elapsed += 1; driver.invalidate()
        let before = events; old(); XCTAssertEqual(events, before)
        driver.suspend(); let afterWithdrawal = events; scheduler.saved.last?(); XCTAssertEqual(events, afterWithdrawal)
        XCTAssertEqual(driver.status, .suspended)
        driver.close(); driver.invalidate(); XCTAssertEqual(driver.status, .closed)
    }
    func testMissingUnknownAndMixedAreDistinctAndDoNotInstall() {
        let wall = Date(timeIntervalSince1970: 1_000), scheduler = HostDeadlineTestScheduler()
        var deadline: DockContentRecomputeDeadline?, installs = 0
        let driver = HostDeadlineDriver<Int>(wallNow: { wall }, elapsed: { 0 }, scheduler: scheduler,
            clear: {}, recompute: { _ in .init(value: 1, sourceToken: 1, deadline: deadline) },
            install: { _ in installs += 1 }, sourceIsCurrent: { $0 == 1 })
        driver.invalidate(); XCTAssertEqual(driver.status, .missingContract)
        deadline = .unknown; driver.invalidate(); XCTAssertEqual(driver.status, .unknown)
        deadline = .scheduled(wall.addingTimeInterval(10), hasUnknownDeadline: true)
        driver.invalidate(); XCTAssertEqual(driver.status, .mixedUnknown); XCTAssertNotNil(scheduler.due)
        XCTAssertEqual(installs, 0, "No retained/mixed display policy is inferred")
        deadline = .some(.none); driver.invalidate(); XCTAssertEqual(driver.status, .noFutureDeadline); XCTAssertEqual(installs, 1)
    }
    func testReentrantReplacementAndStaleSourceFailClosed() {
        let wall = Date(timeIntervalSince1970: 1_000), scheduler = HostDeadlineTestScheduler()
        var source: UInt64 = 1, installs = 0, clears = 0
        let driver = HostDeadlineDriver<Int>(wallNow: { wall }, elapsed: { 0 }, scheduler: scheduler,
            clear: { clears += 1 }, recompute: { _ in
                let old = source; source += 1
                return .init(value: 1, sourceToken: old, deadline: .some(.none))
            }, install: { _ in installs += 1 }, sourceIsCurrent: { $0 == source })
        driver.invalidate()
        XCTAssertEqual(driver.status, .staleSource); XCTAssertEqual(installs, 0)
        XCTAssertGreaterThanOrEqual(clears, 1)
    }
    func testDeadlineCrossedBetweenProjectionAndArmingNeverInstallsOldValue() {
        let origin = Date(timeIntervalSince1970: 1_000), expiry = origin.addingTimeInterval(1)
        var calls = 0, installs: [String] = []
        let scheduler = HostDeadlineTestScheduler()
        let driver = HostDeadlineDriver<String>(wallNow: { calls += 1; return calls == 1 ? origin : expiry }, elapsed: { 0 }, scheduler: scheduler,
            clear: {}, recompute: { now in .init(value: now < expiry ? "old" : "expired", sourceToken: 1,
                deadline: now < expiry ? .some(.scheduled(expiry, hasUnknownDeadline: false)) : .some(.none)) },
            install: { installs.append($0) }, sourceIsCurrent: { $0 == 1 })
        driver.invalidate()
        XCTAssertEqual(installs, ["expired"])
    }
    func testReentrantSnapshotReplacementCannotPairOldProjectionWithNewDeadline() {
        let wall = Date(timeIntervalSince1970: 1_000), scheduler = HostDeadlineTestScheduler()
        var source: UInt64 = 1, installed: [String] = []
        var driver: HostDeadlineDriver<String>!
        driver = HostDeadlineDriver<String>(wallNow: { wall }, elapsed: { 0 }, scheduler: scheduler,
            clear: {}, recompute: { _ in
                let captured = source
                if captured == 1 { source = 2; driver.invalidate() }
                return .init(value: "projection-\(captured)", sourceToken: captured, deadline: .some(.none))
            }, install: { installed.append($0) }, sourceIsCurrent: { $0 == source })
        driver.invalidate()
        XCTAssertEqual(installed, ["projection-2"], "A nested source replacement must retire the outer projection and deadline together")
    }

    func testProducerSuppliedResetBoundariesRecomputeWithoutNewRows() {
        var wall = Date(timeIntervalSince1970: 1_000), elapsed = 10.0
        let published = wall.addingTimeInterval(5), expires = wall.addingTimeInterval(12)
        let scheduler = HostDeadlineTestScheduler(); var events: [String] = []
        let driver = HostDeadlineDriver<String>(wallNow: { wall }, elapsed: { elapsed }, scheduler: scheduler,
            clear: { events.append("clear") }, recompute: { now in
                events.append("recompute")
                let value = now < published ? "not-yet" : (now < expires ? "announced" : "ended")
                let deadline: DockContentRecomputeDeadline = now < published ? .scheduled(published, hasUnknownDeadline: false) :
                    (now < expires ? .scheduled(expires, hasUnknownDeadline: false) : .none)
                return .init(value: value, sourceToken: 1, deadline: deadline)
            }, install: { events.append($0) }, sourceIsCurrent: { $0 == 1 })
        driver.invalidate(); XCTAssertEqual(events, ["clear", "recompute", "not-yet"])
        wall = published; elapsed = 15; scheduler.fire()
        XCTAssertEqual(Array(events.suffix(3)), ["clear", "recompute", "announced"])
        wall = expires; elapsed = 22; scheduler.fire()
        XCTAssertEqual(Array(events.suffix(3)), ["clear", "recompute", "ended"])
        XCTAssertNil(scheduler.due)
    }

}
