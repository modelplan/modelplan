// SPDX-License-Identifier: MIT
import Foundation

public struct SessionRateIdentity: Equatable, Sendable {
    public let sessionID: String
    public let modelID: String
    public let effort: String
    public let fast: Bool
    public init(sessionID: String, modelID: String, effort: String, fast: Bool) {
        self.sessionID = sessionID; self.modelID = modelID; self.effort = effort; self.fast = fast
    }
}

public struct SessionRate: Sendable {
    public let value: Double?
    public let lastAt: Date?
    public let samples: Int
    public let minimumSamples: Int
    public let validSession60s: Bool
    public let configuration: SessionRateIdentity?
    public init(value: Double?, lastAt: Date?, samples: Int, minimumSamples: Int = 5, validSession60s: Bool,
                configuration: SessionRateIdentity? = nil) {
        self.value = known(value); self.lastAt = lastAt; self.samples = samples
        self.minimumSamples = minimumSamples; self.validSession60s = validSession60s
        self.configuration = configuration
    }
    public func reading(now: Date, matching expected: SessionRateIdentity? = nil) -> Double? {
        if let expected, configuration != expected { return nil }
        guard validSession60s, samples >= max(5, minimumSamples), let lastAt,
              now.timeIntervalSince(lastAt) >= 0, now.timeIntervalSince(lastAt) < 60 else { return nil }
        return value
    }
}

/// Supplied session identity/rate must already match model, effort, fast mode and attribution in the Core join.
public struct InstrumentSession: Sendable {
    public let id: String
    public let subscriptionID: String?
    public let tool: String
    public let model: String
    public let effort: String?
    public let fast: Bool
    public let projectID: String?
    public let projectName: String?
    public let startedAt: Date?
    public let endedAt: Date?
    public let lastAt: Date?
    public let running: Bool
    public let rate: SessionRate?
    public let tokens: Double?
    public let evidence: InstrumentEvidence
    public init(id: String, subscriptionID: String?, tool: String, model: String, effort: String?, fast: Bool = false,
                projectID: String? = nil, projectName: String? = nil, startedAt: Date?, endedAt: Date?, lastAt: Date?,
                running: Bool, rate: SessionRate? = nil, tokens: Double? = nil, evidence: InstrumentEvidence = .init()) {
        self.id = id; self.subscriptionID = subscriptionID; self.tool = tool; self.model = model; self.effort = effort
        self.fast = fast; self.projectID = projectID; self.projectName = projectName; self.startedAt = startedAt
        self.endedAt = endedAt; self.lastAt = lastAt; self.running = running; self.rate = rate; self.tokens = known(tokens)
        self.evidence = evidence
    }
    public func working(now: Date) -> Bool {
        guard running, endedAt == nil, evidence.usable(at: now), startedAt.map({ $0 <= now }) ?? true, let lastAt else { return false }
        return now.timeIntervalSince(lastAt) >= 0 && now.timeIntervalSince(lastAt) < 300
    }
}

public enum RecordActivity: Sendable { case working, completed, unknown }
public struct RecordLine: Sendable {
    public let id: String
    public let working: Bool
    public let speed60s: Double?
    public let age: String?
    public let tool: String
    public let model: String
    public let effort: String?
    public let fast: Bool
    public let projectID: String?
    public let projectName: String?
    public let tokens: Double?
    public let activity: RecordActivity
}

private func sessionLines(_ sessions: [InstrumentSession], scope: InstrumentScope, showProjectNames: Bool,
                          now: Date, language: InstrumentLanguage) -> [RecordLine] {
    let ordered = sessions.enumerated().filter { scope == .all || $0.element.subscriptionID.map { scope == .subscription($0) } == true }
        .sorted { a, b in
            let aw = a.element.working(now: now), bw = b.element.working(now: now)
            if aw != bw { return aw }
            let at = (aw ? a.element.startedAt : a.element.endedAt ?? a.element.lastAt) ?? .distantPast
            let bt = (bw ? b.element.startedAt : b.element.endedAt ?? b.element.lastAt) ?? .distantPast
            if at != bt { return at > bt }
            if a.element.id != b.element.id { return a.element.id < b.element.id }
            return a.offset < b.offset
        }.map(\.element)
    return ordered.map { session in
        let working = session.working(now: now)
        let identity = session.effort.map { SessionRateIdentity(sessionID: session.id, modelID: session.model, effort: $0, fast: session.fast) }
        let speed = working ? identity.flatMap { session.rate?.reading(now: now, matching: $0) } : nil
        return RecordLine(id: session.id, working: working, speed60s: speed,
                          age: working ? nil : InstrumentFormat(language).age(session.endedAt ?? session.lastAt, now: now),
                          tool: shortTool(session.tool), model: session.model, effort: session.effort, fast: session.fast,
                          projectID: session.projectID, projectName: showProjectNames ? session.projectName : nil, tokens: session.tokens,
                          activity: working ? .working : session.endedAt.map { $0 <= now ? .completed : .unknown } ?? .unknown)
    }
}

private func shortTool(_ tool: String) -> String {
    switch tool {
    case "Claude Code": return "Claude"
    case "OpenCode", "opencode": return "OpenCode"
    default: return tool
    }
}

public struct RecordStripPresentation: Sendable {
    public let lines: [RecordLine]
    public let overflow: Int
    public let runningOverflow: Int
    public var moreDestination: MainScreenContent? {
        overflow > 0 ? .page(.init(.destinations, destinationsMode: .timeline)) : nil
    }
    public init(sessions: [InstrumentSession], height: Double, scope: InstrumentScope, showProjectNames: Bool,
                now: Date, language: InstrumentLanguage) {
        let rows = sessionLines(sessions, scope: scope, showProjectNames: showProjectNames, now: now, language: language)
        let count = height >= 884 ? 5 : 3
        lines = Array(rows.prefix(count)); overflow = max(0, rows.count - count)
        runningOverflow = rows.dropFirst(count).filter(\.working).count
    }
}

/// Project order/totals are supplied by the CLI. Combined totals cannot be relabelled as one account's totals.
public struct InstrumentProject: Sendable {
    public let id: String
    public let name: String?
    public let subscriptionIDs: Set<String>
    public let combinedTokens: Double?
    public let tokensBySubscription: [String: Double]
    public init(id: String, name: String?, subscriptionIDs: Set<String>, combinedTokens: Double?, tokensBySubscription: [String: Double] = [:]) {
        self.id = id; self.name = name; self.subscriptionIDs = subscriptionIDs
        self.combinedTokens = known(combinedTokens); self.tokensBySubscription = tokensBySubscription
    }
}
public struct ProjectRow: Sendable {
    public let id: String
    public let name: String?
    public let tokens: Double?
}
public enum TimelineRange: Equatable, Sendable { case today, days7 }
public enum ProjectRankingPeriod: Equatable, Sendable { case days7, days30 }
public struct SuppliedProjectRanking: Sendable {
    public let period: ProjectRankingPeriod
    public let projects: [InstrumentProject]
    public let evidence: InstrumentEvidence
    public init(period: ProjectRankingPeriod, projects: [InstrumentProject], evidence: InstrumentEvidence) {
        self.period = period; self.projects = projects; self.evidence = evidence
    }
}
public struct DestinationsPresentation: Sendable {
    public let projects: [ProjectRow]
    public let timeline: [RecordLine]
    public let projectPeriod: ProjectRankingPeriod?
    public let projectUnavailableReason: String?
    public init(projects: [InstrumentProject], sessions: [InstrumentSession], scope: InstrumentScope,
                timelineRange: TimelineRange, showProjectNames: Bool, now: Date, calendar: Calendar, language: InstrumentLanguage) {
        self.projects = projects.compactMap { project in
            let tokens: Double?
            switch scope {
            case .all: tokens = project.combinedTokens
            case .subscription(let id):
                guard project.subscriptionIDs.contains(id) else { return nil }
                tokens = known(project.tokensBySubscription[id]) ?? (project.subscriptionIDs == [id] ? project.combinedTokens : nil)
            }
            return ProjectRow(id: project.id, name: showProjectNames ? project.name : nil, tokens: tokens)
        }
        let today = calendar.startOfDay(for: now)
        let first = timelineRange == .today ? today : calendar.date(byAdding: .day, value: -6, to: today)!
        let relevant = sessions.filter {
            if $0.working(now: now) { return true }
            guard let last = $0.endedAt ?? $0.lastAt else { return false }
            return last >= first && last <= now
        }
        timeline = sessionLines(relevant, scope: scope, showProjectNames: showProjectNames, now: now, language: language)
        projectPeriod = nil; projectUnavailableReason = nil
    }
    public init(ranking: SuppliedProjectRanking?, expectedPeriod: ProjectRankingPeriod, sessions: [InstrumentSession], scope: InstrumentScope,
                timelineRange: TimelineRange, showProjectNames: Bool, now: Date, calendar: Calendar, language: InstrumentLanguage) {
        let usable = ranking?.period == expectedPeriod && ranking?.evidence.usable(at: now) == true
        let page = Self(projects: usable ? ranking?.projects ?? [] : [], sessions: sessions, scope: scope,
                        timelineRange: timelineRange, showProjectNames: showProjectNames, now: now, calendar: calendar, language: language)
        projects = page.projects; timeline = page.timeline; projectPeriod = expectedPeriod
        projectUnavailableReason = usable ? nil : "ranking-unavailable-or-incompatible-period"
    }
}
