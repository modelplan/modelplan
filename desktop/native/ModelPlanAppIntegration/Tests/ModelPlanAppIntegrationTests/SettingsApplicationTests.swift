// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanSettings
import ModelPlanInstruments
@testable import ModelPlanAppIntegration

@MainActor final class SettingsApplicationTests: XCTestCase {
    private func file() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("app-settings-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("preferences.json")
    }

    func testSavedThresholdFeedsBothDockAndActualSubscriptionConsumer() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        try await store.update { $0.redBelow = 16 }
        let restored = try SettingsStore(url: url)
        let coordinator = SettingsApplicationCoordinator(store: restored) { _ in }
        await coordinator.reload()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var dockInput = DockInstrumentInput(id: "sample", name: "Synthetic", windows: [
            .init(id: "q", period: .fiveHour, label: "5h", remainingPercent: 20,
                  resetsAt: now.addingTimeInterval(3600), durationSeconds: 18000)])
        dockInput.dataState = .fresh
        let input = SubscriptionNowInput(id: "sample", header: nil, windows: [
            .init(id: "q", period: .fiveHours, remaining: 20, resetsAt: now.addingTimeInterval(3600))])
        for threshold in [16,25] {
            if threshold == 25 { try await coordinator.commit(.redBelow(25)) }
            let application = try XCTUnwrap(coordinator.latest)
            let before = try Data(contentsOf: url)
            let detail = application.subscriptionNowSnapshot(inputs: [input], scope: .subscription("sample"), at: now, calendar: Calendar(identifier: .gregorian))
            let row = try XCTUnwrap(detail.accounts.first?.rows.first { $0.id.hasSuffix(".window.q") })
            XCTAssertEqual(row.level, threshold == 16 ? .amber : .critical)
            XCTAssertEqual(detail.accounts.first?.summary.level, row.level)
            XCTAssertEqual(try application.dockReading(for: dockInput, at: now).status, threshold == 16 ? .warning : .critical)
            XCTAssertEqual(application.snapshot.preferences.redBelow, threshold)
            XCTAssertEqual(try Data(contentsOf: url), before, "projection must not rewrite the saved threshold")
            let saved = await restored.snapshot()
            XCTAssertEqual(saved.preferences.redBelow, threshold)
        }
    }
    func testRestoreDoesNotWriteOrEmitAUserCommit() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        var applications = [SettingsApplication]()
        let app = SettingsApplicationCoordinator(store: store) { applications.append($0) }
        await app.reload(); await app.reload()
        XCTAssertEqual(applications.count, 1)
        XCTAssertEqual(applications.first?.reason, .restore)
        XCTAssertEqual(applications.first?.snapshot.revision, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testSuccessfulSaveFeedsActualQuotaProjectionAndPreservesUnrelatedChoices() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        try await store.update { $0.openAtLogin = false; $0.readerConsent.cursor = true }
        var context = SettingsPageContext()
        context.subscriptions = [.init(id: "sample", name: .init("Sample", "示例"))]
        var applications = [SettingsApplication]()
        let app = SettingsApplicationCoordinator(store: store, context: context) { applications.append($0) }
        await app.reload()
        try await app.commit(.percentageMode(.used))
        try await app.commit(.redBelow(20))
        try await app.commit(.showPercentages(false))
        try await app.commit(.percentagePin("sample", .fiveHour))
        let state = try XCTUnwrap(app.latest)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var input = DockInstrumentInput(id: "sample", name: "Sample", windows: [
            .init(id: "short", period: .fiveHour, label: "5h", remainingPercent: 19,
                  resetsAt: now.addingTimeInterval(1000), durationSeconds: 18000),
        ])
        input.dataState = .fresh
        let reading = try state.dockReading(for: input, at: now)
        XCTAssertEqual(reading.readout, "81%")
        XCTAssertEqual(reading.status, .critical)
        XCTAssertEqual(reading.selectedWindowID, "short")
        XCTAssertFalse(state.effective.showPercentages)
        XCTAssertEqual(applications.filter { $0.reason == .commit }.map { $0.snapshot.revision }, [2, 3, 4, 5])
        let restored = try SettingsStore(url: url)
        let preferences = await restored.snapshot().preferences
        XCTAssertFalse(preferences.openAtLogin); XCTAssertTrue(preferences.readerConsent.cursor)
        XCTAssertEqual(preferences.percentageMode, .used)
    }

    func testLateSuccessfulReceiptCannotRegressKnownNewerRevision() async throws {
        let store = try SettingsStore(url: file())
        var applications = [SettingsApplication]()
        let app = SettingsApplicationCoordinator(store: store) { applications.append($0) }
        await app.reload()
        let old = await store.snapshot()
        try await app.commit(.size(.large))
        let before = applications.count
        // A genuine old receipt, delivered late by a suspended caller; no forged snapshot.
        app.editor.onCommit?(old, EffectiveSettings(old.preferences, environment: .init()))
        XCTAssertEqual(applications.count, before)
        XCTAssertEqual(app.latest?.snapshot.revision, 1)
        XCTAssertEqual(app.latest?.effective.size, .large)
    }

    func testEnvironmentAtSameRevisionAppliesWithoutSavingAndDeduplicates() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        var applications = [SettingsApplication]()
        let app = SettingsApplicationCoordinator(store: store) { applications.append($0) }
        await app.reload()
        var environment = SettingsEnvironment()
        environment.reduceMotion = true; environment.increaseContrast = true
        app.update(environment: environment); app.update(environment: environment)
        XCTAssertEqual(applications.count, 2)
        XCTAssertEqual(app.latest?.reason, .environment)
        XCTAssertTrue(app.latest?.effective.reduceMotion == true)
        XCTAssertTrue(app.latest?.effective.increaseContrast == true)
        XCTAssertEqual(app.latest?.snapshot.revision, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testContextCarriesSubscriptionsWithoutInventingPreferenceCommit() async throws {
        let store = try SettingsStore(url: file())
        var applications = [SettingsApplication]()
        let app = SettingsApplicationCoordinator(store: store) { applications.append($0) }
        await app.reload()
        var context = SettingsPageContext()
        context.subscriptions = [.init(id: "sample", name: .init("Sample", "示例"))]
        app.update(context: context)
        XCTAssertEqual(applications.count, 2)
        XCTAssertEqual(app.latest?.reason, .context)
        XCTAssertEqual(app.latest?.context.subscriptions.map(\.id), ["sample"])
        XCTAssertEqual(app.latest?.snapshot.revision, 0)
    }

    func testReentrantEnvironmentChangesAreSerializedAndCoalesced() async throws {
        let store = try SettingsStore(url: file())
        var app: SettingsApplicationCoordinator!
        var applications = [SettingsApplication](), depth = 0, maximumDepth = 0
        app = SettingsApplicationCoordinator(store: store) { state in
            depth += 1; maximumDepth = max(maximumDepth, depth); applications.append(state)
            if state.reason == .restore {
                var environment = SettingsEnvironment(); environment.darkAppearance = true
                app.update(environment: environment)
                environment.reduceMotion = true; app.update(environment: environment)
            }
            depth -= 1
        }
        await app.reload()
        XCTAssertEqual(maximumDepth, 1)
        XCTAssertEqual(applications.count, 2)
        XCTAssertTrue(applications.last?.effective.darkAppearance == true)
        XCTAssertTrue(applications.last?.effective.reduceMotion == true)
    }

    func testFailedWriteDoesNotForwardPreferenceOrCommitReceipt() async throws {
        let url = try file(), store = try SettingsStore(url: url)
        var applications = [SettingsApplication]()
        let app = SettingsApplicationCoordinator(store: store) { applications.append($0) }
        await app.reload()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        do { try await app.commit(.theme(.night)); XCTFail("write accepted") } catch {}
        XCTAssertEqual(applications.count, 1)
        XCTAssertEqual(app.latest?.effective.darkAppearance, false)
        XCTAssertEqual(app.latest?.snapshot.revision, 0)
    }

    func testExternalCommittedTruthRequiresExplicitReloadAndIsNotAUICommit() async throws {
        let store = try SettingsStore(url: file())
        var applications = [SettingsApplication]()
        let app = SettingsApplicationCoordinator(store: store) { applications.append($0) }
        await app.reload()
        try await store.update { $0.size = .small }
        XCTAssertEqual(app.latest?.effective.size, .medium)
        await app.reload()
        XCTAssertEqual(app.latest?.effective.size, .small)
        XCTAssertEqual(app.latest?.snapshot.revision, 1)
        XCTAssertEqual(app.latest?.reason, .restore)
        XCTAssertFalse(applications.contains { $0.reason == .commit })
    }
    func testReentrantAppearanceRevertDoesNotPublishTheSupersededQueuedValue() async throws {
        let store = try SettingsStore(url: file())
        var app: SettingsApplicationCoordinator!
        var applications = [SettingsApplication]()
        app = SettingsApplicationCoordinator(store: store) { state in
            applications.append(state)
            if state.reason == .restore {
                var environment = SettingsEnvironment(); environment.darkAppearance = true
                app.update(environment: environment)
                app.update(environment: .init())
            }
        }
        await app.reload()
        XCTAssertEqual(applications.count, 1)
        XCTAssertFalse(try XCTUnwrap(app.latest).effective.darkAppearance)
        XCTAssertFalse(try XCTUnwrap(app.editor.effective).darkAppearance)
    }

    func testReentrantContextSurvivesAnAppearanceRevert() async throws {
        let store = try SettingsStore(url: file())
        var app: SettingsApplicationCoordinator!
        var applications = [SettingsApplication]()
        app = SettingsApplicationCoordinator(store: store) { state in
            applications.append(state)
            if state.reason == .restore {
                var environment = SettingsEnvironment(); environment.darkAppearance = true
                app.update(environment: environment)
                var context = SettingsPageContext()
                context.subscriptions = [.init(id: "sample", name: .init("Sample", "示例"))]
                app.update(context: context)
                app.update(environment: .init())
            }
        }
        await app.reload()
        XCTAssertEqual(applications.count, 2)
        XCTAssertEqual(app.latest?.reason, .context)
        XCTAssertEqual(app.latest?.context.subscriptions.map(\.id), ["sample"])
        XCTAssertFalse(try XCTUnwrap(app.latest).effective.darkAppearance)
    }

    func testSameRevisionReceiptAfterContextKeepsCurrentContext() async throws {
        let store = try SettingsStore(url: file())
        let app = SettingsApplicationCoordinator(store: store) { _ in }
        await app.reload()
        let receipt = try await app.commit(.size(.large))
        var context = SettingsPageContext()
        context.subscriptions = [.init(id: "new", name: .init("New", "新"))]
        app.update(context: context)
        app.editor.onCommit?(receipt, EffectiveSettings(receipt.preferences, environment: .init()))
        XCTAssertEqual(app.latest?.snapshot.revision, receipt.revision)
        XCTAssertEqual(app.latest?.context.subscriptions.map(\.id), ["new"])
        XCTAssertEqual(app.latest?.effective.size, .large)
    }

}
