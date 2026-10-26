// SPDX-License-Identifier: MIT
import Foundation

public enum HelpUIMapMode: Equatable, Sendable { case hidden, heldOption, latched }
public enum HelpUIProfile: Equatable, Sendable { case tall890, compact640 }
public enum HelpUIDismissReason: Equatable, Sendable { case escape, pointer, explicitButton }

public struct HelpUIAnchor: Equatable, Sendable {
    public let id: String
    /// Coordinates in this overlay's top-left origin, supplied by the owning live surface.
    public let rect: CGRect
    public let visible: Bool
    public init(id: String, rect: CGRect, visible: Bool = true) { self.id = id; self.rect = rect; self.visible = visible }
}
public struct HelpUIContextCard: Equatable, Sendable {
    public let id: String, anchorID: String
    public let explanation: HelpExplanation
    public let actionID: String?, actionTitle: String?
    public init(id: String, anchorID: String, explanation: HelpExplanation, actionID: String? = nil, actionTitle: String? = nil) {
        self.id = id; self.anchorID = anchorID; self.explanation = explanation; self.actionID = actionID; self.actionTitle = actionTitle
    }
}
/// The sole upper arbiter supplies this offer/token and exact localized copy. No hint kind/ledger lives here.
public struct HelpUIFirstUseCard: Equatable, Sendable {
    public let offerID: UUID
    public let anchorID: String, text: String, dismissTitle: String
    public init(offerID: UUID, anchorID: String, text: String, dismissTitle: String) {
        self.offerID = offerID; self.anchorID = anchorID; self.text = text; self.dismissTitle = dismissTitle
    }
}
public struct HelpUIMapInput: Equatable, Sendable {
    public var mode: HelpUIMapMode
    public var surface: HelpMapSurface
    public var regionAnchors: [HelpMapRegion: String]
    /// Frozen/private placement is injected as gutter columns, never inferred by moving instruments.
    public var columns: [CGRect]
    public var header: CGRect
    /// Optional complete private/frozen frame recipe. Every eligible caption must be supplied and fit.
    /// Use this to keep state-specific Detach/Put back frames stable without shifting neighbouring notes.
    public var captionFrames: [String: CGRect]?
    /// Task72 replaces the old pin caption. A visible pin-region anchor requires an injected override.
    public var sentenceOverrides: [HelpMapRegion: String] = [:]
    public var todayAverageAnchorID: String?, liveSpeedAnchorID: String?
    public var returnFocusID: String?
    public var sourceActionID: String?, sourceActionTitle: String?
    public var sourceFrame: CGRect?
    /// Current host facts not represented by P02's fixed directory, e.g. visible 0/1–6 shortcut facts.
    public var supplements: [HelpUIMapSupplement] = []
    public init(mode: HelpUIMapMode = .hidden, surface: HelpMapSurface = .cockpit,
                regionAnchors: [HelpMapRegion: String] = [:], columns: [CGRect] = [], header: CGRect = .zero) {
        self.mode = mode; self.surface = surface; self.regionAnchors = regionAnchors; self.columns = columns; self.header = header
    }
}
public struct HelpUIMapSupplement: Equatable, Sendable {
    public let id: String, anchorID: String, text: String
    public init(id: String, anchorID: String, text: String) { self.id=id;self.anchorID=anchorID;self.text=text }
}
public struct HelpUIRenderInput: Equatable, Sendable {
    public var sessionID: UUID
    public var viewport: CGSize
    public var profile: HelpUIProfile
    public var language: InstrumentLanguage
    public var anchors: [HelpUIAnchor]
    public var liveReadings: [CGRect]
    public var map: HelpUIMapInput
    /// Already resolved by the source's existing 500ms dwell/immediate keyboard-focus boundary.
    /// Bind Engine/Fader/MainScreen onHelpChange; this layer adds no dwell/hint timer or legacy queue.
    public var contextual: HelpUIContextCard?
    public var firstUse: HelpUIFirstUseCard?
    public var active = true, reduceMotion = false, reduceTransparency = false
    public init(sessionID: UUID, viewport: CGSize, profile: HelpUIProfile, language: InstrumentLanguage,
                anchors: [HelpUIAnchor], liveReadings: [CGRect] = [], map: HelpUIMapInput = .init(),
                contextual: HelpUIContextCard? = nil, firstUse: HelpUIFirstUseCard? = nil) {
        self.sessionID = sessionID; self.viewport = viewport; self.profile = profile; self.language = language
        self.anchors = anchors; self.liveReadings = liveReadings; self.map = map; self.contextual = contextual; self.firstUse = firstUse
    }
}
public enum HelpUIAction: Equatable, Sendable {
    case dismissMap(reason: HelpUIDismissReason, returnFocusID: String?)
    case dismissHint(offerID: UUID, reason: HelpUIDismissReason)
    case dismissContext(id: String, returnFocusID: String?)
    case contextualAction(id: String, actionID: String)
    case contextualHover(id: String, inside: Bool)
    case mapSourceAction(actionID: String)
}
public struct HelpUIMapLabel: Equatable, Sendable {
    public let id: String, text: String, anchorID: String
    public let frame: CGRect
    public let leader: [CGPoint]
    public init(id: String, text: String, anchorID: String, frame: CGRect, leader: [CGPoint]) {
        self.id=id;self.text=text;self.anchorID=anchorID;self.frame=frame;self.leader=leader
    }
}
public enum HelpUICardIdentity: Equatable, Sendable { case context(String), firstUse(UUID) }
public struct HelpUICardPlacement: Equatable, Sendable {
    public let identity: HelpUICardIdentity
    public let anchorID: String
    public let frame: CGRect
    public init(identity: HelpUICardIdentity, anchorID: String, frame: CGRect) { self.identity=identity;self.anchorID=anchorID;self.frame=frame }
}
/// Geometry eligibility only. This never means WindowServer-visible or confirmShown/seen/budget spent.
public struct HelpUIPresentation: Equatable, Sendable {
    public let sessionID: UUID
    public let mapHeader: CGRect?
    public let mapLabels: [HelpUIMapLabel]
    public let mapSourceFrame: CGRect?
    public let unresolvedMapIDs: [String]
    public let card: HelpUICardPlacement?
    public init(sessionID: UUID, mapHeader: CGRect? = nil, mapLabels: [HelpUIMapLabel] = [], mapSourceFrame: CGRect? = nil,
                unresolvedMapIDs: [String] = [], card: HelpUICardPlacement? = nil) {
        self.sessionID=sessionID;self.mapHeader=mapHeader;self.mapLabels=mapLabels;self.mapSourceFrame=mapSourceFrame;self.unresolvedMapIDs=unresolvedMapIDs;self.card=card
    }
}
