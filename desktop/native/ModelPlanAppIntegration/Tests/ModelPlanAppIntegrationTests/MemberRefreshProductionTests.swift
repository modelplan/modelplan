// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor MemberRefreshTestClient: EngineClient {
    let store: EngineStore
    let supported: Bool
    let context = EngineDeliveryContext(sessionID: "synthetic-refresh", floor: .init(storeEpoch: "synthetic-refresh", generation: 1), revision: 1)
    var outcome: WireMemberRefreshResult = try! .init(outcome: .started)
    var calls = 0
    init(store: EngineStore, supported: Bool = true) { self.store = store; self.supported = supported }
    nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool { value.sessionID == "synthetic-refresh" && value.revision == 1 }
    func supportsCapability(_ capability: String) async -> Bool { supported && capability == "memberRefreshV1" }
    func start() async throws -> EngineDeliveryContext { await store.consume(.connection(.ready(context))); await store.consume(.context(context)); return context }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func setOutcome(_ value: WireMemberRefreshResult) { outcome = value }
    func requestCount() -> Int { calls }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?, prepared: @escaping @Sendable (WireRequestID) async -> Void) async throws -> EngineRequestCompletion {
        guard request.member != nil else { throw EngineClientError.unsupportedCapability }
        calls += 1
        let id = WireRequestID.string("member-\(calls)")
        await prepared(id)
        let envelope = try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: outcome)
        await store.consume(.response(requestID: id, .memberRefresh(.init(envelope: envelope, delivery: context))))
        return .init(requestID: id)
    }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class MemberRefreshProductionTests: XCTestCase {
    func testNormalEntryLeavesAdapterUnavailableWithoutCapability() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("member-unsupported-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]), createsNativePanels: false, makeClient: { _, store in MemberRefreshTestClient(store: store, supported: false) }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare(); await app.composition.start()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(app.memberRefreshAdapter)
        XCTAssertFalse(app.composition.dock.ringRefreshAvailable)
        await app.composition.stop()
    }
    func testNormalEntryInstallsNegotiatedAdapterAndMapsOutcomes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("member-refresh-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let member = try XCTUnwrap(EngineAccountMemberCatalogue(rows: rows.projection.rows).members.first { $0.isStable && ($0.account.subscriptionRef != nil || $0.account.accountLocator != nil) })
        var client: MemberRefreshTestClient?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]), createsNativePanels: false, makeClient: { _, store in let value = MemberRefreshTestClient(store: store); client = value; return value }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare()
        await app.composition.start()
        for _ in 0..<100 { if app.memberRefreshAdapter != nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        let adapter = try XCTUnwrap(app.memberRefreshAdapter)
        let engine = try XCTUnwrap(client)
        let context = engine.context
        XCTAssertEqual(adapter.admission(for: member, delivery: context, now: Date()), .ready)
        try await adapter.request(member: member, delivery: context)
        await engine.setOutcome(try .init(outcome: .deferred, notBefore: .init("2099-01-01T00:00:00Z"), reason: .floor))
        try await adapter.request(member: member, delivery: context)
        XCTAssertEqual(adapter.admission(for: member, delivery: context, now: Date()), .deferred)
        let requestCount = await engine.requestCount()
        XCTAssertEqual(requestCount, 2)
        let unsupported = AppServerMemberRefreshAdapter(client: engine, store: app.composition.store)
        await engine.setOutcome(try .init(outcome: .deferred, reason: .notGranted))
        do { try await unsupported.request(member: member, delivery: context); XCTFail("Unavailable refresh must not succeed") }
        catch EngineClientError.unsupportedCapability {}
        await app.composition.stop()
    }
}
