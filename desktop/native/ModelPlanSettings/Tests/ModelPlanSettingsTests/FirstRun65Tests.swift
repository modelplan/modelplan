// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

final class FirstRun65Tests: XCTestCase {
    private func file() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-first65-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }; return dir.appendingPathComponent("preferences.json")
    }
    func testCurrentFlowIsOnePageWithoutTourOrPracticeAndReaderLoginChoicesAreIndependent() throws {
        XCTAssertEqual(OnboardingDefinition.task65.steps.count, 1)
        XCTAssertEqual(OnboardingDefinition.task65.steps[0].capabilities, [])
        XCTAssertEqual(OnboardingState().step, .setup)
        for language in SettingsLanguage.allCases { for count in [0,1,6] {
            var p = SettingsPreferences(); p.language = language
            var c = SettingsPageContext()
            c.subscriptions = (0..<count).map { .init(id: "s\($0)", name: .init("Sample \($0)", "样本\($0)")) }
            c.readerObservations = [.codex: .detected, .claude: .denied]
            let page = try FirstRunPage(preferences: p, context: c)
            XCTAssertEqual(page.subscriptions.count, count); XCTAssertTrue(page.login.requestedEnabled)
            XCTAssertEqual(page.login.observedState, .notRegistered)
            XCTAssertEqual(page.loginSubtitle.value(language), language == .english ? "You can turn this off in Settings" : "可随时在设置里关闭")
            XCTAssertEqual(page.readers.filter { $0.consent != nil }.map(\.consent), [false,false])
            XCTAssertEqual(page.readers.first { $0.id == .claude }?.observation, .denied)
        }}
    }
    func testDoneAndSeeWhatsHereCommitBeforeTypedEffectsForBothHosts() async throws {
        for host in [FirstRunHost.popup,.standalone] { for action in [FirstRunAction.done,.seeWhatsHere] {
            let url = try file(), store = try SettingsStore(url: url), initial = await store.snapshot()
            var options = OnboardingOptions(preferences: initial.preferences); options.openAtLogin = false; options.readerConsent.gemini = true
            var caps = SettingsCapabilities(); caps.login = .enabled
            let result = try await store.completeFirstRun(options: options, action: action, host: host, capabilities: caps, expectedRevision: initial.revision)
            XCTAssertTrue(result.snapshot.preferences.onboarding.completed)
            XCTAssertEqual(result.snapshot.preferences.onboarding.step, .setup)
            XCTAssertFalse(result.snapshot.preferences.openAtLogin); XCTAssertTrue(result.snapshot.preferences.readerConsent.gemini)
            XCTAssertFalse(result.snapshot.preferences.readerConsent.cursor); XCTAssertFalse(result.snapshot.preferences.notifications.optedIn)
            XCTAssertEqual(result.login.request, .setLoginEnabled(false)); XCTAssertEqual(result.login.observedState, .enabled)
            let expected: [FirstRunEffect] = action == .done ? (host == .popup ? [.closeFirstRunPopup,.revealDock] : [.returnToSettings]) : (host == .popup ? [.closeFirstRunPopup,.openCockpit,.latchOptionHelp] : [.openCockpit,.latchOptionHelp])
            XCTAssertEqual(result.effects, expected)
            let restart = try SettingsStore(url: url), restored = await restart.snapshot()
            XCTAssertTrue(restored.preferences.onboarding.completed); XCTAssertFalse(restored.preferences.openAtLogin)
            XCTAssertTrue(restored.preferences.readerConsent.gemini)
            var replay = restored.preferences; replay.onboarding.replay()
            XCTAssertFalse(replay.onboarding.completed); XCTAssertFalse(replay.openAtLogin); XCTAssertTrue(replay.readerConsent.gemini)
        }}
    }
    func testSameOptionMapLatchAndReleaseDoNotRequireAnotherMapOrWindowEffects() {
        var help = OptionHelpState(); XCTAssertFalse(help.visible)
        help.optionChanged(true); XCTAssertTrue(help.visible)
        help.latchFromFirstRun(); help.optionChanged(false); XCTAssertTrue(help.visible)
        help.release(); XCTAssertFalse(help.visible); XCTAssertFalse(help.latched)
        help.optionChanged(true); help.release(); XCTAssertFalse(help.visible)
    }
    func testFailedOrStalePersistenceProducesNoCompletionOrLoginEffects() async throws {
        let url = try file(), store = try SettingsStore(url: url), initial = await store.snapshot()
        let options = OnboardingOptions(preferences: initial.preferences)
        try await store.update { $0.openAtLogin = false }
        do {
            _ = try await store.completeFirstRun(options: options, action: .seeWhatsHere, host: .popup, capabilities: .init(), expectedRevision: initial.revision)
            XCTFail("Stale completion must not return effects")
        } catch { XCTAssertEqual(error as? SettingsError, .staleRevision) }
        let snapshot = await store.snapshot(); XCTAssertFalse(snapshot.preferences.onboarding.completed); XCTAssertFalse(snapshot.preferences.openAtLogin)
        let brokenURL = try file(), broken = try SettingsStore(url: brokenURL)
        try FileManager.default.createDirectory(at: brokenURL, withIntermediateDirectories: true)
        do {
            _ = try await broken.completeFirstRun(options: options, action: .done, host: .standalone, capabilities: .init(), expectedRevision: 0)
            XCTFail("Failed rename must not return effects")
        } catch {}
        let unchanged = await broken.snapshot(); XCTAssertFalse(unchanged.preferences.onboarding.completed); XCTAssertEqual(unchanged.revision, 0)
    }
    func testLegacyFinishedAndUnfinishedProgressSafelyAdoptSinglePageKeepingFalseChoice() async throws {
        for completed in [false,true] {
            let url = try file(), raw = "{\"schemaVersion\":1,\"preferences\":{\"openAtLogin\":false,\"onboarding\":{\"step\":3,\"completed\":\(completed)}}}"
            try Data(raw.utf8).write(to: url)
            let store = try SettingsStore(url: url), snapshot = await store.snapshot()
            XCTAssertEqual(snapshot.preferences.onboarding.step, .setup); XCTAssertEqual(snapshot.preferences.onboarding.completed, completed)
            XCTAssertFalse(snapshot.preferences.openAtLogin); XCTAssertEqual(snapshot.preferences.readerConsent, .init())
            XCTAssertTrue(snapshot.preferences.helpHints.seen.isEmpty); XCTAssertEqual(try String(contentsOf: url), raw)
        }
    }
    func testReaderChoicesPersistOnlyAllowedConsentWithoutClaimingReaderActivation() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        try await store.update { $0.readerConsent.cursor = true; $0.openAtLogin = false }
        let restart = try SettingsStore(url: url), snapshot = await restart.snapshot()
        let rows = ReaderSetting.project(consent: snapshot.preferences.readerConsent, observations: [:])
        XCTAssertTrue(rows.allSatisfy { $0.observation == .unknown })
        XCTAssertEqual(rows.first { $0.id == .cursor }?.consent, true)
        XCTAssertFalse(snapshot.preferences.openAtLogin); XCTAssertFalse(snapshot.preferences.notifications.optedIn)
        XCTAssertEqual(try JSONDecoder().decode(ReaderConsent.self, from: Data("{}".utf8)), .init())
        XCTAssertThrowsError(try JSONDecoder().decode(ReaderConsent.self, from: Data("{\"cursor\":\"true\"}".utf8)))
    }
    func testHintStatePersistsAndResetKeepsLoginConsentAndCompletedFirstRun() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        try await store.update { p in
            p.openAtLogin = false; p.readerConsent.cursor = true; p.onboarding.next()
            p.helpHints = .init(seen: Set(FirstUseHintKind.allCases), cockpitOpens: 2, hasPinned: true)
        }
        let restart = try SettingsStore(url: url), loaded = await restart.snapshot()
        XCTAssertEqual(loaded.preferences.helpHints.seen.count, 8)
        let reset = try await restart.resetFirstUseHints(expectedRevision: loaded.revision)
        XCTAssertEqual(reset.preferences.helpHints, .init()); XCTAssertFalse(reset.preferences.openAtLogin)
        XCTAssertTrue(reset.preferences.readerConsent.cursor); XCTAssertTrue(reset.preferences.onboarding.completed)
    }
    func testLoginRequestsOnlyFollowSuccessfulExplicitCommitsNotSystemObservationOrRestore() async throws {
        let store = try SettingsStore(url: file())
        for state in [LoginServiceState.notRegistered,.requiresApproval,.unavailable,.enabled] {
            XCTAssertNil(LoginServicePolicy.request(choice: true, observed: state, reason: .systemObservation))
            XCTAssertNil(LoginServicePolicy.request(choice: true, observed: state, reason: .restoration))
        }
        var caps = SettingsCapabilities(); caps.login = .notRegistered
        let saved = try await store.commitOpenAtLogin(true, capabilities: caps, expectedRevision: 0)
        XCTAssertEqual(saved.request, .setLoginEnabled(true)); XCTAssertEqual(saved.observedState, .notRegistered)
        caps.login = .requiresApproval
        let pending = try await store.commitOpenAtLogin(true, capabilities: caps, expectedRevision: saved.revision)
        XCTAssertNil(pending.request); XCTAssertEqual(pending.observedState, .requiresApproval)
        caps.login = .unavailable
        let unavailable = try await store.commitOpenAtLogin(false, capabilities: caps, expectedRevision: pending.revision)
        XCTAssertNil(unavailable.request); XCTAssertFalse(unavailable.snapshot.preferences.openAtLogin)
        XCTAssertEqual(unavailable.observedState, .unavailable)
    }
}
