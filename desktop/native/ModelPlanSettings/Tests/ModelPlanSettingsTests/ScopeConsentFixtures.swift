// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

enum ScopeConsentFixtures {
    enum Failure: Error { case missingCapture }
    static let local = "gemini.local_history"
    static let gemini = "gemini.account_usage.saved_login"
    static let cursor = "cursor.account_usage.saved_login"
    static func facts(grantedGemini: Bool = false, cursorDefault: Bool = false, retiredGemini: Bool = false, unknownGeminiRoute: Bool = false) throws -> WireConsentFacts {
        var root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent()
        while root.path != "/", !FileManager.default.fileExists(atPath: root.appendingPathComponent("schema/app-cli/captures/WireConsentFacts.json").path) { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent("schema/app-cli/captures/WireConsentFacts.json"))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let capturedScopes = object["scopes"] as? [[String: Any]], let base = capturedScopes.first else { throw Failure.missingCapture }
        let specs = [(local, "gemini", "local_log", true), (gemini, "gemini", "saved_login_api", false), (cursor, "cursor", "saved_login_api", cursorDefault)]
        let scopes = specs.map { id, tool, route, checked -> [String: Any] in
            var value = base
            value["scope"] = id; value["tool"] = tool; value["route"] = route
            if id == gemini && unknownGeminiRoute { value["route"] = "future-route-canary" }
            value["detected"] = id == gemini ? !retiredGemini : true; value["retired"] = id == gemini && retiredGemini
            value["state"] = id == gemini && grantedGemini ? "allowed" : "unset"
            value["defaultCheck"] = checked; value["cleanupPending"] = false
            value.removeValue(forKey: "keychain"); value.removeValue(forKey: "disabledReason")
            return value
        }
        return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: ["scopes": scopes]))
    }
}
actor ScopeConsentTestClient: EngineClient {
    private var failure: EngineClientError?
    private var inspections = 0
    func failGrant(_ error: EngineClientError) { failure = error }
    func inspectionCount() -> Int { inspections }
    private var plugins: [WirePluginInstallParams] = []
    func recordedPlugins() -> [WirePluginInstallParams] { plugins }
    private var grants: [WireConsentGrantParams] = []
    private var shouldHold = false
    private var held: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    func holdGrant() { shouldHold = true }
    func waitForGrantStart() async {
        if !grants.isEmpty { return }
        await withCheckedContinuation { started = $0 }
    }
    func finishGrant() { held?.resume(); held = nil; shouldHold = false }
    func recordedGrants() -> [WireConsentGrantParams] { grants }
    func start() async throws -> EngineDeliveryContext { throw EngineClientError.notReady }
    func retry() async throws -> EngineDeliveryContext { throw EngineClientError.notReady }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.notReady }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { inspections += 1; return try completion() }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion {
        grants.append(request); started?.resume(); started = nil
        if shouldHold { await withCheckedContinuation { held = $0 } }
        if let failure { throw failure }
        return try completion()
    }
    private func completion() throws -> EngineRequestCompletion {
        .init(requestID: try WireDecoder.decode(WireRequestID.self, from: Data(#""rpc-u8""#.utf8)))
    }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.notReady }
    func history(_ query: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.notReady }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { plugins.append(request); throw EngineClientError.featureDecode(.pluginInstall) }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.notReady }
}
