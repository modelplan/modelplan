// SPDX-License-Identifier: MIT
import Foundation

// CLI schema 1 wire values; nullable/missing fields remain unknown.
public struct PublicPublication: Decodable, Sendable {
    public let schemaVersion: Int
    public let contractVersion: Int?
    public let capabilities: [String: ContractCapability]?
    public let publicationId: String
    public let publishedAt: WireInstant?
    public let units: PublicationUnits
    public let models: [PublishedModel]
    public let lineups: [PublishedLineup]
    public let speedTiers: [SpeedTier]?
    public let resets: [JSONValue]?
    public let windows: [JSONValue]?
    public let multipliers: [JSONValue]?
    public let multiplierHorizon: JSONValue?
    public let planMetering: JSONValue?
}

public struct PublicationUnits: Decodable, Sendable {
    public let ability: String
    public let cost: String
    public let time: String?
}

public struct PublishedModel: Decodable, Sendable {
    public let id: String
    public let name: String?
    public let developerId: String?
    public let current: Bool?
    public let recommended: String?
    public let harnessIds: [String:[String]]?
    public let harnessEvidence: JSONValue?
    public let efforts: [PublishedEffort]?
    public let basis: JSONValue?
    public let recommendedBasis: JSONValue?
}

public struct PublishedEffort: Decodable, Sendable {
    public let effort: String
    public let label: String?
    public let available: Bool?
    public let ability: Double?
    public let abilityBasis: String?
    public let cost: Double?
    public let time: Double?
    public let timeEstimated: Bool?
    public let timeBasis: JSONValue?
    public let costBasisId: String?
    public let basis: JSONValue?
    public let recommended: Bool?
}

public struct PublishedLineup: Decodable, Sendable {
    public let developerId: String
    public let costBasisId: String?
    public let method: String?
    public let tie: Double?
    public let baseline: String?
    public let frontier: [String]?
    public let members: [LineupMember]?
    public let steps: [JSONValue]?
}

public struct LineupMember: Decodable, Sendable {
    public let id: String
    public let status: String?
    public let ability: Double?
    public let cost: Double?
    public let costRelative: Double?
    public let tags: [String]?
    public let dominatedBy: JSONValue?
}

public struct SpeedTier: Decodable, Sendable {
    public let id: String
    public let harness: String?
    public let tier: String?
    public let label: String?
    public let toggle: String?
    public let eligibility: JSONValue?
    public let models: [TierModel]?
    public let billing: [JSONValue]?
    public let caveats: [String]?
    public let sources: [JSONValue]?
    public let reviewedAt: WireInstant?
}

public struct TierModel: Decodable, Sendable {
    public let vendorModelId: String?
    public let modelId: String?
    public let speed: TierSpeed?
}

public struct TierSpeed: Decodable, Sendable {
    public let ratio: Double?
    public let qualifier: String?
}

extension PublicPublication {
    public var supportedUnits: Bool { units.ability == "websiteAbility" && units.cost == "usdPerReferenceTask" && units.time == "taskTimeCrossModel" }
    public var normalizedSpeedTiers: [SpeedTier] { speedTiers ?? [] }
}
