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
    /// macrevc-786-1: the grace period only ends as a recovery when a page opened and nothing failed after it.
    /// A rebuild that opens, then fails, and whose next page cannot be created, must still announce the failure.
    @MainActor func testFailedRebuildAfterAPageFailureStillShowsTheNoticeAndASuccessfulRebuildDoesNot() async throws {
        for recovers in [false,true] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("g3-66-rebuild-"+UUID().uuidString)
            defer{try? FileManager.default.removeItem(at:root)}
            let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
            let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
            let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
            let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
            owner.coordinator=coordinator
            var notices:[CockpitUnavailableNotice]=[]
            let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(300))
            surface.show()
            for _ in 0..<50 where !surface.wantsVisible { try await Task.sleep(for:.milliseconds(10)) }
            owner.pageFailure?(.messageRejected)          // the first page fails
            coordinator.onOpened?()                        // the rebuild opens ...
            if !recovers {
                owner.pageFailure?(.messageRejected)       // ... then fails
                coordinator.onUnavailable?(.pageCreation("synthetic")) // and the next page cannot be created
            }
            try await Task.sleep(for:.milliseconds(900))
            XCTAssertEqual(notices.count,recovers ? 0 : 1,recovers ? "A rebuild that opened and stayed up is a recovery: no notice" : "A rebuild that failed again is announced, not treated as a recovery")
            surface.hide();await coordinator.shutdown();await composition.stop()
        }
    }
}
#endif
