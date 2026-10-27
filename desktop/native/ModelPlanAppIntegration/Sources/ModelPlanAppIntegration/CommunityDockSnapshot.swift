// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings

/// Read-only adaptation of the existing store view. This value owns no reader, clock or preferences.
public struct CommunityDockSnapshot: Sendable {
    public let inputs: [DockInstrumentInput]
    public let subscriptions: [SettingsSubscription]
    public let unavailableReason: String?

    public init(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics, now: Date) {
        guard let snapshot else {
            inputs = []; subscriptions = []
            unavailableReason = diagnostics.personal ?? "personal-not-loaded"
            return
        }
        let personal = snapshot.personal
        let readable = diagnostics.personal == nil && snapshot.presentation.actionable &&
            now.timeIntervalSinceReferenceDate.isFinite && personal.generatedAt.date <= now &&
            personal.validUntilReported && personal.validUntil.map { $0.date > now } == true
        unavailableReason = readable ? nil : diagnostics.personal ?? snapshot.presentation.unavailableReason ?? "personal-unavailable"
        let accounts = personal.accounts ?? []
        // An explicit ref is real membership even when its current reading is unavailable. Never
        // manufacture an account from a source name, public catalogue, session or a demo fixture.
        var ids: [String] = []
        for id in (personal.subscriptions ?? []).map(\.subscriptionRef) + accounts.compactMap({ $0.subscription?.subscriptionRef }) {
            if !id.isEmpty && !ids.contains(id) { ids.append(id) }
        }
        var adapted: [DockInstrumentInput] = [], catalogue: [SettingsSubscription] = []
        for id in ids {
            let owned = accounts.filter { $0.subscription?.subscriptionRef == id }
            let sources = Array(Set(owned.map(\.source).filter { !$0.isEmpty })).sorted()
            let names = Array(Set(owned.compactMap { account -> String? in
                let pieces = [account.source, account.plan ?? ""].filter { !$0.isEmpty }
                return pieces.isEmpty ? nil : pieces.joined(separator: " · ")
            })).sorted()
            let name = names.isEmpty ? id : names.joined(separator: " / ")
            var windows: [DockQuotaWindowInput] = []
            var projectedOffset = 0
            var hasCurrentReading = false
            for (accountIndex, account) in accounts.enumerated() {
                let rawWindows = account.windows ?? []
                defer { projectedOffset += rawWindows.count }
                guard account.subscription?.subscriptionRef == id,
                      account.subscription?.status == "verified" else { continue }
                for (windowIndex, window) in rawWindows.enumerated() {
                    let index = projectedOffset + windowIndex
                    let quota = snapshot.presentation.quotas.indices.contains(index) ? snapshot.presentation.quotas[index] : nil
                    let matched = quota?.source == account.source && quota?.subscription == id && quota?.kind == window.kind
                    let observed = quota?.observedAt
                    let current = readable && matched && quota?.reason == nil &&
                        observed.map { $0 <= now } == true && window.unknownReason == nil && window.reason == nil
                    if current { hasCurrentReading = true }
                    // These IDs locate a reported row only; they are not invented CLI window IDs.
                    let locator = "account.\(accountIndex).window.\(windowIndex)"
                    let duration = window.windowMinutes.flatMap { minutes -> Double? in
                        let seconds = minutes * 60
                        return seconds.isFinite && seconds > 0 ? seconds : nil
                    }
                    windows.append(.init(id: locator, period: Self.period(window.kind), label: window.kind,
                        remainingPercent: current ? quota?.remaining : nil,
                        resetsAt: current ? window.resetsAt?.date : nil,
                        durationSeconds: current ? duration : nil))
                }
            }
            var input = DockInstrumentInput(id: id, name: name, windows: windows)
            let vendors = sources.compactMap { source in
                ["codex": "openai", "openai": "openai", "claude": "claude", "cursor": "cursor", "copilot": "copilot", "kimi": "kimi", "glm": "glm", "opencode": "opencode"][source.lowercased()]
            }
            if vendors.count == sources.count, Set(vendors).count == 1 { input.vendorResourceKey = vendors.first }
            input.dataState = !readable ? .stale : windows.isEmpty ? .unavailable : hasCurrentReading ? .fresh : .stale
            // A running session does not prove newly observed output. Do not invent working/jet evidence.
            adapted.append(input)
            catalogue.append(.init(id: id, name: .init(name, name),
                plan: Array(Set(owned.compactMap(\.plan))).sorted().joined(separator: " / "),
                vendor: sources.joined(separator: " / "), toolNames: sources,
                source: input.dataState == .fresh ? .fresh : input.dataState == .stale ? .stale : .unavailable))
        }
        inputs = adapted; subscriptions = catalogue
    }

    private static func period(_ kind: String) -> DockQuotaPeriod {
        switch kind {
        case "five_hour": return .fiveHour
        case "daily", "day": return .day
        case "weekly", "week": return .week
        case "monthly", "month": return .month
        default: return .other
        }
    }
}
