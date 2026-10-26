// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanPrimitives
@testable import ModelPlanCockpitShell

@MainActor private final class VisibleTestWindow: NSWindow {
    override var isVisible: Bool { true }
    override var occlusionState: NSWindow.OcclusionState { .visible }
}
@MainActor private final class TestSkin: CockpitShellSkin {
    var suppliedStill: CGImage?, layersRequested = 0, discarded = 0
    var marker = false, failLayers = false
    var badRaster = false, badBounds = false
    func layout(for s: CockpitSurfaceState) throws -> CockpitSurfaceLayout {
        CockpitSurfaceLayout(rootSize:CGSize(width:80,height:100),
            drawableBounds:badBounds ? CGRect(x:0,y:0,width:Double.infinity,height:110):CGRect(x:-4,y:s.closed ? 10:0,width:88,height:s.closed ? 100:110),
            slots:s.closed ? [.controls:CGRect(x:8,y:12,width:60,height:10)] : [.window:CGRect(x:0,y:0,width:80,height:10),.controls:CGRect(x:8,y:12,width:60,height:10)],
            expectedStillKey:s.closed ? nil:"current")
    }
    func backdrop(for s: CockpitSurfaceState, layout: CockpitSurfaceLayout, matchingStill: CGImage?) throws -> CGImage {
        suppliedStill = matchingStill
        return Self.image(width:badRaster ? 1:Int(layout.drawableBounds.width)*s.appearance.scale,
                          height:Int(layout.drawableBounds.height)*s.appearance.scale)
    }
    static func image(width:Int=1,height:Int=1)->CGImage {
        CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }
    func stationLayers(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout) throws -> [CALayer] {
        layersRequested += 1
        if failLayers { throw CockpitSurfaceError.invalidRaster }
        let layer = CALayer()
        if marker { layer.frame = CGRect(x:20,y:95,width:10,height:3); layer.backgroundColor = NSColor.red.cgColor }
        return [layer]
    }
    func discardTransientResources() { discarded += 1 }
}
final class CockpitShellSurfaceTests: XCTestCase {
    func testStillIdentityClosedAllocationAndWholeRootInputScaling() async throws {
        try await MainActor.run {
            let skin = TestSkin(), surface = CockpitShellSurface(skin:skin)
            let window = NSView(), controls = NSButton(title:"Key",target:nil,action:nil)
            surface.setContent(window,for:.window); surface.setContent(controls,for:.controls)
            try surface.configure(.init(profile:.full,closed:false,appearance:.init(scale:2),still:.init(key:"stale",image:TestSkin.image())))
            XCTAssertNil(skin.suppliedStill)
            try surface.configure(.init(profile:.full,closed:false,appearance:.init(scale:2),still:.init(key:"current",image:TestSkin.image())))
            XCTAssertNotNil(skin.suppliedStill); XCTAssertFalse(window.isHidden)
            try surface.setRootScale(0.5)
            XCTAssertEqual(surface.frame.size,CGSize(width:44,height:55))
            XCTAssertEqual(surface.bounds,CGRect(x:-4,y:0,width:88,height:110))
            XCTAssertEqual(controls.frame,CGRect(x:8,y:12,width:60,height:10))
            let parent = NSView(frame:CGRect(x:0,y:0,width:100,height:100)); parent.addSubview(surface)
            let local = CGPoint(x:30,y:17)
            let roundTrip = surface.convert(parent.convert(local,from:surface),from:parent)
            XCTAssertEqual(roundTrip.x,local.x,accuracy:1e-8); XCTAssertEqual(roundTrip.y,local.y,accuracy:1e-8)
            try surface.configure(.init(profile:.compact,closed:true,appearance:.init(scale:1),still:.init(key:"current",image:TestSkin.image())))
            XCTAssertNil(skin.suppliedStill); XCTAssertTrue(window.isHidden); XCTAssertFalse(controls.isHidden)
            XCTAssertEqual(surface.bounds.minY,10); XCTAssertEqual(skin.layersRequested,0)
            surface.stop()
        }
    }
    func testMalformedInputsAndProviderRasterFailBeforeRetention() async throws {
        try await MainActor.run {
            let skin = TestSkin(), surface = CockpitShellSurface(skin:skin)
            let duplicate = CockpitStation(id:"same",centerX:20,columnWidth:10,working:true,signal:.healthy)
            XCTAssertThrowsError(try surface.configure(.init(profile:.full,closed:false,appearance:.init(),stations:[duplicate,duplicate])))
            XCTAssertThrowsError(try surface.configure(.init(profile:.full,closed:false,appearance:.init(scale:3))))
            XCTAssertThrowsError(try surface.configure(.init(profile:.full,closed:false,appearance:.init(),effectPhase:.nan)))
            XCTAssertThrowsError(try surface.setRootScale(.infinity)); XCTAssertThrowsError(try surface.setRootScale(0))
            skin.badBounds = true
            XCTAssertThrowsError(try surface.configure(.init(profile:.full,closed:false,appearance:.init())))
            skin.badBounds = false; skin.badRaster = true
            XCTAssertThrowsError(try surface.configure(.init(profile:.full,closed:false,appearance:.init())))
            XCTAssertNil(surface.state); XCTAssertEqual(surface.backdropBytes,0)
        }
    }
    func testQuickFadeKeepsInputAvailableAndSuspensionDropsTransientResources() async throws {
        try await MainActor.run {
            let skin = TestSkin(), surface = CockpitShellSurface(skin:skin)
            try surface.configure(.init(profile:.full,closed:false,appearance:.init()))
            try surface.quickOpen(reduceMotion:false)
            XCTAssertEqual(surface.layer?.animation(forKey:"cockpit-quick-open")?.duration,0.18)
            XCTAssertFalse(surface.isHidden); XCTAssertEqual(surface.layer?.opacity,1)
            try surface.quickOpen(reduceMotion:true); XCTAssertNil(surface.layer?.animation(forKey:"cockpit-quick-open"))
            let before = skin.discarded
            surface.setPresentationAllowed(false); XCTAssertGreaterThan(skin.discarded,before)
            surface.setPresentationAllowed(true); XCTAssertEqual(surface.stationLayerCount,0)
            surface.stop(); XCTAssertEqual(skin.layersRequested,0)
        }
    }
    func testHostedStationUsesRootCoordinatesAndFailureReleasesResources() async throws {
        try await MainActor.run {
            _ = NSApplication.shared
            let skin = TestSkin(); skin.marker = true
            let surface = CockpitShellSurface(skin:skin)
            // Logical visibility seam only; physical occlusion is separately verified in the private host.
            let window = VisibleTestWindow(contentRect:CGRect(x:0,y:0,width:88,height:110),styleMask:.borderless,backing:.buffered,defer:false)
            window.isReleasedWhenClosed = false; window.contentView = surface
            defer { surface.stop(); window.contentView = nil; window.close() }
            try surface.configure(.init(profile:.full,closed:false,appearance:.init(scale:1)))
            XCTAssertEqual(surface.stationLayerCount,1)
            let ctx = CGContext(data:nil,width:88,height:110,bitsPerComponent:8,bytesPerRow:352,
                space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.translateBy(x:0,y:110); ctx.scaleBy(x:1,y:-1)
            surface.layer!.render(in:ctx)
            let pixels = ctx.data!.assumingMemoryBound(to:UInt8.self)
            XCTAssertGreaterThan(pixels[96*352+26*4],200)
            XCTAssertEqual(pixels[14*352+26*4],0)
            var reported = false
            surface.onRenderingFailure = { _ in reported = true }
            skin.failLayers = true; let before = skin.discarded
            surface.setPresentationAllowed(true)
            XCTAssertTrue(reported); XCTAssertEqual(surface.stationLayerCount,0); XCTAssertGreaterThan(skin.discarded,before)
        }
    }
    func testConfiguredOpenHeightsDriveTierChoiceAndContainment() throws {
        let metrics = CockpitMetrics(contentWidth:400,silhouetteWidth:420,closedFullHeight:510,closedCompactHeight:430,
                                     exhaustReserve:24,openFullHeight:734,openCompactHeight:548)
        for (height,tier) in [(CGFloat(764),CockpitHeightTier.full),(763,.compact),(577,.collapsed),(400,.collapsed)] {
            let fit = try XCTUnwrap(CockpitLayout.fit(.init(usableFrame:CGRect(x:-900,y:100,width:800,height:height),anchorX:-400,anchorOffset:300),metrics:metrics,window:.init()))
            XCTAssertEqual(fit.tier,tier)
            XCTAssertLessThanOrEqual(fit.occupiedFrame.height,height-6+1e-8)
            XCTAssertGreaterThanOrEqual(fit.occupiedFrame.minY,100-1e-8)
        }
    }
}
