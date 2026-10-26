// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanSettings

@MainActor final class BehaviorEditorTests: XCTestCase {
    private func file() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-behavior-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("preferences.json")
    }
    private func context(_ ids: [String] = ["a","b","c"]) -> SettingsPageContext {
        var result = SettingsPageContext()
        result.subscriptions = ids.map { .init(id: $0, name: .init("Plan " + $0, "套餐 " + $0), vendor: "Same vendor") }
        return result
    }
    func testBehaviorChoicesPersistAndFeedExistingDockAndOpeningConsumers() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        let editor = SettingsEditor(store: store, context: context())
        await editor.reload()
        var receipts = [SettingsSnapshot]()
        editor.onCommit = { snapshot, _ in receipts.append(snapshot) }
        let edits: [SettingsB21Edit] = [.showDock(false), .autoHide(false), .reveal(300), .magnification(.strong),
            .fullscreen(true), .activeDisplay(false), .dockEdge(.left), .menuDisplay(.twoWindows), .language(.english),
            .opening(.hold), .countdown(150), .automaticUpdates(false), .readerConsent(.gemini,true), .login(false)]
        for edit in edits { try await editor.commit(edit) }
        XCTAssertEqual(receipts.count, edits.count)
        XCTAssertEqual(receipts.last?.revision, UInt64(edits.count))
        let restarted = try SettingsStore(url: url), p = await restarted.snapshot().preferences
        XCTAssertFalse(p.showDock); XCTAssertFalse(p.autoHide); XCTAssertEqual(p.dockEdge, .left)
        XCTAssertEqual(p.revealMilliseconds, 300); XCTAssertEqual(p.magnification, .strong)
        XCTAssertTrue(p.showOverFullscreen); XCTAssertFalse(p.followActiveDisplay)
        XCTAssertEqual(p.menuDisplay, .twoWindows); XCTAssertEqual(p.language, .english)
        XCTAssertFalse(p.automaticUpdates); XCTAssertFalse(p.openAtLogin); XCTAssertTrue(p.readerConsent.gemini)
        XCTAssertFalse(p.readerConsent.cursor)

        var environment = SettingsEnvironment(); environment.fullscreen = true
        var effective = EffectiveSettings(p, environment: environment)
        XCTAssertEqual(effective.opening, .quick); XCTAssertEqual(effective.revealSeconds, 0.3)
        var presence = DockPresence(); presence.pointer = .wake
        var reducer = DockVisibilityState(policy: effective.visibilityPolicy)
        XCTAssertEqual(try reducer.step(effective.applying(to: presence), at: 0).state, .suppressed(.userHidden))
        try await editor.commit(.showDock(true)); let restored = editor.snapshot!.preferences
        environment.macOSMajor = 26; environment.entranceAccepted = true
        effective = .init(restored, environment: environment)
        XCTAssertEqual(effective.ignitionSeconds!, 0.65, accuracy: 1e-9)
        XCTAssertEqual(try reducer.step(effective.applying(to: presence), at: 1).state, .expanded)
        environment.reduceMotion = true
        XCTAssertEqual(EffectiveSettings(restored, environment: environment).opening, .quick)
    }
    func testOrderVisibilityAliasAndDisconnectedPreferencesShareOneStore() async throws {
        let store = try SettingsStore(url: file())
        try await store.update {
            $0.subscriptions = .init(order: ["a","absent","b"], hiddenIDs: ["ghost"])
            $0.subscriptionSettings["b"] = .init(alias: "Original", percentagePin: .week)
        }
        let editor = SettingsEditor(store: store, context: context()); await editor.reload()
        try await editor.commit(.moveSubscription("c", to: 0, expectedOrder: ["a","b","c"]))
        try await editor.commit(.visible("b",false))
        var draft = AliasDraft(subscriptionID: "b", committed: "Original")
        draft.input("工", composing: true)
        do { try await editor.commit(.alias(draft)); XCTFail("composed alias accepted") } catch {}
        draft.input(" 工作 ", composing: false); try await editor.commit(.alias(draft))
        let p = editor.snapshot!.preferences
        XCTAssertEqual(try p.presentedSubscriptionIDs(["a","b","c"]), ["c","a"])
        XCTAssertEqual(try p.presentedSubscriptionIDs(["a","b","c"], includingHidden: true), ["c","a","b"])
        XCTAssertEqual(p.subscriptionSettings["b"]?.alias, "工作")
        XCTAssertEqual(p.subscriptionSettings["b"]?.percentagePin, .week)
        XCTAssertTrue(p.subscriptions.hiddenIDs.contains("ghost"))
        editor.update(context: context(["a","absent","b","c"]))
        XCTAssertEqual(try p.presentedSubscriptionIDs(["a","absent","b","c"], includingHidden: true), ["c","absent","a","b"])
        let revision = editor.snapshot!.revision
        do { try await editor.commit(.moveSubscription("a", to: 0, expectedOrder: ["c","a","b"])); XCTFail("stale drag accepted") }
        catch { XCTAssertEqual(error as? SettingsEditorError, .staleContext) }
        XCTAssertEqual(editor.snapshot?.revision, revision)
        try await editor.commit(.resetOrder)
        XCTAssertEqual(try editor.snapshot!.preferences.presentedSubscriptionIDs(["a","absent","b","c"], includingHidden: true), ["a","absent","b","c"])
        XCTAssertTrue(editor.snapshot!.preferences.subscriptions.hiddenIDs.contains("b"))
    }
    func testLoginAndHintRequestsFollowPersistenceAndNeverFakeObservedState() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        try await store.update { $0.helpHints = .init(seen: Set(FirstUseHintKind.allCases), opens: 2, reveals: 2) }
        var ctx = context(); ctx.capabilities.login = .unavailable
        let editor = SettingsEditor(store: store, context: ctx); await editor.reload()
        var requests = [SettingsHostRequest]()
        editor.onHostRequest = { request in
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertEqual(request.revision, editor.snapshot?.revision)
            requests.append(request)
        }
        try await editor.commit(.login(false)); XCTAssertTrue(requests.isEmpty)
        ctx.capabilities.login = .notRegistered; editor.update(context: ctx)
        try await editor.commit(.login(true))
        XCTAssertEqual(requests.last?.intent, .action(.setLoginEnabled(true)))
        XCTAssertEqual(editor.context.capabilities.login, .notRegistered)
        ctx.capabilities.login = .requiresApproval; editor.update(context: ctx)
        let count = requests.count
        try await editor.commit(.login(true)); XCTAssertEqual(requests.count, count)
        try await editor.commit(.login(false))
        XCTAssertEqual(requests.last?.intent, .action(.setLoginEnabled(false)))
        try await editor.commit(.resetHints)
        XCTAssertEqual(requests.last?.intent, .action(.resetHelpHints))
        XCTAssertEqual(editor.snapshot?.preferences.helpHints, FirstUseHintPreferences())
        XCTAssertEqual(FirstUseHintKind.allCases.count, 9)
        let after = requests.count
        await editor.reload(); editor.update(environment: .init()); editor.update(context: ctx)
        XCTAssertEqual(requests.count, after, "restoration/observation is not a user-service request")
    }
    func testShortcutObservationBelongsToItsExactChordAndLocalMatchingSurvivesDenial() async throws {
        let store = try SettingsStore(url: file()), p = SettingsPreferences()
        var ctx = context()
        ctx.shortcutObservations = [.init(action: .openCockpit, chord: p.openShortcut, registration: .registered)]
        let editor = SettingsEditor(store: store, context: ctx); await editor.reload()
        var requests = [SettingsHostRequest](); editor.onHostRequest = { requests.append($0) }
        let chord = ShortcutChord("K", modifiers: [.command,.shift])
        try await editor.commit(.shortcut(.openCockpit,chord))
        XCTAssertEqual(requests.last?.intent, .shortcutPreferencesChanged(openCockpit: chord, toggleDock: p.dockShortcut))
        let saved = editor.snapshot!.preferences
        XCTAssertEqual(ctx.shortcutPolicy(preferences: saved).openRegistration, .notRequested)
        for state in [ShortcutRegistration.conflict, .denied, .unavailable] {
            ctx.shortcutObservations = [.init(action: .openCockpit, chord: chord, registration: state)]
            let policy = ctx.shortcutPolicy(preferences: saved)
            XCTAssertNil(policy.action(for: chord, preferences: saved, global: true))
            XCTAssertEqual(policy.action(for: chord, preferences: saved, global: false), .openCockpit)
            XCTAssertNil(policy.action(for: chord, preferences: saved, global: false, composing: true))
        }
        let revision = editor.snapshot!.revision, count = requests.count
        do { try await editor.commit(.shortcut(.openCockpit,p.dockShortcut)); XCTFail("duplicate shortcut accepted") } catch {}
        XCTAssertEqual(editor.snapshot?.revision, revision); XCTAssertEqual(requests.count, count)
    }
    func testFailedWritesAndStaleRevisionsEmitNoHostIntent() async throws {
        let url = try file(), store = try SettingsStore(url: url), editor = SettingsEditor(store: store)
        await editor.reload()
        var requests = 0; editor.onHostRequest = { _ in requests += 1 }
        try await store.update { $0.language = .english }
        do { try await editor.commit(.login(false)); XCTFail("stale edit accepted") }
        catch { XCTAssertEqual(error as? SettingsError, .staleRevision) }
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        do { try await editor.commit(.resetHints); XCTFail("failed write accepted") } catch {}
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(editor.snapshot?.preferences.language, .english)
    }
    func testAutomaticUpdatePreferenceIsAdditiveStrictAndDoesNotGrantServiceAvailability() throws {
        let decoder = JSONDecoder()
        let missing = try decoder.decode(SettingsPreferences.self, from: Data("{}".utf8))
        XCTAssertTrue(missing.automaticUpdates); XCTAssertTrue(missing.openAtLogin)
        let off = try decoder.decode(SettingsPreferences.self, from: Data(#"{"automaticUpdates":false,"openAtLogin":false}"#.utf8))
        XCTAssertFalse(off.automaticUpdates); XCTAssertFalse(off.openAtLogin)
        for raw in ["null","1",#""false""#] {
            XCTAssertThrowsError(try decoder.decode(SettingsPreferences.self, from: Data("{\"automaticUpdates\":\(raw)}".utf8)))
        }
        XCTAssertFalse(SettingsCapabilities().updateServiceAvailable)
        XCTAssertThrowsError(try SettingsB21Edit(key: .captureHiding, value: "true"))
        XCTAssertThrowsError(try SettingsB21Edit(key: .notificationConsent, value: "true"))
        XCTAssertThrowsError(try SettingsB21Edit(key: .optionalReaders, value: "true", subscriptionID: "codex"))
        let rows = try SettingsCatalogue.rows(preferences: missing, context: .init(), query: "自动检查更新")
        XCTAssertEqual(rows.map(\.key), [.automaticUpdates])
        XCTAssertEqual(rows.first?.paneID, "general")
    }
}
