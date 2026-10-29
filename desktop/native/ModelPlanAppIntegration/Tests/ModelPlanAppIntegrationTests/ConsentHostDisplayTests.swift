// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class ConsentHostDisplayTests: XCTestCase {
    private actor Wire: ConsentJSONTransport {
        let data: Data
        var grants = 0
        init(_ data: Data) { self.data = data }
        func readConsentJSON() async throws -> CommandResult { .init(exitCode: 0, stdout: data) }
        func grantConsentJSON(_ payload: Data) async throws -> CommandResult {
            grants += 1; XCTFail("Host display must never request a grant"); throw TransportError.launchFailed
        }
        func grantCount() -> Int { grants }
    }
    private actor Desktop: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult {
            XCTFail("No reader/helper effects in the host-display contract"); throw TransportError.launchFailed
        }
    }
    private final class Surface: SettingsWindowSurface {
        func prepare() async {}
        func show(paneID: String?) {}
        func hide() {}
    }
    // Synthetic reproduction uses the literal host forms reported from pinned v0.5.43;
    // the separately recorded full CLI capture is checked by the pinned-fixture test.
    private func payload(_ hosts: [Any], id: String = "claude") throws -> Data {
        var object = try GeneratedAppCLIFixtures.object("consented-consent.json")
        let tools = try XCTUnwrap(object["tools"] as? [[String: Any]])
        var tool = try XCTUnwrap(tools.first { $0["id"] as? String == id })
        tool["allowed"] = false; tool["hosts"] = hosts
        tool.removeValue(forKey: "hostDetails") // Deliberate legacy compatibility mutation.
        object["tools"] = [tool]
        return try JSONSerialization.data(withJSONObject: object)
    }
    private func control(_ view: NSView, _ id: String) throws -> ConnectionButton {
        func find(_ view: NSView) -> ConnectionButton? {
            if let button = view as? ConnectionButton, button.accessibilityIdentifier() == id { return button }
            return view.subviews.lazy.compactMap(find).first
        }
        return try XCTUnwrap(find(view), "Missing actual first-run control: " + id)
    }
    func testActualFactoryAcceptsURLAndLabelMetadataAndMountsTheFirstRunChoices() async throws {
        let data = try payload(["https://api.anthropic.com", "https://api.z.ai",
            "https://chatgpt.com (Codex runtime)", "Provider chosen by the tool"])
        let wire = Wire(data), desktop = Desktop()
        let port = CommunityCLIConsentPort(transport: wire, apiAvailable: true)
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("consent-hosts-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { true }, environment: { .init() }, activate: {})
        var mounted: SettingsConnectionsView?
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend,
            canPresent: { true }, makeFirstRun: { editor in
                XCTAssertTrue(editor === app.editor)
                mounted = SettingsConnectionsView(editor: editor, firstRun: true); return Surface()
            })
        defer { entry.flow.dispose() }
        try CommunityConnectionWiring.requireInstalled(entry, application: app, backend: backend)
        await entry.restorePreferences()
        XCTAssertEqual(app.editor.connections.phase, .idle)
        let snapshot = try XCTUnwrap(app.editor.connections.snapshot)
        XCTAssertEqual(snapshot.tools.first?.providerHosts, ["api.anthropic.com", "api.z.ai",
            "chatgpt.com (Codex runtime)", "Provider chosen by the tool"])
        XCTAssertEqual(snapshot.tools.first?.authorization, .noConsent)
        let view = try XCTUnwrap(mounted)
        XCTAssertTrue(try control(view, "connections.choose.claude").isEnabled)
        XCTAssertTrue(try control(view, "connections.allowSelected").isEnabled)
        XCTAssertEqual(try control(view, "connections.keychain.claude").state, .off)
        let grants = await wire.grantCount(); XCTAssertEqual(grants, 0)
        XCTAssertNil(view.window)
    }
    func testLegacyStringsAndStructuredLabelsProduceTheSameSnapshot() throws {
        let forms: [[Any]] = [["https://chatgpt.com (Codex runtime)", "Tool-selected endpoint"],
            [["host": "https://chatgpt.com", "note": "Codex runtime"], ["host": "Tool-selected endpoint"]]]
        for hosts in forms {
            let preview = try FeedDecoder.consentPreview(payload(hosts, id: "codex"))
            let snapshot = try CommunityConsentPreviewFacts(canonical: preview).projecting()
            XCTAssertEqual(snapshot.tools.first?.providerHosts, ["chatgpt.com (Codex runtime)", "Tool-selected endpoint"])
            XCTAssertEqual(snapshot.tools.first?.authorization, .noConsent)
        }
    }
    func testBothCanonicalAndDirectSnapshotRejectControlsAndOverlongLabels() throws {
        for text in ["line\nbreak", "hidden\u{0}text", String(repeating: "x", count: 254)] {
            let preview = try FeedDecoder.consentPreview(payload([text]))
            XCTAssertThrowsError(try CommunityConsentPreviewFacts(canonical: preview))
            XCTAssertThrowsError(try SettingsConnectionSnapshot(tools: [.init(tool: .claude, providerHosts: [text])]))
        }
    }
    func testRecordedPinned543OutputDecodesThroughTheSameSettingsFactory() async throws {
        let fixture = try XCTUnwrap(Bundle.module.url(forResource: "consent-v0.5.43-synthetic", withExtension: "json"))
        let provenanceURL = try XCTUnwrap(Bundle.module.url(forResource: "consent-v0.5.43-provenance", withExtension: "json"))
        let provenance = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: provenanceURL)) as? [String: Any])
        var native = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<3 { native.deleteLastPathComponent() }
        let pin = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: native.appendingPathComponent("consent-cli-pin.json"))) as? [String: Any])
        XCTAssertEqual(provenance["cliVersion"] as? String, "0.5.43")
        XCTAssertEqual(provenance["syntheticHomeOnly"] as? Bool, true)
        let data = try Data(contentsOf: fixture)
        let decoded = try FeedDecoder.consentPreview(data)
        XCTAssertEqual(decoded.tools.count, 1, "This exact capture has one record; extra cases are synthetic")
        XCTAssertEqual(decoded.tools.first?.id, "codex")
        XCTAssertEqual(decoded.tools.first?.hosts, ["https://chatgpt.com (Codex runtime)"])
        let wire = Wire(data), desktop = Desktop()
        let backend = CommunityConnectionBackend(port: CommunityCLIConsentPort(transport: wire, apiAvailable: true),
            desktop: .init(readOnly: desktop, normal: desktop))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("recorded-consent-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        XCTAssertEqual(app.editor.connections.phase, .idle)
        XCTAssertEqual(app.editor.connections.snapshot?.consentGeneration, decoded.generation)
        XCTAssertEqual(app.editor.connections.snapshot?.mode, .off)
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.providerHosts, ["chatgpt.com (Codex runtime)"])
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.authorization, .noConsent)
        let grants = await wire.grantCount(); XCTAssertEqual(grants, 0)
    }
    func testRecordedPinned545OutputDecodesThroughTheSameSettingsFactory() async throws {
        let fixture = try XCTUnwrap(Bundle.module.url(forResource: "consent-v0.5.45-synthetic", withExtension: "json"))
        let provenanceURL = try XCTUnwrap(Bundle.module.url(forResource: "consent-v0.5.45-provenance", withExtension: "json"))
        let provenance = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: provenanceURL)) as? [String: Any])
        var native = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<3 { native.deleteLastPathComponent() }
        let pin = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: native.appendingPathComponent("consent-cli-pin.json"))) as? [String: Any])
        XCTAssertEqual(provenance["cliVersion"] as? String, pin["version"] as? String)
        XCTAssertEqual(provenance["syntheticHomeOnly"] as? Bool, true)
        let data = try Data(contentsOf: fixture)
        let decoded = try FeedDecoder.consentPreview(data)
        XCTAssertEqual(decoded.tools.count, 1, "This exact capture has one record; extra cases are synthetic")
        XCTAssertEqual(decoded.tools.first?.id, "codex")
        XCTAssertEqual(decoded.tools.first?.hosts, ["https://chatgpt.com (Codex runtime)"])
        let wire = Wire(data), desktop = Desktop()
        let backend = CommunityConnectionBackend(port: CommunityCLIConsentPort(transport: wire, apiAvailable: true),
            desktop: .init(readOnly: desktop, normal: desktop))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("recorded-consent-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let base = CommunitySettingsSession(application: app, canPresent: { false })
        let entry = try CommunityApplicationFactory.connectSettings(base: base, application: app, backend: backend, canPresent: { false })
        defer { entry.flow.dispose() }
        await entry.restorePreferences()
        XCTAssertEqual(app.editor.connections.phase, .idle)
        XCTAssertEqual(app.editor.connections.snapshot?.consentGeneration, decoded.generation)
        XCTAssertEqual(app.editor.connections.snapshot?.mode, .off)
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.providerHosts, ["chatgpt.com (Codex runtime)"])
        XCTAssertEqual(app.editor.connections.snapshot?.tools.first?.authorization, .noConsent)
        let grants = await wire.grantCount(); XCTAssertEqual(grants, 0)
    }
    func testAdditiveHostDetailsKeepLegacyLabelsAndWorkWithoutLegacyHosts() throws {
        let legacy = ["https://chatgpt.com (Codex runtime)", "Tool-selected endpoint"]
        for keepLegacy in [true, false] {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload(legacy, id: "codex")) as? [String: Any])
            var tools = try XCTUnwrap(object["tools"] as? [[String: Any]])
            tools[0]["hostDetails"] = [["host": "chatgpt.com", "note": "Codex runtime"]]
            if !keepLegacy { tools[0].removeValue(forKey: "hosts") }
            object["tools"] = tools
            let decoded = try FeedDecoder.consentPreview(JSONSerialization.data(withJSONObject: object))
            let snapshot = try CommunityConsentPreviewFacts(canonical: decoded).projecting()
            XCTAssertEqual(snapshot.tools.first?.providerHosts,
                keepLegacy ? ["chatgpt.com (Codex runtime)", "Tool-selected endpoint"] : ["chatgpt.com (Codex runtime)"])
        }
    }
    func testStructuredLabelsKeepTypeAndTextBounds() throws {
        for item: [String: Any] in [["host": 42], ["host": "example.test", "note": false]] {
            XCTAssertThrowsError(try FeedDecoder.consentPreview(payload([item])))
        }
        for note in ["line\nbreak", String(repeating: "x", count: 254)] {
            let decoded = try FeedDecoder.consentPreview(payload([["host": "example.test", "note": note]]))
            XCTAssertThrowsError(try CommunityConsentPreviewFacts(canonical: decoded))
        }
    }

}
