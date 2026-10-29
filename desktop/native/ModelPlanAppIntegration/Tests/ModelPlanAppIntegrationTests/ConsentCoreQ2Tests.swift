// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanCore
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class ConsentCoreQ2Tests: XCTestCase {
    private actor Wire: ConsentJSONTransport {
        var reads = 0, writes = 0, revoked = false
        var failReadback = false, badReceipt = false, failAllReads = false, ordinarySuccess = false
        var pendingIDs = ["claude"]
        func configure(failReadback: Bool = false, badReceipt: Bool = false, pendingIDs: [String] = ["claude"], failAllReads: Bool = false, ordinarySuccess: Bool = false) { self.ordinarySuccess = ordinarySuccess; self.failAllReads = failAllReads; self.failReadback = failReadback; self.badReceipt = badReceipt; self.pendingIDs = pendingIDs }
        func readConsentJSON() async throws -> CommandResult {
            reads += 1
            if failAllReads || (revoked && failReadback) { throw TransportError.launchFailed }
            var object = try GeneratedAppCLIFixtures.object(revoked ? "revoked-consent.json" : "consented-consent.json")
            let tools = try XCTUnwrap(object["tools"] as? [[String: Any]])
            var claude = try XCTUnwrap(tools.first { $0["id"] as? String == "claude" })
            claude["allowed"] = !revoked // This test intentionally simulates a granted Claude row.
            object["tools"] = [claude]
            return .init(exitCode: 0, stdout: try JSONSerialization.data(withJSONObject: object))
        }
        func grantConsentJSON(_ payload: Data) async throws -> CommandResult {
            writes += 1
            let value = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
            XCTAssertEqual(value["deny"] as? [String], ["claude"])
            XCTAssertEqual(value["allow"] as? [String], [])
            XCTAssertEqual(value["keychain"] as? [String: String], [:])
            revoked = true
            var reply = try GeneratedAppCLIFixtures.object(ordinarySuccess ? "revoked-revoke.json" : "cleanup-pending-revoke.json")
            reply["requestId"] = badReceipt ? UUID().uuidString : value["requestId"]!
            reply["pendingForget"] = ordinarySuccess ? [] : pendingIDs
            // Generated cleanup is Copilot/Codex; keep this test's intentional Claude scope/fault.
            reply["tools"] = []
            return .init(exitCode: ordinarySuccess ? 0 : 1, stdout: try JSONSerialization.data(withJSONObject: reply))
        }
        func counts() -> [Int] { [reads, writes] }
    }
    private actor Desktop: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { XCTFail("No real reader in synthetic fixture"); throw TransportError.launchFailed }
    }
    private final class Surface: SettingsWindowSurface {
        var panes: [String?] = []
        func prepare() async {}
        func show(paneID: String?) { panes.append(paneID) }
        func hide() {}
    }
    private func bundle() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("consent-core-q2-" + UUID().uuidString).resolvingSymlinksInPath()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Contents/Helpers"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Contents/Resources"), withIntermediateDirectories: true)
        let bytes = Data("Inert bundle fixture; never executable".utf8)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        try bytes.write(to: root.appendingPathComponent("Contents/Helpers/modelplan"))
        try Data((hash + "\n").utf8).write(to: root.appendingPathComponent("Contents/Resources/modelplan.sha256"))
        let info = ["CFBundleShortVersionString": "1.2.3", "ModelPlanPublicSource": String(repeating: "a", count: 40),
            "ModelPlanHelperVersion": "0.5.45", "ModelPlanSourceHelperSHA256": CommunityConsentBundleIdentity.sourceSHA256ByArchitecture["arm64"]!,
            "ModelPlanBundledHelperSHA256": hash]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: root.appendingPathComponent("Contents/Info.plist"))
        return root
    }
    func testActualFactoryAboutUsesVerifiedCLIAppAndNumericOSFacts() throws {
        let root = try bundle(), wire = Wire()
        let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
        let about = CommunityApplicationFactory.makeSettingsContext(bundle: root, availability: port.availability,
            operatingSystem: .init(majorVersion: 15, minorVersion: 4, patchVersion: 3)).about
        XCTAssertEqual(about.cliState, .ready)
        XCTAssertEqual(about.cliVersion, "0.5.45")
        XCTAssertEqual(about.version, "1.2.3")
        XCTAssertEqual(about.macOSVersion, "15.4.3")
    }
    func testActualFactoryForgetRereadsCommittedRevocationAndOffersLocalHelp() async throws {
        let root = try bundle(), wire = Wire(), desktop = Desktop(), firstRun = Surface(), about = Surface()
        let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { true }, environment: { .init() }, activate: {}, makeSurface: { _ in about })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend,
            canPresent: { true }, makeFirstRun: { _ in firstRun })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        let view = SettingsConnectionsView(editor: app.editor, firstRun: true)
        let request = try XCTUnwrap(app.editor.connections.requestForget(.claude))
        await app.editor.connections.confirm(request.id)
        let counts = await wire.counts(); XCTAssertEqual(counts, [3, 1])
        XCTAssertEqual(app.editor.connections.snapshot?.consentGeneration, 2)
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.authorization, .noConsent)
        XCTAssertNotEqual(app.editor.connections.phase, .failed(.requestFailed))
        let help = try XCTUnwrap(view.arrangedSubviews.compactMap { $0 as? ConnectionButton }.first { $0.accessibilityIdentifier() == "connections.cleanupHelp" })
        help.invoke?()
        for _ in 0..<1000 where about.panes.isEmpty { await Task.yield() }
        XCTAssertEqual(about.panes.first ?? nil, "about")
        XCTAssertNil(view.window)
        let final = await wire.counts(); XCTAssertEqual(final, [3, 1], "Help must not retry cleanup or execute credentials")
    }
    func testCleanupReadbackFailureWithdrawsCurrentConsentAndPreservesOwnership() async throws {
        let root = try bundle(), wire = Wire(), desktop = Desktop()
        await wire.configure(failReadback: true)
        let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        let original = try XCTUnwrap(app.editor.connections.snapshot)
        let membership = SettingsVerifiedSubscription(reference: "synthetic-owned", tool: .claude, name: .init("Synthetic plan", "合成方案"))
        var tools = original.tools; tools[0].binding = .verified(references: [membership.reference])
        app.editor.connections.receive(try .init(consentGeneration: original.consentGeneration, tools: tools,
            subscriptions: [membership], consentPreview: original.consentPreview, mode: original.mode))
        let request = try XCTUnwrap(app.editor.connections.requestForget(.claude))
        await app.editor.connections.confirm(request.id)
        XCTAssertEqual(app.editor.connections.phase, .failed(.cleanupReadbackUnavailable))
        XCTAssertNil(app.editor.connections.snapshot?.consentGeneration)
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.authorization, .unknown)
        XCTAssertEqual(app.editor.connections.snapshot?.subscriptions, [membership])
        XCTAssertFalse(app.editor.connections.canForget(.claude))
        let copy = SettingsConnectionPresentation.status(app.editor.connections.phase)
        XCTAssertTrue(copy.english.contains("could not be verified")); XCTAssertFalse(copy.english.contains("cleanup_pending"))
        let counts = await wire.counts(); XCTAssertEqual(counts, [3, 1])
    }
    func testCleanupReceiptMustMatchTheRequestAndItsExplicitDenyScope() async throws {
        for badID in [true, false] {
            let root = try bundle(), wire = Wire(), desktop = Desktop()
            await wire.configure(badReceipt: badID, pendingIDs: badID ? ["claude"] : ["codex"])
            let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
            let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
            let controller = SettingsConnectionController(service: backend)
            await controller.refresh()
            let request = try XCTUnwrap(controller.requestForget(.claude))
            await controller.confirm(request.id)
            XCTAssertEqual(controller.phase, .failed(.requestFailed))
            XCTAssertTrue(controller.snapshot?.pendingCleanupTools.isEmpty == true)
            let counts = await wire.counts(); XCTAssertEqual(counts, [2, 1])
        }
    }
    func testAboutUnverifiedStatusAndManualCleanupLinkAreHumanAndReadOnly() throws {
        let root = try bundle()
        let context = CommunityApplicationFactory.makeSettingsContext(bundle: root, availability: .unverified,
            operatingSystem: .init(majorVersion: 15, minorVersion: 4, patchVersion: 3))
        XCTAssertEqual(context.about.cliState, .unavailable)
        XCTAssertEqual(context.about.cliVersion, "unknown")
        XCTAssertEqual(context.about.version, "1.2.3"); XCTAssertEqual(context.about.macOSVersion, "15.4.3")
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: context, paneID: "about")
        let status = try XCTUnwrap(rows.first { $0.key == .cliStatus })
        if case .text(let copy) = status.value { XCTAssertTrue(copy.contains("核验")); XCTAssertNotEqual(copy, "unavailable") }
        else { XCTFail("Expected human status") }
        let help = try XCTUnwrap(rows.first { $0.key == .consentHelp })
        if case .link(let url) = help.value { XCTAssertEqual(url, SettingsAbout.consentHelpURL) }
        else { XCTFail("Expected read-only instructions link") }
    }

    func testStandaloneFactoryRetainsOneSettingsApplicationAndBoundBackend() async throws {
        let root = try bundle(), wire = Wire(), desktop = Desktop()
        let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let context = CommunityApplicationFactory.makeSettingsContext(bundle: root, availability: port.availability)
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), context: context, apply: { _ in })
        var factories = 0
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: CommunityInstrumentSurfaceProvider(), consentBackend: backend) { _ in
            factories += 1
            let base = CommunitySettingsSession(application: app, canPresent: { false })
            return try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        }
        let lifecycle = LifecycleCoordinator(store: SnapshotStore(transport: desktop))
        XCTAssertNil(delegate.settingsIntegration)
        delegate.configureSettings(lifecycle); delegate.configureSettings(lifecycle)
        let entry = try XCTUnwrap(delegate.settingsIntegration as? CommunityConnectionIntegration)
        defer { entry.flow.dispose() }
        XCTAssertTrue(entry.flow.application === app)
        try CommunityConnectionWiring.requireInstalled(entry, application: app, backend: backend)
        XCTAssertEqual(factories, 1)
        await entry.restorePreferences()
        let counts = await wire.counts(); XCTAssertEqual(counts, [1, 0])
    }
    func testCanonicalReadFailureHasALocalActionWithoutClaimingSuccessfulReadback() async throws {
        let root = try bundle(), wire = Wire(), desktop = Desktop(), firstRun = Surface(), about = Surface()
        await wire.configure(failAllReads: true)
        let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let context = CommunityApplicationFactory.makeSettingsContext(bundle: root, availability: port.availability)
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), context: context, apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { true }, environment: { .init() }, activate: {}, makeSurface: { _ in about })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend,
            canPresent: { true }, makeFirstRun: { _ in firstRun })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        let view = SettingsConnectionsView(editor: app.editor, firstRun: true)
        XCTAssertEqual(app.editor.connections.phase, .failed(.requestFailed))
        XCTAssertNil(app.editor.connections.snapshot)
        XCTAssertEqual(app.editor.context.about.cliState, .ready, "Verified component is not successful canonical data")
        XCTAssertTrue(SettingsConnectionPresentation.status(app.editor.connections.phase).english.contains("About"))
        let help = try XCTUnwrap(view.arrangedSubviews.compactMap { $0 as? ConnectionButton }.first { $0.accessibilityIdentifier() == "connections.requestHelp" })
        help.invoke?()
        for _ in 0..<1000 where about.panes.isEmpty { await Task.yield() }
        XCTAssertEqual(about.panes.first ?? nil, "about")
        let counts = await wire.counts(); XCTAssertEqual(counts, [1, 0])
        XCTAssertNil(view.window)
    }

    func testCleanupReadbackPreservesVerifiedMembershipWithCurrentRevocation() async throws {
        let root = try bundle(), wire = Wire(), desktop = Desktop()
        let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        let original = try XCTUnwrap(app.editor.connections.snapshot)
        let membership = SettingsVerifiedSubscription(reference: "synthetic-owned", tool: .claude, name: .init("Synthetic plan", "合成方案"))
        var tools = original.tools; tools[0].binding = .verified(references: [membership.reference])
        app.editor.connections.receive(try .init(consentGeneration: original.consentGeneration, tools: tools,
            subscriptions: [membership], consentPreview: original.consentPreview, mode: original.mode))
        let request = try XCTUnwrap(app.editor.connections.requestForget(.claude))
        await app.editor.connections.confirm(request.id)
        XCTAssertEqual(app.editor.connections.snapshot?.consentGeneration, 2)
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.authorization, .noConsent)
        XCTAssertEqual(app.editor.connections.snapshot?.subscriptions, [membership])
        XCTAssertEqual(app.editor.connections.phase, .cleanupPending)
        XCTAssertEqual(app.editor.connections.snapshot?.pendingCleanupTools, [.claude])
    }

    private actor AdmissionProbe: CLITransport {
        let code: Int32
        init(_ code: Int32) { self.code = code }
        func execute(_ command: CLICommand) async throws -> CommandResult { .init(exitCode: code, stdout: Data()) }
    }
    func testOrdinaryForgetLostReadbackWithdrawsConsentWithoutRetryOrOwnershipLoss() async throws {
        let root = try bundle(), wire = Wire()
        await wire.configure(failReadback: true, ordinarySuccess: true)
        let gate = ConsentGatedDesktopTransport(readOnly: AdmissionProbe(69), normal: AdmissionProbe(0))
        let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
        let backend = CommunityConnectionBackend(port: port, desktop: gate)
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        let admitted = try await gate.execute(.desktop); XCTAssertEqual(admitted.exitCode, 0)
        let original = try XCTUnwrap(app.editor.connections.snapshot)
        let membership = SettingsVerifiedSubscription(reference: "synthetic-owned", tool: .claude, name: .init("Synthetic plan", "合成方案"))
        var tools = original.tools; tools[0].binding = .verified(references: [membership.reference])
        app.editor.connections.receive(try .init(consentGeneration: original.consentGeneration, tools: tools,
            subscriptions: [membership], consentPreview: original.consentPreview, mode: original.mode))
        let request = try XCTUnwrap(app.editor.connections.requestForget(.claude))
        await app.editor.connections.confirm(request.id)
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.authorization, .unknown)
        XCTAssertNil(app.editor.connections.snapshot?.consentGeneration)
        XCTAssertNil(app.editor.connections.snapshot?.consentPreview)
        XCTAssertEqual(app.editor.connections.snapshot?.subscriptions, [membership])
        XCTAssertFalse(app.editor.connections.canForget(.claude))
        await app.editor.connections.confirm(request.id)
        let counts = await wire.counts(); XCTAssertEqual(counts, [3, 1])
        let refused = try await gate.execute(.desktop); XCTAssertEqual(refused.exitCode, 69)
        XCTAssertEqual(app.editor.connections.phase, .failed(.mutationReadbackUnavailable))
    }
    func testManualInstructionURLIsRenderedSelectableWithoutAHostOrWindow() async throws {
        let root = try bundle()
        let context = CommunityApplicationFactory.makeSettingsContext(bundle: root, availability: .unverified)
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), context: context, apply: { _ in })
        await app.reload()
        let snapshot = try XCTUnwrap(app.editor.snapshot)
        let item = try XCTUnwrap(try SettingsCatalogue.rows(preferences: snapshot.preferences, context: context, paneID: "about").first { $0.key == .consentHelp })
        for language in [SettingsLanguage.english, .chinese] {
            let row = SettingsNativeRow(key: .consentHelp)
            row.apply(item, language: language, saving: false, input: nil, reduced: true, onChoice: NSSelectorFromString("unused:"),
                target: self, showGroup: false, snapshot: snapshot, context: context, holdAvailable: false, hasHost: false,
                onEdit: { _, _ in XCTFail("Read-only instructions must not edit") },
                onSurfaceAction: { _, _ in XCTFail("Rendering must not execute a URL/CLI action") }, onDraftCleared: { _ in })
            let field = try XCTUnwrap(row.controls.arrangedSubviews.compactMap { $0 as? NSTextField }.first { $0.stringValue.contains(SettingsAbout.consentHelpURL.absoluteString) })
            XCTAssertTrue(field.isSelectable); XCTAssertFalse(field.isEditable)
            XCTAssertFalse(field.stringValue.contains("Not available in this build"))
            XCTAssertFalse(field.stringValue.contains("此版本暂不可用"))
            XCTAssertNil(row.window)
            row.retireControls()
        }
    }
    func testReadingModesRenderHumanBilingualLabelsInTheFirstRunSection() async throws {
        let root = try bundle(), wire = Wire(), desktop = Desktop()
        let port = CommunityApplicationFactory.makeConsentPort(bundle: root, transport: wire)
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        defer { entry.flow.dispose() }
        let values: [(SettingsReadingMode, String, String)] = [(.automatic, "Automatic reading", "自动读取"),
            (.passive, "Passive reading", "被动读取"), (.off, "Reading disabled", "已停用读取"), (.unknown, "Not verified", "尚未核验")]
        for (mode, en, zh) in values {
            app.editor.connections.receive(try .init(consentGeneration: 1, mode: mode))
            let view = SettingsConnectionsView(editor: app.editor, firstRun: true)
            for language in [SettingsLanguage.english, .chinese] {
                view.apply(language: language)
                let expected = language == .english ? "Usage reading mode: " + en : "用量读取模式：" + zh
                XCTAssertTrue(view.arrangedSubviews.compactMap { $0 as? NSTextField }.contains { $0.stringValue == expected })
                XCTAssertNil(view.window)
            }
        }
    }

}
