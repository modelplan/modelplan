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
        CommunityCockpitApplicationFactory.verificationNoticeGrace = .milliseconds(300)
        CockpitFailureLog.verificationLine={ lines.append($0) }
        defer {
            CommunityCockpitApplicationFactory.verificationNoticeGrace=nil
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
        XCTAssertEqual(lines.count,1)
        let line=lines.first ?? ""
        XCTAssertTrue(line.hasPrefix("unavailable path=open.noDelivery wantsVisible=true foreground=true pageOpened=false "),line)
        XCTAssertTrue(line.contains("sinceLaunchMs="),"The line says how early in the launch it happened")
        XCTAssertTrue(line.contains("engine=[client=true delivery=false"),"and the engine's state")
        await app.composition.stop()
    }

    /// The failure line's launch age comes from the process start time, not the -1 "unknown" fallback (glm-783-1).
    func testMsSinceLaunchReadsTheProcessStartTime() async throws {
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertGreaterThan(CockpitFailureLog.msSinceLaunch, 0)
    }

    /// G3-66, startup order: an open before the engine has its first context is not announced at once. The notice
    /// waits out its grace period (the open is retried meanwhile) and only a failure that lasts reaches the user.
    @MainActor func testOpenBeforeTheEngineIsReadyOnlyAnnouncesAFailureThatLasts() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("g3-66-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let store=try EngineRowsEntry.makeSettingsStore(applicationSupport:root,preferredLanguages:["en"])
        var notices:[CockpitUnavailableNotice]=[]
        CommunityCockpitApplicationFactory.verificationPageFactory={ _ in throw CockpitBridgeError.unavailable }
        CommunityCockpitApplicationFactory.verificationConsoleNotice={ notices.append($0) }
        CommunityCockpitApplicationFactory.verificationNoticeGrace = .milliseconds(1500)
        defer {
            CommunityCockpitApplicationFactory.verificationPageFactory=nil
            CommunityCockpitApplicationFactory.verificationConsoleNotice=nil
            CommunityCockpitApplicationFactory.verificationNoticeGrace=nil
        }
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),
            settingsStore:store,createsNativePanels:false,cockpitEntryEnabled:true,activateSettings:{})
        await app.prepare()
        app.showConsole()
        try await Task.sleep(for:.milliseconds(600))
        XCTAssertTrue(notices.isEmpty,"The engine may still be starting: nothing is announced inside the grace period")
        for _ in 0..<300 where notices.isEmpty { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(notices.count,1,"A failure that outlasts the grace period is announced once")
        await app.composition.stop()
    }
}
#endif
