// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

@MainActor final class PrivacyEditorTests: XCTestCase {
    private func file() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("settings-privacy-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("preferences.json")
    }
    func testNotificationConsentUsesOneExistingPolicyOnlyAfterPersistence() async throws {
        let url = try file(), store = try SettingsStore(url: url), editor = SettingsEditor(store: store)
        await editor.reload()
        let consumer = SettingsNotificationConsumer()
        var requests = [SettingsHostRequest](), effects = [NotificationPermissionEffect]()
        editor.onHostRequest = { request in
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            requests.append(request)
            effects.append(consumer.committedConsent(request, snapshot: editor.snapshot!))
        }
        XCTAssertFalse(editor.snapshot!.preferences.notifications.optedIn)
        try await editor.commit(.notificationConsent(true))
        guard let effect = effects.last, case .requestAuthorization(let token) = effect else { return XCTFail("missing explicit opt-in intent") }
        XCTAssertEqual(consumer.policy.authorization, .notDetermined)
        XCTAssertEqual(consumer.committedConsent(requests[0], snapshot: editor.snapshot!), .none)
        consumer.receivedAuthorization(.authorized, request: UUID())
        XCTAssertEqual(consumer.policy.authorization, .notDetermined)
        consumer.receivedAuthorization(.denied, request: token)
        XCTAssertEqual(consumer.policy.authorization, .denied)
        let count = requests.count
        await editor.reload(); editor.update(context: .init()); editor.update(environment: .init())
        XCTAssertEqual(requests.count, count)
        try await editor.commit(.notificationConsent(false)); try await editor.commit(.notificationConsent(true))
        XCTAssertEqual(effects.last, NotificationPermissionEffect.none, "denial must not prompt again")
        for kind in NotificationKind.allCases { try await editor.commit(.notification(kind,false)) }
        try await editor.commit(.projectNames(false))
        let restarted = try SettingsStore(url: url), p = await restarted.snapshot().preferences
        XCTAssertTrue(p.notifications.optedIn); XCTAssertTrue(p.notifications.kinds.isEmpty); XCTAssertFalse(p.showProjectNames)
        XCTAssertEqual(requests.count, count + 2, "per-kind/name choices do not request permission")
    }
    func testAllFiveNoticeKindsReuseDedupExpiryRestorationAndHiddenNameRules() async throws {
        let store = try SettingsStore(url: file())
        try await store.update { $0.notifications.optedIn = true; $0.showProjectNames = false }
        let snapshot = await store.snapshot(), now = Date(timeIntervalSince1970: 1_800_000_000)
        let consumer = SettingsNotificationConsumer(policy: .init(authorization: .authorized))
        var accepted = [NotificationDelivery]()
        for kind in NotificationKind.allCases {
            let notice = SettingsNotice(kind: kind, subscriptionID: "opaque-sub", episodeID: kind.rawValue,
                                       beganAt: now, expiresAt: now.addingTimeInterval(60), projectName: "not-for-delivery")
            let first = try XCTUnwrap(consumer.delivery(for: notice, snapshot: snapshot, now: now))
            XCTAssertNil(first.projectName)
            // A failed fake transport is not recorded and can be retried.
            XCTAssertNotNil(consumer.delivery(for: notice, snapshot: snapshot, now: now))
            accepted.append(first); consumer.recordAccepted(notice, snapshot: snapshot, now: now)
            XCTAssertNil(consumer.delivery(for: notice, snapshot: snapshot, now: now))
            let restored = SettingsNotice(kind: kind, subscriptionID: "other", episodeID: "restored",
                beganAt: now, expiresAt: now.addingTimeInterval(60), restored: true)
            XCTAssertNil(consumer.delivery(for: restored, snapshot: snapshot, now: now))
            let expired = SettingsNotice(kind: kind, subscriptionID: "other", episodeID: "expired", beganAt: now.addingTimeInterval(-60), expiresAt: now)
            XCTAssertNil(consumer.delivery(for: expired, snapshot: snapshot, now: now))
        }
        XCTAssertEqual(accepted.count, 5); XCTAssertEqual(consumer.policy.ledger.count, 5)
        let encoded = try JSONEncoder().encode(consumer.policy.ledger)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("not-for-delivery"))
        let restored = SettingsNotificationConsumer(policy: .init(authorization: .authorized,
            ledger: try JSONDecoder().decode(NotificationLedger.self, from: encoded)))
        let duplicate = SettingsNotice(kind: .reset, subscriptionID: "opaque-sub", episodeID: "reset", beganAt: now, expiresAt: now.addingTimeInterval(60))
        XCTAssertNil(restored.delivery(for: duplicate, snapshot: snapshot, now: now))
    }
    func testCacheRequestIsScopedByFakeHostAndNeverResetsPreferencesOrCLIData() async throws {
        let url = try file(), root = url.deletingLastPathComponent(), store = try SettingsStore(url: url)
        try await store.update { $0.subscriptionSettings["sample"] = .init(alias: "Work"); $0.readerConsent.cursor = true }
        let derived = root.appendingPathComponent("fake-app-derived-cache")
        try FileManager.default.createDirectory(at: derived, withIntermediateDirectories: false)
        let cacheFile = derived.appendingPathComponent("thumbnail.bin"), cli = root.appendingPathComponent("fake-cli-history"), ledger = root.appendingPathComponent("notification-ledger.json")
        try Data("derived".utf8).write(to: cacheFile); try Data("CLI-owned".utf8).write(to: cli)
        try JSONEncoder().encode(NotificationLedger()).write(to: ledger)
        let protected = try [url,cli,ledger].map { try Data(contentsOf: $0) }
        let editor = SettingsEditor(store: store); await editor.reload()
        XCTAssertThrowsError(try editor.request(.clearAppCache))
        var ctx = editor.context; ctx.capabilities.appCacheClearAvailable = true; editor.update(context: ctx)
        var commits = 0, clears = 0; editor.onCommit = { _, _ in commits += 1 }
        editor.onHostRequest = { request in
            guard request.intent == .action(.clearAppCache) else { return XCTFail("wrong cache intent") }
            XCTAssertEqual(request.revision, editor.snapshot!.revision)
            do { try FileManager.default.removeItem(at: cacheFile); clears += 1 } catch { XCTFail("fake cache clear failed") }
        }
        try editor.request(.clearAppCache)
        XCTAssertEqual(clears, 1); XCTAssertEqual(commits, 0)
        XCTAssertEqual(try [url,cli,ledger].map { try Data(contentsOf: $0) }, protected)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))
        XCTAssertThrowsError(try SettingsB22Edit(key: .clearCLI, value: "true"))
        XCTAssertThrowsError(try SettingsB22Edit(key: .retention, value: "1"))
    }
    func testFirstRunCommitSharesStoreAndPublishesOneNavigationBatchAfterSave() async throws {
        let store = try SettingsStore(url: file())
        var ctx = SettingsPageContext(); ctx.capabilities.helpMapAvailable = true
        let editor = SettingsEditor(store: store, context: ctx); await editor.reload()
        var map = OptionHelpState(), events = [SettingsHostRequest](), commits = 0
        editor.onCommit = { _, _ in commits += 1 }
        editor.onHostRequest = { request in
            events.append(request)
            if case .firstRunCompleted(let effects, _) = request.intent, effects.contains(.latchOptionHelp) { map.latchFromFirstRun() }
        }
        var options = OnboardingOptions(preferences: editor.snapshot!.preferences)
        options.openAtLogin = false; options.readerConsent.gemini = true
        let completed = try await editor.completeFirstRun(options: options, action: .seeWhatsHere, host: .popup, expectedRevision: 0)
        XCTAssertEqual(completed.effects, [.closeFirstRunPopup,.openCockpit,.latchOptionHelp])
        XCTAssertEqual(commits, 1); XCTAssertEqual(events.count, 1); XCTAssertTrue(map.latched)
        XCTAssertTrue(editor.snapshot!.preferences.onboarding.completed)
        XCTAssertFalse(editor.snapshot!.preferences.openAtLogin); XCTAssertTrue(editor.snapshot!.preferences.readerConsent.gemini)
        XCTAssertTrue(editor.context.readerObservations.isEmpty)
        map.release(); XCTAssertFalse(map.visible)
        do { _ = try await editor.completeFirstRun(options: options, action: .done, host: .popup, expectedRevision: 0); XCTFail("stale completion accepted") }
        catch { XCTAssertEqual(error as? SettingsError, .staleRevision) }
        XCTAssertEqual(events.count, 1)
    }
    func testFailureHasNoFirstRunEffectsAndObserversDoNotReplaceSettingsPresentation() async throws {
        let url = try file(), store = try SettingsStore(url: url), editor = SettingsEditor(store: store)
        var legacy = 0, first = 0, second = 0, events = 0
        editor.onChange = { legacy += 1 }; editor.onHostRequest = { _ in events += 1 }
        let one = editor.observeChanges { first += 1 }, two = editor.observeChanges { second += 1 }
        await editor.reload(); editor.update(context: .init())
        XCTAssertEqual(legacy, 2); XCTAssertEqual(first, 2); XCTAssertEqual(second, 2)
        editor.removeChangeObserver(one); editor.update(environment: .init())
        XCTAssertEqual(first, 2); XCTAssertEqual(second, 3); editor.removeChangeObserver(two)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        do { _ = try await editor.completeFirstRun(options: .init(preferences: editor.snapshot!.preferences), action: .done, host: .popup, expectedRevision: 0); XCTFail("failed save accepted") } catch {}
        XCTAssertEqual(events, 0); XCTAssertFalse(editor.snapshot!.preferences.onboarding.completed)
    }
    func testBilingualAboutLinksAndDiagnosticsStayAllowlisted() throws {
        var context = SettingsPageContext(), p = SettingsPreferences()
        context.about = .init(appVersion: "1.2.3", cliVersion: "/Users/not-a-version")
        context.about.macOSVersion = "26.5.2"; context.about.enabledReaders = [.codex]
        p.subscriptionSettings["account-secret"] = .init(alias: "private-alias"); p.readerConsent.gemini = true
        let text = context.about.diagnosticText
        for secret in ["/Users", "account-secret", "private-alias", "gemini"] { XCTAssertFalse(text.contains(secret)) }
        XCTAssertTrue(text.contains("cli=unknown"))
        let en = try SettingsCatalogue.rows(preferences: p, context: context, query: "Methodology")
        let zh = try SettingsCatalogue.rows(preferences: p, context: context, query: "方法说明")
        XCTAssertEqual(en.map(\.key), [.methodologyLink]); XCTAssertEqual(zh.map(\.key), [.methodologyLink])
        for link in SettingsPublicLink.allCases { XCTAssertEqual(link.url.scheme, "https"); XCTAssertNil(link.url.query) }
        XCTAssertEqual(SettingsPublicLink.feedback.url, SettingsAbout.feedbackURL)
    }
}
