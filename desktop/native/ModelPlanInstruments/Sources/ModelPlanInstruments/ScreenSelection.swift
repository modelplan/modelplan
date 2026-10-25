// SPDX-License-Identifier: MIT
import Foundation

/// Exact CLI-published facts. nil is unknown; false remains an explicit negative.
/// This value neither selects a representative nor infers a status from names, scores or lineup ability status.
public struct InstrumentLineage: Codable, Equatable, Sendable {
    public let lineageId: String?
    public let lineageStatus: String?
    public let defaultSelected: Bool?
    public let current: Bool?
    public init(lineageId: String? = nil, lineageStatus: String? = nil, defaultSelected: Bool? = nil, current: Bool? = nil) {
        self.lineageId = lineageId; self.lineageStatus = lineageStatus
        self.defaultSelected = defaultSelected; self.current = current
    }
}

public struct SelectionPublication: Equatable, Sendable {
    public let publicationID: String
    public let selectionRevision: String?
    public init(publicationID: String, selectionRevision: String?) {
        self.publicationID = publicationID; self.selectionRevision = selectionRevision
    }
}

/// Ordered result injected from the ONE shared scope selector owned by M2.
/// No ranking, lineage eligibility, seven-day cutoff or 10/6/3-cap policy is repeated in this module.
public struct InjectedModelSelection: Sendable {
    public let publication: SelectionPublication
    public let scope: InstrumentScope
    public let orderedModelIDs: [String]
    public let selectedModelID: String?
    public let unavailableReason: String?
    public let recentUseAtByModel: [String: Date]
    public init(publication: SelectionPublication, scope: InstrumentScope, orderedModelIDs: [String],
                selectedModelID: String? = nil, unavailableReason: String? = nil, recentUseAtByModel: [String: Date] = [:]) {
        self.publication = publication; self.scope = scope; self.orderedModelIDs = orderedModelIDs
        self.selectedModelID = selectedModelID; self.unavailableReason = unavailableReason
        self.recentUseAtByModel = recentUseAtByModel
    }
    public func matches(_ publication: SelectionPublication?, scope: InstrumentScope) -> Bool {
        guard let publication, !publication.publicationID.isEmpty,
              let revision = publication.selectionRevision, !revision.isEmpty else { return false }
        return self.publication == publication && self.scope == scope && unavailableReason == nil
    }
}

public struct EffortPagePresentation: Sendable {
    public let models: [InstrumentModel]
    public let orderedModelIDs: [String]
    public let missingModelIDs: [String]
    public let selectedModelID: String?
    public let publication: SelectionPublication?
    public let unavailableReason: String?
    public let recentUseAtByModel: [String: Date]
    public init(models: [InstrumentModel], selection: InjectedModelSelection?, scope: InstrumentScope,
                publication: SelectionPublication?, publicationUsable: Bool) {
        self.publication = publication
        guard publicationUsable, let selection, selection.matches(publication, scope: scope) else {
            self.models = []; orderedModelIDs = []; missingModelIDs = []; selectedModelID = nil
            recentUseAtByModel = [:]
            unavailableReason = selection?.unavailableReason ?? (publicationUsable ? "selection-unavailable-or-mismatched" : "publication-unavailable")
            return
        }
        var seen = Set<String>()
        orderedModelIDs = selection.orderedModelIDs.filter { seen.insert($0).inserted }
        let grouped = Dictionary(grouping: models, by: \.id)
        // A duplicate model ID is ambiguous; never silently pick a different model/effort row.
        let available = grouped.compactMapValues { $0.count == 1 ? $0.first : nil }
        let visible = orderedModelIDs.compactMap { available[$0] }
        self.models = visible
        let visibleIDs = Set(visible.map(\.id))
        recentUseAtByModel = selection.recentUseAtByModel.filter { visibleIDs.contains($0.key) }
        missingModelIDs = orderedModelIDs.filter { available[$0] == nil }
        selectedModelID = selection.selectedModelID.flatMap { id in visible.contains { $0.id == id } ? id : nil }
        unavailableReason = nil
    }
}
