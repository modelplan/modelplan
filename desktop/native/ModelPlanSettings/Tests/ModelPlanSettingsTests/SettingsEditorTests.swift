// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

@MainActor final class SettingsEditorTests: XCTestCase {
    private func file() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-editor-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("preferences.json")
    }
    func testSuccessfulCommitPublishesPersistedSnapshotWithoutReplacingOtherPreferences() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        try await store.update { p in
            p.openAtLogin = false; p.readerConsent.cursor = true
            p.subscriptionSettings["sample"] = .init(alias: "Work", percentagePin: .auto)
        }
        var context = SettingsPageContext()
        context.subscriptions = [.init(id: "sample", name: .init("Sample", "示例"))]
        let editor = SettingsEditor(store: store, context: context)
        await editor.reload()
        var commits = [SettingsSnapshot]()
        editor.onCommit = { snapshot, effective in
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertEqual(snapshot.preferences.size, effective.size)
            commits.append(snapshot)
        }
        try await editor.commit(.percentagePin("sample", .week))
        try await editor.commit(.size(.small))
        XCTAssertEqual(commits.map(\.revision), [2, 3])
        let restarted = try SettingsStore(url: url)
        let p = await restarted.snapshot().preferences
        XCTAssertEqual(p.size, .small); XCTAssertEqual(p.subscriptionSettings["sample"]?.percentagePin, .week)
        XCTAssertEqual(p.subscriptionSettings["sample"]?.alias, "Work")
        XCTAssertFalse(p.openAtLogin); XCTAssertTrue(p.readerConsent.cursor)
        XCTAssertEqual(editor.lastChangedSubscriptionID, "sample")
    }
    func testStaleEditReloadsTruthWithoutReceiptOrOverwritingExternalEdit() async throws {
        let store = try SettingsStore(url: file()), editor = SettingsEditor(store: store)
        await editor.reload()
        var commits = 0; editor.onCommit = { _, _ in commits += 1 }
        try await store.update { $0.theme = .night; $0.openAtLogin = false }
        do { try await editor.commit(.size(.large)); XCTFail("stale edit accepted") }
        catch { XCTAssertEqual(error as? SettingsError, .staleRevision) }
        XCTAssertEqual(commits, 0); XCTAssertFalse(editor.isSaving)
        XCTAssertEqual(editor.snapshot?.preferences.theme, .night)
        XCTAssertEqual(editor.snapshot?.preferences.size, .medium)
        try await editor.commit(.size(.large))
        XCTAssertEqual(commits, 1)
        XCTAssertFalse(editor.snapshot!.preferences.openAtLogin)
    }
    func testWriteFailureAndInvalidEditNeverPublishConsumerReceipt() async throws {
        let url = try file(), store = try SettingsStore(url: url), editor = SettingsEditor(store: store)
        await editor.reload()
        var commits = 0; editor.onCommit = { _, _ in commits += 1 }
        do { try await editor.commit(.redBelow(12)); XCTFail("invalid edit accepted") } catch {}
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        do { try await editor.commit(.theme(.night)); XCTFail("failed write accepted") } catch {}
        XCTAssertEqual(commits, 0); XCTAssertFalse(editor.isSaving)
        XCTAssertEqual(editor.snapshot?.preferences.redBelow, 16)
        XCTAssertEqual(editor.snapshot?.preferences.theme, .system)
    }
    func testContextAndEnvironmentUpdatesDoNotWriteOrPretendToCommit() async throws {
        let url = try file(), store = try SettingsStore(url: url), editor = SettingsEditor(store: store)
        await editor.reload()
        var commits = 0, observations = 0
        editor.onCommit = { _, _ in commits += 1 }
        editor.onEnvironmentChange = { snapshot, effective in
            observations += 1; XCTAssertEqual(snapshot.revision, 0); XCTAssertTrue(effective.reduceMotion)
        }
        var environment = SettingsEnvironment(); environment.reduceMotion = true
        editor.update(environment: environment); editor.update(context: .init())
        do { try await editor.commit(.percentagePin("gone", .week)); XCTFail("missing subscription accepted") }
        catch { XCTAssertEqual(error as? SettingsEditorError, .subscriptionUnavailable) }
        XCTAssertEqual(commits, 0); XCTAssertEqual(observations, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(editor.snapshot?.preferences.motion, .system)
        XCTAssertThrowsError(try SettingsB20Edit(key: .login, value: "true"))
        XCTAssertThrowsError(try SettingsB20Edit(key: .percentagePin, value: "week"))
    }
    func testConcurrentReloadAndCommitKeepTheLatestRevision() async throws {
        let store = try SettingsStore(url: file()), editor = SettingsEditor(store: store)
        await editor.reload()
        async let reload: Void = editor.reload()
        let committed = try await editor.commit(.theme(.night))
        await reload
        XCTAssertEqual(editor.snapshot?.revision, committed.revision)
        XCTAssertEqual(editor.snapshot?.preferences.theme, .night)
    }
}
