// SPDX-License-Identifier: MIT
import Foundation

public enum DockLogicError: Error, Equatable {
    case invalidCatalogue, missingSubscription, staleReorder, invalidTime, staleGeneration
}

/// Only local presentation preferences. No account observations or credentials are persisted.
public struct DockSubscriptionPreferences: Codable, Equatable, Sendable {
    public private(set) var order: [String]
    public var hiddenIDs: Set<String>
    public init(order: [String] = [], hiddenIDs: Set<String> = []) {
        var seen = Set<String>()
        self.order = order.filter { !$0.isEmpty && seen.insert($0).inserted }
        self.hiddenIDs = hiddenIDs.filter { !$0.isEmpty }
    }
    private enum CodingKeys: CodingKey { case order, hiddenIDs }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(order: try c.decodeIfPresent([String].self, forKey: .order) ?? [],
                  hiddenIDs: Set(try c.decodeIfPresent([String].self, forKey: .hiddenIDs) ?? []))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(order, forKey: .order); try c.encode(hiddenIDs.sorted(), forKey: .hiddenIDs)
    }
    public func orderedIDs(in catalogue: [String], visibleOnly: Bool = false) throws -> [String] {
        guard !catalogue.contains(""), Set(catalogue).count == catalogue.count else { throw DockLogicError.invalidCatalogue }
        let available = Set(catalogue), preferred = Set(order)
        let result = order.filter { available.contains($0) } + catalogue.filter { !preferred.contains($0) }
        return visibleOnly ? result.filter { !hiddenIDs.contains($0) } : result
    }
    public mutating func move(_ id: String, to index: Int, in catalogue: [String]) throws {
        var ids = try orderedIDs(in: catalogue)
        guard let from = ids.firstIndex(of: id), ids.indices.contains(index) else { throw DockLogicError.missingSubscription }
        ids.remove(at: from); ids.insert(id, at: index)
        // Retain missing IDs at their preference slots for a later reconnect; never invent new IDs.
        let active = Set(ids); var cursor = ids.makeIterator()
        var next = order.map { active.contains($0) ? cursor.next()! : $0 }
        while let id = cursor.next() { next.append(id) }
        order = next
    }
    public mutating func resetOrder() { order = [] }
    public func beginReorder(_ id: String, in catalogue: [String]) throws -> DockReorderSession {
        let ids = try orderedIDs(in: catalogue)
        guard ids.contains(id) else { throw DockLogicError.missingSubscription }
        return DockReorderSession(source: id, catalogue: catalogue, original: ids, basePreference: order)
    }
}

/// A preview never writes preferences. A catalogue/order change invalidates commit; cancel is final.
public struct DockReorderSession: Sendable {
    public let source: String
    public private(set) var preview: [String]
    private let catalogue: [String], original: [String], basePreference: [String]
    private var finished = false
    fileprivate init(source: String, catalogue: [String], original: [String], basePreference: [String]) {
        self.source = source; self.catalogue = catalogue; self.original = original
        self.basePreference = basePreference; preview = original
    }
    public mutating func hover(over id: String) throws {
        guard !finished else { throw DockLogicError.staleReorder }
        guard let target = original.firstIndex(of: id), let from = original.firstIndex(of: source) else { throw DockLogicError.missingSubscription }
        // Target's original index matches the existing drop rule. Repeated hover is idempotent.
        preview = original; preview.remove(at: from); preview.insert(source, at: target)
    }
    public mutating func cancel() { finished = true; preview = original }
    public mutating func commit(into preferences: inout DockSubscriptionPreferences, catalogue current: [String]) throws {
        guard !finished, current == catalogue, preferences.order == basePreference,
              try preferences.orderedIDs(in: current) == original else { finished = true; throw DockLogicError.staleReorder }
        guard let target = preview.firstIndex(of: source) else { throw DockLogicError.missingSubscription }
        try preferences.move(source, to: target, in: current); finished = true
    }
}
