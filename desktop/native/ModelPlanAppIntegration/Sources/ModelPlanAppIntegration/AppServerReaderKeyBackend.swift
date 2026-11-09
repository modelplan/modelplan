// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire

/// D90: the production `ReaderKeyBackend`. It sends `readerkey/*` through the one ordered engine
/// client and reads each answer from the accepted event stream, like the member-refresh adapter.
/// The key is only a request parameter: it is never stored here, logged or returned.
@MainActor final class AppServerReaderKeyBackend: EngineStoreEventSink, ReaderKeyBackend {
    private let client: any EngineClient
    private let allow: @MainActor (String) async -> Bool
    private var replies: [String: (WireReaderKeyResult, EngineDeliveryContext)] = [:]

    /// `allow` grants one consent scope through the existing grant path.
    init(client: any EngineClient, store: EngineStore, allow: @escaping @MainActor (String) async -> Bool) {
        self.client = client; self.allow = allow
        _ = store.attach(self)
    }
    private func key(_ id: WireRequestID) -> String { String(describing: id) }
    private func wire(_ provider: ReaderKeyProvider) -> WireReaderKeyProvider { provider == .zai ? .zai : .opencodego }
    private func wire(_ region: ReaderKeyRegion?) -> WireReaderKeyRegion {
        switch region { case .some(.global): return .global; case .some(.china): return .china; case .none: return WireReaderKeyRegion.none }
    }
    private func region(_ value: WireReaderKeyRegion) -> ReaderKeyRegion? {
        switch value { case .global: return .global; case .china: return .china; default: return nil }
    }
    private func outcome(_ value: WireReaderKeyOutcome) -> ReaderKeyOutcome { ReaderKeyOutcome(wire: value.rawValue) }

    private func call(_ method: EngineReaderKeyMethod, _ provider: ReaderKeyProvider, key text: String, region: ReaderKeyRegion?) async -> WireReaderKeyResult? {
        guard let params = try? WireReaderKeyParams(provider: wire(provider), region: wire(region), key: text) else { return nil }
        do {
            let completion = try await client.readerKey(method, params, timeout: nil)
            let id = key(completion.requestID)
            defer { replies.removeValue(forKey: id) }
            guard let (reply, delivery) = replies[id], client.isCurrent(delivery) else { return nil }
            return reply
        } catch { return nil }
    }
    private func reply(_ result: WireReaderKeyResult?, fallback: ReaderKeyOutcome = .failed) -> ReaderKeyReply {
        guard let result else { return .init(outcome: fallback, status: .init(present: false, region: nil)) }
        return .init(outcome: outcome(result.outcome), status: .init(present: result.present, region: region(result.region)))
    }

    func status(_ provider: ReaderKeyProvider) async -> ReaderKeyStatus {
        reply(await call(.status, provider, key: "", region: nil)).status
    }
    func set(_ provider: ReaderKeyProvider, key: String, region: ReaderKeyRegion?) async -> ReaderKeyReply {
        reply(await call(.set, provider, key: key, region: region))
    }
    func test(_ provider: ReaderKeyProvider, key: String?, region: ReaderKeyRegion?) async -> ReaderKeyReply {
        reply(await call(.test, provider, key: key ?? "", region: region))
    }
    func remove(_ provider: ReaderKeyProvider) async -> ReaderKeyReply {
        reply(await call(.remove, provider, key: "", region: nil))
    }
    func allowReading(_ provider: ReaderKeyProvider) async -> Bool {
        await allow(provider == .zai ? "zai.account_usage.api_key" : "opencodego.account_usage.api_key")
    }

    func acceptedEvent(_ event: EngineClientEvent) {
        guard case .response(let id, .readerKey(let reply)) = event, client.isCurrent(reply.delivery) else { return }
        replies[key(id)] = (reply.envelope.data, reply.delivery)
    }
    func clearPrivateViews(_ invalidation: EngineInvalidation) { replies.removeAll() }
    func apply(_ snapshot: EngineStoreSnapshot) {}
}
