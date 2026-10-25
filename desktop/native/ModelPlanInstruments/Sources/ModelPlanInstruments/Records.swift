// SPDX-License-Identifier: MIT
import Foundation

public struct SessionRate: Sendable {
    public let value: Double?
    public let lastAt: Date?
    public let samples: Int
    public let minimumSamples: Int
    public let validSession60s: Bool
    public init(value: Double?, lastAt: Date?, samples: Int, minimumSamples: Int = 5, validSession60s: Bool) {
        self.value = known(value); self.lastAt = lastAt; self.samples = samples
        self.minimumSamples = minimumSamples; self.validSession60s = validSession60s
    }
    public func reading(now: Date) -> Double? {
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
    public init(id: String, subscriptionID: String?, tool: String, model: String, effort: String?, fast: Bool = false,
                projectID: String? = nil, projectName: String? = nil, startedAt: Date?, endedAt: Date?, lastAt: Date?,
                running: Bool, rate: SessionRate? = nil, tokens: Double? = nil) {
        self.id = id; self.subscriptionID = subscriptionID; self.tool = tool; self.model = model; self.effort = effort
        self.fast = fast; self.projectID = projectID; self.projectName = projectName; self.startedAt = startedAt
        self.endedAt = endedAt; self.lastAt = lastAt; self.running = running; self.rate = rate; self.tokens = known(tokens)
    }
    public func working(now: Date) -> Bool {
        guard running, let lastAt else { return false }
        return now.timeIntervalSince(lastAt) >= 0 && now.timeIntervalSince(lastAt) < 300
    }
}

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
}

private func sessionLines(_ sessions: [InstrumentSession], scope: InstrumentScope, showProjectNames: Bool,
                          now: Date, language: InstrumentLanguage) -> [RecordLine] {
    let ordered = sessions.enumerated().filter { scope == .all || $0.element.subscriptionID.map { scope == .subscription($0) } == true }
        .sorted { a, b in
            let aw = a.element.working(now: now), bw = b.element.working(now: now)
            if aw != bw { return aw }
            let at = (aw ? a.element.startedAt : a.element.endedAt ?? a.element.lastAt) ?? .distantPast
            let bt = (bw ? b.element.startedAt : b.element.endedAt ?? b.element.lastAt) ?? .distantPast
            return at == bt ? a.offset < b.offset : at > bt
        }.map(\.element)
    return ordered.map { session in
        let working = session.working(now: now)
        return RecordLine(id: session.id, working: working, speed60s: working ? session.rate?.reading(now: now) : nil,
                          age: working ? nil : InstrumentFormat(language).age(session.endedAt ?? session.lastAt, now: now),
                          tool: shortTool(session.tool), model: session.model, effort: session.effort, fast: session.fast,
                          projectID: session.projectID, projectName: showProjectNames ? session.projectName : nil, tokens: session.tokens)
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
    public init(sessions: [InstrumentSession], height: Double, scope: InstrumentScope, showProjectNames: Bool,
                now: Date, language: InstrumentLanguage) {
        let rows = sessionLines(sessions, scope: scope, showProjectNames: showProjectNames, now: now, language: language)
        let count = height >= 884 ? 5 : 3
        lines = Array(rows.prefix(count)); overflow = max(0, rows.count - count)
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
public enum TimelineRange: Sendable { case today, days7 }
public struct DestinationsPresentation: Sendable {
    public let projects: [ProjectRow]
    public let timeline: [RecordLine]
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
    }
}
