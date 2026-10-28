// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanDock
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class ProductionSettingsJourneyTests: XCTestCase {
    private actor Desktop: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { throw TransportError.launchFailed }
    }
    private final class Port: CommunityConsentCommandPort {
        var availability: SettingsConnectionAvailability = .unverified
        var reads = 0, grants = 0, granted = false
        var toolID = "codex", keychainState = "unset", readingMode = "automatic"
        var expectedKeychain: [String: String] = [:]
        var recordKeychain = true, reportsTool = true
        func readCanonicalConsent() async throws -> ConsentPreview {
            reads += 1
            let tools = reportsTool ? """
            {"id":"\(toolID)","displayName":"Synthetic tool","accessClass":"standard","detected":true,"allowed":\(granted),"backend":"native","readerId":"native:\(toolID)","keychain":"\(keychainState)","hosts":["example.test"]}
            """ : ""
            return try FeedDecoder.consentPreview(Data("""
            {"generation":\(granted ? 2 : 1),"consentTextVersion":2,"mode":"\(readingMode)","consentText":{"en":"Synthetic consent","zh":"合成授权"},"tools":[\(tools)]}
            """.utf8))
        }
        func applyConsentJSON(_ payload: Data) async throws {
            let value = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
            XCTAssertEqual(value["allow"] as? [String], [toolID])
            XCTAssertEqual(value["deny"] as? [String], [])
            XCTAssertEqual(value["keychain"] as? [String: String], expectedKeychain)
            if recordKeychain, expectedKeychain["claude"] == "allow" { keychainState = "allowed" }
            grants += 1; granted = true
        }
    }
    private final class Placement: CommunityPlacementProducing {
        var onPlacementObserved: ((DockEdgePlacement?, Bool) -> Void)?
    }
    private final class Surface: SettingsWindowSurface {
        var panes: [String?] = []
        func prepare() async {}
        func show(paneID: String?) { panes.append(paneID) }
        func hide() {}
    }
    private final class Scheduler: DockEdgeScheduling {
        func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
        func cancel() {}
    }
    private func store() throws -> SettingsStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("production-settings-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try SettingsStore(url: root.appendingPathComponent("settings.json"))
    }
    private func backend(_ port: Port) -> CommunityConnectionBackend {
        let transport = Desktop()
        return .init(port: port, desktop: .init(readOnly: transport, normal: transport))
    }
    func testFactoryRestoresSameEditorAndOnlyExplicitConfirmationGrantsOnce() async throws {
        let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
        let port = Port(); port.availability = .init(canInspect: true, canGrant: true, canForget: true)
        let backend = backend(port), firstRun = Surface()
        let base = CommunitySettingsSession(application: app, canPresent: { true }, activate: {}, makeSurface: { _ in XCTFail("Unexpected settings surface"); return Surface() })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend,
            placementSource: Placement(), canPresent: { true }, makeFirstRun: { editor in
                XCTAssertTrue(editor === app.editor); return firstRun
            })
        var canonicalDeliveries = 0
        backend.onCanonicalReadback = { _ in canonicalDeliveries += 1 }
        await entry.restorePreferences()
        XCTAssertEqual(firstRun.panes.count, 1); XCTAssertEqual(port.reads, 1); XCTAssertEqual(port.grants, 0)
        let snapshot = try XCTUnwrap(app.editor.connections.snapshot)
        let intent = SettingsConnectionIntent(snapshot: snapshot)
        XCTAssertEqual(intent.orderedTools, [.codex]); XCTAssertEqual(port.grants, 0)
        let confirmation = try XCTUnwrap(app.editor.connections.requestAllow(intent))
        XCTAssertEqual(port.grants, 0)
        await app.editor.connections.confirm(confirmation.id)
        await app.editor.connections.confirm(confirmation.id)
        XCTAssertEqual(port.grants, 1); XCTAssertEqual(port.reads, 3)
        XCTAssertEqual(canonicalDeliveries, 2, "Only inspected and committed canonical readback reach the refresh hook")
        XCTAssertEqual(app.editor.connections.snapshot?.consentGeneration, 2)
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.authorization, .allowed)
        entry.flow.dispose()
    }
    func testUnavailableRealBackendMenuHasHumanReasonAndReachesSameLocalAbout() async throws {
        let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
        let port = Port(), surface = Surface(), firstRun = Surface()
        let base = CommunitySettingsSession(application: app, canPresent: { true }, activate: {}, makeSurface: { editor in
            XCTAssertTrue(editor === app.editor); return surface
        })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(port),
            placementSource: Placement(), canPresent: { true }, makeFirstRun: { _ in firstRun })
        await entry.restorePreferences()
        entry.updateUsageState(snapshot: nil, diagnostics: .init(), now: Date())
        XCTAssertEqual(entry.currentUsageNextStep?.destination, .about)
        XCTAssertTrue(entry.currentUsageMessage.chinese.contains("关于"))
        XCTAssertFalse(entry.usageAccessMenuItem.title.contains("Request unavailable"))
        let target = try XCTUnwrap(entry.usageAccessMenuItem.target as? NSObject)
        let action = try XCTUnwrap(entry.usageAccessMenuItem.action)
        _ = target.perform(action, with: entry.usageAccessMenuItem)
        for _ in 0..<1000 where surface.panes.isEmpty { await Task.yield() }
        XCTAssertEqual(surface.panes.count, 1); XCTAssertEqual(surface.panes.first ?? nil, "about")
        XCTAssertEqual(port.reads, 0); XCTAssertEqual(port.grants, 0)
        XCTAssertEqual(firstRun.panes.count, 1)
        entry.flow.dispose()
    }
    private func control(_ view: NSView, _ id: String) throws -> ConnectionButton {
        func find(_ view: NSView) -> ConnectionButton? {
            if let button = view as? ConnectionButton, button.accessibilityIdentifier() == id { return button }
            return view.subviews.lazy.compactMap(find).first
        }
        return try XCTUnwrap(find(view), "Missing actual mounted control: " + id)
    }
    func testClaudeKeychainChoiceMountsFromActualFactoryAndOnlyExplicitOptInIsSent() async throws {
        for recordsChoice in [true, false] {
            let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
            let port = Port(); port.toolID = "claude"; port.recordKeychain = recordsChoice
            port.expectedKeychain = ["claude": "allow"]
            port.availability = .init(canInspect: true, canGrant: true, canForget: true)
            let firstRun = Surface()
            var mounted: SettingsConnectionsView?
            let base = CommunitySettingsSession(application: app, canPresent: { true }, environment: { .init() }, activate: {})
            let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(port),
                placementSource: Placement(), canPresent: { true }, makeFirstRun: { editor in
                    XCTAssertTrue(editor === app.editor)
                    mounted = SettingsConnectionsView(editor: editor, firstRun: true)
                    return firstRun
                })
            await entry.restorePreferences()
            let view = try XCTUnwrap(mounted)
            let choice = try control(view, "connections.keychain.claude")
            XCTAssertEqual(choice.state, .off); XCTAssertEqual(port.grants, 0)
            choice.invoke?()
            XCTAssertEqual(try control(view, "connections.keychain.claude").state, .on)
            XCTAssertEqual(port.grants, 0, "Checking is a draft, never a Keychain read or grant")
            try control(view, "connections.allowSelected").invoke?()
            guard case .awaitingConfirmation(let confirmation) = app.editor.connections.phase else { return XCTFail("Missing exact confirmation") }
            XCTAssertTrue(SettingsConnectionPresentation.confirmation(confirmation.action).english.contains("Keychain"))
            XCTAssertEqual(port.grants, 0)
            try control(view, "connections.confirm").invoke?()
            for _ in 0..<1000 where port.grants == 0 || app.editor.connections.isBusy { await Task.yield() }
            XCTAssertEqual(port.grants, 1); XCTAssertEqual(port.reads, 3)
            XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.keychain, recordsChoice ? .allowed : .unset)
            XCTAssertEqual(app.editor.connections.phase, recordsChoice ? .idle : .failed(.invalidResponse))
            await app.editor.connections.confirm(confirmation.id); XCTAssertEqual(port.grants, 1)
            XCTAssertNil(view.window, "Construction proof must not open a real window")
            entry.flow.dispose()
        }
    }
    func testClaudeKeychainChangedDraftAndUncheckedNormalSettingsNeverGrantOrDenyIt() async throws {
        let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
        await app.reload()
        _ = try await app.editor.completeFirstRun(options: .init(preferences: app.editor.snapshot!.preferences),
            action: .done, host: .standalone, expectedRevision: app.editor.snapshot!.revision)
        let port = Port(); port.toolID = "claude"; port.keychainState = "allowed"
        port.availability = .init(canInspect: true, canGrant: true, canForget: true)
        let surface = Surface(); var mounted: SettingsConnectionsView?
        let base = CommunitySettingsSession(application: app, canPresent: { true }, environment: { .init() }, activate: {}, makeSurface: { editor in
            mounted = SettingsConnectionsView(editor: editor); return surface
        })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(port),
            placementSource: Placement(), canPresent: { true }, makeFirstRun: { _ in XCTFail("Completed setup must use normal Settings"); return Surface() })
        defer { entry.flow.dispose() }
        await entry.restorePreferences(); await entry.flow.perform(.connections)
        let view = try XCTUnwrap(mounted)
        XCTAssertEqual(try control(view, "connections.keychain.claude").state, .off, "Recorded allow never becomes a new checked intention")
        try control(view, "connections.keychain.claude").invoke?()
        try control(view, "connections.connect.claude").invoke?()
        guard case .awaitingConfirmation(let old) = app.editor.connections.phase else { return XCTFail("Missing confirmation") }
        try control(view, "connections.keychain.claude").invoke?()
        await app.editor.connections.confirm(old.id); XCTAssertEqual(port.grants, 0, "Editing the checkbox invalidates its old confirmation")
        try control(view, "connections.connect.claude").invoke?()
        try control(view, "connections.confirm").invoke?()
        for _ in 0..<1000 where port.grants == 0 || app.editor.connections.isBusy { await Task.yield() }
        XCTAssertEqual(port.grants, 1); XCTAssertEqual(port.keychainState, "allowed", "An unchecked choice is omitted, never deny/Forget")
        XCTAssertEqual(app.editor.connections.phase, .idle); XCTAssertNil(view.window)
    }
    func testActualHostThroughSameFactoryKeepsObservedPlacementSynchronizedWithoutPersistingRecovery() async throws {
        let store = try store()
        try await store.update { $0.dockDisplayID = "missing"; $0.dockEdge = .right; $0.dockAlongFraction = 0.75 }
        let before = await store.snapshot()
        let screen = DockDisplayArea(id: "fixture", frame: .init(x: 0, y: 0, width: 1200, height: 900), visibleFrame: .init(x: 0, y: 0, width: 1200, height: 900))
        let host = StaticDockPreviewHost(appearance: { view, rows, _ in
            try view.applyCommunity(rows); view.setFrameSize(.init(width: 80, height: 180))
            return .init(hoverRects: [view.bounds])
        }, currentDate: { Date(timeIntervalSince1970: 1_800_000_000) }, createsNativePanels: false,
        nativeEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "fixture") }, elapsedClock: { 0 }, edgeScheduling: Scheduler(), purpose: .production)
        defer { host.close() }
        XCTAssertEqual(host.purpose, .production)
        let app = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(Port()), placementSource: host, canPresent: { false })
        await entry.restorePreferences(); host.setPresentationAllowed(true)
        let placement = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertNoThrow(try CommunityDockPlacementFacts.requireSynchronized(placement, recovering: true, application: app))
        XCTAssertEqual(app.editor.context.dockPlacementObservation?.displayID, "fixture")
        host.setPresentationAllowed(false)
        XCTAssertNil(app.editor.context.dockPlacementObservation)
        let after = await store.snapshot()
        XCTAssertEqual(after.revision, before.revision)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(after.preferences), try encoder.encode(before.preferences), "Observed recovery must never rewrite the saved preferred display/edge/fraction")
        XCTAssertNil(host.nativePanel)
        // Use the same commit port called by the production Dock's drag receipt.
        XCTAssertNotNil(host.commitDisplayPlacement, "The real factory must wire the return path to the same editor")
        host.setPresentationAllowed(true)
        host.commitDisplayPlacement?("fixture", .left, 0.35)
        for _ in 0..<1000 where app.editor.snapshot?.preferences.dockEdge != .left { await Task.yield() }
        let moved = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertEqual(moved.edge, .left)
        XCTAssertNoThrow(try CommunityDockPlacementFacts.requireSynchronized(moved, recovering: false, application: app))
        let saved = await store.snapshot()
        XCTAssertEqual(saved.preferences.dockEdge, .left)
        XCTAssertEqual(saved.preferences.dockAlongFraction, 0.35)
        let row = try XCTUnwrap(try SettingsCatalogue.rows(preferences: saved.preferences, context: app.editor.context).first { $0.key == .dockEdge })
        XCTAssertTrue(row.subtitle.chinese.contains("当前位于左侧"))
        host.setPresentationAllowed(false)
        XCTAssertNil(host.nativePanel)
        entry.flow.dispose()
    }
    func testFreshFactoryFirstRunExplainsKeychainRecordsAndTheUncheckedNextStep() async throws {
        let cases = [("allowed", "Allowed by your choice", "已按你的选择允许"),
                     ("denied", "Not allowed by your choice", "你选择了不允许"),
                     ("unset", "Permission not requested yet", "尚未请求权限")]
        for (raw, english, chinese) in cases {
            let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
            let port = Port(); port.toolID = "claude"; port.keychainState = raw
            port.availability = .init(canInspect: true, canGrant: true, canForget: true)
            var mounted: SettingsConnectionsView?
            let base = CommunitySettingsSession(application: app, canPresent: { true }, environment: { .init() }, activate: {})
            let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(port),
                canPresent: { true }, makeFirstRun: { editor in
                    XCTAssertTrue(editor === app.editor)
                    mounted = SettingsConnectionsView(editor: editor, firstRun: true)
                    return Surface()
                })
            await entry.restorePreferences()
            let view = try XCTUnwrap(mounted)
            for language in [SettingsLanguage.english, .chinese] {
                view.apply(language: language)
                let labels = view.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
                let expected = language == .english ? "Keychain permission: " + english : "钥匙串权限：" + chinese
                XCTAssertTrue(labels.contains(expected), "The actual first-run section must translate " + raw)
                XCTAssertTrue(labels.contains { $0.contains(language == .english ? "usage cannot be read" : "无法读取用量") })
                XCTAssertFalse(labels.contains { $0 == "?" || $0.hasSuffix(": " + raw) || $0.hasSuffix("：" + raw) })
                XCTAssertEqual(try control(view, "connections.keychain.claude").state, .off)
            }
            XCTAssertEqual(port.grants, 0); XCTAssertNil(view.window)
            entry.flow.dispose()
        }
    }
    func testFreshFactoryWithNoToolsOffersSignInRecheckAndLocalSettingsAction() async throws {
        let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
        let port = Port(); port.reportsTool = false
        port.availability = .init(canInspect: true, canGrant: true, canForget: true)
        var mounted: SettingsConnectionsView?
        let base = CommunitySettingsSession(application: app, canPresent: { true }, environment: { .init() }, activate: {})
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(port),
            canPresent: { true }, makeFirstRun: { editor in
                mounted = SettingsConnectionsView(editor: editor, firstRun: true); return Surface()
            })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        let view = try XCTUnwrap(mounted)
        for language in [SettingsLanguage.english, .chinese] {
            view.apply(language: language)
            let labels = view.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
            XCTAssertTrue(labels.contains { $0.contains(language == .english ? "Sign in to a supported tool" : "请先登录受支持的工具") })
            XCTAssertTrue(try control(view, "connections.detect").isEnabled)
            XCTAssertFalse(try control(view, "connections.allowSelected").isEnabled)
        }
        entry.updateUsageState(snapshot: nil, diagnostics: .init(), now: Date())
        XCTAssertNotNil(entry.currentUsageNextStep)
        XCTAssertFalse(entry.usageAccessMenuItem.title.contains("?"))
        XCTAssertEqual(port.grants, 0); XCTAssertNil(view.window)
    }

    func testFreshFactoryReadingOffOffersTheSameLocalAboutAction() async throws {
        let app = SettingsApplicationCoordinator(store: try store(), apply: { _ in })
        let port = Port(); port.readingMode = "off"
        port.availability = .init(canInspect: true, canGrant: true, canForget: true)
        let surface = Surface(); var mounted: SettingsConnectionsView?
        let base = CommunitySettingsSession(application: app, canPresent: { true }, environment: { .init() }, activate: {},
            makeSurface: { editor in XCTAssertTrue(editor === app.editor); return surface })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend(port),
            canPresent: { true }, makeFirstRun: { editor in
                mounted = SettingsConnectionsView(editor: editor, firstRun: true); return Surface()
            })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        let view = try XCTUnwrap(mounted)
        XCTAssertFalse(try control(view, "connections.allowSelected").isEnabled)
        XCTAssertEqual(app.editor.connections.snapshot?.mode, .off)
        let help = try control(view, "connections.modeHelp")
        XCTAssertTrue(help.isEnabled); help.invoke?()
        for _ in 0..<1000 where surface.panes.isEmpty { await Task.yield() }
        XCTAssertEqual(surface.panes.first ?? nil, "about")
        XCTAssertEqual(port.grants, 0); XCTAssertNil(view.window)
    }

}
