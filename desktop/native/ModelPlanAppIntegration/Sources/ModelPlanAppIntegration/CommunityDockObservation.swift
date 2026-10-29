// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanDock

enum CommunityDockWindowIdentity {
    static func make(account: Int, window: Int) -> String { "account.\(account).window.\(window)" }
}
/// Original account evidence only. Rendering/CLI report time never becomes an account observation.
enum CommunityObservationAge {
    static let unknown = "Observation time unknown / 观测时间未知"
    static func text(observedAt: Date?, now: Date) -> String {
        guard let observedAt else { return unknown }
        let age = now.timeIntervalSince(observedAt)
        guard age.isFinite, age >= 0, age < Double(Int.max) else { return unknown }
        if age < 60 { return "Observed <1m ago / 1分钟内观测" }
        if age < 3600 { let minutes = Int(age / 60); return "Observed \(minutes)m ago / \(minutes)分钟前观测" }
        let hours = Int(age / 3600)
        return "Observed \(hours)h ago / \(hours)小时前观测"
    }
}
enum CommunityDockObservation {
    static func text(input: DockInstrumentInput, snapshot: JoinedSnapshot?, model: CommunityDockSnapshot?, now: Date) -> String {
        let accounts = Array((snapshot?.personal.accounts ?? []).enumerated().filter { $0.element.subscription?.subscriptionRef == input.id })
        if !accounts.isEmpty {
            if let selected = (try? DockInstrumentProjection.evaluate(input, now: now))?.selectedWindowID {
                for (accountIndex, account) in accounts {
                    for windowIndex in (account.windows ?? []).indices {
                        if CommunityDockWindowIdentity.make(account: accountIndex, window: windowIndex) == selected {
                            return CommunityObservationAge.text(observedAt: account.observedAt?.date, now: now)
                        }
                    }
                }
                return CommunityObservationAge.unknown
            }
            return CommunityObservationAge.text(observedAt: accounts.count == 1 ? accounts[0].element.observedAt?.date : nil, now: now)
        }
        return CommunityObservationAge.text(observedAt: model?.presentationRows[input.id]?.originalObservedAt, now: now)
    }
}
