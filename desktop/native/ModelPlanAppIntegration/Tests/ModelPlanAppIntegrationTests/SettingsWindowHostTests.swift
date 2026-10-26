// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class TestSettingsSurface: SettingsWindowSurface {
    var prepared = 0, hidden = 0
    var shown: [String?] = []
    var preparation: (() async -> Void)?
    var onShow: (() -> Void)?
    func prepare() async { prepared += 1; await preparation?() }
    func show(paneID: String?) { shown.append(paneID); onShow?() }
    func hide() { hidden += 1 }
}

@MainActor final class SettingsWindowHostTests: XCTestCase {
    private func application() throws -> SettingsApplicationCoordinator {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-host-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("preferences.json"))) { _ in }
    }

    func testEntryPointsReuseOneEditorAndLazySurface() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var builds = 0
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }) { editor in
            XCTAssertTrue(editor === app.editor); builds += 1; return surface
        }
        XCTAssertEqual(builds, 0)
        await host.present(paneID: "dock")
        try await app.commit(.size(.large))
        await host.present(paneID: "appearance")
        XCTAssertEqual(builds, 1); XCTAssertEqual(surface.prepared, 2)
        XCTAssertEqual(surface.shown.compactMap { $0 }, ["dock", "appearance"])
        XCTAssertEqual(app.editor.effective?.size, .large)
        let item = host.menuItem(title: "Settings…")
        XCTAssertTrue(item.target === host); XCTAssertNotNil(item.action)
        XCTAssertEqual(item.keyEquivalent, ","); XCTAssertEqual(item.keyEquivalentModifierMask, .command)
    }

    func testBlockedEntryDoesNotLoadOrConstructAWindow() async throws {
        let app = try application()
        let host = SettingsWindowHost(application: app, canPresent: { false }, environment: { .init() }) { _ in
            XCTFail("ineligible entry constructed a window"); return TestSettingsSurface()
        }
        await host.present()
        XCTAssertNil(app.editor.snapshot)
    }

    func testEligibilityIsRecheckedAfterPreparation() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var allowed = true
        surface.preparation = { allowed = false }
        let host = SettingsWindowHost(application: app, canPresent: { allowed }, environment: { .init() }, makeSurface: { _ in surface })
        await host.present()
        XCTAssertEqual(surface.prepared, 1); XCTAssertTrue(surface.shown.isEmpty)
    }

    func testSuspendRetiresPendingPresentationAndKeepsSingleton() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var host: SettingsWindowHost!
        var builds = 0
        host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }) { _ in builds += 1; return surface }
        surface.preparation = { host.suspend() }
        await host.present()
        XCTAssertTrue(surface.shown.isEmpty); XCTAssertEqual(surface.hidden, 1)
        surface.preparation = nil
        await host.present()
        XCTAssertEqual(builds, 1); XCTAssertEqual(surface.shown.count, 1)
    }

    func testLatestConcurrentEntryWinsWithoutOrderingAnOldPane() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var waiting: CheckedContinuation<Void, Never>?
        let reached = expectation(description: "first preparation suspended")
        surface.preparation = {
            if surface.prepared == 1 { await withCheckedContinuation { waiting = $0; reached.fulfill() } }
        }
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, makeSurface: { _ in surface })
        let first = Task { await host.present(paneID: "general") }
        await fulfillment(of: [reached], timeout: 2)
        await host.present(paneID: "appearance")
        waiting?.resume(); await first.value
        XCTAssertEqual(surface.shown.compactMap { $0 }, ["appearance"])
    }

    func testReadOnlyEnvironmentFeedsSameApplicationWithoutPreferenceCommit() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var environment = SettingsEnvironment(); environment.reduceMotion = true; environment.darkAppearance = true
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { environment }, makeSurface: { _ in surface })
        await host.present()
        XCTAssertTrue(app.latest?.effective.reduceMotion == true)
        XCTAssertTrue(app.latest?.effective.darkAppearance == true)
        XCTAssertEqual(app.latest?.snapshot.revision, 0)
        XCTAssertEqual(app.latest?.reason, .restore)
    }
    func testPreparationCannotLeaveConsumersBehindTheSharedEditor() async throws {
        let app = try application(), surface = TestSettingsSurface()
        surface.preparation = {
            do { _ = try await app.editor.store.update { $0.size = .small } }
            catch { XCTFail("preparation write failed: \(error)") }
            await app.editor.reload()
        }
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, makeSurface: { _ in surface })
        await host.present()
        XCTAssertEqual(app.editor.effective?.size, .small)
        XCTAssertEqual(app.latest?.effective.size, .small)
        XCTAssertEqual(app.latest?.snapshot.revision, app.editor.snapshot?.revision)
        XCTAssertEqual(surface.shown.count, 1)
    }

    func testMenuAndGearActionsReachTheSameHost() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var builds = 0
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }) { _ in builds += 1; return surface }
        let gear = expectation(description: "gear action shown")
        surface.onShow = { gear.fulfill() }; host.action()
        await fulfillment(of: [gear], timeout: 2)
        let menu = expectation(description: "menu action shown")
        surface.onShow = { menu.fulfill() }
        let item = host.menuItem(title: "Settings…")
        _ = host.perform(try XCTUnwrap(item.action), with: item)
        await fulfillment(of: [menu], timeout: 2)
        XCTAssertEqual(builds, 1); XCTAssertEqual(surface.shown.count, 2)
    }

    func testSuspendAlsoRetiresAnEntryStillQueuedOnTheMainActor() async throws {
        let app = try application(), surface = TestSettingsSurface()
        let unexpected = expectation(description: "suspended queued action ordered a window"); unexpected.isInverted = true
        surface.onShow = { unexpected.fulfill() }
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, makeSurface: { _ in surface })
        host.action(); host.suspend()
        await fulfillment(of: [unexpected], timeout: 0.05)
        XCTAssertNil(app.editor.snapshot)
    }

    func testDefaultUIObservationPreservesAuthoritativeWindowAndEntranceGates() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var environment = SettingsEnvironment(); environment.fullscreen = true; environment.entranceAccepted = true
        app.update(environment: environment)
        let host = SettingsWindowHost(application: app, canPresent: { true }, makeSurface: { _ in surface })
        await host.present()
        XCTAssertTrue(app.editor.environment.fullscreen)
        XCTAssertTrue(app.editor.environment.entranceAccepted)
        XCTAssertFalse(try XCTUnwrap(app.latest).effective.dockAllowed)
    }

}
