// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanDock

/// Captures the provider pair and reset events from one accepted Store delivery.
/// It does not create a reader or promote retained facts to fresh.
@MainActor final class HostPairedProjection {
    private let store: EngineStore
    private let source: EngineDockMenuProvider
    private let provider: EngineDockContentProvider
    private let client: any EngineClient
    private var pinnedEvents: EngineRowsEventState?
    var isProjecting: Bool { pinnedEvents != nil }
    private var captured: HostRowsSnapshotFence.Capture?
    private(set) var evaluatedAt: Date?
    private(set) var generation: UInt64 = 0

    init(store: EngineStore, source: EngineDockMenuProvider,
         provider: EngineDockContentProvider, client: any EngineClient) {
        self.store = store; self.source = source; self.provider = provider; self.client = client
        provider.resetEventState = { [weak self] in
            guard let self else { return .absentFromSchema }
            return self.pinnedEvents ?? EngineRowsEventDecoder.decode(self.store.snapshot.rows)
        }
    }

    func invalidate() { generation &+= 1; captured = nil; evaluatedAt = nil }
    func isCurrent(_ token: UInt64) -> Bool {
        guard token == generation, let captured else { return false }
        return (try? HostRowsSnapshotFence.check(captured, snapshot: store.snapshot,
            projection: source.dockContent, generation: generation, isCurrent: client.isCurrent)) != nil
    }

    func make(_ context: DockContentContext) throws -> HostDeadlineDriver<DockContent>.Candidate {
        // A nested projection cannot borrow an outer pass's reset facts.
        guard pinnedEvents == nil else { throw HostVerifiedWindowError.staleSnapshot }
        let token = generation
        let first = try HostRowsSnapshotFence.capture(snapshot: store.snapshot,
            projection: source.dockContent, generation: token, isCurrent: client.isCurrent)
        pinnedEvents = first.resetEvents
        defer { pinnedEvents = nil }
        let pair = provider.makeContentAndDeadline(context)
        try HostRowsSnapshotFence.check(first, snapshot: store.snapshot,
            projection: source.dockContent, generation: generation, isCurrent: client.isCurrent)
        captured = first
        let deadline: DockContentRecomputeDeadline
        switch pair.deadline {
        case .scheduled(let date, let unknown): deadline = .scheduled(date, hasUnknownDeadline: unknown)
        case .unknown: deadline = .unknown
        case .none: deadline = .none
        }
        let proofs = pair.verifiedWindows.map { fact in
            HostVerifiedWindowFact(memberID: fact.memberID, windowID: fact.windowID,
                remainingPercent: fact.remainingPercent, resetsAt: fact.resetsAt,
                issuedAt: fact.issuedAt, until: fact.until)
        }
        do {
            let result = try HostVerifiedWindowAdapter.candidate(.init(content: pair.content,
                deadline: deadline, verifiedWindows: proofs, evaluatedAt: context.now,
                sourceToken: token), sourceIsCurrent: isCurrent)
            guard isCurrent(token) else { throw HostVerifiedWindowError.staleSnapshot }
            evaluatedAt = context.now
            return result
        } catch {
            captured = nil; evaluatedAt = nil
            throw error
        }
    }
}

/// Only an admitted pair inside its evaluated clock interval can be read.
/// A late timer or clock rollback clears before synchronously requesting a new pass.
@MainActor final class HostPairedContentCache: DockContentProvider {
    private var value: DockContent?
    private var evaluatedAt: Date?
    var isCurrent: (@MainActor () -> Bool)?
    var onStale: (@MainActor () -> Void)?
    func install(_ value: DockContent, evaluatedAt: Date) {
        self.value = value; self.evaluatedAt = evaluatedAt
    }
    func clear() { value = nil; evaluatedAt = nil }
    func makeContent(_ context: DockContentContext) -> DockContent {
        guard let value, let evaluatedAt else { return empty() }
        guard valid(value, evaluatedAt: evaluatedAt, now: context.now) else {
            clear(); onStale?()
            if let replacement = self.value, let at = self.evaluatedAt,
               valid(replacement, evaluatedAt: at, now: context.now) { return replacement }
            return empty()
        }
        return value
    }
    private func valid(_ value: DockContent, evaluatedAt: Date, now: Date) -> Bool {
        guard now.timeIntervalSinceReferenceDate.isFinite,
              evaluatedAt.timeIntervalSinceReferenceDate.isFinite, now >= evaluatedAt,
              isCurrent?() == true else { return false }
        if case .some(.scheduled(let date, _)) = value.recomputeDeadline {
            return date.timeIntervalSinceReferenceDate.isFinite && now < date
        }
        return true
    }
    private func empty() -> DockContent { DockContent(snapshot: .init(inputs: []), menuStatusLines: []) }
}
