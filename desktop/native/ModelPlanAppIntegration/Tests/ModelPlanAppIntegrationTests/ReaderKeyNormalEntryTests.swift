// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// Synthetic key only.
private let fakeKey = "fake-normal-entry-key-0001"
private let zaiScope = "zai.account_usage.api_key"

/// A stand-in engine: it answers `readerkey/*` like the real one and, once it is asked to allow the
/// provider's reading scope after a key was saved, publishes that provider's row.
private actor KeyEngine: EngineClient {
    struct KeyCall: Equatable { let method: String; let provider: String; let region: String; let key: String }
    let store: EngineStore
    let facts: WireConsentFacts
    let rows: WireRowsSnapshot
    let rowsWithZai: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "synthetic-key", floor: .init(storeEpoch: "synthetic-key", generation: 1), revision: 1)
    private(set) var keyCalls: [KeyCall] = []
    private(set) var grants: [[String]] = []
    private var saved = false
    private var savedRegion: WireReaderKeyRegion = .none
    var testOutcome: WireReaderKeyOutcome = .ok
    init(store: EngineStore, facts: WireConsentFacts, rows: WireRowsSnapshot, rowsWithZai: WireRowsSnapshot) {
        self.store = store; self.facts = facts; self.rows = rows; self.rowsWithZai = rowsWithZai
    }
    nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool {
        value.sessionID == "synthetic-key" && value.floor.generation == 1 && value.revision == 1
    }
    func supportsCapability(_ capability: String) async -> Bool { capability == "reader_key" }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.consentChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: facts), delivery: context)))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func recordedKeyCalls() -> [KeyCall] { keyCalls }
    func recordedGrants() -> [[String]] { grants }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("facts")) }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion {
        grants.append(request.allow)
        if saved && request.allow.contains(zaiScope) {
            await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rowsWithZai), delivery: context), invalidRowCount: 0))
        }
        return .init(requestID: .string(request.requestId))
    }
    func readerKey(_ method: EngineReaderKeyMethod, _ params: WireReaderKeyParams, timeout: Duration?) async throws -> EngineRequestCompletion {
        keyCalls.append(.init(method: method.rawValue, provider: params.provider.rawValue, region: params.region.rawValue, key: params.key))
        var outcome: WireReaderKeyOutcome
        switch method {
        case .test: outcome = testOutcome
        case .set: saved = true; savedRegion = params.region; outcome = .saved
        case .remove: saved = false; savedRegion = .none; outcome = .removed
        case .status: outcome = .ok
        }
        let id = WireRequestID.string("key-\(keyCalls.count)")
        let result = try WireReaderKeyResult(schemaVersion: 1, provider: params.provider, region: saved ? savedRegion : .none, present: saved, outcome: outcome)
        await store.consume(.response(requestID: id, .readerKey(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: result), delivery: context))))
        return .init(requestID: id)
    }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class ReaderKeyNormalEntryTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { view.subviews + view.subviews.flatMap(descendants) }
    private func find<T: NSView>(_ root: NSView, _ id: String, as: T.Type) -> T? {
        descendants(root).first { $0.accessibilityIdentifier() == id } as? T
    }

    /// Normal entry: the app is built the way production builds it; the key area is not there until
    /// the engine says it supports it; then paste a key, Test, Save, and the provider's row appears.
    func testPasteTestSaveThenTheProviderRowAppears() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("reader-key-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures").standardizedFileURL
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures.appendingPathComponent("WireConsentFacts.json"))) as? [String: Any])
        var scope = try XCTUnwrap((object["scopes"] as? [[String: Any]])?.first)
        scope["scope"] = zaiScope; scope["tool"] = "zai"; scope["route"] = "api_key_api"; scope["state"] = "unset"
        scope["detected"] = true; scope["retired"] = false; scope["defaultCheck"] = false
        scope.removeValue(forKey: "disabledReason"); scope.removeValue(forKey: "keychain")
        object["scopes"] = [scope]
        let facts = try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
        let rowsData = try Data(contentsOf: captures.appendingPathComponent("WireRowsSnapshot.json"))
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: rowsData)
        let zaiText = String(decoding: rowsData, as: UTF8.self).replacingOccurrences(of: "\"codex\"", with: "\"zai\"")
        let rowsWithZai = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(zaiText.utf8))
        var engine: KeyEngine?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]), createsNativePanels: false,
            makeClient: { _, store in let value = KeyEngine(store: store, facts: facts, rows: rows, rowsWithZai: rowsWithZai); engine = value; return value }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare(); await app.composition.start()
        let view = app.scopeConsentEntry.view
        for _ in 0..<200 { if find(view, "readerkey.zai.field", as: NSSecureTextField.self) != nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        let field = try XCTUnwrap(find(view, "readerkey.zai.field", as: NSSecureTextField.self), "the key area appears once the engine supports it")
        let ids = { app.composition.store.snapshot.rows?.projection.rows.map(\.id) ?? [] }
        XCTAssertFalse(ids().contains("zai"), "no row before a key is saved")

        // Paste the key.
        field.stringValue = fakeKey
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        // Test.
        try XCTUnwrap(find(view, "readerkey.zai.test", as: ConnectionButton.self)).invoke?()
        let result = { self.find(view, "readerkey.zai.result", as: NSTextField.self)?.stringValue ?? "" }
        for _ in 0..<300 { if result() == ReaderKeyOutcome.ok.message.english { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(result(), ReaderKeyOutcome.ok.message.english)
        // Save.
        try XCTUnwrap(find(view, "readerkey.zai.save", as: ConnectionButton.self)).invoke?()
        for _ in 0..<500 { if ids().contains("zai") { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(ids().contains("zai"), "after Test and Save the provider's row appears")

        let engineValue = try XCTUnwrap(engine)
        let calls = await engineValue.recordedKeyCalls()
        XCTAssertEqual(calls.map(\.method), ["readerkey/status", "readerkey/status", "readerkey/test", "readerkey/set"], "Save reuses the passing Test")
        XCTAssertEqual(calls.last, .init(method: "readerkey/set", provider: "zai", region: "global", key: fakeKey))
        let grants = await engineValue.recordedGrants()
        XCTAssertEqual(grants, [[zaiScope]], "saving turns on exactly that provider's reading scope")
        XCTAssertEqual(find(view, "readerkey.zai.field", as: NSSecureTextField.self)?.stringValue, "", "the key does not stay on screen")
        await app.composition.stop()
    }
}
