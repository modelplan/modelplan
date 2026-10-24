// SPDX-License-Identifier: MIT
import Foundation

// CLI schema 1 wire values; nullable/missing fields remain unknown.
public struct PersonalSnapshot: Decodable, Sendable {
    public let schemaVersion: Int
    public let kind: String
    public let generatedAt: WireInstant
    public let cliVersion: String?
    public let dataRevision: String?
    public let validUntil: WireInstant?
    public let recording: Bool?
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
    public let localUsage: [JSONValue]?
    public let note: String?
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

public struct QuotaWindow: Decodable, Sendable {
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
    public let count: UInt64?
    public let expiresAt: WireInstant?
    public let source: String?
    public let type: String?
    public let observedAt: WireInstant?
}

public struct UsageCredits: Decodable, Sendable {
    public let balance: Double?
    public let unlimited: Bool?
    public let observedAt: WireInstant?
    public let historical: [JSONValue]?
    public let limits: JSONValue?
}

public struct SourceStatus: Decodable, Sendable {
    public let source: String
    public let status: String
    public let reason: String?
}

public struct ConnectionStage: Decodable, Sendable {
    public let status: String
    public let reason: String?
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

