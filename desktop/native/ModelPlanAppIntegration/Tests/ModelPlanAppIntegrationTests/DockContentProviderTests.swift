// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class Provider: DockContentProvider {
    var value: DockContent
    var contexts: [DockContentContext] = []
    init(_ value: DockContent) { self.value = value }
    func makeContent(_ context: DockContentContext) -> DockContent { contexts.append(context); return value }
}
@MainActor final class DockContentProviderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func legacy() throws -> JoinedSnapshot {
        let iso = ISO8601DateFormatter()
        let value: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": iso.string(from: now.addingTimeInterval(-10)),
            "validUntil": iso.string(from: now.addingTimeInterval(300)),
            "accounts": [["source": "codex", "observedAt": iso.string(from: now.addingTimeInterval(-5)),
                "subscription": ["subscriptionRef": "synthetic-sub", "status": "verified"],
                "windows": [["kind": "five_hour", "remainingPercent": 75,
                    "observedAt": iso.string(from: now.addingTimeInterval(-5))]]]],
            "subscriptions": [["subscriptionRef": "synthetic-sub", "sources": ["codex"]]]]
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: value))
        var ledger = ExpiryLedger()
        return .make(personal: personal, presentation: PersonalProjection.evaluate(personal, now: now, ledger: &ledger), publication: nil)
    }
    func testDefaultProviderKeepsExistingProjectionAndLegacyFormatting() throws {
        let joined = try legacy(); var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        let facts = CommunityReaderFactsBinding.make(snapshot: joined, diagnostics: diagnostics, capabilities: .init())
        let expected = CommunityDockSnapshot(snapshot: joined, diagnostics: diagnostics, now: now, readerFacts: facts)
        let actual = LegacyDockContentProvider().makeContent(.init(snapshot: joined, diagnostics: diagnostics, now: now, readerFacts: facts))
        XCTAssertFalse(expected.inputs.isEmpty)
        XCTAssertEqual(actual.snapshot.inputs.map(\.id), expected.inputs.map(\.id))
        XCTAssertEqual(actual.snapshot.inputs.first?.windows.first?.remainingPercent, 75)
        XCTAssertEqual(actual.snapshot.subscriptions.map(\.id), expected.subscriptions.map(\.id))
        XCTAssertEqual(actual.snapshot.readerDiagnostics, expected.readerDiagnostics)
        XCTAssertEqual(actual.snapshot.emptyDiagnostic, expected.emptyDiagnostic)
        XCTAssertNil(actual.menuStatusLines); XCTAssertNil(actual.emptyText)
    }
    func testActualHostReadsInjectedContentAndMenuThenClearsWithoutLegacyFallback() async throws {
        _ = NSApplication.shared
        let input = DockInstrumentInput(id: "engine-row", name: "Synthetic engine row", windows: [])
        let row = DockContentRow(input: input, reason: "Engine-only reason", nextStep: "Engine-only next step")
        let provider = Provider(.init(snapshot: .init(inputs: [input], presentationRows: [input.id: row]),
                                      menuStatusLines: ["Engine-only summary"]))
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false, contentProvider: provider)
        defer { host.close() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-provider-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { host.apply($0) }
        await app.reload()
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        host.render(snapshot: try legacy(), diagnostics: diagnostics)
        let menu = host.menu().items.map(\.title).joined(separator: " ")
        XCTAssertTrue(menu.contains("Engine-only summary"))
        XCTAssertTrue(menu.contains("Engine-only reason"))
        XCTAssertFalse(provider.contexts.isEmpty)
        XCTAssertEqual(provider.contexts.last?.now, now)
        XCTAssertEqual(provider.contexts.last?.snapshot?.personal.accounts?.count, 1)
        XCTAssertNil(host.nativePanel)
        provider.value = .init(snapshot: .init(inputs: []), menuStatusLines: [], emptyText: "Engine-only empty")
        host.refreshDockContent()
        XCTAssertFalse(host.menu().items.contains { $0.title.contains("Engine-only reason") || $0.title.contains("Engine-only summary") })
        XCTAssertFalse(host.menu().items.contains { $0.accessibilityIdentifier() == "dock.empty-reader-status-menu" })
        XCTAssertTrue(host.dockView.subviews.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Engine-only empty" })
        XCTAssertNil(host.nativePanel)
    }
    func testDefaultHostAndExplicitDefaultProviderHaveSameMenu() async throws {
        _ = NSApplication.shared
        let implicit = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
        let explicit = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false,
                                            contentProvider: LegacyDockContentProvider())
        defer { implicit.close(); explicit.close() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-default-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) {
            implicit.apply($0); explicit.apply($0)
        }
        await app.reload()
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        let joined = try legacy()
        implicit.render(snapshot: joined, diagnostics: diagnostics); explicit.render(snapshot: joined, diagnostics: diagnostics)
        XCTAssertEqual(implicit.menu().items.map(\.title), explicit.menu().items.map(\.title))
        XCTAssertNil(implicit.nativePanel); XCTAssertNil(explicit.nativePanel)
    }
}
