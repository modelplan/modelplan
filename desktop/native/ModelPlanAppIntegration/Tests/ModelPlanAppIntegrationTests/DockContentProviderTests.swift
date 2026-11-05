// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
@_spi(DockResourceChecks) import ModelPlanDock
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
    func testCardStatusUsesPrototypeCopyInBothLanguages() {
        let input = DockInstrumentInput(id: "example", name: "Example", windows: [])
        let age = now.addingTimeInterval(-37 * 60)
        let cases: [(DockCardReadingState, String, String)] = [
            (.ok, "", ""),
            (.loading, "读取中", "Reading"),
            (.stale, "过期 · 37分钟前", "Stale · 37m ago"),
            (.errorLastGood, "读取失败 · 保留 37分钟前的读数", "Read failed · showing 37m ago"),
            (.error, "需要读取权限", "Reading permission required")
        ]
        for (state, zh, en) in cases {
            let chinese = DockContentRow(input: input, reason: "需要读取权限", nextStep: "", originalObservedAt: age, sourceName: "本地历史", cardReadingState: state)
            let english = DockContentRow(input: input, reason: "Reading permission required", nextStep: "", originalObservedAt: age, sourceName: "Local history", cardReadingState: state)
            XCTAssertEqual(chinese.cardSourceAndAge(at: now, english: false), "本地历史 · 37分钟前")
            XCTAssertEqual(english.cardSourceAndAge(at: now, english: true), "Local history · 37m ago")
            XCTAssertEqual(chinese.cardBadge(at: now, english: false), zh)
            XCTAssertEqual(english.cardBadge(at: now, english: true), en)
        }
    }
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
    func testCockpitOpeningAcknowledgesMenuButNotFaceNotice() async throws {
        _ = NSApplication.shared
        var input = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [])
        input.dataState = .fresh
        var signal = DockSubscriptionSignal(id: input.id); signal.dataState = .fresh
        signal.reset = .init(id: "synthetic-reset", status: .announced, announcedAt: now.addingTimeInterval(-60))
        let provider = Provider(.init(snapshot: .init(inputs: [input]), signals: [signal]))
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false, contentProvider: provider)
        defer { host.close() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("notice-host-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { host.apply($0) }
        await coordinator.reload(); host.setPresentationAllowed(true)
        XCTAssertEqual(host.menuNotice?.shape, .hollow)
        var opened = false; host.showConsole = { opened = true }
        host.perform(NSSelectorFromString("openConsole"))
        XCTAssertTrue(opened); XCTAssertNil(host.menuNotice)
        XCTAssertEqual(DockNoticeProjection.selected(for: signal, at: now)?.shape, .hollow)
    }
    func testSliverPulseRetiresWhenNoticeIsRemoved() throws {
        var signal = DockSubscriptionSignal(id: "synthetic"); signal.dataState = .fresh
        signal.reset = .init(id: "event", status: .announced, announcedAt: now.addingTimeInterval(-60))
        let notice = try XCTUnwrap(DockNoticeProjection.selected(for: signal, at: now))
        let sliver = DockSliverView(frame: .zero)
        try sliver.apply(image: nil, logicalSize: .init(width: 4, height: 100), scale: 1, accessibilityLabel: "Synthetic")
        sliver.noticeMarks = [.init(position: 0.5, notice: notice, unit: 1)]
        XCTAssertTrue(sliver.pulseNotice(notice.key)); XCTAssertEqual(sliver.noticePulseCountForChecks, 1)
        sliver.noticeMarks = []; XCTAssertEqual(sliver.noticePulseCountForChecks, 0)
        sliver.dispose()
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
        XCTAssertFalse(menu.contains("Engine-only summary"), "Reader diagnostics belong in Settings, not the Dock menu")
        XCTAssertFalse(menu.contains("Engine-only reason"), "The Dock menu must contain only prototype actions")
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
