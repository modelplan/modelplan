// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
@testable import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor G352Engine: EngineClient {
    let context = EngineDeliveryContext(sessionID: "g352", floor: .init(storeEpoch: "g352", generation: 1), revision: 1)
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext { context }
    func retry() async throws -> EngineDeliveryContext { context }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g352")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class G352SettingsNoticeRenderTests: XCTestCase {
    /// G3-52 evidence: Settings and the widget menu while macOS hides the status item. Render-only; the wording is pinned in StatusItemLaunchTests.
    func testG352SettingsShowsTheHiddenIconGuidance() async throws {
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let output = root.appendingPathComponent("dock-instrument-checks/dock-visual/g3-52", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for locale in ["en", "zh-CN"] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g352-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: profile) }
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
            let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), makeClient: { _, _ in G352Engine() }, activateSettings: {})
            await app.prepare()
            defer { app.removeStatusItem(); app.composition.dock.close() }
            app.installStatusItem(); app.renderMenu()
            app.statusItemVisibility = { false }
            app.checkStatusItemVisibility()
            XCTAssertTrue(app.statusItemHidden)
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.settingsHost.present(paneID: "general", origin: .userInitiated)
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let content = try XCTUnwrap(window.contentView)
            content.layoutSubtreeIfNeeded(); window.displayIfNeeded()
            let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
            content.cacheDisplay(in: content.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("settings-\(locale).png"))
            let notice = try XCTUnwrap(app.settingsHost.application.editor.context.statusItemNotice)
            let menuTitle = app.composition.dock.menu().items.first?.title ?? ""
            try "settings notice (\(locale)): \(notice.value(locale == "en" ? .english : .chinese))\nwidget menu first item: \(menuTitle)\n".write(to: output.appendingPathComponent("text-\(locale).txt"), atomically: true, encoding: .utf8)
        }
    }
}
