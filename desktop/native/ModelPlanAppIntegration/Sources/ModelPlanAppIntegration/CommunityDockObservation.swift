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
    static func cardText(observedAt: Date?, now: Date, english: Bool) -> String {
        guard let observedAt else { return english ? "Reading time unknown" : "读数时间未知" }
        let seconds = now.timeIntervalSince(observedAt)
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return english ? "Reading time unknown" : "读数时间未知" }
        if seconds < 60 { return english ? "just now" : "刚刚" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return english ? "\(minutes)m ago" : "\(minutes)分钟前" }
        let hours = minutes / 60
        return english ? "\(hours)h ago" : "\(hours)小时前"
    }
    static func text(observedAt: Date?, now: Date, language: SettingsLanguage = .english) -> String {
        guard let observedAt else { return unknown(language: language) }
        let age = now.timeIntervalSince(observedAt)
        guard age.isFinite, age >= 0, age < Double(Int.max) else { return unknown(language: language) }
        if age < 60 { return language == .english ? "Reading taken <1m ago" : "读取于 1 分钟内" }
        if age < 3600 {
            let minutes = Int(age / 60)
            return language == .english ? "Reading taken \(minutes)m ago" : "读取于 \(minutes) 分钟前"
        }
        let hours = Int(age / 3600)
        return language == .english ? "Reading taken \(hours)h ago" : "读取于 \(hours) 小时前"
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
