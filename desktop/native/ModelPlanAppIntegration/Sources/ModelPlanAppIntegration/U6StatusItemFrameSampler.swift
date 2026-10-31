// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics

/// Passive geometry only. The application constructs this sampler only from its
/// U6 test-contract guard; hosted tests supply their own status item and sink.
@MainActor final class U6StatusItemFrameSampler {
    struct Geometry: Equatable {
        let frame: CGRect, display: CGRect, band: CGRect
    }
    struct Stability {
        private var geometry: Geometry?
        private var since: Double = 0
        private var emitted = false
        mutating func reset() { geometry=nil;emitted=false }
        mutating func observe(_ value: Geometry?, mono: Double) -> Double? {
            guard let value,mono.isFinite else { reset();return nil }
            if value != geometry { geometry=value;since=mono;emitted=false }
            guard !emitted,mono-since>=0.5 else { return nil }
            emitted=true;return since
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
        return Geometry(frame:cg,display:display,band:band)
    }
    private weak var button: NSStatusBarButton?
    private weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var stability=Stability()
    private let emit: ([String:Any]) -> Void
    init(emit: @escaping ([String:Any]) -> Void) { self.emit=emit }
    func bind(_ button: NSStatusBarButton) {
        if self.button !== button { stability.reset() }
        self.button=button
        // Binding is not placement. Re-rendering the same item must not restart
        // the clock unless its observed window/geometry actually changes.
        updateWindow(button.window)
    }
    private func updateWindow(_ value: NSWindow?) {
        guard window !== value else { return }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers=[];window=value;stability.reset()
        guard let value else { return }
        for name in [NSWindow.didMoveNotification,NSWindow.didResizeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:value,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            })
        }
    }
    func sample(mono: Double = ProcessInfo.processInfo.systemUptime) {
        guard let button else { stability.reset();return }
        updateWindow(button.window)
        guard let window=button.window,window.isVisible,let screen=window.screen,
              let id=screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let primary=NSScreen.screens.first else { stability.reset();return }
        let frame=window.convertToScreen(button.convert(button.bounds,to:nil))
        let value=Self.geometry(frame:frame,screen:screen.frame,primaryTop:primary.frame.maxY,
            menuHeight:NSStatusBar.system.thickness,active:CGDisplayIsActive(id.uint32Value) != 0)
        guard let since=stability.observe(value,mono:mono),let value else { return }
        func rectangle(_ r:CGRect) -> [Double] { [Double(r.minX),Double(r.minY),Double(r.width),Double(r.height)] }
        emit(["x":frame.minX,"y":frame.minY,"width":frame.width,"height":frame.height,
              "coordinateSpace":"appkit-screen","cgX":value.frame.minX,"cgY":value.frame.minY,
              "settled":true,"stableSinceMono":since,"displayBounds":rectangle(value.display),"menuBarBand":rectangle(value.band)])
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}
