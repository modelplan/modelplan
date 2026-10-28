// SPDX-License-Identifier: MIT
import Foundation

public struct EngineTableIdentity: Equatable, Sendable {
    public let name: String
    public let shortName: String
    public let alias: String?
    public let brandID: String?
    public init(name: String, shortName: String, alias: String? = nil, brandID: String? = nil) {
        self.name = name; self.shortName = shortName; self.alias = alias; self.brandID = brandID
    }
}
public enum EngineTableIntent: Equatable, Sendable {
    case selectScope(InstrumentScope), changePage(Int), openSubscriptionsSettings
}
public enum EngineNoteTone: Sendable { case normal, warning, critical, publicReset }
public struct EngineQuotaDisplay: Equatable, Sendable {
    public let amount: String
    public let suffix: String
    public let accessibilityLabel: String
    public let notes: [String]
    public let level: QuotaLevel
    public let litSegments: Int?
    public let timeDots: Int?
    public let noteTone: EngineNoteTone
    public let help: HelpExplanation
}
public struct EngineColumnDisplay: Equatable, Sendable {
    public let id: String
    public let identity: EngineTableIdentity
    public let keyLabel: String
    public let keyHelp: HelpExplanation
    public let selected: Bool
    public let dimmed: Bool
    public let unavailable: Bool
    public let caution: QuotaLevel
    public let cells: [EngineQuotaDisplay?]
    public let todayTokens: String?
    public let todaySpeed: String?
    public let reserveLines: [[String]]
    public let todayHelp: HelpExplanation
    public let reserveHelp: HelpExplanation
    public let reserveWarning: Bool
}
public struct EnginePageDisplay: Equatable, Sendable {
    public let page: Int
    public let current: Bool
    public let caution: QuotaLevel
    public let help: HelpExplanation
}

/// Renderer-independent text/state, with no official coordinates, textures or palette.
public struct EngineTablePresentation: Equatable, Sendable {
    public let page: Int
    public let pageCount: Int
    public let tracks: Int
    public let totalSubscriptions: Int
    public let scope: InstrumentScope
    public let columns: [EngineColumnDisplay?]
    public let pageIndicators: [EnginePageDisplay]
    public let labels: [String]
    public let allLabel: String
    public let allKeyLabel: String
    public let allKeyHelp: HelpExplanation
    public let addLabel: String
    public let emptyLabel: String?
    public let previousLabel: String
    public let nextLabel: String
    public let language: InstrumentLanguage
    public let membershipKnowledge: InstrumentMembershipKnowledge
    public var hasReserve: Bool { labels.count == 5 }

    public init(columns: [EngineColumn], identities: [String: EngineTableIdentity] = [:], requestedPage: Int,
                scope: InstrumentScope, language: InstrumentLanguage, now: Date,
                membershipKnowledge: InstrumentMembershipKnowledge = .unknown) {
        let format = InstrumentFormat(language), help = HelpCatalog(language)
        let chinese = language == .chinese
        let model = EnginePage(columns: columns, page: requestedPage)
        page = model.page; pageCount = model.pageCount; tracks = model.columns.count
        totalSubscriptions = columns.count
        self.scope = scope; self.language = language
        self.membershipKnowledge = membershipKnowledge
        let reserves = model.columns.contains { $0?.reserve != nil }
        labels = [format.rowName(.fiveHours), format.rowName(.weekly), format.rowName(.other), chinese ? "今日" : "Today"]
            + (reserves ? [chinese ? "储备" : "Reserve"] : [])
        let all = chinese ? "全部" : "All"
        allLabel = all
        let allKey = all + (chinese ? "（键 0）" : " (key 0)")
        allKeyLabel = allKey
        allKeyHelp = help.explanation(.engine, context: .init(fact: allKey))
        addLabel = chinese ? "＋ 添加订阅" : "＋ Add a subscription"
        emptyLabel = columns.isEmpty ? membershipKnowledge.emptyLabel(language: language) : nil
        previousLabel = chinese ? "上一页订阅" : "Previous subscriptions"
        nextLabel = chinese ? "下一页订阅" : "Next subscriptions"
        self.columns = model.columns.enumerated().map { slot, column in
            guard let column else { return nil }
            let valid = column.evidence.usable(at: now)
            let identity = identities[column.id] ?? EngineTableIdentity(name: column.id, shortName: column.id)
            let keyLabel = identity.name + (chinese ? "（键 \(slot + 1)）" : " (key \(slot + 1))")
            let cells = [column.quotas.fiveHours, column.quotas.weekly, column.quotas.tightestOther]
            let displays = cells.enumerated().map { row, value -> EngineQuotaDisplay? in
                guard let value else { return nil } // Absent window stays a genuinely blank cell.
                let remaining = valid ? value.remaining : nil
                let amount = remaining.map { String(Int($0.rounded())) } ?? "--"
                let tag = row == 2 ? [value.scope, format.period(value.period)].compactMap { $0 }.joined(separator: "·") : ""
                let compactTag = row == 2 ? (value.scope.map { $0.count > 3 ? String($0.prefix(1)) + "·" + format.period(value.period) : $0 } ?? tag) : ""
                let future = valid ? value.resetsAt : nil
                let minutes = future.flatMap { date -> Double? in
                    let m = max(0, date.timeIntervalSince(now) / 60)
                    return m.isFinite && m < Double(Int.max / 2) ? m : nil
                }
                let duration = format.duration(minutes: minutes)
                let short: String = minutes.map { m in
                    m >= 1440 ? "\(Int(m / 1440))d" : m >= 60 ? "\(Int(m / 60))h" : "\(Int(m))m"
                } ?? (chinese ? "未知" : "?")
                var note = !valid ? (chinese ? "读数过期" : "No read") : remaining == nil ? (chinese ? "无数据" : "No data")
                    : remaining == 0 && column.reserve?.drawingCredits == true ? (chinese ? "扣点中" : "credits")
                    : minutes == nil ? (chinese ? "重置未知" : "reset ?") : duration
                var noteTone: EngineNoteTone = remaining == 0 && column.reserve?.drawingCredits == true ? .critical : .normal
                var specialBrief: String?
                if !valid, column.evidence.freshness == .stale, let at = column.evidence.observedAt, at <= now {
                    let age = now.timeIntervalSince(at) / 60
                    if age.isFinite && age < Double(Int.max / 2) {
                        note = chinese ? "\(Int((age / 60).rounded()))h前" : "\(Int((age / 60).rounded()))h ago"
                        let shortAge = age >= 1440 ? "\(Int(age / 1440))d" : age >= 60 ? "\(Int(age / 60))h" : "\(Int(age))m"
                        specialBrief = "−" + shortAge
                    }
                }
                if valid, let event = value.publicReset {
                    noteTone = .publicReset
                    switch event {
                    case .confirmedAwaitingReading:
                        note = chinese ? "已重置 · 等读数" : "Reset · awaiting reading"
                        specialBrief = chinese ? "已重置" : "Reset"
                    case .announced(let at):
                        if let at {
                            let t = format.future(at, now: now, compact: true)
                            let relative = abs(at.timeIntervalSince(now)) < 30 ? (chinese ? "现在" : "now")
                                : at > now ? (chinese ? t + "后" : "in " + t) : format.age(at, now: now)
                            note = chinese ? "预告 \(relative) 重置" : "Reset \(relative) announced"
                            specialBrief = chinese ? "预告\(relative)" : "Due \(relative)"
                        } else { note = chinese ? "预告待定" : "Reset TBA"; specialBrief = note }
                    }
                } else if valid, remaining != nil, let runout = value.runsOutAt {
                    let m = runout.timeIntervalSince(now) / 60
                    noteTone = .warning
                    note = chinese ? "约\(format.duration(minutes: m))用完" : "out ~\(format.duration(minutes: m))"
                    let shortRun = m >= 1440 ? "\(Int(m / 1440))d" : m >= 60 ? "\(Int(m / 60))h" : "\(Int(m))m"
                    specialBrief = chinese ? "约\(shortRun)" : "~\(shortRun)"
                }
                let more = row == 2 && column.quotas.otherOverflow > 0 ? "+\(column.quotas.otherOverflow)" : ""
                let full = [tag, note, more].filter { !$0.isEmpty }.joined(separator: " ")
                let briefNote = specialBrief ?? (valid && remaining != nil && minutes == nil ? short : minutes == nil ? note : short)
                let brief = [compactTag, briefNote, more].filter { !$0.isEmpty }.joined(separator: " ")
                let small = [value.scope.map { String($0.prefix(1)) } ?? tag, briefNote].filter { !$0.isEmpty }.joined(separator: " ") + more
                func quotaFact(_ cell: QuotaCell) -> String {
                    let detailTag = row == 2 ? [cell.scope, format.period(cell.period)].compactMap { $0 }.joined(separator: "·") : ""
                    return identity.name + " · " + (detailTag.isEmpty ? format.rowName(QuotaRow.allCases[row]) : detailTag)
                        + " · " + format.percent(valid ? cell.remaining : nil)
                        + " · " + format.reset(valid ? cell.resetsAt : nil, now: now)
                }
                var facts = row == 2 ? column.quotas.other.map(quotaFact) : [quotaFact(value)]
                if value.publicReset != nil || value.runsOutAt != nil { facts[0] += " · " + note }
                if row == 2, valid {
                    for index in column.quotas.other.indices.dropFirst() {
                        let extra = column.quotas.other[index]
                        if let reset = extra.publicReset {
                            let detail: String
                            switch reset {
                            case .confirmedAwaitingReading: detail = chinese ? "已重置 · 等读数" : "Reset · awaiting reading"
                            case .announced(let date):
                                if let date {
                                    let time = format.future(date, now: now, compact: true)
                                    let relative = abs(date.timeIntervalSince(now)) < 30 ? (chinese ? "现在" : "now")
                                        : date > now ? (chinese ? time + "后" : "in " + time) : format.age(date, now: now)
                                    detail = chinese ? "预告 \(relative) 重置" : "Reset \(relative) announced"
                                } else { detail = chinese ? "预告待定" : "Reset TBA" }
                            }
                            facts[index] += " · " + detail
                        } else if extra.remaining != nil, let runout = extra.runsOutAt {
                            let time = format.duration(minutes: runout.timeIntervalSince(now) / 60)
                            facts[index] += " · " + (chinese ? "约\(time)用完" : "out ~\(time)")
                        }
                    }
                }
                let fact = facts.joined(separator: chinese ? "；" : "; ")
                let label = identity.shortName + " · " + format.rowName(QuotaRow.allCases[row]) + " · " + format.percent(remaining)
                    + (more.isEmpty ? "" : " " + more)
                return EngineQuotaDisplay(amount: amount, suffix: remaining == nil ? "" : "%", accessibilityLabel: label, notes: [full, brief, small],
                                          level: valid ? value.level : .unknown, litSegments: valid ? value.litSegments : nil,
                                          timeDots: valid ? value.timeDots : nil, noteTone: noteTone,
                                          help: help.explanation(valid && value.publicReset != nil ? .publicReset : .quota, context: .init(fact: fact)))
            }
            let attributed = valid && column.todayAttribution == .verifiedSubscription
            let tokens = attributed ? column.todayTokens.map(compactTokens) : nil
            let speed = attributed ? column.todayGenerationTPS.map { value in
                value < Double(Int.max / 2) ? String(Int(value.rounded())) : "--"
            } : nil
            var reserveLines: [[String]] = []
            if let reserve = column.reserve {
                if let count = reserve.resets {
                    if count > 0 {
                        let base = chinese ? "重置 \(count) 次" : "\(count) " + (count == 1 ? "reset" : "resets")
                        let compact = chinese ? "重置\(count)次" : base
                        let expiry = reserve.nearestExpiry.flatMap { date -> String? in
                            let hours = max(0, date.timeIntervalSince(now) / 3600)
                            guard hours.isFinite, hours < Double(Int.max / 2) else { return nil }
                            let h = Int(hours)
                            return h > 48 ? "\(h / 24)d\(h % 24)h" : "\(h)h"
                        }
                        reserveLines.append([base + (expiry.map { " · " + $0 } ?? ""), compact + (expiry.map { "·" + $0 } ?? "")])
                    }
                } else { reserveLines.append(["--"]) }
                if let credits = reserve.credits { reserveLines.append([compactTokens(credits) + (chinese ? " 点数" : credits == 1 ? " credit" : " credits")]) }
            }
            if !valid { reserveLines = column.reserve == nil ? [] : [["--"]] }
            let todayFact = (tokens ?? "--") + " · " + (speed ?? "--") + " t/s"
            let reserveFact = valid ? column.reserve.map {
                format.resets(count: $0.resets, nearestExpiry: $0.nearestExpiry, now: now)
                    + ($0.credits.map { " · " + compactTokens($0) + (chinese ? " 点数" : " credits") } ?? "")
            } ?? "" : "--"
            return EngineColumnDisplay(id: column.id, identity: identity, keyLabel: keyLabel,
                                       keyHelp: help.explanation(.engine, context: .init(fact: keyLabel)), selected: scope == .subscription(column.id),
                                       dimmed: scope != .all && scope != .subscription(column.id), unavailable: !valid,
                                       caution: valid ? column.caution : .unknown, cells: displays, todayTokens: tokens, todaySpeed: speed,
                                       reserveLines: reserveLines, todayHelp: help.explanation(.todaySpeed, context: .init(fact: todayFact, value: speed.map { $0 + " t/s" })),
                                       reserveHelp: help.explanation(.reserve, context: .init(fact: reserveFact)), reserveWarning: valid && column.reserve?.expiryWarning == true)
        }
        pageIndicators = (0..<model.pageCount).map { p in
            let onPage = columns.dropFirst(p * 6).prefix(6)
            let level = onPage.filter { $0.evidence.usable(at: now) }.map(\.caution).filter { $0 >= .amber }.max() ?? .unknown
            let names = onPage.map { identities[$0.id]?.name ?? $0.id }.joined(separator: ", ")
            let fact = (chinese ? "第 \(p + 1) 页：" : "Page \(p + 1): ") + names
                + (level >= .amber ? (chinese ? " · 额度告警" : " · quota alert") : "")
            return EnginePageDisplay(page: p, current: p == model.page, caution: level, help: help.explanation(.page, context: .init(fact: fact)))
        }
    }
}

private func compactTokens(_ value: Double) -> String {
    guard value.isFinite, value >= 0, value < Double(Int.max / 2) else { return "--" }
    if value >= 1_000_000 { return String(format: "%.1fM", locale: Locale(identifier: "en_US_POSIX"), value / 1_000_000) }
    if value >= 1000 { return "\(Int((value / 1000).rounded()))k" }
    return "\(Int(value.rounded()))"
}
