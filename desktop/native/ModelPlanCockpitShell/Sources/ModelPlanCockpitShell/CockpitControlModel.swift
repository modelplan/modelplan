// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanPrimitives

/// A content view may expose registered controls beyond its layout slot, within the vessel bounds.
@MainActor public protocol CockpitOverflowHitTesting: AnyObject { var interactionBounds: CGRect { get } }

@MainActor public protocol CockpitPresentationConsumer: AnyObject {
    func setPresentationAllowed(_ allowed: Bool)
    func stop()
}

public enum CockpitControlID: String, CaseIterable, Sendable { case shutter, alert, settings, attachment, close }
public enum CockpitControlAction: Equatable, Sendable {
    case setWindowClosed(Bool), openAlerts, openSettings, toggleAttachment, close
}
/// M0 owns physical thresholds, placement, snap, persistence and the resulting attached state.
/// These are global AppKit points (Y up), never root-scaled content coordinates.
public enum CockpitTitleDragInput: Equatable, Sendable {
    case began(point: CGPoint, backingScale: CGFloat)
    case moved(point: CGPoint, backingScale: CGFloat)
    case ended(point: CGPoint, backingScale: CGFloat)
    case cancelled
}
public enum CockpitInputCancellation: String, Sendable { case movement, leave, pointerDown, keyboard, focusLoss, removal, layoutChange, teardown }
/// Consumer events only. The single app-owned Settings arbiter owns all dwell/budget/priority/storage policy.
public enum CockpitHintInput: Sendable {
    case entered(control: CockpitControlID, anchor: CGRect, pointer: CGPoint, at: Double)
    case moved(control: CockpitControlID, pointer: CGPoint, at: Double)
    case cancelled(CockpitInputCancellation, at: Double)
}
public struct CockpitStripState {
    public let appearance: RenderProfile
    public let windowClosed: Bool, windowEnabled: Bool, detached: Bool
    public init(appearance: RenderProfile, windowClosed: Bool, windowEnabled: Bool = true, detached: Bool = false) {
        self.appearance = appearance; self.windowClosed = windowClosed; self.windowEnabled = windowEnabled; self.detached = detached
    }
}
public struct CockpitStripLayout {
    public let size: CGSize
    public let controls: [CockpitControlID: CGRect]
    public let shutterTravel: CGFloat
    public init(size: CGSize, controls: [CockpitControlID: CGRect], shutterTravel: CGFloat) {
        self.size = size; self.controls = controls; self.shutterTravel = shutterTravel
    }
}
public struct CockpitButtonState {
    public let pressed: Bool, hovered: Bool, focused: Bool
    public let shutterFraction: CGFloat
    public let lampSeverity: CautionLampModel.Severity?
    public init(pressed: Bool = false, hovered: Bool = false, focused: Bool = false,
                shutterFraction: CGFloat = 0, lampSeverity: CautionLampModel.Severity? = nil) {
        self.pressed = pressed; self.hovered = hovered; self.focused = focused
        self.shutterFraction = shutterFraction; self.lampSeverity = lampSeverity
    }
}
public struct CockpitControlArtwork {
    public let base: CGImage
    public let light: CGImage?
    /// Relative to the logical hit rectangle; permits registered art/glow overhang without moving the hit target.
    public let bounds: CGRect
    public init(base: CGImage, light: CGImage? = nil, bounds: CGRect) { self.base = base; self.light = light; self.bounds = bounds }
}
public struct CockpitShutterArtwork {
    public let track: CockpitControlArtwork, thumb: CockpitControlArtwork, blind: CockpitControlArtwork
    public init(track: CockpitControlArtwork, thumb: CockpitControlArtwork, blind: CockpitControlArtwork) {
        self.track = track; self.thumb = thumb; self.blind = blind
    }
}
@MainActor public protocol CockpitStripSkin: AnyObject {
    func layout(for state: CockpitStripState) throws -> CockpitStripLayout
    func decoration(for state: CockpitStripState) throws -> CockpitControlArtwork?
    func drawStrip(in context: CGContext, bounds: CGRect, state: CockpitStripState)
    func artwork(for control: CockpitControlID, state: CockpitStripState, button: CockpitButtonState) throws -> CockpitControlArtwork
    func shutterArtwork(for state: CockpitStripState, focused: Bool) throws -> CockpitShutterArtwork
    func discardCachedArtwork()
}
/// A local slider gesture, not the window's saved preference. Threshold/extent are injected presentation geometry.
public struct CockpitShutterGesture: Sendable {
    public private(set) var fraction: CGFloat
    public private(set) var moved = false
    private let x: CGFloat, initial: CGFloat, travel: CGFloat, slop: CGFloat
    public init?(x: CGFloat, closed: Bool, travel: CGFloat, slop: CGFloat = 3) {
        guard x.isFinite, travel.isFinite, travel > 0, slop.isFinite, slop >= 0 else { return nil }
        self.x = x; self.travel = travel; self.slop = slop; initial = closed ? 1:0; fraction = initial
    }
    public mutating func move(to x: CGFloat) {
        guard x.isFinite else { return }
        let delta = x-self.x
        if abs(delta)>slop { moved = true }
        if moved { fraction = max(0,min(1,initial+delta/travel)) }
    }
    public mutating func finish(at x: CGFloat, enabled: Bool) -> Bool? {
        guard enabled, x.isFinite else { return nil }; move(to:x)
        return moved ? fraction>=0.5 : initial==0
    }
}
public struct CockpitHelpTarget: Sendable {
    public let id: String, anchor: CGRect, label: String, accessibilityLabel: String
    public init(id: String, anchor: CGRect, label: String, accessibilityLabel: String) {
        self.id = id; self.anchor = anchor; self.label = label; self.accessibilityLabel = accessibilityLabel
    }
}
public enum CockpitControlWords {
    public static func label(_ id: CockpitControlID, chinese: Bool, detached: Bool) -> String {
        switch id {
        case .shutter: return chinese ? "舷窗快门":"Window shutter"
        case .alert: return chinese ? "警报":"Alert"
        case .settings: return chinese ? "设置":"Settings"
        case .attachment: return chinese ? (detached ? "放回菜单栏":"分离窗口"):(detached ? "Put back":"Detach")
        case .close: return chinese ? "关闭":"Close"
        }
    }
    public static func accessibility(_ id: CockpitControlID, chinese: Bool, detached: Bool) -> String {
        if id == .attachment { return chinese ? (detached ? "放回菜单栏":"分离为独立窗口"):(detached ? "Put back in the menu bar":"Detach into its own window") }
        return label(id,chinese:chinese,detached:detached)
    }
}

@MainActor public extension CockpitStripSkin {
    func decoration(for state: CockpitStripState) throws -> CockpitControlArtwork? { nil }
}
