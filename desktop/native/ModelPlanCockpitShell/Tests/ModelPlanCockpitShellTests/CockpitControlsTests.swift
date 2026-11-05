// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanPrimitives
@testable import ModelPlanCockpitShell

final class CockpitControlsTests: XCTestCase {
    func testShutterGestureTwoDetentsSlopCancellationAndDisabled() throws {
        XCTAssertNil(CockpitShutterGesture(x:.nan,closed:false,travel:100))
        XCTAssertNil(CockpitShutterGesture(x:0,closed:false,travel:0))
        var click = try XCTUnwrap(CockpitShutterGesture(x:20,closed:false,travel:100))
        click.move(to:23); XCTAssertFalse(click.moved); XCTAssertEqual(click.finish(at:23,enabled:true),true)
        var drag = try XCTUnwrap(CockpitShutterGesture(x:20,closed:false,travel:100))
        drag.move(to:69); XCTAssertTrue(drag.moved); XCTAssertEqual(drag.fraction,0.49,accuracy:1e-9)
        XCTAssertEqual(drag.finish(at:69,enabled:true),false)
        XCTAssertEqual(drag.finish(at:70,enabled:true),true)
        XCTAssertNil(drag.finish(at:120,enabled:false)); XCTAssertNil(drag.finish(at:.nan,enabled:true))
        var closing = try XCTUnwrap(CockpitShutterGesture(x:0,closed:true,travel:100))
        closing.move(to:-200); XCTAssertEqual(closing.fraction,0)
        XCTAssertEqual(closing.finish(at:-200,enabled:true),false)
    }
}
