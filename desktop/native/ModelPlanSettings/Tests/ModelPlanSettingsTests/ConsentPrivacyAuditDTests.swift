// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// Audit D (consent, Settings and privacy): first-run completion after an engine rejection, the
/// first-run import trigger, removing coverage-only imported history, and the live login-item state.
@MainActor final class ConsentPrivacyAuditDTests: XCTestCase {
    private func controller(_ engine: ScopeConsentTestClient) -> ScopeConsentController {
        ScopeConsentController(commands: EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17,
                      allow: intent.allowIDs, deny: intent.denyIDs, forget: intent.forgetIDs)
        }))
    }
    private func receipt(_ requestID: String, code: WireReceiptCode = .ok) throws -> EngineGrantResult {
        let floor = EngineConsentFloor(storeEpoch: "synthetic", generation: 2)
        return .init(receipt: try WireConsentReceipt(requestId: requestID, committed: true, committedGeneration: 2, code: code),
                     committedAt: floor, delivery: .init(sessionID: "synthetic", floor: floor, revision: 1), supersededByLaterConsent: false)
    }

    /// Finding 1: the engine answers consent/grant with an error only when nothing was committed
    /// (consent_rejected, stale facts). First-run Done then keeps the page open with the choices.
    func testEngineRejectedFirstRunGrantDoesNotCompleteFirstRun() async throws {
        let engine = ScopeConsentTestClient()
        await engine.failGrant(.rpc(code: -32021, context: try WireErrorContext(sessionId: "synthetic")))
        let controller = controller(engine)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        controller.chooseFirstRunTool("cursor", chosen: false)
        let committed = await controller.commitFirstRunChoices()
        XCTAssertFalse(committed, "a rejected grant is not a finished first run")
        if case .idle = controller.phase {} else { XCTFail("nothing is pending after an explicit rejection") }
        if case .requestFailed = controller.notice {} else { XCTFail("the rejection is a failed request, not an unknown outcome") }
        let sent = await engine.recordedGrants()
        XCTAssertEqual(sent.count, 1, "the grant is never replayed on its own")
        XCTAssertEqual(sent.first?.deny.contains(ScopeConsentFixtures.cursor), true)
    }

    /// macrev2-858-1: another writer advances the consent generation while Done's grant is in flight.
    /// The client clears private state for the newer floor in the error before the grant finishes
    /// with the rejection; first run must still stay open, with nothing replayed or restored.
    func testRejectionAfterAPrivacyClearStillKeepsFirstRunOpen() async throws {
        let engine = ScopeConsentTestClient()
        await engine.holdGrant()
        await engine.failGrant(.rpc(code: -32020, context: try WireErrorContext(sessionId: "synthetic", storeEpoch: "synthetic", consentGeneration: 2)))
        let controller = controller(engine)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        controller.chooseFirstRunTool("cursor", chosen: false)
        let done = Task { await controller.commitFirstRunChoices() }
        await engine.waitForGrantStart()
        controller.clearAcceptedPrivateState() // the privacy barrier for the error's newer floor
        await engine.finishGrant()
        let committed = await done.value
        XCTAssertFalse(committed, "a rejected grant is not a finished first run, even after a privacy clear")
        let sent = await engine.recordedGrants()
        XCTAssertEqual(sent.count, 1, "the grant is never replayed on its own")
        XCTAssertNil(controller.facts, "cleared facts are not restored")
        // Post-merge sampling (#858): pressing Done again before replacement facts must not pass.
        XCTAssertFalse(controller.firstRunChoiceSatisfied, "Done stays disabled while the facts are gone")
        let again = await controller.commitFirstRunChoices()
        XCTAssertFalse(again, "a retry without facts must not complete first run without sending choices")
        let sentAfter = await engine.recordedGrants()
        XCTAssertEqual(sentAfter.count, 1)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        XCTAssertFalse(controller.factsClearedSinceAccepted, "fresh facts re-open Done")
    }

    /// Finding 1: the same rejection from Settings is a failed request too, so the user can retry.
    func testEngineRejectedSettingsGrantIsAFailedRequest() async throws {
        let engine = ScopeConsentTestClient()
        await engine.failGrant(.rpc(code: -32020, context: try WireErrorContext(sessionId: "synthetic")))
        let controller = controller(engine)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        controller.choose(ScopeConsentFixtures.local, selected: true)
        let request = try XCTUnwrap(controller.requestAllow())
        await controller.confirm(request.id)
        if case .idle = controller.phase {} else { XCTFail("an explicit rejection leaves nothing pending") }
        if case .requestFailed = controller.notice {} else { XCTFail("an explicit rejection is not an unknown outcome") }
    }

    /// Finding 5: only the committed receipt of the first-run Done grant starts the first-run import,
    /// once. A later Settings revoke (or any other ordinary receipt) never does.
    func testOnlyTheFirstRunGrantReceiptStartsTheFirstRunImport() async throws {
        let engine = ScopeConsentTestClient()
        let controller = controller(engine)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        XCTAssertFalse(controller.takeCommittedFirstRunGrant(try receipt("before-first-run")), "no first run yet")
        let committed = await controller.commitFirstRunChoices()
        XCTAssertTrue(committed)
        let afterDone = await engine.recordedGrants()
        let firstRun = try XCTUnwrap(afterDone.last?.requestId)
        XCTAssertFalse(controller.takeCommittedFirstRunGrant(try receipt("unrelated")))
        XCTAssertTrue(controller.takeCommittedFirstRunGrant(try receipt(firstRun)), "the first-run consent starts the import")
        XCTAssertFalse(controller.takeCommittedFirstRunGrant(try receipt(firstRun)), "once")
        // Later, in Settings: turn one tool off. Its committed receipt is not a first-run consent.
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let revoke = try XCTUnwrap(controller.requestToolChoice("cursor", on: false))
        await controller.confirm(revoke.id)
        let afterRevoke = await engine.recordedGrants()
        let settings = try XCTUnwrap(afterRevoke.last?.requestId)
        XCTAssertNotEqual(settings, firstRun)
        XCTAssertFalse(controller.takeCommittedFirstRunGrant(try receipt(settings)))
    }

    /// Finding 5: a first-run grant the engine did not apply cleanly starts nothing.
    func testRejectedFirstRunReceiptStartsNoImport() async throws {
        let engine = ScopeConsentTestClient()
        let controller = controller(engine)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        _ = await controller.commitFirstRunChoices()
        let afterDone = await engine.recordedGrants()
        let firstRun = try XCTUnwrap(afterDone.last?.requestId)
        XCTAssertFalse(controller.takeCommittedFirstRunGrant(try receipt(firstRun, code: .rejected)))
    }

    private final class ImportCommands: HistoryImportCommands {
        var ready = true
        var calls: [String] = []
        func start(days: Int, firstRun: Bool) async throws { calls.append("start") }
        func status() async throws { calls.append("status") }
        func cancel() async throws { calls.append("cancel") }
        func remove() async throws { calls.append("remove") }
    }

    /// Finding 4: a recorded coverage span with no daily rows is still imported history: Remove deletes it.
    func testCoverageWithoutRowsCanBeRemoved() async throws {
        let commands = ImportCommands(), model = HistoryImportModel(commands: commands)
        let json = #"{"schemaVersion":1,"phase":"done","days":30,"filesDone":0,"filesTotal":0,"firstRunDone":false,"importedRows":0,"coverage":[{"source":"codex","from":"2026-10-10","through":"2026-11-08","rows":0}],"sources":[]}"#
        model.receive(try WireDecoder.decode(WireHistoryImportStatus.self, from: Data(json.utf8)))
        XCTAssertTrue(model.hasImported); XCTAssertTrue(model.canRemove)
        await model.remove()
        XCTAssertEqual(commands.calls, ["remove"])
        let empty = #"{"schemaVersion":1,"phase":"idle","days":30,"filesDone":0,"filesTotal":0,"firstRunDone":false,"importedRows":0,"coverage":[],"sources":[]}"#
        model.receive(try WireDecoder.decode(WireHistoryImportStatus.self, from: Data(empty.utf8)))
        XCTAssertFalse(model.hasImported); XCTAssertFalse(model.canRemove)
    }

    /// Finding 6: the login item was turned on outside ModelPlan after launch. Choosing Off in Settings
    /// is decided against the live state, so the unregister request goes out.
    func testExplicitLoginChoiceUsesTheLiveLoginItemState() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("audit-d-login-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        var context = SettingsPageContext(); context.capabilities.login = .notRegistered
        let editor = SettingsEditor(store: try SettingsStore(url: directory.appendingPathComponent("preferences.json")), context: context)
        await editor.reload()
        var live = LoginServiceState.notRegistered
        editor.observeLogin = { live }
        var requests: [SettingsHostRequest] = []
        editor.onHostRequest = { requests.append($0) }
        live = .enabled // changed in System Settings while ModelPlan runs
        try await editor.commit(SettingsB21Edit.login(false))
        XCTAssertEqual(requests.last?.intent, .action(.setLoginEnabled(false)))
        XCTAssertEqual(editor.context.capabilities.login, .enabled, "the shown state follows the live read")
        live = .notRegistered
        let count = requests.count
        try await editor.commit(SettingsB21Edit.login(false))
        XCTAssertEqual(requests.count, count, "nothing to change when the item is already off")
    }
}
