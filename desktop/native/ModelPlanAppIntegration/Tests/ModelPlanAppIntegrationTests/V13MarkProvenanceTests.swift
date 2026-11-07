// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import ModelPlanDockResources
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration

private actor V13SyntheticClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "reserve-synthetic", floor: .init(storeEpoch: "reserve-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class V13Timer: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class V13MarkProvenanceTests: XCTestCase {
    func testV13NormalEntryUsesApprovedCommunityMarkBytes() async throws {
        _ = NSApplication.shared
        let manifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: false))
        let resourceRoot = try DockThirdPartyResources.rootURL()
        let resources = try DockArtworkStore(root: resourceRoot, manifest: manifest)
        let sourceURL = try resources.checkedURL("notice-vendors")
        let notes = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(notes.localizedCaseInsensitiveContains("trademark"))
        XCTAssertNil(manifest.files["logo-zai-white"], "Beta-only marks must not enter the community manifest")
        // Pin the reviewed upstream bytes independently of the mutable resource manifest.
        let vendors = [
            ("openai", "logo-openai", "01d158767c4eec0e47bd617e67759c33da0accd1438be1a8d29dfdb99ce87285"),
            ("claude", "logo-claude", "6d53db4be375e899c937c26cf16684a80d6e869b1928d72b37748bef2560e219"),
            ("cursor", "logo-cursor", "cd0e3e5d8991a4cdd4577f8896cd063105207665165c73e25a1ff918dd367eb7"),
            ("copilot", "logo-copilot", "ae3ac7a6dc1415aeaf7064c7a749d9efd7f1ec49a68450590df7cf0da8d83781"),
            ("gemini", "logo-gemini", "5e7cfecaa53f4f65a313fe89b0f389548126544a78fad8489510c70ae641a4a1"),
            ("zhipu", "logo-zhipu", "94ff9c00af67774e5178428942a6e0a9952c7e2f3aba4c25f3b05c782841ee4c"),
            ("zai", "logo-zai", "e7fa404fb412b9788f460bb69f2536c4d7fc7dc1c7f3bba231d3b355ca971395"),
            ("qwen", "logo-qwen", "cd9390bc4209c319121d111f3a1f535b3c7dd909b8f860d41acc9744138d58df"),
            ("x", "logo-x", "a83542eb0563242949d7dbde720014fb7ab48ae14ed59f43eec34907cb90c477"),
            ("grok", "logo-grok", "3a462c3c2524733c173bb05c431de737812f8219db8fa115b0025d12a347e086"),
            ("xiaomi", "logo-xiaomi", "cbd7602e878c987180cbb14e86aa241541e3523e85362e1ac0bc7b896f93ea65"),
            ("kiro", "logo-kiro", "eaf4e3a56ad089982e2b06d1d7bcbded64b24b7df946a3991ad8fcc778ee46c6"),
            ("amp", "logo-amp", "d4e6d7bab74bfcebf3edc2b14549d92b3e4384e6ec6629781a074a816d42ea08"),
            ("antigravity", "logo-antigravity", "193ba1805de11c23cd0c7a1df92aa0a886708e57350f6f7766100afe5befed73"),
            ("droid", "logo-droid", "8b6270e882a878c8c962b2f48c4d4d3813b06ac9689f4fbd8309777067ee78e0"),
            ("minimax", "logo-minimax", "d095a4fff8770ace5d8b537a9f642e3c4f1230a56a36177a16537d36d84b2e33"),
            ("kimi", "logo-kimi", "3821ae593eebce6940992f56e2fee3f55a08bbbba78713303c23ea714d44c5f9"),
            ("deepseek", "logo-deepseek", "357e144b8f2a169a0edb8eb4ef6472c9a6d4b5b8aa945561a61b09bed133e38d"),
            ("opencode", "logo-opencode", "4e84f87aa7bc2a5f8a72eeb08d3d4f1836b422189256d0bd5e7bfabc830d7ed0")
        ]
        for (vendor, expectedResource, expectedHash) in vendors {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("v13-mark-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: profile) }
            let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
            var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
            var projection = try XCTUnwrap(root["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
            var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
            row["vendorKey"] = vendor; row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
            row["expiresAt"] = "2028-12-01T00:00:00Z"
            row["reason"] = ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
            row["nextStep"] = ["action": "open_settings_consent", "text": ["en": "Check read access in Settings", "zh": "在设置检查读取权限"], "availableAt": NSNull(), "disabledReason": NSNull()]
            account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
            account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = "2028-12-01T00:00:00Z"
            account["lastFailure"] = NSNull(); account["credits"] = ["balance": 123.45, "unit": "unknown"]
            windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
            windows[0]["observedAt"] = "2026-12-01T00:00:00Z"; windows[0]["validUntil"] = "2028-12-01T00:00:00Z"
            windows[0]["resetsAt"] = "2028-12-01T00:00:00Z"; windows[0]["remainingPercent"] = 42.0
            account["windows"] = [windows[0]]; row["accounts"] = [account]; rows[0] = row
            projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
            let snapshot = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
            XCTAssertEqual(snapshot.projection.invalidRowCount, 0)
            let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z"))
            let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
            let pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
            let timer = V13Timer()
            let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
                settingsStore: settings, createsNativePanels: false,
                dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: pointer) },
                deadlineNow: { now }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
                makeClient: { _, store in V13SyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
            defer { app.composition.dock.close() }
            await app.prepare(); app.allowDockPresentation(); await app.composition.start()
            let view = app.composition.dock.dockView
            XCTAssertFalse(view.zaiMarkEnabled, "Normal entry must retain the beta-only policy")
            let reading = try XCTUnwrap(view.presentedReadingsForChecks["aaaaaaaaaaaaaaaa"])
            let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == reading.subscriptionID })
            XCTAssertEqual(reading.vendorResourceKey, vendor)
            XCTAssertEqual(station.glyphs[vendor], expectedResource)
            let record = try XCTUnwrap(manifest.files[expectedResource])
            let assetURL = try resources.checkedURL(expectedResource)
            let bytes = try Data(contentsOf: assetURL)
            let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(bytes.count, record.bytes)
            XCTAssertEqual(hash, record.sha256.lowercased())
            XCTAssertEqual(hash, expectedHash, "The approved mark bytes must remain unchanged")
            XCTAssertTrue(notes.contains(URL(fileURLWithPath: record.path).lastPathComponent))
            await app.composition.stop()
        }
    }
}
