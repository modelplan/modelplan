// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

final class PreferencesTests: XCTestCase {
    private func file() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-settings-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir.appendingPathComponent("preferences.json")
    }
    private func encoded(_ p: SettingsPreferences) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys; return try encoder.encode(p)
    }
    func testF15DefaultsAndMissingV1Fields() throws {
        let p = try JSONDecoder().decode(SettingsPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(p.theme, .system); XCTAssertEqual(p.size, .medium)
        XCTAssertEqual(p.motion, .system); XCTAssertEqual(p.transparency, .system)
        XCTAssertEqual(p.percentageMode, .remaining); XCTAssertTrue(p.showPercentages)
        XCTAssertEqual(p.redBelow, 25); XCTAssertTrue(p.sliverAlert)
        XCTAssertTrue(p.showDock); XCTAssertTrue(p.autoHide); XCTAssertEqual(p.revealMilliseconds, 150)
        XCTAssertFalse(p.showOverFullscreen); XCTAssertFalse(p.followActiveDisplay)
        XCTAssertEqual(p.menuDisplay, .icon); XCTAssertEqual(p.opening, .hold); XCTAssertEqual(p.beatMilliseconds, 250)
        XCTAssertTrue(p.showProjectNames); XCTAssertFalse(p.notifications.optedIn)
        XCTAssertEqual(p.notifications.kinds, Set(NotificationKind.allCases))
        for bad in ["{\"theme\":\"custom\"}", "{\"theme\":null}", "{\"redBelow\":17}", "{\"revealMilliseconds\":0}", "{\"showDock\":\"false\"}"] {
            XCTAssertThrowsError(try JSONDecoder().decode(SettingsPreferences.self, from: Data(bad.utf8)), bad)
        }
    }
    func testRestartRoundTripsEveryChoiceAndOnboarding() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        let snapshot = try await store.update { p in
            p.theme = .day; p.size = .large; p.motion = .on; p.transparency = .on
            p.percentageMode = .used; p.showPercentages = false; p.redBelow = 25; p.sliverAlert = false
            p.showDock = false; p.autoHide = false; p.revealMilliseconds = 300; p.magnification = .strong
            p.showOverFullscreen = true; p.followActiveDisplay = false; p.menuDisplay = .twoWindows
            p.language = .english; p.opening = .quick; p.beatMilliseconds = 150; p.showProjectNames = false
            p.openShortcut = .init("1", modifiers: [.control, .option]); p.dockShortcut = .init("2", modifiers: [.command])
            p.notifications.optedIn = true; p.notifications.kinds = [.reset, .official]
            p.subscriptions.hiddenIDs = ["b"]
            try p.subscriptions.move("b", to: 0, in: ["a", "b"])
            p.subscriptionSettings["a"] = .init(alias: "工作", percentagePin: .week)
            p.onboarding.next(); p.onboarding.next(); p.onboarding.recordLesson(.quick, holdAvailable: false); p.onboarding.next()
        }
        let restarted = try SettingsStore(url: url)
        let loaded = await restarted.snapshot()
        XCTAssertEqual(try encoded(snapshot.preferences), try encoded(loaded.preferences))
        XCTAssertEqual(loaded.preferences.subscriptions.order, ["b", "a"])
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        let text = try String(contentsOf: url, encoding: .utf8)
        for forbidden in ["login", "screenCapture", "authorization", "sourceStatus", "cliOutput", "apiKey", "cookie"] {
            XCTAssertFalse(text.contains("\"" + forbidden + "\""))
        }
    }
    func testNewDefaultsDoNotOverwriteExplicitSavedChoices() throws {
        let data = Data("{\"redBelow\":16,\"followActiveDisplay\":true,\"autoHide\":false,\"sliverAlert\":false}".utf8)
        let stored = try JSONDecoder().decode(SettingsPreferences.self, from: data)
        let restored = try JSONDecoder().decode(SettingsPreferences.self, from: JSONEncoder().encode(stored))
        XCTAssertEqual(restored.redBelow, 16)
        XCTAssertTrue(restored.followActiveDisplay)
        XCTAssertFalse(restored.autoHide)
        XCTAssertFalse(restored.sliverAlert)
    }
    func testExplicitDefaultsSurviveRestartAndUnrelatedEdits() async throws {
        for threshold in [10, 16, 20, 25] {
            let url = try file(), store = try SettingsStore(url: url)
            try await store.update { p in
                p.redBelow = threshold; p.size = .small; p.dockEdge = .left
                p.followActiveDisplay = true; p.autoHide = false
                p.sliverAlert = false; p.showOverFullscreen = true
            }
            let restarted = try SettingsStore(url: url)
            try await restarted.update { $0.language = .english }
            let snapshot = await restarted.snapshot()
            let saved = snapshot.preferences
            XCTAssertEqual(saved.redBelow, threshold); XCTAssertEqual(saved.size, .small)
            XCTAssertEqual(saved.dockEdge, .left); XCTAssertTrue(saved.followActiveDisplay)
            XCTAssertFalse(saved.autoHide); XCTAssertFalse(saved.sliverAlert); XCTAssertTrue(saved.showOverFullscreen)
        }
    }
    func testInvalidAndStaleTransactionsLeaveDiskAndMemoryIntact() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        try await store.update { $0.redBelow = 20 }
        let before = try Data(contentsOf: url)
        do { try await store.update { $0.redBelow = 12 }; XCTFail("accepted invalid threshold") } catch { XCTAssertEqual(error as? SettingsError, .invalidPreference) }
        do { try await store.update(expectedRevision: 0) { $0.showDock = false }; XCTFail("accepted stale edit") } catch { XCTAssertEqual(error as? SettingsError, .staleRevision) }
        XCTAssertEqual(try Data(contentsOf: url), before)
        let snapshot = await store.snapshot(); XCTAssertEqual(snapshot.revision, 1); XCTAssertEqual(snapshot.preferences.redBelow, 20)
    }
    func testWriteFailureDoesNotCommit() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        // A directory at the destination makes the atomic rename fail, without changing permissions elsewhere.
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        do { try await store.update { $0.showDock = false }; XCTFail("write should fail") } catch {}
        let snapshot = await store.snapshot(); XCTAssertTrue(snapshot.preferences.showDock); XCTAssertEqual(snapshot.revision, 0)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path), [url.lastPathComponent])
    }
    func testFutureCorruptAndOversizedFilesRemainUntouched() throws {
        let url = try file()
        for data in [Data("{\"schemaVersion\":2,\"preferences\":{}}".utf8), Data("broken".utf8), Data(repeating: 32, count: SettingsStore.maximumBytes + 1)] {
            try data.write(to: url)
            XCTAssertThrowsError(try SettingsStore(url: url))
            XCTAssertEqual(try Data(contentsOf: url), data)
        }
    }
    func testSerializedConcurrentEditsDoNotLoseOtherFields() async throws {
        let store = try SettingsStore(url: file())
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<20 { group.addTask { try await store.update { $0.subscriptionSettings["s\(index)"] = .init(alias: "alias\(index)") } } }
            try await group.waitForAll()
        }
        let snapshot = await store.snapshot(); XCTAssertEqual(snapshot.revision, 20); XCTAssertEqual(snapshot.preferences.subscriptionSettings.count, 20)
    }
    func testInvalidShortcutsAndAliasesAreRejected() throws {
        var p = SettingsPreferences(); p.dockShortcut = p.openShortcut; XCTAssertThrowsError(try p.validate())
        p = .init(); p.openShortcut = .init("A", modifiers: [.shift]); XCTAssertThrowsError(try p.validate())
        p = .init(); p.openShortcut = .init("Escape", modifiers: [.command]); XCTAssertThrowsError(try p.validate())
        p = .init(); p.subscriptionSettings["a"] = .init(alias: String(repeating: "a", count: 129)); XCTAssertThrowsError(try p.validate())
        p.subscriptionSettings["a"] = .init(alias: "a\nb"); XCTAssertThrowsError(try p.validate())
    }
}
