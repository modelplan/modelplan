// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

// An extension in its own file: the class is a headless one, whose own source must stay unconditional.
#if MODELPLAN_TEST_ONLY_SPI
extension CommunityCockpitEntryTests {
    /// CKP-SHELL-27 at the normal entry: the real factory and console, opened before the engine has
    /// a session. The log names the path, and the recovery notice is the one the user always got.
    @MainActor func testNormalEntryOpenFailureLogsItsPathAndKeepsTheRecoveryNotice() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("ckp-shell-27-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let store=try EngineRowsEntry.makeSettingsStore(applicationSupport:root,preferredLanguages:["en"])
        var notices:[CockpitUnavailableNotice]=[],lines:[String]=[]
        CommunityCockpitApplicationFactory.verificationPageFactory={ _ in throw CockpitBridgeError.unavailable }
        CommunityCockpitApplicationFactory.verificationConsoleNotice={ notices.append($0) }
        CockpitFailureLog.verificationLine={ lines.append($0) }
        defer {
            CommunityCockpitApplicationFactory.verificationPageFactory=nil
            CommunityCockpitApplicationFactory.verificationConsoleNotice=nil
            CockpitFailureLog.verificationLine=nil
        }
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),
            settingsStore:store,createsNativePanels:false,cockpitEntryEnabled:true,activateSettings:{})
        await app.prepare()
        app.showConsole()
        for _ in 0..<300 where notices.isEmpty { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(notices.count,1,"The failed open still asks for the recovery notice")
        XCTAssertEqual(notices.first?.history,false)
        XCTAssertEqual(notices.first?.actions,[.settings,.dockReadings,.cancel])
        XCTAssertEqual(lines,["unavailable path=open.noDelivery wantsVisible=true foreground=true pageOpened=false"])
        await app.composition.stop()
    }
}
#endif
