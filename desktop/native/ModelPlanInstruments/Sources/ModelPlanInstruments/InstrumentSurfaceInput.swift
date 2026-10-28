// SPDX-License-Identifier: MIT
import Foundation

/// Explicit host observations. Empty arrays never manufacture one of these states.
public enum InstrumentReaderState: String, Equatable, Sendable {
    case unknown, notDetected, noConsent, notConnectedYet, stale, available
}
public struct InstrumentReaderObservation: Sendable {
    public let sourceID: String
    public let state: InstrumentReaderState
    public let evidence: InstrumentEvidence
    public init(sourceID: String, state: InstrumentReaderState, evidence: InstrumentEvidence) {
        self.sourceID = sourceID; self.state = state; self.evidence = evidence
    }
}
public enum InstrumentSurfaceError: Error, Equatable {
    case invalidInput, invalidFrames, selectionMismatch
}

/// Supplied by the existing layout owner; this type neither chooses a profile nor places a panel.
public struct InstrumentSurfaceFrames: Equatable, Sendable {
    public let engines: CGSize, console: CGSize
    public let mainScreen: CGRect, faders: CGRect
    public init(engines: CGSize, console: CGSize, mainScreen: CGRect, faders: CGRect) throws {
        let sizes = [engines, console, mainScreen.size, faders.size]
        guard sizes.allSatisfy({ $0.width.isFinite && $0.height.isFinite && $0.width > 0 && $0.height > 0
            && $0.width <= 2048 && $0.height <= 2048 }),
            [mainScreen.minX, mainScreen.minY, faders.minX, faders.minY].allSatisfy(\.isFinite),
            CGRect(origin: .zero, size: console).contains(mainScreen),
            CGRect(origin: .zero, size: console).contains(faders),
            !mainScreen.intersects(faders) else { throw InstrumentSurfaceError.invalidFrames }
        self.engines = engines; self.console = console; self.mainScreen = mainScreen; self.faders = faders
    }
}

/// An immutable observation supplied by the one host/assembly. No reader, join, ranking or retention.
public struct InstrumentSurfaceInput: Sendable {
    public let observationID: String
    public let columns: [EngineColumn], identities: [String: EngineTableIdentity]
    public let channels: [FaderChannelInput]
    public let selection: InjectedModelSelection?, publication: SelectionPublication?
    public let publicationUsable: Bool
    public let scope: InstrumentScope, language: InstrumentLanguage
    public let now: Date
    public let compact: Bool, showProjectNames: Bool
    public let favoriteIDs: [String]
    public let pages: [MainScreenPageContent], sourcedBodies: [MainScreenSourcedBody]
    public let readers: [InstrumentReaderObservation]
    public let membershipKnowledge: InstrumentMembershipKnowledge
    public init(observationID: String, columns: [EngineColumn], identities: [String: EngineTableIdentity] = [:],
                channels: [FaderChannelInput], selection: InjectedModelSelection?, publication: SelectionPublication?,
                publicationUsable: Bool, scope: InstrumentScope, language: InstrumentLanguage, now: Date,
                compact: Bool, favoriteIDs: [String] = [], showProjectNames: Bool = true,
                pages: [MainScreenPageContent] = [], sourcedBodies: [MainScreenSourcedBody] = [],
                readers: [InstrumentReaderObservation] = [],
                membershipKnowledge: InstrumentMembershipKnowledge = .unknown) throws {
        guard !observationID.isEmpty, now.timeIntervalSinceReferenceDate.isFinite,
              Set(columns.map(\.id)).count == columns.count,
              Set(channels.map { $0.model.id }).count == channels.count,
              Set(readers.map(\.sourceID)).count == readers.count,
              pages.allSatisfy({ ($0.overview.map { $0.scope == scope } ?? true)
                && ($0.subscription.map { $0.language == language && $0.scope == scope } ?? true)
                && ($0.history.map { $0.language == language && $0.scope == scope } ?? true)
                && ($0.effort.map { $0.language == language && $0.scope == scope } ?? true)
                && ($0.destinations.map { $0.language == language && $0.scope == scope } ?? true) })
        else { throw InstrumentSurfaceError.invalidInput }
        if let selection {
            guard selection.matches(publication, scope: scope) else { throw InstrumentSurfaceError.selectionMismatch }
        }
        // Validation is identity consistency, not a second eligibility/order computation.
        if publicationUsable {
            guard let selection, selection.matchesExact(publication, scope: scope),
                  Set(channels.map { $0.model.id }).isSubset(of: Set(selection.orderedModelIDs))
            else { throw InstrumentSurfaceError.selectionMismatch }
        }
        self.observationID = observationID; self.columns = columns; self.identities = identities
        self.channels = channels; self.selection = selection; self.publication = publication
        self.publicationUsable = publicationUsable; self.scope = scope; self.language = language; self.now = now
        self.compact = compact; self.favoriteIDs = favoriteIDs; self.showProjectNames = showProjectNames
        self.pages = pages; self.sourcedBodies = sourcedBodies; self.readers = readers
        self.membershipKnowledge = membershipKnowledge
    }
}
