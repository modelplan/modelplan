// SPDX-License-Identifier: MIT
import Foundation

/// Published verdicts only. This consumer never derives tags/frontier membership from metrics.
public enum FieldPickerTag: String, Codable, CaseIterable, Hashable, Sendable {
    case strongest, bestValue = "best_value", cheapest, outclassed = "dominated", pricierTwin = "equivalent_costlier"
}
public struct FieldPickerVerdict: Equatable, Sendable {
    public let publicModelID: String, tags: [FieldPickerTag]
    public init(publicModelID: String, tags: [FieldPickerTag]) { self.publicModelID = publicModelID; self.tags = tags }
}
public enum FieldPickerPreset: String, Codable, Sendable { case mine, site, all, custom }

/// Public-ID inputs supplied by the existing selector/publication adapter, never personal objects.
public struct FieldPickerCatalogue: Sendable {
    public let projection: FieldPublicProjection
    public let scopeModelIDs: [String], siteModelIDs: [String], rosterModelIDs: [String]
    public let scopeFocusID: String?
    public let tags: [String: [FieldPickerTag]]
    public let developerNames: [String: String]
    private let ids: Set<String>
    public init(projection: FieldPublicProjection, scopeModelIDs: [String], siteModelIDs: [String],
                rosterModelIDs: [String]? = nil, scopeFocusID: String? = nil,
                verdictRevision: String? = nil, verdicts: [FieldPickerVerdict] = [], developerNames: [String: String] = [:]) throws {
        let ids = Set(projection.models.map(\.id))
        guard ids.count == projection.models.count, ids.count <= 256,
              ids.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }),
              verdicts.isEmpty || verdictRevision == projection.revision else { throw FieldContractError.invalidProjection }
        self.projection = projection; self.ids = ids
        func clean(_ values: [String]) -> [String] {
            var seen = Set<String>(); return values.filter { ids.contains($0) && seen.insert($0).inserted }
        }
        self.scopeModelIDs = clean(scopeModelIDs); self.siteModelIDs = clean(siteModelIDs)
        self.rosterModelIDs = clean((rosterModelIDs ?? projection.models.map(\.id)) + projection.models.map(\.id))
        self.scopeFocusID = scopeFocusID.flatMap { ids.contains($0) ? $0 : nil }
        // Ambiguous duplicate verdicts do not become a successful tag lookup.
        let grouped = Dictionary(grouping: verdicts.filter { ids.contains($0.publicModelID) }, by: \.publicModelID)
        tags = grouped.compactMapValues { rows in
            guard rows.count == 1 else { return nil }
            var seen = Set<FieldPickerTag>(); return rows[0].tags.filter { seen.insert($0).inserted }
        }
        self.developerNames = developerNames
    }
    public func contains(_ publicID: String) -> Bool { ids.contains(publicID) }
    public func clean(_ values: [String]) -> [String] {
        var seen = Set<String>(); return values.filter { ids.contains($0) && seen.insert($0).inserted }
    }
}

/// Field-local UI value. Persistence is returned to the existing owner; no store/timer is created.
public struct FieldFleetPicker: Sendable {
    public static let capacity = 10
    public private(set) var preset: FieldPickerPreset = .mine
    public private(set) var chosenIDs: [String]?
    public private(set) var focusedID: String?
    public private(set) var expanded = true
    public private(set) var maker: String?, query = ""
    private var legacyExtraIDs: [String]
    public init(catalogue: FieldPickerCatalogue, savedValue: Data? = nil, legacyExtraIDs: [String] = []) {
        self.legacyExtraIDs = catalogue.clean(legacyExtraIDs)
        guard let savedValue, savedValue.count <= 16 * 1024,
              let value = try? JSONSerialization.jsonObject(with: savedValue) as? [String: Any],
              let values = value["ids"] as? [Any] else { return }
        chosenIDs = Array(catalogue.clean(values.compactMap { $0 as? String }).prefix(Self.capacity))
        preset = (value["preset"] as? String).flatMap(FieldPickerPreset.init(rawValue:)) ?? .custom
    }
    public func selectedIDs(in catalogue: FieldPickerCatalogue) -> [String] {
        Array(catalogue.clean(chosenIDs ?? (catalogue.scopeModelIDs + legacyExtraIDs)).prefix(Self.capacity))
    }
    public func effectiveFocus(in catalogue: FieldPickerCatalogue) -> String? {
        let ids = selectedIDs(in: catalogue)
        if let focusedID, ids.contains(focusedID) { return focusedID }
        if let scope = catalogue.scopeFocusID, ids.contains(scope) { return scope }
        return ids.first
    }
    @discardableResult public mutating func setLaunched(_ enabled: Bool, publicID: String, in catalogue: FieldPickerCatalogue) -> Bool {
        guard catalogue.contains(publicID) else { return false }
        let ids = selectedIDs(in: catalogue)
        guard !enabled || ids.contains(publicID) || ids.count < Self.capacity else { return false }
        chosenIDs = enabled ? catalogue.clean(ids + [publicID]) : ids.filter { $0 != publicID }
        if !enabled, focusedID == publicID { focusedID = nil }
        return true
    }
    @discardableResult public mutating func focus(_ publicID: String, in catalogue: FieldPickerCatalogue) -> Bool {
        guard catalogue.contains(publicID) else { return false }
        if !selectedIDs(in: catalogue).contains(publicID), !setLaunched(true, publicID: publicID, in: catalogue) { return false }
        focusedID = publicID; return true
    }
    public mutating func selectPreset(_ next: FieldPickerPreset, in catalogue: FieldPickerCatalogue) {
        guard next != .custom else { return }
        preset = next; maker = nil; query = ""
        let ids: [String]
        switch next {
        case .mine: ids = catalogue.scopeModelIDs
        case .site: ids = catalogue.siteModelIDs
        case .all: ids = catalogue.projection.models.map(\.id)
        case .custom: return
        }
        chosenIDs = Array(catalogue.clean(ids).prefix(Self.capacity))
        if let focusedID, !chosenIDs!.contains(focusedID) { self.focusedID = nil }
    }
    public mutating func reset(in catalogue: FieldPickerCatalogue) { selectPreset(.mine, in: catalogue) }
    public mutating func setExpanded(_ expanded: Bool) { self.expanded = expanded }
    public mutating func filter(maker: String? = nil, query: String = "") { self.maker = maker; self.query = query }
    public mutating func reconcile(with catalogue: FieldPickerCatalogue) {
        if let chosenIDs { self.chosenIDs = Array(catalogue.clean(chosenIDs).prefix(Self.capacity)) }
        if let focusedID, !catalogue.contains(focusedID) { self.focusedID = nil }
    }
    /// Exactly public IDs and preset. Names, tags, accounts, sessions and scope refs never persist here.
    public func savedValue(in catalogue: FieldPickerCatalogue) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["ids": selectedIDs(in: catalogue), "preset": preset.rawValue], options: [.sortedKeys])
    }
}
