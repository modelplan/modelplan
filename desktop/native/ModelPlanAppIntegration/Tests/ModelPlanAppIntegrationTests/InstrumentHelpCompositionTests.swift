// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanInstruments
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class HelpClock { var now = 0.0 }
@MainActor private final class HelpScheduler: HintDeadlineScheduling {
    var deadline: Double?, action: (@MainActor () -> Void)?
    func arm(at deadline: Double, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline; self.action = action }
    func cancel() { deadline = nil; action = nil }
}
private actor HelpPausedWriter: HintPreferenceWriting {
    let store: SettingsStore
    var revisions: [UInt64] = []
    var blocker: CheckedContinuation<Void, Never>?, waiter: CheckedContinuation<Void, Never>?
    var paused = false
    init(_ store: SettingsStore) { self.store = store }
    func snapshot() async -> SettingsSnapshot { await store.snapshot() }
    func acceptsOrigin(of edit: SettingsCommittedEdit) -> Bool { edit.belongs(to: store) }
    func saveHints(_ preferences: FirstUseHintPreferences, expectedRevision: UInt64) async throws -> SettingsSnapshot {
        revisions.append(expectedRevision)
        if revisions.count == 1 {
            await withCheckedContinuation { blocker = $0; paused = true; waiter?.resume(); waiter = nil }
        }
        return try await store.saveHints(preferences, expectedRevision: expectedRevision)
    }
    func wait() async { if !paused { await withCheckedContinuation { waiter = $0 } } }
    func release() { let old = blocker; blocker = nil; old?.resume() }
}

@MainActor final class InstrumentHelpCompositionTests: XCTestCase {
    private func application() throws -> SettingsApplicationCoordinator {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("help-composition-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("preferences.json"))) { _ in }
    }
    private func input(_ id: UUID = UUID()) -> HelpUIRenderInput {
        .init(sessionID: id, viewport: .init(width: 1000, height: 640), profile: .compact640, language: .english,
              anchors: [.init(id: "anchor", rect: .init(x: 450, y: 300, width: 20, height: 20))])
    }
    private func context(_ input: HelpUIRenderInput) -> HintContext {
        var context = HintContext(cockpitOpen: input.sessionID); context.captureReady = true; return context
    }
    private func copy(_ kind: FirstUseHintKind = .detach) -> [FirstUseHintKind: HelpHintContent] {
        [kind: .init(anchorID: "anchor", text: "Neutral test explanation", dismissTitle: "Dismiss")]
    }
    private func composition(_ app: SettingsApplicationCoordinator, clock: HelpClock? = nil,
                             visibility: (@MainActor (HelpUILayerView, CGRect) -> Bool)? = { _, _ in true }) async -> InstrumentHelpComposition {
        let clock = clock ?? HelpClock()
        return await InstrumentHelpComposition.restored(application: app, scheduler: HelpScheduler(), uptime: { clock.now }, visibility: visibility)
    }
    func testConcreteLayerAndSameStoreConfirmThenRefreshTheExistingEditor() async throws {
        let app = try application(), composition = await composition(app), input = input()
        var windowChanges = 0; app.editor.onChange = { windowChanges += 1 }
        try composition.update(input, content: copy(), context: context(input)); await composition.flush()
        let snapshot = await app.editor.store.snapshot()
        XCTAssertTrue(snapshot.preferences.helpHints.seen.contains(.detach))
        XCTAssertEqual(snapshot.preferences.helpHints, composition.host.hints.preferences)
        XCTAssertEqual(app.editor.snapshot?.revision, snapshot.revision)
        XCTAssertEqual(composition.layer.presentation?.card?.identity, composition.host.hints.visible.map { .firstUse($0.offer.id) })
        XCTAssertTrue(composition.host.hints.cockpitBudgetUsed); XCTAssertGreaterThan(windowChanges, 0)
        composition.dispose()
    }
    func testGeometryWithoutAWindowNeverConfirmsOrSpends() async throws {
        let app = try application(), composition = await composition(app, visibility: nil), input = input()
        var geometryOffers = 0
        composition.layer.onPresentation = { if $0.card != nil { geometryOffers += 1 } }
        try composition.update(input, content: copy(), context: context(input)); await composition.flush()
        XCTAssertGreaterThan(geometryOffers, 0); XCTAssertNil(composition.layer.window)
        XCTAssertTrue(composition.host.hints.preferences.seen.isEmpty)
        XCTAssertFalse(composition.host.hints.cockpitBudgetUsed); XCTAssertNil(composition.host.hints.visible)
        composition.dispose()
    }
    func testUnplaceableLayerConsumesNothingEvenWithInjectedVisibility() async throws {
        let app = try application(), composition = await composition(app)
        var input = input(); input.liveReadings = [.init(origin: .zero, size: input.viewport)]
        try composition.update(input, content: copy(), context: context(input)); await composition.flush()
        XCTAssertTrue(composition.host.hints.preferences.seen.isEmpty); XCTAssertFalse(composition.host.hints.cockpitBudgetUsed)
        composition.dispose()
    }
    func testVisibilityCalloutSuspensionCannotConfirmStaleRender() async throws {
        let app = try application(); var current: InstrumentHelpComposition?
        let composition = await composition(app, visibility: { _, _ in current?.suspend(); return true }); current = composition
        let input = input(); try composition.update(input, content: copy(), context: context(input)); await composition.flush()
        XCTAssertFalse(composition.host.isRunning); XCTAssertTrue(composition.host.hints.preferences.seen.isEmpty)
        XCTAssertNil(composition.host.hints.visible); composition.dispose()
    }
    func testOldHideAndHeldActionCannotDismissReplacementSession() async throws {
        let app = try application(), composition = await composition(app), first = input()
        try composition.update(first, content: copy(), context: context(first)); await composition.flush()
        let oldID = try XCTUnwrap(composition.host.hints.visible?.offer.id), oldAction = try XCTUnwrap(composition.layer.onAction)
        let next = input(); try composition.update(next, content: copy(.optionHelp), context: context(next)); await composition.flush()
        let newID = try XCTUnwrap(composition.host.hints.visible?.offer.id)
        XCTAssertNotEqual(oldID, newID)
        composition.overlay.hide(offerID: oldID)
        oldAction(.dismissHint(offerID: newID, reason: .escape))
        composition.layer.onAction?(.dismissHint(offerID: oldID, reason: .escape))
        XCTAssertEqual(composition.layer.presentation?.card?.identity, .firstUse(newID))
        composition.layer.onAction?(.dismissHint(offerID: newID, reason: .explicitButton))
        XCTAssertNil(composition.host.hints.visible); XCTAssertNil(composition.layer.presentation?.card)
        composition.dispose()
    }
    func testTrialRequiresMatchingLiveSourceBindingAndRetiresOnReplacement() async throws {
        for bound in [false, true] {
            let app = try application(), clock = HelpClock(), composition = await composition(app, clock: clock), input = input()
            let anchor = FaderRestAnchor(modelID: "model", regionID: "travel", travel: .init(x: 1, y: 1, width: 20, height: 100))
            let state = InstrumentHintSourceSnapshot(anchor: anchor, pointer: .init(x: 10, y: 20))
            try composition.update(input, content: copy(.trial), context: context(input), trialSource: bound ? state : nil)
            let lease = composition.host.sources.register(isLive: { true }, resolve: { state })
            composition.host.sources.receive(.faderRestCandidate(anchor: anchor, pointer: state.pointer, at: 0), from: lease)
            clock.now = 0.5; try composition.host.request(.optionHelp); await composition.flush()
            XCTAssertEqual(composition.host.hints.preferences.seen.contains(.trial), bound)
            XCTAssertEqual(composition.host.hints.cockpitBudgetUsed, bound)
            if bound {
                try composition.update(input, content: copy(.trial), context: context(input), trialSource: nil)
                XCTAssertNil(composition.host.hints.visible); XCTAssertNil(composition.layer.presentation?.card)
                XCTAssertTrue(composition.host.hints.preferences.seen.contains(.trial))
            }
            composition.dispose()
        }
    }
    func testGeometryChangeCancelsRestWithoutASecondViewTimer() async throws {
        let app = try application(), clock = HelpClock(), composition = await composition(app, clock: clock)
        var input = input()
        let anchor = FaderRestAnchor(modelID: "model", regionID: "travel", travel: .init(x: 1, y: 1, width: 20, height: 100))
        let state = InstrumentHintSourceSnapshot(anchor: anchor, pointer: .init(x: 10, y: 20))
        try composition.update(input, content: copy(.trial), context: context(input), trialSource: state)
        let lease = composition.host.sources.register(isLive: { true }, resolve: { state })
        composition.host.sources.receive(.faderRestCandidate(anchor: anchor, pointer: state.pointer, at: 0), from: lease)
        XCTAssertNotNil(composition.host.hints.trialRest)
        input.viewport.width += 1
        try composition.update(input, content: copy(.trial), context: context(input), trialSource: state)
        XCTAssertNil(composition.host.hints.trialRest); XCTAssertNil(composition.host.sources.pendingTarget)
        composition.dispose()
    }
    func testMapSuppressesFirstUseAndForwardsExistingSemanticAction() async throws {
        let app = try application(), composition = await composition(app)
        var input = input(); input.map.mode = .latched
        var actions: [HelpUIAction] = []; composition.onHelpAction = { actions.append($0) }
        try composition.update(input, content: copy(), context: context(input)); await composition.flush()
        XCTAssertTrue(composition.host.hints.preferences.seen.isEmpty)
        XCTAssertTrue(composition.layer.handleEscape()); XCTAssertEqual(actions.count, 1)
        composition.dispose()
    }
    func testUnrelatedCommitAdvancesOnlyProvenCASAndKeepsWindowCallbacks() async throws {
        let app = try application(), composition = await composition(app)
        var changes = 0, results: [Bool] = []; app.editor.onChange = { changes += 1 }
        composition.onSettingsReceipt = { _, accepted in results.append(accepted) }
        _ = try await app.editor.commit(SettingsB20Edit.theme(.night))
        XCTAssertEqual(results, [true]); XCTAssertEqual(app.latest?.snapshot.preferences.theme, .night)
        let input = input(); try composition.update(input, content: copy(), context: context(input)); await composition.flush()
        let snapshot = await app.editor.store.snapshot()
        XCTAssertEqual(snapshot.preferences.theme, .night); XCTAssertTrue(snapshot.preferences.helpHints.seen.contains(.detach))
        XCTAssertNil(composition.host.persistenceError); XCTAssertGreaterThan(changes, 0)
        composition.dispose()
    }
    func testTypedSuccessfulResetReachesSingleHostAndFailedResetDoesNotClear() async throws {
        let app = try application(), composition = await composition(app), input = input()
        var kinds: [SettingsCommittedEdit.Kind] = []; composition.onSettingsReceipt = { edit, _ in kinds.append(edit.kind) }
        try composition.update(input, content: copy(), context: context(input)); await composition.flush()
        let before = composition.host.hints.preferences
        _ = try await app.editor.store.update(expectedRevision: app.editor.snapshot!.revision) { $0.theme = .night }
        do { _ = try await app.editor.commit(SettingsB21Edit.resetHints); XCTFail("stale reset must fail") }
        catch { XCTAssertEqual(error as? SettingsError, .staleRevision) }
        XCTAssertEqual(composition.host.hints.preferences, before); XCTAssertTrue(kinds.isEmpty)
        _ = try await app.editor.commit(SettingsB21Edit.resetHints)
        XCTAssertEqual(kinds, [.resetHelpHints]); XCTAssertTrue(composition.host.hints.preferences.seen.isEmpty)
        XCTAssertFalse(composition.host.hints.cockpitBudgetUsed); XCTAssertNil(composition.layer.presentation?.card)
        composition.dispose()
    }
    func testAlreadyEmptyResetIsStillTypedAndNeverTreatedAsOrdinaryEdit() async throws {
        let app = try application(), composition = await composition(app)
        var kinds: [SettingsCommittedEdit.Kind] = [], accepted: [Bool] = []
        composition.onSettingsReceipt = { edit, success in kinds.append(edit.kind); accepted.append(success) }
        _ = try await app.editor.commit(SettingsB21Edit.resetHints)
        _ = try await app.editor.commit(SettingsB20Edit.size(.large))
        XCTAssertEqual(kinds, [.resetHelpHints, .preferences]); XCTAssertEqual(accepted, [true, true])
        XCTAssertTrue(composition.host.hints.preferences.seen.isEmpty); composition.dispose()
    }
    func testTypedReceiptHoldsSaveBoundaryUntilAcknowledged() async throws {
        let app = try application(); await app.reload()
        let arrived = expectation(description: "receipt consumer"), released = expectation(description: "released")
        var continuation: CheckedContinuation<Void, Never>?, receipts = 0
        let observer = app.editor.observeCommittedEdits { _ in
            receipts += 1; arrived.fulfill()
            await withCheckedContinuation { continuation = $0 }
            released.fulfill()
        }
        let commit = Task { try await app.editor.commit(SettingsB20Edit.theme(.night)) }
        await fulfillment(of: [arrived], timeout: 2)
        XCTAssertTrue(app.editor.isSaving)
        do { _ = try await app.editor.commit(SettingsB21Edit.resetHints); XCTFail("must not overtake") }
        catch { XCTAssertEqual(error as? SettingsEditorError, .editInProgress) }
        continuation?.resume(); _ = try await commit.value
        await fulfillment(of: [released], timeout: 2)
        app.editor.removeCommitObserver(observer)
        _ = try await app.editor.commit(SettingsB20Edit.size(.small)); XCTAssertEqual(receipts, 1)
    }
    func testReceiptFromAnotherStoreCannotRebaseAcrossAnEmptyReset() async throws {
        let app = try application(), other = try application(); await app.reload(); await other.reload()
        let scheduler = HelpScheduler(), overlay = HelpUILayerView(), adapter = InstrumentHelpOverlay(layer: overlay, visibility: { _, _ in true })
        let host = await HintExecutionHost.restored(persistence: app.editor.store, scheduler: scheduler, overlay: adapter, uptime: { 0 })
        _ = try await app.editor.store.update(expectedRevision: 0) { $0.helpHints = .init() }
        var receipt: SettingsCommittedEdit?
        _ = other.editor.observeCommittedEdits { receipt = $0 }
        _ = try await other.editor.commit(SettingsB20Edit.theme(.system))
        let accepted = await host.reconcileUnchangedHints(try XCTUnwrap(receipt)); XCTAssertFalse(accepted)
        let input = input(); adapter.updateSurface(input, content: copy()); try host.updateContext(context(input)); await host.flushPersistence()
        XCTAssertEqual(host.persistenceError as? SettingsError, .staleRevision)
        let saved = await app.editor.store.snapshot(); XCTAssertTrue(saved.preferences.helpHints.seen.isEmpty)
        host.dispose(); adapter.dispose()
    }
    func testRealStaleCASRecoversOnlyThroughTheMatchingUnchangedLedgerReceipt() async throws {
        let app = try application(); await app.reload()
        let adapter = InstrumentHelpOverlay(layer: HelpUILayerView(), visibility: { _, _ in true })
        let host = await HintExecutionHost.restored(persistence: app.editor.store, scheduler: HelpScheduler(), overlay: adapter, uptime: { 0 })
        var receipt: SettingsCommittedEdit?; _ = app.editor.observeCommittedEdits { receipt = $0 }
        _ = try await app.editor.commit(SettingsB20Edit.theme(.night))
        let input = input(); adapter.updateSurface(input, content: copy()); try host.updateContext(context(input)); await host.flushPersistence()
        XCTAssertEqual(host.persistenceError as? SettingsError, .staleRevision)
        let accepted = await host.reconcileUnchangedHints(try XCTUnwrap(receipt)); XCTAssertTrue(accepted); await host.flushPersistence()
        let saved = await app.editor.store.snapshot(); XCTAssertEqual(saved.preferences.theme, .night)
        XCTAssertTrue(saved.preferences.helpHints.seen.contains(.detach)); XCTAssertNil(host.persistenceError)
        host.dispose(); adapter.dispose()
    }
    func testMatchingReceiptCannotRebaseOverANewerEmptyReset() async throws {
        let app = try application(); await app.reload()
        let adapter = InstrumentHelpOverlay(layer: HelpUILayerView(), visibility: { _, _ in true })
        let host = await HintExecutionHost.restored(persistence: app.editor.store, scheduler: HelpScheduler(), overlay: adapter, uptime: { 0 })
        var receipt: SettingsCommittedEdit?; _ = app.editor.observeCommittedEdits { receipt = $0 }
        _ = try await app.editor.commit(SettingsB20Edit.theme(.night))
        _ = try await app.editor.store.update(expectedRevision: 1) { $0.helpHints = .init() }
        let input = input(); adapter.updateSurface(input, content: copy()); try host.updateContext(context(input)); await host.flushPersistence()
        let accepted = await host.reconcileUnchangedHints(try XCTUnwrap(receipt))
        XCTAssertFalse(accepted); XCTAssertEqual(host.persistenceError as? SettingsError, .staleRevision)
        let saved = await app.editor.store.snapshot(); XCTAssertTrue(saved.preferences.helpHints.seen.isEmpty)
        XCTAssertTrue(host.hints.preferences.seen.contains(.detach)) // Real memory truth survives the rejected rebase.
        host.dispose(); adapter.dispose()
    }
    func testPreCommitPendingWriterIsFencedBeforeReconciledWrite() async throws {
        let app = try application(); await app.reload(); let writer = HelpPausedWriter(app.editor.store)
        let adapter = InstrumentHelpOverlay(layer: HelpUILayerView(), visibility: { _, _ in true })
        let host = await HintExecutionHost.restored(persistence: writer, scheduler: HelpScheduler(), overlay: adapter, uptime: { 0 })
        let input = input(); adapter.updateSurface(input, content: copy()); try host.updateContext(context(input)); await writer.wait()
        var receipt: SettingsCommittedEdit?; _ = app.editor.observeCommittedEdits { receipt = $0 }
        _ = try await app.editor.commit(SettingsB20Edit.theme(.night))
        let accepted = await host.reconcileUnchangedHints(try XCTUnwrap(receipt)); XCTAssertTrue(accepted)
        await writer.release(); await host.flushPersistence()
        let revisions = await writer.revisions, saved = await app.editor.store.snapshot()
        XCTAssertEqual(revisions, [0, 1]); XCTAssertEqual(saved.preferences.theme, .night)
        XCTAssertTrue(saved.preferences.helpHints.seen.contains(.detach)); XCTAssertNil(host.persistenceError)
        host.dispose(); adapter.dispose()
    }
    func testDisposeUnbindsSettingsAndHeldCallbacksWithoutCreatingAnotherHost() async throws {
        let app = try application(), composition = await composition(app), input = input()
        var actions = 0; composition.onHelpAction = { _ in actions += 1 }
        try composition.update(input, content: [:], context: context(input)); await composition.flush()
        let action = composition.layer.onAction
        composition.dispose()
        action?(.mapSourceAction(actionID: "test"))
        _ = try await app.editor.commit(SettingsB20Edit.theme(.night))
        XCTAssertEqual(actions, 0); XCTAssertNil(composition.layer.onAction); XCTAssertFalse(composition.host.isRunning)
    }
    func testStartupReceiptWaitsForTheRestoredCompositionBeforeReleasingSave() async throws {
        let app = try application(); await app.reload()
        let connection = HelpSettingsReceiptConnection(), arrived = expectation(description: "startup receipt")
        let observer = app.editor.observeCommittedEdits { edit in
            arrived.fulfill(); await connection.receive(edit)
        }
        let edit = Task { try await app.editor.commit(SettingsB20Edit.theme(.night)) }
        await fulfillment(of: [arrived], timeout: 2)
        XCTAssertTrue(app.editor.isSaving)
        let restored = await composition(app)
        XCTAssertTrue(app.editor.isSaving) // The earlier startup connection still owns acknowledgment.
        await connection.connect(restored); _ = try await edit.value
        XCTAssertFalse(app.editor.isSaving); XCTAssertEqual(app.editor.snapshot?.preferences.theme, .night)
        XCTAssertTrue(restored.host.hints.preferences.seen.isEmpty)
        app.editor.removeCommitObserver(observer); restored.dispose()
    }
    func testCommunitySessionRetainsOneConcreteHostWithoutShowingAWindow() async throws {
        let app = try application(); var created = 0
        let session = CommunitySettingsSession(application: app, canPresent: { false }, makeHelp: { app in
            created += 1; return await self.composition(app)
        })
        async let first: Void = session.restorePreferences()
        async let second: Void = session.restorePreferences()
        _ = await (first, second)
        XCTAssertEqual(created, 1); let help = try XCTUnwrap(session.helpComposition)
        XCTAssertNil(help.layer.window); XCTAssertEqual(help.host.hints.preferences.opens, 0)
        session.suspend(); XCTAssertFalse(help.host.isRunning)
        help.dispose()
    }
}
