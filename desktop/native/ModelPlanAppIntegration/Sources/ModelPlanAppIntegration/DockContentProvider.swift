// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanDock

/// Existing read-only inputs for the default adapter. An engine-backed provider
/// may ignore these and read its already-admitted state; it must not run commands.
public struct DockContentContext: Sendable {
    public let snapshot: JoinedSnapshot?
    public let diagnostics: StoreDiagnostics
    public let now: Date
    public let readerFacts: [CommunityReaderFacts]
    public let canonicalConsent: ConsentPreview?
    public init(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics, now: Date,
                readerFacts: [CommunityReaderFacts] = [], canonicalConsent: ConsentPreview? = nil) {
        self.snapshot = snapshot; self.diagnostics = diagnostics; self.now = now
        self.readerFacts = readerFacts; self.canonicalConsent = canonicalConsent
    }
}

/// Timing facts for the same already-admitted content projection.
/// `none` is not a claim of perpetual validity; nil on DockContent means unsupported.
public enum DockContentRecomputeDeadline: Equatable, Sendable {
    case scheduled(Date, hasUnknownDeadline: Bool)
    case unknown
    case none
}

/// Rendering value only. nil overrides retain legacy text; empty menuStatusLines
/// intentionally suppress legacy status copy. A provider never changes placement.
public struct DockContent: Sendable {
    public let snapshot: CommunityDockSnapshot
    public let menuStatusLines: [String]?
    public let emptyText: String?
    /// Provider-owned semantic signals; presentation is selected by the host.
    public let signals: [DockSubscriptionSignal]
    /// nil means the provider has not supplied the deadline contract, not `.none`.
    public let recomputeDeadline: DockContentRecomputeDeadline?
    public init(snapshot: CommunityDockSnapshot, menuStatusLines: [String]? = nil,
                emptyText: String? = nil, signals: [DockSubscriptionSignal] = [],
                recomputeDeadline: DockContentRecomputeDeadline? = nil) {
        self.snapshot = snapshot
        self.menuStatusLines = menuStatusLines
        self.emptyText = emptyText; self.signals = signals; self.recomputeDeadline = recomputeDeadline
    }
}

@MainActor public protocol DockContentProvider: AnyObject {
    /// Pure synchronous presentation read; no host mutation, RPC or publication.
    func makeContent(_ context: DockContentContext) -> DockContent
}

/// Default preserves the existing projection and menu/empty-state formatting.
@MainActor public final class LegacyDockContentProvider: DockContentProvider {
    public init() {}
    public func makeContent(_ context: DockContentContext) -> DockContent {
        .init(snapshot: .init(snapshot: context.snapshot, diagnostics: context.diagnostics,
                             now: context.now, readerFacts: context.readerFacts,
                             canonicalConsent: context.canonicalConsent))
    }
}
