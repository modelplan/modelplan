// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import ModelPlanPrimitives

public enum CockpitContentSlot: String, CaseIterable, Sendable { case window, controls, engines, console, records }
public enum CockpitStationSignal: Sendable { case healthy, warning, critical, unknown }
public struct CockpitStation {
    /// Nil is an inert empty bay. Centers/widths come from the visible engine columns, not array guesses.
    public let id: String?
    public let centerX: CGFloat, columnWidth: CGFloat
    public let working: Bool
    public let signal: CockpitStationSignal
    public let outputRate: Double?
    public let color: NSColor
    public init(id: String?, centerX: CGFloat, columnWidth: CGFloat, working: Bool,
                signal: CockpitStationSignal, outputRate: Double? = nil, color: NSColor = .gray) {
        self.id = id; self.centerX = centerX; self.columnWidth = columnWidth
        self.working = id != nil && working; self.signal = signal; self.outputRate = outputRate; self.color = color
    }
}
public struct CockpitStill {
    public let key: String
    public let image: CGImage
    public init(key: String, image: CGImage) { self.key = key; self.image = image }
}
public struct CockpitSurfaceState {
    public let profile: CockpitProfile
    public let closed: Bool
    public let appearance: RenderProfile
    public let stations: [CockpitStation]
    public let still: CockpitStill?
    /// An injected named phase for deterministic captures; nil requests the provider's bounded live effects.
    public let effectPhase: Double?
    public init(profile: CockpitProfile, closed: Bool, appearance: RenderProfile,
                stations: [CockpitStation] = [], still: CockpitStill? = nil, effectPhase: Double? = nil) {
        self.profile = profile; self.closed = closed; self.appearance = appearance
        self.stations = stations; self.still = still; self.effectPhase = effectPhase
    }
}
public struct CockpitSurfaceLayout {
    /// All coordinates use the provider's root points, with Y down. Transparent canvas padding can be cropped.
    public let rootSize: CGSize
    public let drawableBounds: CGRect
    public let slots: [CockpitContentSlot: CGRect]
    public let expectedStillKey: String?
    public init(rootSize: CGSize, drawableBounds: CGRect, slots: [CockpitContentSlot: CGRect], expectedStillKey: String?) {
        self.rootSize = rootSize; self.drawableBounds = drawableBounds; self.slots = slots; self.expectedStillKey = expectedStillKey
    }
}
public enum CockpitSurfaceError: Error { case invalidGeometry, duplicateStation, invalidRaster }

/// Distinctive geometry/materials/assets stay in an external presentation provider. The community provider
/// below is complete and neutral; no private checkout, WebKit, RealityKit or artwork is required.
@MainActor public protocol CockpitShellSkin: AnyObject {
    func layout(for state: CockpitSurfaceState) throws -> CockpitSurfaceLayout
    func backdrop(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout, matchingStill: CGImage?) throws -> CGImage
    /// Layers use root coordinates and are owned exclusively by this surface. Hidden surfaces discard them.
    func stationLayers(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout) throws -> [CALayer]
    func discardTransientResources()
}

@MainActor public final class CockpitShellSurface: NSView {
    public override var isFlipped: Bool { true }
    public private(set) var surfaceLayout: CockpitSurfaceLayout?
    public private(set) var state: CockpitSurfaceState?
    public private(set) var rootScale: CGFloat = 1
    public var onLayoutChanged: ((CockpitSurfaceLayout) -> Void)?
    public private(set) var stationLayerCount = 0
    public private(set) var backdropBytes = 0
    private let skin: any CockpitShellSkin
    private let backdropLayer = CALayer(), stationContainer = CALayer()
    private var content: [CockpitContentSlot: NSView] = [:]
    private var presentationAllowed = true
    private var windowToken: NSObjectProtocol?
    private var accessibilityToken: NSObjectProtocol?
    public var onRenderingFailure: ((Error) -> Void)?
    public init(skin: any CockpitShellSkin) {
        self.skin = skin; super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(backdropLayer); layer?.addSublayer(stationContainer)
        accessibilityToken = NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object:nil,queue:.main) { [weak self] _ in MainActor.assumeIsolated { self?.refreshStations() } }
    }
    public required init?(coder: NSCoder) { return nil }
    public override var intrinsicContentSize: NSSize {
        guard let layout = surfaceLayout else { return .zero }
        return NSSize(width: layout.drawableBounds.width * rootScale, height: layout.drawableBounds.height * rootScale)
    }
    public func setContent(_ view: NSView?, for slot: CockpitContentSlot) {
        content.removeValue(forKey: slot)?.removeFromSuperview()
        if let view { content[slot] = view; addSubview(view) }
        updateGeometry()
    }
    public func setRootScale(_ scale: CGFloat) throws {
        guard scale.isFinite, scale > 0, scale <= 4 else { throw CockpitSurfaceError.invalidGeometry }
        rootScale = scale; updateGeometry()
    }
    public func configure(_ state: CockpitSurfaceState) throws {
        let layout = try skin.layout(for: state)
        try validate(layout, state)
        let still = !state.closed && state.still?.key == layout.expectedStillKey ? state.still?.image : nil
        let image = try skin.backdrop(for: state, layout: layout, matchingStill: still)
        let scale = CGFloat(state.appearance.scale)
        guard image.width == Int(ceil(layout.drawableBounds.width * scale)),
              image.height == Int(ceil(layout.drawableBounds.height * scale)) else { throw CockpitSurfaceError.invalidRaster }
        self.state = state; surfaceLayout = layout
        CATransaction.begin(); CATransaction.setDisableActions(true)
        backdropLayer.contents = image; backdropLayer.contentsScale = scale; backdropLayer.contentsGravity = .resize
        backdropBytes = image.bytesPerRow * image.height
        CATransaction.commit()
        updateGeometry(); try rebuildStations()
        onLayoutChanged?(layout)
    }
    /// OS pause/Space/ordering is supplied by the native owner; application deactivation alone is irrelevant.
    public func setPresentationAllowed(_ allowed: Bool) {
        presentationAllowed = allowed
        if allowed { refreshStations() }
        else { clearStations(); skin.discardTransientResources() }
    }
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let windowToken { NotificationCenter.default.removeObserver(windowToken) }; windowToken = nil
        if let window {
            windowToken = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                object: window, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.refreshStations() } }
        }
        refreshStations()
    }
    public override func viewDidHide() { super.viewDidHide(); clearStations(); skin.discardTransientResources() }
    public override func viewDidUnhide() { super.viewDidUnhide(); refreshStations() }
    /// Input remains available throughout the compositor-only quick-open fade.
    public func quickOpen(reduceMotion: Bool, duration: CFTimeInterval = 0.18) throws {
        guard duration.isFinite, duration >= 0, duration <= 1 else { throw CockpitSurfaceError.invalidGeometry }
        layer?.removeAnimation(forKey: "cockpit-quick-open")
        guard !reduceMotion, duration > 0 else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0; fade.toValue = 1; fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.add(fade, forKey: "cockpit-quick-open")
    }
    public func stop() { layer?.removeAnimation(forKey: "cockpit-quick-open"); presentationAllowed = false; clearStations(); skin.discardTransientResources() }
    private func validate(_ layout: CockpitSurfaceLayout, _ state: CockpitSurfaceState) throws {
        let b = layout.drawableBounds
        guard !b.isNull, !b.isInfinite, [b.minX,b.minY,b.width,b.height,layout.rootSize.width,layout.rootSize.height].allSatisfy(\.isFinite),
              b.width > 0, b.height > 0, b.width <= 2048, b.height <= 2048,
              layout.rootSize.width > 0, layout.rootSize.height > 0,
              layout.rootSize.width <= 2048, layout.rootSize.height <= 2048,
              state.effectPhase.map({ $0.isFinite && $0 >= 0 }) ?? true, (1...2).contains(state.appearance.scale) else {
            throw CockpitSurfaceError.invalidGeometry
        }
        for rect in layout.slots.values {
            guard !rect.isNull, !rect.isInfinite, [rect.minX,rect.minY,rect.width,rect.height].allSatisfy(\.isFinite),
                  rect.width >= 0, rect.height >= 0, b.contains(rect) else { throw CockpitSurfaceError.invalidGeometry }
        }
        var ids: Set<String> = []
        for station in state.stations {
            guard station.centerX.isFinite, station.columnWidth.isFinite, station.columnWidth > 0,
                  station.centerX >= b.minX, station.centerX <= b.maxX,
                  station.outputRate.map({ $0.isFinite && $0 >= 0 }) ?? true else { throw CockpitSurfaceError.invalidGeometry }
            if let id = station.id, id.isEmpty || !ids.insert(id).inserted { throw CockpitSurfaceError.duplicateStation }
        }
    }
    private func updateGeometry() {
        guard let layout = surfaceLayout else { return }
        frame.size = intrinsicContentSize
        bounds = layout.drawableBounds // NSView scales drawing, child controls and input coordinates together.
        CATransaction.begin(); CATransaction.setDisableActions(true)
        backdropLayer.frame = bounds; stationContainer.frame = bounds; stationContainer.bounds = bounds
        CATransaction.commit()
        for (slot, view) in content {
            view.isHidden = (slot == .window && state?.closed == true) || layout.slots[slot] == nil
            if let rect = layout.slots[slot] { view.frame = rect }
        }
        invalidateIntrinsicContentSize()
    }
    private func rebuildStations() throws {
        clearStations()
        guard presentationAllowed, !isHiddenOrHasHiddenAncestor, let state, let layout = surfaceLayout,
              window.map({ $0.isVisible && $0.occlusionState.contains(.visible) }) ?? false else {
            skin.discardTransientResources(); return
        }
        let layers: [CALayer]
        do { layers = try skin.stationLayers(for:state,layout:layout) }
        catch { skin.discardTransientResources(); throw error }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for layer in layers { stationContainer.addSublayer(layer) }
        stationLayerCount = layers.count
        CATransaction.commit()
    }
    private func refreshStations() {
        do { try rebuildStations() }
        catch { clearStations(); skin.discardTransientResources(); onRenderingFailure?(error) }
    }
    private func clearStations() {
        func clear(_ layer: CALayer) { layer.removeAllAnimations(); for child in layer.sublayers ?? [] { clear(child) } }
        for layer in stationContainer.sublayers ?? [] { clear(layer); layer.removeFromSuperlayer() }
        stationLayerCount = 0
    }
    deinit {
        if let windowToken { NotificationCenter.default.removeObserver(windowToken) }
        if let accessibilityToken { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityToken) }
        let skin = skin
        Task { @MainActor in skin.discardTransientResources() }
    }
}

@MainActor public final class NeutralCockpitShellSkin: CockpitShellSkin {
    public init() {}
    public func layout(for state: CockpitSurfaceState) throws -> CockpitSurfaceLayout {
        let height: CGFloat = state.closed ? 420 : state.profile == .full ? 700 : 540
        var slots: [CockpitContentSlot: CGRect] = [.controls: CGRect(x: 12,y: 12,width: 376,height: 30)]
        if !state.closed { slots[.window] = CGRect(x: 12,y: 50,width: 376,height: 100) }
        return CockpitSurfaceLayout(rootSize: CGSize(width: 400,height: height),
            drawableBounds: CGRect(x: 0,y: 0,width: 400,height: height + 24), slots: slots, expectedStillKey: nil)
    }
    public func backdrop(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout, matchingStill: CGImage?) throws -> CGImage {
        let scale = state.appearance.scale, b = layout.drawableBounds
        guard let ctx = CGContext(data: nil,width: Int(b.width)*scale,height: Int(b.height)*scale,bitsPerComponent: 8,bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CockpitSurfaceError.invalidRaster }
        ctx.scaleBy(x: CGFloat(scale),y: CGFloat(scale))
        ctx.setFillColor(NSColor(calibratedWhite: state.appearance.dark ? 0.12 : 0.8,alpha: 1).cgColor)
        ctx.fill(CGRect(origin: .zero,size: layout.rootSize))
        guard let image = ctx.makeImage() else { throw CockpitSurfaceError.invalidRaster }; return image
    }
    public func stationLayers(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout) throws -> [CALayer] { [] }
    public func discardTransientResources() {}
}
