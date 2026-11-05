// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanCore
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class HostVerifiedWindowAdapterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func fixture(source: SubscriptionSourceState = .stale) -> DockContent {
        let session = DockQuotaWindowInput(id: "session", period: .fiveHour, label: "5h", remainingPercent: nil, resetsAt: nil, durationSeconds: 100)
        let weekly = DockQuotaWindowInput(id: "weekly", period: .week, label: "Weekly", remainingPercent: nil, resetsAt: nil, durationSeconds: 1_000)
        var input = DockInstrumentInput(id: "member", name: "Synthetic", windows: [session, weekly]); input.dataState = .unavailable
        let sub = SettingsSubscription(id: "member", name: .init("Synthetic", "合成"), source: source)
        let row = DockContentRow(input: input, reason: "Some readings are stale", nextStep: "Check Settings")
        return .init(snapshot: .init(inputs: [input], subscriptions: [sub], presentationRows: [input.id: row]))
    }
    private func proof(member: String = "member", window: String = "weekly", until: Date? = nil) -> HostVerifiedWindowFact {
        .init(memberID: member, windowID: window, remainingPercent: 75, resetsAt: now.addingTimeInterval(1_000), issuedAt: now, until: until ?? now.addingTimeInterval(200))
    }
    func testPairedProofRestoresOnlyMatchingWeeklyWhileAggregateStaysStale() throws {
        let deadline: DockContentRecomputeDeadline = .scheduled(now.addingTimeInterval(200), hasUnknownDeadline: false)
        let candidate = try HostVerifiedWindowAdapter.candidate(.init(content: fixture(), deadline: deadline, verifiedWindows: [proof()], evaluatedAt: now, sourceToken: 7), sourceIsCurrent: { $0 == 7 })
        XCTAssertEqual(candidate.sourceToken, 7); XCTAssertEqual(candidate.deadline, deadline)
        XCTAssertEqual(candidate.value.recomputeDeadline, deadline)
        let input = try XCTUnwrap(candidate.value.snapshot.inputs.first)
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertEqual(reading.dataState, .stale); XCTAssertNil(reading.outer?.fraction); XCTAssertEqual(reading.inner?.fraction, 0.75)
        XCTAssertEqual(reading.readout, "75%")
        let card = try DockCardProjection.content(input: input, stateLabel: "Some readings are stale", at: now)
        XCTAssertEqual(card.rows.first { $0.id == "quota:session" }?.value, "--")
        XCTAssertEqual(card.rows.first { $0.id == "quota:weekly" }?.value, "75%")
        XCTAssertEqual(candidate.value.snapshot.presentationRows["member"]?.input.dataState, .stale)
        XCTAssertEqual(candidate.value.snapshot.subscriptions.first?.source, .stale)
        XCTAssertTrue(candidate.value.menuStatusLines?.first?.contains("Some readings are stale") == true)
        XCTAssertNil(try DockInstrumentProjection.evaluate(input, now: now.addingTimeInterval(200)).remainingPercent,
                     "The value remains time-fenced even before a new row is delivered")
    }
    func testAtDeadlineCannotReviveTheWindow() throws {
        XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(fixture(), proofs: [proof(until: now)], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
        let original = fixture(source: .fresh)
        var raw = original.snapshot.inputs[0]; raw.dataState = .fresh
        raw.windows[1].remainingPercent = 75; raw.windows[1].resetsAt = now.addingTimeInterval(1_000)
        let populated = DockContent(snapshot: .init(inputs: [raw], subscriptions: original.snapshot.subscriptions))
        XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(populated, proofs: [proof(until: now)], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
    }
    func testUnmatchedDuplicateAndRevokedProofsFailClosed() {
        for proofs in [[proof(member: "other")], [proof(window: "missing")], [proof(), proof()]] {
            XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(fixture(), proofs: proofs, now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
        }
        for state in [SubscriptionSourceState.denied, .readerDisabled, .unavailable] {
            XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(fixture(source: state), proofs: [proof()], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
        }
    }
    func testGenerationChangeDuringAdaptationRejectsThePair() {
        var calls = 0
        XCTAssertThrowsError(try HostVerifiedWindowAdapter.candidate(.init(content: fixture(), deadline: .some(.none), verifiedWindows: [proof()], evaluatedAt: now, sourceToken: 3), sourceIsCurrent: { _ in
            calls += 1; return calls == 1
        })) { XCTAssertEqual($0 as? HostVerifiedWindowError, .staleSnapshot) }
    }
    func testInvalidOrNonfiniteProofRejected() {
        let invalid = HostVerifiedWindowFact(memberID: "member", windowID: "weekly", remainingPercent: .nan, resetsAt: nil, issuedAt: now, until: now.addingTimeInterval(20))
        XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(fixture(), proofs: [invalid], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
    }
    func testConflictingProjectionAndNonfiniteDeadlineAreRejected() {
        let base = fixture()
        var input = base.snapshot.inputs[0]; input.windows[1].remainingPercent = 80
        let divergent = DockContent(snapshot: .init(inputs: [input], subscriptions: base.snapshot.subscriptions,
            presentationRows: base.snapshot.presentationRows))
        XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(divergent, proofs: [proof()], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
        let bad = HostVerifiedWindowFact(memberID: "member", windowID: "weekly", remainingPercent: 75, resetsAt: nil, issuedAt: now,
                                         until: Date(timeIntervalSinceReferenceDate: .infinity))
        XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(fixture(), proofs: [bad], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
    }

    func testProofBoundaryCanOnlyAdvanceScheduledReevaluation() throws {
        let later = now.addingTimeInterval(1_000), earliest = now.addingTimeInterval(200)
        let candidate = try HostVerifiedWindowAdapter.candidate(.init(content: fixture(), deadline: .scheduled(later, hasUnknownDeadline: true),
            verifiedWindows: [proof()], evaluatedAt: now, sourceToken: 1), sourceIsCurrent: { $0 == 1 })
        XCTAssertEqual(candidate.deadline, .scheduled(earliest, hasUnknownDeadline: true))
        for missing: DockContentRecomputeDeadline? in [nil, .some(.unknown), .some(.none)] {
            XCTAssertThrowsError(try HostVerifiedWindowAdapter.candidate(.init(content: fixture(), deadline: missing,
                verifiedWindows: [proof()], evaluatedAt: now, sourceToken: 1), sourceIsCurrent: { $0 == 1 }))
        }
    }

    func testUnprovedFreshRawValuesAndMenuLinesAreWithheld() throws {
        let base = fixture(source: .fresh)
        var input = base.snapshot.inputs[0]; input.dataState = .fresh
        input.windows[0].remainingPercent = 30; input.windows[0].resetsAt = now.addingTimeInterval(30)
        input.windows[1].remainingPercent = 75; input.windows[1].resetsAt = now.addingTimeInterval(1_000)
        let row = DockContentRow(input: input, reason: "Synthetic", nextStep: "Check Settings",
                                 resetTimes: ["session": now.addingTimeInterval(30), "weekly": now.addingTimeInterval(1_000)])
        var signal = DockSubscriptionSignal(id: "member"); signal.dataState = .fresh
        let raw = DockContent(snapshot: .init(inputs: [input], subscriptions: base.snapshot.subscriptions, presentationRows: ["member": row]),
                              menuStatusLines: ["Synthetic 75%"], signals: [signal])
        let checked = try HostVerifiedWindowAdapter.apply(raw, proofs: [], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 })
        let result = try XCTUnwrap(checked.snapshot.inputs.first)
        XCTAssertNil(try DockInstrumentProjection.evaluate(result, now: now).remainingPercent)
        XCTAssertEqual(checked.menuStatusLines, ["Synthetic · -- · Reading unavailable"])
        XCTAssertEqual(checked.signals.first?.dataState, .unavailable)
        XCTAssertTrue(try XCTUnwrap(checked.snapshot.presentationRows["member"]).resetTimes.isEmpty)
    }

    // The proof is supplied by the producer; malformed versus genuinely absent reset
    // must be distinguished before the producer issues it. Host never infers that distinction.
    func testProducerVerifiedAbsentResetUsesExplicitUntil() throws {
        let until = now.addingTimeInterval(200)
        let verified = HostVerifiedWindowFact(memberID: "member", windowID: "weekly", remainingPercent: 75,
            resetsAt: nil, issuedAt: now, until: until)
        let candidate = try HostVerifiedWindowAdapter.candidate(.init(content: fixture(),
            deadline: .scheduled(now.addingTimeInterval(500), hasUnknownDeadline: false),
            verifiedWindows: [verified], evaluatedAt: now, sourceToken: 1), sourceIsCurrent: { $0 == 1 })
        XCTAssertEqual(candidate.deadline, .scheduled(until, hasUnknownDeadline: false))
        let input = try XCTUnwrap(candidate.value.snapshot.inputs.first)
        XCTAssertEqual(try DockInstrumentProjection.evaluate(input, now: now).remainingPercent, 75)
        XCTAssertNil(try DockInstrumentProjection.evaluate(input, now: until).remainingPercent)
    }

    func testFutureIssuedAndUnstableMemberAreRejected() {
        let future = HostVerifiedWindowFact(memberID: "member", windowID: "weekly", remainingPercent: 75,
            resetsAt: now.addingTimeInterval(1_000), issuedAt: now.addingTimeInterval(1), until: now.addingTimeInterval(200))
        for invalid in [future] {
            XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(fixture(), proofs: [invalid], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
        }
        let base = fixture()
        let unstable = SettingsSubscription(id: "member", name: .init("Synthetic", "合成"), source: .stale, isUnstable: true)
        let content = DockContent(snapshot: .init(inputs: base.snapshot.inputs, subscriptions: [unstable], presentationRows: base.snapshot.presentationRows))
        XCTAssertThrowsError(try HostVerifiedWindowAdapter.apply(content, proofs: [proof()], now: now, sourceToken: 1, sourceIsCurrent: { $0 == 1 }))
    }

    func testAdmittedStaleReserveSurvivesButRevokedReserveIsScrubbed() throws {
        let base = fixture()
        let input = try XCTUnwrap(base.snapshot.inputs.first)
        let reserve = DockCardRow(id: "reserve", kind: .reserve, label: "Reserve", value: "1",
                                  detail: "Last known")
        let row = DockContentRow(input: input, reason: "Last known", nextStep: "Refresh",
                                 additionalRows: [reserve])
        for source: SubscriptionSourceState in [.stale, .denied] {
            let sub = SettingsSubscription(id: input.id, name: .init("Synthetic", "合成"), source: source)
            let content = DockContent(snapshot: .init(inputs: [input], subscriptions: [sub],
                                                       presentationRows: [input.id: row]))
            let result = try HostVerifiedWindowAdapter.apply(content, proofs: [], now: now,
                                                               sourceToken: 1, sourceIsCurrent: { $0 == 1 })
            let rendered = try XCTUnwrap(result.snapshot.presentationRows[input.id])
            XCTAssertEqual(rendered.additionalRows, source == .stale ? [reserve] : [])
            XCTAssertEqual(rendered.input.dataState, source == .stale ? .stale : .unavailable)
        }
    }

    func testCacheWithdrawsBeforeLateTimerOrClockRollbackCanExposeValues() throws {
        let until = now.addingTimeInterval(10)
        let checked = try HostVerifiedWindowAdapter.candidate(.init(content: fixture(),
            deadline: .scheduled(until, hasUnknownDeadline: false),
            verifiedWindows: [proof(until: until)], evaluatedAt: now, sourceToken: 1),
            sourceIsCurrent: { $0 == 1 })
        let cache = HostPairedContentCache(); var withdrawals = 0
        cache.isCurrent = { true }; cache.onStale = { withdrawals += 1 }
        func context(_ date: Date) -> DockContentContext { .init(snapshot: nil, diagnostics: .init(), now: date) }
        cache.install(checked.value, evaluatedAt: now)
        XCTAssertFalse(cache.makeContent(context(now)).snapshot.inputs.isEmpty)
        XCTAssertTrue(cache.makeContent(context(until)).snapshot.inputs.isEmpty)
        XCTAssertEqual(withdrawals, 1)
        cache.install(checked.value, evaluatedAt: now)
        XCTAssertTrue(cache.makeContent(context(now.addingTimeInterval(-1))).snapshot.inputs.isEmpty)
        XCTAssertEqual(withdrawals, 2)
        cache.install(checked.value, evaluatedAt: now)
        cache.isCurrent = { false }
        XCTAssertTrue(cache.makeContent(context(now)).snapshot.inputs.isEmpty)
        XCTAssertEqual(withdrawals, 3)
    }

    func testCacheReturnsOnlyRevalidatedSynchronousReplacement() throws {
        let until = now.addingTimeInterval(10)
        let first = try HostVerifiedWindowAdapter.candidate(.init(content: fixture(),
            deadline: .scheduled(until, hasUnknownDeadline: false), verifiedWindows: [proof(until: until)],
            evaluatedAt: now, sourceToken: 1), sourceIsCurrent: { $0 == 1 })
        let replacement = DockContent(snapshot: fixture().snapshot, menuStatusLines: ["refreshed"],
            recomputeDeadline: .scheduled(until.addingTimeInterval(20), hasUnknownDeadline: false))
        let cache = HostPairedContentCache()
        cache.isCurrent = { true }
        cache.onStale = { cache.install(replacement, evaluatedAt: until) }
        cache.install(first.value, evaluatedAt: now)
        let result = cache.makeContent(.init(snapshot: nil, diagnostics: .init(), now: until))
        XCTAssertEqual(result.menuStatusLines, ["refreshed"])
    }

    func testUnprovedFreshReadingIsUnavailableAndHasLocalizedNextStep() throws {
        let base = fixture(source: .fresh)
        var input = try XCTUnwrap(base.snapshot.inputs.first)
        input.dataState = .fresh; input.windows[0].remainingPercent = 30
        let row = DockContentRow(input: input, reason: "Reading available", nextStep: "No action")
        let content = DockContent(snapshot: .init(inputs: [input], subscriptions: base.snapshot.subscriptions,
                                                  presentationRows: [input.id: row]))
        for (language, reason, step) in [("en", "Reading unavailable", "Check Settings"),
                                         ("zh", "读数不可用", "请检查设置")] {
            let result = try HostVerifiedWindowAdapter.apply(content, proofs: [], now: now,
                sourceToken: 1, language: language, sourceIsCurrent: { $0 == 1 })
            let safe = try XCTUnwrap(result.snapshot.inputs.first)
            XCTAssertEqual(safe.dataState, .unavailable)
            XCTAssertNil(try DockInstrumentProjection.evaluate(safe, now: now).remainingPercent)
            XCTAssertEqual(result.snapshot.presentationRows[input.id]?.reason, reason)
            XCTAssertEqual(result.snapshot.presentationRows[input.id]?.nextStep, step)
        }
    }

}
