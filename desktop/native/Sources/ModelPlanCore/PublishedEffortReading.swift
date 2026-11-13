// SPDX-License-Identifier: MIT
import Foundation

/// Published order and numbers are displayed verbatim. Current and recommended are independent facts.
public struct PublishedEffortReading: Sendable {
    public let key: String
    public let label: String?
    public let ability: Double?
    public let cost: Double?
    public let time: Double?
    public let abilityBasis: String?
    public let costBasisID: String?
    public let timeBasis: JSONValue?
    public let timeEstimated: Bool?
    public let isCurrent: Bool
    public let isRecommended: Bool
}
extension JoinedSnapshot {
    public func efforts(harness: String, id: String, current: CurrentConfiguration?) -> [PublishedEffortReading] {
        guard let modelID = model(harness: harness, id: id), let model = publication?.models.first(where: { $0.id == modelID }) else { return [] }
        let ownEffort = current?.source == harness && current?.harnessModel == id ? current?.effort : nil
        return (model.efforts ?? []).map { effort in
            PublishedEffortReading(key: effort.effort, label: effort.label, ability: effort.ability, cost: effort.cost,
                time: effort.time, abilityBasis: effort.abilityBasis, costBasisID: effort.costBasisId,
                timeBasis: effort.timeBasis, timeEstimated: effort.timeEstimated,
                isCurrent: effort.effort == ownEffort, isRecommended: effort.effort == model.recommended)
        }
    }
}
