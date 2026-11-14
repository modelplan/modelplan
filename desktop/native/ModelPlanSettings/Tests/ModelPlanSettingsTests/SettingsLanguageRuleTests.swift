// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

/// SET-9-39: first-launch language walks the whole macOS list, one English fallback, and a Follow System choice.
@MainActor final class SettingsLanguageRuleTests: XCTestCase {
    func testResolveWalksTheWholePreferredList() {
        let table: [([String], SettingsLanguage)] = [
            (["en-US", "zh-Hans"], .english),
            (["fr-FR", "zh-Hans"], .chinese),
            (["fr-FR", "de-DE", "en-GB"], .english),
            (["zh-TW"], .chinese), (["zh-Hant"], .chinese), (["zh-HK"], .chinese), (["zh-Hant-TW"], .chinese),
            (["zh_Hans_CN"], .chinese), (["ZH-hans"], .chinese), (["zh"], .chinese), (["en"], .english),
            (["fr-FR"], .english), ([], .english), (["zhx-Latn", "en"], .english), (["english"], .english),
        ]
        for (list, expected) in table {
            XCTAssertEqual(SettingsLanguage.resolve(preferredLanguages: list), expected, "\(list)")
        }
    }
    func testOneSharedFallbackIsEnglishAndEveryDefaultUsesIt() async throws {
        XCTAssertEqual(SettingsLanguage.fallback, .english)
        XCTAssertEqual(SettingsPreferences().language, SettingsLanguage.fallback)
        XCTAssertEqual(SettingsLanguage.resolve(preferredLanguages: []), SettingsLanguage.fallback)
        let store = try SettingsStore(url: file())
        let editor = SettingsEditor(store: store); await editor.reload()
        XCTAssertEqual(editor.snapshot?.preferences.language, SettingsLanguage.fallback)
    }
    func testFreshInstallFollowsTheSystemAndRelaunchRefollowsIt() async throws {
        let root = try directory()
        let first = try SettingsStore(foundationAt: root, product: .community,
            defaultLanguage: SettingsLanguage.resolve(preferredLanguages: ["fr-FR", "zh-Hans"]), preferredLanguages: ["fr-FR", "zh-Hans"])
        let created = await first.snapshot().preferences
        XCTAssertEqual(created.language, .chinese); XCTAssertTrue(created.followsSystemLanguage)
        // The macOS list changes between launches: a store that follows the system follows it again.
        let second = try SettingsStore(foundationAt: root, product: .community,
            defaultLanguage: .english, preferredLanguages: ["en-US"])
        let relaunched = await second.snapshot().preferences
        XCTAssertEqual(relaunched.language, .english); XCTAssertTrue(relaunched.followsSystemLanguage)
    }
    func testExplicitChoiceIsKeptAcrossLaunchesUntilFollowSystemIsChosenAgain() async throws {
        let root = try directory()
        let store = try SettingsStore(foundationAt: root, product: .community, defaultLanguage: .english, preferredLanguages: ["en-US"])
        let editor = SettingsEditor(store: store); await editor.reload()
        try await editor.commit(SettingsB21Edit.language(.chinese))
        let stored = try SettingsStore(foundationAt: root, product: .community, preferredLanguages: ["en-US"])
        let explicit = await stored.snapshot().preferences
        XCTAssertEqual(explicit.language, .chinese); XCTAssertFalse(explicit.followsSystemLanguage)
        let again = SettingsEditor(store: stored); await again.reload()
        try await again.commit(SettingsB21Edit.followSystemLanguage(resolved: .english))
        let followed = try SettingsStore(foundationAt: root, product: .community, preferredLanguages: ["zh-Hant-TW"])
        let afterwards = await followed.snapshot().preferences
        XCTAssertTrue(afterwards.followsSystemLanguage)
        XCTAssertEqual(afterwards.language, .chinese, "Follow System resolves from the list at launch")
    }
    func testFollowSystemIsAThirdChoiceOnTheLanguageRow() throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        var preferences = SettingsPreferences()
        func row() throws -> SettingsRowValue {
            try XCTUnwrap(SettingsCatalogue.rows(preferences: preferences, context: context).first { $0.key == .language }).value
        }
        guard case .choice(let selected, let options) = try row() else { return XCTFail("Language must offer choices") }
        XCTAssertEqual(Set(options), Set(["system", "zh-CN", "en"]))
        XCTAssertEqual(selected, "en", "An existing document without the field keeps its stored language")
        preferences.followsSystemLanguage = true
        guard case .choice(let following, _) = try row() else { return XCTFail("Language must offer choices") }
        XCTAssertEqual(following, "system")
        XCTAssertEqual(SettingsWords.option("system", key: .language, language: .english), "Follow system")
        XCTAssertEqual(SettingsWords.option("system", key: .language, language: .chinese), "跟随系统")
        let edit = try SettingsB21Edit(key: .language, value: "system")
        guard case .followSystemLanguage = edit else { return XCTFail("system must map to Follow System") }
        var applied = SettingsPreferences()
        try SettingsB21Edit.language(.english).apply(to: &applied, catalogue: [])
        XCTAssertFalse(applied.followsSystemLanguage)
    }
    func testMissingFieldInAnExistingDocumentKeepsItsLanguage() throws {
        let decoded = try JSONDecoder().decode(SettingsPreferences.self, from: Data(#"{"language":"zh-CN"}"#.utf8))
        XCTAssertEqual(decoded.language, .chinese); XCTAssertFalse(decoded.followsSystemLanguage)
        let round = try JSONDecoder().decode(SettingsPreferences.self, from: JSONEncoder().encode(SettingsPreferences()))
        XCTAssertFalse(round.followsSystemLanguage)
    }
    /// Sampling #873: before Follow System the default was Chinese, and the sparse writer left `language` out for every
    /// Chinese user. Upgrading must keep Chinese (not English, not Follow System), and every save now writes the key.
    func testUpgradedSparseFileWithoutLanguageStaysChineseAndSavesWriteTheKey() async throws {
        let root = try directory()
        let location = try FoundationPreferenceLocation(applicationSupport: root, product: .community)
        try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":1,"sparse":true,"settings":{"theme":"night"},"core":{"favouriteModelIDs":[]}}"#.utf8).write(to: location.target)
        func open() throws -> SettingsStore {
            try SettingsStore(foundationAt: root, product: .community, defaultLanguage: .english, preferredLanguages: ["en-US"])
        }
        func saved() throws -> [String: Any] {
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: location.target)) as? [String: Any])
            return try XCTUnwrap(object["settings"] as? [String: Any])
        }
        var store = try open()
        var preferences = await store.snapshot().preferences
        XCTAssertEqual(preferences.language, .chinese, "a pre-#873 file without the key was a Chinese choice")
        XCTAssertFalse(preferences.followsSystemLanguage, "the upgrade does not switch to Follow System")
        XCTAssertEqual(preferences.theme, .night)
        // An unrelated save writes the language too, so the file no longer depends on the old default.
        _ = try await store.update { $0.theme = .day }
        XCTAssertEqual(try saved()["language"] as? String, "zh-CN")
        XCTAssertEqual(try saved()["followsSystemLanguage"] as? Bool, false)
        _ = try await store.update { $0.language = .english }
        XCTAssertEqual(try saved()["language"] as? String, "en", "English, now the default, is still written")
        store = try open()
        preferences = await store.snapshot().preferences
        XCTAssertEqual(preferences.language, .english); XCTAssertFalse(preferences.followsSystemLanguage)
        // The legacy single-file store reads and writes the same way.
        let url = try file()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":1,"sparse":true,"preferences":{"theme":"night"}}"#.utf8).write(to: url)
        let legacy = try SettingsStore(url: url)
        let legacyLanguage = await legacy.snapshot().preferences.language
        XCTAssertEqual(legacyLanguage, .chinese)
        _ = try await legacy.update { $0.theme = .day }
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((envelope["preferences"] as? [String: Any])?["language"] as? String, "zh-CN")
    }
    /// Sampling #873: a fresh install keeps #873's default (follow the macOS list) and writes both keys.
    func testFreshInstallStillFollowsTheSystemAndWritesTheLanguage() async throws {
        let root = try directory()
        let store = try SettingsStore(foundationAt: root, product: .community, defaultLanguage: .english, preferredLanguages: ["en-US"])
        let created = await store.snapshot().preferences
        XCTAssertEqual(created.language, .english); XCTAssertTrue(created.followsSystemLanguage)
        let location = try FoundationPreferenceLocation(applicationSupport: root, product: .community)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: location.target)) as? [String: Any])
        let settings = try XCTUnwrap(object["settings"] as? [String: Any])
        XCTAssertEqual(settings["language"] as? String, "en"); XCTAssertEqual(settings["followsSystemLanguage"] as? Bool, true)
        // A file from a build after #873 that followed the system and left English out reads as English.
        let decoded = try JSONDecoder().decode(SettingsPreferences.self, from: Data(#"{"followsSystemLanguage":true}"#.utf8))
        XCTAssertEqual(decoded.language, .english); XCTAssertTrue(decoded.followsSystemLanguage)
        XCTAssertEqual(try JSONDecoder().decode(SettingsPreferences.self, from: Data("{}".utf8)).language, .chinese)
        XCTAssertEqual(SettingsPreferences().language, .english, "a brand-new value keeps the English fallback")
    }
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("settings-language-rule-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func file() throws -> URL {
        try directory().appendingPathComponent("settings.json")
    }
}
