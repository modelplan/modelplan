// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

public enum DockInstrumentAction: Equatable, Sendable {case subscription(String),notice(String),overflow}
@MainActor private final class DockInstrumentAXNode:NSAccessibilityElement {
    var press:(()->Bool)?
    var focus:((Bool)->Void)?
    var normalHelp: String? { didSet { setAccessibilityHelp(contextualHelp ?? normalHelp) } }
    var contextualHelp: String? { didSet { setAccessibilityHelp(contextualHelp ?? normalHelp) } }
    override func accessibilityPerformPress()->Bool {press?() ?? false}
    override func setAccessibilityFocused(_ focused: Bool) { super.setAccessibilityFocused(focused); focus?(focused) }
}

/// B06 instrument surface only. Window dispatch, menus/cards, autohide and movement belong to later owners.
/// Its local alpha hit-test is NOT proof that a transparent NSWindow forwards the original cross-app click.
@MainActor public final class DockInstrumentView:NSView {
    public var requestedNozzleDiameter: CGFloat?
    public private(set) var appliedGeometryScale: CGFloat = 1
    private var communityRowHeight: CGFloat = 44
    @_spi(DockResourceChecks) public var presentedNozzleDiameters: [CGFloat] { skin?.stations.map(\.diameter) ?? [] }
    /// The host resolves the destination screen even while this view is detached/collapsed.
    public var presentationBackingScale: Int?
    /// Destination display facts are supplied by the host, never inferred from raster size.
    public var appearanceDisplaySize: CGSize?
    public var appearanceMenuBarExclusion: CGFloat = 0
    /// Current admitted notices, kept out of the static material cache.
    public var appearanceNotices: [String: DockNotice] = [:]
    /// The signed package controls this single beta-only mark switch.
    @_spi(DockResourceChecks) public var zaiMarkEnabled = (Bundle.main.object(forInfoDictionaryKey: "zaiMarkEnabled") as? Bool) ?? false
    @_spi(DockResourceChecks) public var presentedNoticesForChecks: [String: DockNotice] { failed ? [:] : notices }
    @_spi(DockResourceChecks) public var presentedReadingsForChecks: [String: DockInstrumentReading] { failed ? [:] : readings }
    /// Read-only capture of the currently presented synthetic test surface.
    @_spi(DockResourceChecks) public var presentedSkinForChecks: DockInstrumentSkin? { failed || community ? nil : skin }
    /// Skin-space origin of the view's local coordinates (the hover viewport when one is reserved).
    @_spi(DockResourceChecks) public var layoutOriginForChecks: CGPoint { layoutOrigin }
    @_spi(DockResourceChecks) public var presentedImageForChecks: CGImage? { failed || community ? nil : image }
    @_spi(DockResourceChecks) public var renderedPixelSize: CGSize? {
        image.map { CGSize(width: $0.width, height: $0.height) }
    }
    /// Quota consumers share the ink of the current successful instrument appearance.
    /// Reading/label overrides are not quota colours; failed/community appearances have no supplied ink.
    public func quotaInk(for status:DockQuotaStatus) -> DockInk? {
        guard !failed, !community else { return nil }
        return skin?.palette[status.rawValue]
    }
    public var onAction:((DockInstrumentAction)->Void)? {didSet{refreshNodes()}}
    public var permitsAction:((DockInstrumentAction,DockActionSource)->Bool)?
    /// Separate empty-state action; never routed through subscription/overflow interaction.
    public var onEmptyAction: (() -> Bool)? { didSet { refreshNodes() } }
    public var permitsEmptyAction: ((DockActionSource) -> Bool)?
    public weak var backgroundDragDelegate:(any DockBackgroundDragHandling)?
    public weak var nozzleEventDelegate:(any DockNozzleEventHandling)?
    public var keyboardNavigationEnabled=false
    public var keyboardTargetID: String? {
        didSet { if keyboardTargetID != oldValue { helpFocusChanged() } }
    }
    public var onHelpFocusChanged: (() -> Void)?
    /// G3-10: the pointer moved over (or left) the widget. The help owner re-samples which
    /// element is under the pointer; repeated samples over one element stay silent there.
    public var onHelpPointerMoved: (() -> Void)?
    public private(set) var registeredGripRects: [CGRect] = []
    public private(set) var focusedGripIndex: Int? {
        didSet { if focusedGripIndex != oldValue { updateGripEmphasis(); helpFocusChanged() } }
    }
    private var hoveredGripIndex: Int?
    private var gripOutline: CAShapeLayer?
    @_spi(DockResourceChecks) public var emphasizedGripFrameForChecks: CGRect? { gripOutline?.path?.boundingBox }

    public func registerGripRects(_ rects: [CGRect]) {
        let valid = rects.filter { !$0.isEmpty && bounds.contains($0) && isPainted(atLocal: CGPoint(x: $0.midX, y: $0.midY)) }
        guard registeredGripRects != valid else { return }
        registeredGripRects = valid
        hoveredGripIndex = nil
        focusedGripIndex = nil
        updateGripEmphasis()
        refreshNodes()
    }

    private func updateGripEmphasis() {
        guard let index = focusedGripIndex ?? hoveredGripIndex, registeredGripRects.indices.contains(index) else {
            gripOutline?.removeFromSuperlayer()
            gripOutline = nil
            return
        }
        let outline = gripOutline ?? CAShapeLayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outline.frame = bounds
        outline.path = CGPath(roundedRect: registeredGripRects[index], cornerWidth: 3, cornerHeight: 3, transform: nil)
        outline.fillColor = NSColor.clear.cgColor
        outline.strokeColor = NSColor.systemOrange.cgColor
        outline.lineWidth = 2
        if outline.superlayer == nil { layer?.addSublayer(outline) }
        gripOutline = outline
        CATransaction.commit()
    }
    public var interactionProjectionAvailable: Bool { !community && !failed && skin != nil }
    /// Registered local geometry, never a second layout or an input window.
    public func interactionTargets(edge: DockEdge) -> [DockReorderTarget] {
        guard !community, !failed else { return [] }
        return orderedIDs.compactMap { id in
            guard let rect = stationRect(id) else { return nil }
            return DockReorderTarget(id:id,along:Double(edge.isHorizontal ? rect.midX : rect.midY))
        }
    }
    public var interactionOverflowIDs: Set<String> {
        guard !community, !failed, skin?.stations.contains(where: { $0.overflowCount != nil }) == true else { return [] }
        return Set(orderedIDs).subtracting(skin?.stations.compactMap(\.subscriptionID) ?? [])
    }
    public func interactionAnchor(_ id: String) -> CGRect? { stationRect(id) }
    /// Registered visible reading geometry for the Help-map owner, in view-local points.
    public func helpReadoutAnchor(_ id: String) -> CGRect? {
        guard !community, !failed, let skin, readings[id] != nil,
              let station = skin.stations.first(where: { $0.subscriptionID == id }),
              station.showsReadout != false, (station.readoutOpacity ?? 1) > 0 else { return nil }
        return station.readout.offsetBy(dx: -layoutOrigin.x, dy: -layoutOrigin.y)
    }
    public func helpNoticeAnchor(_ id: String) -> CGRect? {
        guard !community, !failed, let skin, let notice = notices[id],
              let station = skin.stations.first(where: { $0.subscriptionID == id }) else { return nil }
        let diameter = (notice.shape == .solid ? station.eventSolidDiameter : station.eventHollowDiameter) ?? station.eventRect.width / 2
        let outline = notice.shape == .solid && station.eventOutlineKey != nil ? (station.eventSolidOutlineWidth ?? 0) : 0
        let radius = diameter / 2 + outline
        return CGRect(x: station.eventRect.midX - layoutOrigin.x - radius,
                      y: station.eventRect.midY - layoutOrigin.y - radius, width: 2 * radius, height: 2 * radius)
    }
    private var focusedNoticeID: String? {
        didSet { if focusedNoticeID != oldValue { helpFocusChanged() } }
    }

    public var focusedHelpAnchorID: String? {
        if let index = focusedGripIndex { return "dock.grip.\(index)" }
        if let id = focusedNoticeID, helpNoticeAnchor(id) != nil { return "dock.notice." + id }
        guard let id = keyboardTargetID else { return nil }
        return (helpRingsAnchor(id) == nil ? "dock.nozzle." : "dock.rings.") + id
    }

    private weak var contextualHelpNode: DockInstrumentAXNode?

    private func helpFocusChanged() {
        clearFocusedHelpExplanation()
        onHelpFocusChanged?()
    }

    public func clearFocusedHelpExplanation() {
        contextualHelpNode?.contextualHelp = nil
        contextualHelpNode = nil
    }

    /// Update only the current keyboard control. The underlying reading remains its AX value.
    @discardableResult public func setFocusedHelpExplanation(_ text: String?, for anchorID: String) -> Bool {
        guard !failed, !isHiddenOrHasHiddenAncestor, focusedHelpAnchorID == anchorID,
              nozzleEventDelegate?.hasCapture != true, backgroundDragDelegate?.isBackgroundMoving != true else { return false }
        let key = focusedGripIndex.map { "grip.\($0)" }
            ?? focusedNoticeID.map { "notice." + $0 }
            ?? keyboardTargetID.map { "subscription." + $0 }
        guard let key, let node = nodes[key] else { return false }
        if contextualHelpNode !== node { clearFocusedHelpExplanation() }
        node.contextualHelp = text
        contextualHelpNode = text == nil ? nil : node
        return true
    }

    public func helpRingsAnchor(_ id: String) -> CGRect? {
        guard !failed, !community, let skin,
              let station = skin.stations.first(where: { $0.subscriptionID == id }),
              station.replacementResource == nil, readings[id] != nil else { return nil }
        let radius = max(station.outer.radius + station.outer.width / 2, station.inner.radius + station.inner.width / 2)
        return CGRect(x: station.centre.x - layoutOrigin.x - radius,
                      y: station.centre.y - layoutOrigin.y - radius,
                      width: 2 * radius, height: 2 * radius)
    }

    public func helpAnchorID(atLocal point: CGPoint) -> String? {
        guard isPainted(atLocal: point), !community, let skin,
              nozzleEventDelegate?.hasCapture != true, backgroundDragDelegate?.isBackgroundMoving != true else { return nil }
        // The renderer paints the dot above the readout, then the quota rings above the nozzle.
        for station in skin.stations.reversed() {
            guard let id = station.subscriptionID, let reading = readings[id] else { continue }
            if let rect = helpNoticeAnchor(id), hypot(point.x - rect.midX, point.y - rect.midY) <= rect.width / 2 { return "dock.notice." + id }
            if helpReadoutAnchor(id)?.contains(point) == true { return "dock.number." + id }
            let distance = hypot(point.x + layoutOrigin.x - station.centre.x,
                                 point.y + layoutOrigin.y - station.centre.y)
            if station.replacementResource == nil,
               abs(distance - station.outer.radius) <= station.outer.width / 2 ||
               (reading.inner != nil && abs(distance - station.inner.radius) <= station.inner.width / 2) {
                return "dock.rings." + id
            }
            if distance <= station.diameter / 2 { return "dock.nozzle." + id }
        }
        return registeredGripRects.firstIndex(where: { $0.contains(point) }).map { "dock.grip.\($0)" }
    }
    private var edgeTracking:NSTrackingArea?
    /// The pooled-effect adapter stops/releases its old leases before a profile/identity transaction.
    public var onVisualReset:(()->Void)?
    public private(set) var workingLayerParents=[String:CALayer]()
    private var image:CGImage?,backgroundImage:CGImage?,skin:DockInstrumentSkin?,readings=[String:DockInstrumentReading](),notices=[String:DockNotice]()
    private var officialRenderer: DockInstrumentRenderer?
    private var restingInstrumentImage: CGImage?
    private var hoverViewport: CGRect?
    private var imageUsesHoverViewport = false
    private var layoutOrigin: CGPoint { (hoverViewport ?? skin?.bounds)?.origin ?? .zero }
    private var restingPaintFrame: CGRect {
        guard let skin else { return bounds }
        return skin.bounds.offsetBy(dx: -layoutOrigin.x, dy: -layoutOrigin.y)
    }
    @_spi(DockResourceChecks) public private(set) var nozzlePosesForChecks: [String: DockNozzlePose] = [:]
    private var refreshSweepTask: Task<Void, Never>?
    private var refreshSweepOriginal: (image: CGImage, usesHoverViewport: Bool)?
    private var refreshSweepGeneration: UInt64 = 0
    @_spi(DockResourceChecks) public private(set) var refreshSweepCountForChecks = 0
    @_spi(DockResourceChecks) public var refreshSweepAnimatingForChecks: Bool { refreshSweepTask != nil }
    /// The effect driver only receives a currently successful official skin.
    var workingEffectSkin: DockInstrumentSkin? { failed || community ? nil : skin }
    private var orderedIDs=[String](),nodes=[String:DockInstrumentAXNode](),alphaData:CFData?
    private var noticePulseLayers = [CALayer]()
    @_spi(DockResourceChecks) public var noticePulseCountForChecks: Int { noticePulseLayers.count }
    /// Registered hull extent excludes raster padding, separate controls and shadows.
    public var registeredHullBounds: CGRect? {
        guard let path = registeredHullPath else { return nil }
        let rect = path.boundingBoxOfPath
        return rect.isNull || rect.isEmpty ? nil : rect
    }
    /// The existing instrument renderer supplies every pulse pixel; this only animates a transient crop.
    public var visibleNoticesForPulse: [(String, DockNotice)] {
        guard !failed, !community, let skin else { return [] }
        return skin.stations.compactMap { station in
            guard let key = station.subscriptionID ?? station.overflowNoticeKey, let notice = notices[key] else { return nil }
            return (key, notice)
        }
    }
    @discardableResult public func pulseNotice(_ key: String) -> Bool {
        guard !failed, !community, let skin, let image = restingInstrumentImage, let notice = notices[key], let root = layer,
              let station = skin.stations.first(where: { $0.subscriptionID == key || $0.overflowNoticeKey == key }) else { return false }
        let local = station.eventRect.offsetBy(dx: -skin.bounds.minX, dy: -skin.bounds.minY)
        let pixels = CGRect(x: local.minX * CGFloat(scale), y: local.minY * CGFloat(scale),
                            width: local.width * CGFloat(scale), height: local.height * CGFloat(scale)).integral
        guard pixels.width > 0, pixels.height > 0, pixels.width <= 128, pixels.height <= 128,
              let crop = image.cropping(to: pixels) else { return false }
        let rim = station.showsReadout == false || station.overflowCount != nil
        var contents = crop
        if !rim {
            guard let c = CGContext(data: nil, width: crop.width, height: crop.height, bitsPerComponent: 8,
                                    bytesPerRow: crop.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
            guard let memory = c.data else { return false }
            let bytes = memory.assumingMemoryBound(to: UInt8.self)
            for i in 0..<(crop.width * crop.height) {
                let alpha = Int(bytes[i * 4 + 3])
                for channel in 0..<3 { bytes[i * 4 + channel] = UInt8(min(alpha, Int((Double(bytes[i * 4 + channel]) * 2.2).rounded()))) }
            }
            guard let bright = c.makeImage() else { return false }; contents = bright
        }
        let overlay = CALayer(); overlay.contents = contents; overlay.contentsScale = CGFloat(scale)
        overlay.frame = CGRect(x: restingPaintFrame.minX + pixels.minX / CGFloat(scale),
                               y: restingPaintFrame.minY + pixels.minY / CGFloat(scale),
                               width: pixels.width / CGFloat(scale), height: pixels.height / CGFloat(scale))
        let mask = CAShapeLayer(); mask.frame = overlay.bounds
        let diameter = (notice.shape == .solid ? station.eventSolidDiameter : station.eventHollowDiameter) ?? station.eventRect.width / 2
        let dot = CGRect(x: overlay.bounds.midX-diameter/2, y: overlay.bounds.midY-diameter/2, width: diameter, height: diameter)
        let path = CGMutablePath(); path.addEllipse(in: dot)
        if notice.shape == .hollow {
            let width = station.eventStrokeWidth ?? 1.2
            if dot.width > 2 * width { path.addEllipse(in: dot.insetBy(dx: width, dy: width)) }
            mask.fillRule = .evenOdd
        }
        mask.path = path; overlay.mask = mask; root.addSublayer(overlay); noticePulseLayers.append(overlay)
        let pulse = CAKeyframeAnimation(keyPath: rim ? "transform.scale" : "opacity")
        pulse.values = rim ? [1, 2.1, 1] : [0, 1, 0]; pulse.keyTimes = [0, 0.35, 1]
        pulse.duration = rim ? 0.9 : 0.45; pulse.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeOut)]
        CATransaction.begin(); CATransaction.setCompletionBlock { [weak self, weak overlay] in
            overlay?.removeFromSuperlayer()
            self?.noticePulseLayers.removeAll { $0 === overlay }
        }
        overlay.add(pulse, forKey: "dock-notice-first-appearance"); CATransaction.commit()
        return true
    }
    public var registeredHullPath: CGPath? {
        guard !failed else { return nil }
        guard let skin, skin.bodyPolygon.count >= 3 else { return nil }
        let path = CGMutablePath()
        path.addLines(between: skin.bodyPolygon.map { CGPoint(x: $0.x - layoutOrigin.x, y: $0.y - layoutOrigin.y) })
        path.closeSubpath(); return path
    }
    /// Movement may outline the neutral rectangle; supplier hull/sliver registration stays independent.
    public var registeredMoveOutlinePath: CGPath? {
        guard !failed else { return nil }
        if community { return bounds.isEmpty ? nil : CGPath(rect: bounds, transform: nil) }
        return registeredHullPath
    }
    public func registeredDragRegions(excluding controls: [CGRect]) -> DockBackgroundDragRegions? {
        if community {
            guard !failed, let body = registeredMoveOutlinePath else { return nil }
            let rows = orderedIDs.compactMap { stationRect($0) }
            return DockBackgroundDragRegions(body: body, excludedControls: controls + rows,
                bodyHitTest: { [weak self] point in
                    guard let self, self.community else { return false }
                    return self.isPainted(atLocal: point)
                })
        }
        guard let skin else { return nil }
        let path: CGPath
        let bodyHitTest: ((CGPoint) -> Bool)?
        if let hull = registeredHullPath {
            path = hull; bodyHitTest = nil
        } else {
            // Precomposited skins deliberately omit a vector body. Register the
            // rendered pixels, not transparent padding or an invented silhouette.
            guard skin.bodyPolygon.isEmpty, !community, !failed, image != nil, alphaData != nil else { return nil }
            path = CGPath(rect: bounds, transform: nil)
            bodyHitTest = { [weak self] point in self?.isPainted(atLocal: point) ?? false }
        }
        var excluded = controls
        for station in skin.stations {
            excluded.append(CGRect(x: station.centre.x - station.diameter / 2 - layoutOrigin.x,
                y: station.centre.y - station.diameter / 2 - layoutOrigin.y, width: station.diameter, height: station.diameter))
            excluded.append(station.readout.offsetBy(dx: -layoutOrigin.x, dy: -layoutOrigin.y))
            excluded.append(station.eventRect.offsetBy(dx: -layoutOrigin.x, dy: -layoutOrigin.y))
            if let alias = station.aliasRect { excluded.append(alias.offsetBy(dx: -layoutOrigin.x, dy: -layoutOrigin.y)) }
        }
        return DockBackgroundDragRegions(body: path, grips: registeredGripRects.map { CGPath(rect: $0, transform: nil) },
                                         excludedControls: excluded, bodyHitTest: bodyHitTest)
    }
    public var onNeedsFreshPresentation:(()->Void)?
    private var windowObservers=[NSObjectProtocol]()
    private var workspaceObserver:NSObjectProtocol?
    private var scale=1,locale="en",community=true,failed=false
    public override var isFlipped:Bool{true}
    public override var acceptsFirstResponder:Bool{keyboardNavigationEnabled}
    public override func becomeFirstResponder() -> Bool {
        guard keyboardNavigationEnabled, super.becomeFirstResponder() else { return false }
        if keyboardTargetID == nil { keyboardTargetID = orderedIDs.first }
        nozzleEventDelegate?.hoverNozzle(keyboardTargetID)
        return true
    }
    public override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        keyboardTargetID = nil; focusedGripIndex = nil; focusedNoticeID = nil; nozzleEventDelegate?.hoverNozzle(nil)
        return true
    }
    public override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.isGeometryFlipped=true;setAccessibilityElement(false);setAccessibilityRole(.group)}
    deinit {for token in windowObservers{NotificationCenter.default.removeObserver(token)};if let workspaceObserver{NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)}}
    required init?(coder:NSCoder){fatalError("init(coder:) is unsupported")}
    public func applyCommunity(_ rows:[DockInstrumentReading],locale:String="en") throws {
        guard Set(rows.map(\.subscriptionID)).count==rows.count else{throw DockLogicError.invalidCatalogue}
        clearFocusedHelpExplanation();resetVisuals();registerGripRects([]);restingInstrumentImage=nil;hoverViewport=nil;imageUsesHoverViewport=false;officialRenderer=nil;self.locale=locale;community=true;failed=false;skin=nil;image=nil;backgroundImage=nil;alphaData=nil;notices=[:];appearanceNotices=[:]
        orderedIDs=rows.map(\.subscriptionID);readings=Dictionary(uniqueKeysWithValues:rows.map{($0.subscriptionID,$0)})
        communityRowHeight = requestedNozzleDiameter ?? 44
        guard communityRowHeight.isFinite, (8...256).contains(communityRowHeight) else { throw DockArtworkError.invalidManifest }
        appliedGeometryScale = 1
        frame.size=CGSize(width:240 * communityRowHeight / 44,height:max(communityRowHeight,CGFloat(rows.count)*communityRowHeight));refreshNodes();needsDisplay=true
    }
    public func applyOfficial(skin:DockInstrumentSkin,rows:[DockInstrumentReading],notices:[String:DockNotice]=[:],renderer:DockInstrumentRenderer,scale:Int,locale:String,hoverViewport:CGRect?=nil) throws {
        guard Set(rows.map(\.subscriptionID)).count==rows.count else{throw DockLogicError.invalidCatalogue}
        let renderScale = presentationBackingScale ?? window.map { Int($0.backingScaleFactor) } ?? scale
        guard (1...2).contains(scale), (1...2).contains(renderScale) else{throw DockArtworkError.invalidManifest}
        resetVisuals()
        do {
            let factor: CGFloat
            if let target = requestedNozzleDiameter, let station = skin.stations.first {
                let source = station.logicalPoints.map { CGFloat($0) } ?? station.diameter
                guard target.isFinite, (8...256).contains(target), source.isFinite, source > 0 else { throw DockArtworkError.invalidManifest }
                factor = target / source
            } else { factor = 1 }
            let skin = try skin.scaled(by: factor)
            let viewport = hoverViewport?.applying(CGAffineTransform(scaleX: factor, y: factor))
            if let viewport {
                guard viewport.contains(skin.bounds), viewport.width <= 4096, viewport.height <= 4096 else {
                    throw DockArtworkError.invalidManifest
                }
            }
            self.hoverViewport = viewport
            imageUsesHoverViewport = false
            appliedGeometryScale = factor
            let values=Dictionary(uniqueKeysWithValues:rows.map{($0.subscriptionID,$0)}),result=try renderer.render(skin:skin,readings:values,notices:notices,scale:renderScale)
            community=false;failed=false;self.skin=skin;self.scale=renderScale;self.locale=locale;self.notices=notices
            self.officialRenderer=renderer
            orderedIDs=rows.map(\.subscriptionID);readings=values;image=result.image;restingInstrumentImage=result.image;backgroundImage=result.backgroundImage;alphaData=result.image.dataProvider?.data
            frame.size = viewport?.size ?? skin.bounds.size
            CATransaction.begin();CATransaction.setDisableActions(true);layer?.contentsScale=CGFloat(renderScale)
            let visible=Set(skin.stations.compactMap(\.subscriptionID))
            for id in Array(workingLayerParents.keys) where !visible.contains(id){workingLayerParents[id]?.removeFromSuperlayer();workingLayerParents.removeValue(forKey:id)}
            for station in skin.stations {guard let id=station.subscriptionID,values[id] != nil else{continue}
                let parent=workingLayerParents[id] ?? CALayer();parent.isGeometryFlipped=true;parent.contentsScale=CGFloat(renderScale)
                parent.frame=CGRect(x:station.centre.x-station.diameter/2-layoutOrigin.x,y:station.centre.y-station.diameter/2-layoutOrigin.y,width:station.diameter,height:station.diameter)
                if parent.superlayer == nil{layer?.addSublayer(parent)};workingLayerParents[id]=parent
            }
            CATransaction.commit();refreshNodes();needsDisplay=true
        } catch {
            retireOfficialPresentation()
            throw error
        }
    }
    /// A failed refresh keeps only the last supplied material. Old data and all instrument actions retire.
    public func retireOfficialPresentation() {
        setAccessibilityValue(nil)
        clearFocusedHelpExplanation(); resetVisuals(); focusedGripIndex = nil; registeredGripRects = []; community = false; failed = true
        restingInstrumentImage = nil
        imageUsesHoverViewport = false
        image = backgroundImage; alphaData = backgroundImage?.dataProvider?.data
        readings = [:]; orderedIDs = []; notices = [:]; nodes = [:]; setAccessibilityChildren([])
        workingLayerParents.values.forEach { $0.removeFromSuperlayer() }; workingLayerParents = [:]
        needsDisplay = true
    }
    public func dispose(){setAccessibilityValue(nil);clearFocusedHelpExplanation();onHelpFocusChanged=nil;onHelpPointerMoved=nil;registeredGripRects=[];appearanceNotices=[:];nozzleEventDelegate?.cancelNozzle();nozzleEventDelegate=nil;keyboardTargetID=nil;backgroundDragDelegate?.cancelBackgroundMove();backgroundDragDelegate=nil;permitsAction=nil;if let edgeTracking{removeTrackingArea(edgeTracking);self.edgeTracking=nil};clearObservers();resetVisuals();failed=true;workingLayerParents.values.forEach{$0.removeFromSuperlayer()};workingLayerParents=[:];nodes=[:];readings=[:];orderedIDs=[];image=nil;restingInstrumentImage=nil;backgroundImage=nil;alphaData=nil;setAccessibilityChildren([]);onAction=nil;onEmptyAction=nil;permitsEmptyAction=nil;onVisualReset=nil}
    private func resetVisuals(){hoveredGripIndex=nil;updateGripEmphasis();cancelRefreshSweep();setNozzlePoses([:]);noticePulseLayers.forEach { $0.removeAllAnimations(); $0.removeFromSuperlayer() }; noticePulseLayers=[];onVisualReset?();for parent in workingLayerParents.values{parent.sublayers?.forEach{$0.removeFromSuperlayer()}}}

    /// Draws only the changed pose over the existing static material. The model, registered
    /// pointer targets, readout geometry and refresh cadence remain in their original basis.
    public func setNozzlePoses(_ poses: [String: DockNozzlePose]) {
        guard poses != nozzlePosesForChecks, !failed, !community, let skin, let renderer = officialRenderer,
              let restingInstrumentImage else { return }
        let painted: CGImage
        if poses.isEmpty {
            painted = restingInstrumentImage
        } else {
            guard let result = try? renderer.render(skin: skin, readings: readings, notices: notices, scale: scale,
                poses: poses, cachedBackground: backgroundImage, viewport: hoverViewport) else { return }
            painted = result.image
        }
        nozzlePosesForChecks = poses
        let usesViewport = !poses.isEmpty && hoverViewport != nil
        if refreshSweepOriginal == nil {
            image = painted
            imageUsesHoverViewport = usesViewport
        } else { refreshSweepOriginal = (painted, usesViewport) }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (id, layer) in workingLayerParents {
            if let pose = poses[id] {
                layer.setAffineTransform(CGAffineTransform(translationX: pose.offset.x, y: pose.offset.y)
                    .scaledBy(x: pose.scale, y: pose.scale))
            } else { layer.setAffineTransform(.identity) }
        }
        CATransaction.commit()
        needsDisplay = true
    }

    /// Renders a bounded one-off sweep from the existing admitted reading, without changing its age.
    @discardableResult public func playRefreshSweep(_ id: String, reduceMotion: Bool) -> Bool {
        cancelRefreshSweep()
        guard !failed, !community, let skin, let renderer = officialRenderer, let original = image,
              let reading = readings[id], reading.remainingPercent != nil,
              original.width <= 4096, original.height <= 4096,
              original.width * original.height <= 4_194_304 else { return false }
        refreshSweepCountForChecks += 1
        if reduceMotion { return true }
        refreshSweepOriginal = (original, imageUsesHoverViewport)
        refreshSweepGeneration &+= 1
        let token = refreshSweepGeneration, base = readings, notices = self.notices, scale = self.scale
        let started = ProcessInfo.processInfo.systemUptime
        refreshSweepTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.refreshSweepGeneration == token else { return }
                let elapsed = max(0, ProcessInfo.processInfo.systemUptime - started)
                guard let progress = DockRefreshSweep.fraction(elapsed: elapsed, target: 1, reduceMotion: false) else { break }
                var frame = base; frame[id] = reading.refreshSweepFrame(progress: progress)
                let viewport = self.nozzlePosesForChecks.isEmpty ? nil : self.hoverViewport
                do {
                    self.image = try renderer.render(skin: skin, readings: frame, notices: notices, scale: scale,
                        poses: self.nozzlePosesForChecks, cachedBackground: self.backgroundImage, viewport: viewport).image
                    self.imageUsesHoverViewport = viewport != nil
                } catch { break }
                self.needsDisplay = true
                if elapsed >= DockRefreshSweep.duration { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard let self, self.refreshSweepGeneration == token else { return }
            self.cancelRefreshSweep()
        }
        return true
    }
    private func cancelRefreshSweep() {
        refreshSweepGeneration &+= 1; refreshSweepTask?.cancel(); refreshSweepTask = nil
        if let original = refreshSweepOriginal {
            image = original.image; imageUsesHoverViewport = original.usesHoverViewport
            refreshSweepOriginal = nil; needsDisplay = true
        }
    }
    public override func viewWillMove(toWindow newWindow:NSWindow?){if newWindow==nil{resetVisuals()};super.viewWillMove(toWindow:newWindow)}
    public override func viewDidHide(){clearFocusedHelpExplanation();focusedGripIndex=nil;focusedNoticeID=nil;resetVisuals();super.viewDidHide()}
    private func clearObservers(){
        windowObservers.forEach{NotificationCenter.default.removeObserver($0)};windowObservers=[]
        if let workspaceObserver{NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver);self.workspaceObserver=nil}
    }
    public override func viewDidMoveToWindow(){
        super.viewDidMoveToWindow();clearObservers()
        if let window {
            windowObservers.append(NotificationCenter.default.addObserver(forName:NSWindow.didChangeOcclusionStateNotification,object:window,queue:.main){[weak self] _ in
                MainActor.assumeIsolated {guard let self else{return};if self.window?.occlusionState.contains(.visible)==true{self.onNeedsFreshPresentation?()}else{self.resetVisuals()}}
            })
            for name in [NSWindow.didChangeScreenNotification,NSWindow.didChangeBackingPropertiesNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(forName:name,object:window,queue:.main){[weak self] _ in
                    MainActor.assumeIsolated {self?.invalidatePresentation()}
                })
            }
            workspaceObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main){[weak self] _ in
                MainActor.assumeIsolated {self?.invalidatePresentation()}
            }
        }
        if window != nil{onNeedsFreshPresentation?()}
    }
    private func invalidatePresentation(){resetVisuals();onNeedsFreshPresentation?()}
    public func communityRowText(_ id:String) -> String? {
        guard community,let r=readings[id] else { return nil }
        let heading=[r.alias ?? r.name,r.readout].joined(separator:"  ")
        guard r.remainingPercent == nil else { return heading }
        let reason=r.unavailableReason?.trimmingCharacters(in:.whitespacesAndNewlines)
        return heading+"\n"+String((reason?.isEmpty == false ? reason! : locale.hasPrefix("zh") ? "不可用" : "Unavailable").prefix(80))
    }
    public func communityRowIsDimmed(_ id:String) -> Bool {
        guard community, let reading=readings[id] else { return false }
        return reading.remainingPercent == nil
    }
    public override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();invalidatePresentation()}
    public override func draw(_ dirtyRect:NSRect){
        if let image {
            NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
            NSGraphicsContext.current?.imageInterpolation = .high
            NSGraphicsContext.current?.cgContext.setShouldAntialias(true)
            let paintFrame = imageUsesHoverViewport ? bounds : restingPaintFrame
            if paintFrame != bounds { NSColor.clear.setFill(); dirtyRect.fill(using: .copy) }
            NSImage(cgImage: image, size: paintFrame.size).draw(in: paintFrame, from: .zero,
                operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
            return
        }
        // Official rasters include transparent/grain pixels: replace the backing contents,
        // rather than accumulating alpha over the previous appearance on each redraw.
        if !community { NSColor.clear.setFill(); bounds.fill(using: .copy); return }
        NSColor.windowBackgroundColor.setFill();bounds.fill()
        if failed {let label=locale.hasPrefix("zh") ? "仪表暂不可用":"Instruments unavailable";(label as NSString).draw(at:CGPoint(x:12,y:12),withAttributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.secondaryLabelColor]);return}
        for (index,id) in orderedIDs.enumerated(){guard let r=readings[id] else{continue}
            let value=communityRowText(id) ?? [r.alias ?? r.name,r.readout].joined(separator:"  ")
            let context = NSGraphicsContext.current?.cgContext
            context?.saveGState()
            if let control = stationRect(id) { context?.clip(to: control) }
            let scale=communityRowHeight/44,paragraph=NSMutableParagraphStyle();paragraph.lineBreakMode = .byTruncatingTail
            (value as NSString).draw(in:CGRect(x:12*scale,y:CGFloat(index)*communityRowHeight+8*scale,width:bounds.width-24*scale,height:communityRowHeight-12*scale),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:12*scale,weight:.regular),.foregroundColor:communityRowIsDimmed(id) ? NSColor.secondaryLabelColor : NSColor.labelColor,.paragraphStyle:paragraph])
            context?.restoreGState()
        }
    }
    private func stationRect(_ id:String)->CGRect? {
        if community {
            guard let i=orderedIDs.firstIndex(of:id) else{return nil}
            let inset = 8 * communityRowHeight / 44
            return CGRect(x:0,y:CGFloat(i)*communityRowHeight,width:bounds.width,height:communityRowHeight).insetBy(dx:inset,dy:inset)
        }
        guard let s=skin?.stations.first(where:{$0.subscriptionID==id}) else{return nil}
        let origin = layoutOrigin
        return CGRect(x:s.centre.x-s.diameter/2-origin.x,y:s.centre.y-s.diameter/2-origin.y,width:s.diameter,height:s.diameter)
    }
    private var emptyStationRect: CGRect? {
        guard !community, !failed, let skin,
              let station = skin.stations.first(where: { $0.placeholderStyle != nil && $0.placeholderLabel != nil && $0.subscriptionID == nil && $0.overflowCount == nil }) else { return nil }
        return CGRect(x: station.centre.x-station.diameter/2-layoutOrigin.x,
                      y: station.centre.y-station.diameter/2-layoutOrigin.y, width: station.diameter, height: station.diameter)
    }
    @_spi(DockResourceChecks) public var emptyStationRectForChecks: CGRect? { emptyStationRect }
    private func refreshNodes(){
        var children=[DockInstrumentAXNode](),used=Set<String>()
        func append(_ key:String,_ label:String,_ value:String?,_ help:String,_ rect:CGRect,_ action:DockInstrumentAction) {
            let node=nodes[key] ?? DockInstrumentAXNode(),oldValue=node.accessibilityValue() as? String
            node.setAccessibilityRole(.button);node.setAccessibilityParent(self);node.setAccessibilityEnabled(onAction != nil)
            node.setAccessibilityIdentifier("dock."+key);node.setAccessibilityLabel(label);node.setAccessibilityValue(value);node.normalHelp=help
            node.setAccessibilityFrameInParentSpace(rect);node.press={[weak self,weak node] in
                guard let self,let node,self.nodes[key] === node,self.permitsAction?(action,.accessibility) ?? true else{return false}
                // A gate may synchronously refresh the snapshot; recheck this stable AX node afterward.
                guard self.nodes[key] === node,let onAction=self.onAction else{return false};onAction(action);return true
            }
            node.focus = { [weak self, weak node] focused in
                guard let self, let node, self.nodes[key] === node else { return }
                if case .notice(let id) = action {
                    if focused {
                        self.focusedGripIndex = nil
                        self.keyboardTargetID = nil
                        self.nozzleEventDelegate?.hoverNozzle(nil)
                        self.focusedNoticeID = id
                    } else if self.focusedNoticeID == id { self.focusedNoticeID = nil }
                    return
                }
                guard case .subscription(let id) = action else { return }
                if focused { self.focusedNoticeID = nil; self.focusedGripIndex = nil; self.keyboardTargetID = id; self.nozzleEventDelegate?.hoverNozzle(id) }
                else if self.keyboardTargetID == id { self.keyboardTargetID = nil; self.nozzleEventDelegate?.hoverNozzle(nil) }
            }
            nodes[key]=node;children.append(node);used.insert(key)
            if oldValue != value {NSAccessibility.post(element:node,notification:.valueChanged)}
        }
        for id in orderedIDs {guard let reading=readings[id],let rect=stationRect(id) else{continue}
            let stale = reading.dataState == .stale ? (reading.unavailableReason ?? (locale.hasPrefix("zh") ? "部分读数已过期" : "Some readings are stale")) : nil
            append("subscription."+id,reading.alias ?? reading.name,reading.readout,[reading.selectedWindowLabel,reading.readout,stale].compactMap{$0}.joined(separator:" · "),rect,.subscription(id))
            if !community,let notice=notices[id],let station=skin?.stations.first(where:{$0.subscriptionID==id}) {
                let origin = layoutOrigin
                let zh=locale.hasPrefix("zh"),label:String
                switch notice.key.kind {
                case .forecast:label=zh ? "可能提前耗尽":"May run out before reset"
                case .resetAnnounced:label=zh ? "已公告额外重置":"Extra reset announced"
                case .resetConfirmed:label=zh ? "额外重置已确认，等待读数":"Extra reset confirmed; awaiting a reading"
                case .cardsExpiring:label=zh ? "重置卡即将过期":"Reset card expiring"
                case .credits:label=zh ? "正在使用点数":"Using credits"
                }
                append("notice."+id,label,nil,label,station.eventRect.offsetBy(dx:-origin.x,dy:-origin.y),.notice(id))
            }
        }
        if let rect = emptyStationRect {
            let key = "empty", node = nodes[key] ?? DockInstrumentAXNode(), zh = locale.hasPrefix("zh")
            node.setAccessibilityRole(.button); node.setAccessibilityParent(self); node.setAccessibilityEnabled(onEmptyAction != nil)
            node.setAccessibilityIdentifier("dock.empty"); node.setAccessibilityLabel(zh ? "未检测到订阅" : "No subscriptions found")
            node.setAccessibilityHelp(zh ? "打开设置以连接订阅" : "Open Settings to connect a subscription")
            node.setAccessibilityFrameInParentSpace(rect)
            node.press = { [weak self, weak node] in
                guard let self, let node, self.nodes[key] === node, self.emptyStationRect != nil,
                      self.permitsEmptyAction?(.accessibility) ?? true, let action = self.onEmptyAction else { return false }
                return action()
            }
            nodes[key] = node; children.append(node); used.insert(key)
        }
        if !community,let more=skin?.stations.first(where:{$0.overflowCount != nil}) {
            let origin = layoutOrigin
            let label=locale.hasPrefix("zh") ? "更多订阅":"More subscriptions"
            append("overflow",label,String(more.overflowCount ?? 0),label,CGRect(x:more.centre.x-more.diameter/2-origin.x,y:more.centre.y-more.diameter/2-origin.y,width:more.diameter,height:more.diameter),.overflow)
        }
        for (index, rect) in registeredGripRects.enumerated() {
            let key = "grip.\(index)"
            let node = nodes[key] ?? DockInstrumentAXNode()
            node.setAccessibilityRole(.group)
            node.setAccessibilityParent(self)
            node.setAccessibilityIdentifier("dock." + key)
            node.setAccessibilityLabel(locale.hasPrefix("zh") ? "移动额度挂件" : "Move Quota Widget")
            node.setAccessibilityFrameInParentSpace(rect)
            node.focus = { [weak self, weak node] focused in
                guard let self, let node, self.nodes[key] === node else { return }
                if focused {
                    self.focusedNoticeID = nil
                    self.keyboardTargetID = nil
                    self.nozzleEventDelegate?.hoverNozzle(nil)
                    self.focusedGripIndex = index
                } else if self.focusedGripIndex == index { self.focusedGripIndex = nil }
            }
            nodes[key] = node
            children.append(node)
            used.insert(key)
        }
        nodes=nodes.filter{used.contains($0.key)}
        if let id = focusedNoticeID, !used.contains("notice." + id) { focusedNoticeID = nil }
        if let id=keyboardTargetID, !used.contains("subscription." + id) { keyboardTargetID=nil;nozzleEventDelegate?.hoverNozzle(nil) }
        setAccessibilityChildren(children)
    }
    public func isPainted(atLocal local:NSPoint)->Bool {
        guard !isHiddenOrHasHiddenAncestor,bounds.contains(local),!failed else{return false}
        if community{return true}
        // This tests only this view's painted raster. The containing window's native route is a separate gate.
        let painted = restingPaintFrame
        guard painted.contains(local), let image = restingInstrumentImage, let bytes = alphaData,
              CFDataGetLength(bytes) >= image.bytesPerRow * image.height,
              image.bitsPerPixel == 32, image.bitsPerComponent == 8 else { return false }
        let x = min(image.width - 1, Int((local.x - painted.minX) * CGFloat(scale)))
        let y = min(image.height - 1, Int((local.y - painted.minY) * CGFloat(scale)))
        let alphaIndex=(image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first) ? 0:3
        guard CFDataGetBytePtr(bytes)![y*image.bytesPerRow+x*4+alphaIndex]>0 else{return false};return true
    }
    public override func hitTest(_ point:NSPoint)->NSView? {isPainted(atLocal:convert(point,from:superview)) ? self:nil}
    public override func updateTrackingAreas(){
        if let edgeTracking{removeTrackingArea(edgeTracking)}
        let next=NSTrackingArea(rect:.zero,options:[.inVisibleRect,.cursorUpdate,.mouseMoved,.mouseEnteredAndExited,.activeAlways],owner:self,userInfo:nil)
        edgeTracking=next;addTrackingArea(next);super.updateTrackingAreas()
    }
    public override func cursorUpdate(with event:NSEvent){
        if backgroundDragDelegate?.isBackgroundMoving == true{NSCursor.closedHand.set()}
        else if backgroundDragDelegate?.backgroundCanDrag(local:convert(event.locationInWindow,from:nil)) == true{NSCursor.openHand.set()}
        else{NSCursor.arrow.set()}
    }
    public override func mouseMoved(with event:NSEvent){
        let p=convert(event.locationInWindow,from:nil)
        let grip = isPainted(atLocal: p) ? registeredGripRects.firstIndex { $0.contains(p) } : nil
        if hoveredGripIndex != grip { hoveredGripIndex = grip; updateGripEmphasis() }
        if case .subscription(let id)?=pointerAction(atLocal:p),isPainted(atLocal:p){nozzleEventDelegate?.hoverNozzle(id)}else{nozzleEventDelegate?.hoverNozzle(nil)}
        onHelpPointerMoved?()
    }
    public override func mouseEntered(with event:NSEvent){mouseMoved(with:event)}
    public override func mouseExited(with event:NSEvent){hoveredGripIndex=nil;updateGripEmphasis();nozzleEventDelegate?.hoverNozzle(nil);onHelpPointerMoved?()}
    public override func mouseDragged(with event:NSEvent){
        if nozzleEventDelegate?.hasCapture == true{nozzleEventDelegate?.moveNozzle(local:convert(event.locationInWindow,from:nil));return}
        guard let window,let handler=backgroundDragDelegate else{super.mouseDragged(with:event);return}
        handler.updateBackgroundMove(global:window.convertPoint(toScreen:event.locationInWindow))
        if handler.isBackgroundMoving{NSCursor.closedHand.set()}
    }
    public override func mouseUp(with event:NSEvent){
        if let handler=nozzleEventDelegate,handler.hasCapture,let window{
            let p=convert(event.locationInWindow,from:nil),id:String?
            if case .subscription(let current)?=pointerAction(atLocal:p),isPainted(atLocal:p){id=current}else{id=nil}
            handler.endNozzle(global:window.convertPoint(toScreen:event.locationInWindow),currentID:id);return
        }
        if let window{backgroundDragDelegate?.endBackgroundMove(global:window.convertPoint(toScreen:event.locationInWindow))}
        NSCursor.arrow.set()
    }
    public override func cancelOperation(_ sender:Any?){nozzleEventDelegate?.cancelNozzle();backgroundDragDelegate?.cancelBackgroundMove();NSCursor.arrow.set()}
    public override func keyDown(with event:NSEvent){
        let modifiers=event.modifierFlags.intersection([.option,.control,.command])
        if modifiers.isEmpty, event.keyCode == 48, keyboardNavigationEnabled, !registeredGripRects.isEmpty {
            let backward = event.modifierFlags.contains(.shift)
            let next = focusedGripIndex.map { $0 + (backward ? -1 : 1) } ?? (backward ? registeredGripRects.count - 1 : 0)
            if registeredGripRects.indices.contains(next) {
                focusedNoticeID = nil
                keyboardTargetID = nil
                nozzleEventDelegate?.hoverNozzle(nil)
                focusedGripIndex = next
                return
            }
            focusedGripIndex = nil
        }
        if modifiers == .option,let id=keyboardTargetID,nozzleEventDelegate?.optionArrow(id:id,keyCode:event.keyCode)==true{return}
        if modifiers.isEmpty, let id=keyboardTargetID, let index=orderedIDs.firstIndex(of:id), [123,124,125,126].contains(event.keyCode) {
            let delta = event.keyCode == 123 || event.keyCode == 126 ? -1 : 1
            keyboardTargetID = orderedIDs[max(0,min(orderedIDs.count-1,index+delta))]
            nozzleEventDelegate?.hoverNozzle(keyboardTargetID)
            return
        }
        if modifiers.isEmpty,let id=keyboardTargetID,(event.keyCode == 36 || event.charactersIgnoringModifiers == " ") {
            let action = DockInstrumentAction.subscription(id)
            if permitsAction?(action, .accessibility) ?? true { onAction?(action) }
            return
        }
        super.keyDown(with:event)
    }
    private func pointerAction(atLocal p:NSPoint)->DockInstrumentAction?{
        if let skin,!community {
            let global=CGPoint(x:p.x+layoutOrigin.x,y:p.y+layoutOrigin.y)
            for s in skin.stations.reversed(){
                if let id=s.subscriptionID,notices[id] != nil,s.eventRect.contains(global){return .notice(id)}
                if let id=s.subscriptionID,let r=stationRect(id),r.contains(p) || (s.showsReadout != false && s.readout.contains(global)) || s.aliasRect?.contains(global)==true{return .subscription(id)}
                if s.overflowCount != nil,CGRect(x:s.centre.x-s.diameter/2,y:s.centre.y-s.diameter/2,width:s.diameter,height:s.diameter).contains(global){return .overflow}
            }
        } else if let id=orderedIDs.first(where:{stationRect($0)?.contains(p)==true}){return .subscription(id)}
        return nil
    }
    @discardableResult private func dispatchPointer(currentPoint:()->NSPoint?,nozzleGlobal:CGPoint?=nil)->Bool{
        guard let initial=currentPoint(),isPainted(atLocal:initial) else{return false}
        if emptyStationRect?.contains(initial) == true {
            guard permitsEmptyAction?(.pointer) ?? true, let current = currentPoint(), isPainted(atLocal: current),
                  emptyStationRect?.contains(current) == true, let action = onEmptyAction else { return false }
            return action()
        }
        guard let action=pointerAction(atLocal:initial),permitsAction?(action,.pointer) ?? true else{return false}
        // A gate can replace/reorder stations without removing their readings. Re-hit-test the
        // original physical pointer against the current presentation, rather than validating only ID existence.
        guard let current=currentPoint(),isPainted(atLocal:current),pointerAction(atLocal:current)==action else{return false}
        if nozzleGlobal != nil,case .subscription(let id)=action,let handler=nozzleEventDelegate{return handler.beginNozzle(id:id,local:current)}
        guard let onAction else{return false};onAction(action);return true
    }
    /// Neutral checks exercise the same dispatcher without creating a native window/event source.
    @_spi(DockResourceChecks) @discardableResult public func performPointerPress(atLocal point:NSPoint)->Bool{
        dispatchPointer(currentPoint:{point})
    }
    public override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    public override func mouseDown(with event:NSEvent){
        guard !failed else{return}
        if event.modifierFlags.contains(.control) {
            if let menu = menu(for: event) { NSMenu.popUpContextMenu(menu, with: event, for: self) }
            return
        }
        let eventWindow=window,screenPoint=window?.convertPoint(toScreen:event.locationInWindow)
        func currentPoint()->NSPoint?{
            if let eventWindow,let screenPoint{
                guard window === eventWindow else{return nil}
                return convert(eventWindow.convertPoint(fromScreen:screenPoint),from:nil)
            }
            guard window==nil else{return nil};return convert(event.locationInWindow,from:nil)
        }
        guard let p=currentPoint() else{return}
        if let screenPoint,backgroundDragDelegate?.beginBackgroundMove(local:p,global:screenPoint) == true{return}
        dispatchPointer(currentPoint:currentPoint,nozzleGlobal:screenPoint)
    }
}
