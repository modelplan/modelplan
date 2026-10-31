// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics

/// Passive geometry only. The application constructs this sampler only from its
/// U6 test-contract guard; hosted tests supply their own status item and sink.
@MainActor final class U6StatusItemFrameSampler {
    struct Geometry: Equatable {
        let frame: CGRect, display: CGRect, band: CGRect, appKitFrame: CGRect
    }
    struct Publication {
        let generation: UInt64, windowNumber: Int, visible: Bool
        let geometry: Geometry?, stableSince: Double?
        var fields: [String:Any] {
            var result: [String:Any] = ["frameGeneration":generation,"windowNumber":windowNumber,
                "visible":visible,"settled":stableSince != nil]
            if let geometry,let since=stableSince {
                func rect(_ r:CGRect) -> [Double] { [Double(r.minX),Double(r.minY),Double(r.width),Double(r.height)] }
                result.merge(["x":geometry.appKitFrame.minX,"y":geometry.appKitFrame.minY,
                    "width":geometry.frame.width,"height":geometry.frame.height,"coordinateSpace":"appkit-screen",
                    "cgX":geometry.frame.minX,"cgY":geometry.frame.minY,"stableSinceMono":since,
                    "displayBounds":rect(geometry.display),"menuBarBand":rect(geometry.band)]) { _,new in new }
            }
            return result
        }
    }
    struct Stability {
        private var geometry: Geometry?
        private var since: Double = 0
        private var generation: UInt64 = 0
        private var windowNumber = 0
        private var visible = false
        private var lastPublication: Double = -.infinity
        mutating func observe(_ value: Geometry?, windowNumber: Int, visible: Bool,
                              mono: Double, force: Bool = false) -> Publication? {
            guard mono.isFinite else { return nil }
            let number=max(0,windowNumber),current=visible && number>0 ? value : nil
            if generation==0 || force || current != geometry || number != self.windowNumber || visible != self.visible {
                generation &+= 1;geometry=current;since=mono;self.windowNumber=number;self.visible=visible
                lastPublication=mono
                // Invalidation is itself current evidence, even with no geometry.
                return Publication(generation:generation,windowNumber:number,visible:visible,geometry:nil,stableSince:nil)
            }
            guard let current,mono-since>=0.5,mono-lastPublication>=0.2 else { return nil }
            lastPublication=mono
            return Publication(generation:generation,windowNumber:number,visible:visible,geometry:current,stableSince:since)
        }
    }
    static func geometry(frame: CGRect, screen: CGRect, primaryTop: CGFloat,
                         menuHeight: CGFloat, active: Bool) -> Geometry? {
        let values=[frame.minX,frame.minY,frame.width,frame.height,screen.minX,screen.minY,screen.width,screen.height,primaryTop,menuHeight]
        guard active,values.allSatisfy(\.isFinite),frame.width>0,frame.height>0,
              screen.width>0,screen.height>0,menuHeight>0,menuHeight<=screen.height else { return nil }
        let cg=CGRect(x:frame.minX,y:primaryTop-frame.maxY,width:frame.width,height:frame.height)
        let display=CGRect(x:screen.minX,y:primaryTop-screen.maxY,width:screen.width,height:screen.height)
        let band=CGRect(x:display.minX,y:display.minY,width:display.width,height:menuHeight)
        let centre=CGPoint(x:cg.midX,y:cg.midY)
        guard cg.minY<=display.minY+1,cg.maxY>=display.minY-1,
              display.contains(centre),band.contains(centre) else { return nil }
        return Geometry(frame:cg,display:display,band:band,appKitFrame:frame)
    }
    private weak var button: NSStatusBarButton?
    private weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var visibilityObserver: NSKeyValueObservation?
    private var mustInvalidate = true
    private var stability=Stability()
    private let emit: ([String:Any]) -> Void
    init(emit: @escaping ([String:Any]) -> Void) { self.emit=emit }
    func bind(_ button: NSStatusBarButton) {
        if self.button !== button { mustInvalidate=true }
        self.button=button
        // Binding is not placement. Re-rendering the same item must not restart
        // the clock unless its observed window/geometry actually changes.
        updateWindow(button.window)
        sample()
    }
    private func updateWindow(_ value: NSWindow?) {
        guard window !== value else { return }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers=[];visibilityObserver=nil;window=value;mustInvalidate=true
        guard let value else { return }
        visibilityObserver=value.observe(\.isVisible,options:[.new]) { [weak self] _,_ in
            MainActor.assumeIsolated { self?.sample() }
        }
        for name in [NSWindow.didMoveNotification,NSWindow.didResizeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:value,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            })
        }
    }
    func sample(mono: Double = ProcessInfo.processInfo.systemUptime) {
        updateWindow(button?.window)
        let visible=button?.window?.isVisible == true
        var value: Geometry?
        if let button,let window=button.window,visible,let screen=window.screen,
           let id=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           let primary=NSScreen.screens.first {
            value=Self.geometry(frame:window.convertToScreen(button.convert(button.bounds,to:nil)),
                screen:screen.frame,primaryTop:primary.frame.maxY,menuHeight:NSStatusBar.system.thickness,
                active:CGDisplayIsActive(id.uint32Value) != 0)
        }
        let publication=stability.observe(value,windowNumber:button?.window?.windowNumber ?? 0,
            visible:visible,mono:mono,force:mustInvalidate)
        mustInvalidate=false
        if let publication { emit(publication.fields) }
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}
