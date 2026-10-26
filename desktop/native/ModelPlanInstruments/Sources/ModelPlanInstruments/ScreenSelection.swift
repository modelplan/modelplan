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
    public let publicDefaultFallback: Bool
    public let selectionNotice: String?
    /// Caller-localized tool/use descriptions; these are not subscription-entitlement claims.
    public let modelAvailabilityNotes: [String: String]
    public init(publication: SelectionPublication, scope: InstrumentScope, orderedModelIDs: [String],
                selectedModelID: String? = nil, unavailableReason: String? = nil, recentUseAtByModel: [String: Date] = [:],
                publicDefaultFallback: Bool = false, selectionNotice: String? = nil, modelAvailabilityNotes: [String: String] = [:]) {
        self.publication = publication; self.scope = scope; self.orderedModelIDs = orderedModelIDs
        self.selectedModelID = selectedModelID; self.unavailableReason = unavailableReason
        self.recentUseAtByModel = recentUseAtByModel
        self.publicDefaultFallback = publicDefaultFallback; self.selectionNotice = selectionNotice
        self.modelAvailabilityNotes = modelAvailabilityNotes
    }
    public func matches(_ publication: SelectionPublication?, scope: InstrumentScope) -> Bool {
        guard publicDefaultFallback else { return matchesExact(publication, scope: scope) }
        guard let publication, !publication.publicationID.isEmpty,
              self.publication.publicationID == publication.publicationID, self.scope == scope else { return false }
        let actual = self.publication.selectionRevision.flatMap { $0.isEmpty ? nil : $0 }
        let expected = publication.selectionRevision.flatMap { $0.isEmpty ? nil : $0 }
        // The explicit catalogue mode may lack a revision; known conflicting revisions are not a missing-revision case.
        if let actual, let expected, actual != expected { return false }
        return true
    }
    /// Exact/scored consumers keep the original gate; catalogue fallback never attests an exact selection.
    public func matchesExact(_ publication: SelectionPublication?, scope: InstrumentScope) -> Bool {
        guard !publicDefaultFallback else { return false }
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
    public let publicDefaultFallback: Bool
    public let selectionNotice: String?
    public let modelAvailabilityNotes: [String: String]
    public let emptyStateNotice: String?
    public init(models: [InstrumentModel], selection: InjectedModelSelection?, scope: InstrumentScope,
                publication: SelectionPublication?, publicationUsable: Bool, language: InstrumentLanguage = .english) {
        self.publication = publication
        publicDefaultFallback = selection?.publicDefaultFallback ?? false
        selectionNotice = selection?.selectionNotice
        let emptyNotice = language == .chinese ? "暂无可显示的公开模型数据" : "No public model data is available to display."
        guard publicationUsable || publicDefaultFallback, let selection, selection.matches(publication, scope: scope) else {
            self.models = []; orderedModelIDs = []; missingModelIDs = []; selectedModelID = nil
            recentUseAtByModel = [:]
            modelAvailabilityNotes = [:]; emptyStateNotice = emptyNotice
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
        modelAvailabilityNotes = selection.modelAvailabilityNotes.filter { visibleIDs.contains($0.key) }
        missingModelIDs = orderedModelIDs.filter { available[$0] == nil }
        selectedModelID = selection.selectedModelID.flatMap { id in visible.contains { $0.id == id } ? id : nil }
        unavailableReason = nil
        emptyStateNotice = visible.isEmpty ? emptyNotice : nil
    }
}
