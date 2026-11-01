// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import AppKit
import ModelPlanDock
import XCTest
@testable import ModelPlanOfficialDock

final class T2ImpactJetTests: XCTestCase {
    func testFrameUsesBoundedSourceResolutionAndProtectsLogoCentre() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let image = try T2ImpactJet.frame(diameter: diameter, backingScale: 2, status: .normal, time: 0.672)
            let side = Int((diameter * 1.5).rounded())
            XCTAssertEqual(image.width, side); XCTAssertEqual(image.height, side)
            let pixels = NSBitmapImageRep(cgImage: image)
            XCTAssertEqual(try XCTUnwrap(pixels.colorAt(x: side/2, y: side/2)).alphaComponent, 0, accuracy: 1.0/255)
            XCTAssertEqual(try XCTUnwrap(pixels.colorAt(x: 0, y: 0)).alphaComponent, 0, accuracy: 1.0/255)
        }
    }
    func testFramesAreDeterministicAndTimeVarying() throws {
        func bytes(_ time: Double) throws -> Data {
            let image = try T2ImpactJet.frame(diameter: 44, backingScale: 2, status: .critical, time: time)
            return try XCTUnwrap(image.dataProvider?.data as Data?)
        }
        XCTAssertEqual(try bytes(1.8), try bytes(1.8))
        XCTAssertNotEqual(try bytes(0.672), try bytes(0.784))
        XCTAssertThrowsError(try T2ImpactJet.frame(diameter: 44, backingScale: 2, status: .unknown, time: 0))
    }
}
