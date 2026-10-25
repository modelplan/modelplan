// SPDX-License-Identifier: MIT
import Foundation

public enum ModelSelection {
    public static let recentUseInterval: TimeInterval = 7 * 24 * 60 * 60

    public static func select(_ input: SelectionInput) -> SharedModelSelection {
        var issues: [SelectionIssue] = []
        func result(_ models: [SelectedModel] = []) -> SharedModelSelection {
            SharedModelSelection(scope: input.scope, publicationID: input.publication?.publicationID,
                selectionRevision: input.publication?.selectionRevision, models: models, issues: issues)
        }
        guard let publication = input.publication else { issues.append(.init(.publicationUnavailable)); return result() }
        guard input.now.timeIntervalSinceReferenceDate.isFinite else { issues.append(.init(.invalidReferenceTime)); return result() }

        var subscriptions: [String: SelectionSubscription] = [:], badSubscriptions: Set<String> = []
        for subscription in input.subscriptions {
            guard !subscription.id.isEmpty else { issues.append(.init(.invalidSubscriptionID)); continue }
            if let old = subscriptions[subscription.id], old != subscription { badSubscriptions.insert(subscription.id) }
            else { subscriptions[subscription.id] = subscription }
        }
        var scoped: [SelectionSubscription] = [], seenSubscriptions: Set<String> = []
        for subscription in input.subscriptions where seenSubscriptions.insert(subscription.id).inserted {
            if case .subscription(let id) = input.scope, id != subscription.id { continue }
            guard !subscription.id.isEmpty else { continue }
            if badSubscriptions.contains(subscription.id) {
                issues.append(.init(.conflictingSubscriptionID, subscriptionID: subscription.id)); continue
            }
            switch subscription.availability {
            case .unavailable: issues.append(.init(.subscriptionUnavailable, subscriptionID: subscription.id))
            case .unknown: issues.append(.init(.subscriptionAvailabilityUnknown, subscriptionID: subscription.id))
            case .available:
                if subscription.offeredModelIDs == nil { issues.append(.init(.offeringsUnknown, subscriptionID: subscription.id)) }
                else { scoped.append(subscription) }
            }
        }
        if case .subscription(let id) = input.scope, subscriptions[id] == nil {
            issues.append(.init(.unknownScope, subscriptionID: id)); return result()
        }
        let offered = scoped.reduce(into: Set<String>()) { $0.formUnion($1.offeredModelIDs ?? []) }
        var byID: [String: SelectionModel] = [:], badIDs: Set<String> = []
        for model in publication.models {
            guard !model.id.isEmpty else { issues.append(.init(.invalidModelID)); continue }
            if let old = byID[model.id], old != model { badIDs.insert(model.id) }
            else { byID[model.id] = model }
        }
        for id in offered.sorted() where byID[id] == nil { issues.append(.init(.modelNotPublished, modelID: id)) }

        let scopedByID = Dictionary(uniqueKeysWithValues: scoped.map { ($0.id, $0.offeredModelIDs ?? []) })
        let cutoff = input.now.addingTimeInterval(-recentUseInterval)
        var recent: [String: Date] = [:]
        for use in input.usage {
            guard scopedByID[use.subscriptionID]?.contains(use.modelID) == true else { continue }
            guard use.usedAt.timeIntervalSinceReferenceDate.isFinite, use.usedAt <= input.now else {
                issues.append(.init(.invalidUsageTime, modelID: use.modelID, subscriptionID: use.subscriptionID)); continue
            }
            guard use.usedAt >= cutoff else { continue }
            recent[use.modelID] = max(recent[use.modelID] ?? use.usedAt, use.usedAt)
        }

        var candidates: [SelectionModel] = [], seenModels: Set<String> = []
        for model in publication.models where !model.id.isEmpty && offered.contains(model.id) && seenModels.insert(model.id).inserted {
            func reject(_ reason: SelectionIssueReason) { issues.append(.init(reason, modelID: model.id)) }
            if badIDs.contains(model.id) { reject(.conflictingModelID); continue }
            if model.defaultSelected == nil { reject(.unknownGlobalDefault) }
            else if model.defaultSelected == false { reject(.notGlobalDefault) }
            if model.exclusion == .legacy { reject(.legacy); continue }
            if model.exclusion == .retired || model.lineageStatus == "retired" { reject(.retired); continue }
            if model.lineageStatus == "preview" { reject(.preview); continue }
            var unknown = false
            if model.lineageID?.isEmpty != false { reject(.unknownLineageID); unknown = true }
            if model.lineageStatus == nil { reject(.unknownLineageStatus); unknown = true }
            else if !["current", "older"].contains(model.lineageStatus!) { reject(.unsupportedLineageStatus); unknown = true }
            if unknown { continue }
            if model.lineageStatus == "older" {
                guard recent[model.id] != nil else { reject(.olderNotRecentlyUsed); continue }
            } else if input.scope == .all {
                guard model.defaultSelected == true else { continue }
            }
            if model.developerID?.isEmpty != false { reject(.unknownDeveloper) }
            candidates.append(model)
        }
        // Multiple distinct current representatives are inconsistent published facts, not an invitation to rank.
        var currentByLineage: [String: [String]] = [:]
        for model in candidates where model.lineageStatus == "current" {
            currentByLineage[model.lineageID!, default: []].append(model.id)
        }
        let ambiguous = Set(currentByLineage.values.filter { $0.count > 1 }.flatMap { $0 })
        candidates = candidates.filter { model in
            guard ambiguous.contains(model.id) else { return true }
            issues.append(.init(.ambiguousCurrentLineage, modelID: model.id)); return false
        }
        let candidatesByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let index = Dictionary(uniqueKeysWithValues: candidates.enumerated().map { ($0.element.id, $0.offset) })
        func tail(_ model: SelectionModel) -> Bool { model.placement == .dominated || model.placement == .pricierTwin }
        var ordered: [SelectedModel] = [], selected: Set<String> = []
        func append(_ model: SelectionModel, _ origin: SelectionOrigin) {
            if selected.insert(model.id).inserted { ordered.append(SelectedModel(model: model, origin: origin)) }
        }
        let used = candidates.filter { recent[$0.id] != nil }.sorted {
            let a = recent[$0.id]!, b = recent[$1.id]!
            return a == b ? index[$0.id]! < index[$1.id]! : a > b
        }
        for model in used.prefix(3) { append(model, .recentUsage(recent[model.id]!)) }
        for kind in PublishedPickKind.allCases {
            for pick in publication.picks where pick.kind == kind {
                if let model = candidatesByID[pick.modelID], !tail(model) { append(model, .publishedPick(kind)) }
            }
        }
        var developers: [String] = [], groups: [String: [SelectionModel]] = [:], unknownDevelopers: [SelectionModel] = []
        for model in candidates {
            if let developer = model.developerID, !developer.isEmpty, !developers.contains(developer) { developers.append(developer) }
        }
        for model in candidates where !selected.contains(model.id) && !tail(model) {
            guard let developer = model.developerID, !developer.isEmpty else { unknownDevelopers.append(model); continue }
            groups[developer, default: []].append(model)
        }
        let rounds = groups.values.map(\.count).max() ?? 0
        for round in 0..<rounds {
            for developer in developers {
                if let models = groups[developer], round < models.count { append(models[round], .developerRoundRobin) }
            }
        }
        for model in unknownDevelopers { append(model, .developerRoundRobin) }
        for model in candidates where tail(model) { append(model, .publishedTail) }
        return result(ordered)
    }
}
