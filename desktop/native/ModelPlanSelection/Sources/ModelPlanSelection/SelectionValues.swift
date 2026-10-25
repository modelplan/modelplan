// SPDX-License-Identifier: MIT
import Foundation

public enum SelectionScope: Equatable, Sendable { case all, subscription(String) }
public enum SubscriptionAvailability: Equatable, Sendable { case available, unavailable, unknown }
public enum PublishedExclusion: Equatable, Sendable { case legacy, retired }
public enum PublishedPlacement: Equatable, Sendable { case unspecified, mainstay, dominated, pricierTwin }
public enum PublishedPickKind: String, CaseIterable, Equatable, Sendable {
    case strongest, bestValue = "best_value", cheapest
}

/// Native DTO, not a new CLI schema. All flags are producer facts; nil remains unknown.
/// There are deliberately no names, versions, scores or capability-status inputs.
public struct SelectionModel: Equatable, Sendable {
    public let id: String
    public let developerID: String?
    public let lineageID: String?
    public let lineageStatus: String?
    public let defaultSelected: Bool?
    public let exclusion: PublishedExclusion?
    public let placement: PublishedPlacement
    public init(id: String, developerID: String?, lineageID: String?, lineageStatus: String?,
                defaultSelected: Bool?, exclusion: PublishedExclusion? = nil,
                placement: PublishedPlacement = .unspecified) {
        self.id = id; self.developerID = developerID; self.lineageID = lineageID
        self.lineageStatus = lineageStatus; self.defaultSelected = defaultSelected
        self.exclusion = exclusion; self.placement = placement
    }
}
public struct PublishedPick: Equatable, Sendable {
    public let modelID: String
    public let kind: PublishedPickKind
    public init(modelID: String, kind: PublishedPickKind) { self.modelID = modelID; self.kind = kind }
}
public struct SelectionPublication: Equatable, Sendable {
    public let publicationID: String
    public let selectionRevision: String?
    public let models: [SelectionModel]
    public let picks: [PublishedPick]
    /// Preserve the publication's model and lineup-member order. Picks are already published verdicts.
    public init(publicationID: String, selectionRevision: String?, models: [SelectionModel], picks: [PublishedPick]) {
        self.publicationID = publicationID; self.selectionRevision = selectionRevision
        self.models = models; self.picks = picks
    }
}
public struct SelectionSubscription: Equatable, Sendable {
    public let id: String
    public let availability: SubscriptionAvailability
    /// Nil is unknown offerings; an empty set is a known empty offering. IDs are canonical, already joined.
    public let offeredModelIDs: Set<String>?
    public init(id: String, availability: SubscriptionAvailability, offeredModelIDs: Set<String>?) {
        self.id = id; self.availability = availability; self.offeredModelIDs = offeredModelIDs
    }
}
public struct SelectionUsage: Equatable, Sendable {
    public let modelID: String, subscriptionID: String
    public let usedAt: Date
    /// Exact attributed per-model event time only. Never substitute evaluation now or SessionRank.lastAt.
    public init(modelID: String, subscriptionID: String, usedAt: Date) {
        self.modelID = modelID; self.subscriptionID = subscriptionID; self.usedAt = usedAt
    }
}
/// Membership in a fresh, upstream-validated recent7d summary with positive usage for this configuration.
/// There is deliberately no event timestamp. Canonical model/subscription attribution is resolved upstream.
public struct SelectionWindowUsage: Equatable, Sendable {
    public let modelID: String, subscriptionID: String
    public init(modelID: String, subscriptionID: String) {
        self.modelID = modelID; self.subscriptionID = subscriptionID
    }
}
public struct SelectionInput: Sendable {
    public let scope: SelectionScope
    public let publication: SelectionPublication?
    public let subscriptions: [SelectionSubscription]
    public let usage: [SelectionUsage]
    public let windowUsage: [SelectionWindowUsage]
    public let now: Date
    public init(scope: SelectionScope, publication: SelectionPublication?, subscriptions: [SelectionSubscription],
                usage: [SelectionUsage], windowUsage: [SelectionWindowUsage] = [], now: Date) {
        self.scope = scope; self.publication = publication; self.subscriptions = subscriptions
        self.usage = usage; self.windowUsage = windowUsage; self.now = now
    }
}

public enum SelectionIssueReason: Equatable, Sendable {
    case publicationUnavailable, invalidReferenceTime, unknownScope, invalidSubscriptionID, conflictingSubscriptionID
    case subscriptionUnavailable, subscriptionAvailabilityUnknown, offeringsUnknown, modelNotPublished
    case invalidModelID, conflictingModelID, unknownLineageID, unknownLineageStatus, unsupportedLineageStatus
    case unknownGlobalDefault, notGlobalDefault, retired, legacy, preview, olderNotRecentlyUsed
    case ambiguousCurrentLineage, unknownDeveloper, invalidUsageTime
}
public struct SelectionIssue: Equatable, Sendable {
    public let reason: SelectionIssueReason
    public let modelID: String?
    public let subscriptionID: String?
    init(_ reason: SelectionIssueReason, modelID: String? = nil, subscriptionID: String? = nil) {
        self.reason = reason; self.modelID = modelID; self.subscriptionID = subscriptionID
    }
}
public enum SelectionOrigin: Equatable, Sendable {
    case recentUsage(Date), recentWindow, publishedDefaultFallback
    case publishedPick(PublishedPickKind), developerRoundRobin, publishedTail
}
public struct SelectedModel: Equatable, Sendable {
    public let model: SelectionModel
    public let origin: SelectionOrigin
    public var id: String { model.id }
    public var isOlder: Bool { model.lineageStatus == "older" }
}
public struct SharedModelSelection: Equatable, Sendable {
    public let scope: SelectionScope
    public let publicationID: String?
    public let selectionRevision: String?
    public let models: [SelectedModel]
    public let issues: [SelectionIssue]
    public var orderedIDs: [String] { models.map(\.id) }
    public var fieldIDs: [String] { Array(orderedIDs.prefix(10)) }
    public var chartIDs: [String] { Array(fieldIDs.prefix(6)) }
    public var rowIDs: [String] { Array(chartIDs.prefix(3)) }
}

/// Highlight is independent of selection ordering. No click can promote a model into the first three.
public struct ModelSelectionState: Equatable, Sendable {
    public private(set) var selection: SharedModelSelection
    public private(set) var selectedID: String?
    public init(selection: SharedModelSelection) { self.selection = selection }
    public mutating func replace(_ selection: SharedModelSelection) {
        self.selection = selection
        if let selectedID, !selection.orderedIDs.contains(selectedID) { self.selectedID = nil }
    }
    @discardableResult public mutating func select(_ id: String) -> Bool {
        guard selection.orderedIDs.contains(id) else { return false }
        selectedID = id; return true
    }
}
