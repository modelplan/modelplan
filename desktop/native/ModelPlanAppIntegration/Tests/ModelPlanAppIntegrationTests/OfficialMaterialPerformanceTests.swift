// SPDX-License-Identifier: MIT
import CoreGraphics
import XCTest
@testable import ModelPlanOfficialDock

@MainActor final class OfficialMaterialPerformanceTests: XCTestCase {
    func testRepeatedNoiseViewportReusesExactBytes() {
        let cache = T2GrainRasterCache(capacity: 1024), view = CGRect(x: 3, y: 7, width: 2, height: 2)
        let first = cache.raster(viewport: view, scale: 1)
        XCTAssertEqual(cache.raster(viewport: view, scale: 1), first)
        XCTAssertEqual(cache.rasterizations, 1)
        let uncached = T2GrainRasterCache(capacity: 0)
        XCTAssertEqual(first, uncached.raster(viewport: view, scale: 1))
    }
    func testNoiseKeyIncludesOriginSizeAndBackingScale() {
        let cache = T2GrainRasterCache(capacity: 4096), view = CGRect(x: 3, y: 7, width: 2, height: 2)
        let base = cache.raster(viewport: view, scale: 1)
        XCTAssertNotEqual(base, cache.raster(viewport: view.offsetBy(dx: 1, dy: 0), scale: 1))
        XCTAssertNotEqual(base, cache.raster(viewport: view.offsetBy(dx: 0, dy: 1), scale: 1))
        XCTAssertEqual(cache.raster(viewport: view, scale: 2).count, 256)
        XCTAssertEqual(cache.raster(viewport: CGRect(x:3,y:7,width:3,height:2), scale:1).count, 96)
        XCTAssertEqual(cache.rasterizations, 5)
    }
    func testTinyRasterKeysHaveAnEntryBoundAsWellAsAByteBound() {
        let cache = T2GrainRasterCache(capacity:4096)
        for x in 0..<100 { _ = cache.raster(viewport:CGRect(x:x,y:0,width:1,height:1),scale:1) }
        XCTAssertEqual(cache.retainedBytes,32*16)
    }
    func testNoiseReuseIsBoundedAndOversizedRasterIsNotRetained() {
        let cache = T2GrainRasterCache(capacity: 32)
        let a = CGRect(x:0,y:0,width:1,height:1), b = a.offsetBy(dx:1,dy:0), c = a.offsetBy(dx:2,dy:0)
        _ = cache.raster(viewport:a,scale:1); _ = cache.raster(viewport:b,scale:1)
        _ = cache.raster(viewport:a,scale:1); _ = cache.raster(viewport:c,scale:1)
        XCTAssertEqual(cache.retainedBytes,32); XCTAssertEqual(cache.rasterizations,3)
        _ = cache.raster(viewport:a,scale:1); XCTAssertEqual(cache.rasterizations,3)
        _ = cache.raster(viewport:b,scale:1); XCTAssertEqual(cache.rasterizations,4)
        _ = cache.raster(viewport:a,scale:2); XCTAssertEqual(cache.retainedBytes,32)
    }
}
