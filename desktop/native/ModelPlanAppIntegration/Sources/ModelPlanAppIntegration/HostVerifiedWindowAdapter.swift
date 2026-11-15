// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings

/// A value-only copy of a proof from one accepted Provider projection.
struct HostVerifiedWindowFact: Equatable, Sendable {
    let memberID: String
    let windowID: String
    let remainingPercent: Double
    let resetsAt: Date?
    let issuedAt: Date
    let until: Date
}

/// One synchronous accepted Provider result, captured with the Host generation and evaluation time.
struct HostVerifiedContentFacts: Sendable {
    let content: DockContent
    let deadline: DockContentRecomputeDeadline?
    let verifiedWindows: [HostVerifiedWindowFact]
    let evaluatedAt: Date
    let sourceToken: UInt64
    var language: String = "en"
}

enum HostVerifiedWindowError: Error, Equatable {
    case staleSnapshot, invalidProof, duplicateIdentity, unmatchedIdentity, inadmissibleSource
}

/// M2 consumes proofs; only the Provider can issue them. Never creates membership,
/// invents an unknown deadline or upgrades an aggregate stale source to fresh.
@MainActor enum HostVerifiedWindowAdapter {
    private struct Key: Hashable { let member: String, window: String }

    static func apply(_ content: DockContent, proofs: [HostVerifiedWindowFact], now: Date,
                      sourceToken: UInt64, language: String = "en", sourceIsCurrent: @MainActor (UInt64) -> Bool) throws -> DockContent {
        guard sourceIsCurrent(sourceToken) else { throw HostVerifiedWindowError.staleSnapshot }
        guard now.timeIntervalSinceReferenceDate.isFinite else { throw HostVerifiedWindowError.invalidProof }
        let original = content.snapshot
        guard Set(original.inputs.map(\.id)).count == original.inputs.count,
              Set(original.subscriptions.map(\.id)).count == original.subscriptions.count else {
            throw HostVerifiedWindowError.duplicateIdentity
        }
        var facts: [Key: HostVerifiedWindowFact] = [:]
        for proof in proofs {
            guard !proof.memberID.isEmpty, !proof.windowID.isEmpty,
                  proof.remainingPercent.isFinite, (0...100).contains(proof.remainingPercent),
                  proof.issuedAt.timeIntervalSinceReferenceDate.isFinite, proof.issuedAt == now,
                  proof.until.timeIntervalSinceReferenceDate.isFinite, proof.until > proof.issuedAt,
                  proof.resetsAt.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true else {
                throw HostVerifiedWindowError.invalidProof
            }
            let key = Key(member: proof.memberID, window: proof.windowID)
            guard facts.updateValue(proof, forKey: key) == nil else { throw HostVerifiedWindowError.duplicateIdentity }
        }
        var pending = Set(facts.keys)
        let subscriptions = Dictionary(uniqueKeysWithValues: original.subscriptions.map { ($0.id, $0) })
        var inputs: [DockInstrumentInput] = []
        for var input in original.inputs {
            guard Set(input.windows.map(\.id)).count == input.windows.count else { throw HostVerifiedWindowError.duplicateIdentity }
            let memberFacts = facts.filter { $0.key.member == input.id }
            let subscription = subscriptions[input.id]
            if !memberFacts.isEmpty {
                guard let subscription, !subscription.isUnstable,
                      subscription.source == .fresh || subscription.source == .stale,
                      input.dataState != .loading else { throw HostVerifiedWindowError.inadmissibleSource }
            }
            if subscription?.source == .stale { input.dataState = .stale }
            if subscription == nil || subscription?.source == .denied || subscription?.source == .readerDisabled || subscription?.source == .unavailable {
                input.dataState = .unavailable
            }
            for index in input.windows.indices {
                let key = Key(member: input.id, window: input.windows[index].id)
                guard let proof = facts[key] else {
                    // A raw window value is not proof, even when its aggregate row says fresh.
                    input.windows[index].remainingPercent = nil; input.windows[index].resetsAt = nil
                    input.windows[index].validity = .unavailable
                    continue
                }
                pending.remove(key)
                // Never render a proof after its own deadline, even if a timer is late.
                guard now < proof.until else {
                    input.windows[index].remainingPercent = nil; input.windows[index].resetsAt = nil
                    input.windows[index].validity = .unavailable
                    continue
                }
                if let existing = input.windows[index].remainingPercent, existing != proof.remainingPercent {
                    throw HostVerifiedWindowError.invalidProof
                }
                if let existing = input.windows[index].resetsAt, existing != proof.resetsAt {
                    throw HostVerifiedWindowError.invalidProof
                }
                input.windows[index].remainingPercent = proof.remainingPercent
                input.windows[index].resetsAt = proof.resetsAt
                input.windows[index].validity = .verifiedCurrent(until: proof.until)
            }
            let hasCurrentWindow = input.windows.contains { window in
                guard case .verifiedCurrent(let until) = window.validity else { return false }
                return now < until && window.remainingPercent != nil
            }
            if input.dataState == .fresh && !input.windows.isEmpty && !hasCurrentWindow {
                input.dataState = .unavailable
            }
            inputs.append(input)
        }
        guard pending.isEmpty else { throw HostVerifiedWindowError.unmatchedIdentity }
        var rows = original.presentationRows
        for input in inputs {
            guard let row = rows[input.id] else { continue }
            let provenIDs = Set(input.windows.compactMap { window -> String? in
                guard case .verifiedCurrent(let until) = window.validity, now < until,
                      window.remainingPercent != nil else { return nil }
                return window.id
            })
            let safeResetTimes = row.resetTimes.filter { provenIDs.contains($0.key) && $0.value > now }
            let admitted = subscriptions[input.id].map {
                !$0.isUnstable && ($0.source == .fresh || $0.source == .stale)
            } ?? false
            let unproved = input.dataState == .unavailable && subscriptions[input.id]?.source == .fresh
            let reason = unproved ? (language == "en" ? "Reading unavailable" : "读数不可用") : row.reason
            let nextStep = unproved ? (language == "en" ? "Check Settings" : "请检查设置") : row.nextStep
            rows[input.id] = .init(input: input, reason: reason, nextStep: nextStep,
                originalObservedAt: admitted ? row.originalObservedAt : nil,
                plan: admitted ? row.plan : "", sourceName: admitted ? row.sourceName : "",
                resetTimes: safeResetTimes,
                windowDescriptions: row.windowDescriptions.filter { provenIDs.contains($0.key) },
                // Public reset notices are independently admitted by the Provider;
                // missing private quota proof must not erase that public status.
                additionalRows: admitted ? row.additionalRows : row.additionalRows.filter { $0.kind == .notice && $0.id.hasPrefix("reset-event:") },
                resetCountExpiry: admitted ? row.resetCountExpiry : nil,
                links: row.links,
                windowObservations: row.windowObservations.map { observations in
                    admitted ? observations.filter { provenIDs.contains($0.key) || $0.value.verifiedRetained } : [:]
                },
                cardReadingState: unproved ? .error : (admitted || row.cardReadingState == .loading ? row.cardReadingState : .error))
            rows[input.id]?.actionLabel = row.actionLabel
        }
        let snapshot = CommunityDockSnapshot(inputs: inputs, subscriptions: original.subscriptions,
            presentationRows: rows, unavailableReason: original.unavailableReason,
            readerDiagnostics: original.readerDiagnostics, emptyDiagnostic: original.emptyDiagnostic)
        guard sourceIsCurrent(sourceToken) else { throw HostVerifiedWindowError.staleSnapshot }
        let states = Dictionary(uniqueKeysWithValues: inputs.map { ($0.id, $0.dataState) })
        let provenMembers = Set(inputs.filter { input in
            input.windows.contains { window in
                guard case .verifiedCurrent(let until) = window.validity else { return false }
                return now < until && window.remainingPercent != nil
            }
        }.map(\.id))
        let signals = content.signals.compactMap { original -> DockSubscriptionSignal? in
            guard let state = states[original.id] else { return nil }
            var signal = original; signal.dataState = provenMembers.contains(original.id) ? state : .unavailable; return signal
        }
        // Rebuild menu text from the same proof-checked values, never the raw
        // preformatted Provider lines that bypass this projection.
        let lines = inputs.map { input -> String in
            let reading = try? DockInstrumentProjection.evaluate(input, now: now)
            return [reading?.alias ?? reading?.name ?? input.name, reading?.readout ?? "--", rows[input.id]?.reason]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        }
        return .init(snapshot: snapshot, menuStatusLines: lines.isEmpty ? content.emptyText.map { [$0] } : lines,
                     emptyText: content.emptyText, signals: signals, recomputeDeadline: content.recomputeDeadline)
    }
    /// `content`, `deadline` and `proofs` must be mapped synchronously from the
    /// same accepted Provider pair; no later side-channel read is admissible.
    static func candidate(_ facts: HostVerifiedContentFacts,
                          sourceIsCurrent: @MainActor (UInt64) -> Bool) throws -> HostDeadlineDriver<DockContent>.Candidate {
        let content = facts.content, deadline = facts.deadline, proofs = facts.verifiedWindows
        let now = facts.evaluatedAt, sourceToken = facts.sourceToken
        let checked = try apply(content, proofs: proofs, now: now, sourceToken: sourceToken, language: facts.language, sourceIsCurrent: sourceIsCurrent)
        let active = proofs.filter { now < $0.until }
        let bounded: DockContentRecomputeDeadline?
        switch deadline {
        case .some(.scheduled(let date, let unknown)):
            guard date.timeIntervalSinceReferenceDate.isFinite, now < date else { throw HostVerifiedWindowError.invalidProof }
            let earliestProof = active.map(\.until).min()
            bounded = .scheduled(earliestProof.map { min($0, date) } ?? date, hasUnknownDeadline: unknown)
        case .some(.unknown), .some(.none), .none:
            // A current proof has a known future boundary and cannot be paired with no timer fact.
            guard active.isEmpty else { throw HostVerifiedWindowError.invalidProof }
            bounded = deadline
        }
        guard sourceIsCurrent(sourceToken) else { throw HostVerifiedWindowError.staleSnapshot }
        let bound = DockContent(snapshot: checked.snapshot, menuStatusLines: checked.menuStatusLines,
            emptyText: checked.emptyText, signals: checked.signals, recomputeDeadline: bounded)
        return .init(value: bound, sourceToken: sourceToken, deadline: bounded)
    }

}
