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

/// Optional synchronous delivery of the exact accepted event, with its original request ID.
@MainActor public protocol EngineStoreEventSink: EngineStoreSink {
    func acceptedEvent(_ event: EngineClientEvent)
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
    private var readerLog = ReaderStateLog()
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
        switch event {
        case .rowsChanged, .clearPrivateViews:
            for line in readerLog.changes(core.snapshot.rows) { DiagnosticsLog.shared.info("readers", line) }
        default: break
        }
        if case .response(let requestID,.refresh(let reply))=event {
            for observer in Array(refreshObservers.values) { observer(requestID,reply.envelope.data) }
        }
        if case .clearPrivateViews(let invalidation) = effect {
            for sink in liveSinks() { sink.clearPrivateViews(invalidation) }
        }
        for sink in liveSinks() {
            (sink as? any EngineStoreEventSink)?.acceptedEvent(event)
            sink.apply(snapshot)
        }
    }

    private func liveSinks() -> [any EngineStoreSink] {
        sinks = sinks.filter { $0.value.value != nil }
        return sinks.values.compactMap(\.value)
    }
}

/// One app-log line per tool reader whose state or cause changes: tool id, state and cause code only. Declared
/// rows (whose ids the user chose) and account values are never logged.
struct ReaderStateLog {
    private var last: [String: String] = [:]
    mutating func changes(_ rows: WireRowsSnapshot?) -> [String] {
        guard let rows else { last = [:]; return [] } // the clear itself is logged by the engine client
        var next: [String: String] = [:], lines: [String] = []
        for row in rows.projection.rows where row.kind == .tool && !row.invalid {
            let tool = DiagnosticsLog.safeID(row.id)
            let value = "state=" + DiagnosticsLog.safeID(row.state.rawValue) + " cause=" + DiagnosticsLog.safeID(row.reason.code.rawValue)
            if next[tool] != nil { continue }
            next[tool] = value
            if last[tool] != value { lines.append("reader " + tool + " " + value + (last[tool].map { " was " + $0 } ?? "")) }
        }
        for tool in last.keys.sorted() where next[tool] == nil { lines.append("reader " + tool + " gone") }
        last = next
        return lines
    }
}
