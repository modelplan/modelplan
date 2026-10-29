// SPDX-License-Identifier: MIT
import Foundation

public enum MetricMath {
    public static func generationRate(_ sums: [MetricSums]) -> Double? {
        guard !sums.isEmpty else { return nil }
        var requests: UInt64 = 0, tokens: UInt64 = 0; var milliseconds = 0.0
        for s in sums {
            guard let r = s.eligibleRequests, let t = s.eligibleOutputTokens, let ms = s.genMs, ms >= 0 else { return nil }
            let a = requests.addingReportingOverflow(r), b = tokens.addingReportingOverflow(t)
            guard !a.overflow, !b.overflow else { return nil }
            requests = a.partialValue; tokens = b.partialValue; milliseconds += ms
        }
        guard requests >= 5, milliseconds.isFinite, milliseconds > 0 else { return nil }
        let value = Double(tokens) / (milliseconds / 1000)
        return value.isFinite ? value : nil
    }
    public static func generationRate(_ rows: [PerformanceRow], window: String) -> Double? {
        guard let first = rows.first, let parser = first.parser, let eligibility = first.eligibility,
              rows.allSatisfy({ $0.parser == parser && $0.eligibility == eligibility }),
              rows.allSatisfy({ $0.windows[window] != nil }) else { return nil }
        return generationRate(rows.compactMap { $0.windows[window]?.sums })
    }
    public static func cacheHit(input: UInt64?, cacheRead: UInt64?) -> Double? {
        guard let input, let cacheRead else { return nil }
        let sum = input.addingReportingOverflow(cacheRead)
        guard !sum.overflow, sum.partialValue > 0 else { return nil }
        return Double(cacheRead) / Double(sum.partialValue)
    }
    /// Source-wide history is never promoted to historical subscription ownership.
    public static func sourceWideTodayRate(_ snapshot: PersonalSnapshot, source: String) -> SourceWideGenerationRate? {
        // todayTotals has no cross-source parser/eligibility proof; keep this statistic to one source.
        let sourceSet: Set<String> = [source]
        guard !source.isEmpty else { return nil }
        let rows = (snapshot.todayTotals ?? []).filter { sourceSet.contains($0.source) }
        guard Set(rows.map(\.source)) == sourceSet, rows.count == sourceSet.count,
              let value = generationRate(rows.map(\.sums)) else { return nil }
        return SourceWideGenerationRate(value: value, sources: sourceSet.sorted())
    }

}

public struct SourceWideGenerationRate: Sendable {
    public let value: Double
    public let sources: [String]
    public let scope = "source-wide-today"
    public let subscriptionAttribution = "unattributed"
}

public struct QuotaReading: Sendable {
    public let source: String
    public let subscription: String?
    public let kind: String
    public let remaining: Double?
    public let historicalRemaining: Double?
    public let reason: String?
    public let observedAt: Date?
}

public struct CurrentConfiguration: Sendable {
    public let source: String
    public let harnessModel: String?
    public let effort: String? // Never the legacy recommended fallback.
}

public struct LiveReading: Sendable {
    public let ref: String
    public let subscription: String?
    public let working: Bool
    public let rate: Double?
}

/// Expiry latches use the original observation, not a formatted percentage or dataRevision.
/// Moving wall time backwards cannot resurrect an observation; a fresh observation gets a new key.
public struct ExpiryLedger: Sendable {
    private var retired = Set<String>()
    private var seen = Set<String>()
    public init() {}
    mutating func begin() { seen.removeAll(keepingCapacity: true) }
    mutating func end() { retired.formIntersection(seen) }
    mutating func expired(_ key: String, deadline: Date?, now: Date) -> Bool {
        seen.insert(key)
        if let deadline, deadline <= now { retired.insert(key) }
        return retired.contains(key)
    }
}

public struct PersonalProjection: Sendable {
    public let actionable: Bool
    public let unavailableReason: String?
    public let quotas: [QuotaReading]
    public let current: [CurrentConfiguration]
    public let live: [LiveReading]
    public let events: [AdviceEvent]
    public let nextDeadline: Date?

    public static func evaluate(_ snapshot: PersonalSnapshot, now: Date, ledger: inout ExpiryLedger) -> Self {
        ledger.begin()
        let previouslyExpired = ledger.expired("snapshot|" + snapshot.generatedAt.raw, deadline: snapshot.validUntil?.date, now: now)
        let expired = !snapshot.validUntilReported || previouslyExpired
        let accounts = snapshot.accounts ?? []
        var deadlines = [snapshot.validUntil?.date].compactMap { $0 }.filter { $0 > now }
        let quotas = accounts.flatMap { account in (account.windows ?? []).map { window -> QuotaReading in
            let observed = window.observedAt ?? account.observedAt
            let key = ["quota", account.source, account.subscription?.subscriptionRef ?? "", window.kind, window.limit ?? "", observed?.raw ?? "", window.resetsAt?.raw ?? ""].joined(separator: "|")
            let resetPassed = ledger.expired(key, deadline: window.resetsAt?.date, now: now)
            if let reset = window.resetsAt?.date, reset > now { deadlines.append(reset) }
            // Native Claude and the legacy status-line share an account source name.
            // Only the native reader's status can invalidate a native account reading.
            let statusSource = account.via == "native" && account.source == "claude-code" ? "native:claude" : account.source
            let status = snapshot.sources?.first(where: { $0.source == statusSource })
            let stale = account.stale == true || (status != nil && status?.status != "ok") || status?.reason == "out-of-use"
            let reason: String? = expired ? "snapshot-expired" : resetPassed || window.pace == "reset_passed" ? "reset_passed" : stale ? "stale" : observed == nil ? "unknown-observation-time" : nil
            return QuotaReading(source: account.source, subscription: account.subscription?.subscriptionRef, kind: window.kind,
                                remaining: reason == nil ? window.remainingPercent : nil, historicalRemaining: window.remainingPercent, reason: reason, observedAt: observed?.date)
        } }
        let current = (snapshot.sessions ?? []).map { session in
            CurrentConfiguration(source: session.source, harnessModel: session.model?.harnessId,
                                 effort: !expired && session.stale != true && session.effortStatus == "reported" ? session.effort?.key : nil)
        }
        let live = (snapshot.liveSessions ?? []).map { session -> LiveReading in
            let key = "live|\(session.ref)|\(session.lastAt?.raw ?? "")"
            let until = session.lastAt?.date.addingTimeInterval(300)
            let old = ledger.expired(key, deadline: until, now: now) || session.lastAt == nil || expired
            if let until, until > now { deadlines.append(until) }
            let candidates = accounts.filter { $0.source == session.source && $0.stale != true && $0.subscription?.status == "verified" }
            let refs = Set(candidates.compactMap { $0.subscription?.subscriptionRef })
            let sub: String?
            if let reported = session.subscriptionRef { sub = refs.contains(reported) ? reported : nil }
            else { sub = refs.count == 1 ? refs.first : nil }
            let rate = session.rate
            let rateKey = "rate|\(session.ref)|\(session.effort ?? "")|\(rate?.lastAt?.raw ?? "")"
            let rateUntil = rate?.lastAt?.date.addingTimeInterval(60)
            let rateOld = ledger.expired(rateKey, deadline: rateUntil, now: now)
            if let rateUntil, rateUntil > now { deadlines.append(rateUntil) }
            let eligible = sub != nil && !old && !rateOld && rate?.lastAt != nil && rate?.status == "ok" && rate?.window == "60s" && rate?.scope == "session" && (rate?.n ?? 0) >= max(5, rate?.min ?? 5) && session.effortStatus == "reported"
            return LiveReading(ref: session.ref, subscription: sub, working: !old && session.status == "running" && sub != nil, rate: eligible ? rate?.value : nil)
        }
        let events = (snapshot.events ?? []).filter { event in
            let old = ledger.expired("event|\(event.key ?? event.type)|\(snapshot.generatedAt.raw)", deadline: event.expiresAt?.date, now: now)
            if let at = event.expiresAt?.date, at > now { deadlines.append(at) }
            return !expired && !old
        }
        ledger.end()
        return Self(actionable: !expired, unavailableReason: expired ? (!snapshot.validUntilReported ? "unknown-lifetime" : "personal-expired") : nil, quotas: quotas, current: current, live: live, events: events, nextDeadline: deadlines.min())
    }
}

public struct AliasKey: Hashable, Sendable {
    public let harness: String
    public let id: String
    public init(harness: String, id: String) { self.harness = harness; self.id = id }
}

public struct JoinedSnapshot: Sendable {
    public let personal: PersonalSnapshot
    public let presentation: PersonalProjection
    public let publication: PublicPublication?
    public let scoredUnavailableReason: String?
    public let aliases: [AliasKey: String]
    public let ambiguousAliases: Set<AliasKey>
    public func model(harness: String, id: String) -> String? { aliases[AliasKey(harness: harness, id: id)] }

    public static func make(personal: PersonalSnapshot, presentation: PersonalProjection, publication: PublicPublication?, publicUsable: Bool = true) -> Self {
        var reason: String?
        if !presentation.actionable { reason = presentation.unavailableReason ?? "personal-unavailable" }
        else if !publicUsable || publication == nil { reason = "publication-unavailable" }
        else if personal.publication?.publicationId == nil || personal.publication?.publicationId != publication?.publicationId { reason = "publication-mismatch" }
        else if publication?.supportedUnits != true { reason = "unsupported-units" }
        var aliases: [AliasKey: String] = [:], ambiguous = Set<AliasKey>()
        if reason == nil, let publication {
            for model in publication.models { for (harness, names) in model.harnessIds ?? [:] { for name in names {
                let key = AliasKey(harness: harness, id: name)
                if let old = aliases[key], old != model.id { aliases.removeValue(forKey: key); ambiguous.insert(key) }
                else if !ambiguous.contains(key) { aliases[key] = model.id }
            } } }
        }
        return Self(personal: personal, presentation: presentation, publication: reason == nil ? publication : nil, scoredUnavailableReason: reason, aliases: aliases, ambiguousAliases: ambiguous)
    }
}
