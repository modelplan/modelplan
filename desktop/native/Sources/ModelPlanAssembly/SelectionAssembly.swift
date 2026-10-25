// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanSelection
import ModelPlanInstruments

public struct SelectionMappingIssue: Equatable, Sendable {
    public enum Reason: Equatable, Sendable { case unsupportedDominance }
    public let modelID: String
    public let reason: Reason
}

public enum SessionOwnershipBasis: String, Sendable { case explicitSubscription, uniqueSource }
public struct SessionWindowEvidence: Sendable {
    public let modelID: String, subscriptionID: String
    public let ownership: SessionOwnershipBasis
    // This is window membership, deliberately not a per-model event timestamp.
}
public struct AssembledModelSelection: Sendable {
    public let mappingIssues: [SelectionMappingIssue]
    public let shared: SharedModelSelection
    public let instruments: InjectedModelSelection?
    public let models: [InstrumentModel]
    public let unavailableReason: String?
    public let publicDefaultFallback: Bool
    public let selectionNotice: String?
    public let modelAvailabilityNotes: [String: String]
    public let sessionEvidence: [SessionWindowEvidence]
    public let emptyStateMessage: String
    public let language: InstrumentLanguage
    public var effortPage: EffortPagePresentation? {
        instruments.map { .init(models:models,selection:$0,scope:$0.scope,
            publication:$0.publication,publicationUsable:true,language:language) }
    }
}

/// Current runtime policy: public defaults, tool compatibility and observed session-window membership.
/// This never declares account entitlements or fabricates a per-model usage instant.
public struct SelectionAssembly: Sendable {
    private var ledger = ExpiryLedger()
    public init() {}

    public mutating func evaluate(feeds: ModelSelectionFeeds, scope: SelectionScope,
                                  selectedID: String? = nil, language: InstrumentLanguage = .chinese,
                                  now: Date) -> AssembledModelSelection {
        let chinese = language == .chinese
        let defaultNote = chinese ? "按公开默认" : "Public defaults"
        let toolNote = chinese ? "该工具可用" : "Available in this tool"
        let usedNote = chinese ? "实际用过" : "Observed use"
        let noData = chinese ? "公开默认车队暂未加载" : "Public default fleet is not loaded yet"
        guard let source = feeds.publication, !source.publicationId.isEmpty, source.supportedUnits else {
            let empty = ModelSelection.select(.init(scope:scope,publication:nil,subscriptions:[],usage:[],now:now))
            return .init(mappingIssues:[],shared:empty,instruments:nil,models:[],unavailableReason:"publication-unavailable",
                publicDefaultFallback:true,selectionNotice:defaultNote,modelAvailabilityNotes:[:],sessionEvidence:[],emptyStateMessage:noData,language:language)
        }
        let mapped = Self.publication(source)
        let publication = mapped.publication
        let allIDs = Set(publication.models.map(\.id))
        var bindings: [String: Set<String>] = [:]
        var sourceOwners: [String: Set<String>] = [:]
        var personalFresh = false
        if let personal = feeds.personal {
            let projection = PersonalProjection.evaluate(personal,now:now,ledger:&ledger)
            personalFresh = feeds.personalUsable && projection.actionable && personal.generatedAt.date <= now
            if personalFresh {
                for binding in personal.subscriptions ?? [] where !binding.subscriptionRef.isEmpty {
                    for source in binding.sources ?? [] where !source.isEmpty {
                        bindings[binding.subscriptionRef,default:[]].insert(source)
                        sourceOwners[source,default:[]].insert(binding.subscriptionRef)
                    }
                }
            }
        }
        var evidence: [SessionWindowEvidence] = []
        if personalFresh, let personal = feeds.personal {
            evidence = Self.windowEvidence(personal:personal,publication:source,sourceOwners:sourceOwners,now:now)
        }
        let windowUsage = evidence.map { SelectionWindowUsage(modelID:$0.modelID,subscriptionID:$0.subscriptionID) }
        let actualIDs: Set<String>
        if case .subscription(let id) = scope { actualIDs = Set(evidence.filter { $0.subscriptionID == id }.map(\.modelID)) }
        else { actualIDs = Set(evidence.map(\.modelID)) }
        var toolIDs: Set<String> = []
        var subscriptions: [SelectionSubscription] = []
        var fallback = !personalFresh || feeds.publicIsLastGood
        switch scope {
        case .all:
            // The virtual source is a public catalog, not a detected/paid account.
            let virtual = "public-catalog:" + source.publicationId
            let owners = Set(evidence.map(\.subscriptionID)).union([virtual])
            subscriptions = owners.sorted().map { .init(id:$0,availability:.available,offeredModelIDs:allIDs) }
        case .subscription(let id):
            let sources = bindings[id] ?? []
            toolIDs = Set(source.models.filter { model in
                sources.contains { harness in (model.harnessIds?[harness] ?? []).contains { !$0.isEmpty } }
            }.map(\.id))
            let candidates = toolIDs.union(actualIDs)
            if !sources.isEmpty || !actualIDs.isEmpty {
                subscriptions = [.init(id:id,availability:.available,offeredModelIDs:candidates)]
            } else { fallback = true }
        }
        var shared = ModelSelection.select(.init(scope:scope,publication:publication,
            subscriptions:subscriptions,usage:[],windowUsage:windowUsage,now:now))
        if shared.models.isEmpty || publication.selectionRevision?.isEmpty != false || fallback {
            shared = ModelSelection.publicDefaults(publication:publication,scope:scope)
            fallback = true
        }
        let notice = fallback ? defaultNote : nil
        var labels: [String: String] = [:]
        if !fallback, case .subscription = scope {
            for id in shared.orderedIDs {
                labels[id] = toolIDs.contains(id) ? toolNote : actualIDs.contains(id) ? usedNote : nil
            }
        }
        let instrumentScope: InstrumentScope
        switch scope { case .all: instrumentScope = .all; case .subscription(let id): instrumentScope = .subscription(id) }
        let noModels = shared.models.isEmpty
        let injected = InjectedModelSelection(publication:.init(publicationID:source.publicationId,
            selectionRevision:source.selectionRevision),scope:instrumentScope,orderedModelIDs:shared.orderedIDs,
            selectedModelID:selectedID.flatMap { shared.orderedIDs.contains($0) ? $0 : nil },
            unavailableReason:noModels ? "public-default-unavailable" : nil,recentUseAtByModel:[:],
            publicDefaultFallback:fallback,selectionNotice:notice,modelAvailabilityNotes:labels)
        return .init(mappingIssues:mapped.issues,shared:shared,instruments:injected,models:Self.instrumentModels(source),
            unavailableReason:noModels ? "public-default-unavailable" : nil,publicDefaultFallback:fallback,
            selectionNotice:notice,modelAvailabilityNotes:labels,sessionEvidence:evidence,emptyStateMessage:noModels ? noData : "",language:language)
    }

    private static func instrumentModels(_ source: PublicPublication) -> [InstrumentModel] {
        source.models.map { model in
            let efforts = (model.efforts ?? []).filter { $0.available != false }.map { effort in
                let timeBasis: String?
                if case .string(let value) = effort.timeBasis { timeBasis = value } else { timeBasis = nil }
                return InstrumentEffort(key:effort.effort,label:effort.label ?? effort.effort,
                    ability:.init(effort.ability,basis:effort.abilityBasis),
                    cost:.init(effort.cost,basis:effort.costBasisId),time:.init(effort.time,basis:timeBasis))
            }
            // A publication cannot establish the user's current effort or fast tier.
            return InstrumentModel(id:model.id,name:model.name ?? model.id,efforts:efforts,
                recommended:model.recommended,current:nil,lineage:.init(lineageId:model.lineageId,
                    lineageStatus:model.lineageStatus,defaultSelected:model.defaultSelected,current:model.current))
        }
    }

    private struct SessionModelKey: Hashable { let modelID: String; let subscriptionID: String }
    private static func windowEvidence(personal: PersonalSnapshot, publication: PublicPublication,
                                       sourceOwners: [String:Set<String>], now: Date) -> [SessionWindowEvidence] {
        guard personal.validUntil.map({ $0.date > now }) == true,
              personal.sessionRanking?.measure == "observed-output-tokens" else { return [] }
        let byID = Dictionary(grouping:publication.models,by:\.id)
        var aliases: [AliasKey:Set<String>] = [:]
        for model in publication.models {
            for (source,names) in model.harnessIds ?? [:] {
                for name in names { aliases[.init(harness:source,id:name),default:[]].insert(model.id) }
            }
        }
        var result: [SessionWindowEvidence] = []
        var indices: [SessionModelKey:Int] = [:]
        for session in personal.sessionRanking?.recent7d?.top ?? [] {
            if let last = session.lastAt?.date, last > personal.generatedAt.date { continue }
            let owner: String, basis: SessionOwnershipBasis
            if let id = session.subscriptionRef, !id.isEmpty { owner = id; basis = .explicitSubscription }
            else if let source = session.source, let ids = sourceOwners[source], ids.count == 1, let id = ids.first {
                owner = id; basis = .uniqueSource
            } else { continue }
            for config in session.configs ?? [] where (config.observedOutputTokens ?? 0) > 0 {
                var candidates = aliases[.init(harness:session.source ?? "",id:config.model)] ?? []
                if byID[config.model] != nil { candidates.insert(config.model) }
                guard candidates.count == 1, let id = candidates.first, byID[id]?.count == 1 else { continue }
                let key = SessionModelKey(modelID:id,subscriptionID:owner)
                if let index = indices[key] {
                    if basis == .explicitSubscription {
                        result[index] = .init(modelID:id,subscriptionID:owner,ownership:basis)
                    }
                } else {
                    indices[key] = result.count
                    result.append(.init(modelID:id,subscriptionID:owner,ownership:basis))
                }
            }
        }
        return result
    }

    private struct MappedPublication {
        let publication: ModelPlanSelection.SelectionPublication
        let issues: [SelectionMappingIssue]
    }
    private static func publication(_ source: PublicPublication) -> MappedPublication {
        let members = source.lineups.flatMap { $0.members ?? [] }
        let membersByID = Dictionary(grouping: members, by: \.id)
        var issues: [SelectionMappingIssue] = [], quarantined = Set<String>()
        let models = source.models.flatMap { model -> [SelectionModel] in
            // Keep every explicitly different readable context; the selector abstains on conflicts.
            var placements: [PublishedPlacement] = []
            for member in membersByID[model.id] ?? [] {
                let placement: PublishedPlacement
                switch member.dominatedBy {
                case nil, .some(.null): placement = .unspecified
                case .some(.object(let value)):
                    if case .string(let id) = value["id"], !id.isEmpty,
                       case .string(let kind) = value["kind"], ["equivalent", "weaker"].contains(kind) {
                        placement = kind == "equivalent" ? .pricierTwin : .dominated
                    } else {
                        if quarantined.insert(model.id).inserted { issues.append(.init(modelID:model.id, reason:.unsupportedDominance)) }
                        return []
                    }
                default:
                    if quarantined.insert(model.id).inserted { issues.append(.init(modelID:model.id, reason:.unsupportedDominance)) }
                    return []
                }
                if !placements.contains(placement) { placements.append(placement) }
            }
            if placements.isEmpty { placements = [.unspecified] }
            return placements.map { placement in
                SelectionModel(id: model.id, developerID: model.developerId, lineageID: model.lineageId,
                    lineageStatus: model.lineageStatus, defaultSelected: model.defaultSelected, placement: placement)
            }
        }
        // Quarantine all duplicate records for an unreadable model, not just the first context.
        let publication = ModelPlanSelection.SelectionPublication(publicationID: source.publicationId,
            selectionRevision: source.selectionRevision, models: models.filter { !quarantined.contains($0.id) },
            picks: members.filter { !quarantined.contains($0.id) }.flatMap { member in
                (member.tags ?? []).compactMap { PublishedPickKind(rawValue: $0).map { PublishedPick(modelID: member.id, kind: $0) } }
            })
        return MappedPublication(publication:publication, issues:issues)
    }
}
