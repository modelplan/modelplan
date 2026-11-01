// SPDX-License-Identifier: MIT
import Foundation

/// App-owned reset-event state. IDs are public event identities, not account IDs.
@MainActor public final class EngineResetEventLedger {
    private struct State:Codable {
        var acknowledged:Set<String> = []
        var delivered:Set<String> = []
    }
    private let url:URL
    private var state:State
    public init(url:URL) throws {
        self.url=url
        if FileManager.default.fileExists(atPath:url.path) {
            state=try JSONDecoder().decode(State.self,from:Data(contentsOf:url))
        } else { state=State() }
    }
    public var acknowledged:Set<String> { state.acknowledged }
    public func wasDelivered(_ id:String) -> Bool { state.delivered.contains(id) }
    public func acknowledge(_ id:String) throws {
        guard !id.isEmpty else { return }
        var next=state;next.acknowledged.insert(id);try save(next)
    }
    public func recordDelivered(_ id:String) throws {
        guard !id.isEmpty else { return }
        var next=state;next.delivered.insert(id);try save(next)
    }
    private func save(_ next:State) throws {
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        try JSONEncoder().encode(next).write(to:url,options:.atomic)
        state=next
    }
}
