// SPDX-License-Identifier: MIT
import Foundation

/// One synchronous observation from the existing store. No retained feed, decoder or scheduler.
/// observedAt is the host's observation clock, never a generatedAt or per-model usage timestamp.
public struct SnapshotObservation: Sendable {
    public let observedAt: Date
    public let snapshot: JoinedSnapshot?
    public let selectionFeeds: ModelSelectionFeeds
    public let diagnostics: StoreDiagnostics
}
