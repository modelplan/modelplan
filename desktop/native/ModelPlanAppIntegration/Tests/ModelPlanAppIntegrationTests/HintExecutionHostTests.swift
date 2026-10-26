// SPDX-License-Identifier: MIT
import Foundation
import XCTest
// Internal construction is confined to negative stale/uncommitted receipt fixtures.
@testable import ModelPlanSettings
import ModelPlanInstruments
@testable import ModelPlanAppIntegration

@MainActor private final class HintClock { var now = 0.0 }
@MainActor private final class HintTestScheduler: HintDeadlineScheduling {
    var deadline: Double?, action: (@MainActor () -> Void)?
    var saved: [@MainActor () -> Void] = []
    func arm(at deadline: Double, _ action: @escaping @MainActor () -> Void) {
        self.deadline = deadline; self.action = action; saved.append(action)
    }
    func cancel() { deadline = nil; action = nil }
    func fire() { let next = action; action = nil; next?() }
}
@MainActor private final class HintTestOverlay: HintOverlayPresenting {
    var kinds: Set<FirstUseHintKind> = [.detach], accepted = true, remainsVisible = true
    var visible: HintOffer?, presented: [HintOffer] = [], hidden: [UUID] = [], updates: [HintPresentation] = []
    var onPlace: (() -> Void)?, onShow: (() -> Void)?, onHide: (() -> Void)?
    func placeableKinds(context: HintContext, trial: InstrumentHintSourceSnapshot?) -> Set<FirstUseHintKind> { onPlace?(); return kinds }
    func showAndVerify(_ offer: HintOffer, trial: InstrumentHintSourceSnapshot?) -> Bool {
        visible = offer; presented.append(offer); onShow?(); return accepted
    }
    func updateAndVerify(_ presentation: HintPresentation) -> Bool { updates.append(presentation); return remainsVisible }
    func hide(offerID: UUID) { hidden.append(offerID); if visible?.id == offerID { visible = nil }; onHide?() }
}
private actor HintGateWriter: HintPreferenceWriting {
    let store: SettingsStore
    let afterCommit: Bool
    var calls = 0, active = 0, maximumActive = 0
    var attemptedRevisions: [UInt64] = []
    private var blocker: CheckedContinuation<Void, Never>?, listeners: [CheckedContinuation<Void, Never>] = []
    private var blocked = false
    init(store: SettingsStore, afterCommit: Bool = false) { self.store = store; self.afterCommit = afterCommit }
    func snapshot() async -> SettingsSnapshot { await store.snapshot() }
    func saveHints(_ preferences: FirstUseHintPreferences, expectedRevision: UInt64) async throws -> SettingsSnapshot {
        attemptedRevisions.append(expectedRevision)
        calls += 1; let first = calls == 1; active += 1; maximumActive = max(maximumActive, active)
        defer { active -= 1 }
        if first && !afterCommit { await pause() }
        let value = try await store.saveHints(preferences, expectedRevision: expectedRevision)
        if first && afterCommit { await pause() }
        return value
    }
    private func pause() async {
        await withCheckedContinuation { continuation in
            blocker = continuation; blocked = true; let ready = listeners; listeners = []; ready.forEach { $0.resume() }
        }
    }
    func waitUntilBlocked() async { if !blocked { await withCheckedContinuation { listeners.append($0) } } }
    func release() { let value = blocker; blocker = nil; value?.resume() }
}

@MainActor final class HintExecutionHostTests: XCTestCase {
    private func store() throws -> SettingsStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("hint-host-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsStore(url: directory.appendingPathComponent("settings.json"))
    }
    private func context(_ id: UUID = UUID()) -> HintContext {
        var value = HintContext(cockpitOpen: id); value.captureReady = true; return value
    }
    private func host(_ writer: any HintPreferenceWriting, _ clock: HintClock, _ timer: HintTestScheduler,
                      _ overlay: HintTestOverlay) async -> HintExecutionHost {
        await HintExecutionHost.restored(persistence: writer, scheduler: timer, overlay: overlay, uptime: { clock.now })
    }
    func testConfirmedVisibleOfferPersistsThroughTheSameStoreAndSpendsOneBudget() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay), ctx = context()
        try host.updateContext(ctx); await host.flushPersistence()
        let saved = await store.snapshot()
        XCTAssertEqual(saved.preferences.helpHints, host.hints.preferences)
        XCTAssertEqual(saved.preferences.helpHints.opens, 1); XCTAssertTrue(saved.preferences.helpHints.seen.contains(.detach))
        XCTAssertTrue(host.hints.cockpitBudgetUsed); XCTAssertEqual(timer.deadline, 5)
        try host.updateContext(ctx); XCTAssertEqual(overlay.presented.count, 1)
    }
    func testUnplaceableAndUnverifiedOfferSpendNoFlagOrBudget() async throws {
        for unplaceable in [true, false] {
            let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
            overlay.kinds = unplaceable ? [] : [.detach]; overlay.accepted = false
            let host = await host(store, clock, timer, overlay)
            try host.updateContext(context()); await host.flushPersistence()
            XCTAssertFalse(host.hints.cockpitBudgetUsed); XCTAssertTrue(host.hints.preferences.seen.isEmpty)
            XCTAssertNil(host.hints.visible); XCTAssertNil(overlay.visible)
        }
    }
    func testRenderReentrantSuspensionDoesNotSpendOrResurrectAnOffer() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay)
        overlay.onShow = { overlay.onShow = nil; host.suspend() }
        try host.updateContext(context()); await host.flushPersistence()
        XCTAssertFalse(host.isRunning); XCTAssertNil(host.hints.visible); XCTAssertNil(overlay.visible)
        XCTAssertTrue(host.hints.preferences.seen.isEmpty); XCTAssertFalse(host.hints.cockpitBudgetUsed)
    }
    func testOldRenderHideCannotDismissAReentrantReplacement() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay)
        overlay.onShow = { overlay.onShow = nil; try! host.updateContext(self.context()) }
        try host.updateContext(context()); await host.flushPersistence()
        XCTAssertEqual(overlay.presented.count, 2); XCTAssertEqual(host.hints.preferences.opens, 2)
        XCTAssertEqual(overlay.visible?.id, host.hints.visible?.offer.id)
        XCTAssertEqual(overlay.visible?.id, overlay.presented.last?.id)
        XCTAssertFalse(overlay.hidden.contains(overlay.presented.last!.id))
    }
    func testRecipeReentrantDisposalWinsBeforeOfferAndLateTimerIsInert() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay)
        overlay.onPlace = { overlay.onPlace = nil; host.dispose() }
        try host.updateContext(context()); await host.flushPersistence()
        try host.resume(context: context()); timer.saved.forEach { $0() }
        XCTAssertTrue(overlay.presented.isEmpty); XCTAssertNil(host.hints.visible); XCTAssertFalse(host.isRunning)
    }
    func testDisposeCannotBeReenteredAsAResumeFromOverlayHide() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay); try host.updateContext(context())
        overlay.onHide = { overlay.onHide = nil; try! host.resume(context: self.context()) }
        host.dispose(); await host.flushPersistence()
        XCTAssertFalse(host.isRunning); XCTAssertNil(host.hints.visible); XCTAssertNil(overlay.visible)
        XCTAssertEqual(overlay.presented.count, 1)
    }
    func testOneHalfSecondDwellAndFiveSecondLifetimeWithStaleTimerGuard() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        overlay.kinds = [.ignition]
        let host = await host(store, clock, timer, overlay)
        var ctx = HintContext(dockReveal: UUID()); ctx.reducedMotion = true
        try host.updateContext(ctx); try host.beginDockRevealDwell()
        XCTAssertEqual(timer.deadline, 0.5); let old = timer.saved.last!
        clock.now = 0.49; timer.fire(); XCTAssertTrue(overlay.presented.isEmpty)
        clock.now = 0.5; timer.fire(); XCTAssertEqual(timer.deadline, 5.5)
        XCTAssertEqual(host.hints.visible?.fadeSeconds, 0)
        old(); XCTAssertEqual(overlay.presented.count, 1)
        clock.now = 5.5; timer.fire(); XCTAssertNil(host.hints.visible); XCTAssertNil(timer.deadline)
        XCTAssertTrue(host.hints.preferences.seen.contains(.ignition)); await host.flushPersistence()
    }
    func testVisibleAnchorLossHidesButPreservesTheRealSeenAndBudgetSpend() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay), ctx = context(); try host.updateContext(ctx)
        overlay.remainsVisible = false; try host.updateContext(ctx); await host.flushPersistence()
        XCTAssertNil(host.hints.visible); XCTAssertNil(overlay.visible); XCTAssertNil(timer.deadline)
        XCTAssertTrue(host.hints.preferences.seen.contains(.detach)); XCTAssertTrue(host.hints.cockpitBudgetUsed)
    }
    func testReducedMotionUpdateKeepsTheSingleOriginalExpiry() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay); var ctx = context(); try host.updateContext(ctx)
        clock.now = 1; ctx.reducedMotion = true; try host.updateContext(ctx); await host.flushPersistence()
        XCTAssertEqual(overlay.updates.last?.fadeSeconds, 0); XCTAssertEqual(timer.deadline, 5)
        XCTAssertEqual(overlay.presented.count, 1)
    }
    func testSameContextRenderReentryCannotStrandAnUnconfirmedOffer() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay); var ctx = context()
        overlay.onShow = { overlay.onShow = nil; ctx.reducedMotion = true; try! host.updateContext(ctx) }
        try host.updateContext(ctx); await host.flushPersistence()
        XCTAssertEqual(host.hints.preferences.opens, 1); XCTAssertEqual(overlay.presented.count, 2)
        XCTAssertNil(host.hints.offered); XCTAssertEqual(host.hints.visible?.offer.id, overlay.visible?.id)
        XCTAssertTrue(host.hints.cockpitBudgetUsed)
    }
    func testExpiryIsMeasuredAfterTheVisibilityCallout() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay); overlay.onShow = { clock.now = 3 }
        try host.updateContext(context()); XCTAssertEqual(timer.deadline, 8); await host.flushPersistence()
    }
    func testTrialSourceIsValidatedAgainAfterRenderingBeforeSpending() async throws {
        let store = try store(); _ = try await store.update { $0.helpHints = .init(seen: Set(FirstUseHintKind.allCases.filter { $0 != .trial })) }
        let clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay(); overlay.kinds = [.trial]
        let host = await host(store, clock, timer, overlay); try host.updateContext(context())
        var live = true
        let state = InstrumentHintSourceSnapshot(anchor: .init(modelID: "a", regionID: "travel", travel: CGRect(x: 0, y: 0, width: 100, height: 100)), pointer: CGPoint(x: 20, y: 20))
        let lease = host.sources.register(isLive: { live }) { state }
        host.sources.receive(.faderRestCandidate(anchor: state.anchor, pointer: state.pointer, at: 0), from: lease)
        overlay.onShow = { live = false }; clock.now = 0.5; timer.fire(); await host.flushPersistence()
        XCTAssertFalse(host.hints.preferences.seen.contains(.trial)); XCTAssertFalse(host.hints.cockpitBudgetUsed)
        XCTAssertNil(host.sources.pendingTarget); XCTAssertNil(overlay.visible)
    }
    func testPersistenceSerializesAndCoalescesWhilePreservingOtherPreferences() async throws {
        let store = try store(), writer = HintGateWriter(store: store), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(writer, clock, timer, overlay); try host.updateContext(context())
        await writer.waitUntilBlocked(); try host.updateContext(context())
        await writer.release(); await host.flushPersistence()
        let saved = await store.snapshot(), maximum = await writer.maximumActive, calls = await writer.calls
        XCTAssertEqual(maximum, 1); XCTAssertEqual(calls, 2)
        XCTAssertEqual(saved.preferences.helpHints, host.hints.preferences); XCTAssertEqual(saved.preferences.helpHints.opens, 2)
    }
    func testCASConflictDoesNotRetryOverAnUnrelatedCommitOrLoseMemoryTruth() async throws {
        let store = try store(), writer = HintGateWriter(store: store), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(writer, clock, timer, overlay); try host.updateContext(context())
        await writer.waitUntilBlocked()
        let other = try await store.update { $0.openAtLogin = false }; host.observeCommitted(other)
        await writer.release(); await host.flushPersistence()
        XCTAssertNotNil(host.persistenceError); XCTAssertTrue(host.hints.preferences.seen.contains(.detach))
        let saved = await store.snapshot(); XCTAssertFalse(saved.preferences.openAtLogin); XCTAssertTrue(saved.preferences.helpHints.seen.isEmpty)
        try host.updateContext(context()); await host.flushPersistence(); let calls = await writer.calls
        XCTAssertEqual(calls, 1); XCTAssertFalse(host.hints.cockpitBudgetUsed)
        XCTAssertEqual(host.hints.preferences.opens, 2); XCTAssertEqual(overlay.presented.count, 1)
    }
    func testExplicitRetryRecoversTransientIOAndPersistsShownLedger() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("hint-retry-" + UUID().uuidString)
        try Data([1]).write(to: parent)
        addTeardownBlock { try? FileManager.default.removeItem(at: parent) }
        let url = parent.appendingPathComponent("settings.json")
        let store = try SettingsStore(url: url), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay)
        try host.updateContext(context()); await host.flushPersistence()
        let shown = host.hints.preferences
        XCTAssertNotNil(host.persistenceError); XCTAssertTrue(shown.seen.contains(.detach))
        try FileManager.default.removeItem(at: parent)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        host.retryPersistence(); await host.flushPersistence()
        let saved = await store.snapshot()
        XCTAssertNil(host.persistenceError); XCTAssertEqual(saved.revision, 1)
        XCTAssertEqual(saved.preferences.helpHints, shown)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(host.hints.cockpitBudgetUsed); XCTAssertEqual(overlay.presented.count, 1)
    }
    func testExplicitRetryPreservesCapturedCASRevisionAndReportsAnotherConflict() async throws {
        let store = try store(), writer = HintGateWriter(store: store), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(writer, clock, timer, overlay)
        try host.updateContext(context()); await writer.waitUntilBlocked()
        let other = try await store.update { $0.openAtLogin = false }; host.observeCommitted(other)
        await writer.release(); await host.flushPersistence()
        XCTAssertNotNil(host.persistenceError); let shown = host.hints.preferences
        host.retryPersistence(); await host.flushPersistence()
        let attempted = await writer.attemptedRevisions, saved = await store.snapshot()
        XCTAssertEqual(attempted, [0, 0]); XCTAssertNotNil(host.persistenceError)
        XCTAssertEqual(host.persistenceError as? SettingsError, .staleRevision)
        XCTAssertEqual(saved.revision, other.revision); XCTAssertFalse(saved.preferences.openAtLogin)
        XCTAssertTrue(saved.preferences.helpHints.seen.isEmpty); XCTAssertEqual(host.hints.preferences, shown)
        XCTAssertTrue(host.hints.cockpitBudgetUsed)
    }
    func testCommittedResetFencesAnOldWriteBeforeItTouchesTheStore() async throws { try await resetRace(afterCommit: false) }
    func testCommittedResetFencesALateSuccessReceipt() async throws { try await resetRace(afterCommit: true) }
    private func resetRace(afterCommit: Bool) async throws {
        let store = try store(), writer = HintGateWriter(store: store, afterCommit: afterCommit), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(writer, clock, timer, overlay); try host.updateContext(context()); await writer.waitUntilBlocked()
        let reset = try await store.update { $0.helpHints = .init() }
        let accepted = await host.applyCommittedReset(.init(revision: reset.revision, intent: .action(.resetHelpHints)))
        XCTAssertTrue(accepted); await writer.release(); await host.flushPersistence()
        let saved = await store.snapshot()
        XCTAssertEqual(saved.preferences.helpHints, .init()); XCTAssertEqual(host.hints.preferences, .init())
        XCTAssertNil(host.persistenceError); XCTAssertNil(host.hints.visible); XCTAssertNil(overlay.visible)
    }
    func testStaleOrUncommittedResetDoesNotClearSeenFlagsOrBudget() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay); try host.updateContext(context()); await host.flushPersistence()
        let before = host.hints.preferences
        let uncommitted = await host.applyCommittedReset(.init(revision: 999, intent: .action(.resetHelpHints)))
        XCTAssertFalse(uncommitted); XCTAssertEqual(host.hints.preferences, before); XCTAssertTrue(host.hints.cockpitBudgetUsed)
        let reset = try await store.update { $0.helpHints = .init() }
        let newer = try await store.update { $0.openAtLogin = false }; host.observeCommitted(newer)
        let stale = await host.applyCommittedReset(.init(revision: reset.revision, intent: .action(.resetHelpHints)))
        XCTAssertFalse(stale); XCTAssertEqual(host.hints.preferences, before)
    }
    func testRealEditorResetUsesTheSameStoreAndDoesNotReplaceWindowChangeObserver() async throws {
        let store = try store(), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay); try host.updateContext(context()); await host.flushPersistence()
        let editor = SettingsEditor(store: store); await editor.reload()
        var changes = 0, request: SettingsHostRequest?
        editor.onChange = { changes += 1 }; editor.onHostRequest = { request = $0 }
        _ = try await editor.commit(SettingsB21Edit.resetHints)
        let accepted = await host.applyCommittedReset(try XCTUnwrap(request))
        XCTAssertTrue(accepted); XCTAssertGreaterThan(changes, 0); XCTAssertEqual(host.hints.preferences, .init())
    }
    func testWriteFailureKeepsShownMemoryTruthAndReportsFailure() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("hint-io-" + UUID().uuidString)
        try Data([1]).write(to: parent); addTeardownBlock { try? FileManager.default.removeItem(at: parent) }
        let store = try SettingsStore(url: parent.appendingPathComponent("settings.json")), clock = HintClock(), timer = HintTestScheduler(), overlay = HintTestOverlay()
        let host = await host(store, clock, timer, overlay); var failures = 0
        host.onPersistenceFailure = { _ in failures += 1 }
        try host.updateContext(context()); await host.flushPersistence()
        XCTAssertEqual(failures, 1); XCTAssertNotNil(host.persistenceError)
        XCTAssertTrue(host.hints.preferences.seen.contains(.detach)); XCTAssertTrue(host.hints.cockpitBudgetUsed)
        let saved = await store.snapshot(); XCTAssertEqual(saved.revision, 0); XCTAssertTrue(saved.preferences.helpHints.seen.isEmpty)
    }
}
