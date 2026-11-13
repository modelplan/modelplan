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
        XCTAssertEqual(lines.count,2,lines.joined(separator:"\n"))
        XCTAssertTrue(lines.last?.hasPrefix("notice-shown cause=open.noDelivery bundleProblem=false") ?? false,"the notice names its cause in the log")
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

    /// G3-95, content process terminated: the page is rebuilt silently; only a failure that lasts is announced, and the
    /// notice names the cause in the log and is not a reinstall prompt.
    @MainActor func testG395ContentProcessTerminationRecoversSilentlyOrNamesItsCauseAndDoesNotAskForReinstall() async throws {
        for recovers in [true,false] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("g395-term-"+UUID().uuidString)
            defer{try? FileManager.default.removeItem(at:root)}
            let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
            let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
            let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
            let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
            owner.coordinator=coordinator
            var notices:[CockpitUnavailableNotice]=[],lines:[String]=[]
            CockpitFailureLog.verificationLine={ lines.append($0) }
            defer{CockpitFailureLog.verificationLine=nil}
            let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(300))
            surface.show()
            try await Self.untilTheConsoleOpenStepRan(coordinator,surface)
            owner.pageFailure?(.contentTerminated)
            if recovers { coordinator.onOpened?() }
            try await Task.sleep(for:.milliseconds(900))
            XCTAssertEqual(notices.count,recovers ? 0 : 1)
            if !recovers {
                XCTAssertFalse(notices[0].bundleProblem,"a terminated content process is not a missing bundle: no reinstall copy")
                XCTAssertTrue(lines.contains { $0.hasPrefix("notice-shown cause=page.contentTerminated bundleProblem=false") },lines.joined(separator:"\n"))
            }
            surface.hide();await coordinator.shutdown();await composition.stop()
        }
    }
    /// G3-95, engine or client not ready: the open is tried once more after a short wait, inside the grace period, and
    /// the notice (if it still comes) is one, with the cause named.
    @MainActor func testG395OpenWithoutAClientIsRetriedOnceBeforeAnyNotice() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("g395-noclient-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        owner.coordinator=coordinator
        var notices:[CockpitUnavailableNotice]=[],lines:[String]=[],reports=0
        CockpitFailureLog.verificationLine={ lines.append($0) }
        defer{CockpitFailureLog.verificationLine=nil}
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(1800))
        let wrapped=coordinator.onUnavailable
        coordinator.onUnavailable={ reason in reports+=1; wrapped?(reason) }
        surface.show()
        try await Task.sleep(for:.milliseconds(1200))
        XCTAssertEqual(reports,2,"the first open and exactly one retry")
        XCTAssertTrue(notices.isEmpty,"nothing is announced inside the grace period")
        XCTAssertTrue(lines.contains { $0.hasPrefix("open-retry after=open.noClient") })
        for _ in 0..<300 where notices.isEmpty { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(notices.count,1)
        XCTAssertFalse(notices[0].bundleProblem)
        XCTAssertTrue(lines.contains { $0.hasPrefix("notice-shown cause=open.noClient bundleProblem=false") })
        surface.hide();await coordinator.shutdown();await composition.stop()
    }
    /// macrevc-887-2: an open before the first delivery is pending (open.noDelivery); when the delivery then finds a damaged
    /// bundle, the notice names that cause and asks for a reinstall, though the grace period began with the pending open.
    @MainActor func testG395BundleErrorAfterAPendingOpenIsNamedAndAsksForReinstall() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("g395-pending-bundle-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        owner.coordinator=coordinator
        var notices:[CockpitUnavailableNotice]=[],lines:[String]=[]
        CockpitFailureLog.verificationLine={ lines.append($0) }
        defer{CockpitFailureLog.verificationLine=nil}
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(400))
        surface.show()
        try await Self.untilTheConsoleOpenStepRan(coordinator,surface)
        coordinator.onUnavailable?(.noDelivery)                        // the open waits for the first context
        coordinator.onUnavailable?(.pageCreation("integrity"))         // the delivery finds a damaged bundle
        try await Task.sleep(for:.milliseconds(1000))
        XCTAssertEqual(notices.count,1,"one notice, the grace period was not restarted")
        XCTAssertTrue(notices.first?.bundleProblem ?? false,"a damaged bundle gets the reinstall copy")
        XCTAssertTrue(lines.contains { $0.hasPrefix("unavailable path=open.pageCreation.integrity") },lines.joined(separator:"\n"))
        XCTAssertTrue(lines.contains { $0.hasPrefix("notice-shown cause=open.pageCreation.integrity bundleProblem=true") },lines.joined(separator:"\n"))
        surface.hide();await coordinator.shutdown();await composition.stop()
    }
    /// Post-merge 887, P2: an open that first reports "no delivery yet" starts the grace period without a retry. A retryable
    /// failure that follows it (here the open step's own "no client") must still get the one quiet retry.
    @MainActor func testG395RetryableFailureAfterAPendingOpenStillGetsTheQuietRetry() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("g395-pending-retry-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        owner.coordinator=coordinator
        var notices:[CockpitUnavailableNotice]=[],lines:[String]=[]
        CockpitFailureLog.verificationLine={ lines.append($0) }
        defer{CockpitFailureLog.verificationLine=nil}
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(2500))
        surface.show()
        coordinator.onUnavailable?(.noDelivery)   // the open waits for the first context: the grace period starts, no retry spent
        for _ in 0..<250 where !lines.contains(where:{ $0.hasPrefix("open-retry") }) { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertTrue(lines.contains { $0.hasPrefix("open-retry after=open.noClient") },"the later retryable failure is retried once: "+lines.joined(separator:"\n"))
        XCTAssertEqual(lines.filter { $0.hasPrefix("open-retry") }.count,1)
        XCTAssertTrue(notices.isEmpty,"nothing is announced inside the grace period")
        surface.hide();await coordinator.shutdown();await composition.stop()
    }
    /// Post-merge 887, P3: a retry scheduled for one click does not run in the next one. Hide and open again before it is
    /// due: the second click is retried once, not twice.
    @MainActor func testG395QuietRetryDoesNotSurviveHideAndReopen() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("g395-retry-reopen-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        owner.coordinator=coordinator
        var notices:[CockpitUnavailableNotice]=[],lines:[String]=[]
        CockpitFailureLog.verificationLine={ lines.append($0) }
        defer{CockpitFailureLog.verificationLine=nil}
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(3000))
        func failures() -> Int { lines.filter { $0.hasPrefix("unavailable path=open.noClient") }.count }
        surface.show()
        for _ in 0..<500 where failures() < 1 { try await Task.sleep(for:.milliseconds(10)) } // first click: failed, retry scheduled
        surface.hide()
        surface.show()
        for _ in 0..<500 where failures() < 2 { try await Task.sleep(for:.milliseconds(10)) } // second click: failed, its own retry scheduled
        try await Task.sleep(for:.milliseconds(1300)) // past both due times
        XCTAssertEqual(lines.filter { $0.hasPrefix("open-retry") }.count,1,"only the second click's retry runs: "+lines.joined(separator:"\n"))
        surface.hide();await coordinator.shutdown();await composition.stop()
    }
    /// Post-merge 887, P2: a bundle that was admitted and then could not serve a file reports a bundle cause, so the
    /// notice asks for a reinstall; the navigation failure that follows does not replace it.
    @MainActor func testG395BundleDamagedAfterAdmissionAsksForReinstall() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("g395-bundle-resource-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        owner.coordinator=coordinator
        var notices:[CockpitUnavailableNotice]=[],lines:[String]=[]
        CockpitFailureLog.verificationLine={ lines.append($0) }
        defer{CockpitFailureLog.verificationLine=nil}
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(300))
        surface.show()
        try await Self.untilTheConsoleOpenStepRan(coordinator,surface)
        owner.pageFailure?(.bundleResource)
        owner.pageFailure?(.provisionalNavigationFailed)
        try await Task.sleep(for:.milliseconds(900))
        XCTAssertEqual(notices.count,1)
        XCTAssertTrue(notices.first?.bundleProblem ?? false,"a bundled file that cannot be served is a reinstall problem")
        XCTAssertTrue(lines.contains { $0.hasPrefix("notice-shown cause=page.bundleResource bundleProblem=true") },lines.joined(separator:"\n"))
        surface.hide();await coordinator.shutdown();await composition.stop()
    }
    /// macrev-900-1: a bundle cause belongs to its own failure episode. After a rebuild opens (recovery), a later query
    /// failure names itself and does not send the user to reinstall.
    @MainActor func testG395RecoveredBundleFailureDoesNotPoisonALaterQueryNotice() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("g395-bundle-recovered-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        owner.coordinator=coordinator
        var notices:[CockpitUnavailableNotice]=[],lines:[String]=[]
        CockpitFailureLog.verificationLine={ lines.append($0) }
        defer{CockpitFailureLog.verificationLine=nil}
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(300))
        surface.show()
        try await Self.untilTheConsoleOpenStepRan(coordinator,surface)
        owner.pageFailure?(.bundleResource)
        coordinator.onOpened?()                          // the rebuild opened: recovered
        coordinator.onUnavailable?(.query("timeout"))    // an independent later failure
        try await Task.sleep(for:.milliseconds(900))
        XCTAssertEqual(notices.count,1)
        XCTAssertFalse(notices.first?.bundleProblem ?? true,"the working bundle is not a reinstall problem")
        XCTAssertTrue(lines.contains { $0.hasPrefix("notice-shown cause=query.timeout bundleProblem=false") },lines.joined(separator:"\n"))
        surface.hide();await coordinator.shutdown();await composition.stop()
    }
    /// G3-95, slow load: a page that failed to load in time and a query that timed out are not bundle problems; only a
    /// bundle error at page creation asks for a reinstall, and it is not retried.
    @MainActor func testG395OnlyABundleErrorAtPageCreationAsksForReinstall() async throws {
        for (path,expectBundle) in [("open.pageCreation.integrity",true),("open.pageCreation.unavailable",true),("query.timeout",false),("page.visibilityReceiptTimeout",false),("adopt.contextRejected",false)] {
            XCTAssertEqual(CockpitUnavailableNotice.isBundleProblem(path:path),expectBundle,path)
        }
        XCTAssertFalse(CockpitUnavailableNotice(history:false).bundleProblem)
    }
    /// show() opens from a task after a settings hop. The tests below simulate page events, so they first wait for
    /// that open step (which reports "no client" in this setup) to have run; otherwise it lands after the simulated
    /// recovery and starts a grace period of its own, which is a test ordering artefact, not product behaviour.
    @MainActor static func untilTheConsoleOpenStepRan(_ coordinator:EngineCockpitCoordinator,_ surface:SharedEngineCockpitConsole) async throws {
        var ran=false
        let previous=coordinator.onUnavailable
        coordinator.onUnavailable={ reason in previous?(reason); ran=true }
        for _ in 0..<500 where !ran { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertTrue(ran,"the console's open step ran")
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
            try await Self.untilTheConsoleOpenStepRan(coordinator,surface)
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
    /// macrev2-786-1: after a recovered rebuild the user closes the cockpit through the controller's close path
    /// (the coordinator's onClosed). That is an ordinary close: no reopen inside the grace period and no notice.
    @MainActor func testUserCloseAfterARecoveredRebuildDoesNotReopenOrAnnounce() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("g3-66-userclose-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        var opens=0
        let coordinator=EngineCockpitCoordinator { _ in opens+=1; throw CockpitBridgeError.unavailable }
        owner.coordinator=coordinator
        var notices:[CockpitUnavailableNotice]=[]
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(300))
        surface.show()
        try await Self.untilTheConsoleOpenStepRan(coordinator,surface)
        owner.pageFailure?(.messageRejected)   // the first page fails
        coordinator.onOpened?()                 // the rebuild opens: recovered
        let before=opens
        coordinator.onClosed?()                 // the user closes it
        try await Task.sleep(for:.milliseconds(900))
        XCTAssertFalse(surface.wantsVisible,"A user close after a recovery retires the presentation")
        XCTAssertEqual(opens,before,"A user close is not rebuilt")
        XCTAssertTrue(notices.isEmpty,"A user close is not a failure")
        surface.hide();await coordinator.shutdown();await composition.stop()
    }
    /// Audit A-5: a query that fails on the open cockpit and then succeeds on the same page is a recovery, so its notice
    /// is dropped; without the fresh data the failure is still announced once its grace period ends.
    @MainActor func testAQueryFailureFollowedByFreshDataOnTheSamePageIsNotAnnounced() async throws {
        for recovers in [false,true] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("audit-a5-query-"+UUID().uuidString)
            defer{try? FileManager.default.removeItem(at:root)}
            let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
            let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
            let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
            let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
            owner.coordinator=coordinator
            var notices:[CockpitUnavailableNotice]=[]
            let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(300))
            surface.show()
            try await Self.untilTheConsoleOpenStepRan(coordinator,surface)
            coordinator.onOpened?()                          // the cockpit is up
            coordinator.onUnavailable?(.query("timeout"))     // a query on it fails ...
            if recovers { coordinator.onDisplayed?() }        // ... and the next one shows fresh data
            try await Task.sleep(for:.milliseconds(900))
            XCTAssertEqual(notices.count,recovers ? 0 : 1,recovers ? "Fresh data on the same page is a recovery: no notice" : "A query failure that lasts is announced")
            XCTAssertTrue(surface.wantsVisible,"the cockpit stays up either way")
            surface.hide();await coordinator.shutdown();await composition.stop()
        }
    }
    /// Audit A-5: closing the cockpit through the page (its close key, an outside click: the coordinator's onClosed) while
    /// a query failure is in its grace period retires the notice. The close the coordinator makes after an engine feature
    /// failure is that failure's own, and its notice still appears.
    @MainActor func testAUserCloseRetiresAPendingNoticeButAFeatureFailureCloseKeepsIt() async throws {
        for featureFailure in [false,true] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("audit-a5-close-"+UUID().uuidString)
            defer{try? FileManager.default.removeItem(at:root)}
            let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
            let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in RouteClient()})
            let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
            let coordinator=EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
            owner.coordinator=coordinator
            var notices:[CockpitUnavailableNotice]=[]
            let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.milliseconds(300))
            surface.show()
            try await Self.untilTheConsoleOpenStepRan(coordinator,surface)
            coordinator.onOpened?()                                  // the cockpit is up
            if featureFailure { coordinator.onUnavailable?(.featureFailure) } // the engine says the feature failed; the coordinator closes
            else { coordinator.onUnavailable?(.query("timeout")) }    // a query fails; then the user closes the cockpit
            coordinator.onClosed?()
            try await Task.sleep(for:.milliseconds(900))
            XCTAssertFalse(surface.wantsVisible)
            XCTAssertEqual(notices.count,featureFailure ? 1 : 0,featureFailure ? "A feature failure is announced after its own close" : "A user close is not followed by a notice")
            surface.hide();await coordinator.shutdown();await composition.stop()
        }
    }
}
#endif
