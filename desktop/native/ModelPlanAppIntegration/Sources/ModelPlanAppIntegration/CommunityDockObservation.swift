// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings

enum CommunityDockWindowIdentity {
    static func make(account: Int, window: Int) -> String { "account.\(account).window.\(window)" }
}
/// Original account evidence only. Rendering/CLI report time never becomes an account observation.
enum CommunityObservationAge {
    static let unknown = "Reading time unknown"
    static func unknown(language: SettingsLanguage) -> String {
        language == .english ? unknown : "读数时间未知"
    }
    /// Older readings switch to days, and nothing older than this is printed as a number:
    /// a missing, zero or otherwise implausible timestamp must never read "632675小时前".
    static let longestShownAge: TimeInterval = 30 * 86_400
    /// Readings cannot predate the product; a timestamp before 2020 is a missing/zero value.
    private static let earliestPlausible = Date(timeIntervalSince1970: 1_577_836_800)
    private enum Age { case unknown, justNow, minutes(Int), hours(Int), days(Int), older }
    private static func age(_ observedAt: Date?, now: Date) -> Age {
        guard let observedAt, observedAt >= earliestPlausible else { return .unknown }
        let seconds = now.timeIntervalSince(observedAt)
        guard seconds.isFinite, seconds >= 0 else { return .unknown }
        if seconds < 60 { return .justNow }
        if seconds < 3600 { return .minutes(Int(seconds / 60)) }
        if seconds < 48 * 3600 { return .hours(Int(seconds / 3600)) }
        if seconds <= longestShownAge { return .days(Int(seconds / 86_400)) }
        return .older
    }
    static func cardText(observedAt: Date?, now: Date, english: Bool) -> String {
        switch age(observedAt, now: now) {
        case .unknown: return english ? "Reading time unknown" : "读数时间未知"
        case .justNow: return english ? "just now" : "刚刚"
        case .minutes(let n): return english ? "\(n)m ago" : "\(n)分钟前"
        case .hours(let n): return english ? "\(n)h ago" : "\(n)小时前"
        case .days(let n): return english ? "\(n)d ago" : "\(n)天前"
        case .older: return english ? "over 30 days ago" : "超过 30 天前"
        }
    }
    static func text(observedAt: Date?, now: Date, language: SettingsLanguage = .english) -> String {
        let english = language == .english
        switch age(observedAt, now: now) {
        case .unknown: return unknown(language: language)
        case .justNow: return english ? "Reading taken <1m ago" : "读取于 1 分钟内"
        case .minutes(let n): return english ? "Reading taken \(n)m ago" : "读取于 \(n) 分钟前"
        case .hours(let n): return english ? "Reading taken \(n)h ago" : "读取于 \(n) 小时前"
        case .days(let n): return english ? "Reading taken \(n)d ago" : "读取于 \(n) 天前"
        case .older: return english ? "Reading taken over 30 days ago" : "读取于超过 30 天前"
        }
    }
}
enum CommunityDockObservation {
    static func text(input: DockInstrumentInput, snapshot: JoinedSnapshot?, model: CommunityDockSnapshot?, now: Date,
                     language: SettingsLanguage = .english) -> String {
        let accounts = Array((snapshot?.personal.accounts ?? []).enumerated().filter { $0.element.subscription?.subscriptionRef == input.id })
        if !accounts.isEmpty {
            if let selected = (try? DockInstrumentProjection.evaluate(input, now: now))?.selectedWindowID {
                for (accountIndex, account) in accounts {
                    for windowIndex in (account.windows ?? []).indices {
                        if CommunityDockWindowIdentity.make(account: accountIndex, window: windowIndex) == selected {
                            return CommunityObservationAge.cardText(observedAt: account.observedAt?.date, now: now, english: language == .english)
                        }
                    }
                }
                return CommunityObservationAge.unknown(language: language)
            }
            return CommunityObservationAge.cardText(observedAt: accounts.count == 1 ? accounts[0].element.observedAt?.date : nil, now: now, english: language == .english)
        }
        return CommunityObservationAge.cardText(observedAt: model?.presentationRows[input.id]?.originalObservedAt, now: now, english: language == .english)
    }
}
