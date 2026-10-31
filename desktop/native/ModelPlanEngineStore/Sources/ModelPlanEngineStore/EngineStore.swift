// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanEngineStoreCore
import ModelPlanWire

// Keep the native facade stable while the portable package owns value storage.
public typealias EngineStoreSnapshot = ModelPlanEngineStoreCore.EngineStoreSnapshot
public typealias EngineStoreFeatureFailure = ModelPlanEngineStoreCore.EngineStoreFeatureFailure

/// A view/cache owner clears synchronously, before consume acknowledges the barrier.
/// Implementations must not retain a Task that later republishes a prior snapshot.
@MainActor public protocol EngineStoreSink: AnyObject {
    func clearPrivateViews(_ invalidation: EngineInvalidation)
    func apply(_ snapshot: EngineStoreSnapshot)
}

@MainActor private final class WeakSink {
    weak var value: (any EngineStoreSink)?
    init(_ value: any EngineStoreSink) { self.value = value }
}

/// Native UI fanout only. Core applies accepted values; EngineClient owns
/// protocol admission. UI sinks clear before this consumer acknowledges.
@MainActor public final class EngineStore: EngineClientEventConsumer {
    private var core = EngineStoreCore()
    public var snapshot: EngineStoreSnapshot { core.snapshot }
    private var sinks: [UUID: WeakSink] = [:]
    private var refreshObservers: [UUID:(WireRequestID,[WireRefreshScheduled])->Void] = [:]

    public func observeRefreshReplies(_ observer:@escaping (WireRequestID,[WireRefreshScheduled])->Void) -> UUID {
        let token=UUID();refreshObservers[token]=observer;return token
    }
    public func removeRefreshReplyObserver(_ token:UUID) { refreshObservers.removeValue(forKey:token) }

    public init() {}

    @discardableResult
    public func attach(_ sink: any EngineStoreSink) -> UUID {
        let id = UUID()
        sinks[id] = WeakSink(sink)
        sink.apply(snapshot)
        return id
    }

    public func detach(_ id: UUID) { sinks.removeValue(forKey: id) }

    public func consume(_ event: EngineClientEvent) async {
        // No suspension or RPC: the UI/cache barrier is acknowledged only
        // after Core reset, synchronous sink clearing, and empty-state fanout.
        let effect = core.apply(event)
        if case .response(let requestID,.refresh(let reply))=event {
            for observer in Array(refreshObservers.values) { observer(requestID,reply.envelope.data) }
        }
        if case .clearPrivateViews(let invalidation) = effect {
            for sink in liveSinks() { sink.clearPrivateViews(invalidation) }
        }
        for sink in liveSinks() { sink.apply(snapshot) }
    }

    private func liveSinks() -> [any EngineStoreSink] {
        sinks = sinks.filter { $0.value.value != nil }
        return sinks.values.compactMap(\.value)
    }
}
