// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

final class FirstRunFoundationConsentTests: XCTestCase {
    func testNonRetryableSaveErrorsDoNotSuggestAnIdenticalRetry() {
        for error in [FoundationPreferenceError.engineOwnedConsent, .recoveryRequired, .invalidLocation, .requiresFoundationStore, .durabilityUncertain] {
            for language in SettingsLanguage.allCases {
                let message = FirstRunSaveError.message(error, language: language)
                XCTAssertFalse(message.localizedCaseInsensitiveContains("try again"))
                XCTAssertFalse(message.contains("重试"))
            }
        }
        XCTAssertTrue(FirstRunSaveError.message(SettingsError.staleRevision, language: .english).contains("try again"))
        XCTAssertTrue(FirstRunSaveError.message(FoundationPreferenceError.engineOwnedConsent, language: .english).contains("engine"))
    }

    func testCheckedReaderDoesNotBlockFoundationFirstRunOrCreateConsent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-foundation-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for product in [FoundationSettingsMigration.ProductIdentity.official, .community] {
            let profile = root.appendingPathComponent(UUID().uuidString)
            let store = try SettingsStore(foundationAt: profile, product: product)
            let initial = await store.snapshot()
            var options = OnboardingOptions(preferences: initial.preferences)
            options.readerConsent.gemini = true
            options.openAtLogin = false
            let result = try await store.completeFirstRun(options: options, action: .done, host: .popup, capabilities: .init(), expectedRevision: initial.revision)
            XCTAssertTrue(result.snapshot.preferences.onboarding.completed)
            XCTAssertFalse(result.snapshot.preferences.openAtLogin)
            XCTAssertEqual(result.snapshot.preferences.readerConsent, ReaderConsent(), "The foundation store must not grant or persist engine-owned consent")
            XCTAssertEqual(result.effects, [.closeFirstRunPopup, .revealDock])
            let location = try FoundationPreferenceLocation(applicationSupport: profile, product: product)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: location.target)) as? [String: Any])
            XCTAssertNil((object["settings"] as? [String: Any])?["readerConsent"])
            let reopened = try SettingsStore(foundationAt: profile, product: product)
            let persisted = await reopened.snapshot()
            XCTAssertTrue(persisted.preferences.onboarding.completed)
            XCTAssertEqual(persisted.preferences.readerConsent, ReaderConsent())
        }
    }
}
