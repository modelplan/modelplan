// SPDX-License-Identifier: MIT
import AppKit

public struct CockpitRocketProjection: Equatable, Sendable {
    public struct Point: Equatable, Sendable {
        public let modelID:String, normalized:CGPoint
        public let visible:Bool
        public init(modelID:String,normalized:CGPoint,visible:Bool = true) {
            self.modelID = modelID;self.normalized = normalized;self.visible = visible
        }
    }
    public let captureID:String,stillKey:String,points:[Point]
    public init(captureID:String,stillKey:String,points:[Point]) {
        self.captureID = captureID;self.stillKey = stillKey;self.points = points
    }
    /// Viewport points, independent of backing pixels or the cockpit root's uniform scale.
    public func nearest(to point:CGPoint,admittedIDs:Set<String>,radius:CGFloat = 28,
                        convertNormalizedPoint:(CGPoint)->CGPoint)->String? {
        guard point.x.isFinite,point.y.isFinite,radius.isFinite,radius>0,
              points.count<=256,Set(points.map(\.modelID)).count==points.count else { return nil }
        var best:String?,distance = radius
        for candidate in points where candidate.visible && admittedIDs.contains(candidate.modelID) {
            let p = candidate.normalized
            guard p.x.isFinite,p.y.isFinite,(0...1).contains(p.x),(0...1).contains(p.y) else { continue }
            let viewport = convertNormalizedPoint(p)
            guard viewport.x.isFinite,viewport.y.isFinite else { continue }
            let next = hypot(point.x-viewport.x,point.y-viewport.y)
            if next<=radius && (best==nil || next<distance) { best = candidate.modelID;distance = next }
        }
        return best
    }
}
public enum CockpitPortholeTrigger: Sendable { case field, zoom, keyboard, accessibility }
public struct CockpitPortholeGesture: Sendable {
    public let timestamp:Double,windowPoint:CGPoint,clickCount:Int
    public let windowNumber:Int?
    public init(timestamp:Double,windowPoint:CGPoint,clickCount:Int,windowNumber:Int? = nil) {
        self.timestamp = timestamp;self.windowPoint = windowPoint;self.clickCount = clickCount;self.windowNumber = windowNumber
    }
}
public struct CockpitPortholeIntent: Sendable {
    /// Nil means retain the host's current selection. This is never a new recommendation.
    public let focusModelID:String?
    public let captureID:String?,trigger:CockpitPortholeTrigger,gesture:CockpitPortholeGesture?
}
public enum CockpitPortholeWords {
    public static func openField(chinese:Bool)->String { chinese ? "点击打开 3D 发射场":"Click to open the 3D launch field" }
}
public enum CockpitPortholeHelpInput:Sendable {
    case entered(target:CockpitHelpTarget,pointer:CGPoint,at:Double)
    case moved(pointer:CGPoint,at:Double)
    case cancelled(CockpitInputCancellation,at:Double)
}
public struct CockpitPortholeState {
    public let size:CGSize,imageRect:CGRect,still:CockpitStill?
    public let admittedModelIDs:[String]
    public let closed:Bool,interactive:Bool,rendererAvailable:Bool
    public let accessibilityLabel:String,locale:String
    public var helpText:String { CockpitPortholeWords.openField(chinese:locale.hasPrefix("zh")) }
    public init(size:CGSize,imageRect:CGRect,still:CockpitStill?,admittedModelIDs:[String],closed:Bool,
                interactive:Bool = true,rendererAvailable:Bool = false,locale:String = "en",accessibilityLabel:String? = nil) {
        self.size = size;self.imageRect = imageRect;self.still = still;self.admittedModelIDs = admittedModelIDs
        self.closed = closed;self.interactive = interactive;self.rendererAvailable = rendererAvailable;self.locale = locale;self.accessibilityLabel = accessibilityLabel ?? CockpitPortholeWords.openField(chinese:locale.hasPrefix("zh"))
    }
}
/// Input-only leaf. The app owns the existing selection/enlargement runtime and its release gates.
/// Keep the HUD as a sibling above this input leaf; its pointer and accessibility routes stay separate.
@MainActor public final class CockpitPortholeView:NSView,CockpitPresentationConsumer {
    public override var isFlipped:Bool { true }
    public override var acceptsFirstResponder:Bool { admitted }
    /// Return true only if the existing guarded host accepted the opening request.
    public var onEnlargeRequest:((CockpitPortholeIntent)->Bool)?
    /// Consumer events only; the single host help owner owns dwell/priority/persistence/overlay.
    public var onHelpInput:((CockpitPortholeHelpInput)->Void)?
    /// Optional exact aperture admission supplied by the same skin as the displayed field.
    public var containsFieldPoint:((CGPoint)->Bool)?
    public private(set) var state:CockpitPortholeState?
    public private(set) var opening = false
    private var allowed = false
    private var openingGesture:CockpitPortholeGesture?
    private var fieldTracking:NSTrackingArea?,hovering = false
    private var stateRevision:UInt64 = 0,dispatching = false,tearingDown = false
    public override init(frame:NSRect) {
        super.init(frame:frame);setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityIdentifier("cockpit.field")
    }
    public convenience init() { self.init(frame:.zero) }
    public required init?(coder:NSCoder) { return nil }
    public func configure(_ state:CockpitPortholeState) throws {
        guard !tearingDown else { throw CockpitSurfaceError.invalidGeometry }
        let root = CGRect(origin:.zero,size:state.size),r = state.imageRect
        guard [state.size.width,state.size.height,r.minX,r.minY,r.width,r.height].allSatisfy(\.isFinite),
              state.size.width>0,state.size.height>0,state.size.width<=2048,state.size.height<=2048,
              r.width>0,r.height>0,root.contains(r),state.admittedModelIDs.count<=256,
              Set(state.admittedModelIDs).count==state.admittedModelIDs.count,
              state.admittedModelIDs.allSatisfy({!$0.isEmpty && $0.utf8.count<=1024}),state.accessibilityLabel.utf8.count<=4096,!state.locale.isEmpty,state.locale.utf8.count<=64 else { throw CockpitSurfaceError.invalidGeometry }
        let cancel = self.state?.imageRect != state.imageRect || self.state?.locale != state.locale || self.state?.closed != state.closed || self.state?.interactive != state.interactive || self.state?.rendererAvailable != state.rendererAvailable || self.state?.accessibilityLabel != state.accessibilityLabel || self.state?.still?.key != state.still?.key || self.state?.still?.captureID != state.still?.captureID
        stateRevision &+= 1
        self.state = state;frame.size = state.size;setAccessibilityLabel(state.accessibilityLabel);setAccessibilityHelp(state.helpText)
        updateTrackingAreas();invalidateFieldCursor()
        if cancel { cancelHelp(.layoutChange) }
        // Refreshing metadata must not reset an already accepted opening.
    }
    public func setPresentationAllowed(_ allowed:Bool) { guard !tearingDown else { return };if self.allowed != allowed { stateRevision &+= 1 };self.allowed = allowed;if !allowed { cancelHelp(.focusLoss) };invalidateFieldCursor() }
    public func setEnlarged(_ enlarged:Bool) { guard !tearingDown else { return };opening = enlarged;if !enlarged { openingGesture = nil } else { cancelHelp(.pointerDown) };invalidateFieldCursor() }
    public func stop() {
        guard !tearingDown else { return }
        tearingDown = true;defer { tearingDown = false }
        stateRevision &+= 1;allowed = false;opening = false;openingGesture = nil;state = nil
        // Revoke first: host cancellation may call back into any public entry point.
        cancelHelp(.teardown);updateTrackingAreas();invalidateFieldCursor()
    }
    private var admitted:Bool { !tearingDown && allowed && !isHiddenOrHasHiddenAncestor && state?.closed==false && state?.interactive==true && state?.rendererAvailable==true }
    public var pointingHandRect:CGRect? { admitted && !opening ? state?.imageRect:nil }
    public func helpTargets()->[CockpitHelpTarget] {
        guard let rect = pointingHandRect,let state else { return [] }
        return [.init(id:"field",anchor:rect,label:state.helpText,accessibilityLabel:state.accessibilityLabel)]
    }
    public override func resetCursorRects() {
        super.resetCursorRects()
        if let rect = pointingHandRect { addCursorRect(rect,cursor:.pointingHand) }
    }
    private func invalidateFieldCursor() { window?.invalidateCursorRects(for:self) }
    public override func updateTrackingAreas() {
        if let fieldTracking { removeTrackingArea(fieldTracking) };fieldTracking = nil
        if let state {
            let area = NSTrackingArea(rect:state.imageRect,options:[.mouseEnteredAndExited,.mouseMoved,.activeInActiveApp],owner:self,userInfo:nil)
            addTrackingArea(area);fieldTracking = area
        }
        super.updateTrackingAreas()
    }
    private func reportHover(_ event:NSEvent) {
        let point = convert(event.locationInWindow,from:nil)
        guard let target = helpTargets().first,target.anchor.contains(point),containsFieldPoint?(point) != false else { cancelHelp(.leave);return }
        let at = ProcessInfo.processInfo.systemUptime
        if !hovering { hovering = true;onHelpInput?(.entered(target:target,pointer:point,at:at)) }
        else { onHelpInput?(.moved(pointer:point,at:at)) }
    }
    private func cancelHelp(_ reason:CockpitInputCancellation) {
        guard hovering else { return };hovering = false;onHelpInput?(.cancelled(reason,at:ProcessInfo.processInfo.systemUptime))
    }
    public override func mouseEntered(with event:NSEvent) { reportHover(event) }
    public override func mouseMoved(with event:NSEvent) { reportHover(event) }
    public override func mouseExited(with event:NSEvent) { cancelHelp(.leave) }
    public override func viewDidHide() { super.viewDidHide();cancelHelp(.leave);invalidateFieldCursor() }
    public override func viewDidUnhide() { super.viewDidUnhide();invalidateFieldCursor() }
    public override func viewDidMoveToWindow() { super.viewDidMoveToWindow();if window==nil { cancelHelp(.removal) };invalidateFieldCursor() }
    /// The existing zoom key can call the same route. No field runtime is constructed here.
    @discardableResult public func requestEnlarge(trigger:CockpitPortholeTrigger = .zoom,atLocalPoint:CGPoint? = nil,
                                                  gesture:CockpitPortholeGesture? = nil)->Bool {
        guard admitted,!opening,!dispatching,let state,onEnlargeRequest != nil else { return false }
        dispatching = true;defer { dispatching = false }
        let revision = stateRevision
        var focus:String?
        if let point = atLocalPoint {
            guard point.x.isFinite,point.y.isFinite,state.imageRect.contains(point),containsFieldPoint?(point) != false else { return false }
            if let still = state.still,let captureID = still.captureID,!captureID.isEmpty,captureID.utf8.count<=1024,!still.key.isEmpty,still.key.utf8.count<=4096,let projection = still.rocketProjection,
               projection.captureID==captureID,projection.stillKey==still.key {
                let viewportPoint = convert(point,to:nil),rect = state.imageRect
                focus = projection.nearest(to:viewportPoint,admittedIDs:Set(state.admittedModelIDs)) { normalized in
                    self.convert(CGPoint(x:rect.minX+normalized.x*rect.width,y:rect.minY+normalized.y*rect.height),to:nil)
                }
            }
        }
        // Latch before calling the host so reentrant, double-click and key paths cannot double-open.
        cancelHelp(.pointerDown)
        guard revision==stateRevision,admitted,!opening,let onEnlargeRequest else { return false }
        opening = true;openingGesture = gesture;invalidateFieldCursor()
        let accepted = onEnlargeRequest(.init(focusModelID:focus,captureID:state.still?.captureID,trigger:trigger,gesture:gesture))
        if !accepted { opening = false;openingGesture = nil;invalidateFieldCursor() }
        return accepted
    }
    /// Call before the existing backdrop-close action. Native clickCount supplies the system's
    /// spatial multi-click classification; no invented distance threshold or timer is introduced.
    public func consumeOpeningContinuation(_ next:CockpitPortholeGesture,doubleClickInterval:Double = NSEvent.doubleClickInterval)->Bool {
        guard opening,let first = openingGesture,first.clickCount==1,next.clickCount==2,
              let window = first.windowNumber,window==next.windowNumber,
              first.timestamp.isFinite,next.timestamp.isFinite,doubleClickInterval.isFinite,doubleClickInterval>=0 else { return false }
        let elapsed = next.timestamp-first.timestamp
        guard elapsed>=0 else { return false }
        if elapsed>doubleClickInterval { openingGesture = nil;return false }
        openingGesture = nil;return true
    }
    public override func mouseDown(with event:NSEvent) {
        guard event.buttonNumber==0 else { return }
        _ = requestEnlarge(trigger:.field,atLocalPoint:convert(event.locationInWindow,from:nil),
            gesture:.init(timestamp:event.timestamp,windowPoint:event.locationInWindow,clickCount:event.clickCount,windowNumber:event.windowNumber))
    }
    public override func keyDown(with event:NSEvent) {
        if [36,49,76].contains(event.keyCode) { _ = requestEnlarge(trigger:.keyboard) } else { super.keyDown(with:event) }
    }
    public override func accessibilityPerformPress()->Bool { requestEnlarge(trigger:.accessibility) }
}
