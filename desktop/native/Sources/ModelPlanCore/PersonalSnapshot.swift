// SPDX-License-Identifier: MIT
import Foundation

// CLI schema 1 wire values; nullable/missing fields remain unknown.
public struct PersonalSnapshot: Decodable, Sendable {
    public let schemaVersion: Int
    public let contractVersion: Int?
    public let capabilities: [String: ContractCapability]?
    public let kind: String
    public let generatedAt: WireInstant
    public let cliVersion: String?
    public let dataRevision: String?
    public let validUntil: WireInstant?
    public let recording: Bool?
    public let effortSuggestion: PersonalEffortSuggestion?
    public let publication: PersonalPublication?
    public let accounts: [QuotaAccount]?
    public let subscriptions: [SubscriptionBinding]?
    public let sessions: [HarnessSession]?
    public let liveSessions: [LiveSession]?
    public let sources: [SourceStatus]?
    public let connections: [ConnectionStatus]?
    public let events: [AdviceEvent]?
    public let todayTotals: [TodayTotal]?
    public let perfStats: [PerformanceRow]?
    public let daily: [DailyBucket]?
    public let dailyLong: [DailyBucket]?
    public let hourly: [HourlyBucket]?
    public let dailyCoverage: Coverage?
    public let dailyLongCoverage: Coverage?
    public let sessionRanking: SessionRanking?
    public let projectRanking: ProjectRanking?
    public let projectLabels: Bool?
    public let paceHistory: PaceHistory?
    public let measured: [JSONValue]?
    public let qwenUsage: JSONValue?
    public let localUsage: [JSONValue]?
    public let note: String?
    public let validUntilReported: Bool
    private enum CodingKeys: String, CodingKey { case schemaVersion, contractVersion, capabilities, kind, generatedAt, cliVersion, dataRevision, validUntil, recording, effortSuggestion, publication, accounts, subscriptions, sessions, liveSessions, sources, connections, events, todayTotals, perfStats, daily, dailyLong, hourly, dailyCoverage, dailyLongCoverage, sessionRanking, projectRanking, projectLabels, paceHistory, measured, qwenUsage, localUsage, note }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        validUntilReported = c.contains(.validUntil)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        contractVersion = try c.decodeIfPresent(Int.self, forKey: .contractVersion)
        capabilities = try c.decodeIfPresent([String: ContractCapability].self, forKey: .capabilities)
        kind = try c.decode(String.self, forKey: .kind)
        generatedAt = try c.decode(WireInstant.self, forKey: .generatedAt)
        cliVersion = try c.decodeIfPresent(String.self, forKey: .cliVersion)
        dataRevision = try c.decodeIfPresent(String.self, forKey: .dataRevision)
        validUntil = try c.decodeIfPresent(WireInstant.self, forKey: .validUntil)
        recording = try c.decodeIfPresent(Bool.self, forKey: .recording)
        effortSuggestion = try c.decodeIfPresent(PersonalEffortSuggestion.self, forKey: .effortSuggestion)
        publication = try c.decodeIfPresent(PersonalPublication.self, forKey: .publication)
        accounts = try c.decodeIfPresent([QuotaAccount].self, forKey: .accounts)
        subscriptions = try c.decodeIfPresent([SubscriptionBinding].self, forKey: .subscriptions)
        sessions = try c.decodeIfPresent([HarnessSession].self, forKey: .sessions)
        liveSessions = try c.decodeIfPresent([LiveSession].self, forKey: .liveSessions)
        sources = try c.decodeIfPresent([SourceStatus].self, forKey: .sources)
        connections = try c.decodeIfPresent([ConnectionStatus].self, forKey: .connections)
        events = try c.decodeIfPresent([AdviceEvent].self, forKey: .events)
        todayTotals = try c.decodeIfPresent([TodayTotal].self, forKey: .todayTotals)
        perfStats = try c.decodeIfPresent([PerformanceRow].self, forKey: .perfStats)
        daily = try c.decodeIfPresent([DailyBucket].self, forKey: .daily)
        dailyLong = try c.decodeIfPresent([DailyBucket].self, forKey: .dailyLong)
        hourly = try c.decodeIfPresent([HourlyBucket].self, forKey: .hourly)
        dailyCoverage = try c.decodeIfPresent(Coverage.self, forKey: .dailyCoverage)
        dailyLongCoverage = try c.decodeIfPresent(Coverage.self, forKey: .dailyLongCoverage)
        sessionRanking = try c.decodeIfPresent(SessionRanking.self, forKey: .sessionRanking)
        projectRanking = try c.decodeIfPresent(ProjectRanking.self, forKey: .projectRanking)
        projectLabels = try c.decodeIfPresent(Bool.self, forKey: .projectLabels)
        paceHistory = try c.decodeIfPresent(PaceHistory.self, forKey: .paceHistory)
        measured = try c.decodeIfPresent([JSONValue].self, forKey: .measured)
        qwenUsage = try c.decodeIfPresent(JSONValue.self, forKey: .qwenUsage)
        localUsage = try c.decodeIfPresent([JSONValue].self, forKey: .localUsage)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

}

// Personal local advice, never model context. Missing means unknown/suppressed.
// costRatio compares published reference costs, not forecast quota consumption.
public struct PersonalEffortSuggestion: Decodable, Sendable {
    public let source: String
    public let plan: String
    public let modelId: String
    public let modelName: String
    public let direction: String
    public let fromEffort: String
    public let fromLabel: String
    public let toEffort: String
    public let toLabel: String
    public let recommended: String
    public let fast: Bool
    public let cycles: Int
    public let averageUsed: Double
    public let hitLimitCycles: Int
    public let costRatio: Double
    public let costBasisId: String
    public let publicationId: String
    public let resetAt: WireInstant
    public let expiresAt: WireInstant
    public let message: String?
}

public struct PersonalPublication: Decodable, Sendable {
    public let publicationId: String?
    public let publishedAt: WireInstant?
    public let checkedAt: WireInstant?
    public let verifiedAt: WireInstant?
    public let stale: Bool?
    public let lastError: JSONValue?
}

public struct SubscriptionBinding: Decodable, Sendable {
    public let subscriptionRef: String
    public let sources: [String]?
    public let basis: String?
    public let observedAt: WireInstant?
}

public struct AccountBinding: Decodable, Sendable {
    public let subscriptionRef: String
    public let status: String?
    public let basis: String?
    public let observedAt: WireInstant?
}

public struct QuotaAccount: Decodable, Sendable {
    public let beta: Bool?
    public let sharedPool: QuotaSharedPool?
    public let generation: String?
    public let pool: String?
    public let source: String
    public let plan: String?
    public let observedAt: WireInstant?
    public let stale: Bool?
    public let windows: [QuotaWindow]?
    public let subscription: AccountBinding?
    public let cards: [ResetCard]?
    public let credits: UsageCredits?
    public let headroom: String?
    public let deciding: String?
    public let harness: JSONValue?
    public let reserve: JSONValue?
    public let via: String?
}

/// Reported shared-pool eligibility does not establish a cross-tool account binding.
public struct QuotaSharedPool: Decodable, Sendable {
    public let kind: String?
    public let status: String?
    public let additive: Bool?
}

public struct RequestUsage: Decodable, Sendable {
    public let used: Int64?
    public let limit: Int64?
    public let unlimited: Bool?
    public let reason: String?
}

public struct QuotaWindow: Decodable, Sendable {
    public let usedUsd: Double?
    public let limitUsd: Double?
    public let requests: RequestUsage?
    public let unknownReason: String?
    public let kind: String
    public let limit: String?
    public let usedPercent: Double?
    public let remainingPercent: Double?
    public let windowMinutes: Double?
    public let resetsAt: WireInstant?
    public let resetsInMinutes: Double?
    public let resetMode: String?
    public let observedAt: WireInstant?
    public let elapsedPercent: Double?
    public let projectedPercent: Double?
    public let ageMinutes: Double?
    public let recentPercentPerHour: Double?
    public let runsOutInMinutes: Double?
    public let pace: String?
    public let reason: String?
}

public struct ResetCard: Decodable, Sendable {
    public let kind: String?
    public let count: UInt64?
    public let expiresAt: WireInstant?
    public let source: String?
    public let type: String?
    public let observedAt: WireInstant?
}

public struct UsageCredits: Decodable, Sendable {
    public let ageMinutes: Double?
    public let balance: Double?
    public let unlimited: Bool?
    public let observedAt: WireInstant?
    public let historical: [JSONValue]?
    public let limits: JSONValue?
}

public struct SourceStatus: Decodable, Sendable {
    public let beta: Bool?
    public let source: String
    public let status: String
    public let reason: String?
    public let nextStep: String?
}

public struct ConnectionStage: Decodable, Sendable {
    public let status: String
    public let reason: String?
    public let nextStep: String?
    public let via: String?
    public let at: WireInstant?
    public let binding: String?
}

public struct ConnectionStatus: Decodable, Sendable {
    public let id: String
    public let kind: String?
    public let support: String?
    public let installed: ConnectionStage?
    public let history: ConnectionStage?
    public let authorization: ConnectionStage?
    public let quota: ConnectionStage?
    public let paths: JSONValue?
    public let hosts: [String]?
    public let privacy: JSONValue?
    public let quotaAccess: ConnectionQuotaAccess?
}

/// Reported backend admission metadata. Missing fields do not imply consent or denial.
/// Raw wire codes are evidence for an allowlisted presentation mapper, not display text.
public struct ConnectionQuotaAccess: Decodable, Sendable {
    public let provider: String?
    public let backend: String?
    public let blocked: String?
    public let accessClass: String?
}

public struct ModelReference: Decodable, Sendable {
    public let harnessId: String?
    public let id: String?
    public let name: String?
    public let developerId: String?
}

public struct EffortReference: Decodable, Sendable {
    public let key: String?
    public let label: String?
    public let star: Bool?
}

public struct HarnessSession: Decodable, Sendable {
    public let origin: String?
    public let headroom: String?
    public let deciding: String?
    public let pool: String?
    public let source: String
    public let observedAt: WireInstant?
    public let attribution: String?
    public let stale: Bool?
    public let model: ModelReference?
    public let effort: EffortReference?
    public let effortStatus: String?
    public let recommended: EffortReference?
    public let speed: String?
    public let projectRef: String?
    public let subscription: AccountBinding?
    public let tokenRate: RateReading?
    public let workloadRate: RateReading?
    public let activity: JSONValue?
    public let vsRecommended: JSONValue?
}

public struct RateReading: Decodable, Sendable {
    public let source: String?
    public let configKey: String?
    public let window: String?
    public let scope: String?
    public let value: Double?
    public let status: String
    public let n: UInt64?
    public let min: UInt64?
    public let reason: String?
    public let lastAt: WireInstant?
    public let freshness: String?
    public let configCount: UInt64?
}

public struct LiveSession: Decodable, Sendable {
    public let ref: String
    public let source: String
    public let model: String?
    public let effort: String?
    public let effortStatus: String?
    public let speed: String?
    public let projectRef: String?
    public let subscriptionRef: String?
    public let startedAt: WireInstant?
    public let lastAt: WireInstant?
    public let status: String
    public let rate: RateReading?
}

public struct AdviceEvent: Decodable, Sendable {
    public let type: String
    public let key: String?
    public let severity: String?
    public let source: String?
    public let window: String?
    public let at: WireInstant?
    public let expiresAt: WireInstant?
    public let inMinutes: Double?
    public let remainingPercent: Double?
    public let runsOutInMinutes: Double?
    public let model: String?
    public let effort: String?
    public let text: [String:String]?
    public let short: [String:String]?
    public let inMenuBar: Bool?
    public let suggest: JSONValue?
    public let alternative: JSONValue?
    public let current: JSONValue?
}

public struct MetricSums: Decodable, Sendable {
    public let observedRequests: UInt64?
    public let observedOutputTokens: UInt64?
    public let eligibleRequests: UInt64?
    public let eligibleOutputTokens: UInt64?
    public let genMs: Double?
    public let turns: UInt64?
    public let turnMs: Double?
    public let turnOutputTokens: UInt64?
    public let mixedConfigTurnsExcluded: UInt64?
    public let inputTokens: UInt64?
    public let cacheReadTokens: UInt64?
    public let cacheWriteTokens: UInt64?
}

public struct TodayTotal: Decodable, Sendable {
    public let source: String
    public let sums: MetricSums
}

public struct PerformanceMetric: Decodable, Sendable {
    public let value: Double?
    public let status: String
    public let n: UInt64?
    public let min: UInt64?
    public let reason: String?
}

public struct Histogram: Decodable, Sendable {
    public let scheme: String
    public let unit: String
    public let counts: [String:UInt64]
}

public struct PerformanceWindow: Decodable, Sendable {
    public let sums: MetricSums
    public let hist: [String:Histogram]?
    public let metrics: [String:PerformanceMetric]?
}

public struct PerformanceRow: Decodable, Sendable {
    public let source: String
    public let model: String
    public let effortStatus: String?
    public let effort: String?
    public let speed: String?
    public let parser: String?
    public let eligibility: String?
    public let basis: JSONValue?
    public let attribution: String?
    public let since: WireInstant?
    public let lastAt: WireInstant?
    public let freshness: String?
    public let windows: [String:PerformanceWindow]
}

public struct DailyBucket: Decodable, Sendable {
    public let day: String
    public let source: String
    public let model: String
    public let observedOutputTokens: UInt64?
    public let observedRequests: UInt64?
    public let inputTokens: UInt64?
    public let cacheReadTokens: UInt64?
    public let cacheWriteTokens: UInt64?
}

public struct HourlyBucket: Decodable, Sendable {
    public let hour: WireInstant
    public let source: String
    public let model: String
    public let observedOutputTokens: UInt64?
    public let observedRequests: UInt64?
    public let inputTokens: UInt64?
    public let cacheReadTokens: UInt64?
    public let cacheWriteTokens: UInt64?
}

public struct Coverage: Decodable, Sendable {
    public let from: String?
    public let recording: Bool?
}

public struct RankingConfiguration: Decodable, Sendable {
    public let model: String
    public let effortStatus: String?
    public let effort: String?
    public let speed: String?
    public let observedOutputTokens: UInt64?
    public let share: Double?
    public let recommendedEffort: String?
}

public struct SessionRank: Decodable, Sendable {
    public let ref: String
    public let source: String?
    public let firstAt: WireInstant?
    public let lastAt: WireInstant?
    public let observedOutputTokens: UInt64?
    public let observedRequests: UInt64?
    public let share: Double?
    public let projectRef: String?
    public let subscriptionRef: String?
    public let configs: [RankingConfiguration]?
}

public struct SessionRankWindow: Decodable, Sendable {
    public let sessions: UInt64?
    public let totalObservedOutputTokens: UInt64?
    public let top: [SessionRank]?
}

public struct SessionRanking: Decodable, Sendable {
    public let measure: String?
    public let recent7d: SessionRankWindow?
    public let recent30d: SessionRankWindow?
}

public struct ProjectRank: Decodable, Sendable {
    public let ref: String
    public let label: String?
    public let sessions: UInt64?
    public let lastAt: WireInstant?
    public let observedOutputTokens: UInt64?
    public let observedRequests: UInt64?
    public let share: Double?
    public let subscriptionRefs: [String]?
    public let configs: [RankingConfiguration]?
}

public struct ProjectRankWindow: Decodable, Sendable {
    public let projects: UInt64?
    public let totalObservedOutputTokens: UInt64?
    public let unattributedOutputTokens: UInt64?
    public let top: [ProjectRank]?
}

public struct ProjectRanking: Decodable, Sendable {
    public let measure: String?
    public let recent7d: ProjectRankWindow?
    public let recent30d: ProjectRankWindow?
}

public struct PaceSpent: Decodable, Sendable {
    public let model: String
    public let effort: String?
    public let fast: Bool?
    public let points: Double?
}

public struct PaceCycle: Decodable, Sendable {
    public let resetsAt: WireInstant?
    public let closed: Bool?
    public let firstObservedAt: WireInstant?
    public let firstUsed: Double?
    public let lastObservedAt: WireInstant?
    public let lastUsed: Double?
    public let readings: UInt64?
    public let spanMinutes: Double?
    public let coverage: Double?
    public let gapCount: UInt64?
    public let maxGapMinutes: Double?
    public let drops: UInt64?
    public let hadDrop: Bool?
    public let points: Double?
    public let gapPoints: Double?
    public let spent: [PaceSpent]?
    public let spentBasis: String?
}

public struct PaceGroup: Decodable, Sendable {
    public let source: String
    public let plan: String?
    public let limit: String?
    public let kind: String
    public let windowMinutes: Double?
    public let attribution: String?
    public let closedCycles: UInt64?
    public let validCycles: UInt64?
    public let observedIntervalRatePerHour: Double?
    public let status: String?
    public let min: UInt64?
    public let cycles: [PaceCycle]?
}

public struct PaceHistory: Decodable, Sendable {
    public let since: WireInstant?
    public let status: String?
    public let reason: String?
    public let gapLimitMinutes: [String:Double]?
    public let groups: [PaceGroup]?
}
