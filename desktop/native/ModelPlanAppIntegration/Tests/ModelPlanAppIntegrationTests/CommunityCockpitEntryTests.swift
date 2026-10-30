// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

final class CommunityCockpitEntryTests: XCTestCase {
    @MainActor func testActualDockConsoleSelectorRoutesToProductCockpitOnlyWhenPermitted() async {
        var opens = 0
        CommunityCockpitEntry.actionProbe = { opens += 1 }
        defer { CommunityCockpitEntry.actionProbe = nil }
        let host = StaticDockPreviewHost(currentDate:Date.init,createsNativePanels:false)
        _ = host.perform(NSSelectorFromString("openConsole"))
        XCTAssertEqual(opens,0)
        host.setPresentationAllowed(true)
        _ = host.perform(NSSelectorFromString("openConsole"))
        XCTAssertEqual(opens,1,"The exact Dock/menu Objective-C action must reach the product binding")
        host.setPresentationAllowed(false)
        _ = host.perform(NSSelectorFromString("openConsole"))
        XCTAssertEqual(opens,1,"Blocked presentation cannot create a cockpit")
        host.close()
    }
}
