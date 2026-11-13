// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

@MainActor private final class CommitObserverGate {
    var continuation: CheckedContinuation<Void, Never>?
    var calls = 0
    func wait() async { calls += 1; await withCheckedContinuation { continuation = $0 } }
    func release() { let old = continuation; continuation = nil; old?.resume() }
}
@MainActor final class SettingsCommitDeliveryTests: XCTestCase {
    private func store() throws -> SettingsStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-commit-delivery-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
    }
    func testNeverReturningObserverCannotKeepAnAlreadySavedEditBusyForever() async throws {
        let store = try store(), editor = SettingsEditor(store: store), gate = CommitObserverGate()
        await editor.reload()
        let entered = expectation(description: "consumer entered"), returned = expectation(description: "save returned")
        _ = editor.observeCommittedEdits { _ in entered.fulfill(); await gate.wait() }
        let save = Task { let value = try await editor.commit(SettingsB20Edit.theme(.night)); returned.fulfill(); return value }
        await fulfillment(of: [entered], timeout: 2)
        // The observer ignores cancellation and remains suspended until teardown, not until the save returns.
        await fulfillment(of: [returned], timeout: 3)
        XCTAssertFalse(editor.isSaving)
        let diskTruth = await store.snapshot(); XCTAssertEqual(diskTruth.preferences.theme, .night)
        XCTAssertEqual(editor.lastCommitDeliveryFailure?.revision, diskTruth.revision)
        XCTAssertTrue(editor.lastCommitDeliveryFailure?.message(.english).contains("Settings saved") == true)
        _ = try await editor.commit(SettingsB20Edit.size(.large))
        XCTAssertEqual(gate.calls, 1) // The uncooperative task is not launched once per later save.
        XCTAssertEqual(editor.snapshot?.preferences.size, .large)
        gate.release(); _ = try await save.value
    }
    func testSharedDeadlineDoesNotPreventOtherConsumersReceivingTheResetBoundary() async throws {
        let store = try store(), editor = SettingsEditor(store: store, commitObserverLimit: .milliseconds(30))
        await editor.reload()
        let first = CommitObserverGate(), second = CommitObserverGate()
        var failed = Set<UUID>(), resetRevision: UInt64?, hostRequest: SettingsHostRequest?
        let one = editor.observeCommittedEdits(onFailure: { failed.insert($0.observerID) }) { _ in await first.wait() }
        let two = editor.observeCommittedEdits(onFailure: { failed.insert($0.observerID) }) { _ in await second.wait() }
        _ = editor.observeCommittedEdits { edit in if let reset = edit.resetRequest { resetRevision = reset.revision } }
        editor.onHostRequest = { hostRequest = $0 }
        let saved = try await editor.commit(SettingsB21Edit.resetHints)
        XCTAssertEqual(resetRevision, saved.revision); XCTAssertEqual(hostRequest?.revision, saved.revision)
        XCTAssertEqual(failed, [one, two]); XCTAssertEqual(first.calls, 1); XCTAssertEqual(second.calls, 1)
        for _ in 0..<4 { _ = try await editor.commit(SettingsB20Edit.redBelow(20)) }
        XCTAssertEqual(first.calls, 1); XCTAssertEqual(second.calls, 1); XCTAssertFalse(editor.isSaving)
        first.release(); second.release()
    }
    func testRemovingOutstandingObserverReleasesSaveWithoutReportingDiskFailure() async throws {
        let store = try store(), editor = SettingsEditor(store: store), gate = CommitObserverGate()
        await editor.reload(); let entered = expectation(description: "entered")
        var committed = 0, changes = 0
        editor.onCommit = { _, _ in committed += 1 }; editor.onChange = { changes += 1 }
        let id = editor.observeCommittedEdits { _ in entered.fulfill(); await gate.wait() }
        let save = Task { try await editor.commit(SettingsB20Edit.theme(.day)) }
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertTrue(editor.isSaving); editor.removeCommitObserver(id)
        let saved = try await save.value
        XCTAssertFalse(editor.isSaving); XCTAssertEqual(saved.preferences.theme, .day)
        XCTAssertEqual(committed, 1); XCTAssertGreaterThan(changes, 0); XCTAssertNil(editor.lastCommitDeliveryFailure)
        gate.release()
    }
    func testLateCompletionDoesNotReenableConsumerOrClearTheRecordedFailure() async throws {
        let store = try store(), editor = SettingsEditor(store: store, commitObserverLimit: .milliseconds(30)), gate = CommitObserverGate()
        await editor.reload(); let completed = expectation(description: "old observer eventually completed")
        _ = editor.observeCommittedEdits { _ in await gate.wait(); completed.fulfill() }
        let saved = try await editor.commit(SettingsB20Edit.theme(.night))
        let issue = try XCTUnwrap(editor.lastCommitDeliveryFailure); XCTAssertEqual(issue.revision, saved.revision)
        _ = try await editor.commit(SettingsB21Edit.resetHints)
        gate.release(); await fulfillment(of: [completed], timeout: 2)
        _ = try await editor.commit(SettingsB20Edit.theme(.system))
        XCTAssertEqual(gate.calls, 1); XCTAssertEqual(editor.lastCommitDeliveryFailure, issue)
        XCTAssertFalse(editor.isSaving)
    }
    func testFailedCASCommitEmitsNoConsumerReceiptOrDeliveryFailure() async throws {
        let store = try store(), editor = SettingsEditor(store: store, commitObserverLimit: .milliseconds(30))
        await editor.reload(); var received = 0
        _ = editor.observeCommittedEdits { _ in received += 1 }
        _ = try await store.update(expectedRevision: 0) { $0.theme = .night }
        do { _ = try await editor.commit(SettingsB21Edit.resetHints); XCTFail("stale save") }
        catch { XCTAssertEqual(error as? SettingsError, .staleRevision) }
        XCTAssertEqual(received, 0); XCTAssertNil(editor.lastCommitDeliveryFailure)
        XCTAssertEqual(editor.snapshot?.preferences.theme, .night); XCTAssertFalse(editor.isSaving)
    }
    func testCooperativeConsumersAcknowledgeWithoutFailureAndKeepCallbacks() async throws {
        let store = try store(), editor = SettingsEditor(store: store), gate = CommitObserverGate()
        await editor.reload(); let entered = expectation(description: "entered")
        var receipts: [UInt64] = []
        _ = editor.observeCommittedEdits { edit in receipts.append(edit.after.revision); entered.fulfill(); await gate.wait() }
        let save = Task { try await editor.commit(SettingsB20Edit.theme(.night)) }
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertTrue(editor.isSaving); gate.release(); _ = try await save.value
        XCTAssertEqual(receipts, [1]); XCTAssertFalse(editor.isSaving); XCTAssertNil(editor.lastCommitDeliveryFailure)
    }

}
