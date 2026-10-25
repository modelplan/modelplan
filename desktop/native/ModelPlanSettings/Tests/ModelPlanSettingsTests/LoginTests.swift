// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

final class LoginTests: XCTestCase {
    private func file() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-login-choice-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("preferences.json")
    }
    func testNewAndMissingFieldDefaultsAreOnWithoutServiceRegistration() async throws {
        XCTAssertTrue(SettingsPreferences().openAtLogin)
        let partial = try JSONDecoder().decode(SettingsPreferences.self, from: Data("{}".utf8))
        XCTAssertTrue(partial.openAtLogin)
        let url = try file(), store = try SettingsStore(url: url), snapshot = await store.snapshot()
        XCTAssertTrue(snapshot.preferences.openAtLogin)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let capabilities = SettingsCapabilities()
        let login = LoginSetting(preferences: snapshot.preferences, capabilities: capabilities)
        XCTAssertTrue(login.requestedEnabled); XCTAssertEqual(login.observedState, .notRegistered)
        XCTAssertEqual(capabilities.login, .notRegistered)
    }
    func testOldV1DocumentWithoutChoiceAdoptsTrueAndKeepsOtherValues() async throws {
        let url = try file()
        let document = "{\"schemaVersion\":1,\"preferences\":{\"theme\":\"night\",\"showProjectNames\":false,\"language\":\"en\"}}"
        try Data(document.utf8).write(to: url)
        let store = try SettingsStore(url: url), snapshot = await store.snapshot()
        XCTAssertTrue(snapshot.preferences.openAtLogin); XCTAssertEqual(snapshot.preferences.theme, .night)
        XCTAssertFalse(snapshot.preferences.showProjectNames); XCTAssertEqual(snapshot.preferences.language, .english)
        XCTAssertFalse(snapshot.preferences.notifications.optedIn)
        XCTAssertEqual(try String(contentsOf: url), document) // Reading an older document does not rewrite it.
    }
    func testExplicitFalseV1LoadRoundTripAndRestartStayFalse() async throws {
        let url = try file()
        try Data("{\"schemaVersion\":1,\"preferences\":{\"openAtLogin\":false}}".utf8).write(to: url)
        let store = try SettingsStore(url: url), loaded = await store.snapshot()
        XCTAssertFalse(loaded.preferences.openAtLogin)
        try await store.update { $0.theme = .day }
        let restarted = try SettingsStore(url: url), snapshot = await restarted.snapshot()
        XCTAssertFalse(snapshot.preferences.openAtLogin); XCTAssertEqual(snapshot.preferences.theme, .day)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(envelope["schemaVersion"] as? Int, 1)
        let values = try XCTUnwrap(envelope["preferences"] as? [String: Any])
        XCTAssertEqual(values["openAtLogin"] as? Bool, false)
        for forbidden in ["login", "observedState", "requestedEnabled", "requiresApproval", "serviceState"] { XCTAssertNil(values[forbidden]) }
        let roundTrip = try JSONDecoder().decode(SettingsPreferences.self, from: JSONEncoder().encode(snapshot.preferences))
        XCTAssertFalse(roundTrip.openAtLogin)
    }
    func testMalformedPresentChoicesFailClosedAndRemainUntouched() throws {
        let url = try file()
        for value in ["null", "0", "1", "\"false\"", "\"true\"", "{}", "[]"] {
            let data = Data("{\"schemaVersion\":1,\"preferences\":{\"openAtLogin\":\(value)}}".utf8)
            try data.write(to: url)
            XCTAssertThrowsError(try SettingsStore(url: url), value)
            XCTAssertEqual(try Data(contentsOf: url), data)
            XCTAssertThrowsError(try JSONDecoder().decode(SettingsPreferences.self, from: Data("{\"openAtLogin\":\(value)}".utf8)))
        }
    }
    func testSettingsAndOnboardingKeepChoiceSeparateFromEveryObservedState() throws {
        for observed in [LoginServiceState.notRegistered, .requiresApproval, .unavailable, .enabled] {
            for requested in [false, true] {
                var preferences = SettingsPreferences(); preferences.openAtLogin = requested
                var context = SettingsPageContext(); context.capabilities.login = observed
                let projected = LoginSetting(preferences: preferences, capabilities: context.capabilities)
                XCTAssertEqual(projected.requestedEnabled, requested); XCTAssertEqual(projected.observedState, observed)
                let row = try XCTUnwrap(SettingsCatalogue.rows(preferences: preferences, context: context).first { $0.key == .login })
                XCTAssertEqual(row.value, .login(projected)); XCTAssertEqual(row.availability, .available)
                XCTAssertEqual(row.title, LoginSetting.title)
                let options = OnboardingOptions(preferences: preferences)
                XCTAssertEqual(options.openAtLogin, requested)
                XCTAssertEqual(options.loginSetting(capabilities: context.capabilities), projected)
                XCTAssertEqual(context.capabilities.login, observed)
            }
        }
    }
    func testLoginRequestsRemainPureIntentsAndUnavailableRemainsUnavailable() {
        for observed in [LoginServiceState.notRegistered, .requiresApproval, .unavailable, .enabled] {
            var capabilities = SettingsCapabilities(); capabilities.login = observed
            for requested in [false, true] {
                XCTAssertEqual(capabilities.loginRequest(enabled: requested), observed == .unavailable ? nil : .setLoginEnabled(requested))
                XCTAssertEqual(capabilities.login, observed)
            }
        }
    }
    func testOnboardingCanUntickAndPersistCanonicalChoiceWithoutChangingProgressOrConsent() async throws {
        let store = try SettingsStore(url: file())
        let initial = await store.snapshot()
        var options = OnboardingOptions(preferences: initial.preferences)
        XCTAssertTrue(options.openAtLogin)
        options.openAtLogin = false
        let draft = options
        let updated = try await store.update(expectedRevision: initial.revision) { draft.apply(to: &$0) }
        XCTAssertFalse(updated.preferences.openAtLogin)
        XCTAssertEqual(updated.preferences.onboarding, initial.preferences.onboarding)
        XCTAssertEqual(updated.preferences.notifications, initial.preferences.notifications)
        XCTAssertEqual(updated.preferences.showProjectNames, initial.preferences.showProjectNames)
        var replayed = updated.preferences
        replayed.onboarding.next(); replayed.onboarding.replay()
        XCTAssertFalse(OnboardingOptions(preferences: replayed).openAtLogin)
        var capabilities = SettingsCapabilities(); capabilities.login = .requiresApproval
        XCTAssertEqual(draft.loginSetting(capabilities: capabilities).observedState, .requiresApproval)
    }
    func testFailedTransactionDoesNotReplaceExplicitOptOut() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        try await store.update { $0.openAtLogin = false }
        let before = try Data(contentsOf: url)
        do {
            try await store.update { $0.openAtLogin = true; $0.redBelow = 17 }
            XCTFail("Invalid edit should fail before commit")
        } catch { XCTAssertEqual(error as? SettingsError, .invalidPreference) }
        let snapshot = await store.snapshot()
        XCTAssertFalse(snapshot.preferences.openAtLogin); XCTAssertEqual(try Data(contentsOf: url), before)
    }
}
