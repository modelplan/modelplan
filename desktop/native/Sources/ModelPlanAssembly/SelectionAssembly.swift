// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanSelection
import ModelPlanInstruments

/// Explicit offering facts from a native data adapter, never inferred from an account or harness binding.
public struct SubscriptionSelectionEvidence: Sendable {
    public let subscription: SelectionSubscription
    public let evidence: InstrumentEvidence
    public init(_ subscription: SelectionSubscription, evidence: InstrumentEvidence) {
        self.subscription = subscription; self.evidence = evidence
    }
}

/// A per-model, per-subscription event time. Source-wide totals/configuration are not historical use.
public struct AttributedSelectionUsage: Sendable {
    public let usage: SelectionUsage
    public let attribution: UsageAttribution
    public let evidence: InstrumentEvidence
    public init(_ usage: SelectionUsage, attribution: UsageAttribution, evidence: InstrumentEvidence) {
        self.usage = usage; self.attribution = attribution; self.evidence = evidence
    }
}

public struct AssembledModelSelection: Sendable {
    public let shared: SharedModelSelection
    public let instruments: InjectedModelSelection?
    public let unavailableReason: String?
}

/// The only bridge: validated Core publication -> shared selector -> injected instrument order.
/// Owns the personal expiry latch, but no ranking, file reads, CLI execution or rendering.
public struct SelectionAssembly: Sendable {
    private var ledger = ExpiryLedger()
    public init() {}

    public mutating func evaluate(joined: JoinedSnapshot, scope: SelectionScope,
                                  subscriptions: [SubscriptionSelectionEvidence],
                                  usage: [AttributedSelectionUsage], selectedID: String? = nil,
                                  now: Date) -> AssembledModelSelection {
        // Refresh the personal deadline even when a caller retains an older immutable joined value.
        let personal = PersonalProjection.evaluate(joined.personal, now: now, ledger: &ledger)
        let validated = JoinedSnapshot.make(personal: joined.personal, presentation: personal,
            publication: joined.publication,
            publicUsable: joined.scoredUnavailableReason == nil && joined.presentation.actionable)
        let publication = validated.publication.map(Self.publication)
        let offerings = subscriptions.map { row in
            row.evidence.usable(at: now) ? row.subscription :
                SelectionSubscription(id: row.subscription.id, availability: .unknown, offeredModelIDs: nil)
        }
        let events = usage.filter { $0.attribution == .verifiedSubscription && $0.evidence.usable(at: now) }.map(\.usage)
        let shared = ModelSelection.select(.init(scope: scope, publication: publication,
            subscriptions: offerings, usage: events, now: now))
        let reason: String?
        if validated.scoredUnavailableReason != nil { reason = validated.scoredUnavailableReason }
        else if publication?.selectionRevision?.isEmpty != false { reason = "selection-revision-unavailable" }
        else if subscriptions.isEmpty { reason = "subscription-evidence-unavailable" }
        else if shared.models.isEmpty && !shared.issues.isEmpty { reason = "selection-unavailable" }
        else { reason = nil }
        let instrumentScope: InstrumentScope
        switch scope { case .all: instrumentScope = .all; case .subscription(let id): instrumentScope = .subscription(id) }
        let injected = publication.map { publication in
            InjectedModelSelection(publication: .init(publicationID: publication.publicationID,
                selectionRevision: publication.selectionRevision), scope: instrumentScope,
                orderedModelIDs: shared.orderedIDs,
                selectedModelID: selectedID.flatMap { shared.orderedIDs.contains($0) ? $0 : nil },
                unavailableReason: reason,
                recentUseAtByModel: Dictionary(uniqueKeysWithValues: shared.models.compactMap { model in
                    if case .recentUsage(let at) = model.origin { return (model.id, at) }; return nil
                }))
        }
        return AssembledModelSelection(shared: shared, instruments: injected, unavailableReason: reason)
    }

    private static func publication(_ source: PublicPublication) -> ModelPlanSelection.SelectionPublication {
        let members = source.lineups.flatMap { $0.members ?? [] }
        let membersByID = Dictionary(grouping: members, by: \.id)
        return .init(publicationID: source.publicationId, selectionRevision: source.selectionRevision,
            models: source.models.flatMap { model in
                // Keep every explicitly different published context; the selector abstains on conflicts.
                var placements: [PublishedPlacement] = []
                for member in membersByID[model.id] ?? [] {
                    var placement: PublishedPlacement = .unspecified
                    if case .object(let value) = member.dominatedBy,
                       case .string(let id) = value["id"], !id.isEmpty,
                       case .string(let kind) = value["kind"] {
                        switch kind { case "equivalent": placement = .pricierTwin
                        case "weaker": placement = .dominated; default: break }
                    }
                    if !placements.contains(placement) { placements.append(placement) }
                }
                if placements.isEmpty { placements = [.unspecified] }
                return placements.map { placement in
                    SelectionModel(id: model.id, developerID: model.developerId, lineageID: model.lineageId,
                        lineageStatus: model.lineageStatus, defaultSelected: model.defaultSelected, placement: placement)
                }
            },
            picks: members.flatMap { member in
                (member.tags ?? []).compactMap { PublishedPickKind(rawValue: $0).map { PublishedPick(modelID: member.id, kind: $0) } }
            })
    }
}
