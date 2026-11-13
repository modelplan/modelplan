// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire

/// Admission is supplied by the member-refresh producer; the app never derives scopes from display labels.
public enum DockMemberRefreshAdmission: Equatable, Sendable { case ready, deferred, unavailable }

@MainActor public protocol DockMemberRefreshAdapting: AnyObject {
    func admission(for member: EngineAccountMember, delivery: EngineDeliveryContext, now: Date) -> DockMemberRefreshAdmission
    func request(member: EngineAccountMember, delivery: EngineDeliveryContext) async throws
}

/// Uses the existing ordered client/store path; never invents account identities.
@MainActor final class AppServerMemberRefreshAdapter: EngineStoreEventSink, DockMemberRefreshAdapting {
    private let client: any EngineClient
    private var pending: [String: (String, EngineDeliveryContext)] = [:]
    private var replies: [String: WireMemberRefreshResult] = [:]
    private var deadlines: [String: Date] = [:]
    init(client: any EngineClient, store: EngineStore) {
        self.client = client
        _ = store.attach(self)
    }
    private func key(_ id: WireRequestID) -> String { String(describing: id) }
    private func date(_ stamp: WireTimestamp?) -> Date? {
        guard let stamp else { return nil }
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: stamp.rawValue) ?? ISO8601DateFormatter().date(from: stamp.rawValue)
    }
    func admission(for member: EngineAccountMember, delivery: EngineDeliveryContext, now: Date) -> DockMemberRefreshAdmission {
        guard client.isCurrent(delivery), member.isStable,
              member.account.subscriptionRef != nil || member.account.accountLocator != nil else { return .unavailable }
        if let until = [date(member.account.refreshNotBefore), deadlines[member.id]].compactMap({ $0 }).max(), until > now { return .deferred }
        return .ready
    }
    private func register(_ id: WireRequestID, memberID: String, delivery: EngineDeliveryContext) {
        pending[key(id)] = (memberID, delivery)
    }
    func request(member: EngineAccountMember, delivery: EngineDeliveryContext) async throws {
        guard admission(for: member, delivery: delivery, now: Date()) == .ready else { throw EngineClientError.unsupportedCapability }
        let target = try WireRefreshMember(rowId: member.rowID, route: member.account.route,
            subscriptionRef: member.account.subscriptionRef, accountLocator: member.account.accountLocator)
        let params = try WireRefreshRequestParams(member: target)
        let completion: EngineRequestCompletion
        do {
            completion = try await client.refresh(params, timeout: nil, prepared: { [weak self] id in
                await self?.register(id, memberID: member.id, delivery: delivery)
            })
        } catch {
            let ids = pending.filter { $0.value.0 == member.id && $0.value.1 == delivery }.map(\.key)
            for id in ids { pending.removeValue(forKey: id); replies.removeValue(forKey: id) }
            throw error
        }
        let id = key(completion.requestID)
        defer { pending.removeValue(forKey: id); replies.removeValue(forKey: id) }
        guard client.isCurrent(delivery), let reply = replies[id] else { throw EngineClientError.staleValue }
        switch reply.outcome {
        case .started: deadlines.removeValue(forKey: member.id)
        case .deferred:
            guard let until = date(reply.notBefore) else { throw EngineClientError.unsupportedCapability }
            switch reply.reason {
            case .floor?, .backoff?, .budget?: deadlines[member.id] = until
            default: throw EngineClientError.unsupportedCapability
            }
        case .unknown: throw EngineClientError.unsupportedCapability
        }
    }
    func acceptedEvent(_ event: EngineClientEvent) {
        guard case .response(let id, .memberRefresh(let reply)) = event,
              let (_, expected) = pending[key(id)], expected == reply.delivery, client.isCurrent(expected) else { return }
        replies[key(id)] = reply.envelope.data
    }
    func clearPrivateViews(_ invalidation: EngineInvalidation) { pending.removeAll(); replies.removeAll(); deadlines.removeAll() }
    func apply(_ snapshot: EngineStoreSnapshot) {}
}
